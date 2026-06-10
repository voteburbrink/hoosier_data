"""
download_gateway_parcel.py
Download Indiana Gateway property file zips by dataset, county, and year.

Datasets (DropDownList1 values from page source):
  3 = Tax Bill       (TAXDATA)
  4 = Adjustments    (ADJMENTS)
  5 = Real Property  (PARCEL)   ← default
  6 = Personal Property (PERSPROP)

Usage:
    # Bartholomew Real Property test:
    python download_gateway_parcel.py --counties 03 --years 2024

    # Pre-SEA-1 baseline:
    python download_gateway_parcel.py --counties 03 --years 2022

    # All counties, both years (one ~4GB file per year):
    python download_gateway_parcel.py --counties -99 --years 2022 2024

    # Different dataset:
    python download_gateway_parcel.py --dataset 4 --counties 03 --years 2024

Output: <output_dir>/<dataset_name>_<CountyName>_<code>_<yr>p<yr+1>.zip
        Defaults to current directory; override with --output-dir.

Dependencies: pip install requests beautifulsoup4
"""

import argparse
import os
import time

import requests
from bs4 import BeautifulSoup

DOWNLOAD_URL = "https://gateway.ifionline.org/public/download.aspx"

DATASETS = {
    "3": "taxbill",
    "4": "adjments",
    "5": "realparcel",
    "6": "persprop",
}

INDIANA_COUNTIES = {
    "-99": "AllCounties",
    "01": "Adams",        "02": "Allen",         "03": "Bartholomew",
    "04": "Benton",       "05": "Blackford",     "06": "Boone",
    "07": "Brown",        "08": "Carroll",       "09": "Cass",
    "10": "Clark",        "11": "Clay",          "12": "Clinton",
    "13": "Crawford",     "14": "Daviess",       "15": "Dearborn",
    "16": "Decatur",      "17": "DeKalb",        "18": "Delaware",
    "19": "Dubois",       "20": "Elkhart",       "21": "Fayette",
    "22": "Floyd",        "23": "Fountain",      "24": "Franklin",
    "25": "Fulton",       "26": "Gibson",        "27": "Grant",
    "28": "Greene",       "29": "Hamilton",      "30": "Hancock",
    "31": "Harrison",     "32": "Hendricks",     "33": "Henry",
    "34": "Howard",       "35": "Huntington",    "36": "Jackson",
    "37": "Jasper",       "38": "Jay",           "39": "Jefferson",
    "40": "Jennings",     "41": "Johnson",       "42": "Knox",
    "43": "Kosciusko",    "44": "LaGrange",      "45": "Lake",
    "46": "LaPorte",      "47": "Lawrence",      "48": "Madison",
    "49": "Marion",       "50": "Marshall",      "51": "Martin",
    "52": "Miami",        "53": "Monroe",        "54": "Montgomery",
    "55": "Morgan",       "56": "Newton",        "57": "Noble",
    "58": "Ohio",         "59": "Orange",        "60": "Owen",
    "61": "Parke",        "62": "Perry",         "63": "Pike",
    "64": "Porter",       "65": "Posey",         "66": "Pulaski",
    "67": "Putnam",       "68": "Randolph",      "69": "Ripley",
    "70": "Rush",         "71": "St. Joseph",    "72": "Scott",
    "73": "Shelby",       "74": "Spencer",       "75": "Starke",
    "76": "Steuben",      "77": "Sullivan",      "78": "Switzerland",
    "79": "Tippecanoe",   "80": "Tipton",        "81": "Union",
    "82": "Vanderburgh",  "83": "Vermillion",    "84": "Vigo",
    "85": "Wabash",       "86": "Warren",        "87": "Warrick",
    "88": "Washington",   "89": "Wayne",         "90": "Wells",
    "91": "White",        "92": "Whitley",
}


def get_viewstate(session):
    resp = session.get(DOWNLOAD_URL, timeout=30)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")

    def val(name):
        tag = soup.find("input", {"name": name})
        return tag["value"] if tag else ""

    return {
        "ctl00_ContentPlaceHolder1_ScriptManager1_TSM": val(
            "ctl00_ContentPlaceHolder1_ScriptManager1_TSM"
        ),
        "__EVENTTARGET":        "",
        "__EVENTARGUMENT":      "",
        "__LASTFOCUS":          "",
        "__VIEWSTATE":          val("__VIEWSTATE"),
        "__VIEWSTATEGENERATOR": val("__VIEWSTATEGENERATOR"),
        "__SCROLLPOSITIONX":    "0",
        "__SCROLLPOSITIONY":    "316",
        "__EVENTVALIDATION":    val("__EVENTVALIDATION"),
        "ctl00$ContentPlaceHolder1$RadComboBox1":       "Annual Financial Reports",
        "ctl00$ContentPlaceHolder1$RadComboBox2":       "Capital Assets",
        "ctl00$ContentPlaceHolder1$DropDownListUnitType": "All",
        "ctl00$ContentPlaceHolder1$DropDownListYear":   "2025",
    }


def download_one(session, dataset_code, county_code, assess_year, output_dir):
    dataset_name = DATASETS.get(dataset_code, f"dataset{dataset_code}")
    county_name  = INDIANA_COUNTIES.get(county_code, f"County{county_code}")
    pay_year     = str(int(assess_year) + 1)
    out_name     = f"{dataset_name}_{county_name}_{county_code}_{assess_year}p{pay_year}.zip"
    out_path     = os.path.join(output_dir, out_name)

    if os.path.exists(out_path):
        print(f"  SKIP (exists): {out_name}")
        return True

    payload = get_viewstate(session)
    payload.update({
        "ctl00$ContentPlaceHolder1$DropDownList1": dataset_code,
        "ctl00$ContentPlaceHolder1$DropDownList2": assess_year,
        "ctl00$ContentPlaceHolder1$DropDownList3": county_code,
        "ctl00$ContentPlaceHolder1$button2":       "Download",
    })

    print(f"  Downloading: {out_name} ...", end="", flush=True)
    resp = session.post(DOWNLOAD_URL, data=payload, timeout=300, stream=True)
    resp.raise_for_status()

    content_type = resp.headers.get("Content-Type", "")
    if "zip" not in content_type and "octet-stream" not in content_type:
        print(f" FAILED (got {content_type})")
        return False

    with open(out_path, "wb") as f:
        for chunk in resp.iter_content(chunk_size=1024 * 256):
            f.write(chunk)

    size_kb = os.path.getsize(out_path) // 1024
    print(f" {size_kb:,} KB")
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Download Indiana Gateway property file zips"
    )
    parser.add_argument(
        "--dataset", default="5",
        choices=list(DATASETS.keys()),
        help="Dataset code: 3=TaxBill 4=Adjustments 5=RealProperty 6=PersonalProperty (default: 5)"
    )
    parser.add_argument(
        "--counties", nargs="+", default=["03"],
        help="County codes, or '-99' for all-counties file (default: 03)"
    )
    parser.add_argument(
        "--years", nargs="+", default=["2024"],
        help="Assessment years (default: 2024)"
    )
    parser.add_argument(
        "--output-dir", default=".",
        help="Directory to save zip files (default: current dir)"
    )
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0"})

    dataset_name = DATASETS.get(args.dataset, args.dataset)
    total   = len(args.counties) * len(args.years)
    success = 0
    failed  = []

    print(f"Dataset: {dataset_name} (code {args.dataset})")
    print(f"Downloading {total} file(s) to {os.path.abspath(args.output_dir)}\n")

    for year in args.years:
        print(f"Assessment year {year} (pay {int(year)+1}):")
        for code in args.counties:
            ok = download_one(session, args.dataset, code, year, args.output_dir)
            if ok:
                success += 1
            else:
                failed.append((code, year))
            time.sleep(0.5)

    print(f"\nDone: {success}/{total} downloaded.")
    if failed:
        print("Failed:")
        for code, year in failed:
            print(f"  county {code}, year {year}")


if __name__ == "__main__":
    main()
