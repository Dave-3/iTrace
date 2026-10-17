import from ..lib.aiSettings { load_ai, save_ai }

glob DEFAULT_MODEL: str = "gemini/gemini-2.5-flash";

glob SAFETY: list[list[str]] = [
    ["Stays in this browser", "Saved in your browser's local storage on this device only. iTrace has no database table of keys."],
    ["Used only for your own checks", "Sent along with your own agent requests, used for that one LLM call, then discarded. Never logged or stored on the server."],
    ["You stay in control", "Remove it any time with \"Use rule engine only\". A free-tier key with a spending limit is all you need."]
];

"""Modal where a user brings their own LLM key (Gemini free tier works)."""
def:pub SettingsPanel(onClose: Callable[[], None]) -> JsxElement {
    has key: str = load_ai().key,
        model: str = load_ai().model,
        show_key: bool = False,
        saved: bool = False;

    def change_key(e: ChangeEvent) { key = e.target.value; saved = False; }
    def change_model(e: ChangeEvent) { model = e.target.value; saved = False; }
    def handle_save(e: MouseEvent) {
        save_ai(key.strip(), model.strip() or DEFAULT_MODEL);
        saved = True;
    }
    def handle_clear(e: MouseEvent) {
        save_ai("", DEFAULT_MODEL);
        key = "";
        model = DEFAULT_MODEL;
        saved = True;
    }
    def handle_close(e: MouseEvent) { onClose(); }

    return <div className="fixed inset-0 z-50 overflow-y-auto bg-black/75 backdrop-blur-sm" role="dialog" aria-modal="true" aria-labelledby="ai-title">
        <div className="flex min-h-full items-center justify-center px-4 py-10">
            <div className="w-full max-w-xl rounded-2xl border border-white/10 bg-surface text-white shadow-2xl">
                <div className="flex items-start justify-between gap-4 border-b border-white/10 p-6">
                    <div>
                        <p className="text-xs font-semibold uppercase tracking-[0.16em] text-amber">Optional</p>
                        <h2 id="ai-title" className="mt-1 font-display text-2xl font-bold">Turn on AI reasoning</h2>
                        <p className="mt-1 text-sm leading-6 text-slate-400">iTrace works without a key - a rule engine answers. Add your own key and the agents reason over the evidence with an LLM, step by step.</p>
                    </div>
                    <button type="button" onClick={handle_close} aria-label="Close" className="-mr-2 -mt-1 rounded-full px-3 py-1 text-2xl leading-none text-slate-400 hover:bg-white/5 hover:text-white">×</button>
                </div>

                <div className="flex flex-col gap-5 p-6">
                    <div className="grid gap-3 sm:grid-cols-3">
                        {for s in SAFETY {
                            <div key={s[0]} className="rounded-xl border border-teal/25 bg-teal/5 p-3">
                                <p className="flex items-center gap-1.5 text-sm font-semibold text-teal"><span aria-hidden="true">🔒</span>{s[0]}</p>
                                <p className="mt-1.5 text-xs leading-5 text-slate-400">{s[1]}</p>
                            </div>
                        }}
                    </div>

                    <div>
                        <div className="flex items-baseline justify-between gap-3">
                            <label htmlFor="ai-key" className="text-sm font-semibold">Your API key</label>
                            <a href="https://aistudio.google.com/app/apikey" target="_blank" rel="noreferrer" className="text-xs text-amber hover:underline">Get a free Gemini key ↗</a>
                        </div>
                        <div className="mt-2 flex gap-2">
                            <input id="ai-key" type={"text" if show_key else "password"} value={key} onChange={change_key} autoComplete="off" spellCheck={False}
                                placeholder="Paste your key, e.g. AIza…"
                                className="h-12 min-w-0 flex-1 rounded-lg border border-white/15 bg-ink-deep px-3 font-mono text-sm text-white placeholder:text-slate-500 focus:border-amber focus:outline-none" />
                            <button type="button" onClick={lambda { show_key = not show_key; }} className="h-12 shrink-0 rounded-lg border border-white/15 px-3 text-xs text-slate-300 hover:border-white/40">{"Hide" if show_key else "Show"}</button>
                        </div>
                    </div>

                    <div>
                        <label htmlFor="ai-model" className="text-sm font-semibold">Model</label>
                        <input id="ai-model" value={model} onChange={change_model} spellCheck={False}
                            className="mt-2 h-12 w-full rounded-lg border border-white/15 bg-ink-deep px-3 font-mono text-sm text-white focus:border-amber focus:outline-none" />
                        <p className="mt-2 text-xs leading-5 text-slate-500">Default: gemini/gemini-2.5-flash (free tier). Any LiteLLM model id works, e.g. gpt-4o-mini or claude-sonnet-4-6 with a matching key.</p>
                    </div>

                    <div className="flex flex-wrap items-center gap-3 border-t border-white/10 pt-5">
                        <button type="button" onClick={handle_save} disabled={key.strip() == ""} className="h-11 rounded-full bg-amber px-6 font-semibold text-ink hover:bg-amber-soft disabled:opacity-50">Save key</button>
                        <button type="button" onClick={handle_clear} className="h-11 rounded-full border border-white/15 px-5 text-sm text-slate-300 hover:border-white/40">Use rule engine only</button>
                        {if saved {
                            <span role="status" className="text-sm text-teal">{"Saved - AI reasoning is on." if key.strip() != "" else "Key removed - rule engine on."}</span>
                        }}
                    </div>
                </div>
            </div>
        </div>
    </div>;
}
