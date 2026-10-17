"""Brand-manager session token, kept in this browser only."""

glob _SESSION_KEY: str = "itrace.session";

def:pub load_token() -> str {
    try {
        t = localStorage.getItem(_SESSION_KEY);
        return (t or "") as str;
    } except Exception {
        return "";
    }
    return "";
}

def:pub save_token(tok: str) {
    try {
        if tok == "" {
            localStorage.removeItem(_SESSION_KEY);
        } else {
            localStorage.setItem(_SESSION_KEY, tok);
        }
    } except Exception {
        console.warn("iTrace: could not store session");
    }
}
