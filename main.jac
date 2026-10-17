import from services.scanwise { lookup_code, submit_report }
import from .components.ScanWise { ScanWise }
import ".styles.global.css";

def:pub app() -> JsxElement {
    return <ScanWise />;
}
