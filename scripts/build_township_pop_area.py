"""
build_township_pop_area.py
Produce censusdata/township_pop_area.csv: every Indiana county subdivision
(township / town / city) with its 2020 Census population and land area in
square miles. This is the input the SEA-1 LIT model needs for the statutory
fire/EMS distribution formula (IC 6-3.6-6-4.3(b)):

    share = (service population + square miles x 20) / county total

Sources (both public, no API key required):
  * Population: US Census 2020 Redistricting (P.L. 94-171), table P1_001N,
    geography = county subdivision, state = 18 (Indiana).
    https://api.census.gov/data/2020/dec/pl
  * Land area: US Census 2023 Gazetteer, National County Subdivisions file
    (column ALAND_SQMI), filtered to USPS = 'IN'.
    https://www2.census.gov/geo/docs/maps-data/data/gazetteer/2023_Gazetteer/

Join key: the 10-digit GEOID (state 2 + county 3 + county subdivision 5).

Output columns:
    geoid, state_fips, county_fips, county_name, cousub_fips,
    subdivision_name, township_name, subdivision_type,
    population_2020, land_sqmi, data_vintage

Run:  python scripts/build_township_pop_area.py
Then: python scripts/load_snowflake_township_pop_area.py
"""

import csv
import io
import json
import os
import re
import sys
import urllib.request
import zipfile

POP_URL = ("https://api.census.gov/data/2020/dec/pl"
           "?get=NAME,P1_001N&for=county%20subdivision:*"
           "&in=state:18&in=county:*")
# The Census API requires a free key. Get one (instant) at
# https://api.census.gov/data/key_signup.html and set CENSUS_API_KEY.
GAZ_URL = ("https://www2.census.gov/geo/docs/maps-data/data/gazetteer/"
           "2023_Gazetteer/2023_Gaz_cousubs_national.zip")
GAZ_MEMBER = "2023_Gaz_cousubs_national.txt"
DATA_VINTAGE = "2020 Census P1 + 2023 Gazetteer"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(REPO_ROOT, "censusdata")
OUT_CSV = os.path.join(OUT_DIR, "township_pop_area.csv")
DLGF_CSV = os.path.join(REPO_ROOT, "propertydata", "dlgf_township_codes.csv")


def twp_key(name: str) -> str:
    """Normalize township name for DLGF-to-Census matching."""
    k = name.upper().strip()
    k = re.sub(r"\s+TOWNSHIP$", "", k)
    k = k.replace(" ", "")
    return k


def fips_to_county_number(fips3):
    """Indiana DLGF county_number (alphabetical, 1-92) from 3-digit county FIPS."""
    return f"{(int(fips3) + 1) // 2:02d}"


def load_dlgf_lookup():
    """{(county_number, twp_key(name)): (county_number, township_number)}."""
    if not os.path.exists(DLGF_CSV):
        sys.exit("ERROR: missing %s (DLGF township codes)." % DLGF_CSV)
    lookup = {}
    with open(DLGF_CSV, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            cn = str(row["county_number"]).zfill(2)
            key = (cn, twp_key(row["township_name"]))
            lookup[key] = (cn, row["township_number"])
    return lookup


def fetch_population(api_key):
    """{geoid: (subdivision_name, county_name, population)} from Census API."""
    print("Fetching 2020 population (Census P.L. 94-171, county subdivisions)...")
    url = POP_URL + "&key=" + api_key
    with urllib.request.urlopen(url, timeout=120) as r:
        rows = json.load(r)
    header, data = rows[0], rows[1:]
    i_name = header.index("NAME")
    i_pop = header.index("P1_001N")
    i_st = header.index("state")
    i_co = header.index("county")
    i_cs = header.index("county subdivision")
    out = {}
    for row in data:
        geoid = row[i_st] + row[i_co] + row[i_cs]
        # NAME e.g. "Harrison township, Bartholomew County, Indiana"
        parts = [p.strip() for p in row[i_name].split(",")]
        sub_name = parts[0]
        county_name = parts[1].replace(" County", "") if len(parts) > 1 else ""
        try:
            pop = int(row[i_pop])
        except (TypeError, ValueError):
            pop = None
        out[geoid] = (sub_name, county_name, pop)
    print("  %d Indiana county subdivisions." % len(out))
    return out


def fetch_land_area():
    """{geoid: land_sqmi} for Indiana from the Census Gazetteer."""
    print("Downloading 2023 Census Gazetteer (national county subdivisions)...")
    with urllib.request.urlopen(GAZ_URL, timeout=180) as r:
        blob = r.read()
    zf = zipfile.ZipFile(io.BytesIO(blob))
    member = GAZ_MEMBER if GAZ_MEMBER in zf.namelist() else zf.namelist()[0]
    out = {}
    with zf.open(member) as f:
        text = io.TextIOWrapper(f, encoding="latin-1")
        reader = csv.DictReader(text, delimiter="\t")
        reader.fieldnames = [h.strip() for h in reader.fieldnames]
        for row in reader:
            if (row.get("USPS") or "").strip() != "IN":
                continue
            geoid = (row.get("GEOID") or "").strip()
            try:
                out[geoid] = float((row.get("ALAND_SQMI") or "0").strip())
            except ValueError:
                out[geoid] = None
    print("  %d Indiana land-area rows." % len(out))
    return out


def subdivision_type(name):
    low = name.lower()
    if "township" in low:
        return "township"
    if low.endswith("city"):
        return "city"
    if low.endswith("town"):
        return "town"
    return "other"


def main():
    api_key = os.environ.get("CENSUS_API_KEY", "").strip()
    if len(sys.argv) > 1 and sys.argv[1].startswith("--key="):
        api_key = sys.argv[1].split("=", 1)[1].strip()
    if not api_key:
        sys.exit("ERROR: set CENSUS_API_KEY (free, instant) from "
                 "https://api.census.gov/data/key_signup.html\n"
                 "  PowerShell:  $env:CENSUS_API_KEY = 'your_key'\n"
                 "  or run:      python scripts/build_township_pop_area.py "
                 "--key=your_key")
    os.makedirs(OUT_DIR, exist_ok=True)
    pop = fetch_population(api_key)
    area = fetch_land_area()
    dlgf = load_dlgf_lookup()

    n = 0
    unmatched = []
    with open(OUT_CSV, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["geoid", "state_fips", "county_fips", "county_name",
                    "cousub_fips", "subdivision_name", "township_name",
                    "subdivision_type", "population_2020", "land_sqmi",
                    "data_vintage", "county_number", "township_number"])
        for geoid, (sub_name, county_name, p) in sorted(pop.items()):
            twp_name = (sub_name.replace(" township", "")
                        .replace(" Township", "").strip())
            county_num = fips_to_county_number(geoid[2:5])
            dlgf_match = dlgf.get((county_num, twp_key(sub_name)))
            if dlgf_match:
                out_county_number, out_township_number = dlgf_match
            else:
                out_county_number, out_township_number = "", ""
                unmatched.append((county_num, county_name, sub_name))
            w.writerow([geoid, geoid[:2], geoid[2:5], county_name, geoid[5:],
                        sub_name, twp_name, subdivision_type(sub_name),
                        p if p is not None else "",
                        area.get(geoid, "") if area.get(geoid) is not None
                        else "", DATA_VINTAGE,
                        out_county_number, out_township_number])
            n += 1
    missing = [g for g in pop if g not in area]
    print("\nWrote %d rows -> %s" % (n, OUT_CSV))
    if missing:
        print("  NOTE: %d subdivisions had no Gazetteer area match "
              "(land_sqmi blank)." % len(missing))
    if unmatched:
        print("  Unmatched (no DLGF code): %d" % len(unmatched))
        for cn, county_name, sub_name in sorted(unmatched):
            print("    county %s  %-22s  %s" % (cn, county_name, sub_name))


if __name__ == "__main__":
    main()
