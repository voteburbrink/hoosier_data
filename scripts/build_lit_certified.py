"""
build_lit_certified.py
Produce litdata/lit_certified.csv for all 92 counties (KAN-129 verified base).

Method (exact, internally consistent): a county's income base is
    AGI = total LIT distribution / total LIT rate
Both come from the SBA Certification Calculations report. Equivalently,
certified-shares distribution / certified-shares rate yields the same AGI;
the two agree to the dollar (validated on Bartholomew = $3.335B).

Sources (public):
  * SBA 2026 Certification Calculations (distributions + rate components,
    one clean row per county in raw text extraction):
    https://www.in.gov/sba/files/2026-Certification-Calculations-November-Release.pdf
  * DOR Departmental Notice #1 (county codes 01-92):
    https://www.in.gov/dor/files/dn01.pdf

Dependency: the `pdftotext` utility (poppler). On Windows, install poppler and
put pdftotext.exe on PATH, or run this in an environment that has it. The
committed litdata/lit_certified.csv was generated this way; re-run only to
refresh for a new year (update the SBA URL).

Run:  python scripts/build_lit_certified.py
Then: python scripts/load_snowflake_lit_certified.py
"""

import csv
import os
import re
import subprocess
import sys
import urllib.request

SBA_URL = ("https://www.in.gov/sba/files/"
           "2026-Certification-Calculations-November-Release.pdf")
DN1_URL = "https://www.in.gov/dor/files/dn01.pdf"
REPORT_YEAR = "2026"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(REPO_ROOT, "litdata")
OUT_CSV = os.path.join(OUT_DIR, "lit_certified.csv")


def pdf_to_text(url, raw=True):
    fn = os.path.join(OUT_DIR, "_tmp_" + os.path.basename(url))
    urllib.request.urlretrieve(url, fn)
    txt = fn + ".txt"
    mode = "-raw" if raw else "-layout"
    subprocess.run(["pdftotext", mode, fn, txt], check=True)
    with open(txt, encoding="utf-8", errors="ignore") as f:
        data = f.read()
    os.remove(fn)
    os.remove(txt)
    return data


def county_codes(dn1_text):
    codes = {}
    for ln in dn1_text.splitlines():
        for m in re.finditer(r"([A-Za-z.][A-Za-z. ]+?)\s+(\d{2})\s+0\.\d+", ln):
            codes[m.group(1).strip().upper()] = m.group(2)
    return codes


def parse_sba(sba_text):
    dist, rate = {}, {}
    for ln in sba_text.splitlines():
        ln = ln.rstrip()
        md = re.match(r"^([A-Za-z.][A-Za-z. ]+?)\s+"
                      r"(\$[\d,]+(?:\s+(?:\$[\d,]+|-)){2,}.*)$", ln)
        if md:
            amts = re.findall(r"\$[\d,]+", md.group(2))
            if amts:
                dist[md.group(1).strip()] = int(amts[-1].replace("$", "")
                                                .replace(",", ""))
        mr = re.match(r"^([A-Za-z.][A-Za-z. ]+?)\s+"
                      r"(\d\.\d+%(?:\s+\d\.\d+%){2,})$", ln)
        if mr:
            pcts = re.findall(r"(\d\.\d+)%", mr.group(2))
            if pcts:
                rate[mr.group(1).strip()] = float(pcts[-1])
    return dist, rate


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Downloading + extracting SBA certification calculations...")
    dist, rate = parse_sba(pdf_to_text(SBA_URL, raw=True))
    print("Downloading + extracting DOR DN#1 (county codes)...")
    codes = county_codes(pdf_to_text(DN1_URL, raw=False))

    names = sorted(set(dist) & set(rate))
    if len(names) < 92:
        print("WARNING: only %d counties matched (expected 92)." % len(names))
    with open(OUT_CSV, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["county_number", "county_name", "report_year",
                    "lit_rate_pct", "certified_distribution",
                    "agi_base_reported", "source_url", "notes"])
        for n in names:
            w.writerow([codes.get(n.upper(), ""), n, REPORT_YEAR,
                        rate[n], dist[n], "", SBA_URL,
                        "Total LIT distribution / total rate = county AGI base"])
    print("Wrote %d counties -> %s" % (len(names), OUT_CSV))
    if "Bartholomew" in names:
        d, r = dist["Bartholomew"], rate["Bartholomew"]
        print("  Bartholomew check: $%s / %.4f%% -> AGI $%.0f, 0.025%% = $%.0f"
              % (f"{d:,}", r, d / (r / 100), d / (r / 100) * 0.00025))


if __name__ == "__main__":
    main()
