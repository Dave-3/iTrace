"""iTrace agents: walkers gather evidence from the graph, byLLM reasons over it.

VerifyAgent   - consumer: registry walk + crowd walk + ReAct investigation
ChannelAgent  - routes the shopper to the right official Kenyan verification channel
MarketIntel   - brand: regional counterfeit pressure -> proposed actions (human approves)
Every agent has a deterministic fallback, so iTrace works with no API key.
"""

import from byllm.lib { Model }
import from datetime { datetime }
import hashlib;
import hmac;
import secrets;
import from services.graph {
    Hub, Brand, Product, Batch, Unit, Region, Trace, Scan, Report, Action, ScannedIn,
    get_hub, find_brand, trace_for, record_scan, km_between, now_iso, REGIONS, share
}

glob agent_llm: Model = Model(model_name="gemini/gemini-2.5-flash");

# =====================================================================
# Shared typed views (these cross the wire to the client)
# =====================================================================

obj AgentStep {
    has agent: str,
        action: str,
        result: str;
}

obj Channel {
    has name: str,
        how: str,
        shortcode: str = "",
        message: str = "",
        link: str = "",
        cost: str = "";
}

obj ScanView {
    has at: str,
        region: str,
        verdict: str,
        lat: float = 0.0,
        lng: float = 0.0;
}

obj RegistryFacts {
    has found: bool = False,
        brand: str = "",
        product: str = "",
        sku: str = "",
        category: str = "",
        mark: str = "",
        permit: str = "",
        batch_no: str = "",
        plant: str = "",
        expires_on: str = "",
        recalled: bool = False,
        price_kes: int = 0,
        kcal_per_100: int = 0,
        sugar_g: float = 0.0,
        salt_g: float = 0.0;
}

obj CrowdFacts {
    has scan_count: int = 0,
        regions: list[str] = [],
        report_notes: list[str] = [],
        claimed_brand: str = "",
        impossible_travel: str = "",
        scans: list[ScanView] = [];
}

obj Investigation {
    has status: str = "unknown",
        confidence: int = 50,
        headline: str = "",
        explanation: str = "",
        evidence: list[str] = [],
        next_steps: list[str] = [],
        category: str = "";
}

sem Investigation.status = "Exactly one of: verified, suspicious, warning, unknown. verified = registered code with clean history. suspicious = signs of cloning/counterfeiting (impossible travel, crowd reports, fake code claiming a brand). warning = genuine but unsafe to use (recalled or expired batch). unknown = not enough evidence either way.";
sem Investigation.confidence = "0-100 confidence in the status, grounded only in tool evidence.";
sem Investigation.headline = "One short plain-language sentence a Kenyan shopper understands, e.g. 'This code was scanned in Mombasa and Kisumu 18 minutes apart'.";
sem Investigation.explanation = "2-3 sentences explaining the reasoning. Never claim certainty the evidence does not support; a code match is not proof the physical item is genuine.";
sem Investigation.evidence = "Bullet facts taken from tool results only. Do not invent numbers.";
sem Investigation.next_steps = "2-4 concrete actions for the shopper (e.g. verify the KEBS mark by SMS, do not consume, report to ACA).";
sem Investigation.category = "Product category: food, beverage, pharma, seed, cosmetic, or other (best guess from product name if unregistered).";

obj VerifyResult {
    has code: str,
        status: str,
        confidence: int,
        headline: str,
        explanation: str,
        evidence: list[str],
        next_steps: list[str],
        category: str,
        registry: RegistryFacts,
        crowd: CrowdFacts,
        channels: list[Channel],
        steps: list[AgentStep],
        ai_used: bool = False,
        ai_note: str = "";
}

obj RegionStat {
    has region: str,
        lat: float,
        lng: float,
        genuine: int = 0,
        suspicious: int = 0,
        fake: int = 0,
        reports: int = 0,
        share_lost_pct: int = 0,
        est_loss_kes: int = 0;
}

obj ProposedAction {
    has kind: str,
        title: str,
        detail: str,
        region: str,
        impact_kes: int;
}

sem ProposedAction.kind = "Exactly one of: field_audit, retailer_alert, promotion, recall_notice.";
sem ProposedAction.title = "Short imperative title, e.g. 'Run a field audit of Kisumu retailers'.";
sem ProposedAction.detail = "1-2 sentences: what to do and why, citing the regional numbers. For a promotion state the discount % and the duration.";
sem ProposedAction.region = "The region the action targets (must be one of the input regions).";
sem ProposedAction.impact_kes = "Estimated monthly KES protected or recovered; use the est_loss_kes figures, do not inflate.";

obj ActionView {
    has id: str,
        kind: str,
        title: str,
        detail: str,
        region: str,
        impact_kes: int,
        status: str,
        by_ai: bool;
}

obj IntelResult {
    has brand: str,
        total_scans: int,
        genuine: int,
        flagged: int,
        share_lost_pct: int,
        est_loss_kes: int,
        regions: list[RegionStat],
        summary: str,
        actions: list[ActionView],
        steps: list[AgentStep],
        ai_used: bool = False,
        ai_note: str = "";
}

# =====================================================================
# Walkers - the graph does the evidence gathering
# =====================================================================

"""Walks Hub -> Brand -> Product -> Batch -> Unit looking for a registered code."""
walker RegistryWalker {
    has code: str,
        facts: RegistryFacts = RegistryFacts(),
        visited: int = 0;

    can start with Hub entry {
        visit [-->[?:Brand]];
    }

    can on_brand with Brand entry {
        visit [-->[?:Product]];
    }

    can on_product with Product entry {
        self.visited += 1;
        # smart routing: iTrace codes embed the SKU token, so skip unrelated product lines
        parts = self.code.split("-");
        if len(parts) >= 3 and parts[0] == "ITR" and parts[1] not in here.sku {
            skip;
        }
        visit [-->[?:Batch]];
    }

    can on_batch with Batch entry {
        hits = [u for u in [here -->][?:Unit] if u.code == self.code];
        if len(hits) > 0 {
            prod = [here <--][?:Product][0];
            brand = [prod <--][?:Brand][0];
            self.facts = RegistryFacts(
                found=True, brand=brand.name, product=prod.name, sku=prod.sku,
                category=prod.category, mark=prod.mark, permit=prod.permit,
                batch_no=here.batch_no, plant=here.plant, expires_on=here.expires_on,
                recalled=here.recalled, price_kes=prod.price_kes,
                kcal_per_100=prod.kcal_per_100, sugar_g=prod.sugar_g, salt_g=prod.salt_g
            );
            disengage;
        }
    }
}

"""Walks a code's Trace -> Scans -> Regions to rebuild its crowd history."""
walker CrowdWalker {
    has facts: CrowdFacts = CrowdFacts();

    can on_trace with Trace entry {
        self.facts.claimed_brand = here.claimed_brand;
        self.facts.report_notes = [r.note for r in [here -->][?:Report]];
        visit [-->[?:Scan]];
    }

    can on_scan with Scan entry {
        regs = [here ->:ScannedIn:->];
        lat = regs[0].lat if len(regs) > 0 else 0.0;
        lng = regs[0].lng if len(regs) > 0 else 0.0;
        self.facts.scans.append(ScanView(at=here.at, region=here.region, verdict=here.verdict, lat=lat, lng=lng));
    }
}

"""Walks a Brand's supply chain and collects every genuine unit code it owns."""
walker SupplyWalker {
    has codes: list[str] = [],
        avg_price: int = 0,
        _prices: list[int] = [];

    can on_brand with Brand entry {
        visit [-->[?:Product]];
    }

    can on_product with Product entry {
        self._prices.append(here.price_kes);
        self.avg_price = int(sum(self._prices) / len(self._prices));
        visit [-->[?:Batch]];
    }

    can on_batch with Batch entry {
        self.codes.extend([u.code for u in [here -->][?:Unit]]);
    }
}

# =====================================================================
# Evidence helpers (also exposed to the LLM as tools)
# =====================================================================

glob _steps: list[AgentStep] = [];

def _log(agent: str, action: str, result: str) {
    _steps.append(AgentStep(agent=agent, action=action, result=result));
}

def _by_time(s: ScanView) -> str {
    return s.at;
}

def gather_registry(code: str) -> RegistryFacts {
    w = RegistryWalker(code=code, facts=RegistryFacts());
    get_hub() spawn w;
    return w.facts;
}

def gather_crowd(code: str) -> CrowdFacts {
    hub = get_hub();
    w = CrowdWalker(facts=CrowdFacts(scans=[], regions=[], report_notes=[]));
    trace_for(hub, code) spawn w;
    facts = w.facts;
    facts.scans = sorted(facts.scans, key=_by_time);
    facts.scan_count = len(facts.scans);
    facts.regions = sorted(list(set([s.region for s in facts.scans])));
    # impossible travel: consecutive scans further apart than a car could drive (> 120 km/h)
    for i in range(1, len(facts.scans)) {
        a = facts.scans[i - 1];
        b = facts.scans[i];
        if a.region == b.region {
            continue;
        }
        km = km_between(a.lat, a.lng, b.lat, b.lng);
        mins = max(1.0, (datetime_from(b.at) - datetime_from(a.at)).total_seconds() / 60.0);
        if km / (mins / 60.0) > 120.0 {
            facts.impossible_travel = f"Scanned in {a.region} then {b.region} ({int(km)} km) only {int(mins)} minutes apart";
        }
    }
    return facts;
}

def datetime_from(s: str) -> datetime {
    return datetime.fromisoformat(s);
}

def lookup_registry(code: str) -> str {
    f = gather_registry(code);
    out = (
        f"REGISTERED. Brand: {f.brand}. Product: {f.product} ({f.category}). Batch {f.batch_no} from {f.plant}, expires {f.expires_on}. "
        + ("BATCH IS RECALLED. " if f.recalled else "Batch not recalled. ")
        + f"KEBS mark: {f.mark or 'n/a'} permit {f.permit}."
    ) if f.found else "NOT REGISTERED: no brand on iTrace owns this code.";
    _log("VerifyAgent", f"lookup_registry('{code}')", out);
    return out;
}
sem lookup_registry = "Look up a product code in the iTrace brand registry graph (brand -> product -> batch -> unit). Returns brand, product, batch, expiry, recall status and KEBS permit, or NOT REGISTERED.";
sem lookup_registry.code = "The product code exactly as printed or scanned.";

def crowd_history(code: str) -> str {
    f = gather_crowd(code);
    out = f"{f.scan_count} prior scans across {len(f.regions)} regions ({', '.join(f.regions) or 'none'}). ";
    if f.impossible_travel {
        out += f"IMPOSSIBLE TRAVEL: {f.impossible_travel}. ";
    }
    if len(f.report_notes) > 0 {
        out += f"{len(f.report_notes)} shopper reports: " + " | ".join(f.report_notes) + ". ";
    }
    if f.claimed_brand {
        out += f"Shoppers say this code is on '{f.claimed_brand}' products. ";
    }
    _log("VerifyAgent", f"crowd_history('{code}')", out);
    return out;
}
sem crowd_history = "Read the crowd scan network for a code: how many times and where it was scanned, impossible-travel cloning signals, and shopper reports. Works even for brands not on iTrace.";
sem crowd_history.code = "The product code.";

def official_channels(category: str) -> str {
    chans = channels_for(category, "");
    out = "; ".join([f"{c.name}: {c.how}" for c in chans]);
    _log("ChannelAgent", f"official_channels('{category}')", out);
    return out;
}
sem official_channels = "List the official Kenyan verification/reporting channels (KEBS, KEPHIS, PPB, KRA, ACA) relevant to a product category.";
sem official_channels.category = "food, beverage, pharma, seed, cosmetic or other.";

# =====================================================================
# ChannelAgent knowledge - verified facts, never LLM-generated
# =====================================================================

def channels_for(category: str, permit: str) -> list[Channel] {
    chans: list[Channel] = [];
    p = permit if permit.startswith("SM-") or permit.startswith("DM-") else "";
    num = p.split("-", 1)[1] if p else "<permit no.>";
    if category in ["food", "beverage", "cosmetic", "other", ""] {
        chans.append(Channel(
            name="KEBS Standardization Mark", how="SMS the permit number printed under the KEBS S-Mark to 20023. The reply names the licensed manufacturer and whether the permit is valid.",
            shortcode="20023", message=f"SM#{num}", cost="Standard SMS rate"
        ));
    }
    if category == "beverage" {
        chans.append(Channel(
            name="KRA Excise Stamp", how="Scan the excise stamp on bottled water, juice or alcohol with KRA's Soma Label app.",
            link="https://play.google.com/store/search?q=soma%20label%20kra&c=apps", cost="Free app"
        ));
    }
    if category == "pharma" {
        chans.append(Channel(
            name="Pharmacy and Poisons Board", how="Search the product's registration in the PPB health products register, and check the pharmacy's licence.",
            link="https://ppb.go.ke/", cost="Free"
        ));
    }
    if category == "seed" {
        chans.append(Channel(
            name="KEPHIS seed check", how="Scratch the KEPHIS label on the packet and SMS the code to 1393. The reply gives variety, producer and lot.",
            shortcode="1393", message="<scratch code>", cost="Free on all networks"
        ));
    }
    chans.append(Channel(
        name="Anti-Counterfeit Authority", how="Report suspected counterfeits to ACA (+254 717 430 640) or KEBS toll-free 1545.",
        link="https://www.aca.go.ke/", shortcode="1545", cost="Toll-free (KEBS)"
    ));
    return chans;
}

# =====================================================================
# VerifyAgent - ReAct investigation with deterministic fallback
# =====================================================================

def investigate(code: str, shopper_note: str, region: str) -> Investigation by agent_llm(
    tools=[lookup_registry, crowd_history, official_channels],
    max_react_iterations=6,
    temperature=0.2
);
sem investigate = "You are iTrace's VerifyAgent, protecting Kenyan shoppers from counterfeit goods. Investigate the product code: ALWAYS call lookup_registry and crowd_history first, then official_channels for the category. Decide the status strictly from tool evidence. Be honest about uncertainty: an unregistered code is 'unknown' unless crowd evidence shows counterfeiting.";
sem investigate.code = "The product code the shopper scanned or typed.";
sem investigate.shopper_note = "Optional observations from the shopper about packaging, taste, seller (may be empty).";
sem investigate.region = "Where the shopper is scanning, e.g. Kisumu.";

def rule_investigation(code: str, reg: RegistryFacts, crowd: CrowdFacts) -> Investigation {
    ev: list[str] = [];
    if reg.found {
        ev.append(f"Code is registered to {reg.brand} - {reg.product}.");
        ev.append(f"Batch {reg.batch_no} ({reg.plant}), expires {reg.expires_on}.");
    } else {
        ev.append("No brand on iTrace owns this code.");
    }
    ev.append(f"{crowd.scan_count} earlier scans across {len(crowd.regions)} region(s).");
    if crowd.impossible_travel {
        ev.append(crowd.impossible_travel + ".");
    }
    if len(crowd.report_notes) > 0 {
        ev.append(f"{len(crowd.report_notes)} shopper report(s): \"{crowd.report_notes[0]}\"");
    }
    if reg.found and reg.recalled {
        return Investigation(
            status="warning", confidence=95, category=reg.category,
            headline=f"Genuine {reg.product}, but batch {reg.batch_no} has been recalled.",
            explanation="The code matches the manufacturer's records, but the manufacturer has recalled this batch. Do not use it; return it to the seller.",
            evidence=ev, next_steps=["Do not use this product.", "Return it to the seller for a replacement.", "Check the pharmacy's licence with PPB."]
        );
    }
    if reg.found and crowd.impossible_travel {
        return Investigation(
            status="suspicious", confidence=85, category=reg.category,
            headline=crowd.impossible_travel + " - this code has likely been cloned.",
            explanation="The code is real, but one physical item cannot be in two distant towns minutes apart. Someone has probably copied a genuine code onto counterfeit packs.",
            evidence=ev, next_steps=["Verify the KEBS mark by SMS before consuming.", "Compare packaging with a trusted outlet.", "Report the seller to ACA."]
        );
    }
    if reg.found {
        return Investigation(
            status="verified", confidence=80, category=reg.category,
            headline=f"Registered {reg.product} from {reg.brand} with a clean scan history.",
            explanation="The code, batch and expiry match the manufacturer's records and no cloning signals were found. A code match cannot prove the physical item is genuine, so check the seal and KEBS mark too.",
            evidence=ev, next_steps=["Check the seal and the KEBS mark.", "Keep your receipt."]
        );
    }
    if len(crowd.report_notes) > 0 or crowd.scan_count >= 3 {
        return Investigation(
            status="suspicious", confidence=65, category="food",
            headline=f"Unregistered code with {crowd.scan_count} scans and {len(crowd.report_notes)} shopper complaints.",
            explanation="The brand owner is not on iTrace, so we cannot confirm the code. Other shoppers have flagged this code, which is a strong warning sign.",
            evidence=ev, next_steps=["Verify the KEBS mark by SMS to 20023.", "Avoid consuming until verified.", "Report to ACA if the KEBS check fails."]
        );
    }
    return Investigation(
        status="unknown", confidence=40, category="other",
        headline="We don't have this code yet - you're the first to check it.",
        explanation="No brand owns this code on iTrace and nobody has scanned it before. That is not proof of a fake. Use the official channel below to confirm.",
        evidence=ev, next_steps=["Verify the KEBS mark by SMS to 20023.", "Report anything unusual."]
    );
}

def _normalize(inv: Investigation, fallback: Investigation) -> Investigation {
    if inv.status not in ["verified", "suspicious", "warning", "unknown"] {
        inv.status = fallback.status;
    }
    # safety rail: the LLM may never upgrade a recalled or cloned item to verified
    if fallback.status in ["warning", "suspicious"] and inv.status == "verified" {
        inv.status = fallback.status;
    }
    if not inv.category {
        inv.category = fallback.category;
    }
    inv.confidence = max(0, min(100, inv.confidence));
    return inv;
}

def:pub verify_product(code: str, region: str, note: str, api_key: str, model: str) -> VerifyResult {
    global _steps;
    _steps = [];
    clean = code.strip().upper();
    hub = get_hub();
    _log("VerifyAgent", "plan", f"Investigate '{clean}' scanned in {region}: registry walk, crowd walk, then route to an official channel.");
    reg = gather_registry(clean);
    _log("RegistryWalker", "walk Hub -> Brand -> Product -> Batch -> Unit", f"{'match: ' + reg.product if reg.found else 'no match'}");
    crowd = gather_crowd(clean);
    _log("CrowdWalker", "walk Trace -> Scan -> Region", f"{crowd.scan_count} scans, regions: {', '.join(crowd.regions) or 'none'}");
    fallback = rule_investigation(clean, reg, crowd);
    inv = fallback;
    ai_used = False;
    ai_note = "AI reasoning off - add a Gemini key in Settings. Rule engine used.";
    if api_key.strip() {
        try {
            agent_llm.api_key = api_key.strip();
            agent_llm.model_name = model.strip() or "gemini/gemini-2.5-flash";
            inv = _normalize(investigate(clean, note, region), fallback);
            ai_used = True;
            ai_note = f"Reasoned by {agent_llm.model_name} using {len([s for s in _steps if s.action.startswith(('lookup', 'crowd', 'official'))])} tool calls.";
        } except Exception as e {
            inv = fallback;
            ai_note = "AI unavailable (" + str(e)[:120] + ") - rule engine used.";
        }
    }
    channels = channels_for(inv.category or reg.category, reg.permit);
    _log("ChannelAgent", f"route category '{inv.category or reg.category}'", " -> ".join([c.name for c in channels]));
    # every check feeds the network
    record_scan(hub, clean, region, inv.status);
    if reg.found {
        _log("VerifyAgent", "record scan", f"Scan saved in {region}; the crowd network now has {crowd.scan_count + 1} scans of this code.");
    } else {
        _log("VerifyAgent", "record scan", f"Unregistered code added to the crowd network from {region}.");
    }
    return VerifyResult(
        code=clean, status=inv.status, confidence=inv.confidence, headline=inv.headline,
        explanation=inv.explanation, evidence=inv.evidence, next_steps=inv.next_steps,
        category=inv.category or reg.category, registry=reg, crowd=crowd, channels=channels,
        steps=list(_steps), ai_used=ai_used, ai_note=ai_note
    );
}

def:pub report_product(code: str, region: str, note: str) -> str {
    clean = code.strip().upper();
    if len(note.strip()) < 5 {
        return "Please describe what you noticed (at least 5 characters).";
    }
    hub = get_hub();
    rep = (trace_for(hub, clean) ++> Report(note=note.strip()[:1000], region=region, at=now_iso()))[0];
    share(rep);
    return "Report saved. It now warns every shopper who checks this code, and alerts the brand.";
}

def:pub list_regions() -> list[str] {
    return [r.name for r in REGIONS];
}

def:pub list_brands() -> list[str] {
    return [b.name for b in [get_hub() -->][?:Brand]];
}

# =====================================================================
# MarketIntelAgent - where is the brand losing to fakes, and what to do
# =====================================================================

def propose_actions(brand: str, regions: list[RegionStat], total_loss_kes: int) -> list[ProposedAction] by agent_llm(temperature=0.3);
sem propose_actions = "You are iTrace's MarketIntelAgent advising a Kenyan brand manager. From regional scan statistics, propose 3-4 high-impact actions: field audits or retailer alerts where counterfeit share is highest, and a time-limited promotion (with a discount %) in a region where genuine demand is strong but fakes are creeping in, to win shoppers back to genuine stock. Actions are proposals; a human approves them.";
sem propose_actions.brand = "The brand name.";
sem propose_actions.regions = "Per-region stats: genuine scans, suspicious (cloned) scans, fake (unregistered code claiming the brand), shopper reports, share lost %, estimated monthly loss in KES.";
sem propose_actions.total_loss_kes = "Total estimated monthly loss in KES across Kenya.";

def rule_actions(regions: list[RegionStat]) -> list[ProposedAction] {
    ranked = sorted(regions, key=lambda r: RegionStat : r.share_lost_pct, reverse=True);
    acts: list[ProposedAction] = [];
    if len(ranked) > 0 and ranked[0].share_lost_pct > 0 {
        r = ranked[0];
        acts.append(ProposedAction(kind="field_audit", title=f"Run a field audit of {r.region} retailers",
            detail=f"{r.share_lost_pct}% of scans in {r.region} fail verification ({r.fake} fake codes, {r.suspicious} cloned). Send a team with ACA to the top outlets.",
            region=r.region, impact_kes=r.est_loss_kes));
    }
    if len(ranked) > 1 and ranked[1].share_lost_pct > 0 {
        r = ranked[1];
        acts.append(ProposedAction(kind="retailer_alert", title=f"Alert {r.region} retailers to cloned codes",
            detail=f"SMS registered stockists in {r.region}: {r.suspicious + r.fake} flagged scans this month. Ask them to buy only from authorised distributors.",
            region=r.region, impact_kes=int(r.est_loss_kes / 2)));
    }
    by_genuine = sorted([r for r in regions if r.genuine > 0], key=lambda r: RegionStat : r.genuine, reverse=True);
    if len(by_genuine) > 0 {
        r = by_genuine[0];
        acts.append(ProposedAction(kind="promotion", title=f"10% off genuine stock in {r.region} for 2 weeks",
            detail=f"{r.region} has your strongest verified demand ({r.genuine} genuine scans). A short promotion on scanned-genuine packs rewards shoppers who verify and squeezes fake sellers on price.",
            region=r.region, impact_kes=int(r.est_loss_kes / 3) + 15000));
    }
    return acts;
}

def _view(a: Action) -> ActionView {
    return ActionView(id=jid(a), kind=a.kind, title=a.title, detail=a.detail, region=a.region,
        impact_kes=a.impact_kes, status=a.status, by_ai=a.by_ai);
}

obj RegionScan {
    has regions: list[RegionStat],
        avg_price: int,
        n_codes: int;
}

def _region_stats(hub: Hub, brand: Brand) -> RegionScan {
    sw = SupplyWalker(codes=[], _prices=[]);
    brand spawn sw;
    own = set(sw.codes);
    stats: dict[str, RegionStat] = {};
    for r in [hub -->][?:Region] {
        stats[r.name] = RegionStat(region=r.name, lat=r.lat, lng=r.lng);
    }
    for t in [hub -->][?:Trace] {
        mine = t.code in own;
        claimed = t.claimed_brand == brand.name;
        if not mine and not claimed {
            continue;
        }
        for s in [t -->][?:Scan] {
            if s.region not in stats {
                continue;
            }
            st = stats[s.region];
            if mine and s.verdict == "suspicious" {
                st.suspicious += 1;
            } elif mine {
                st.genuine += 1;
            } else {
                st.fake += 1;
            }
        }
        for rp in [t -->][?:Report] {
            if rp.region in stats {
                stats[rp.region].reports += 1;
            }
        }
    }
    for st in stats.values() {
        bad = st.suspicious + st.fake;
        total = bad + st.genuine;
        st.share_lost_pct = int(round(100 * bad / total)) if total > 0 else 0;
        # each flagged scan ~ 40 packs sold through the same channel (pilot assumption)
        st.est_loss_kes = bad * 40 * max(sw.avg_price, 50);
    }
    return RegionScan(regions=list(stats.values()), avg_price=sw.avg_price, n_codes=len(own));
}

def:pub market_intel(token: str, api_key: str, model: str, refresh: bool) -> IntelResult {
    global _steps;
    _steps = [];
    hub = get_hub();
    acct = _account_by_token(token);
    brand_name = acct.brand if acct is not None else "";
    brand = find_brand(hub, brand_name) if acct is not None else None;
    if brand is None {
        return IntelResult(brand=brand_name, total_scans=0, genuine=0, flagged=0, share_lost_pct=0,
            est_loss_kes=0, regions=[], summary="Sign in to see your brand's dashboard.", actions=[], steps=[]);
    }
    _log("MarketIntelAgent", "plan", f"Map counterfeit pressure on {brand.name} across Kenya and propose actions.");
    rs = _region_stats(hub, brand);
    regions = rs.regions;
    _log("SupplyWalker", "walk Brand -> Product -> Batch -> Unit", f"{rs.n_codes} genuine unit codes, average price KES {rs.avg_price}");
    genuine = sum([r.genuine for r in regions]);
    flagged = sum([r.suspicious + r.fake for r in regions]);
    loss = sum([r.est_loss_kes for r in regions]);
    share_pct = int(round(100 * flagged / (genuine + flagged))) if genuine + flagged > 0 else 0;
    hot = sorted(regions, key=lambda r: RegionStat : r.share_lost_pct, reverse=True);
    _log("MarketIntelAgent", "scan crowd network", f"{genuine} genuine vs {flagged} flagged scans; hotspots: {', '.join([h.region for h in hot[:3]])}");
    summary = f"{share_pct}% of {brand.name} scans nationally fail verification. Hotspots: " + ", ".join([f"{h.region} ({h.share_lost_pct}%)" for h in hot[:3]]) + f". Estimated KES {loss:,} a month leaks to counterfeits.";

    existing = [a for a in [brand -->][?:Action]];
    ai_used = False;
    ai_note = "AI reasoning off - rule engine proposed these actions.";
    if refresh or len(existing) == 0 {
        props = rule_actions(regions);
        if api_key.strip() {
            try {
                agent_llm.api_key = api_key.strip();
                agent_llm.model_name = model.strip() or "gemini/gemini-2.5-flash";
                ai_props = propose_actions(brand.name, [r for r in regions if r.genuine + r.fake + r.suspicious > 0], loss);
                if len(ai_props) > 0 {
                    props = ai_props;
                    ai_used = True;
                    ai_note = f"Actions proposed by {agent_llm.model_name}.";
                }
            } except Exception as e {
                ai_note = "AI unavailable (" + str(e)[:120] + ") - rule engine used.";
            }
        }
        # replace pending proposals; keep decided ones as history
        for a in existing {
            if a.status == "pending" {
                del a;
            }
        }
        for p in props {
            act = (brand ++> Action(kind=p.kind, title=p.title, detail=p.detail, region=p.region,
                impact_kes=p.impact_kes, created_at=now_iso(), by_ai=ai_used))[0];
            share(act);
        }
        _log("MarketIntelAgent", "propose actions", f"{len(props)} actions awaiting human approval");
    }
    actions = [_view(a) for a in [brand -->][?:Action]];
    return IntelResult(brand=brand.name, total_scans=genuine + flagged, genuine=genuine, flagged=flagged,
        share_lost_pct=share_pct, est_loss_kes=loss, regions=regions, summary=summary, actions=actions,
        steps=list(_steps), ai_used=ai_used, ai_note=ai_note);
}

def:pub decide_action(token: str, action_id: str, decision: str) -> ActionView | None {
    acct = _account_by_token(token);
    if acct is None {
        return None;
    }
    target = jobj(action_id);
    owners = [b.name for b in [target <--][?:Brand]] if isinstance(target, Action) else [];
    if isinstance(target, Action) and acct.brand in owners and decision in ["approved", "rejected"] {
        target.status = decision;
        return _view(target);
    }
    return None;
}

# =====================================================================
# Business API - brands push their registry and scan events (REST)
# =====================================================================

"""POST /walker/register_batch - a brand registers a batch of unit codes."""
walker:pub register_batch {
    has brand: str,
        product: str,
        batch_no: str,
        category: str = "food",
        expires_on: str = "",
        codes: list[str] = [];

    can create with Root entry {
        hub = get_hub();
        b = find_brand(hub, self.brand);
        if b is None {
            b = (hub ++> Brand(name=self.brand, sector=self.category))[0];
            share(b);
        }
        prods = [p for p in [b -->][?:Product] if p.name == self.product];
        prod = prods[0] if len(prods) > 0 else (b ++> Product(sku=self.product.upper().replace(" ", "-")[:24], name=self.product, category=self.category))[0];
        share(prod);
        batch = (prod ++> Batch(batch_no=self.batch_no, expires_on=self.expires_on, size=len(self.codes)))[0];
        share(batch);
        for c in self.codes {
            share((batch ++> Unit(code=c.strip().upper()))[0]);
        }
        report {"ok": True, "brand": b.name, "product": prod.name, "batch": batch.batch_no, "units": len(self.codes)};
    }
}

"""POST /walker/ingest_scan - a retailer POS or distributor pushes a scan event."""
walker:pub ingest_scan {
    has code: str,
        region: str = "Nairobi CBD";

    can create with Root entry {
        reg = gather_registry(self.code.strip().upper());
        verdict = "verified" if reg.found else "unknown";
        record_scan(get_hub(), self.code.strip().upper(), self.region, verdict);
        report {"ok": True, "code": self.code, "registered": reg.found, "verdict": verdict};
    }
}

# =====================================================================
# Brand workspaces - accounts live on the graph (salted PBKDF2, session tokens)
# =====================================================================

node Account {
    has email: str,
        brand: str,
        salt: str,
        pw_hash: str,
        token: str = "",
        created_at: str = "";
}

obj Session {
    has ok: bool = False,
        token: str = "",
        email: str = "",
        brand: str = "",
        error: str = "";
}

def _hash(password: str, salt: str) -> str {
    return hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 120000).hex();
}

def _account_by_email(hub: Hub, email: str) -> Account | None {
    for a in [hub -->][?:Account] {
        if a.email == email {
            return a;
        }
    }
    return None;
}

def _account_by_token(token: str) -> Account | None {
    if len(token) < 20 {
        return None;
    }
    for a in [get_hub() -->][?:Account] {
        if a.token != "" and hmac.compare_digest(a.token, token) {
            return a;
        }
    }
    return None;
}

def:pub sign_up(email: str, password: str, brand_name: str) -> Session {
    hub = get_hub();
    clean = email.strip().lower();
    if "@" not in clean or len(clean) > 120 {
        return Session(error="Enter a valid work email.");
    }
    if len(password) < 8 {
        return Session(error="Use a password of at least 8 characters.");
    }
    if len(brand_name.strip()) < 2 {
        return Session(error="Choose the brand you manage.");
    }
    if _account_by_email(hub, clean) is not None {
        return Session(error="An account with this email already exists - sign in instead.");
    }
    brand = brand_name.strip()[:60];
    if find_brand(hub, brand) is None {
        share((hub ++> Brand(name=brand, sector="New on iTrace"))[0]);
    }
    salt = secrets.token_hex(16);
    tok = secrets.token_urlsafe(32);
    hub ++> Account(email=clean, brand=brand, salt=salt, pw_hash=_hash(password, salt), token=tok, created_at=now_iso());
    return Session(ok=True, token=tok, email=clean, brand=brand);
}

def:pub sign_in(email: str, password: str) -> Session {
    a = _account_by_email(get_hub(), email.strip().lower());
    if a is None or not hmac.compare_digest(a.pw_hash, _hash(password, a.salt)) {
        return Session(error="Email or password is incorrect.");
    }
    a.token = secrets.token_urlsafe(32);
    return Session(ok=True, token=a.token, email=a.email, brand=a.brand);
}

def:pub whoami(token: str) -> Session {
    a = _account_by_token(token);
    if a is None {
        return Session(error="Session expired - please sign in.");
    }
    return Session(ok=True, token=token, email=a.email, brand=a.brand);
}

def:pub sign_out(token: str) -> bool {
    a = _account_by_token(token);
    if a is not None {
        a.token = "";
    }
    return True;
}
