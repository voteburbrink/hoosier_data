"""
verify_parcel_load.py
Quick verification of GATEWAY_PARCEL load and HOMESTEAD_AV_BY_TOWNSHIP view.
"""
import os, sys, tkinter as tk
from tkinter import simpledialog
import snowflake.connector

ACCOUNT = "docbdlg-sc53221"

def prompt_credentials():
    root = tk.Tk(); root.withdraw()
    user     = simpledialog.askstring("Snowflake", "Username:", parent=root)
    password = simpledialog.askstring("Snowflake", "Password:", show="*", parent=root)
    passcode = simpledialog.askstring("Snowflake", "MFA passcode:", parent=root)
    root.destroy()
    if not all([user, password, passcode]): sys.exit("Cancelled.")
    return user.strip(), password, passcode.strip()

user, password, passcode = prompt_credentials()
conn = snowflake.connector.connect(
    account=ACCOUNT, user=user, password=password,
    authenticator="username_password_mfa", passcode=passcode,
    database="HOOSIER_DATA", schema="RAW", warehouse="COMPUTE_WH", role="ACCOUNTADMIN",
)
cur = conn.cursor()

# 1. Row counts by year
print("=== GATEWAY_PARCEL row counts by year ===")
cur.execute("""
    SELECT pay_year, COUNT(*) AS rows, COUNT(DISTINCT county_number) AS counties
    FROM HOOSIER_DATA.RAW.GATEWAY_PARCEL
    GROUP BY 1 ORDER BY 1
""")
for r in cur.fetchall():
    print(f"  {r[0]}: {r[1]:>12,} rows  {r[2]} counties")

# 2. Bartholomew townships — homestead share
print("\n=== HOMESTEAD_AV_BY_TOWNSHIP — Bartholomew County (pay_year=2025) ===")
cur.execute("""
    SELECT
        t.township_number,
        n.unit_name,
        t.parcel_count,
        t.gross_av,
        t.homestead_gross_av,
        t.homestead_pct,
        t.commercial_av,
        t.farmland_av
    FROM HOOSIER_DATA.ANALYTICS.HOMESTEAD_AV_BY_TOWNSHIP t
    LEFT JOIN (
        SELECT DISTINCT state_assigned_township_number, unit_name
        FROM HOOSIER_DATA.RAW.GATEWAY_CERT_NAV
        WHERE cnty_cd = '03'
    ) n ON t.township_number = n.state_assigned_township_number
    WHERE t.county_number = '03' AND t.pay_year = '2025'
    ORDER BY t.homestead_pct DESC NULLS LAST
""")
rows = cur.fetchall()
print(f"  {'Township':>6}  {'Name':<28} {'Parcels':>8}  {'Gross AV':>14}  {'Homestead AV':>14}  {'HS%':>6}  {'Comm AV':>12}  {'Farm AV':>12}")
print("  " + "-"*105)
for r in rows:
    name = r[1] or "?"
    print(f"  {r[0]:>6}  {name:<28} {r[2]:>8,}  {(r[3] or 0):>14,.0f}  {(r[4] or 0):>14,.0f}  {(r[5] or 0):>6.1%}  {(r[6] or 0):>12,.0f}  {(r[7] or 0):>12,.0f}")

# 3. Sanity check: does assumed 65% hold?
print("\n=== Weighted avg homestead % across Bartholomew townships (pay_year=2025) ===")
cur.execute("""
    SELECT
        SUM(homestead_gross_av) / NULLIF(SUM(gross_av), 0) AS weighted_hs_pct,
        SUM(gross_av) AS total_gross_av,
        SUM(homestead_gross_av) AS total_hs_av
    FROM HOOSIER_DATA.ANALYTICS.HOMESTEAD_AV_BY_TOWNSHIP
    WHERE county_number = '03' AND pay_year = '2025'
""")
r = cur.fetchone()
print(f"  Weighted homestead %: {r[0]:.1%}")
print(f"  Total gross AV:       ${r[1]:,.0f}")
print(f"  Total homestead AV:   ${r[2]:,.0f}")
print(f"\n  (SEA-1 analysis assumed 65% — {'CONFIRMED' if abs(r[0] - 0.65) < 0.05 else 'REVISE ESTIMATE'})")

cur.close(); conn.close()
