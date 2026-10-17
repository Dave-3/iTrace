sv import from ..services.agents {
    market_intel, decide_action, list_brands,
    IntelResult, RegionStat, ActionView, AgentStep
}
import from ..lib.aiSettings { load_ai }
import from .AgentTrace { AgentTrace }

glob KIND_LABEL: dict[str, str] = {
    "field_audit": "Field audit",
    "retailer_alert": "Retailer alert",
    "promotion": "Promotion",
    "recall_notice": "Recall notice"
};

def fmt_kes(n: int) -> str {
    digits = str(n);
    out = "";
    for (i, ch) in enumerate(digits) {
        if i > 0 and (len(digits) - i) % 3 == 0 {
            out = out + ",";
        }
        out = out + str(ch);
    }
    return "KES " + out;
}

def heat(pct: int) -> str {
    return "#ef6b5b" if pct >= 60 else ("#ffc03d" if pct >= 30 else "rgb(36,182,182)");
}

def:pub Kpi(label: str, value: str, hint: str = "") -> JsxElement {
    return <div className="rounded-2xl border border-white/10 bg-surface p-5">
        <p className="text-xs uppercase tracking-[0.14em] text-slate-400">{label}</p>
        <p className="mt-2 font-display text-3xl font-extrabold">{value}</p>
        {if hint != "" { <p className="mt-1 text-xs text-slate-500">{hint}</p> }}
    </div>;
}

"""Kenya hotspot map: regions plotted from their real lat/lng, sized by flagged scans."""
def:pub HotspotMap(regions: list[RegionStat]) -> JsxElement {
    # Kenya bounding box ~ lng 33.9..41.9, lat -4.7..5.0
    def px(lng: float) -> float { return (lng - 33.6) / (42.2 - 33.6) * 400; }
    def py(lat: float) -> float { return (5.2 - lat) / (5.2 + 4.9) * 460; }
    return <div className="rounded-2xl border border-white/10 bg-surface p-5">
        <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Counterfeit pressure map</h3>
        <p className="mt-1 text-xs text-slate-400">Circle size = flagged scans · colour = share of scans failing verification</p>
        <svg viewBox="0 0 400 460" className="mt-3 w-full" role="img" aria-label="Map of Kenya with counterfeit hotspots">
            <path d="M120,60 L250,40 L300,95 L360,150 L330,240 L345,330 L300,395 L255,440 L215,420 L180,345 L95,300 L40,265 L30,200 L60,140 Z"
                fill="#1f2b36" stroke="rgba(255,255,255,0.12)" strokeWidth="1.5"></path>
            {for r in regions {
                flagged = r.suspicious + r.fake;
                rad: float = 6.0 + min(26.0, flagged * 1.6);
                <g key={r.region}>
                    <circle cx={px(r.lng)} cy={py(r.lat)} r={rad} fill={heat(r.share_lost_pct)} fillOpacity="0.28" stroke={heat(r.share_lost_pct)} strokeWidth="1.5"></circle>
                    <circle cx={px(r.lng)} cy={py(r.lat)} r="2.5" fill="#fff"></circle>
                    {if flagged > 0 {
                        <text x={px(r.lng) + rad + 3} y={py(r.lat) + 4} fill="#cbd5e1" fontSize="11">{r.region + " " + str(r.share_lost_pct) + "%"}</text>
                    }}
                </g>
            }}
        </svg>
    </div>;
}

def:pub RegionBars(regions: list[RegionStat]) -> JsxElement {
    def by_loss(r: RegionStat) -> int { return r.est_loss_kes; }
    ranked = sorted(regions, key=by_loss, reverse=True);
    return <div className="rounded-2xl border border-white/10 bg-surface p-5">
        <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Where you're losing share</h3>
        <div className="mt-2 flex gap-4 text-xs text-slate-400">
            <span className="flex items-center gap-1.5"><span className="size-2.5 rounded-sm bg-teal"></span>genuine</span>
            <span className="flex items-center gap-1.5"><span className="size-2.5 rounded-sm bg-gold"></span>cloned code</span>
            <span className="flex items-center gap-1.5"><span className="size-2.5 rounded-sm bg-danger"></span>fake code</span>
        </div>
        <div className="mt-4 flex flex-col gap-3">
            {for r in ranked {
                total = max(1, r.genuine + r.suspicious + r.fake);
                <div key={r.region}>
                    <div className="flex items-baseline justify-between gap-3 text-sm">
                        <span className="text-slate-200">{r.region}</span>
                        <span className="text-xs text-slate-400">{str(r.share_lost_pct) + "% lost · " + fmt_kes(r.est_loss_kes) + "/mo"}</span>
                    </div>
                    <div className="mt-1 flex h-2.5 overflow-hidden rounded-full bg-white/5">
                        <div className="bg-teal" style={{"width": str(100 * r.genuine / total) + "%"}}></div>
                        <div className="bg-gold" style={{"width": str(100 * r.suspicious / total) + "%"}}></div>
                        <div className="bg-danger" style={{"width": str(100 * r.fake / total) + "%"}}></div>
                    </div>
                </div>
            }}
        </div>
    </div>;
}

def:pub ActionCard(a: ActionView, onDecide: Callable[[str, str], None]) -> JsxElement {
    def approve(e: MouseEvent) { onDecide(a.id, "approved"); }
    def reject(e: MouseEvent) { onDecide(a.id, "rejected"); }
    badge = "border-teal/60 text-teal" if a.status == "approved" else ("border-white/20 text-slate-400" if a.status == "rejected" else "border-amber/60 text-amber");
    return <div className={"flex flex-col gap-3 rounded-xl border bg-ink-deep p-4 " + ("border-teal/40" if a.status == "approved" else "border-white/10")}>
        <div className="flex flex-wrap items-center justify-between gap-2">
            <span className="text-xs font-bold uppercase tracking-[0.12em] text-slate-400">{(KIND_LABEL[a.kind] or a.kind) + " · " + a.region}</span>
            <span className={"rounded-full border px-2 py-0.5 text-[11px] " + badge}>{a.status + (" · AI" if a.by_ai else "")}</span>
        </div>
        <p className="font-semibold text-white">{a.title}</p>
        <p className="text-sm leading-6 text-slate-400">{a.detail}</p>
        <div className="flex flex-wrap items-center justify-between gap-3">
            <span className="text-sm text-teal">{"protects ~" + fmt_kes(a.impact_kes) + "/mo"}</span>
            {if a.status == "pending" {
                <div className="flex gap-2">
                    <button type="button" onClick={reject} className="rounded-full border border-white/15 px-4 py-1.5 text-sm text-slate-300 hover:border-white/40">Reject</button>
                    <button type="button" onClick={approve} className="rounded-full bg-amber px-4 py-1.5 text-sm font-semibold text-ink hover:bg-amber-soft">Approve</button>
                </div>
            }}
        </div>
    </div>;
}

glob API_SNIPPET: str = "curl -X POST https://<your-itrace-host>/walker/register_batch \\\n  -H 'Content-Type: application/json' \\\n  -d '{\"brand\": \"Nyota Beverages\", \"product\": \"Nyota Mango Nectar 1L\",\n       \"batch_no\": \"NB-2700\", \"category\": \"beverage\",\n       \"codes\": [\"ITR-MANGO-2700\", \"ITR-MANGO-2701\"]}'\n\ncurl -X POST https://<your-itrace-host>/walker/ingest_scan \\\n  -H 'Content-Type: application/json' -d '{\"code\": \"ITR-MANGO-2700\", \"region\": \"Kisumu\"}'";

def:pub BusinessPage() -> JsxElement {
    has brands: list[str] = [],
        selected: str = "Nyota Beverages",
        intel: IntelResult | None = None,
        busy: bool = False,
        error: str = "";

    async def load(brand: str, rerun: bool) {
        selected = brand;
        busy = True;
        error = "";
        ai = load_ai();
        brand_name = brand;
        api_key = ai.key;
        model = ai.model;
        refresh = rerun;
        try {
            intel = await market_intel(brand_name, api_key, model, refresh);
        } except Exception {
            error = "Could not reach MarketIntelAgent.";
        }
        busy = False;
    }

    async can with entry {
        brands = await list_brands();
        await load("Nyota Beverages", False);
    }

    async def decide(action_id: str, decision: str) {
        _ = await decide_action(action_id, decision);
        # write-then-refetch: the decision is persisted on the brand's graph
        await load(selected, False);
    }

    return <main className="mx-auto w-full max-w-7xl px-4 pb-20 pt-10 sm:px-8">
        <section className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
            <div>
                <p className="text-sm font-semibold uppercase tracking-[0.16em] text-amber">Business solutions</p>
                <h1 className="mt-3 font-display text-4xl font-extrabold leading-[0.95] tracking-tight sm:text-6xl">See where fakes<br /><span className="text-slate-400">eat your market.</span></h1>
            </div>
            <div className="flex flex-col gap-3">
                <div className="flex flex-wrap gap-2">
                    {for b in brands {
                        <button key={b} type="button" onClick={lambda { load(b, False); }}
                            className={"rounded-full border px-3 py-1.5 text-sm " + ("border-amber bg-amber text-ink" if b == selected else "border-white/15 text-slate-300 hover:border-white/40")}>{b}</button>
                    }}
                </div>
                <button type="button" onClick={lambda { load(selected, True); }} disabled={busy}
                    className="self-start rounded-full border border-amber px-5 py-2 text-sm font-semibold text-amber hover:bg-amber hover:text-ink disabled:opacity-60 lg:self-end">
                    {"MarketIntelAgent analysing…" if busy else "↻ Re-run MarketIntelAgent"}
                </button>
            </div>
        </section>
        {if error != "" { <p role="alert" className="mt-4 text-danger">{error}</p> }}

        {if intel is not None {
            <div className={"mt-10 flex flex-col gap-6 " + ("opacity-60" if busy else "")}>
                <p className="rounded-2xl border border-amber/30 bg-amber/5 p-5 text-lg leading-8 text-slate-200">{intel.summary}</p>
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    <Kpi label="Scans failing verification" value={str(intel.share_lost_pct) + "%"} hint={str(intel.flagged) + " of " + str(intel.total_scans) + " scans"} />
                    <Kpi label="Est. monthly leakage" value={fmt_kes(intel.est_loss_kes)} hint="flagged scans × 40 packs × avg price" />
                    <Kpi label="Genuine scans" value={str(intel.genuine)} hint="shoppers who verified your product" />
                    <Kpi label="Actions awaiting you" value={str(len([a for a in intel.actions if a.status == "pending"]))} hint="proposed by MarketIntelAgent" />
                </div>
                <div className="grid gap-6 lg:grid-cols-2">
                    <HotspotMap regions={intel.regions} />
                    <RegionBars regions={intel.regions} />
                </div>
                <div className="grid gap-6 lg:grid-cols-[1.3fr_1fr]">
                    <div className="rounded-2xl border border-white/10 bg-surface p-5">
                        <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Proposed actions</h3>
                        <p className="mt-1 text-sm text-slate-400">Nothing happens until you approve. Every decision is logged on the brand's graph.</p>
                        <div className="mt-4 flex flex-col gap-3">
                            {for a in intel.actions {
                                <ActionCard key={a.id} a={a} onDecide={lambda aid: str, d: str { decide(aid, d); }} />
                            }}
                        </div>
                    </div>
                    <div className="flex flex-col gap-6">
                        <AgentTrace steps={intel.steps} note={intel.ai_note} busy={busy} />
                        <div className="rounded-2xl border border-white/10 bg-surface p-5">
                            <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Connect your systems</h3>
                            <p className="mt-1 text-sm text-slate-400">Every iTrace walker is a REST endpoint. Push batches from your ERP and scans from your POS.</p>
                            <pre className="mt-3 overflow-x-auto rounded-lg bg-ink-deep p-3 text-[11px] leading-5 text-slate-300">{API_SNIPPET}</pre>
                        </div>
                    </div>
                </div>
            </div>
        }}
    </main>;
}
