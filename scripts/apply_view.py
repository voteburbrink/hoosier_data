"""
apply_view.py
Recreate a single ANALYTICS view in Snowflake from a .sql file, without
running the whole file. Extracts the one
`CREATE OR REPLACE VIEW HOOSIER_DATA.ANALYTICS.<NAME> ... ;` statement and
executes it. Read-write (CREATE), so it uses Josh's own login + MFA.

Usage:
    python scripts/apply_view.py FIRE_COST_TREND
    python scripts/apply_view.py SEA1_FIRE_IMPACT_SUMMARY --file sql/analytics/sea1_impact.sql

Default --file is sql/analytics/sea1_impact.sql. Credentials come from the
SNOWFLAKE_USER / SNOWFLAKE_PASSWORD env vars if set, else it prompts.
Dependencies: pip install snowflake-connector-python
"""

import argparse
import getpass
import os
import re
import sys

import snowflake.connector

ACCOUNT = "DOCBDLG-SC53221"
DATABASE = "HOOSIER_DATA"
SCHEMA = "ANALYTICS"
WAREHOUSE = "COMPUTE_WH"
ROLE = "ACCOUNTADMIN"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
DEFAULT_FILE = os.path.join(REPO_ROOT, "sql", "analytics", "sea1_impact.sql")


def extract_statement(sql_text, view_name):
    # Strip "--" line comments first: they can contain ';' or stray quotes
    # that would confuse the terminator scan below.
    no_comments = re.sub(r"--[^\n]*", "", sql_text)
    # Locate the CREATE OR REPLACE VIEW header for this view.
    head = re.compile(
        r"CREATE\s+OR\s+REPLACE\s+VIEW\s+HOOSIER_DATA\.ANALYTICS\."
        + re.escape(view_name) + r"\b", re.IGNORECASE)
    m = head.search(no_comments)
    if not m:
        sys.exit("ERROR: could not find CREATE OR REPLACE VIEW "
                 "HOOSIER_DATA.ANALYTICS.%s in the file." % view_name)
    # Scan for the terminating ';' that sits OUTSIDE any single-quoted string
    # literal. View bodies may carry ';' inside literals (e.g. provenance_note),
    # which a non-greedy regex would wrongly truncate on. SQL escapes a quote
    # inside a literal by doubling it ('').
    start, i, n = m.start(), m.end(), len(no_comments)
    in_str = False
    while i < n:
        ch = no_comments[i]
        if ch == "'":
            if in_str and i + 1 < n and no_comments[i + 1] == "'":
                i += 2            # escaped '' inside a string literal
                continue
            in_str = not in_str
        elif ch == ";" and not in_str:
            return no_comments[start:i + 1]
        i += 1
    sys.exit("ERROR: no terminating ';' found for "
             "HOOSIER_DATA.ANALYTICS.%s (unbalanced quotes?)." % view_name)


def main():
    p = argparse.ArgumentParser(description="Recreate one ANALYTICS view")
    p.add_argument("view", help="View name, e.g. FIRE_COST_TREND")
    p.add_argument("--file", default=DEFAULT_FILE)
    p.add_argument("--user", default=os.environ.get("SNOWFLAKE_USER", ""))
    p.add_argument("--password", default=os.environ.get("SNOWFLAKE_PASSWORD", ""))
    p.add_argument("--passcode", default="", help="6-digit MFA TOTP code")
    p.add_argument("--print-only", action="store_true",
                   help="Print the statement and exit (no connection)")
    args = p.parse_args()

    with open(args.file, encoding="utf-8") as f:
        stmt = extract_statement(f.read(), args.view.upper())

    if args.print_only:
        print(stmt)
        return

    user = args.user or input("Snowflake username: ").strip()
    password = args.password or getpass.getpass("Password: ")
    passcode = args.passcode or input("MFA passcode (6-digit): ").strip()

    print("Connecting to %s as %s ..." % (ACCOUNT, user))
    conn = snowflake.connector.connect(
        account=ACCOUNT, user=user, password=password,
        authenticator="username_password_mfa", passcode=passcode,
        database=DATABASE, schema=SCHEMA, warehouse=WAREHOUSE, role=ROLE,
    )
    try:
        conn.cursor().execute(stmt)
        print("Recreated HOOSIER_DATA.ANALYTICS.%s" % args.view.upper())
    finally:
        conn.close()


if __name__ == "__main__":
    main()
