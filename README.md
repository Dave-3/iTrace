# ScanWise

ScanWise is a consumer-facing product-code verification demo. It compares a manually entered code with a small fictional catalog, shows the evidence behind a deterministic result, and saves user-submitted reports to the Jac graph store.

## Run

The JacHammer preview runs this project automatically. In a local Jac 0.34.23 environment:

```bash
jac install
jac start --dev main.jac
```

No API key, external integration, or QR-scanning package is required. The demo intentionally uses manual code entry.

## Walkthrough

Enter one of the fictional sample codes:

- `SW-2841-A` — registered demo product, linked batch, no seeded scan-history alert.
- `SW-7730-B` — registered demo product with a missing batch-origin check.
- `SW-9902-X` — registered demo product whose synthetic scan history contains distant regions 18 minutes apart.
- Any other value — unknown/unrecognized; not a counterfeit determination.

The suspicious sample conditionally displays its scan-history investigation step. Statuses come from explicit demo rules; there is no LLM inference in this MVP. Submit a report with at least five characters to store a `ProductReport` node reachable from the shared graph root. The queue is demo-only and has no administration interface.

## Trust model and limitations

All products, brands, batches, and scan events shown are fictional. A QR code can be copied, and a record match does not establish the authenticity, safety, or provenance of the physical item. Suspicious activity is a signal for investigation, not proof of wrongdoing. The app does not scan QR images, contact manufacturers, certify products, or expose private supply-chain data. Reports are persisted in the local Jac graph store; this demo has no authentication, abuse controls, or private report access policy and must not be used for real-world reports.
