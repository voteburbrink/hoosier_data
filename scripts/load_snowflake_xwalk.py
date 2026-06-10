"""
load_snowflake_xwalk.py
PUT the township -> legislative district crosswalk CSV to the Snowflake internal
stage and COPY INTO RAW.LEGISLATIVE_DISTRICT_XWALK (KAN-158).

Run scripts/build_legislative_xwalk.py first to produce
districtdata/legislative_district_xwalk.csv.

Credentials are read from environment variables (set before running):
    $env:SNOWFLAKE_USER     = "your_username"
    $env:SNOWFLAKE_PASSWORD = "your_password"
Or pass --user/--password/--passcode on the command line. MFA passcode is the
6-digit TOTP from your authenticator app (same flow as load_snowflake_trc.py).

Usage:
    python load_snowflake_xwalk.py

Dependencies: pip install snowflake-connector-python

REFRESH SEMANTICS: this crosswalk is a single full-statewide snapshot, so the
loader TRUNCATEs the table before COPY to avoid duplicate rows on re-load. The
table is created with CREATE TABLE IF NOT EXISTS and NEVER dropped/recreated —
TRUNCATE is the documented safe-refresh path (7-day Time Travel covers it).
(June 5 2026 incident: CREATE OR REPLACE wiped ~22M rows.) Use --no-truncate to
append instead.
"""

import argparse
import os
import sys
import tkinter as tk
from tkinter import simpledialog

import snowflake.connector

ACCOUNT   = "docbdlg-sc53221"
DATABASE  = "HOOSIER_DATA"
SCHEMA    = "RAW"
WAREHOUSE = "COMPUTE_WH"
ROLE      = "ACCOUNTADMIN"
STAGE     = "@HOOSIER_DATA.RAW.GATEWAY_STAGE"
TABLE     = "HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT  = os.path.dirname(SCRIPT_DIR)
DEFAULT_CSV = os.path.join(REPO_ROOT, "districtdata", "legislative_district_xwalk.csv")


def prompt_credentials():
    root = tk.Tk()
    root.withdraw()
    user = simpledialog.askstring("Snowflake Login", "Username:", parent=root)
    if not user:
        sys.exit("Cancelled.")
    password = simpledialog.askstring("Snowflake Login", "Password:", show="*", parent=root)
    if not password:
        sys.exit("Cancelled.")
    passcode = simpledialog.askstring("Snowflake Login", "MFA passcode (6-digit):", parent=root)
    if not passcode:
        sys.exit("Cancelled.")
    root.destroy()
    return user.strip(), password, passcode.strip()


def connect(user, password, passcode):
    print(f"Connecting to Snowflake ({ACCOUNT})...")
    conn = snowflake.connector.connect(
        account=ACCOUNT, user=user, password=password,
        authenticator="username_password_mfa", passcode=passcode,
        database=DATABASE, schema=SCHEMA, warehouse=WAREHOUSE, role=ROLE,
    )
    print("  Connected.\n")
    return conn


def create_table(cursor):
    print(f"Creating {TABLE} if not exists...")
    cursor.execute(f"""
        CREATE TABLE IF NOT EXISTS {TABLE} (
            county_number          VARCHAR,
            county_name            VARCHAR,
            township_number        VARCHAR,
            township_name          VARCHAR,
            house_district         VARCHAR,
            senate_district        VARCHAR,
            congressional_district VARCHAR,
            is_split               VARCHAR,
            precinct_count         VARCHAR,
            data_vintage           VARCHAR
        )
    """)
    print("  Done.\n")


def put_file(cursor, local_path):
    uri = "file://" + os.path.abspath(local_path).replace("\\", "/")
    print(f"PUT: {os.path.basename(local_path)} -> {STAGE}")
    cursor.execute(f"PUT '{uri}' {STAGE} AUTO_COMPRESS=TRUE OVERWRITE=TRUE PARALLEL=4")
    for r in cursor.fetchall():
        status = r[6] if len(r) > 6 else "?"
        print(f"  {r[0]} status={status}")


def copy_into(cursor):
    print(f"\nCOPY INTO {TABLE}...")
    cursor.execute(f"""
        COPY INTO {TABLE}
        FROM {STAGE}
        PATTERN = '.*legislative_district_xwalk\\.csv.*'
        FILE_FORMAT = (
            TYPE = 'CSV'
            SKIP_HEADER = 1
            FIELD_OPTIONALLY_ENCLOSED_BY = '"'
            NULL_IF = ('')
            ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        )
        ON_ERROR = 'ABORT_STATEMENT'
        PURGE = FALSE
    """)
    rows = cursor.fetchall()
    loaded = sum(r[3] for r in rows if len(r) > 3 and r[3] is not None)
    for r in rows:
        print(f"  {os.path.basename(str(r[0]))} status={r[1]} loaded={r[3]} errors={r[5]}")
    print(f"  Rows loaded: {loaded:,}")
    return loaded


def main():
    parser = argparse.ArgumentParser(description="Load legislative district crosswalk into Snowflake")
    parser.add_argument("--user", default=os.environ.get("SNOWFLAKE_USER", ""))
    parser.add_argument("--password", default=os.environ.get("SNOWFLAKE_PASSWORD", ""))
    parser.add_argument("--passcode", default="", help="6-digit MFA TOTP code")
    parser.add_argument("--file", default=DEFAULT_CSV, help="crosswalk CSV path")
    parser.add_argument("--no-truncate", action="store_true",
                        help="append instead of TRUNCATE-then-load (default truncates)")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        print(f"ERROR: {args.file} not found — run build_legislative_xwalk.py first.")
        sys.exit(1)

    if not args.user or not args.password or not args.passcode:
        args.user, args.password, args.passcode = prompt_credentials()

    conn = connect(args.user, args.password, args.passcode)
    cursor = conn.cursor()
    try:
        create_table(cursor)
        if not args.no_truncate:
            print(f"TRUNCATE {TABLE} (full-snapshot refresh)...")
            cursor.execute(f"TRUNCATE TABLE IF EXISTS {TABLE}")
            print("  Done.\n")
        put_file(cursor, args.file)
        copy_into(cursor)
        cursor.execute(f"""
            SELECT COUNT(*) AS row_count,
                   COUNT(DISTINCT county_number || township_number) AS townships,
                   SUM(CASE WHEN is_split = 'true' THEN 1 ELSE 0 END) AS split_rows
            FROM {TABLE}
        """)
        n_rows, n_twp, n_split = cursor.fetchone()
        print(f"\nIn-table now: {n_rows:,} rows | {n_twp:,} townships | {n_split:,} split rows")
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    main()
