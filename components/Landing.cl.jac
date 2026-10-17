import from .ParticleField { ParticleField }

glob STATS: list[list[str]] = [
    ["1 in 5", "products on the Kenyan market is counterfeit"],
    ["KSh 153bn", "in tax lost to illicit trade every year"],
    ["44,000", "jobs lost every year"]
];

glob AGENTS: list[list[str]] = [
    ["VerifyAgent", "Walks the brand registry and every past scan of a code. Catches cloned codes (same code, two towns, minutes apart), recalled batches and crowd-reported fakes.", "For shoppers"],
    ["ChannelAgent", "Routes you to the right official check - KEBS 20023, KEPHIS 1393, PPB, KRA Soma Label - and pre-writes the SMS. Facts come from verified tools, never from the model's memory.", "For shoppers"],
    ["MarketIntelAgent", "Maps where fakes are eating a brand's market, estimates the shillings leaking away, and proposes audits, alerts and promotions. Nothing runs until a human approves.", "For brands"]
];

glob CHANNELS: list[str] = ["KEBS · 20023", "KEPHIS · 1393", "PPB register", "KRA Soma Label", "ACA · 1545"];

"""The prototype's amber arrow disc."""
def:pub GoDisc(href: str, label: str) -> JsxElement {
    return <a href={"#" + href} aria-label={label}
        className="group relative inline-flex size-16 shrink-0 items-center justify-center rounded-full bg-amber text-ink transition-transform duration-300 hover:scale-105 sm:size-24">
        <span className="absolute right-full top-1/2 mr-2 hidden h-0.5 w-16 bg-white sm:block"></span>
        <span className="text-2xl font-bold sm:text-4xl">→</span>
    </a>;
}

def:pub Landing() -> JsxElement {
    return <main>
        <section className="relative h-[calc(100svh-57px)] min-h-[560px] overflow-hidden">
            <ParticleField />
            <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-transparent via-transparent to-ink"></div>
            <div className="relative mx-auto flex h-full max-w-7xl flex-col justify-center gap-10 px-4 sm:px-8">
                <div className="flex items-center gap-5 sm:ml-[18%]">
                    <h1 className="font-display font-extrabold leading-[0.9] tracking-tight">
                        <span className="block text-xl sm:text-3xl">check</span>
                        <span className="block text-5xl sm:text-8xl">authenticity</span>
                    </h1>
                    <GoDisc href="/verify" label="Check a product" />
                </div>
                <div className="flex items-center gap-5 sm:ml-[6%]">
                    <h2 className="font-display font-extrabold leading-[0.9] tracking-tight">
                        <span className="block text-xl sm:text-3xl">business</span>
                        <span className="block text-5xl sm:text-8xl">solutions</span>
                    </h2>
                    <GoDisc href="/business" label="Open the business dashboard" />
                </div>
            </div>
        </section>

        <section className="mx-auto max-w-7xl px-4 py-24 sm:px-8">
            <p className="text-sm font-semibold uppercase tracking-[0.16em] text-amber">The problem</p>
            <p className="mt-4 font-display text-6xl font-extrabold tracking-tight sm:text-8xl lg:text-9xl">KSh 800,000,000,000</p>
            <p className="mt-4 max-w-3xl text-xl leading-8 text-slate-300">Illicit trade costs Kenya roughly KSh 800 billion a year - about 9% of GDP. Shoppers can't tell what's real. Brands can't see where they're losing.</p>
            <p className="mt-2 text-xs text-slate-500">Source: Anti-Counterfeit Authority, KEPSA forum on illicit trade, May 2026.</p>
            <div className="mt-12 grid gap-4 sm:grid-cols-3">
                {for s in STATS {
                    <div key={s[0]} className="rounded-2xl border border-white/10 bg-surface p-6">
                        <p className="font-display text-4xl font-extrabold text-amber">{s[0]}</p>
                        <p className="mt-2 text-slate-400">{s[1]}</p>
                    </div>
                }}
            </div>
        </section>

        <section className="border-y border-white/5 bg-ink-deep">
            <div className="mx-auto max-w-7xl px-4 py-24 sm:px-8">
                <p className="text-sm font-semibold uppercase tracking-[0.16em] text-amber">How iTrace works</p>
                <h2 className="mt-4 max-w-3xl font-display text-4xl font-extrabold leading-tight sm:text-5xl">One trust graph. Three agents walking it.</h2>
                <p className="mt-4 max-w-3xl text-slate-400">Every brand, batch, unit code, scan, region and report is a node in a Jac graph. Agents are walkers that traverse it, then reason over the evidence with an LLM. Every scan makes the network smarter - even for brands that haven't joined yet.</p>
                <div className="mt-12 grid gap-4 lg:grid-cols-3">
                    {for (i, a) in enumerate(AGENTS) {
                        <div key={a[0]} className="flex flex-col gap-4 rounded-2xl border border-white/10 bg-surface p-6">
                            <div className="flex items-center justify-between">
                                <span className="flex size-10 items-center justify-center rounded-full bg-amber font-display font-extrabold text-ink">{str(i + 1)}</span>
                                <span className="text-xs uppercase tracking-[0.14em] text-slate-500">{a[2]}</span>
                            </div>
                            <h3 className="font-display text-2xl font-bold">{a[0]}</h3>
                            <p className="leading-7 text-slate-400">{a[1]}</p>
                        </div>
                    }}
                </div>
            </div>
        </section>

        <section className="mx-auto grid max-w-7xl gap-6 px-4 py-24 sm:px-8 lg:grid-cols-2">
            <div className="rounded-2xl border border-white/10 bg-surface p-8">
                <p className="text-sm font-semibold uppercase tracking-[0.16em] text-teal">For shoppers</p>
                <h3 className="mt-3 font-display text-3xl font-extrabold">Is it real? What's in it?</h3>
                <p className="mt-3 leading-7 text-slate-400">Type or scan the code. Get a verdict with the evidence behind it, the nutrition facts the brand registered, and a one-tap SMS to the right regulator.</p>
                <a href="#/verify" className="mt-6 inline-block rounded-full bg-amber px-6 py-3 font-semibold text-ink hover:bg-amber-soft">Check a product</a>
            </div>
            <div className="rounded-2xl border border-white/10 bg-surface p-8">
                <p className="text-sm font-semibold uppercase tracking-[0.16em] text-amber">For brands</p>
                <h3 className="mt-3 font-display text-3xl font-extrabold">Find the leak. Approve the fix.</h3>
                <p className="mt-3 leading-7 text-slate-400">See counterfeit hotspots by region, the shillings at stake, and agent-proposed actions. Connect your ERP and POS through the REST API in minutes.</p>
                <a href="#/business" className="mt-6 inline-block rounded-full border border-amber px-6 py-3 font-semibold text-amber hover:bg-amber hover:text-ink">Open the dashboard</a>
            </div>
        </section>

        <section className="mx-auto max-w-7xl px-4 pb-24 sm:px-8">
            <p className="text-center text-xs uppercase tracking-[0.16em] text-slate-500">Routes shoppers to official Kenyan channels</p>
            <div className="mt-5 flex flex-wrap justify-center gap-3">
                {for c in CHANNELS {
                    <span key={c} className="rounded-full border border-white/10 px-4 py-2 text-sm text-slate-300">{c}</span>
                }}
            </div>
            <div className="mt-16 rounded-3xl border border-white/10 bg-surface p-10 text-center">
                <p className="font-display text-sm uppercase tracking-[0.16em] text-slate-400">Where this goes next</p>
                <p className="mx-auto mt-4 max-w-3xl font-display text-2xl font-bold leading-snug sm:text-3xl">Every verified scan carries what's inside the pack. Aggregated, that becomes Kenya's first map of what people actually eat - data for the fight against lifestyle diseases, which now cause over 40% of deaths.</p>
            </div>
        </section>
    </main>;
}
