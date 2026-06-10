"""
load_snowflake_parcel.py
PUT parsed PARCEL CSVs to Snowflake internal stage and run COPY INTO GATEWAY_PARCEL.

Credentials are read from environment variables (set them before running):
    $env:SNOWFLAKE_USER     = "your_username"
    $env:SNOWFLAKE_PASSWORD = "your_password"

Or pass them on the command line:
    python load_snowflake_parcel.py --user josh --password "secret"

Usage:
    # Load both years (default):
    python load_snowflake_parcel.py

    # Load a specific file:
    python load_snowflake_parcel.py --files C:\\path\\to\\parcel_AllCounties_2024p2025.csv

Dependencies: pip install snowflake-connector-python
"""

import argparse
import os
import sys
import time
import tkinter as tk
from tkinter import simpledialog

import snowflake.connector

ACCOUNT   = "docbdlg-sc53221"
DATABASE  = "HOOSIER_DATA"
SCHEMA    = "RAW"
WAREHOUSE = "COMPUTE_WH"
ROLE      = "ACCOUNTADMIN"
STAGE     = "@HOOSIER_DATA.RAW.GATEWAY_STAGE"
TABLE     = "HOOSIER_DATA.RAW.GATEWAY_PARCEL"

DEFAULT_FILES = [
    r"C:\Users\jburbrink\hoosier_data\propertydata\parcel_AllCounties_2022p2023.csv",
    r"C:\Users\jburbrink\hoosier_data\propertydata\parcel_AllCounties_2024p2025.csv",
]

TOWNSHIP_CSV = r"C:\Users\jburbrink\hoosier_data\propertydata\dlgf_township_codes.csv"
TOWNSHIP_TABLE = "HOOSIER_DATA.RAW.DLGF_TOWNSHIP_CODES"


def prompt_credentials():
    """Pop up dialogs for username, password, and MFA passcode."""
    root = tk.Tk()
    root.withdraw()

    user = simpledialog.askstring("Snowflake Login", "Username:", parent=root)
    if not user:
        sys.exit("Cancelled.")

    password = simpledialog.askstring("Snowflake Login", "Password:", show="*", parent=root)
    if not password:
        sys.exit("Cancelled.")

    passcode = simpledialog.askstring("Snowflake Login", "MFA passcode (6-digit code from authenticator app):", parent=root)
    if not passcode:
        sys.exit("Cancelled.")

    root.destroy()
    return user.strip(), password, passcode.strip()


def to_put_uri(path):
    """Convert a Windows path to a file:// URI snowflake PUT accepts."""
    return "file://" + path.replace("\\", "/")


def connect(user, password, passcode):
    print(f"Connecting to Snowflake ({ACCOUNT})...")
    conn = snowflake.connector.connect(
        account=ACCOUNT,
        user=user,
        password=password,
        authenticator="username_password_mfa",
        passcode=passcode,
        database=DATABASE,
        schema=SCHEMA,
        warehouse=WAREHOUSE,
        role=ROLE,
    )
    print("  Connected.\n")
    return conn


def put_file(cursor, local_path):
    uri      = to_put_uri(local_path)
    filename = os.path.basename(local_path)
    size_mb  = os.path.getsize(local_path) // 1024 // 1024

    print(f"PUT: {filename} ({size_mb} MB) -> {STAGE}")
    start = time.time()

    cursor.execute(
        f"PUT '{uri}' {STAGE} AUTO_COMPRESS=TRUE OVERWRITE=FALSE PARALLEL=4"
    )

    rows = cursor.fetchall()
    elapsed = time.time() - start
    for row in rows:
        # row: (source, target, source_size, target_size, source_compression,
        #        target_compression, status, message)
        status = row[6] if len(row) > 6 else "?"
        print(f"  {row[0]} -> {row[1]}  status={status}  ({elapsed:.0f}s)")

    return all((r[6] if len(r) > 6 else "") in ("UPLOADED", "SKIPPED") for r in rows)


def load_township_codes(cursor):
    import csv as _csv
    print(f"Loading {TOWNSHIP_TABLE}...")
    cursor.execute(f"CREATE OR REPLACE TABLE {TOWNSHIP_TABLE} (county_number VARCHAR, county_name VARCHAR, township_number VARCHAR, township_name VARCHAR)")
    with open(TOWNSHIP_CSV, encoding="utf-8") as f:
        reader = _csv.DictReader(f)
        rows = [(r["county_number"], r["county_name"], r["township_number"], r["township_name"]) for r in reader]
    cursor.executemany(f"INSERT INTO {TOWNSHIP_TABLE} VALUES (%s,%s,%s,%s)", rows)
    print(f"  {len(rows):,} township rows loaded.\n")


def create_table(cursor):
    print(f"Creating {TABLE} if not exists...")
    cursor.execute(f"""
        CREATE TABLE IF NOT EXISTS {TABLE} (
            assessment_year              VARCHAR,
            pay_year                     VARCHAR,
            county_number                VARCHAR,
            county_description           VARCHAR,
            parcel_number                VARCHAR,
            local_assessor_parcel        VARCHAR,
            township_number              VARCHAR,
            local_district_number        VARCHAR,
            state_district_number        VARCHAR,
            property_address             VARCHAR,
            property_city                VARCHAR,
            property_zip                 VARCHAR,
            property_class_code          VARCHAR,
            av_total_land                VARCHAR,
            av_total_improvements        VARCHAR,
            av_total_land_and_impr       VARCHAR,
            av_land_1pct                 VARCHAR,
            av_impr_1pct                 VARCHAR,
            av_nonhs_res_land_2pct       VARCHAR,
            av_nonhs_res_impr_2pct       VARCHAR,
            av_apt_land_2pct             VARCHAR,
            av_apt_impr_2pct             VARCHAR,
            av_ltc_land_2pct             VARCHAR,
            av_ltc_impr_2pct             VARCHAR,
            av_farmland_2pct             VARCHAR,
            av_mobile_home_land_2pct     VARCHAR,
            av_land_3pct                 VARCHAR,
            av_impr_3pct                 VARCHAR,
            av_classified_land           VARCHAR,
            legally_deeded_acreage       VARCHAR,
            prior_av_total_land          VARCHAR,
            prior_av_total_impr          VARCHAR
        )
    """)
    print("  Done.\n")


def copy_into(cursor):
    print(f"\nCOPY INTO {TABLE}...")
    cursor.execute(f"""
        COPY INTO {TABLE}
        FROM {STAGE}
        PATTERN = '.*parcel_.*\\.csv.*'
        FILE_FORMAT = (
            TYPE = 'CSV'
            SKIP_HEADER = 1
            FIELD_OPTIONALLY_ENCLOSED_BY = '"'
            NULL_IF = ('')
            ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        )
        ON_ERROR = 'CONTINUE'
        PURGE = FALSE
    """)

    rows        = cursor.fetchall()
    loaded      = sum(r[3] for r in rows if len(r) > 3 and r[3] is not None)
    errors_seen = sum(r[5] for r in rows if len(r) > 5 and r[5] is not None)
    print(f"  Files processed: {len(rows)}")
    print(f"  Rows loaded:     {loaded:,}")
    print(f"  Rows errored:    {errors_seen:,}")

    for row in rows:
        status = row[1] if len(row) > 1 else "?"
        loaded_n = row[3] if len(row) > 3 else 0
        errs = row[5] if len(row) > 5 else 0
        print(f"  {os.path.basename(str(row[0]))}  status={status}  loaded={loaded_n}  errors_seen={errs}")

    return loaded


def row_count(cursor):
    cursor.execute(f"SELECT COUNT(*) FROM {TABLE}")
    return cursor.fetchone()[0]


def main():
    parser = argparse.ArgumentParser(description="Load PARCEL CSVs into Snowflake")
    parser.add_argument("--user",     default=os.environ.get("SNOWFLAKE_USER", ""))
    parser.add_argument("--password", default=os.environ.get("SNOWFLAKE_PASSWORD", ""))
    parser.add_argument("--passcode", default="", help="6-digit MFA TOTP code")
    parser.add_argument("--files",    nargs="+", default=DEFAULT_FILES,
                        help="CSV file paths to load (default: both all-counties files)")
    args = parser.parse_args()

    if not args.user or not args.password or not args.passcode:
        args.user, args.password, args.passcode = prompt_credentials()

    missing = [f for f in args.files if not os.path.exists(f)]
    if missing:
        print("ERROR: File(s) not found:")
        for f in missing:
            print(f"  {f}")
        sys.exit(1)

    conn = connect(args.user, args.password, args.passcode)
    cursor = conn.cursor()

    try:
        load_township_codes(cursor)
        create_table(cursor)

        # PUT all files
        for path in args.files:
            ok = put_file(cursor, path)
            if not ok:
                print(f"  WARNING: PUT may not have completed cleanly for {path}")

        # Single COPY INTO picks up everything staged
        loaded = copy_into(cursor)

        # Final row count
        total = row_count(cursor)
        print(f"\nDone. GATEWAY_PARCEL now has {total:,} rows total.")

    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()
