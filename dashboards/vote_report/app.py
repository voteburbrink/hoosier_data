import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

pd.set_option("styler.render.max_elements", 5_000_000)

st.set_page_config(
    page_title="Indiana Legislative Vote Record",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    """
    <div style="background:#1a3a5c;padding:10px 20px;border-bottom:3px solid #c8a951;margin-bottom:12px">
        <span style="color:#ffffff;font-size:20px;font-weight:bold;letter-spacing:.5px">
            Indiana Legislative Vote Record
        </span>
        <span style="color:#aac4e0;font-size:12px;margin-left:14px">
            Source: LegiScan · HOOSIER_DATA.RAW
        </span>
    </div>
    """,
    unsafe_allow_html=True,
)

# ── Connection ────────────────────────────────────────────────────────────────
_sf_session = get_active_session()


@st.cache_data(ttl=300, show_spinner=False)
def run_query(sql: str) -> pd.DataFrame:
    return _sf_session.sql(sql).to_pandas()


@st.cache_data(ttl=3600, show_spinner=False)
def load_sessions() -> dict:
    df = run_query("""
        SELECT SESSION_ID, LEFT(MAX(STATUS_DATE), 4) AS YR
        FROM HOOSIER_DATA.RAW.LEGISCAN_BILLS
        GROUP BY SESSION_ID
        ORDER BY SESSION_ID DESC
    """)
    return {
        f"{int(row.YR)} - Session {row.SESSION_ID}": row.SESSION_ID
        for row in df.itertuples()
    }


# ── Sidebar ───────────────────────────────────────────────────────────────────
def _esc(s: str) -> str:
    return s.replace("'", "''")


with st.sidebar:
    st.markdown("### Report Parameters")

    session_map = load_sessions()
    session_label = st.selectbox("Session", list(session_map.keys()), index=0)
    session_id = session_map[session_label]
    chamber    = st.selectbox("Chamber", ["Both", "House", "Senate"])
    party      = st.selectbox("Party",   ["Both", "D", "R"])
    vote_result = st.selectbox("Vote",   ["All", "Yea", "Nay", "NV"])
    vote_desc_kw = st.text_input("Vote description contains", "Third reading")
    bill_kw      = st.text_input("Bill number (e.g. HB1001)", "")
    district_kw  = st.text_input("District (e.g. HD-059)", "")

    st.markdown("---")
    run = st.button("▶  Run Report", type="primary", use_container_width=True)
    if st.button("↺  Clear cache", use_container_width=True):
        run_query.clear()
        load_sessions.clear()
        st.rerun()

# ── SQL ───────────────────────────────────────────────────────────────────────
clauses = [f"b.SESSION_ID = '{_esc(str(session_id))}'"]

if chamber != "Both":
    clauses.append(f"rc.CHAMBER = '{_esc(chamber)}'")
if party != "Both":
    clauses.append(f"p.PARTY = '{_esc(party)}'")
if vote_result != "All":
    clauses.append(f"v.VOTE_DESC = '{_esc(vote_result)}'")
if vote_desc_kw.strip():
    clauses.append(f"LOWER(rc.DESCRIPTION) LIKE LOWER('%{_esc(vote_desc_kw.strip())}%')")
if bill_kw.strip():
    clauses.append(f"b.BILL_NUMBER ILIKE '%{_esc(bill_kw.strip())}%'")
if district_kw.strip():
    clauses.append(f"p.DISTRICT ILIKE '%{_esc(district_kw.strip())}%'")

where = " AND ".join(clauses)

SQL = f"""
SELECT
    p.NAME                              AS "Legislator",
    p.PARTY                             AS "Party",
    p.DISTRICT                          AS "District",
    p.ROLE                              AS "Chamber",
    b.BILL_NUMBER                       AS "Bill",
    LEFT(b.TITLE, 90)                   AS "Title",
    b.STATUS_DESC                       AS "Bill Status",
    rc.DATE                             AS "Vote Date",
    rc.DESCRIPTION                      AS "Vote Description",
    v.VOTE_DESC                         AS "Vote",
    TRY_CAST(rc.YEA AS INTEGER)         AS "Yeas",
    TRY_CAST(rc.NAY AS INTEGER)         AS "Nays",
    b.URL                               AS "LegiScan URL"
FROM  HOOSIER_DATA.RAW.LEGISCAN_VOTES      v
JOIN  HOOSIER_DATA.RAW.LEGISCAN_PEOPLE     p   ON v.PEOPLE_ID    = p.PEOPLE_ID
JOIN  HOOSIER_DATA.RAW.LEGISCAN_ROLLCALLS  rc  ON v.ROLL_CALL_ID = rc.ROLL_CALL_ID
JOIN  HOOSIER_DATA.RAW.LEGISCAN_BILLS      b   ON rc.BILL_ID     = b.BILL_ID
WHERE {where}
QUALIFY ROW_NUMBER() OVER (PARTITION BY v.ROLL_CALL_ID, v.PEOPLE_ID ORDER BY p.ROLE_ID) = 1
ORDER BY rc.DATE DESC, b.BILL_NUMBER, p.LAST_NAME
"""

# ── Execute ───────────────────────────────────────────────────────────────────
SPONSOR_SQL = f"""
SELECT
    b.BILL_NUMBER                           AS "Bill",
    MAX(CASE WHEN s.POSITION = '1' THEN p.NAME  END) AS "Primary Sponsor",
    MAX(CASE WHEN s.POSITION = '1' THEN p.PARTY END) AS "Sponsor Party",
    COUNT(CASE WHEN s.POSITION = '2' THEN 1 END)     AS "Cosponsors"
FROM  HOOSIER_DATA.RAW.LEGISCAN_SPONSORS s
JOIN  HOOSIER_DATA.RAW.LEGISCAN_BILLS    b ON s.BILL_ID    = b.BILL_ID
JOIN  HOOSIER_DATA.RAW.LEGISCAN_PEOPLE   p ON s.PEOPLE_ID  = p.PEOPLE_ID
WHERE b.SESSION_ID = '{_esc(str(session_id))}'
GROUP BY b.BILL_NUMBER
"""

SPONSORED_BY_SQL = f"""
SELECT
    p.NAME          AS "Legislator",
    COUNT(DISTINCT CASE WHEN s.POSITION = '1' THEN s.BILL_ID END) AS "Bills Sponsored",
    COUNT(DISTINCT CASE WHEN s.POSITION = '2' THEN s.BILL_ID END) AS "Bills Cosponsored"
FROM  HOOSIER_DATA.RAW.LEGISCAN_SPONSORS s
JOIN  HOOSIER_DATA.RAW.LEGISCAN_BILLS    b ON s.BILL_ID   = b.BILL_ID
JOIN  HOOSIER_DATA.RAW.LEGISCAN_PEOPLE   p ON s.PEOPLE_ID = p.PEOPLE_ID
WHERE b.SESSION_ID = '{_esc(str(session_id))}'
GROUP BY p.NAME
"""

if run or "report_df" not in st.session_state:
    with st.spinner("Querying Snowflake…"):
        try:
            st.session_state["report_df"]      = run_query(SQL)
            st.session_state["report_sql"]     = SQL
            st.session_state["sponsor_df"]     = run_query(SPONSOR_SQL)
            st.session_state["sponsored_df"]   = run_query(SPONSORED_BY_SQL)
        except Exception as exc:
            st.error(f"Query error: {exc}")
            st.stop()

df: pd.DataFrame = st.session_state.get("report_df", pd.DataFrame())

if not df.empty:
    df["Margin"] = pd.to_numeric(df["Yeas"], errors="coerce") - pd.to_numeric(df["Nays"], errors="coerce")

if df.empty:
    st.warning("No rows returned. Try broadening your filters.")
    with st.expander("View SQL"):
        st.code(SQL, language="sql")
    st.stop()

# ── KPIs ──────────────────────────────────────────────────────────────────────
k1, k2, k3, k4, k5, k6 = st.columns(6)
k1.metric("Rows",        f"{len(df):,}")
k2.metric("Bills",       f"{df['Bill'].nunique():,}")
k3.metric("Legislators", f"{df['Legislator'].nunique():,}")
k4.metric("Yea",         f"{(df['Vote'] == 'Yea').sum():,}")
k5.metric("Nay",         f"{(df['Vote'] == 'Nay').sum():,}")
k6.metric("NV / Absent", f"{df['Vote'].isin(['NV','Absent']).sum():,}")

st.markdown("---")

# ── Tabs ──────────────────────────────────────────────────────────────────────
tab_detail, tab_bills, tab_alignment = st.tabs(
    ["Vote Detail", "Bill Summary", "Legislator Alignment"]
)

# ── Tab 1: Vote Detail ────────────────────────────────────────────────────────
with tab_detail:
    chart_col, _ = st.columns([1, 3])
    with chart_col:
        st.markdown("**Vote by Party**")
        pv = (
            df.groupby(["Party", "Vote"])
            .size()
            .reset_index(name="Count")
            .pivot(index="Party", columns="Vote", values="Count")
            .fillna(0)
        )
        st.bar_chart(pv)

    DETAIL_COLS = [
        "Legislator", "Party", "District", "Chamber",
        "Bill", "Title", "Bill Status", "Vote Date",
        "Vote Description", "Vote", "Yeas", "Nays", "Margin",
    ]

    def _style_row(row):
        styles = [""] * len(row)
        idx = list(row.index)
        vote_i  = idx.index("Vote")  if "Vote"  in idx else None
        party_i = idx.index("Party") if "Party" in idx else None
        if vote_i is not None:
            if row["Vote"] == "Yea":
                styles[vote_i] = "background-color:#d4edda;color:#155724;font-weight:600"
            elif row["Vote"] == "Nay":
                styles[vote_i] = "background-color:#f8d7da;color:#721c24;font-weight:600"
        if party_i is not None:
            if row["Party"] == "D":
                styles[party_i] = "background-color:#cce0ff;color:#003380;font-weight:600"
            elif row["Party"] == "R":
                styles[party_i] = "background-color:#ffd9d9;color:#7a0000;font-weight:600"
        return styles

    styled = df[DETAIL_COLS].style.apply(_style_row, axis=1)

    st.dataframe(
        styled,
        hide_index=True,
        use_container_width=True,
        height=500,
        column_config={
            "Bill": st.column_config.LinkColumn(
                "Bill",
                display_text=r"(H|S)B\d+",
            ),
        },
    )

    dl_col, sql_col = st.columns([1, 3])
    with dl_col:
        st.download_button(
            "⬇  Export CSV",
            data=df[DETAIL_COLS].to_csv(index=False).encode(),
            file_name="vote_detail.csv",
            mime="text/csv",
        )
    with sql_col:
        with st.expander("View SQL"):
            st.code(st.session_state.get("report_sql", SQL), language="sql")

# ── Tab 2: Bill Summary ───────────────────────────────────────────────────────
with tab_bills:
    bill_sum = (
        df.groupby(["Bill", "Title", "Bill Status"])
        .agg(
            Yeas=("Yeas", "first"),
            Nays=("Nays", "first"),
            Margin=("Margin", "first"),
            D_Yea=("Vote", lambda s: ((df.loc[s.index, "Party"] == "D") & (s == "Yea")).sum()),
            D_Nay=("Vote", lambda s: ((df.loc[s.index, "Party"] == "D") & (s == "Nay")).sum()),
            R_Yea=("Vote", lambda s: ((df.loc[s.index, "Party"] == "R") & (s == "Yea")).sum()),
            R_Nay=("Vote", lambda s: ((df.loc[s.index, "Party"] == "R") & (s == "Nay")).sum()),
        )
        .reset_index()
        .sort_values("Bill")
    )

    sponsor_df = st.session_state.get("sponsor_df", pd.DataFrame())
    if not sponsor_df.empty:
        bill_sum = bill_sum.merge(sponsor_df, on="Bill", how="left")
        cols = ["Bill", "Title", "Bill Status", "Primary Sponsor", "Sponsor Party",
                "Cosponsors", "Yeas", "Nays", "Margin", "D_Yea", "D_Nay", "R_Yea", "R_Nay"]
        bill_sum = bill_sum[[c for c in cols if c in bill_sum.columns]]

    def _style_status(val):
        if val == "Passed":
            return "background-color:#d4edda;color:#155724"
        if val in ("Failed", "Vetoed"):
            return "background-color:#f8d7da;color:#721c24"
        return ""

    def _style_sponsor_party(val):
        if val == "D":
            return "background-color:#cce0ff;color:#003380;font-weight:600"
        if val == "R":
            return "background-color:#ffd9d9;color:#7a0000;font-weight:600"
        return ""

    style_cols = {"Bill Status": _style_status}
    if "Sponsor Party" in bill_sum.columns:
        style_cols["Sponsor Party"] = _style_sponsor_party

    styled_bills = bill_sum.style
    for col, fn in style_cols.items():
        styled_bills = styled_bills.map(fn, subset=[col])

    st.dataframe(styled_bills, hide_index=True, use_container_width=True, height=500)

    st.download_button(
        "⬇  Export CSV",
        data=bill_sum.to_csv(index=False).encode(),
        file_name="bill_summary.csv",
        mime="text/csv",
    )

# ── Tab 3: Legislator Alignment ───────────────────────────────────────────────
with tab_alignment:
    st.caption("How each legislator voted across all bills in the filtered result set.")

    align = (
        df.groupby(["Legislator", "Party", "District", "Chamber"])
        .agg(
            Total=("Vote", "count"),
            Yea=("Vote", lambda s: (s == "Yea").sum()),
            Nay=("Vote", lambda s: (s == "Nay").sum()),
            NV =("Vote", lambda s: s.isin(["NV", "Absent"]).sum()),
        )
        .reset_index()
    )
    align["Yea %"] = (align["Yea"] / align["Total"] * 100).round(1)
    align["Nay %"] = (align["Nay"] / align["Total"] * 100).round(1)

    sponsored_df = st.session_state.get("sponsored_df", pd.DataFrame())
    if not sponsored_df.empty:
        align = align.merge(sponsored_df, on="Legislator", how="left")
        align["Bills Sponsored"]   = align["Bills Sponsored"].fillna(0).astype(int)
        align["Bills Cosponsored"] = align["Bills Cosponsored"].fillna(0).astype(int)

    align = align.sort_values(["Party", "Nay %"], ascending=[True, False])

    def _style_align(row):
        styles = [""] * len(row)
        idx = list(row.index)
        p_i = idx.index("Party") if "Party" in idx else None
        y_i = idx.index("Yea %") if "Yea %" in idx else None
        n_i = idx.index("Nay %") if "Nay %" in idx else None
        if p_i is not None:
            if row["Party"] == "D":
                styles[p_i] = "background-color:#cce0ff;color:#003380;font-weight:600"
            elif row["Party"] == "R":
                styles[p_i] = "background-color:#ffd9d9;color:#7a0000;font-weight:600"
        if y_i is not None and row.get("Yea %", 0) >= 80:
            styles[y_i] = "background-color:#d4edda;color:#155724"
        if n_i is not None and row.get("Nay %", 0) >= 50:
            styles[n_i] = "background-color:#f8d7da;color:#721c24"
        return styles

    st.dataframe(
        align.style.apply(_style_align, axis=1),
        hide_index=True,
        use_container_width=True,
        height=500,
    )

    st.download_button(
        "⬇  Export CSV",
        data=align.to_csv(index=False).encode(),
        file_name="legislator_alignment.csv",
        mime="text/csv",
    )
