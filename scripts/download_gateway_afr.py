"""
download_gateway_afr.py
Download Indiana Gateway Annual Financial Report (AFR) files by report type
and year. Built to extend the operating-expense history before 2020: the
warehouse RAW.GATEWAY_DISBURSEMENTS currently holds 2020-2024 only, but
Gateway publishes AFR data back to 2012.

The download page (gateway.ifionline.org/public/download.aspx) AFR section:
  RadComboBox1 = "Annual Financial Reports"
  RadComboBox2 = report type, e.g. "Disbursements by Fund" (matches the
                 RAW.GATEWAY_DISBURSEMENTS schema: Fund + CLASS_NAME +
                 DISBURSE_NAME, no department column), "Township Disbursements",
                 "Detailed Receipts", "Capital Assets", etc.
  DropDownListUnitType = "All" | "County" | "Township" | "City/Town" | ...
  DropDownListYear     = 2012 .. 2025 | "All"
  button_download1     = "Download"  (the AFR button; "button2" is property)

Usage:
    # Pre-2020 township disbursements (to backfill the expense history):
    python scripts/download_gateway_afr.py --years 2012 2013 2014 2015 2016 2017 2018 2019

    # A single year, default report (Disbursements by Fund, Township):
    python scripts/download_gateway_afr.py --years 2019

    # A different report or unit type:
    python scripts/download_gateway_afr.py --report "Detailed Receipts" --unit-type All --years 2019

Output: <output-dir>/gateway_afr_<report>_<unit>_<year>.txt
  A pipe-delimited (|) text file. For "Disbursements by Fund" + Township the
  header matches RAW.GATEWAY_DISBURSEMENTS column-for-column, so the years
  append cleanly: year|cnty_cd|cnty_description|budget_unit_type|unit_code|
  sboa_id|afr_unit_type|unit_name|ent_id|ent_name|Fund_code|unit_fund_number|
  fund_name|disburse_class_code|class_name|disburse_code|section|disburse_name|
  amount| (trailing pipe -> empty SPARE_COL).
Dependencies: pip install requests beautifulsoup4
"""

import argparse
import os
import time

import requests
from bs4 import BeautifulSoup

DOWNLOAD_URL = "https://gateway.ifionline.org/public/download.aspx"
DEFAULT_REPORT = "Disbursements by Fund"   # matches RAW.GATEWAY_DISBURSEMENTS
DEFAULT_UNIT = "All"                       # matches the all-unit warehouse scope

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
DEFAULT_OUT = os.path.join(REPO_ROOT, "gatewaydata")  # *.txt is gitignored


def get_state(session):
    """Fresh __VIEWSTATE / __EVENTVALIDATION for an AFR POST."""
    r = session.get(DOWNLOAD_URL, timeout=30)
    r.raise_for_status()
    soup = BeautifulSoup(r.text, "html.parser")

    def val(name):
        t = soup.find("input", {"name": name})
        return t.get("value", "") if t else ""

    return {
        "ctl00_ContentPlaceHolder1_ScriptManager1_TSM":
            val("ctl00_ContentPlaceHolder1_ScriptManager1_TSM"),
        "__EVENTTARGET": "", "__EVENTARGUMENT": "", "__LASTFOCUS": "",
        "__VIEWSTATE": val("__VIEWSTATE"),
        "__VIEWSTATEGENERATOR": val("__VIEWSTATEGENERATOR"),
        "__SCROLLPOSITIONX": "0", "__SCROLLPOSITIONY": "0",
        "__EVENTVALIDATION": val("__EVENTVALIDATION"),
    }


def download_one(session, report, unit_type, year, output_dir):
    # Gateway serves a pipe-delimited .txt as an attachment (content-type
    # "application/text"); the server-side filename is in Content-Disposition,
    # e.g. detailedDisburse_fundsNOdept_Township2019.txt.
    safe = report.lower().replace(" ", "_").replace("/", "_")
    out_name = "gateway_afr_%s_%s_%s.txt" % (safe, unit_type.lower().replace("/", ""), year)
    out_path = os.path.join(output_dir, out_name)
    if os.path.exists(out_path):
        print("  SKIP (exists): %s" % out_name)
        return True

    payload = get_state(session)
    payload.update({
        "ctl00$ContentPlaceHolder1$RadComboBox1": "Annual Financial Reports",
        "ctl00$ContentPlaceHolder1$RadComboBox2": report,
        "ctl00$ContentPlaceHolder1$DropDownListUnitType": unit_type,
        "ctl00$ContentPlaceHolder1$DropDownListYear": str(year),
        "ctl00$ContentPlaceHolder1$button_download1": "Download",
    })

    print("  Downloading: %s ..." % out_name, end="", flush=True)
    resp = session.post(DOWNLOAD_URL, data=payload, timeout=600, stream=True)
    resp.raise_for_status()
    # A real export comes back as an attachment; a re-rendered page (bad
    # report/year/unit combo) comes back as text/html with no disposition.
    disp = resp.headers.get("Content-Disposition", "")
    if "attachment" not in disp.lower():
        print(" FAILED (no file returned; report/year/unit combo may not exist)")
        return False
    n = 0
    with open(out_path, "wb") as f:
        for chunk in resp.iter_content(chunk_size=256 * 1024):
            f.write(chunk)
            n += len(chunk)
    print(" %s KB" % format(n // 1024, ","))
    return True


def main():
    p = argparse.ArgumentParser(description="Download Indiana Gateway AFR files")
    p.add_argument("--report", default=DEFAULT_REPORT,
                   help='AFR report type (default: "Disbursements by Fund")')
    p.add_argument("--unit-type", default=DEFAULT_UNIT,
                   help="All | County | Township | City/Town | ... (default: All)")
    p.add_argument("--years", nargs="+",
                   default=[str(y) for y in range(2012, 2020)],
                   help="Years (default: 2012-2019, the pre-load gap)")
    p.add_argument("--output-dir", default=DEFAULT_OUT,
                   help="Where to write the .txt files (default: repo gatewaydata/)")
    args = p.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0"})

    print("Report: %s | Unit: %s | Years: %s\n"
          % (args.report, args.unit_type, ", ".join(args.years)))
    ok, fail = 0, []
    for y in args.years:
        if download_one(session, args.report, args.unit_type, y, args.output_dir):
            ok += 1
        else:
            fail.append(y)
        time.sleep(0.5)
    print("\nDone: %d/%d downloaded." % (ok, len(args.years)))
    if fail:
        print("Failed years:", ", ".join(fail))


if __name__ == "__main__":
    main()
