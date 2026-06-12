"""
load_snowflake_township_pop_area.py
PUT censusdata/township_pop_area.csv to the Snowflake internal stage and
COPY INTO RAW.TOWNSHIP_POP_AREA (KAN-159 input: statutory fire/EMS LIT
distribution = service population + square miles x 20).

Run scripts/build_township_pop_area.py first to produce the CSV.

Same credential / refresh pattern as load_snowflake_xwalk.py: full-statewide
snapshot, so TRUNCATE before COPY. CREATE TABLE IF NOT EXISTS, never
drop/recreate. MFA passcode is the 6-digit TOTP from your authenticator.

Usage:
    python scripts/load_snowflake_township_pop_area.py
    (or pass --user/--password/--passcode)
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
STAGE = "@HOOSIER_DATA.RAW.GATEWAY_STAGE"
TABLE = "HOOSIER_DATA.RAW.TOWNSHIP_POP_AREA"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
DEFAULT_CSV = os.path.join(REPO_ROOT, "censusdata", "township_pop_area.csv")


def prompt_credentials():
    root = tk.Tk()
    root.withdraw()
    user = simpledialog.askstring("Snowflake Login", "Username:", parent=root)
    if not user:
        sys.exit("Cancelled.")
    password = simpledialog.askstring("Snowflake Login", "Password:",
                                      show="*", parent=root)
    if not password:
        sys.exit("Cancelled.")
    passcode = simpledialog.askstring("Snowflake Login",
                                      "MFA passcode (6-digit):", parent=root)
    if not passcode:
        sys.exit("Cancelled.")
    root.destroy()
    return user.strip(), password, passcode.strip()


def connect(user, password, passcode):
    print("Connecting to Snowflake (%s)..." % ACCOUNT)
    conn = snowflake.connector.connect(
        account=ACCOUNT, user=user, password=password,
        authenticator="username_password_mfa", passcode=passcode,
        database=DATABASE, schema=SCHEMA, warehouse=WAREHOUSE, role=ROLE,
    )
    print("  Connected.\n")
    return conn


def create_table(cursor):
    print("Creating %s if not exists..." % TABLE)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS %s (
            geoid             VARCHAR,
            state_fips        VARCHAR,
            county_fips       VARCHAR,
            county_name       VARCHAR,
            cousub_fips       VARCHAR,
            subdivision_name  VARCHAR,
            township_name     VARCHAR,
            subdivision_type  VARCHAR,
            population_2020   NUMBER,
            land_sqmi         FLOAT,
            data_vintage      VARCHAR,
            county_number     VARCHAR,
            township_number   VARCHAR
        )
    """ % TABLE)
    print("  Done.\n")


def put_file(cursor, local_path):
    uri = "file://" + os.path.abspath(local_path).replace("\\", "/")
    print("PUT: %s -> %s" % (os.path.basename(local_path), STAGE))
    cursor.execute("PUT '%s' %s AUTO_COMPRESS=TRUE OVERWRITE=TRUE PARALLEL=4"
                   % (uri, STAGE))
    for r in cursor.fetchall():
        print("  %s status=%s" % (r[0], r[6] if len(r) > 6 else "?"))


def copy_into(cursor):
    print("\nCOPY INTO %s..." % TABLE)
    cursor.execute("""
        COPY INTO %s
        FROM %s
        PATTERN = '.*township_pop_area\\.csv.*'
        FILE_FORMAT = (
            TYPE = 'CSV'
            SKIP_HEADER = 1
            FIELD_OPTIONALLY_ENCLOSED_BY = '"'
            NULL_IF = ('')
            ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        )
        ON_ERROR = 'ABORT_STATEMENT'
        PURGE = FALSE
    """ % (TABLE, STAGE))
    rows = cursor.fetchall()
    loaded = sum(r[3] for r in rows if len(r) > 3 and r[3] is not None)
    for r in rows:
        print("  %s status=%s loaded=%s errors=%s"
              % (os.path.basename(str(r[0])), r[1], r[3], r[5]))
    print("  Rows loaded: %s" % format(loaded, ","))
    return loaded


def main():
    p = argparse.ArgumentParser(description="Load township pop/area into Snowflake")
    p.add_argument("--user", default=os.environ.get("SNOWFLAKE_USER", ""))
    p.add_argument("--password", default=os.environ.get("SNOWFLAKE_PASSWORD", ""))
    p.add_argument("--passcode", default="", help="6-digit MFA TOTP code")
    p.add_argument("--file", default=DEFAULT_CSV)
    p.add_argument("--no-truncate", action="store_true")
    args = p.parse_args()

    if not os.path.exists(args.file):
        sys.exit("ERROR: %s not found - run build_township_pop_area.py first."
                 % args.file)
    if not args.user or not args.password or not args.passcode:
        args.user, args.password, args.passcode = prompt_credentials()

    conn = connect(args.user, args.password, args.passcode)
    cur = conn.cursor()
    try:
        create_table(cur)
        if not args.no_truncate:
            print("TRUNCATE %s (full-snapshot refresh)..." % TABLE)
            cur.execute("TRUNCATE TABLE IF EXISTS %s" % TABLE)
            print("  Done.\n")
        put_file(cur, args.file)
        copy_into(cur)
        cur.execute("""
            SELECT COUNT(*), COUNT(DISTINCT county_name),
                   SUM(CASE WHEN subdivision_type='township' THEN 1 ELSE 0 END)
            FROM %s
        """ % TABLE)
        n, c, t = cur.fetchone()
        print("\nIn-table now: %s rows | %s counties | %s townships"
              % (format(n, ","), c, t))
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
