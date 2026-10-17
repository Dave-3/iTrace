sv import from ..services.agents { sign_up, sign_in, list_brands, Session }
import from ..lib.session { save_token }

glob DEMO_EMAIL: str = "demo@nyota-beverages.co.ke";
glob DEMO_PASSWORD: str = "itrace-demo-2026";

"""Sign in / create a brand workspace."""
def:pub BusinessAuth(onAuthed: Callable[[Session], None]) -> JsxElement {
    has mode: str = "signin",
        email_input: str = "",
        password_input: str = "",
        brand_input: str = "",
        brands: list[str] = [],
        busy: bool = False,
        error: str = "";

    async can with entry {
        brands = await list_brands();
        if len(brands) > 0 {
            brand_input = brands[0];
        }
    }

    def finish(s: Session) {
        if s.ok {
            save_token(s.token);
            onAuthed(s);
        } else {
            error = s.error;
        }
    }

    async def submit_form() {
        busy = True;
        error = "";
        email = email_input;
        password = password_input;
        brand_name = brand_input;
        res: Session | None = None;
        try {
            if mode == "signup" {
                res = await sign_up(email, password, brand_name);
            } else {
                res = await sign_in(email, password);
            }
            if res is not None { finish(res); }
        } except Exception {
            error = "Could not reach iTrace. Is the server running?";
        }
        busy = False;
    }

    async def use_demo() {
        busy = True;
        error = "";
        email = DEMO_EMAIL;
        password = DEMO_PASSWORD;
        brand_name = "Nyota Beverages";
        res: Session | None = None;
        try {
            res = await sign_in(email, password);
            if res is not None and not res.ok {
                res = await sign_up(email, password, brand_name);
            }
            if res is not None { finish(res); }
        } except Exception {
            error = "Could not reach iTrace. Is the server running?";
        }
        busy = False;
    }

    def on_submit(e: FormEvent) { e.preventDefault(); submit_form(); }
    def tab_class(m: str) -> str {
        return "flex-1 rounded-full py-2 text-sm font-semibold transition-colors " + ("bg-amber text-ink" if mode == m else "text-slate-300 hover:text-white");
    }
    field = "mt-1.5 h-11 w-full rounded-lg border border-white/15 bg-ink-deep px-3 text-white placeholder:text-slate-500 focus:border-amber focus:outline-none";

    return <main className="grid min-h-[calc(100svh-57px)] lg:grid-cols-2">
        <section className="relative hidden overflow-hidden border-r border-white/5 bg-ink-deep p-12 lg:flex lg:flex-col lg:justify-between">
            <div>
                <p className="text-sm font-semibold uppercase tracking-[0.16em] text-amber">iTrace for brands</p>
                <h1 className="mt-4 font-display text-5xl font-extrabold leading-[1.02] tracking-tight">Know where fakes<br />eat your market.</h1>
                <p className="mt-5 max-w-md text-lg leading-8 text-slate-400">Every shopper scan in Kenya flows into your dashboard. MarketIntelAgent maps the hotspots, prices the leak and drafts the fix - you approve.</p>
            </div>
            <ul className="flex flex-col gap-4 text-slate-300">
                {for item in ["Counterfeit heat map by region", "Estimated monthly leakage in KES", "Agent-proposed audits, alerts & promotions", "REST API for your ERP and POS"] {
                    <li key={item} className="flex items-center gap-3"><span className="flex size-6 items-center justify-center rounded-full bg-teal/15 text-xs text-teal">✓</span>{item}</li>
                }}
            </ul>
        </section>
        <section className="flex items-center justify-center px-4 py-12">
            <div className="w-full max-w-md">
                <h2 className="font-display text-3xl font-extrabold">{"Welcome back" if mode == "signin" else "Create your brand workspace"}</h2>
                <p className="mt-2 text-sm text-slate-400">{"Sign in to your brand dashboard." if mode == "signin" else "Free while in pilot. One workspace per brand."}</p>
                <div className="mt-6 flex rounded-full border border-white/10 bg-surface p-1" role="tablist">
                    <button type="button" role="tab" onClick={lambda { mode = "signin"; error = ""; }} className={tab_class("signin")}>Sign in</button>
                    <button type="button" role="tab" onClick={lambda { mode = "signup"; error = ""; }} className={tab_class("signup")}>Create account</button>
                </div>
                <form onSubmit={on_submit} className="mt-6 flex flex-col gap-4">
                    <div>
                        <label htmlFor="biz-email" className="text-sm font-semibold">Work email</label>
                        <input id="biz-email" type="email" autoComplete="email" value={email_input} onChange={lambda e: ChangeEvent { email_input = e.target.value; }} placeholder="you@yourbrand.co.ke" className={field} />
                    </div>
                    <div>
                        <label htmlFor="biz-password" className="text-sm font-semibold">Password</label>
                        <input id="biz-password" type="password" autoComplete={"current-password" if mode == "signin" else "new-password"} value={password_input} onChange={lambda e: ChangeEvent { password_input = e.target.value; }} placeholder="At least 8 characters" className={field} />
                    </div>
                    {if mode == "signup" {
                        <div>
                            <label htmlFor="biz-brand" className="text-sm font-semibold">Brand you manage</label>
                            <input id="biz-brand" list="brand-list" value={brand_input} onChange={lambda e: ChangeEvent { brand_input = e.target.value; }} placeholder="Pick a brand or type a new one" className={field} />
                            <datalist id="brand-list">
                                {for b in brands { <option key={b} value={b}></option> }}
                            </datalist>
                        </div>
                    }}
                    {if error != "" { <p role="alert" className="rounded-lg border border-danger/40 bg-danger/10 px-3 py-2 text-sm text-danger">{error}</p> }}
                    <button type="submit" disabled={busy} className="h-12 rounded-full bg-amber font-semibold text-ink hover:bg-amber-soft disabled:opacity-60">
                        {"Please wait…" if busy else ("Sign in" if mode == "signin" else "Create workspace")}
                    </button>
                </form>
                <div className="my-6 flex items-center gap-3 text-xs text-slate-500"><span className="h-px flex-1 bg-white/10"></span>or<span className="h-px flex-1 bg-white/10"></span></div>
                <button type="button" onClick={use_demo} disabled={busy} className="h-12 w-full rounded-full border border-white/15 text-sm font-semibold text-white hover:border-amber hover:text-amber disabled:opacity-60">Explore the demo workspace (Nyota Beverages)</button>
                <p className="mt-6 text-xs leading-5 text-slate-500">Passwords are salted and hashed (PBKDF2-SHA256). Shoppers never need an account - only brand managers do.</p>
            </div>
        </section>
    </main>;
}
