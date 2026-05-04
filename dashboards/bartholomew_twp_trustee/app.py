import streamlit as st
import pandas as pd
import altair as alt
import numpy as np
from typing import Optional
from snowflake.snowpark.context import get_active_session

st.set_page_config(
    page_title="Bartholomew Township Trustee Dashboard",
    layout="wide",
)

APP_TITLE = "Bartholomew County Township Trustee Dashboard"
DB = "HOOSIER_DATA"
SCHEMA = "ANALYTICS"

VIEW_REV_VS_EXP  = f"{DB}.{SCHEMA}.BARTHOLOMEW_TWP_REV_VS_EXP"
VIEW_2024        = f"{DB}.{SCHEMA}.BARTHOLOMEW_TWP_2024_SNAPSHOT"
VIEW_CATEGORY    = f"{DB}.{SCHEMA}.BARTHOLOMEW_TWP_SPENDING_BY_CATEGORY"
VIEW_YOY         = f"{DB}.{SCHEMA}.BARTHOLOMEW_TWP_YOY_GROWTH"
VIEW_SUMMARY     = f"{DB}.{SCHEMA}.BARTHOLOMEW_COUNTY_SUMMARY"
VIEW_POOR_RELIEF = f"{DB}.{SCHEMA}.BARTHOLOMEW_TWP_POOR_RELIEF"
VIEW_TA7         = f"{DB}.{SCHEMA}.BARTHOLOMEW_TWP_TA7"

session = get_active_session()


@st.cache_data(ttl=600, show_spinner=False)
def load_df(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


def money(value) -> str:
    if pd.isna(value):
        return "N/A"
    return f"${value:,.0f}"


def pct(value) -> str:
    if pd.isna(value):
        return "N/A"
    return f"{value:,.1f}%"


def detect_spikes(series: pd.Series, threshold: float = 0.30) -> pd.Series:
    """Flag interior years that exceed both neighbors by more than threshold."""
    result = pd.Series(False, index=series.index)
    arr    = series.values
    idx    = series.index.tolist()
    for pos in range(1, len(arr) - 1):
        prev, curr, nxt = arr[pos - 1], arr[pos], arr[pos + 1]
        if prev > 0 and nxt > 0 and curr > 0:
            if curr > prev * (1 + threshold) and curr > nxt * (1 + threshold):
                result[idx[pos]] = True
    return result


def is_end_of_series_spike(
    series: pd.Series, threshold: float = 0.40, lookback: int = 3
) -> bool:
    """Return True if the last value significantly exceeds the trailing N-year average."""
    arr = series.values
    if len(arr) < lookback + 1:
        return False
    last         = float(arr[-1])
    trailing_avg = float(np.mean(arr[-(lookback + 1):-1]))
    return trailing_avg > 0 and last > trailing_avg * (1 + threshold)


def get_spike_annotations(
    df: pd.DataFrame,
    metric: str,
    township: str,
    category_df: pd.DataFrame,
) -> pd.DataFrame:
    indexed     = df.set_index("YEAR")[metric].astype(float)
    mask        = detect_spikes(indexed)
    spike_years = [yr for yr, flagged in mask.items() if flagged]

    if is_end_of_series_spike(indexed):
        last_yr = int(indexed.index[-1])
        if last_yr not in spike_years:
            spike_years.append(last_yr)

    if not spike_years:
        return pd.DataFrame()

    rows = []
    for year in spike_years:
        if year not in df["YEAR"].values:
            continue
        amount = float(df[df["YEAR"] == year][metric].values[0])
        curr   = category_df[(category_df["TOWNSHIP"] == township) & (category_df["YEAR"] == year)]
        prev   = category_df[(category_df["TOWNSHIP"] == township) & (category_df["YEAR"] == year - 1)]
        label  = "one-time"
        if not curr.empty and not prev.empty:
            merged = curr.merge(prev, on="CATEGORY", suffixes=("_c", "_p"))
            merged["delta"] = merged["AMOUNT_c"] - merged["AMOUNT_p"]
            top = merged.nlargest(1, "delta")
            if not top.empty:
                cat   = top.iloc[0]["CATEGORY"]
                delta = int(top.iloc[0]["delta"])
                label = f"{cat} +${delta:,}"
        rows.append({"YEAR": year, "Amount": amount, "Label": label})

    return pd.DataFrame(rows)


# --------------------------------------------------
# Header
# --------------------------------------------------
st.title(APP_TITLE)
st.caption(
    "Revenue, expenditure, spending categories, year-over-year trends, "
    "policy-aware forecasts, and township assistance accountability. "
    "Data: Indiana Gateway public financial reports."
)
st.warning(
    "Forecasts are illustrative scenarios based on historical trends and policy assumptions. "
    "They are not official budgets or financial projections."
)

# --------------------------------------------------
# Load data
# --------------------------------------------------
summary_df     = load_df(f"SELECT * FROM {VIEW_SUMMARY} ORDER BY YEAR DESC")
rev_exp_df     = load_df(f"SELECT * FROM {VIEW_REV_VS_EXP} ORDER BY YEAR, TOWNSHIP")
snapshot_df    = load_df(f"SELECT * FROM {VIEW_2024} ORDER BY SURPLUS_DEFICIT DESC")
category_df    = load_df(f"SELECT * FROM {VIEW_CATEGORY} ORDER BY YEAR, TOWNSHIP, AMOUNT DESC")
yoy_df         = load_df(f"SELECT * FROM {VIEW_YOY} ORDER BY YEAR, TOWNSHIP")
poor_relief_df = load_df(f"SELECT * FROM {VIEW_POOR_RELIEF} ORDER BY YEAR, TOWNSHIP")
ta7_df         = load_df(f"SELECT * FROM {VIEW_TA7} ORDER BY YEAR, TOWNSHIP")

for df in [summary_df, rev_exp_df, snapshot_df, category_df, yoy_df]:
    if "YEAR" in df.columns:
        df["YEAR"] = df["YEAR"].astype(int)

for df in [poor_relief_df, ta7_df]:
    if "YEAR" in df.columns:
        df["YEAR"] = pd.to_numeric(df["YEAR"], errors="coerce").astype("Int64")

# --------------------------------------------------
# Sidebar
# --------------------------------------------------
st.sidebar.header("Filters")

available_years = sorted(rev_exp_df["YEAR"].dropna().unique().tolist())
min_year, max_year = min(available_years), max(available_years)
selected_year_range = st.sidebar.slider(
    "Year range",
    min_value=int(min_year), max_value=int(max_year),
    value=(int(min_year), int(max_year)), step=1,
)

townships = sorted(rev_exp_df["TOWNSHIP"].dropna().unique().tolist())
selected_township = st.sidebar.selectbox("Township", townships, index=0)

category_options = sorted(category_df["CATEGORY"].dropna().unique().tolist())
selected_categories = st.sidebar.multiselect(
    "Spending categories", category_options, default=category_options,
)

st.sidebar.divider()
st.sidebar.header("Forecast")
show_forecast = st.sidebar.toggle("Show forecast", value=True)
adjust_outliers = st.sidebar.toggle(
    "Flag one-time expenditure spikes",
    value=True,
    help=(
        "Marks years where spending spiked significantly above both neighbors (interior spike) "
        "or above the 3-year trailing average (end-of-series spike). "
        "Flagged years are excluded from the growth rate and the forecast anchors "
        "to a smoothed baseline rather than the inflated value."
    ),
)
forecast_method = st.sidebar.selectbox(
    "Baseline forecast method",
    ["3-year CAGR", "Average YoY growth", "Flat from latest year"],
    index=0,
)
forecast_years = st.sidebar.slider("Forecast years", min_value=1, max_value=5, value=5, step=1)

st.sidebar.subheader("SEA-1 scenario")
sea1_scenario = st.sidebar.selectbox(
    "Scenario",
    ["Baseline only", "Potential SEA-1 impact", "Moderate SEA-1 impact",
     "Severe SEA-1 impact", "Custom SEA-1 impact"],
    index=1,
)

target_revenue_growth_cap: Optional[float] = None
sea1_revenue_impact = 0.0

if sea1_scenario == "Potential SEA-1 impact":
    target_revenue_growth_cap = st.sidebar.slider(
        "Assumed post-SEA-1 revenue growth cap (%)",
        min_value=-5, max_value=10, value=3, step=1,
        help=(
            "SEA-1 constrains property tax levy growth. Set the estimated annual cap. "
            "The implied revenue impact is the difference between this cap and the "
            "township's historical growth rate."
        ),
    ) / 100
elif sea1_scenario == "Moderate SEA-1 impact":
    sea1_revenue_impact = -0.05
elif sea1_scenario == "Severe SEA-1 impact":
    sea1_revenue_impact = -0.10
elif sea1_scenario == "Custom SEA-1 impact":
    sea1_revenue_impact = st.sidebar.slider(
        "Annual revenue impact vs baseline (%)",
        min_value=-30, max_value=10, value=-5, step=1,
    ) / 100

expense_response = st.sidebar.slider(
    "Expense response to revenue pressure (%)",
    min_value=0, max_value=100, value=25, step=5,
    help=(
        "Percent of SEA-1 revenue impact reflected in lower expenditure growth. "
        "0% = spending unchanged. 100% = spending cut by same amount as revenue loss."
    ),
) / 100

with st.sidebar.expander("Model dictionary"):
    st.markdown("""
**3-year CAGR** - Compound annual growth rate over the most recent 3-4 year window,
excluding one-time spike years.

**Average YoY growth** - Mean of recent year-over-year percentage changes.

**Flat from latest year** - Carries the most recent year forward at 0% growth.

**Flag one-time spikes** - Identifies years where spending jumped significantly above
both neighboring years (interior spike) or above the 3-year trailing average
(end-of-series spike, e.g., a one-time fund transfer in the most recent data year).
Flagged years are excluded from the growth rate. When the most recent year is flagged,
the forecast anchors to the 3-year trailing average rather than the inflated value.

**Potential SEA-1 impact** - Revenue growth constrained to a user-set cap. The implied
impact is the difference between that cap and the historical growth rate.

**Moderate SEA-1 impact** - Fixed -5% annual revenue adjustment vs baseline.

**Severe SEA-1 impact** - Fixed -10% annual revenue adjustment vs baseline.

**Custom SEA-1 impact** - Manual annual revenue adjustment.

**Expense response** - Fraction of SEA-1 revenue impact passed through to lower
expenditure growth. Fixed costs limit how much is feasible in practice.

---

**What is SEA-1?** Indiana Senate Enrolled Act 1 (2025) caps assessed value growth
and constrains local government levy increases. Townships funded almost entirely through
property taxes face compressed revenue growth while costs continue rising, producing a
widening structural deficit over the next five years.
    """)

st.sidebar.divider()
st.sidebar.caption("Data: Indiana Gateway - HOOSIER_DATA.ANALYTICS")


# --------------------------------------------------
# Forecast engine
# --------------------------------------------------
def build_forecast(
    df: pd.DataFrame,
    township: str,
    years_forward: int,
    method: str,
    scenario_name: str,
    revenue_policy_impact: float = 0.0,
    expense_policy_response: float = 0.0,
    target_revenue_growth_cap: Optional[float] = None,
    adjust_outliers_flag: bool = True,
) -> pd.DataFrame:
    hist = df[df["TOWNSHIP"] == township].copy().sort_values("YEAR")
    if hist.empty:
        return pd.DataFrame()

    latest      = hist.iloc[-1]
    latest_year = int(latest["YEAR"])

    def growth_rate(metric: str) -> float:
        mh = hist[["YEAR", metric]].dropna().copy()
        mh = mh[mh[metric] > 0]
        if adjust_outliers_flag and len(mh) >= 4:
            indexed    = mh.set_index("YEAR")[metric].astype(float)
            spike_mask = detect_spikes(indexed)
            spike_yrs  = [yr for yr, flagged in spike_mask.items() if flagged]
            mh = mh[~mh["YEAR"].isin(spike_yrs)]
        if len(mh) < 2:
            return 0.0
        if method == "Flat from latest year":
            return 0.0
        if method == "Average YoY growth":
            yoy = mh[metric].pct_change().replace([float("inf"), -float("inf")], pd.NA).dropna()
            return float(yoy.tail(3).mean()) if not yoy.empty else 0.0
        recent = mh.tail(4)
        if len(recent) < 2:
            return 0.0
        first, last = recent.iloc[0], recent.iloc[-1]
        periods = int(last["YEAR"] - first["YEAR"])
        if periods <= 0 or first[metric] <= 0:
            return 0.0
        return float((last[metric] / first[metric]) ** (1 / periods) - 1)

    base_rev_g = growth_rate("REVENUE")
    base_exp_g = growth_rate("EXPENDITURE")

    if target_revenue_growth_cap is not None:
        revenue_policy_impact = target_revenue_growth_cap - base_rev_g

    adj_rev_g = base_rev_g + revenue_policy_impact
    adj_exp_g = base_exp_g + (revenue_policy_impact * expense_policy_response)

    exp_series = hist.set_index("YEAR")["EXPENDITURE"].astype(float)
    rev_series = hist.set_index("YEAR")["REVENUE"].astype(float)

    if adjust_outliers_flag and is_end_of_series_spike(exp_series):
        lookback    = min(3, len(exp_series) - 1)
        expenditure = float(exp_series.iloc[-(lookback + 1):-1].mean())
    else:
        expenditure = float(latest["EXPENDITURE"])

    if adjust_outliers_flag and is_end_of_series_spike(rev_series):
        lookback = min(3, len(rev_series) - 1)
        revenue  = float(rev_series.iloc[-(lookback + 1):-1].mean())
    else:
        revenue = float(latest["REVENUE"])

    rows = []
    for step in range(1, years_forward + 1):
        revenue     *= 1 + adj_rev_g
        expenditure *= 1 + adj_exp_g
        rows.append({
            "YEAR":                        latest_year + step,
            "TOWNSHIP":                    township,
            "EXPENDITURE":                 round(expenditure),
            "REVENUE":                     round(revenue),
            "SURPLUS_DEFICIT":             round(revenue - expenditure),
            "FISCAL_STATUS":               "Surplus" if revenue >= expenditure else "Deficit",
            "DATA_TYPE":                   "Forecast",
            "SCENARIO":                    scenario_name,
            "BASELINE_REVENUE_GROWTH":     base_rev_g,
            "BASELINE_EXPENDITURE_GROWTH": base_exp_g,
            "TARGET_REVENUE_GROWTH_CAP":   target_revenue_growth_cap,
            "SEA1_REVENUE_IMPACT":         revenue_policy_impact,
            "EXPENSE_RESPONSE":            expense_policy_response,
            "ADJUSTED_REVENUE_GROWTH":     adj_rev_g,
            "ADJUSTED_EXPENDITURE_GROWTH": adj_exp_g,
        })

    return pd.DataFrame(rows)


# --------------------------------------------------
# Chart helpers
# --------------------------------------------------
COLOR_INCOME   = "#E6B800"
COLOR_SPENDING = "#1f77b4"
COLOR_DEFICIT  = "#D62728"
COLOR_SURPLUS  = "#2CA02C"
COLOR_OUTLIER  = "#FF7F0E"


def make_spend_vs_income_chart(
    data: pd.DataFrame,
    township: str,
    category_df: pd.DataFrame,
    show_outlier_marks: bool = True,
) -> alt.Chart:
    long_df = data.melt(
        id_vars=["YEAR", "TOWNSHIP", "DATA_TYPE", "SCENARIO"],
        value_vars=["REVENUE", "EXPENDITURE"],
        var_name="Metric", value_name="Amount",
    )
    long_df["Metric"] = long_df["Metric"].replace({
        "REVENUE": "Tax income", "EXPENDITURE": "Spending",
    })
    label_df    = long_df.sort_values("YEAR").groupby("Metric", as_index=False).tail(1)
    color_scale = alt.Scale(domain=["Tax income", "Spending"], range=[COLOR_INCOME, COLOR_SPENDING])

    line = (
        alt.Chart(long_df)
        .mark_line(point=True, strokeWidth=3)
        .encode(
            x=alt.X("YEAR:O", title="Year"),
            y=alt.Y("Amount:Q", title="Amount", axis=alt.Axis(format="$,.0f")),
            color=alt.Color("Metric:N", title="Metric", scale=color_scale),
            strokeDash=alt.StrokeDash(
                "DATA_TYPE:N",
                scale=alt.Scale(domain=["Actual", "Forecast"], range=[[1, 0], [4, 4]]),
                legend=None,
            ),
            tooltip=[
                alt.Tooltip("YEAR:O",      title="Year"),
                alt.Tooltip("SCENARIO:N",  title="Scenario"),
                alt.Tooltip("Metric:N"),
                alt.Tooltip("DATA_TYPE:N", title="Type"),
                alt.Tooltip("Amount:Q",    title="Amount", format="$,.0f"),
            ],
        )
    )
    labels = (
        alt.Chart(label_df)
        .mark_text(align="left", dx=8, fontSize=12)
        .encode(
            x=alt.X("YEAR:O"),
            y=alt.Y("Amount:Q"),
            text=alt.Text("Metric:N"),
            color=alt.Color("Metric:N", legend=None, scale=color_scale),
        )
    )
    chart = line + labels

    if show_outlier_marks:
        actual = data[data["DATA_TYPE"] == "Actual"].copy()
        ann_frames = []
        for metric in ["EXPENDITURE", "REVENUE"]:
            ann = get_spike_annotations(actual, metric, township, category_df)
            if not ann.empty:
                ann_frames.append(ann)
        if ann_frames:
            ann_df   = pd.concat(ann_frames, ignore_index=True)
            diamonds = (
                alt.Chart(ann_df)
                .mark_point(shape="diamond", size=130, color=COLOR_OUTLIER, filled=True)
                .encode(
                    x=alt.X("YEAR:O"),
                    y=alt.Y("Amount:Q"),
                    tooltip=[
                        alt.Tooltip("YEAR:O",   title="Year"),
                        alt.Tooltip("Label:N",  title="Spike driver"),
                        alt.Tooltip("Amount:Q", title="Amount", format="$,.0f"),
                    ],
                )
            )
            ann_text = (
                alt.Chart(ann_df)
                .mark_text(dy=-14, fontSize=10, color=COLOR_OUTLIER)
                .encode(
                    x=alt.X("YEAR:O"),
                    y=alt.Y("Amount:Q"),
                    text=alt.Text("Label:N"),
                )
            )
            chart = chart + diamonds + ann_text

    return chart.properties(height=360)


def make_gap_chart(data: pd.DataFrame) -> alt.Chart:
    cols     = ["YEAR", "TOWNSHIP", "DATA_TYPE", "SCENARIO", "SURPLUS_DEFICIT"]
    gap_df   = data[cols].copy()
    label_df = gap_df.sort_values("YEAR").tail(1)
    zero_rule = (
        alt.Chart(gap_df).mark_rule(strokeDash=[4, 4], color="#888").encode(y=alt.datum(0))
    )
    line = (
        alt.Chart(gap_df)
        .mark_line(point=True, strokeWidth=3)
        .encode(
            x=alt.X("YEAR:O", title="Year"),
            y=alt.Y("SURPLUS_DEFICIT:Q", title="Revenue minus spending",
                    axis=alt.Axis(format="$,.0f")),
            color=alt.Color(
                "DATA_TYPE:N", title="Type",
                scale=alt.Scale(domain=["Actual", "Forecast"],
                                range=[COLOR_SPENDING, COLOR_OUTLIER]),
            ),
            strokeDash=alt.StrokeDash(
                "DATA_TYPE:N",
                scale=alt.Scale(domain=["Actual", "Forecast"], range=[[1, 0], [4, 4]]),
                legend=None,
            ),
            tooltip=[
                alt.Tooltip("YEAR:O",            title="Year"),
                alt.Tooltip("SCENARIO:N",        title="Scenario"),
                alt.Tooltip("DATA_TYPE:N",       title="Type"),
                alt.Tooltip("SURPLUS_DEFICIT:Q", title="Revenue minus spending", format="$,.0f"),
            ],
        )
    )
    labels = (
        alt.Chart(label_df)
        .mark_text(align="left", dx=8, fontSize=12)
        .encode(
            x=alt.X("YEAR:O"),
            y=alt.Y("SURPLUS_DEFICIT:Q"),
            text=alt.Text("SCENARIO:N"),
            color=alt.Color(
                "DATA_TYPE:N", legend=None,
                scale=alt.Scale(domain=["Actual", "Forecast"],
                                range=[COLOR_SPENDING, COLOR_OUTLIER]),
            ),
        )
    )
    return (zero_rule + line + labels).properties(height=360)


# --------------------------------------------------
# Filter / prepare data
# --------------------------------------------------
year_start, year_end = selected_year_range
rev_exp_filtered = rev_exp_df[
    (rev_exp_df["YEAR"] >= year_start) & (rev_exp_df["YEAR"] <= year_end)
]
township_trend = rev_exp_filtered[rev_exp_filtered["TOWNSHIP"] == selected_township].copy()
township_trend["DATA_TYPE"] = "Actual"
township_trend["SCENARIO"]  = "Actual"

forecast_frames = []
if show_forecast:
    forecast_frames.append(build_forecast(
        rev_exp_df, selected_township, forecast_years, forecast_method, "Baseline",
        adjust_outliers_flag=adjust_outliers,
    ))
    if sea1_scenario != "Baseline only":
        forecast_frames.append(build_forecast(
            rev_exp_df, selected_township, forecast_years, forecast_method, sea1_scenario,
            revenue_policy_impact=sea1_revenue_impact,
            expense_policy_response=expense_response,
            target_revenue_growth_cap=target_revenue_growth_cap,
            adjust_outliers_flag=adjust_outliers,
        ))

forecast_df = pd.concat(forecast_frames, ignore_index=True) if forecast_frames else pd.DataFrame()

category_filtered = category_df[
    (category_df["YEAR"] >= year_start) & (category_df["YEAR"] <= year_end)
    & (category_df["TOWNSHIP"] == selected_township)
    & (category_df["CATEGORY"].isin(selected_categories))
]
yoy_filtered = yoy_df[
    (yoy_df["YEAR"] >= year_start) & (yoy_df["YEAR"] <= year_end)
]
latest_summary = summary_df.iloc[0] if not summary_df.empty else None


# --------------------------------------------------
# KPI row
# --------------------------------------------------
st.subheader("County Overview")
if latest_summary is not None:
    kpi_year = int(latest_summary["YEAR"])
    c1, c2, c3, c4, c5 = st.columns(5)
    c1.metric("Latest year",              f"{kpi_year}")
    c2.metric("Total revenue",            money(latest_summary["TOTAL_REVENUE"]))
    c3.metric("Total expenditure",        money(latest_summary["TOTAL_EXPENDITURE"]))
    c4.metric("County surplus / deficit", money(latest_summary["COUNTY_SURPLUS_DEFICIT"]))
    c5.metric("Townships",                f"{int(latest_summary['TOWNSHIP_COUNT']):,}")
    st.caption(
        f"Largest spending township in {kpi_year}: {latest_summary['LARGEST_TOWNSHIP']} "
        f"({money(latest_summary['LARGEST_EXPENDITURE'])}, "
        f"{pct(latest_summary['LARGEST_TWP_SHARE_PCT'])} of total expenditure)."
    )
else:
    st.warning("No county summary records found.")

if show_forecast and not forecast_df.empty:
    final_year = int(forecast_df["YEAR"].max())
    final_fc   = forecast_df[forecast_df["YEAR"] == final_year]
    base_rows  = final_fc[final_fc["SCENARIO"] == "Baseline"]
    if not base_rows.empty:
        base_final = base_rows.iloc[0]
        if sea1_scenario != "Baseline only":
            sea1_rows = final_fc[final_fc["SCENARIO"] == sea1_scenario]
            if not sea1_rows.empty:
                sea1_final = sea1_rows.iloc[0]
                delta      = sea1_final["SURPLUS_DEFICIT"] - base_final["SURPLUS_DEFICIT"]
                if pd.notna(sea1_final["TARGET_REVENUE_GROWTH_CAP"]):
                    scenario_text = (
                        f"Revenue growth constrained to "
                        f"{sea1_final['TARGET_REVENUE_GROWTH_CAP']:.1%}/yr post-SEA-1 "
                        f"(implied annual revenue impact: {sea1_final['SEA1_REVENUE_IMPACT']:.1%})."
                    )
                else:
                    scenario_text = (
                        f"{sea1_scenario}: "
                        f"{sea1_final['SEA1_REVENUE_IMPACT']:.1%} annual revenue adjustment."
                    )
                st.info(
                    f"**{selected_township} SEA-1 forecast** | Method: {forecast_method} | "
                    f"{scenario_text} Expense response: {expense_response:.0%}. "
                    f"Projected {final_year} surplus/deficit: "
                    f"{money(sea1_final['SURPLUS_DEFICIT'])} ({money(delta)} vs baseline)."
                )
        else:
            st.info(
                f"**{selected_township} baseline forecast** | {forecast_method} | "
                f"Projected {final_year} surplus/deficit: {money(base_final['SURPLUS_DEFICIT'])}."
            )

st.divider()


# --------------------------------------------------
# Tabs
# --------------------------------------------------
(
    tab_sea1, tab_trends, tab_categories,
    tab_growth, tab_assistance, tab_explorer,
) = st.tabs([
    "SEA-1 Impact", "Trends and Forecast", "Category Spending",
    "YoY Growth", "Township Assistance", "Data Explorer",
])


# ======= SEA-1 Impact =============================
with tab_sea1:
    st.subheader("Senate Enrolled Act 1 - Fiscal Impact on Bartholomew County Townships")

    with st.expander("What is SEA-1 and how does it affect townships?", expanded=True):
        col_policy, col_winners = st.columns(2)

        with col_policy:
            st.markdown("""
#### What the Law Does

**Indiana Senate Enrolled Act 1 (2025)** is the most significant restructuring of
Indiana's property tax system in decades. Key provisions:

- Caps growth in net assessed value (NAV), limiting how fast the tax base can expand
- Introduces new homestead credits that reduce effective levy collections
- Constrains annual levy growth for townships, schools, libraries, and other local taxing units
- Shifts more of the revenue relief cost onto local governments rather than the state

**How townships are affected:**

Townships are funded almost entirely through property taxes. With the levy growth cap,
revenue that historically grew at 5-7% per year may be constrained to 2-4% or less.
Meanwhile, costs grow with inflation: employee salaries, utilities, contracted services.
Fixed costs cannot be easily reduced. The cumulative result is a structural
spending-revenue gap that widens each year.

**The 5-year risk window:**

- Years 1-2: Minor impact as townships absorb the constraint from existing fund balances
- Years 3-4: Deficits begin appearing for townships with thin reserves or high cost growth
- Year 5+: Structural deficits become unavoidable without service cuts or levy appeals
            """)

        with col_winners:
            st.markdown("""
#### Who Benefits, Who Pays

SEA-1 includes property tax credits for homeowners, but the legislation also
extends significant advantages to commercial and industrial property owners. Those
advantages are paid for, in part, by constraining the revenue available to local
governments like townships.

**Business and corporate provisions in SEA-1:**

- **Business Personal Property (BPP) tax relief** - Raises exemption thresholds for
  equipment, machinery, and inventory. Manufacturers and industrial operators receive
  reductions in personal property assessments.
- **Commercial assessment caps** - Limits on how quickly commercial real estate
  assessments can increase, compressing the revenue growth townships would otherwise capture.
- **Data center incentives** - Property tax abatements and exemptions for qualifying
  data center investments that often require substantial local infrastructure.
- **Industrial property methodology changes** - Modified assessment approaches that
  in many cases reduce taxable assessed value.

**The structural trade-off:**

The same levy constraint that limits what corporations pay also limits what townships
collect. A township cannot raise its levy to compensate for an assessment base
compressed by commercial caps or BPP exemptions. The revenue loss from each
business tax provision is effectively a permanent transfer from township budgets
to property owners.

*Source: Indiana LSA Fiscal Impact Analysis - SEA-1 (2025).*
            """)

    st.divider()

    if not show_forecast:
        st.info("Enable 'Show forecast' in the sidebar to see SEA-1 impact projections.")
    else:
        all_twps      = rev_exp_df["TOWNSHIP"].dropna().unique().tolist()
        baseline_rows = []
        sea1_rows_all = []

        for twp in all_twps:
            b = build_forecast(
                rev_exp_df, twp, forecast_years, forecast_method, "Baseline",
                adjust_outliers_flag=adjust_outliers,
            )
            if not b.empty:
                baseline_rows.append(b)
            if sea1_scenario != "Baseline only":
                s = build_forecast(
                    rev_exp_df, twp, forecast_years, forecast_method, sea1_scenario,
                    revenue_policy_impact=sea1_revenue_impact,
                    expense_policy_response=expense_response,
                    target_revenue_growth_cap=target_revenue_growth_cap,
                    adjust_outliers_flag=adjust_outliers,
                )
                if not s.empty:
                    sea1_rows_all.append(s)

        all_baseline = pd.concat(baseline_rows, ignore_index=True) if baseline_rows else pd.DataFrame()
        all_sea1     = pd.concat(sea1_rows_all,  ignore_index=True) if sea1_rows_all  else pd.DataFrame()

        if sea1_scenario == "Baseline only" or all_sea1.empty:
            st.info(
                "Select a SEA-1 scenario in the sidebar (other than 'Baseline only') "
                "to see the county-wide fiscal impact analysis."
            )
        elif not all_baseline.empty:
            final_yr = int(all_baseline["YEAR"].max())

            base_end = all_baseline[all_baseline["YEAR"] == final_yr][
                ["TOWNSHIP", "SURPLUS_DEFICIT", "EXPENDITURE", "REVENUE"]
            ].copy()
            sea1_end = all_sea1[all_sea1["YEAR"] == final_yr][["TOWNSHIP", "SURPLUS_DEFICIT"]].copy()
            base_end.columns = ["TOWNSHIP", "BASELINE_SURPLUS", "PROJ_EXPENDITURE", "PROJ_REVENUE"]
            sea1_end.columns  = ["TOWNSHIP", "SEA1_SURPLUS"]

            comparison = base_end.merge(sea1_end, on="TOWNSHIP", how="outer")
            comparison["FISCAL_IMPACT"] = comparison["SEA1_SURPLUS"] - comparison["BASELINE_SURPLUS"]
            comparison["BASE_STATUS"]   = comparison["BASELINE_SURPLUS"].apply(
                lambda x: "Surplus" if x >= 0 else "Deficit"
            )
            comparison["SEA1_STATUS"] = comparison["SEA1_SURPLUS"].apply(
                lambda x: "Surplus" if x >= 0 else "Deficit"
            )
            comparison = comparison.sort_values("FISCAL_IMPACT", ascending=True)

            deficit_count      = (comparison["SEA1_STATUS"] == "Deficit").sum()
            base_deficit_count = (comparison["BASE_STATUS"] == "Deficit").sum()
            total_impact       = comparison["FISCAL_IMPACT"].sum()

            st.markdown(f"#### Projected {final_yr} fiscal position: Baseline vs. {sea1_scenario}")
            ca, cb, cc = st.columns(3)
            ca.metric("Townships in deficit (baseline)",  f"{base_deficit_count} of {len(comparison)}")
            cb.metric("Townships in deficit (SEA-1)",     f"{deficit_count} of {len(comparison)}")
            cc.metric("Total county SEA-1 fiscal impact", money(total_impact))

            zero_rule_h = (
                alt.Chart(pd.DataFrame({"x": [0]}))
                .mark_rule(color="#888", strokeDash=[4, 4])
                .encode(x=alt.X("x:Q"))
            )
            impact_chart = (
                alt.Chart(comparison)
                .mark_bar()
                .encode(
                    x=alt.X("FISCAL_IMPACT:Q",
                            title="Change in surplus/deficit vs baseline",
                            axis=alt.Axis(format="$,.0f")),
                    y=alt.Y("TOWNSHIP:N",
                            sort=alt.SortField("FISCAL_IMPACT", order="ascending"),
                            title=None),
                    color=alt.Color(
                        "SEA1_STATUS:N", title="SEA-1 status",
                        scale=alt.Scale(domain=["Deficit", "Surplus"],
                                        range=[COLOR_DEFICIT, COLOR_SURPLUS]),
                    ),
                    tooltip=[
                        alt.Tooltip("TOWNSHIP:N"),
                        alt.Tooltip("BASELINE_SURPLUS:Q", title="Baseline surplus/deficit", format="$,.0f"),
                        alt.Tooltip("SEA1_SURPLUS:Q",     title="SEA-1 surplus/deficit",   format="$,.0f"),
                        alt.Tooltip("FISCAL_IMPACT:Q",    title="SEA-1 impact",            format="$,.0f"),
                        alt.Tooltip("SEA1_STATUS:N",      title="SEA-1 status"),
                    ],
                )
                .properties(height=360)
            )
            st.altair_chart((impact_chart + zero_rule_h), use_container_width=True)
            st.caption(
                "Bars show the change in projected surplus/deficit under SEA-1 vs the no-policy baseline. "
                "Red bars indicate townships projected to be in deficit. "
                "Adjust the revenue growth cap in the sidebar to model different policy assumptions."
            )

            st.markdown(f"#### Year-by-year surplus/deficit trajectory under {sea1_scenario}")
            hist_all = rev_exp_df.copy()
            hist_all["DATA_TYPE"] = "Actual"
            hist_all["SCENARIO"]  = "Actual"
            timeline = pd.concat([hist_all, all_sea1], ignore_index=True)
            timeline = timeline[timeline["YEAR"] >= 2018]

            zero_line = (
                alt.Chart(timeline)
                .mark_rule(strokeDash=[4, 4], color="#888", strokeWidth=1)
                .encode(y=alt.datum(0))
            )
            timeline_chart = (
                alt.Chart(timeline)
                .mark_line(point=False, strokeWidth=2)
                .encode(
                    x=alt.X("YEAR:O", title="Year"),
                    y=alt.Y("SURPLUS_DEFICIT:Q", title="Surplus / Deficit",
                            axis=alt.Axis(format="$,.0f")),
                    color=alt.Color("TOWNSHIP:N", title="Township"),
                    strokeDash=alt.StrokeDash(
                        "DATA_TYPE:N",
                        scale=alt.Scale(domain=["Actual", "Forecast"], range=[[1, 0], [4, 4]]),
                        legend=alt.Legend(title="Type"),
                    ),
                    tooltip=[
                        alt.Tooltip("TOWNSHIP:N"),
                        alt.Tooltip("YEAR:O",            title="Year"),
                        alt.Tooltip("DATA_TYPE:N",       title="Type"),
                        alt.Tooltip("SURPLUS_DEFICIT:Q", title="Surplus/Deficit", format="$,.0f"),
                        alt.Tooltip("REVENUE:Q",         title="Revenue",         format="$,.0f"),
                        alt.Tooltip("EXPENDITURE:Q",     title="Expenditure",     format="$,.0f"),
                    ],
                )
                .properties(height=420)
            )
            st.altair_chart((timeline_chart + zero_line), use_container_width=True)
            st.caption(
                "Solid lines = historical actuals. Dashed lines = SEA-1 scenario projections. "
                "Townships falling below zero are projected to enter structural deficit."
            )

            st.markdown("#### Projected fiscal position by township")
            st.dataframe(
                comparison.rename(columns={
                    "TOWNSHIP":         "Township",
                    "BASELINE_SURPLUS": f"Baseline {final_yr} Surplus/Deficit",
                    "SEA1_SURPLUS":     f"SEA-1 {final_yr} Surplus/Deficit",
                    "FISCAL_IMPACT":    "SEA-1 Impact",
                    "BASE_STATUS":      "Baseline Status",
                    "SEA1_STATUS":      "SEA-1 Status",
                    "PROJ_EXPENDITURE": f"Projected {final_yr} Expenditure",
                    "PROJ_REVENUE":     f"Projected {final_yr} Revenue",
                }),
                use_container_width=True, hide_index=True,
            )


# ======= Trends and Forecast ======================
with tab_trends:
    left, right = st.columns((1.3, 1))

    with left:
        st.subheader(f"Spend vs. Tax Income - {selected_township}")
        if township_trend.empty:
            st.info("No trend records for the selected filters.")
        else:
            view_mode = st.radio(
                "View", ["Spend vs Tax Income", "Funding Gap"], horizontal=True, index=0,
            )
            scenario_names = (
                forecast_df["SCENARIO"].dropna().unique().tolist()
                if not forecast_df.empty else []
            )
            if not scenario_names:
                scenario_names = ["Actual"]

            chart_cols = st.columns(len(scenario_names))
            for col, scenario in zip(chart_cols, scenario_names):
                hist_panel = township_trend.copy()
                hist_panel["SCENARIO"] = scenario
                sc_fc    = forecast_df[forecast_df["SCENARIO"] == scenario].copy() if not forecast_df.empty else pd.DataFrame()
                panel_df = pd.concat([hist_panel, sc_fc], ignore_index=True) if not sc_fc.empty else hist_panel

                with col:
                    st.markdown(f"**{scenario}**")
                    if view_mode == "Spend vs Tax Income":
                        st.altair_chart(
                            make_spend_vs_income_chart(
                                panel_df, township=selected_township,
                                category_df=category_df, show_outlier_marks=adjust_outliers,
                            ),
                            use_container_width=True,
                        )
                    else:
                        st.altair_chart(make_gap_chart(panel_df), use_container_width=True)

            if view_mode == "Spend vs Tax Income":
                cap = "Solid lines = actual. Dashed = forecast."
                if adjust_outliers:
                    cap += (
                        " Orange diamonds mark one-time spending spikes excluded from the "
                        "forecast baseline. When the most recent year is flagged, the forecast "
                        "anchors to a 3-year trailing average rather than the inflated value."
                    )
                st.caption(cap)
            else:
                st.caption("Above zero = surplus. Below zero = deficit.")

            if show_forecast and not forecast_df.empty:
                with st.expander("Show forecast table"):
                    st.dataframe(
                        forecast_df[[
                            "YEAR", "SCENARIO", "REVENUE", "EXPENDITURE",
                            "SURPLUS_DEFICIT", "FISCAL_STATUS",
                            "BASELINE_REVENUE_GROWTH", "TARGET_REVENUE_GROWTH_CAP",
                            "SEA1_REVENUE_IMPACT", "ADJUSTED_REVENUE_GROWTH",
                            "ADJUSTED_EXPENDITURE_GROWTH",
                        ]],
                        use_container_width=True, hide_index=True,
                    )

    with right:
        st.subheader("2024 Surplus / Deficit by Township")
        if snapshot_df.empty:
            st.info("No 2024 snapshot records found.")
        else:
            st.altair_chart(
                alt.Chart(snapshot_df).mark_bar().encode(
                    x=alt.X("SURPLUS_DEFICIT:Q", title="Surplus / Deficit",
                            axis=alt.Axis(format="$,.0f")),
                    y=alt.Y("TOWNSHIP:N", sort="-x", title=None),
                    color=alt.Color(
                        "FISCAL_STATUS:N", title="Status",
                        scale=alt.Scale(domain=["Deficit", "Surplus"],
                                        range=[COLOR_DEFICIT, COLOR_SURPLUS]),
                    ),
                    tooltip=[
                        alt.Tooltip("TOWNSHIP:N"),
                        alt.Tooltip("REVENUE:Q",         format="$,.0f"),
                        alt.Tooltip("EXPENDITURE:Q",     format="$,.0f"),
                        alt.Tooltip("SURPLUS_DEFICIT:Q", format="$,.0f"),
                        alt.Tooltip("SURPLUS_PCT:Q",     format=".1f"),
                        alt.Tooltip("FISCAL_STATUS:N"),
                    ],
                ).properties(height=360),
                use_container_width=True,
            )


# ======= Category Spending ========================
with tab_categories:
    st.subheader(f"Spending by Category - {selected_township}")
    if category_filtered.empty:
        st.info("No category spending records for the selected filters.")
    else:
        st.altair_chart(
            alt.Chart(category_filtered).mark_bar().encode(
                x=alt.X("YEAR:O", title="Year"),
                y=alt.Y("sum(AMOUNT):Q", title="Amount", axis=alt.Axis(format="$,.0f")),
                color=alt.Color("CATEGORY:N", title="Category"),
                tooltip=[
                    alt.Tooltip("YEAR:O"),
                    alt.Tooltip("CATEGORY:N"),
                    alt.Tooltip("sum(AMOUNT):Q", title="Amount", format="$,.0f"),
                ],
            ).properties(height=430),
            use_container_width=True,
        )
        with st.expander("Show category spending table"):
            st.dataframe(
                category_filtered.sort_values(["YEAR", "AMOUNT"], ascending=[True, False]),
                use_container_width=True, hide_index=True,
            )


# ======= YoY Growth ===============================
with tab_growth:
    st.subheader("Year-over-Year Expenditure Top Movers")
    if yoy_filtered.empty:
        st.info("No YoY records for the selected filters.")
    else:
        latest_yoy_year = int(yoy_filtered["YEAR"].max())
        yoy_latest      = yoy_filtered[yoy_filtered["YEAR"] == latest_yoy_year].copy()
        yoy_latest["DIRECTION"] = yoy_latest["YOY_GROWTH_PCT"].apply(
            lambda x: "Increase" if x >= 0 else "Decrease"
        )
        available_movers = yoy_latest["TOWNSHIP"].nunique()
        top_n = st.slider(
            "Number of townships to show",
            min_value=3, max_value=min(12, max(3, available_movers)),
            value=min(6, max(3, available_movers)), step=1,
        )
        half      = top_n // 2
        increases = yoy_latest.sort_values("YOY_GROWTH_PCT", ascending=False).head(half)
        decreases = yoy_latest.sort_values("YOY_GROWTH_PCT", ascending=True).head(top_n - half)
        movers    = pd.concat([increases, decreases]).drop_duplicates(subset=["TOWNSHIP", "YEAR"])

        st.altair_chart(
            alt.Chart(movers).mark_bar().encode(
                x=alt.X("YOY_GROWTH_PCT:Q",
                        title=f"{latest_yoy_year} YoY expenditure growth (%)",
                        axis=alt.Axis(format=".1f")),
                y=alt.Y("TOWNSHIP:N",
                        sort=alt.SortField("YOY_GROWTH_PCT", order="descending"),
                        title=None),
                color=alt.Color(
                    "DIRECTION:N", title="Direction",
                    scale=alt.Scale(domain=["Decrease", "Increase"],
                                    range=[COLOR_DEFICIT, COLOR_SPENDING]),
                ),
                tooltip=[
                    alt.Tooltip("YEAR:O",           title="Year"),
                    alt.Tooltip("TOWNSHIP:N"),
                    alt.Tooltip("EXPENDITURE:Q",    title="Expenditure",   format="$,.0f"),
                    alt.Tooltip("PRIOR_YEAR_EXP:Q", title="Prior year",    format="$,.0f"),
                    alt.Tooltip("CHANGE:Q",         title="Dollar change", format="$,.0f"),
                    alt.Tooltip("YOY_GROWTH_PCT:Q", title="YoY %",         format=".1f"),
                ],
            ).properties(height=max(320, 28 * movers["TOWNSHIP"].nunique())),
            use_container_width=True,
        )
        st.caption(f"Top year-over-year expenditure changes in {latest_yoy_year}.")
        with st.expander("Show YoY table"):
            st.dataframe(
                movers[["YEAR", "TOWNSHIP", "EXPENDITURE", "PRIOR_YEAR_EXP", "CHANGE", "YOY_GROWTH_PCT"]]
                .sort_values("YOY_GROWTH_PCT", ascending=False),
                use_container_width=True, hide_index=True,
            )


# ======= Township Assistance ======================
with tab_assistance:
    st.subheader("Township Assistance - Accountability Analysis")
    st.caption(
        "Two independent data sources: Indiana Gateway disbursement records "
        "(admin cost vs dollars delivered) and the TA-7 Township Assistance "
        "Statistical Report (application outcomes self-reported by each trustee)."
    )

    asst_tab1, asst_tab2 = st.tabs([
        "Admin Cost vs. Assistance Delivered",
        "Application Outcomes (TA-7)",
    ])

    with asst_tab1:
        st.markdown("#### Clerk and Administrative Cost vs. Assistance Paid to Residents")
        st.caption(
            "Personal Services expenditures charged to the Township Assistance fund "
            "(clerk salaries, benefits) compared against dollars that reached residents. "
            "Fire department salaries are reported in the Fire Fighting Fund and are excluded. "
            "**A ratio above 1.0 means administration cost more than the assistance delivered.**"
        )
        pr_years = sorted(poor_relief_df["YEAR"].dropna().unique().tolist())
        if not pr_years:
            st.info("No Township Assistance fund records found.")
        else:
            pr_year_range = st.slider(
                "Year range",
                min_value=int(min(pr_years)), max_value=int(max(pr_years)),
                value=(int(min(pr_years)), int(max(pr_years))),
                step=1, key="pr_year_range",
            )
            pr_filtered = poor_relief_df[
                (poor_relief_df["YEAR"] >= pr_year_range[0])
                & (poor_relief_df["YEAR"] <= pr_year_range[1])
            ].copy()

            flagged = pr_filtered[pr_filtered["ADMIN_PER_DOLLAR_ASSISTANCE"] > 1.0]
            if not flagged.empty:
                flag_by_twp = (
                    flagged.groupby("TOWNSHIP")["YEAR"]
                    .apply(lambda x: ", ".join(sorted(x.astype(str).tolist())))
                    .reset_index()
                )
                flag_by_twp.columns = ["TOWNSHIP", "YEARS"]
                flag_lines = "; ".join(
                    f"**{r['TOWNSHIP']}** ({r['YEARS']})" for _, r in flag_by_twp.iterrows()
                )
                st.error(
                    f"Admin cost exceeded assistance delivered: {flag_lines}. "
                    "More was spent running the program than was paid out to residents in need."
                )

            admin_twps = pr_filtered[pr_filtered["CLERK_ADMIN_COST"] > 0]["TOWNSHIP"].unique()
            pr_admin   = pr_filtered[pr_filtered["TOWNSHIP"].isin(admin_twps)].copy()

            if pr_admin.empty:
                st.info("No townships report administrative costs in the Township Assistance fund for this period.")
            else:
                long_pr = pr_admin.melt(
                    id_vars=["YEAR", "TOWNSHIP"],
                    value_vars=["CLERK_ADMIN_COST", "ASSISTANCE_PAID"],
                    var_name="Type", value_name="Amount",
                )
                long_pr["Type"] = long_pr["Type"].replace({
                    "CLERK_ADMIN_COST": "Admin / Clerk Cost",
                    "ASSISTANCE_PAID":  "Assistance to Residents",
                })
                bar_chart = (
                    alt.Chart(long_pr).mark_bar().encode(
                        x=alt.X("YEAR:O", title="Year"),
                        y=alt.Y("Amount:Q", title="Amount", axis=alt.Axis(format="$,.0f")),
                        xOffset=alt.XOffset("Type:N"),
                        color=alt.Color(
                            "Type:N", title="",
                            scale=alt.Scale(
                                domain=["Admin / Clerk Cost", "Assistance to Residents"],
                                range=[COLOR_DEFICIT, COLOR_SPENDING],
                            ),
                        ),
                        facet=alt.Facet("TOWNSHIP:N", columns=2),
                        tooltip=[
                            alt.Tooltip("TOWNSHIP:N"),
                            alt.Tooltip("YEAR:O",   title="Year"),
                            alt.Tooltip("Type:N"),
                            alt.Tooltip("Amount:Q", format="$,.0f"),
                        ],
                    ).properties(width=350, height=240)
                )
                st.altair_chart(bar_chart)

                st.markdown("#### Admin Cost Ratio - dollars of overhead per dollar of assistance")
                ref_line = (
                    alt.Chart(pd.DataFrame({"y": [1.0]}))
                    .mark_rule(strokeDash=[4, 4], color=COLOR_DEFICIT, strokeWidth=2)
                    .encode(y=alt.Y("y:Q"))
                )
                ref_label = (
                    alt.Chart(pd.DataFrame({"y": [1.02], "label": ["Admin = Assistance"]}))
                    .mark_text(align="left", dx=4, color=COLOR_DEFICIT, fontSize=11)
                    .encode(y=alt.Y("y:Q"), x=alt.value(0), text=alt.Text("label:N"))
                )
                ratio_line = (
                    alt.Chart(pr_admin).mark_line(point=True, strokeWidth=2).encode(
                        x=alt.X("YEAR:O", title="Year"),
                        y=alt.Y("ADMIN_PER_DOLLAR_ASSISTANCE:Q",
                                title="$ admin per $ assistance",
                                axis=alt.Axis(format=".2f")),
                        color=alt.Color("TOWNSHIP:N", title="Township"),
                        tooltip=[
                            alt.Tooltip("TOWNSHIP:N"),
                            alt.Tooltip("YEAR:O",                        title="Year"),
                            alt.Tooltip("ADMIN_PER_DOLLAR_ASSISTANCE:Q", title="Ratio",          format=".2f"),
                            alt.Tooltip("CLERK_ADMIN_COST:Q",            title="Admin cost",      format="$,.0f"),
                            alt.Tooltip("ASSISTANCE_PAID:Q",             title="Assistance paid", format="$,.0f"),
                        ],
                    ).properties(height=300)
                )
                st.altair_chart(
                    (ratio_line + ref_line + ref_label).properties(height=300),
                    use_container_width=True,
                )

            with st.expander("Show assistance data table"):
                st.dataframe(
                    pr_filtered.sort_values(["YEAR", "TOWNSHIP"]),
                    use_container_width=True, hide_index=True,
                )

    with asst_tab2:
        st.markdown("#### TA-7 Township Assistance Statistical Report - Application Outcomes")
        st.caption(
            "Self-reported annual statistics from each township trustee. "
            "The denial tracking field (Question 2c) was blank for every township through 2023. "
            "All townships began populating it in 2024 following increased scrutiny of Columbus Township. "
            "Columbus Township now logs hundreds of denials per year. Harrison Township reports zero."
        )
        if ta7_df.empty:
            st.info("No TA-7 records found.")
        else:
            ta7_years = sorted(ta7_df["YEAR"].dropna().unique().tolist())
            ta7_yr = st.slider(
                "Year range",
                min_value=int(min(ta7_years)), max_value=int(max(ta7_years)),
                value=(2018, int(max(ta7_years))),
                step=1, key="ta7_yr",
            )
            ta7_f = ta7_df[
                (ta7_df["YEAR"] >= ta7_yr[0]) & (ta7_df["YEAR"] <= ta7_yr[1])
            ].copy()
            ta7_f["LOGGING_STATUS"] = ta7_f["DENIAL_LOGGING_ACTIVE"].apply(
                lambda x: "Logged" if x else "Not logged"
            )

            st.markdown("**Denial tracking status by township and year**")
            st.caption("Green = denial count filed. Gray = field left blank.")
            heatmap = (
                alt.Chart(ta7_f).mark_rect(stroke="white", strokeWidth=1).encode(
                    x=alt.X("YEAR:O", title="Year"),
                    y=alt.Y("TOWNSHIP:N", title=None),
                    color=alt.Color(
                        "LOGGING_STATUS:N", title="Denial tracking",
                        scale=alt.Scale(domain=["Logged", "Not logged"],
                                        range=[COLOR_SURPLUS, "#BDBDBD"]),
                    ),
                    tooltip=[
                        alt.Tooltip("TOWNSHIP:N"),
                        alt.Tooltip("YEAR:O",                  title="Year"),
                        alt.Tooltip("LOGGING_STATUS:N",        title="Status"),
                        alt.Tooltip("CASES_DENIED:Q",          title="Denials filed"),
                        alt.Tooltip("APPLICATIONS_RECEIVED:Q", title="Applications"),
                        alt.Tooltip("CASES_APPROVED:Q",        title="Approved"),
                    ],
                ).properties(height=300)
            )
            st.altair_chart(heatmap, use_container_width=True)

            denial_df = ta7_f[ta7_f["DENIAL_LOGGING_ACTIVE"].fillna(False)].copy()
            if not denial_df.empty:
                st.markdown("**Denials reported per township (2024 and forward)**")
                st.altair_chart(
                    alt.Chart(denial_df).mark_bar().encode(
                        x=alt.X("YEAR:O", title="Year"),
                        y=alt.Y("CASES_DENIED:Q", title="Denials reported"),
                        xOffset=alt.XOffset("TOWNSHIP:N"),
                        color=alt.Color("TOWNSHIP:N", title="Township"),
                        tooltip=[
                            alt.Tooltip("TOWNSHIP:N"),
                            alt.Tooltip("YEAR:O",                  title="Year"),
                            alt.Tooltip("CASES_DENIED:Q",          title="Denials"),
                            alt.Tooltip("APPLICATIONS_RECEIVED:Q", title="Applications"),
                            alt.Tooltip("CASES_APPROVED:Q",        title="Approved"),
                            alt.Tooltip("UNACCOUNTED_CASES:Q",     title="Unaccounted"),
                        ],
                    ).properties(height=300),
                    use_container_width=True,
                )

            harrison = ta7_f[ta7_f["TOWNSHIP"] == "HARRISON TOWNSHIP"].copy()
            if not harrison.empty:
                st.markdown("**Harrison Township - unaccounted applications**")
                recent = harrison[harrison["YEAR"] >= 2024]
                if not recent.empty:
                    unaccounted = int(recent["UNACCOUNTED_CASES"].clip(lower=0).sum())
                    st.warning(
                        f"Harrison Township filed **0 denials** in 2024 and 2025 while "
                        f"**{unaccounted} applications** have no recorded outcome - neither "
                        "approved, denied, nor withdrawn. Columbus Township reported 232 and "
                        "275 denials in the same years."
                    )
                st.altair_chart(
                    alt.Chart(harrison).mark_bar(color=COLOR_DEFICIT, opacity=0.8).encode(
                        x=alt.X("YEAR:O", title="Year"),
                        y=alt.Y("UNACCOUNTED_CASES:Q", title="Unaccounted applications"),
                        tooltip=[
                            alt.Tooltip("YEAR:O",                  title="Year"),
                            alt.Tooltip("APPLICATIONS_RECEIVED:Q", title="Received"),
                            alt.Tooltip("APPLICATIONS_REVIEWED:Q", title="Reviewed"),
                            alt.Tooltip("CASES_APPROVED:Q",        title="Approved"),
                            alt.Tooltip("CASES_DENIED:Q",          title="Denied"),
                            alt.Tooltip("UNACCOUNTED_CASES:Q",     title="Unaccounted"),
                        ],
                    ).properties(height=260),
                    use_container_width=True,
                )

            with st.expander("Show TA-7 data table"):
                st.dataframe(
                    ta7_f.sort_values(["YEAR", "TOWNSHIP"]),
                    use_container_width=True, hide_index=True,
                )


# ======= Data Explorer ============================
with tab_explorer:
    st.subheader("Data Explorer")
    selected_view = st.selectbox(
        "Choose a dataset",
        ["County Summary", "Revenue vs Expenditure", "2024 Snapshot",
         "Spending by Category", "YoY Growth", "Township Assistance Fund",
         "TA-7 Application Outcomes"],
    )
    explorer_map = {
        "County Summary":            summary_df,
        "Revenue vs Expenditure":    rev_exp_df,
        "2024 Snapshot":             snapshot_df,
        "Spending by Category":      category_df,
        "YoY Growth":                yoy_df,
        "Township Assistance Fund":  poor_relief_df,
        "TA-7 Application Outcomes": ta7_df,
    }
    st.dataframe(explorer_map[selected_view], use_container_width=True, hide_index=True)