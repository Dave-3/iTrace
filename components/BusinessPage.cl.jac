sv import from ..services.agents {
    market_intel, decide_action, whoami, sign_out,
    IntelResult, RegionStat, ActionView, AgentStep, Session
}
import from ..lib.aiSettings { load_ai }
import from ..lib.session { load_token, save_token }
import from .AgentTrace { AgentTrace }
import from .BusinessAuth { BusinessAuth }

glob KIND_LABEL: dict[str, str] = {
    "field_audit": "Field audit",
    "retailer_alert": "Retailer alert",
    "promotion": "Promotion",
    "recall_notice": "Recall notice"
};

# Kenya outline (Natural Earth, public domain) projected to a 400x500 canvas:
# x = (lng - 33.7) / 8.4 * 400, y = (5.7 - lat) / 10.6 * 500
glob KENYA_PATH: str = "M347.3,309.4 L375.5,348.3 L342.1,367.1 L330.4,386.8 L312.5,390.2 L305.8,423.5 L290.5,442.5 L281.2,473.9 L262.0,489.5 L193.7,442.3 L190.4,415.0 L17.7,318.9 L9.7,313.7 L9.2,263.7 L22.9,244.6 L46.3,213.4 L63.6,179.0 L42.7,124.8 L37.1,101.2 L14.5,68.4 L43.8,40.2 L76.1,9.2 L100.8,17.1 L100.8,43.5 L117.1,59.1 L150.2,59.1 L210.5,99.1 L225.6,99.6 L236.7,98.3 L247.3,103.7 L279.0,107.4 L293.1,87.8 L336.6,68.1 L355.8,84.0 L388.3,84.0 L346.7,137.5 L347.3,309.4 Z";

glob NAV: list[list[str]] = [
    ["overview", "Overview"],
    ["map", "Hotspot map"],
    ["actions", "Action queue"],
    ["agents", "Agent activity"],
    ["api", "API & integrations"]
];

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

def scroll_to(anchor: str) {
    el: any = document.getElementById(anchor);
    if el {
        el.scrollIntoView({"behavior": "smooth"});
    }
}

def px(lng: float) -> float { return (lng - 33.7) / 8.4 * 400; }
def py(lat: float) -> float { return (5.7 - lat) / 10.6 * 500; }

def:pub Kpi(label: str, value: str, hint: str = "", tone: str = "text-white") -> JsxElement {
    return <div className="rounded-2xl border border-white/10 bg-surface p-5">
        <p className="text-xs font-semibold uppercase tracking-[0.14em] text-slate-400">{label}</p>
        <p className={"mt-3 font-display text-3xl font-extrabold " + tone}>{value}</p>
        {if hint != "" { <p className="mt-1 text-xs text-slate-500">{hint}</p> }}
    </div>;
}

"""Heat map over Kenya's real outline; bubbles at each region's lat/lng."""
def:pub HotspotMap(regions: list[RegionStat]) -> JsxElement {
    return <div id="map" className="scroll-mt-24 rounded-2xl border border-white/10 bg-surface p-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
                <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Counterfeit heat map</h3>
                <p className="mt-1 text-xs text-slate-400">Bubble size = flagged scans · colour = share failing verification</p>
            </div>
            <div className="flex gap-3 text-[11px] text-slate-400">
                <span className="flex items-center gap-1"><span className="size-2.5 rounded-full bg-teal"></span>&lt;30%</span>
                <span className="flex items-center gap-1"><span className="size-2.5 rounded-full bg-amber"></span>30-60%</span>
                <span className="flex items-center gap-1"><span className="size-2.5 rounded-full bg-danger"></span>&gt;60%</span>
            </div>
        </div>
        <svg viewBox="0 0 400 500" className="mx-auto mt-2 w-full max-w-md" role="img" aria-label="Map of Kenya with counterfeit hotspots by region">
            <defs>
                <radialGradient id="glow">
                    <stop offset="0%" stopColor="#ffffff" stopOpacity="0.35"></stop>
                    <stop offset="100%" stopColor="#ffffff" stopOpacity="0"></stop>
                </radialGradient>
            </defs>
            <path d={KENYA_PATH} fill="#22313d" stroke="rgba(255,192,61,0.35)" strokeWidth="1.5" strokeLinejoin="round"></path>
            <ellipse cx="22" cy="268" rx="16" ry="22" fill="#1a3a4a" opacity="0.9"></ellipse>
            <text x="8" y="300" fill="#5d7c8c" fontSize="9">L. Victoria</text>
            {for r in regions {
                flagged = r.suspicious + r.fake;
                rad: float = 4.0 + min(30.0, flagged * 1.8);
                <g key={r.region}>
                    {if flagged > 0 {
                        <circle cx={px(r.lng)} cy={py(r.lat)} r={rad + 6} fill="url(#glow)"></circle>
                    }}
                    <circle cx={px(r.lng)} cy={py(r.lat)} r={rad} fill={heat(r.share_lost_pct)} fillOpacity="0.35" stroke={heat(r.share_lost_pct)} strokeWidth="1.5"></circle>
                    <circle cx={px(r.lng)} cy={py(r.lat)} r="2.5" fill="#ffffff"></circle>
                    {if flagged > 0 {
                        <text x={px(r.lng) + rad + 4} y={py(r.lat) + 4} fill="#e2e8f0" fontSize="12" fontWeight="600">{r.region + " · " + str(r.share_lost_pct) + "%"}</text>
                    }}
                </g>
            }}
        </svg>
    </div>;
}

def:pub RegionTable(regions: list[RegionStat]) -> JsxElement {
    def by_loss(r: RegionStat) -> int { return r.est_loss_kes; }
    ranked = sorted(regions, key=by_loss, reverse=True);
    return <div className="rounded-2xl border border-white/10 bg-surface p-5">
        <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Market share by region</h3>
        <div className="mt-2 flex gap-4 text-xs text-slate-400">
            <span className="flex items-center gap-1.5"><span className="size-2.5 rounded-sm bg-teal"></span>genuine</span>
            <span className="flex items-center gap-1.5"><span className="size-2.5 rounded-sm bg-gold"></span>cloned code</span>
            <span className="flex items-center gap-1.5"><span className="size-2.5 rounded-sm bg-danger"></span>fake code</span>
        </div>
        <div className="mt-4 flex flex-col gap-3.5">
            {for r in ranked {
                total = max(1, r.genuine + r.suspicious + r.fake);
                <div key={r.region}>
                    <div className="flex items-baseline justify-between gap-3 text-sm">
                        <span className="text-slate-200">{r.region}</span>
                        <span className="text-xs text-slate-400">{str(r.share_lost_pct) + "% lost · " + fmt_kes(r.est_loss_kes) + "/mo"}</span>
                    </div>
                    <div className="mt-1 flex h-2 overflow-hidden rounded-full bg-white/5">
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

"""Business area: sign-in gate, then the brand dashboard."""
def:pub BusinessPage() -> JsxElement {
    has session: Session | None = None,
        checking: bool = True,
        intel: IntelResult | None = None,
        busy: bool = False,
        error: str = "";

    async def load(rerun: bool) {
        busy = True;
        error = "";
        ai = load_ai();
        token = load_token();
        api_key = ai.key;
        model = ai.model;
        refresh = rerun;
        try {
            intel = await market_intel(token, api_key, model, refresh);
        } except Exception {
            error = "Could not reach MarketIntelAgent.";
        }
        busy = False;
    }

    async can with entry {
        token = load_token();
        if token != "" {
            s = await whoami(token);
            if s.ok {
                session = s;
                await load(False);
            } else {
                save_token("");
            }
        }
        checking = False;
    }

    async def on_authed(s: Session) {
        session = s;
        await load(False);
    }

    async def do_sign_out() {
        token = load_token();
        _ = await sign_out(token);
        save_token("");
        session = None;
        intel = None;
    }

    async def decide(action_id: str, decision: str) {
        token = load_token();
        _ = await decide_action(token, action_id, decision);
        await load(False);
    }

    if checking {
        return <main className="flex min-h-[60vh] items-center justify-center"><p className="agent-pulse text-amber">Loading your workspace…</p></main>;
    }
    if session is None {
        return <BusinessAuth onAuthed={lambda s: Session { on_authed(s); }} />;
    }

    pending = len([a for a in intel.actions if a.status == "pending"]) if intel is not None else 0;
    return <div className="mx-auto grid w-full max-w-[1440px] lg:grid-cols-[248px_1fr]">
        <aside className="hidden border-r border-white/5 lg:block">
            <div className="sticky top-[57px] flex h-[calc(100svh-57px)] flex-col gap-6 p-5">
                <div className="rounded-xl border border-white/10 bg-surface p-4">
                    <p className="text-[11px] uppercase tracking-[0.14em] text-slate-500">Workspace</p>
                    <p className="mt-1 font-display text-lg font-bold leading-tight">{session.brand}</p>
                    <p className="mt-1 truncate text-xs text-slate-400">{session.email}</p>
                </div>
                <nav className="flex flex-col gap-1" aria-label="Dashboard">
                    {for n in NAV {
                        <a key={n[0]} href={"#/business"} onClick={lambda e: MouseEvent { e.preventDefault(); scroll_to(n[0]); }}
                            className="flex items-center justify-between rounded-lg px-3 py-2 text-sm text-slate-300 hover:bg-white/5 hover:text-white">
                            <span>{n[1]}</span>
                            {if n[0] == "actions" and pending > 0 { <span className="rounded-full bg-amber px-2 text-[11px] font-bold text-ink">{str(pending)}</span> }}
                        </a>
                    }}
                </nav>
                <div className="flex-1"></div>
                <button type="button" onClick={do_sign_out} className="rounded-lg border border-white/10 px-3 py-2 text-left text-sm text-slate-400 hover:border-white/30 hover:text-white">Sign out</button>
            </div>
        </aside>

        <main className="min-w-0 px-4 pb-20 pt-8 sm:px-8">
            <header id="overview" className="flex scroll-mt-24 flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
                <div>
                    <p className="text-sm font-semibold uppercase tracking-[0.16em] text-amber">Brand dashboard</p>
                    <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">{session.brand}</h1>
                    <p className="mt-1 text-sm text-slate-400 lg:hidden">{session.email} · <button type="button" onClick={do_sign_out} className="underline">Sign out</button></p>
                </div>
                <button type="button" onClick={lambda { load(True); }} disabled={busy}
                    className="self-start rounded-full bg-amber px-5 py-2.5 text-sm font-semibold text-ink hover:bg-amber-soft disabled:opacity-60 sm:self-auto">
                    {"MarketIntelAgent analysing…" if busy else "↻ Re-run MarketIntelAgent"}
                </button>
            </header>
            {if error != "" { <p role="alert" className="mt-4 text-danger">{error}</p> }}

            {if intel is None {
                <p className="agent-pulse mt-10 text-amber">MarketIntelAgent is walking your supply chain…</p>
            } else {
                <div className={"mt-8 flex flex-col gap-6 " + ("opacity-60" if busy else "")}>
                    <p className="rounded-2xl border border-amber/30 bg-amber/5 p-5 leading-7 text-slate-200">{intel.summary}</p>
                    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
                        <Kpi label="Failing verification" value={str(intel.share_lost_pct) + "%"} hint={str(intel.flagged) + " of " + str(intel.total_scans) + " scans"} tone="text-danger" />
                        <Kpi label="Est. monthly leakage" value={fmt_kes(intel.est_loss_kes)} hint="flagged scans × 40 packs × avg price" tone="text-amber" />
                        <Kpi label="Genuine scans" value={str(intel.genuine)} hint="shoppers who verified you" tone="text-teal" />
                        <Kpi label="Awaiting approval" value={str(pending)} hint="proposed by MarketIntelAgent" />
                    </div>
                    <div className="grid gap-6 xl:grid-cols-[1fr_1fr]">
                        <HotspotMap regions={intel.regions} />
                        <RegionTable regions={intel.regions} />
                    </div>
                    <div className="grid gap-6 xl:grid-cols-[1.3fr_1fr]">
                        <section id="actions" className="scroll-mt-24 rounded-2xl border border-white/10 bg-surface p-5">
                            <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Action queue</h3>
                            <p className="mt-1 text-sm text-slate-400">Nothing runs until you approve. Every decision is logged on your brand's graph.</p>
                            <div className="mt-4 flex flex-col gap-3">
                                {for a in intel.actions {
                                    <ActionCard key={a.id} a={a} onDecide={lambda aid: str, d: str { decide(aid, d); }} />
                                }}
                            </div>
                        </section>
                        <div className="flex flex-col gap-6">
                            <div id="agents" className="scroll-mt-24">
                                <AgentTrace steps={intel.steps} note={intel.ai_note} busy={busy} />
                            </div>
                            <section id="api" className="scroll-mt-24 rounded-2xl border border-white/10 bg-surface p-5">
                                <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">API &amp; integrations</h3>
                                <p className="mt-1 text-sm text-slate-400">Every iTrace walker is a REST endpoint. Push batches from your ERP and scans from your POS.</p>
                                <pre className="mt-3 overflow-x-auto rounded-lg bg-ink-deep p-3 text-[11px] leading-5 text-slate-300">{API_SNIPPET}</pre>
                            </section>
                        </div>
                    </div>
                </div>
            }}
        </main>
    </div>;
}
