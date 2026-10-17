sv import from ..services.scanwise { lookup_code, submit_report }
import from .ui.button { Button }
import from .ui.card { Card, CardContent, CardHeader, CardTitle, CardDescription }
import from .ui.input { Input }
import from .ui.textarea { Textarea }
import from .ui.badge { Badge }
import from .ui.field { Field, FieldLabel }

# Consumer-facing demo verifier with deterministic, fictional evidence.
def:pub ScanWise() -> JsxElement {
    has code: str = "";
    has report_text: str = "";
    has result: dict = {};
    has message: str = "";
    has busy: bool = False;

    def change_code(e: ChangeEvent) { code = e.target.value; }
    def change_report(e: ChangeEvent) { report_text = e.target.value; }

    async def run_lookup(e: any = None) {
        busy = True;
        message = "";
        result = await lookup_code(code);
        busy = False;
    }

    async def run_report(e: any = None) {
        response = await submit_report(code, report_text);
        message = response["message"];
        if response["ok"] {
            report_text = "";
        }
    }

    result_kind = result["kind"] or "";
    result_title = result["status"] or "";
    status_style = "border-teal-500/40 bg-teal-500/10 text-teal-300";
    if result_kind == "suspicious" { status_style = "border-amber-400/50 bg-amber-400/10 text-amber-200"; }
    elif result_kind == "incomplete" { status_style = "border-amber-400/50 bg-amber-400/10 text-amber-200"; }
    elif result_kind == "unknown" { status_style = "border-slate-500 bg-slate-500/10 text-slate-300"; }

    return <main className="min-h-screen bg-[#151d25] text-white">
        <header className="mx-auto flex w-full max-w-7xl items-center justify-between px-5 py-6 sm:px-8">
            <a href="#top" className="flex items-center gap-3" aria-label="ScanWise home">
                <span className="flex size-9 items-center justify-center rounded-full bg-[#ffc239] text-[#151d25] font-bold">S</span>
                <span className="text-lg font-bold tracking-[0.14em]">SCANWISE</span>
            </a>
            <span className="rounded-full border border-white/15 px-3 py-1 text-xs text-slate-300">DEMO DATA ONLY</span>
        </header>

        <section id="top" className="mx-auto grid w-full max-w-7xl gap-10 px-5 pb-14 pt-8 sm:px-8 lg:grid-cols-[1.1fr_0.9fr] lg:items-center lg:pb-20 lg:pt-14">
            <div className="flex flex-col gap-6">
                <div className="flex items-center gap-2 text-sm font-medium text-teal-300">
                    <span className="size-2 rounded-full bg-teal-300"></span>
                    PRODUCT TRUST, MADE CLEAR
                </div>
                <h1 className="max-w-3xl text-balance text-5xl font-bold leading-[0.98] tracking-[-0.05em] sm:text-7xl">Check the code.<br/><span className="text-[#ffc239]">Know the evidence.</span></h1>
                <p className="max-w-xl text-base leading-7 text-slate-300 sm:text-lg">Look up a product code against its recorded demo identity, batch details, and scan signals.</p>
                <div className="flex flex-wrap gap-2 pt-1">
                    <span className="text-xs text-slate-400">TRY A DEMO CODE</span>
                    <button type="button" onClick={lambda { code = "SW-2841-A"; }} className="rounded-full border border-white/15 px-3 py-1 text-xs text-slate-200 transition-colors hover:border-teal-300 hover:text-teal-200">SW-2841-A</button>
                    <button type="button" onClick={lambda { code = "SW-7730-B"; }} className="rounded-full border border-white/15 px-3 py-1 text-xs text-slate-200 transition-colors hover:border-teal-300 hover:text-teal-200">SW-7730-B</button>
                    <button type="button" onClick={lambda { code = "SW-9902-X"; }} className="rounded-full border border-white/15 px-3 py-1 text-xs text-slate-200 transition-colors hover:border-teal-300 hover:text-teal-200">SW-9902-X</button>
                </div>
            </div>

            <Card className="border-white/10 bg-[#1c2731] text-white shadow-2xl shadow-black/20">
                <CardHeader className="gap-2 pb-3">
                    <CardTitle className="text-xl">Check a product</CardTitle>
                    <CardDescription className="text-slate-400">Enter the printed code. QR scanning is not enabled in this demo.</CardDescription>
                </CardHeader>
                <CardContent className="flex flex-col gap-5">
                    <Field>
                        <FieldLabel htmlFor="product-code" className="text-slate-200">Product code</FieldLabel>
                        <div className="flex flex-col gap-2 sm:flex-row">
                            <Input id="product-code" value={code} onChange={change_code} placeholder="For example, SW-2841-A" className="h-12 border-white/15 bg-[#121920] text-white placeholder:text-slate-500" />
                            <Button onClick={run_lookup} disabled={busy} className="h-12 shrink-0 bg-[#ffc239] px-6 font-semibold text-[#151d25] hover:bg-[#ffd064]">{ "Check code" if not busy else "Checking..." }</Button>
                        </div>
                    </Field>
                    <p className="text-xs leading-5 text-slate-400">A QR code can be copied. A record match is not proof that the physical item or packaging is genuine.</p>
                </CardContent>
            </Card>
        </section>

        {if result_title != "" {
            <section className="mx-auto grid w-full max-w-7xl gap-5 px-5 pb-16 sm:px-8 lg:grid-cols-[1fr_0.85fr]">
                <Card className="border-white/10 bg-[#1c2731] text-white shadow-xl">
                    <CardHeader className="gap-4">
                        <div className="flex flex-wrap items-center justify-between gap-3">
                            <Badge className={"border px-3 py-1 " + status_style}>{result_title}</Badge>
                            <span className="text-xs text-slate-400">FICTIONAL DEMO RECORD</span>
                        </div>
                        <CardTitle className="text-2xl">{result["name"]}</CardTitle>
                        {if result["brand"] != "" { <CardDescription className="text-slate-300">{result["brand"]} · Batch {result["batch"]}</CardDescription> } else { <CardDescription className="text-slate-400">Code {result["code"]}</CardDescription> }}
                    </CardHeader>
                    <CardContent className="flex flex-col gap-5">
                        <div className="flex flex-col gap-3 border-t border-white/10 pt-4">
                            <h2 className="text-sm font-semibold text-white">Evidence and checks</h2>
                            {for item in (result["evidence"] as list[str]) {
                                <div key={item} className="flex items-start gap-3 text-sm leading-6 text-slate-300">
                                    <span className="mt-2 size-1.5 shrink-0 rounded-full bg-teal-300"></span>
                                    <span>{item}</span>
                                </div>
                            }}
                        </div>
                        <div className="rounded-lg border border-white/10 bg-[#151d25] p-4">
                            <p className="text-sm font-semibold text-[#ffc239]">What this result means</p>
                            <p className="mt-2 text-sm leading-6 text-slate-300">ScanWise compares this code with fictional records and explicit demo rules. It cannot authenticate the physical item, certify safety, or establish counterfeiting.</p>
                        </div>
                    </CardContent>
                </Card>

                <div className="flex flex-col gap-5">
                    <Card className="border-white/10 bg-[#1c2731] text-white shadow-lg">
                        <CardHeader>
                            <CardTitle className="text-lg">Investigation steps</CardTitle>
                            <CardDescription className="text-slate-400">Deterministic checks, based on available demo evidence.</CardDescription>
                        </CardHeader>
                        <CardContent className="flex flex-col gap-3">
                            <div className="flex items-center gap-3 rounded-lg bg-[#151d25] p-3 text-sm"><span className="flex size-6 items-center justify-center rounded-full bg-teal-400/15 text-teal-300">1</span>Product code lookup completed</div>
                            {if result_kind == "suspicious" {
                                <div className="flex items-center gap-3 rounded-lg bg-[#151d25] p-3 text-sm"><span className="flex size-6 items-center justify-center rounded-full bg-amber-400/15 text-amber-200">2</span>Scan history inspected: distant regions, 18 minutes apart</div>
                            } elif result_kind == "verified" {
                                <div className="flex items-center gap-3 rounded-lg bg-[#151d25] p-3 text-sm"><span className="flex size-6 items-center justify-center rounded-full bg-teal-400/15 text-teal-300">2</span>Batch link and seeded scan signals checked</div>
                            } elif result_kind == "incomplete" {
                                <div className="flex items-center gap-3 rounded-lg bg-[#151d25] p-3 text-sm"><span className="flex size-6 items-center justify-center rounded-full bg-amber-400/15 text-amber-200">2</span>Batch check found a missing origin record</div>
                            } else {
                                <div className="flex items-center gap-3 rounded-lg bg-[#151d25] p-3 text-sm"><span className="flex size-6 items-center justify-center rounded-full bg-slate-400/15 text-slate-300">2</span>No matching product; no unsupported claim made</div>
                            }}
                        </CardContent>
                    </Card>

                    <Card className="border-white/10 bg-[#1c2731] text-white shadow-lg">
                        <CardHeader>
                            <CardTitle className="text-lg">Report a concern</CardTitle>
                            <CardDescription className="text-slate-400">Save a note to the fictional demo review queue.</CardDescription>
                        </CardHeader>
                        <CardContent className="flex flex-col gap-4">
                            <Field>
                                <FieldLabel htmlFor="report-description" className="text-slate-200">What did you notice?</FieldLabel>
                                <Textarea id="report-description" value={report_text} onChange={change_report} maxLength={1000} placeholder="Describe the code or packaging concern" className="min-h-24 border-white/15 bg-[#151d25] text-white placeholder:text-slate-500" />
                            </Field>
                            <Button onClick={run_report} className="w-full bg-[#ffc239] font-semibold text-[#151d25] hover:bg-[#ffd064]">Save report</Button>
                            {if message != "" { <p role="status" className="text-sm text-teal-200">{message}</p> }}
                        </CardContent>
                    </Card>
                </div>
            </section>
        } else {
            <section className="mx-auto w-full max-w-7xl px-5 pb-16 sm:px-8">
                <div className="grid gap-4 border-t border-white/10 pt-8 sm:grid-cols-3">
                    <div><p className="text-sm font-semibold">Identity</p><p className="mt-1 text-sm text-slate-400">Match the code to a product record.</p></div>
                    <div><p className="text-sm font-semibold">Evidence</p><p className="mt-1 text-sm text-slate-400">See which batch and scan checks were available.</p></div>
                    <div><p className="text-sm font-semibold">Next step</p><p className="mt-1 text-sm text-slate-400">Report a concern without overstating what is known.</p></div>
                </div>
            </section>
        }}

        <footer className="border-t border-white/10 px-5 py-6 text-center text-xs text-slate-500">ScanWise demo · Fictional products and events · A QR match is not a guarantee of authenticity</footer>
    </main>;
}
