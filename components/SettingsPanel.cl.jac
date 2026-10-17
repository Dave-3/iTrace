import from ..lib.aiSettings { load_ai, save_ai }

glob DEFAULT_MODEL: str = "gemini/gemini-2.5-flash";

"""Modal where a user brings their own LLM key (Gemini free tier works)."""
def:pub SettingsPanel(onClose: Callable[[], None]) -> JsxElement {
    has key: str = load_ai().key,
        model: str = load_ai().model,
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

    return <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 px-4" role="dialog" aria-modal="true" aria-label="AI settings">
        <div className="w-full max-w-lg rounded-2xl border border-white/10 bg-surface p-6 text-white shadow-2xl">
            <div className="flex items-start justify-between gap-4">
                <div>
                    <h2 className="font-display text-xl font-bold">AI reasoning</h2>
                    <p className="mt-1 text-sm text-slate-400">Bring your own key. Agents use it to reason over the evidence; without one, iTrace's rule engine answers.</p>
                </div>
                <button type="button" onClick={handle_close} aria-label="Close" className="rounded-full px-2 text-2xl leading-none text-slate-400 hover:text-white">×</button>
            </div>
            <label htmlFor="ai-key" className="mt-5 block text-sm font-semibold">API key</label>
            <input id="ai-key" type="password" value={key} onChange={change_key} placeholder="Paste a Gemini key from aistudio.google.com"
                className="mt-2 h-11 w-full rounded-lg border border-white/15 bg-ink-deep px-3 text-sm text-white placeholder:text-slate-500 focus:border-amber focus:outline-none" />
            <label htmlFor="ai-model" className="mt-4 block text-sm font-semibold">Model</label>
            <input id="ai-model" value={model} onChange={change_model}
                className="mt-2 h-11 w-full rounded-lg border border-white/15 bg-ink-deep px-3 font-mono text-sm text-white focus:border-amber focus:outline-none" />
            <p className="mt-2 text-xs text-slate-500">Any LiteLLM model id: gemini/gemini-2.5-flash, gpt-4o-mini, claude-sonnet-4-6… Your key is stored only in this browser.</p>
            <div className="mt-6 flex flex-wrap items-center gap-3">
                <button type="button" onClick={handle_save} className="h-11 rounded-full bg-amber px-6 font-semibold text-ink hover:bg-amber-soft">Save</button>
                <button type="button" onClick={handle_clear} className="h-11 rounded-full border border-white/15 px-5 text-sm text-slate-300 hover:border-white/40">Use rule engine only</button>
                {if saved {
                    <span role="status" className="text-sm text-teal">Saved.</span>
                }}
            </div>
        </div>
    </div>;
}
