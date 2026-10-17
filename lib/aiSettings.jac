"""Bring-your-own-key: the AI key lives only in this browser and rides along with each agent request."""

glob _STORE_KEY: str = "itrace.ai";
glob DEFAULT_MODEL: str = "gemini/gemini-2.5-flash";

obj AiSettings {
    has key: str = "",
        model: str = "gemini/gemini-2.5-flash";
}

def:pub load_ai() -> AiSettings {
    try {
        raw = localStorage.getItem(_STORE_KEY);
        if raw {
            data = JSON.parse(raw);
            k: str = (data["key"] or "") as str;
            m: str = (data["model"] or DEFAULT_MODEL) as str;
            return AiSettings(key=k, model=m);
        }
    } except Exception {
        return AiSettings(key="", model=DEFAULT_MODEL);
    }
    return AiSettings(key="", model=DEFAULT_MODEL);
}

def:pub save_ai(key: str, model: str) {
    try {
        localStorage.setItem(_STORE_KEY, JSON.stringify({"key": key, "model": model or DEFAULT_MODEL}));
        evt = new(CustomEvent, "itrace-ai-change", {"detail": {"on": key != ""}});  # jac:ignore[E1053]
        window.dispatchEvent(evt);  # jac:ignore[E1030]
    } except Exception {
        console.warn("iTrace: could not save AI settings");
    }
}
