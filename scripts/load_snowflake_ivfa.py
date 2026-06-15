"""
load_snowflake_ivfa.py
PUT firedata/ivfa_departments_*.csv to a Snowflake internal stage and
COPY INTO RAW.IVFA_DEPARTMENTS_SOURCE (KAN-182: statewide IVFA fire department
directory, ground truth for the classifier acceptance test).

Same credential / MFA pattern as load_snowflake_township_pop_area.py. The one
difference: this is a SNAPSHOT-APPEND load, NOT a truncate-and-replace. Each
pull carries its own as_of_date, and Snowflake's COPY load history dedupes by
filename, so re-running the same file is a no-op (it won't double-load). Pass
--force only if you intentionally reload an already-loaded file.

Usage:
    python scripts/load_snowflake_ivfa.py
    python scripts/load_snowflake_ivfa.py --file firedata/ivfa_departments_2026-06-12.csv
    (credentials: --user/--password/--passcode, or you'll be prompted)

After this succeeds, apply the department-grain view:
    python scripts/apply_view.py IVFA_DEPARTMENTS --file sql/ivfa/03_analytics_view.sql
"""

import argparse
import glob
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
TABLE = "HOOSIER_DATA.RAW.IVFA_DEPARTMENTS_SOURCE"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)


def newest_csv():
    """Default to the most recent ivfa_departments_*.csv in firedata/."""
    hits = sorted(glob.glob(os.path.join(REPO_ROOT, "firedata",
                                         "ivfa_departments_*.csv")))
    return hits[-1] if hits else os.path.join(
        REPO_ROOT, "firedata", "ivfa_departments_2026-06-12.csv")


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


def create_stage(cursor):
    print("Creating stage %s if not exists..." % STAGE)
    cursor.execute("CREATE STAGE IF NOT EXISTS HOOSIER_DATA.RAW.IVFA_STAGE")
    print("  Done.\n")


def create_table(cursor):
    print("Creating %s if not exists..." % TABLE)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS %s (
            dept_name                   VARCHAR,
            city                        VARCHAR,
            name_pattern                VARCHAR,
            nonfire_or_industrial_flag  VARCHAR,
            source                      VARCHAR,
            as_of_date                  VARCHAR
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


def copy_into(cursor, force):
    print("\nCOPY INTO %s%s..." % (TABLE, " (FORCE)" if force else ""))
    cursor.execute("""
        COPY INTO %s
        FROM %s
        PATTERN = '.*ivfa_departments.*\\.csv.*'
        FILE_FORMAT = (
            TYPE = 'CSV'
            SKIP_HEADER = 1
            FIELD_OPTIONALLY_ENCLOSED_BY = '"'
            ENCODING = 'UTF-8'
            NULL_IF = ('')
            ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
        )
        ON_ERROR = 'ABORT_STATEMENT'
        FORCE = %s
        PURGE = FALSE
    """ % (TABLE, STAGE, "TRUE" if force else "FALSE"))
    rows = cursor.fetchall()
    if not rows:
        print("  No files to load (already loaded this snapshot — "
              "use --force to reload).")
        return 0
    loaded = sum(r[3] for r in rows if len(r) > 3 and r[3] is not None)
    for r in rows:
        print("  %s status=%s loaded=%s errors=%s"
              % (os.path.basename(str(r[0])), r[1], r[3], r[5]))
    print("  Rows loaded: %s" % format(loaded, ","))
    return loaded


def main():
    p = argparse.ArgumentParser(description="Load IVFA directory into Snowflake")
    p.add_argument("--user", default=os.environ.get("SNOWFLAKE_USER", ""))
    p.add_argument("--password", default=os.environ.get("SNOWFLAKE_PASSWORD", ""))
    p.add_argument("--passcode", default="", help="6-digit MFA TOTP code")
    p.add_argument("--file", default=newest_csv())
    p.add_argument("--force", action="store_true",
                   help="Reload even if Snowflake already loaded this filename")
    args = p.parse_args()

    if not os.path.exists(args.file):
        sys.exit("ERROR: %s not found." % args.file)
    if not args.user or not args.password or not args.passcode:
        args.user, args.password, args.passcode = prompt_credentials()

    conn = connect(args.user, args.password, args.passcode)
    cur = conn.cursor()
    try:
        create_stage(cur)
        create_table(cur)
        put_file(cur, args.file)
        copy_into(cur, args.force)
        print("\nIn-table now, by snapshot:")
        cur.execute("SELECT as_of_date, COUNT(*) FROM %s GROUP BY 1 ORDER BY 1"
                    % TABLE)
        for as_of, n in cur.fetchall():
            print("  %s: %s rows" % (as_of, format(n, ",")))
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
