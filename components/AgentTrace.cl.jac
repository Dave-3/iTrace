sv import from ..services.agents { AgentStep }

glob _AGENT_COLORS: dict[str, str] = {
    "VerifyAgent": "bg-amber text-ink",
    "ChannelAgent": "bg-teal text-ink",
    "MarketIntelAgent": "bg-amber text-ink",
    "RegistryWalker": "bg-sage text-ink",
    "CrowdWalker": "bg-sage text-ink",
    "SupplyWalker": "bg-sage text-ink"
};

"""Live timeline of what each agent and walker did - the agentic reasoning, made visible."""
def:pub AgentTrace(steps: list[AgentStep], note: str = "", busy: bool = False) -> JsxElement {
    return <div className="rounded-2xl border border-white/10 bg-surface p-5">
        <div className="mb-4 flex items-center justify-between gap-3">
            <h3 className="font-display text-sm font-bold uppercase tracking-[0.14em] text-white">Agent trace</h3>
            {if busy {
                <span className="agent-pulse text-xs text-amber">agents working…</span>
            }}
        </div>
        <ol className="relative flex flex-col gap-3 border-l border-white/10 pl-5">
            {for (i, s) in enumerate(steps) {
                <li key={str(i)} className="relative">
                    <span className="absolute -left-[27px] top-1 size-3 rounded-full border-2 border-ink bg-amber"></span>
                    <div className="flex flex-wrap items-center gap-2">
                        <span className={"rounded px-1.5 py-0.5 text-[10px] font-bold uppercase tracking-wide " + (_AGENT_COLORS[s.agent] or "bg-white/20 text-white")}>{s.agent}</span>
                        <code className="text-xs text-slate-300">{s.action}</code>
                    </div>
                    <p className="mt-1 text-sm leading-6 text-slate-400">{s.result}</p>
                </li>
            }}
        </ol>
        {if note != "" {
            <p className="mt-4 border-t border-white/10 pt-3 text-xs text-slate-400">{note}</p>
        }}
    </div>;
}
