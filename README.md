# iTrace: agentic product trust for Kenya

> **Illicit trade costs Kenya about KSh 800 billion a year**, roughly 9% of GDP. **1 in 5 products** on the market is counterfeit.
> *(Anti-Counterfeit Authority, KEPSA forum on illicit trade, May 2026)*

iTrace is a product-trust network built with **Jac and Jaseci**. Shoppers check a product code. AI agents then walk a graph of brands, batches, unit codes, scans, regions and shopper reports, and return a verdict with the evidence behind it. They also send the shopper to the right official Kenyan check (KEBS, KEPHIS, PPB, KRA) with the SMS already written. Brands see where counterfeits are taking their market and approve the actions an agent proposes.

**Why we built it:** a US fitness creator read calories straight off a food label. In Kenya you often can't be sure the label belongs to the real product. iTrace answers *"is this real?"* first, and builds toward *"what's in it, and what is Kenya eating?"* That is data for the fight against lifestyle diseases, which now cause over 40% of deaths in Kenya.

---

## What it does

| | Shoppers (`#/verify`) | Brands (`#/business`) |
|---|---|---|
| Ask | "Is this real? What do I do?" | "Where am I losing to fakes? What should I do?" |
| Agents | **VerifyAgent** + **ChannelAgent** | **MarketIntelAgent** |
| Output | A verdict (verified / suspicious / recalled / unknown) with evidence, nutrition facts, a one-tap official SMS, and a report button | A hotspot map, the share of scans failing verification, estimated KES leakage, and proposed audits, retailer alerts and promotions that wait for **human approval** |

### The agents

1. **VerifyAgent.** It runs the `RegistryWalker` over `Hub → Brand → Product → Batch → Unit`, routing smartly so it skips unrelated product lines. It then runs the `CrowdWalker` over `Trace → Scan → Region`. Next, a **byLLM ReAct agent** (`investigate(...) by agent_llm(tools=[lookup_registry, crowd_history, official_channels])`) calls those tools itself and reasons to a typed `Investigation` object. It catches:
   - **cloned codes**, i.e. impossible travel such as "Mombasa then Kisumu, 699 km, 18 minutes apart";
   - **recalled batches**;
   - **crowd-flagged codes**, even for brands that aren't on iTrace yet.

   A safety rail stops the LLM from ever upgrading a recalled or cloned item to "verified".
2. **ChannelAgent.** It maps the product category to the official channel: KEBS `SM#<permit>` to **20023**, KEPHIS scratch code to **1393**, the PPB register, KRA Soma Label, or ACA / KEBS **1545**. The SMS opens pre-filled. The shortcodes come from verified tool data, never from the model's memory.
3. **MarketIntelAgent.** The `SupplyWalker` collects a brand's genuine codes. The agent aggregates genuine, cloned and fake scans per region, estimates monthly leakage, and calls `propose_actions(...) by agent_llm()` for actions. These are saved as `Action` nodes with status **pending**. Nothing happens until a person clicks Approve, and the decision is stored on the graph.

Every agent has a **deterministic fallback**, so iTrace works with no API key. With a key it reasons with an LLM, and the **agent trace** panel shows each walker and tool call live.

---

## How we used Jac and Jaseci

| Jac feature | Where |
|---|---|
| **Nodes and typed edges (OSP)**: the whole domain is a graph | `services/graph.sv.jac`: `Brand, Product, Batch, Unit, Region, Trace, Scan, Report, Action`, `edge ScannedIn: Scan --> Region` |
| **Walkers** as evidence-gathering agents (`visit`, `skip`, `disengage`, node-type entry abilities) | `RegistryWalker`, `CrowdWalker`, `SupplyWalker` in `services/agents.sv.jac` |
| **byLLM `by llm()`** with typed `obj` outputs, `sem` prompts, and **ReAct tool use** | `investigate`, `propose_actions` |
| **Bring your own model**: one `Model` glob, with the key and model set per request | the Settings panel; works with any LiteLLM id (Gemini free tier by default) |
| **Native graph persistence** on `root.shared` (a public commons graph); no external database | `get_hub()` |
| **Auto-generated REST API**: `def:pub` functions and `walker:pub` walkers become endpoints | `POST /walker/register_batch`, `POST /walker/ingest_scan`, `/function/verify_product`… |
| **Full-stack Jac client**: React UI written in Jac (`.cl.jac`), `sv import` RPC with typed objects crossing the wire | `components/*.cl.jac`, including the particle-stream hero ported to Jac canvas code |

About **94% of the code is Jac**. The only other file is a small Tailwind stylesheet.

### Business API

```bash
curl -X POST http://localhost:8044/walker/register_batch -H 'Content-Type: application/json' \
  -d '{"brand":"Nyota Beverages","product":"Nyota Mango Nectar 1L","batch_no":"NB-2700","category":"beverage","codes":["ITR-MANGO-2700"]}'

curl -X POST http://localhost:8044/walker/ingest_scan -H 'Content-Type: application/json' \
  -d '{"code":"ITR-MANGO-2700","region":"Kisumu"}'
```

---

## Run it

```bash
pip install jaseci            # Jac 0.16.x + byllm + jac-client + jac-scale
jac install                   # npm dependencies for the client
jac start main.jac --port 8044   # http://localhost:8044
```

On Windows, run these inside WSL (see `AGENTS.md`). To turn on AI reasoning, click **AI off** in the nav and paste a Gemini key from aistudio.google.com. The key is stored only in your browser.

### Demo codes

| Code | What the agents find |
|---|---|
| `ITR-UGALI-0001` | Verified Tausi maize flour, clean history, nutrition facts |
| `ITR-MANGO-0003` | **Cloned**: scanned in Mombasa then Kisumu 18 minutes apart |
| `ITR-PARA-0105` | Genuine paracetamol from a **recalled batch** |
| `6161100420017` | Unregistered "cooking oil" code with crowd reports from Eastleigh |
| anything else | Unknown, with an honest "you're the first to check it" and the KEBS SMS |

## Trust model and limits

All brands and data in the demo are fictional. A code match is a signal, not proof that a physical item is genuine. Codes can be copied, which is exactly why iTrace watches scan patterns. iTrace prepares and routes official checks, and the regulator's reply is the authority. None of the Kenyan channels has a public API today. An SMS gateway (e.g. Africa's Talking) that sends the check and reads the reply automatically is on the roadmap.

## Roadmap

Camera and QR scanning · automatic SMS checks through a gateway · brand accounts with auth · approved promotions pushed to retailer POS · nutrition analytics → regional eating patterns for NCD research · Swahili UI.
