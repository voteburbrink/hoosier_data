"""
parse_gateway_parcel.py
Parse Indiana Gateway Real Property PARCEL file (50 IAC 26-20-4)
from fixed-width format (1,286 bytes/record) into CSV for Snowflake load.

Header record:  positions 1-10 = "PARCEL" — supplies county + year metadata.
Trailer record: positions 1-10 = "TRAILER" — skipped.
Data records:   all other lines.

Usage:
    python parse_gateway_parcel.py <PARCEL_file> [<PARCEL_file2> ...]

    # Bartholomew County single-year test (county 03):
    python parse_gateway_parcel.py PARCEL_003.txt

Output: parcel_<cnty>_<assess_yr>p<pay_yr>.csv  (same dir as input)
        Comma-delimited, UTF-8, with header row — ready for PUT to GATEWAY_STAGE.

After parsing, load with:
    PUT file://C:\\path\\to\\parcel_03_2024p2025.csv @HOOSIER_DATA.RAW.GATEWAY_STAGE;
    -- then run the COPY INTO from sql/raw/copy_into.sql
"""

import csv
import os
import sys

RECORD_LEN = 1249  # file ends at Legal Description (750-1249); current_av fields absent

# Used to resolve county name when parsing an all-counties file (header county = -99)
COUNTY_NAMES = {
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

COLUMNS = [
    "assessment_year", "pay_year", "county_number", "county_description",
    "parcel_number", "local_assessor_parcel", "township_number",
    "local_district_number", "state_district_number",
    "property_address", "property_city", "property_zip",
    "property_class_code",
    "av_total_land", "av_total_improvements", "av_total_land_and_impr",
    "av_land_1pct", "av_impr_1pct",
    "av_nonhs_res_land_2pct", "av_nonhs_res_impr_2pct",
    "av_apt_land_2pct", "av_apt_impr_2pct",
    "av_ltc_land_2pct", "av_ltc_impr_2pct",
    "av_farmland_2pct", "av_mobile_home_land_2pct",
    "av_land_3pct", "av_impr_3pct",
    "av_classified_land", "legally_deeded_acreage",
    "prior_av_total_land", "prior_av_total_impr",
]


def _parse_header(rec):
    return {
        "county_number":      rec[10:12].strip(),
        "county_description": rec[12:32].strip(),
        "assessment_year":    rec[109:113].strip(),
        "pay_year":           rec[113:117].strip(),
    }


def _parse_data(rec, meta):
    parcel_number = rec[0:25].strip()
    # For all-counties files the header county is -99/99; derive from parcel number prefix
    if meta["county_number"] in ("-99", "99", ""):
        cnty = parcel_number[:2]
        cnty_desc = COUNTY_NAMES.get(cnty, cnty)
    else:
        cnty      = meta["county_number"]
        cnty_desc = meta["county_description"]
    return [
        meta["assessment_year"],
        meta["pay_year"],
        cnty,
        cnty_desc,
        parcel_number,       # parcel_number
        rec[25:50].strip(),      # local_assessor_parcel
        rec[50:54].strip(),      # township_number
        rec[54:57].strip(),      # local_district_number
        rec[57:60].strip(),      # state_district_number
        rec[93:153].strip(),     # property_address
        rec[153:183].strip(),    # property_city
        rec[183:193].strip(),    # property_zip
        rec[193:196].strip(),    # property_class_code
        rec[468:480].strip(),    # av_total_land
        rec[480:492].strip(),    # av_total_improvements
        rec[492:504].strip(),    # av_total_land_and_impr
        rec[540:552].strip(),    # av_land_1pct
        rec[552:564].strip(),    # av_impr_1pct
        rec[564:576].strip(),    # av_nonhs_res_land_2pct
        rec[576:588].strip(),    # av_nonhs_res_impr_2pct
        rec[588:600].strip(),    # av_apt_land_2pct
        rec[600:612].strip(),    # av_apt_impr_2pct
        rec[612:624].strip(),    # av_ltc_land_2pct
        rec[624:636].strip(),    # av_ltc_impr_2pct
        rec[636:648].strip(),    # av_farmland_2pct
        rec[648:660].strip(),    # av_mobile_home_land_2pct
        rec[660:672].strip(),    # av_land_3pct
        rec[672:684].strip(),    # av_impr_3pct
        rec[684:696].strip(),    # av_classified_land
        rec[696:708].strip(),    # legally_deeded_acreage
        rec[720:732].strip(),    # prior_av_total_land
        rec[732:744].strip(),    # prior_av_total_impr
    ]


def parse_file(input_path):
    basename = os.path.basename(input_path)
    size_mb  = os.path.getsize(input_path) // 1024 // 1024
    print(f"\nParsing: {basename} ({size_mb} MB)")

    meta          = {}
    output_path   = None
    writer        = None
    fout          = None
    rows_written  = 0
    rows_skipped  = 0

    with open(input_path, "r", encoding="latin-1", errors="replace") as fin:
        for raw_line in fin:
            rec      = raw_line.rstrip("\r\n")
            rec_type = rec[0:10].strip()

            if rec_type == "PARCEL":
                meta = _parse_header(rec)
                continue

            if rec_type == "TRAILER":
                continue

            if len(rec) < RECORD_LEN:
                if rec.strip():
                    rows_skipped += 1
                continue

            rec = rec[:RECORD_LEN]

            if not meta:
                rows_skipped += 1
                continue

            if output_path is None:
                out_dir  = os.path.dirname(os.path.abspath(input_path))
                cnty_tag = "AllCounties" if meta["county_number"] in ("-99", "99", "") else meta["county_number"]
                out_name = f"parcel_{cnty_tag}_{meta['assessment_year']}p{meta['pay_year']}.csv"
                output_path = os.path.join(out_dir, out_name)
                fout        = open(output_path, "w", newline="", encoding="utf-8")
                writer      = csv.writer(fout, quoting=csv.QUOTE_MINIMAL)
                writer.writerow(COLUMNS)

            writer.writerow(_parse_data(rec, meta))
            rows_written += 1

            if rows_written % 500_000 == 0:
                print(f"  ...{rows_written:,} rows written")

    if fout:
        fout.close()

    out_mb = os.path.getsize(output_path) / 1024 / 1024 if output_path and os.path.exists(output_path) else 0
    print(f"  Done: {rows_written:,} parcel records -> {os.path.basename(output_path or '')} ({out_mb:.1f} MB)")
    if rows_skipped:
        print(f"  Skipped: {rows_skipped:,} short/malformed records")

    return output_path


def main():
    if len(sys.argv) < 2:
        print("Usage: python parse_gateway_parcel.py <PARCEL_file> [<PARCEL_file2> ...]")
        sys.exit(1)

    output_files = []
    for path in sys.argv[1:]:
        if not os.path.exists(path):
            print(f"ERROR: Not found: {path}")
            continue
        out = parse_file(path)
        if out:
            output_files.append(out)

    print(f"\nAll done! {len(output_files)} CSV file(s) written.")
    print("Next steps:")
    for f in output_files:
        print(f"  PUT file://{f} @HOOSIER_DATA.RAW.GATEWAY_STAGE;")
    print("  -- then run the COPY INTO in sql/raw/copy_into.sql")


if __name__ == "__main__":
    main()
