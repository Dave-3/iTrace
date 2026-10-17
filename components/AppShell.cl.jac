import from react { useEffect }
import from ..lib.aiSettings { load_ai }
import from .SettingsPanel { SettingsPanel }
import from .Landing { Landing }
import from .VerifyPage { VerifyPage }
import from .BusinessPage { BusinessPage }

"""Hash routes (#/verify) work on any static host and survive refresh."""
def current_route() -> str {
    h: str = window.location.hash or "";  # jac:ignore[E1030]
    return h[1:] if h.startswith("#/") else "/";
}

def:pub NavBar(path: str) -> JsxElement {
    has show_settings: bool = False,
        ai_on: bool = load_ai().key != "";

    useEffect(lambda {
        handler = lambda(e: any) { ai_on = load_ai().key != ""; };
        window.addEventListener("itrace-ai-change", handler);
        return lambda { window.removeEventListener("itrace-ai-change", handler); };
    }, []);

    def link_class(target: str) -> str {
        base = "rounded-full px-3 py-1.5 text-sm transition-colors ";
        return base + ("bg-white/10 text-white" if path == target else "text-slate-300 hover:text-white");
    }

    return <header className="sticky top-0 z-40 border-b border-white/5 bg-ink/85 backdrop-blur">
        <nav className="mx-auto flex w-full max-w-7xl items-center justify-between gap-3 px-4 py-3 sm:px-8" aria-label="Main">
            <a href="#/" className="bracket font-display text-sm font-bold uppercase tracking-[0.18em] text-white">iTrace</a>
            <div className="flex items-center gap-1 sm:gap-2">
                <a href="#/verify" className={link_class("/verify")}>Verify</a>
                <a href="#/business" className={link_class("/business")}>Business</a>
                <button type="button" onClick={lambda { show_settings = True; }}
                    className={"ml-1 flex items-center gap-2 rounded-full border px-3 py-1.5 text-xs " + ("border-teal/60 text-teal" if ai_on else "border-white/15 text-slate-300 hover:border-white/40")}>
                    <span className={"size-2 rounded-full " + ("bg-teal" if ai_on else "bg-slate-500")}></span>
                    {"AI on" if ai_on else "AI off"}
                </button>
            </div>
        </nav>
        {if show_settings {
            <SettingsPanel onClose={lambda { show_settings = False; }} />
        }}
    </header>;
}

def:pub AppShell() -> JsxElement {
    has route: str = current_route();

    useEffect(lambda {
        handler = lambda(e: any) { route = current_route(); window.scrollTo(0, 0); };
        window.addEventListener("hashchange", handler);
        return lambda { window.removeEventListener("hashchange", handler); };
    }, []);

    return <div className="min-h-screen bg-ink text-white">
        <NavBar path={route} />
        {if route == "/verify" {
            <VerifyPage />
        } elif route == "/business" {
            <BusinessPage />
        } else {
            <Landing />
        }}
        <footer className="border-t border-white/10 px-4 py-8 text-center text-xs text-slate-500">
            iTrace · built with Jac &amp; Jaseci for JacHacks Kenya 2026 · Demo brands are fictional · A code match is a signal, not a guarantee of authenticity
        </footer>
    </div>;
}
