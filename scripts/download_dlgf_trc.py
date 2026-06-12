"""
download_dlgf_trc.py
Download the DLGF "Certified Tax Rates by Taxing District and Unit" workbooks —
the statewide tax-district -> taxing-unit crosswalk with per-fund certified rates.
This is the source for RAW.DLGF_TAX_DISTRICT_UNITS (KAN-153).

One fund-grain row per (year, county, unit_type, unit, fund, tax_district):
    YR_NBR CNTY_CD UNIT_TYPE_CD UNIT_CD UNIT_NAME FUND_CD FUND_LONG_NAME
    TAX_DIST_CD TAX_DIST_NAME CERTD_TAX_RATE_PCNT
    (unit_type_cd: 1=County 2=Township 3=City/Town 4=School 5=Library 6=Special)

Usage:
    # Default — pay years 2024 + 2025 (the SEA-1 model baseline + prior year):
    python download_dlgf_trc.py

    # Specific years:
    python download_dlgf_trc.py --years 2024 2025 2026

Output: <output_dir>/<year>_trc_unit.xlsx   (default: propertydata/trc/)

Dependencies: pip install requests
"""

import argparse
import os

import requests

# DLGF publishes one workbook per pay year. Filenames are inconsistent across
# years (note the recurring "Certifed" typo), so map known years explicitly.
TRC_URLS = {
    "2026": "https://www.in.gov/dlgf/files/2026-reports/2026_Certifed_Tax_Rates_by_District_Unit.xlsx",
    "2025": "https://www.in.gov/dlgf/files/2025-reports/2025_Certifed_Tax_Rates_by_District_Unit.xlsx",
    "2024": "https://www.in.gov/dlgf/files/2024-reports/2024_Certifed_Tax_Rates_by_District_Unit.xlsx",
    "2023": "https://www.in.gov/dlgf/files/2023-reports/2023-Certified-Taxing-District-Rates-by-Unit-and-Fund.xlsx",
}


def download_one(session, year, output_dir):
    url = TRC_URLS.get(year)
    if not url:
        print(f"  SKIP {year}: no known URL (add it to TRC_URLS)")
        return False

    out_path = os.path.join(output_dir, f"{year}_trc_unit.xlsx")
    print(f"  Downloading {year} -> {os.path.basename(out_path)} ...", end="", flush=True)
    resp = session.get(url, timeout=300)
    resp.raise_for_status()

    ctype = resp.headers.get("Content-Type", "")
    if "spreadsheet" not in ctype and "octet-stream" not in ctype:
        print(f" FAILED (got {ctype}) — DLGF may have moved/renamed the file")
        return False

    with open(out_path, "wb") as f:
        f.write(resp.content)
    print(f" {len(resp.content) // 1024:,} KB")
    return True


def main():
    parser = argparse.ArgumentParser(description="Download DLGF TRC unit-level workbooks")
    parser.add_argument("--years", nargs="+", default=["2024", "2025"],
                        help="Pay years to download (default: 2024 2025)")
    parser.add_argument("--output-dir", default=os.path.join("propertydata", "trc"),
                        help="Directory to save xlsx files (default: propertydata/trc)")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0"})

    print(f"Downloading {len(args.years)} TRC workbook(s) to {os.path.abspath(args.output_dir)}\n")
    ok = sum(download_one(session, y, args.output_dir) for y in args.years)
    print(f"\nDone: {ok}/{len(args.years)} downloaded.")


if __name__ == "__main__":
    main()
