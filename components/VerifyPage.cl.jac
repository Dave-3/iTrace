sv import from ..services.agents {
    verify_product, report_product, list_regions,
    VerifyResult, Channel, AgentStep
}
import from ..lib.aiSettings { load_ai }
import from .AgentTrace { AgentTrace }

glob DEMO_CODES: list[list[str]] = [
    ["ITR-UGALI-0001", "Maize flour"],
    ["ITR-MANGO-0003", "Mango nectar"],
    ["ITR-PARA-0105", "Paracetamol"],
    ["6161100420017", "Cooking oil"]
];

glob STATUS_STYLE: dict[str, str] = {
    "verified": "border-teal/50 bg-teal/10 text-teal",
    "suspicious": "border-gold/60 bg-gold/10 text-amber",
    "warning": "border-danger/60 bg-danger/10 text-danger",
    "unknown": "border-slate-500/60 bg-slate-500/10 text-slate-300"
};

glob STATUS_LABEL: dict[str, str] = {
    "verified": "Verified against records",
    "suspicious": "Suspicious - likely counterfeit",
    "warning": "Genuine but unsafe - recalled",
    "unknown": "Unknown - not enough evidence"
};

def sms_href(c: Channel) -> str {
    return "sms:" + c.shortcode + "?&body=" + encodeURIComponent(c.message);
}

def:pub ChannelCard(c: Channel) -> JsxElement {
    return <div className="flex flex-col gap-3 rounded-xl border border-white/10 bg-ink-deep p-4">
        <div className="flex items-start justify-between gap-3">
            <p className="font-semibold text-white">{c.name}</p>
            {if c.cost != "" { <span className="shrink-0 rounded-full bg-white/5 px-2 py-0.5 text-[11px] text-slate-400">{c.cost}</span> }}
        </div>
        <p className="text-sm leading-6 text-slate-400">{c.how}</p>
        <div className="flex flex-wrap gap-2">
            {if c.message != "" and c.shortcode != "" {
                <a href={sms_href(c)} className="rounded-full bg-amber px-4 py-2 text-sm font-semibold text-ink hover:bg-amber-soft">
                    {"SMS " + c.message + " to " + c.shortcode}
                </a>
            } elif c.shortcode != "" {
                <a href={"tel:" + c.shortcode} className="rounded-full border border-white/20 px-4 py-2 text-sm text-white hover:border-amber">{"Call " + c.shortcode}</a>
            }}
            {if c.link != "" {
                <a href={c.link} target="_blank" rel="noreferrer" className="rounded-full border border-white/20 px-4 py-2 text-sm text-white hover:border-amber">Open ↗</a>
            }}
        </div>
    </div>;
}

def:pub VerdictCard(r: VerifyResult) -> JsxElement {
    style = STATUS_STYLE[r.status] or STATUS_STYLE["unknown"];
    reg = r.registry;
    return <div className="rounded-2xl border border-white/10 bg-surface p-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
            <span className={"rounded-full border px-3 py-1 text-sm font-semibold " + style}>{STATUS_LABEL[r.status] or r.status}</span>
            <code className="text-xs text-slate-400">{r.code}</code>
        </div>
        <h2 className="mt-4 font-display text-2xl font-bold leading-tight sm:text-3xl">{r.headline}</h2>
        <div className="mt-4 flex items-center gap-3">
            <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-white/10">
                <div className="h-full rounded-full bg-amber" style={{"width": str(r.confidence) + "%"}}></div>
            </div>
            <span className="text-xs text-slate-400">{str(r.confidence) + "% confidence"}</span>
        </div>
        <p className="mt-4 leading-7 text-slate-300">{r.explanation}</p>

        {if reg.found {
            <div className="mt-5 grid gap-3 rounded-xl bg-ink-deep p-4 text-sm sm:grid-cols-2">
                <div><p className="text-xs text-slate-500">Product</p><p className="text-white">{reg.product}</p></div>
                <div><p className="text-xs text-slate-500">Brand</p><p className="text-white">{reg.brand}</p></div>
                <div><p className="text-xs text-slate-500">Batch</p><p className="text-white">{reg.batch_no + " · " + reg.plant}</p></div>
                <div><p className="text-xs text-slate-500">Expires</p><p className="text-white">{reg.expires_on}</p></div>
            </div>
        }}

        {if reg.found and reg.kcal_per_100 > 0 {
            <div className="mt-4 rounded-xl border border-teal/30 bg-teal/5 p-4">
                <p className="text-xs font-bold uppercase tracking-[0.14em] text-teal">What's inside · per 100g/ml</p>
                <div className="mt-3 grid grid-cols-3 gap-3 text-center">
                    <div><p className="font-display text-2xl font-bold">{str(reg.kcal_per_100)}</p><p className="text-xs text-slate-400">kcal</p></div>
                    <div><p className="font-display text-2xl font-bold">{str(reg.sugar_g) + "g"}</p><p className="text-xs text-slate-400">sugar</p></div>
                    <div><p className="font-display text-2xl font-bold">{str(reg.salt_g) + "g"}</p><p className="text-xs text-slate-400">salt</p></div>
                </div>
            </div>
        }}

        <h3 className="mt-6 text-sm font-semibold text-white">Evidence</h3>
        <ul className="mt-2 flex flex-col gap-2">
            {for (i, item) in enumerate(r.evidence) {
                <li key={str(i)} className="flex gap-3 text-sm leading-6 text-slate-300">
                    <span className="mt-2.5 size-1.5 shrink-0 rounded-full bg-amber"></span><span>{item}</span>
                </li>
            }}
        </ul>
        <h3 className="mt-5 text-sm font-semibold text-white">What to do now</h3>
        <ol className="mt-2 flex flex-col gap-2">
            {for (i, item) in enumerate(r.next_steps) {
                <li key={str(i)} className="flex gap-3 text-sm leading-6 text-slate-300">
                    <span className="flex size-5 shrink-0 items-center justify-center rounded-full bg-white/10 text-[11px]">{str(i + 1)}</span><span>{item}</span>
                </li>
            }}
        </ol>
    </div>;
}

def:pub VerifyPage() -> JsxElement {
    has code_input: str = "",
        region: str = "Nairobi CBD",
        note_input: str = "",
        regions: list[str] = [],
        result: VerifyResult | None = None,
        busy: bool = False,
        error: str = "",
        report_text: str = "",
        report_msg: str = "";

    async can with entry {
        regions = await list_regions();
    }

    async def run_check(target: str) {
        code_input = target;
        code = target;
        note = note_input;
        if code.strip() == "" {
            error = "Enter the code printed on the pack.";
            return;
        }
        busy = True;
        error = "";
        report_msg = "";
        ai = load_ai();
        api_key = ai.key;
        model = ai.model;
        try {
            result = await verify_product(code, region, note, api_key, model);
        } except Exception as e {
            error = "Could not reach the agents. Is the server running?";
        }
        busy = False;
    }

    async def send_report() {
        if result is None { return; }
        code = result.code;
        note = report_text;
        report_msg = await report_product(code, region, note);
        report_text = "";
    }

    def change_code(e: ChangeEvent) { code_input = e.target.value; }
    def change_note(e: ChangeEvent) { note_input = e.target.value; }
    def change_region(e: ChangeEvent) { region = e.target.value; }
    def change_report(e: ChangeEvent) { report_text = e.target.value; }
    def submit(e: FormEvent) { e.preventDefault(); run_check(code_input); }

    return <main className="mx-auto w-full max-w-7xl px-4 pb-20 pt-10 sm:px-8">
        <section className="grid gap-8 lg:grid-cols-[1fr_1fr] lg:items-end">
            <div>
                <p className="text-sm font-semibold uppercase tracking-[0.16em] text-amber">Check authenticity</p>
                <h1 className="mt-3 font-display text-4xl font-extrabold leading-[0.95] tracking-tight sm:text-6xl">Is it real?<br /><span className="text-slate-400">Ask the agents.</span></h1>
                <p className="mt-4 max-w-xl text-slate-400">Three agents walk the iTrace graph - the brand's registry, every past scan in Kenya, shopper reports - then point you to the right official check.</p>
            </div>
            <form onSubmit={submit} className="rounded-2xl border border-white/10 bg-surface p-5">
                <label htmlFor="code" className="text-sm font-semibold">Product code</label>
                <div className="mt-2 flex flex-col gap-2 sm:flex-row">
                    <input id="code" value={code_input} onChange={change_code} placeholder="e.g. ITR-MANGO-0003 or a barcode" autoComplete="off"
                        className="h-12 flex-1 rounded-lg border border-white/15 bg-ink-deep px-3 font-mono text-white placeholder:text-slate-500 focus:border-amber focus:outline-none" />
                    <button type="submit" disabled={busy} className="h-12 shrink-0 rounded-full bg-amber px-7 font-semibold text-ink hover:bg-amber-soft disabled:opacity-60">{"Checking…" if busy else "Check"}</button>
                </div>
                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                    <div>
                        <label htmlFor="region" className="text-xs text-slate-400">Where are you?</label>
                        <select id="region" value={region} onChange={change_region} className="mt-1 h-10 w-full rounded-lg border border-white/15 bg-ink-deep px-2 text-sm text-white">
                            {for r in regions { <option key={r} value={r}>{r}</option> }}
                        </select>
                    </div>
                    <div>
                        <label htmlFor="note" className="text-xs text-slate-400">Anything odd? (optional)</label>
                        <input id="note" value={note_input} onChange={change_note} placeholder="Seal loose, blurry print…"
                            className="mt-1 h-10 w-full rounded-lg border border-white/15 bg-ink-deep px-3 text-sm text-white placeholder:text-slate-500" />
                    </div>
                </div>
                <div className="mt-4 flex flex-wrap items-center gap-2">
                    <span className="text-xs text-slate-500">Try:</span>
                    {for d in DEMO_CODES {
                        <button key={d[0]} type="button" onClick={lambda { run_check(d[0]); }}
                            className="rounded-full border border-white/15 px-3 py-1 text-xs text-slate-200 hover:border-amber hover:text-amber">{d[1]}</button>
                    }}
                </div>
                {if error != "" { <p role="alert" className="mt-3 text-sm text-danger">{error}</p> }}
            </form>
        </section>

        {if busy and result is None {
            <section className="mt-10 rounded-2xl border border-white/10 bg-surface p-8 text-center">
                <p className="agent-pulse font-display text-lg font-bold text-amber">VerifyAgent is walking the graph…</p>
                <p className="mt-2 text-sm text-slate-400">registry → crowd scans → official channels</p>
            </section>
        }}

        {if result is not None {
            <section className={"mt-10 grid gap-6 lg:grid-cols-[1.25fr_1fr] " + ("opacity-60" if busy else "")}>
                <div className="flex flex-col gap-6">
                    <VerdictCard r={result} />
                    <div className="rounded-2xl border border-white/10 bg-surface p-6">
                        <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Confirm with an official channel</h3>
                        <p className="mt-1 text-sm text-slate-400">ChannelAgent picked these for a {result.category or "general"} product. One tap opens your SMS app, pre-filled.</p>
                        <div className="mt-4 grid gap-3 md:grid-cols-2">
                            {for c in result.channels { <ChannelCard key={c.name} c={c} /> }}
                        </div>
                    </div>
                </div>
                <div className="flex flex-col gap-6">
                    <AgentTrace steps={result.steps} note={result.ai_note} busy={busy} />
                    {if len(result.crowd.scans) > 0 {
                        <div className="rounded-2xl border border-white/10 bg-surface p-5">
                            <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Where this code has been scanned</h3>
                            <ul className="mt-3 flex flex-col gap-2">
                                {for (i, s) in enumerate(result.crowd.scans[-6:]) {
                                    <li key={str(i)} className="flex items-center justify-between gap-3 text-sm">
                                        <span className="text-slate-300">{s.region}</span>
                                        <span className="text-xs text-slate-500">{s.at.replace("T", " ")[:16]}</span>
                                    </li>
                                }}
                            </ul>
                        </div>
                    }}
                    <div className="rounded-2xl border border-white/10 bg-surface p-5">
                        <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em]">Report this product</h3>
                        <p className="mt-1 text-sm text-slate-400">Your report warns the next shopper who scans this code and alerts the brand.</p>
                        <textarea value={report_text} onChange={change_report} maxLength={1000} placeholder="What did you notice?"
                            className="mt-3 min-h-20 w-full rounded-lg border border-white/15 bg-ink-deep p-3 text-sm text-white placeholder:text-slate-500"></textarea>
                        <button type="button" onClick={send_report} className="mt-3 w-full rounded-full border border-amber px-4 py-2 text-sm font-semibold text-amber hover:bg-amber hover:text-ink">Send report</button>
                        {if report_msg != "" { <p role="status" className="mt-2 text-sm text-teal">{report_msg}</p> }}
                    </div>
                </div>
            </section>
        }}
    </main>;
}
