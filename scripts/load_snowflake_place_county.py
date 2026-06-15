"""
load_snowflake_place_county.py
Load the geography bridge into Snowflake RAW (KAN-182):
  censusdata/place_county_xwalk.csv         -> RAW.PLACE_COUNTY_XWALK
  censusdata/ivfa_city_county_supplement.csv -> RAW.IVFA_CITY_COUNTY_SUPPLEMENT

Both are full-snapshot reference tables, so this TRUNCATEs before COPY (same
pattern as load_snowflake_township_pop_area.py). CREATE TABLE IF NOT EXISTS,
never drop/recreate. MFA passcode is the 6-digit TOTP from your authenticator.

Run scripts/build_place_county_xwalk.py first if the xwalk CSV is stale.

Usage:
    python scripts/load_snowflake_place_county.py
    (or pass --user/--password/--passcode)

After this, apply the county-aware IVFA view and reconciliation in sql/ivfa/.
"""

import argparse
import os
import sys
import tkinter as tk
from tkinter import simpledialog

import snowflake.connector

ACCOUNT = "docbdlg-sc53221"
DATABASE = "HOOSIER_DATA"
SCHEMA = "RAW"
WAREHOUSE = "COMPUTE_WH"
ROLE = "ACCOUNTADMIN"
STAGE = "@HOOSIER_DATA.RAW.IVFA_STAGE"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)

# (csv path, table, DDL, copy pattern)
JOBS = [
    (os.path.join(REPO_ROOT, "censusdata", "place_county_xwalk.csv"),
     "HOOSIER_DATA.RAW.PLACE_COUNTY_XWALK",
     """CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.PLACE_COUNTY_XWALK (
            place_geoid VARCHAR, place_name VARCHAR, place_namelsad VARCHAR,
            county_name VARCHAR, county_number VARCHAR, overlap_pct VARCHAR,
            is_primary VARCHAR, is_multi_county VARCHAR)""",
     ".*place_county_xwalk.*\\.csv.*"),
    (os.path.join(REPO_ROOT, "censusdata", "ivfa_city_county_supplement.csv"),
     "HOOSIER_DATA.RAW.IVFA_CITY_COUNTY_SUPPLEMENT",
     """CREATE TABLE IF NOT EXISTS HOOSIER_DATA.RAW.IVFA_CITY_COUNTY_SUPPLEMENT (
            city_norm VARCHAR, county_name VARCHAR, county_number VARCHAR,
            method VARCHAR, confidence VARCHAR)""",
     ".*ivfa_city_county_supplement.*\\.csv.*"),
]


def prompt_credentials():
    root = tk.Tk()
    root.withdraw()
    user = simpledialog.askstring("Snowflake Login", "Username:", parent=root)
    password = simpledialog.askstring("Snowflake Login", "Password:",
                                      show="*", parent=root)
    passcode = simpledialog.askstring("Snowflake Login",
                                      "MFA passcode (6-digit):", parent=root)
    root.destroy()
    if not (user and password and passcode):
        sys.exit("Cancelled.")
    return user.strip(), password, passcode.strip()


def connect(user, password, passcode):
    print("Connecting to Snowflake (%s)..." % ACCOUNT)
    conn = snowflake.connector.connect(
        account=ACCOUNT, user=user, password=password,
        authenticator="username_password_mfa", passcode=passcode,
        database=DATABASE, schema=SCHEMA, warehouse=WAREHOUSE, role=ROLE)
    print("  Connected.\n")
    return conn


def run_job(cur, csv_path, table, ddl, pattern):
    if not os.path.exists(csv_path):
        sys.exit("ERROR: %s not found." % csv_path)
    print("=== %s ===" % table)
    cur.execute("CREATE STAGE IF NOT EXISTS HOOSIER_DATA.RAW.IVFA_STAGE")
    cur.execute(ddl)
    cur.execute("TRUNCATE TABLE IF EXISTS %s" % table)
    uri = "file://" + os.path.abspath(csv_path).replace("\\", "/")
    cur.execute("PUT '%s' %s AUTO_COMPRESS=TRUE OVERWRITE=TRUE PARALLEL=4"
                % (uri, STAGE))
    cur.execute("""
        COPY INTO %s FROM %s
        PATTERN = '%s'
        FILE_FORMAT = (TYPE='CSV' SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"'
                       ENCODING='UTF-8' NULL_IF=('') ERROR_ON_COLUMN_COUNT_MISMATCH=FALSE)
        ON_ERROR = 'ABORT_STATEMENT' PURGE = FALSE
    """ % (table, STAGE, pattern))
    rows = cur.fetchall()
    loaded = sum(r[3] for r in rows if len(r) > 3 and r[3] is not None)
    cur.execute("SELECT COUNT(*) FROM %s" % table)
    print("  loaded %s rows | in-table now %s\n"
          % (format(loaded, ","), format(cur.fetchone()[0], ",")))


def main():
    p = argparse.ArgumentParser(description="Load place/county geography bridge")
    p.add_argument("--user", default=os.environ.get("SNOWFLAKE_USER", ""))
    p.add_argument("--password", default=os.environ.get("SNOWFLAKE_PASSWORD", ""))
    p.add_argument("--passcode", default="")
    args = p.parse_args()
    if not (args.user and args.password and args.passcode):
        args.user, args.password, args.passcode = prompt_credentials()

    conn = connect(args.user, args.password, args.passcode)
    cur = conn.cursor()
    try:
        for job in JOBS:
            run_job(cur, *job)
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
