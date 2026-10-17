"""iTrace - agentic product trust for Kenya. Server endpoints + client entry."""

import from services.agents {
    verify_product, report_product, list_regions, list_brands,
    market_intel, decide_action, register_batch, ingest_scan,
    sign_up, sign_in, whoami, sign_out
}

import ".styles.global.css";
import from .components.AppShell { AppShell }

def:pub app() -> JsxElement {
    return <AppShell />;
}
