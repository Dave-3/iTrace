"""iTrace product-trust graph: brands, their supply chain, and the crowd scan network."""

import math;
import random;
import from datetime { datetime, timedelta }

# ---------- Nodes ----------

node Hub {
    has version: str = "itrace-seed-v1";
}

node Brand {
    has name: str,
        sector: str = "",
        hq: str = "Nairobi",
        joined: bool = True;
}

node Product {
    has sku: str,
        name: str,
        category: str,               # food | beverage | pharma | seed | cosmetic
        mark: str = "SM",            # KEBS mark type: SM | DM | ISM | ""
        permit: str = "",            # KEBS permit / PPB reg / KEPHIS lot
        price_kes: int = 0,
        kcal_per_100: int = 0,
        sugar_g: float = 0.0,
        salt_g: float = 0.0;
}

node Batch {
    has batch_no: str,
        plant: str = "",
        made_on: str = "",
        expires_on: str = "",
        size: int = 0,
        recalled: bool = False;
}

node Unit {
    has code: str;
}

node Region {
    has name: str,
        county: str = "",
        lat: float = 0.0,
        lng: float = 0.0;
}

"""Every code ever scanned gets a Trace - the crowd memory, even for brands not on iTrace."""
node Trace {
    has code: str,
        claimed_brand: str = "",
        claimed_product: str = "";
}

node Scan {
    has at: str,
        region: str,
        verdict: str = "unchecked",   # verified | suspicious | unknown | warning
        source: str = "consumer";
}

node Report {
    has note: str,
        region: str = "",
        at: str = "";
}

node Action {
    has kind: str,                    # field_audit | retailer_alert | promotion | recall_notice
        title: str,
        detail: str,
        region: str = "",
        impact_kes: int = 0,
        status: str = "pending",      # pending | approved | rejected
        created_at: str = "",
        by_ai: bool = False;
}

edge ScannedIn: Scan --> Region {}

# ---------- Geography ----------

obj RegionSpec {
    has name: str,
        county: str,
        lat: float,
        lng: float;
}

glob REGIONS: list[RegionSpec] = [
    RegionSpec(name="Nairobi CBD", county="Nairobi", lat=-1.2864, lng=36.8172),
    RegionSpec(name="Eastleigh", county="Nairobi", lat=-1.2741, lng=36.8510),
    RegionSpec(name="Mombasa", county="Mombasa", lat=-4.0435, lng=39.6682),
    RegionSpec(name="Kisumu", county="Kisumu", lat=-0.0917, lng=34.7680),
    RegionSpec(name="Nakuru", county="Nakuru", lat=-0.3031, lng=36.0800),
    RegionSpec(name="Eldoret", county="Uasin Gishu", lat=0.5143, lng=35.2698),
    RegionSpec(name="Thika", county="Kiambu", lat=-1.0333, lng=37.0693),
    RegionSpec(name="Machakos", county="Machakos", lat=-1.5177, lng=37.2634),
    RegionSpec(name="Kakamega", county="Kakamega", lat=0.2827, lng=34.7519),
    RegionSpec(name="Nyeri", county="Nyeri", lat=-0.4201, lng=36.9476)
];

def km_between(lat1: float, lng1: float, lat2: float, lng2: float) -> float {
    r = 6371.0;
    p1 = math.radians(lat1);
    p2 = math.radians(lat2);
    dp = math.radians(lat2 - lat1);
    dl = math.radians(lng2 - lng1);
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2;
    return 2 * r * math.asin(math.sqrt(a));
}

def now_iso() -> str {
    return datetime.now().replace(microsecond=0).isoformat();
}

def ago_iso(minutes: int) -> str {
    return (datetime.now() - timedelta(minutes=minutes)).replace(microsecond=0).isoformat();
}

# ---------- Graph access ----------

"""The shared commons hub. Anonymous requests run on root.shared, so all public data lives here."""
def get_hub() -> Hub {
    hubs = [root.shared -->][?:Hub];
    if len(hubs) > 0 {
        return hubs[0];
    }
    hub = (root.shared ++> Hub())[0];
    seed_graph(hub);
    return hub;
}

def find_region(hub: Hub, name: str) -> Region {
    for r in [hub -->][?:Region] {
        if r.name.lower() == name.lower() {
            return r;
        }
    }
    return [hub -->][?:Region][0];
}

def find_brand(hub: Hub, name: str) -> Brand | None {
    for b in [hub -->][?:Brand] {
        if b.name.lower() == name.lower() {
            return b;
        }
    }
    return None;
}

"""Get-or-create the crowd Trace for a code."""
def trace_for(hub: Hub, code: str) -> Trace {
    for t in [hub -->][?:Trace] {
        if t.code == code {
            return t;
        }
    }
    return (hub ++> Trace(code=code))[0];
}

def record_scan(hub: Hub, code: str, region_name: str, verdict: str, minutes_ago: int = 0) -> Scan {
    tr = trace_for(hub, code);
    sc = (tr ++> Scan(at=ago_iso(minutes_ago), region=find_region(hub, region_name).name, verdict=verdict))[0];
    sc +>:ScannedIn:+> find_region(hub, region_name);
    return sc;
}

# ---------- Seed: fictional Kenyan brands + a living scan network ----------

obj ProductSpec {
    has sku: str,
        name: str,
        category: str,
        mark: str,
        permit: str,
        price: int,
        kcal: int = 0,
        sugar: float = 0.0,
        salt: float = 0.0;
}

obj BrandSpec {
    has brand: str,
        sector: str,
        hq: str,
        products: list[ProductSpec],
        hot: list[str];
}

glob CATALOG: list[BrandSpec] = [
    BrandSpec(brand="Tausi Foods", sector="FMCG - milling", hq="Thika", hot=["Eastleigh", "Machakos"], products=[
        ProductSpec(sku="TF-UGALI-2KG", name="Tausi Sifted Maize Flour 2kg", category="food", mark="SM", permit="SM-11842", price=210, kcal=362, sugar=0.6),
        ProductSpec(sku="TF-CHAPATI-2KG", name="Tausi Home Baking Flour 2kg", category="food", mark="SM", permit="SM-11843", price=245, kcal=340, sugar=0.4)
    ]),
    BrandSpec(brand="Nyota Beverages", sector="Soft drinks & juices", hq="Nairobi", hot=["Kisumu", "Mombasa", "Kakamega"], products=[
        ProductSpec(sku="NB-MANGO-1L", name="Nyota Mango Nectar 1L", category="beverage", mark="SM", permit="SM-20991", price=180, kcal=54, sugar=12.8, salt=0.02),
        ProductSpec(sku="NB-WATER-500", name="Nyota Spring Water 500ml", category="beverage", mark="SM", permit="SM-20990", price=50)
    ]),
    BrandSpec(brand="Kilele Pharma", sector="Pharmaceuticals", hq="Nairobi", hot=["Eldoret"], products=[
        ProductSpec(sku="KP-PARA-500", name="Kilele Paracetamol 500mg x100", category="pharma", mark="", permit="PPB-H2023-0417", price=120)
    ]),
    BrandSpec(brand="Mbegu Bora Seeds", sector="Certified seed", hq="Kitale", hot=["Kakamega", "Nakuru"], products=[
        ProductSpec(sku="MB-H614-2KG", name="Mbegu Bora Hybrid Maize H614 2kg", category="seed", mark="", permit="KEPHIS-L-55102", price=650)
    ])
];

def seed_graph(hub: Hub) {
    rng = random.Random(254);
    regions: list[Region] = [];
    for r in REGIONS {
        regions.append((hub ++> Region(name=r.name, county=r.county, lat=r.lat, lng=r.lng))[0]);
    }
    for b in CATALOG {
        brand = (hub ++> Brand(name=b.brand, sector=b.sector, hq=b.hq))[0];
        hot = b.hot;
        pi = 0;
        for p in b.products {
            prod = (brand ++> Product(
                sku=p.sku, name=p.name, category=p.category, mark=p.mark,
                permit=p.permit, price_kes=p.price, kcal_per_100=p.kcal,
                sugar_g=p.sugar, salt_g=p.salt
            ))[0];
            for bi in range(2) {
                batch = (prod ++> Batch(
                    batch_no=f"{p.sku[:2]}-{2600 + pi * 10 + bi}",
                    plant=f"{b.hq} Plant {bi + 1}",
                    made_on=ago_iso(60 * 24 * (40 + bi * 30))[:10],
                    expires_on=(datetime.now() + timedelta(days=300 - bi * 120)).date().isoformat(),
                    size=500,
                    recalled=(p.category == "pharma" and bi == 1)
                ))[0];
                for ui in range(12) {
                    code = "ITR-" + p.sku.split("-")[1] + f"-{pi}{bi}{ui:02d}";
                    unit = (batch ++> Unit(code=code))[0];
                    # genuine scan history spread across the country
                    for _ in range(rng.randint(0, 2)) {
                        reg = regions[rng.randint(0, len(regions) - 1)];
                        record_scan(hub, unit.code, reg.name, "verified", rng.randint(60, 60 * 24 * 25));
                    }
                }
            }
            pi += 1;
        }
        # counterfeit pressure: fake codes claiming this brand, concentrated in hot regions
        for (hi, hname) in enumerate(hot) {
            for fi in range(rng.randint(6, 11) - hi * 2) {
                fake = f"FK{rng.randint(100000, 999999)}";
                tr = trace_for(hub, fake);
                tr.claimed_brand = b.brand;
                tr.claimed_product = b.products[0].name;
                record_scan(hub, fake, hname, "unknown", rng.randint(60, 60 * 24 * 25));
                if fi % 3 == 0 {
                    tr ++> Report(note="Packaging print looks blurred, cap seal loose.", region=hname, at=ago_iso(rng.randint(60, 9000)));
                }
            }
            # cloned genuine codes: same real code scanned far apart
            for ci in range(2) {
                clone = "ITR-" + b.products[0].sku.split("-")[1] + f"-00{ci + 2:02d}";
                record_scan(hub, clone, hname, "suspicious", rng.randint(60, 60 * 24 * 10));
            }
        }
    }
    # ---- the four hero demo codes ----
    # 1) genuine, clean history (Tausi flour, ITR-UGALI-0001) - add one recent Nairobi scan
    record_scan(hub, "ITR-UGALI-0001", "Thika", "verified", 60 * 24 * 3);
    # 2) cloned genuine code: Mombasa then Kisumu 18 minutes apart (Nyota mango, ITR-MANGO-0003)
    record_scan(hub, "ITR-MANGO-0003", "Mombasa", "verified", 26);
    record_scan(hub, "ITR-MANGO-0003", "Kisumu", "suspicious", 8);
    # 3) recalled pharma batch (Kilele paracetamol batch 2, ITR-PARA-0105)
    # 4) unregistered code with crowd reports in Eastleigh
    t4 = trace_for(hub, "6161100420017");
    t4.claimed_brand = "Simba Cooking Oil (not on iTrace)";
    t4.claimed_product = "Simba Cooking Oil 1L";
    for m in [400, 1300, 2800, 5000] {
        record_scan(hub, "6161100420017", "Eastleigh", "unknown", m);
    }
    t4 ++> Report(note="Oil is cloudy and smells off; seal was re-glued.", region="Eastleigh", at=ago_iso(500));
    t4 ++> Report(note="Same barcode on two different bottle shapes.", region="Eastleigh", at=ago_iso(3000));
}
