node ProductReport {
    has code: str = "";
    has description: str = "";
    has created_at: str = "";
}

# Fictional catalog used only for this deterministic product demonstration.
def:pub lookup_code(code: str) -> dict {
    normalized = code.strip().upper();
    if len(normalized) < 5 or len(normalized) > 32 {
        return {"status": "Unknown / unrecognized", "kind": "unknown", "code": normalized, "name": "No matching record", "brand": "", "batch": "", "evidence": ["Enter a demo code between 5 and 32 characters."]};
    }
    if normalized == "SW-2841-A" {
        return {"status": "Verified against available records", "kind": "verified", "code": normalized, "name": "Coastline Mineral SPF 30", "brand": "Aster & Tide (fictional)", "batch": "AT-2406", "evidence": ["Code matches a registered demo product record.", "Batch AT-2406 is linked to the listed brand record.", "No seeded scan-history alert is present."]};
    }
    if normalized == "SW-7730-B" {
        return {"status": "Incomplete information", "kind": "incomplete", "code": normalized, "name": "Field Notes Hand Cream", "brand": "Morrow Goods (fictional)", "batch": "MG-0912", "evidence": ["Code matches a registered demo product record.", "The batch record is missing its recorded origin check.", "Available records are not enough to complete all checks."]};
    }
    if normalized == "SW-9902-X" {
        return {"status": "Suspicious activity", "kind": "suspicious", "code": normalized, "name": "Northstar Trail Flask", "brand": "Northstar Works (fictional)", "batch": "NW-1810", "evidence": ["Code matches a registered demo product record.", "Seeded scan history includes the same code in distant regions within 18 minutes.", "This activity is a signal to investigate, not proof of counterfeiting."]};
    }
    return {"status": "Unknown / unrecognized", "kind": "unknown", "code": normalized, "name": "No matching record", "brand": "", "batch": "", "evidence": ["No usable match was found in the fictional demo catalog.", "An unknown code is not a finding that a product is counterfeit."]};
}

def:pub submit_report(code: str, description: str) -> dict {
    normalized = code.strip().upper();
    clean_description = description.strip();
    if len(normalized) < 5 or len(normalized) > 32 {
        return {"ok": False, "message": "Enter a valid product code before reporting."};
    }
    if len(clean_description) < 5 {
        return {"ok": False, "message": "Add at least five characters describing your concern."};
    }
    if len(clean_description) > 1000 {
        return {"ok": False, "message": "Please keep the description under 1,000 characters."};
    }
    report_node = root ++> ProductReport(code=normalized, description=clean_description, created_at="Demo submission");
    return {"ok": True, "message": "Report saved to the demo review queue."};
}
