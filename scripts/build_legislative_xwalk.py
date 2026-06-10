"""
build_legislative_xwalk.py
Build the township -> legislative district crosswalk CSV for KAN-158.

Output: districtdata/legislative_district_xwalk.csv, ready to PUT/COPY into
HOOSIER_DATA.RAW.LEGISLATIVE_DISTRICT_XWALK via scripts/load_snowflake_xwalk.py.

Method (precinct-based; chosen because Indiana law requires precincts to nest
entirely within a single House and Senate district and within a township —
IC 3-11-1.5 — so precinct assignments give unambiguous township district sets
with no area-sliver false positives):

  1. Precincts come from IndianaMap "Voting District Boundaries 2024" (current
     123rd GA / 2021 redistricting plan, sourced from the IGA + Indiana Election
     Division). Each precinct already carries its House (h), Senate (s), and
     Congressional (c) district and county FIPS as attributes — no district
     spatial join needed.
  2. The precinct layer has no civil-township field, so each precinct is assigned
     to the civil township (Census TIGER/Line county subdivision = Indiana civil
     township) whose polygon contains it.
  3. Townships are matched to DLGF township_number via DLGF_TOWNSHIP_CODES on
     (county_number, township_name). Indiana county FIPS is deterministic from the
     DLGF alphabetical county_number: fips = 2*county_number - 1.
  4. Output grain: one row per (county_number, township_number, house_district,
     senate_district) that actually occurs in the township, with an is_split flag
     for townships that cross any district line.

District codes are emitted in LEGISCAN_PEOPLE.district format ("HD-059", "SD-041")
so the downstream packet can join xwalk.house_district = people.district directly.

Dependencies: pip install geopandas shapely pandas requests
This script only reads public data and writes a local CSV; it does NOT touch
Snowflake. Run scripts/load_snowflake_xwalk.py afterward to load it.
"""

import argparse
import io
import os
import re
import sys
import zipfile

import geopandas as gpd
import pandas as pd
import requests

PRECINCT_LAYER = (
    "https://gisdata.in.gov/server/rest/services/Hosted/"
    "Voting_District_Boundaries_2024/FeatureServer/1"
)
TIGER_COUSUB = "https://www2.census.gov/geo/tiger/TIGER2024/COUSUB/tl_2024_18_cousub.zip"
DATA_VINTAGE = "2024"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
OUT_DIR = os.path.join(REPO_ROOT, "districtdata")
DLGF_CSV = os.path.join(REPO_ROOT, "propertydata", "dlgf_township_codes.csv")

# Equal-area projection for reliable point-in-polygon / overlap (CONUS Albers).
EQUAL_AREA = "EPSG:5070"

UA = {"User-Agent": "hoosier_data/build_legislative_xwalk (KAN-158)"}

PRECINCT_CACHE = os.path.join(OUT_DIR, "_precincts.gpkg")
TIGER_DIR = os.path.join(OUT_DIR, "_tiger_cousub")


def norm_name(s):
    """Collapse a township/MCD name to alphanumerics only, uppercased.

    Reconciles Census vs DLGF spelling differences such as
    "Flat Rock"/"FLATROCK", "Sand Creek"/"SANDCREEK", "Etna-Troy"/"ETNA TROY".
    """
    return re.sub(r"[^A-Z0-9]", "", str(s).upper())


# Census-name -> DLGF-name aliases for the same civil township, keyed by
# (DLGF county_number, normalized Census NAME). Used only for genuine name
# variants of a township that DOES exist in DLGF; reorganized/abolished
# townships with no DLGF equivalent are reported, not aliased.
TOWNSHIP_ALIASES = {
    ("29", "WESTFIELDWASHINGTON"): "WASHINGTON",  # Hamilton Co. (Westfield)
    ("89", "GREEN"): "GREENE",                    # Wayne Co.
}


def fetch_precincts(refresh=False):
    """Page the precinct FeatureServer into a GeoDataFrame (EPSG:4326)."""
    if not refresh and os.path.exists(PRECINCT_CACHE):
        print(f"Using cached precincts: {PRECINCT_CACHE}")
        return gpd.read_file(PRECINCT_CACHE)
    print("Downloading precincts from IndianaMap Voting District Boundaries 2024...")
    s = requests.Session()
    s.headers.update(UA)
    page = 2000
    offset = 0
    feats = []
    while True:
        r = s.get(
            PRECINCT_LAYER + "/query",
            params={
                "where": "1=1",
                "outFields": "county,p24,c,s,h",
                "outSR": "4326",
                "f": "geojson",
                "resultOffset": offset,
                "resultRecordCount": page,
            },
            timeout=120,
        )
        r.raise_for_status()
        gj = r.json()
        batch = gj.get("features", [])
        feats.extend(batch)
        print(f"  fetched {len(feats):,} precincts...")
        if len(batch) < page:
            break
        offset += page
    gdf = gpd.GeoDataFrame.from_features(feats, crs="EPSG:4326")
    print(f"  total precincts: {len(gdf):,}")
    gdf.to_file(PRECINCT_CACHE, driver="GPKG")
    return gdf


def fetch_townships(refresh=False):
    """Download TIGER county subdivisions (Indiana civil townships) -> GeoDataFrame.

    Keeps ALL county subdivisions (not just NAMELSAD ending in "township") so
    every land precinct can be assigned to its containing MCD; subdivisions with
    no DLGF township_number (e.g. the consolidated town of Zionsville, which
    replaced the abolished Eagle/Union townships) are reported during the build.
    """
    shp_dir = TIGER_DIR
    have = os.path.isdir(shp_dir) and any(f.endswith(".shp") for f in os.listdir(shp_dir))
    if refresh or not have:
        print("Downloading TIGER/Line 2024 county subdivisions (Indiana)...")
        r = requests.get(TIGER_COUSUB, headers=UA, timeout=180)
        r.raise_for_status()
        os.makedirs(shp_dir, exist_ok=True)
        zipfile.ZipFile(io.BytesIO(r.content)).extractall(shp_dir)
    else:
        print(f"Using cached TIGER county subdivisions: {shp_dir}")
    shp = next(f for f in os.listdir(shp_dir) if f.endswith(".shp"))
    gdf = gpd.read_file(os.path.join(shp_dir, shp))
    print(f"  county subdivision polygons: {len(gdf):,}")
    return gdf[["COUNTYFP", "NAME", "NAMELSAD", "geometry"]]


def assign_precincts_to_townships(precincts, townships):
    """Assign each precinct to the township containing its representative point.

    Precincts nest within townships by statute, so a point guaranteed to be
    inside the precinct polygon (representative_point) lands in the correct
    township even for concave shapes. Any precinct whose point falls outside all
    townships (boundary-vintage gaps) is rescued by largest-area overlap.
    """
    print("Assigning precincts to civil townships...")
    pre = precincts.to_crs(EQUAL_AREA)
    twp = townships.to_crs(EQUAL_AREA)
    # A handful of precinct polygons are self-intersecting; repair so the
    # representative-point and overlay operations don't silently drop them.
    bad = ~pre.is_valid
    if bad.any():
        print(f"  repairing {int(bad.sum())} invalid precinct geometries...")
        pre.loc[bad, "geometry"] = pre.loc[bad, "geometry"].make_valid()

    pts = pre.copy()
    pts["geometry"] = pre.representative_point()
    joined = gpd.sjoin(pts, twp, how="left", predicate="within")
    # sjoin can yield >1 match if township polygons overlap; keep first per precinct
    joined = joined[~joined.index.duplicated(keep="first")]

    missing = joined["NAMELSAD"].isna()
    n_missing = int(missing.sum())
    if n_missing:
        print(f"  {n_missing} precincts not matched by point; rescuing via max overlap...")
        unmatched = pre.loc[missing.index[missing]]
        ov = gpd.overlay(
            unmatched.reset_index()[["index", "geometry"]],
            twp.reset_index(drop=True),
            how="intersection",
            keep_geom_type=False,
        )
        ov["a"] = ov.geometry.area
        ov = ov.sort_values("a").groupby("index", as_index=False).last()
        rescue = ov.set_index("index")[["COUNTYFP", "NAME", "NAMELSAD"]]
        for col in ["COUNTYFP", "NAME", "NAMELSAD"]:
            joined.loc[rescue.index, col] = rescue[col]

    still = int(joined["NAMELSAD"].isna().sum())
    if still:
        # Remaining unassigned are water-only precincts (e.g. "LAKE MICHIGAN NV")
        # whose representative point lies outside every land subdivision.
        names = precincts.loc[joined.index[joined["NAMELSAD"].isna()], "p24"].tolist()
        print(f"  {still} precincts unassigned (expected: open-water precincts): "
              + ", ".join(sorted(set(names))[:6]) + (" ..." if still > 6 else ""))
    out = precincts.copy()
    for col in ["COUNTYFP", "NAME", "NAMELSAD"]:
        out[col] = joined[col].values
    return out


def fips_to_county_number(fips3):
    """Indiana DLGF county_number (alphabetical, 1-92) from 3-digit county FIPS."""
    return f"{(int(fips3) + 1) // 2:02d}"


def build_crosswalk(assigned):
    """Aggregate precinct-level assignments to the township-district crosswalk."""
    print("Building crosswalk rows...")
    dlgf = pd.read_csv(DLGF_CSV, dtype=str)
    dlgf["county_number"] = dlgf["county_number"].str.zfill(2)
    dlgf["dlgf_norm"] = dlgf["township_name"].str.replace(
        "TOWNSHIP", "", regex=False).map(norm_name)
    dlgf["key"] = dlgf["county_number"] + "|" + dlgf["dlgf_norm"]
    dlgf_lookup = dlgf.set_index("key")[["county_name", "township_number", "township_name"]]

    df = assigned.dropna(subset=["NAMELSAD"]).copy()
    # County comes from the precinct's own FIPS (authoritative), not the matched
    # polygon's, so a boundary-straddling assignment can't move a precinct county.
    df["county_number"] = df["county"].map(fips_to_county_number)
    tiger_norm = df["NAME"].map(norm_name)
    df["match_norm"] = [
        TOWNSHIP_ALIASES.get((cn, nm), nm)
        for cn, nm in zip(df["county_number"], tiger_norm)
    ]
    df["twp_key"] = df["county_number"] + "|" + df["match_norm"]

    df = df.join(dlgf_lookup, on="twp_key")

    # Report MCDs with precincts that have no DLGF township_number (genuine gaps:
    # abolished/reorganized townships, water, etc.) — excluded from the output.
    unmapped = df[df["township_number"].isna()]
    if len(unmapped):
        rpt = (unmapped.groupby(["county_number", "NAME"])["p24"]
               .nunique().sort_values(ascending=False))
        print(f"  NOTE: {len(rpt)} subdivisions ({len(unmapped)} precincts) have no "
              f"DLGF township_number -- excluded:")
        for (cn, nm), n in rpt.items():
            print(f"    county {cn}  {nm:<22} {n} precinct(s)")

    df = df.dropna(subset=["township_number"])

    df["house_district"] = "HD-" + df["h"].str.zfill(3)
    df["senate_district"] = "SD-" + df["s"].str.zfill(3)
    df["congressional_district"] = "CD-" + df["c"].str.lstrip("0").str.zfill(2)

    # Township-level split: crosses >1 House OR >1 Senate district
    twp_grp = df.groupby(["county_number", "township_number"])
    hcount = twp_grp["house_district"].transform("nunique")
    scount = twp_grp["senate_district"].transform("nunique")
    df["is_split"] = ((hcount > 1) | (scount > 1)).map({True: "true", False: "false"})

    rows = (
        df.groupby(
            [
                "county_number",
                "county_name",
                "township_number",
                "township_name",
                "house_district",
                "senate_district",
                "is_split",
            ],
            as_index=False,
        )
        .agg(
            congressional_district=("congressional_district", lambda x: ",".join(sorted(set(x)))),
            precinct_count=("p24", "nunique"),
        )
    )
    rows["data_vintage"] = DATA_VINTAGE
    rows = rows[
        [
            "county_number",
            "county_name",
            "township_number",
            "township_name",
            "house_district",
            "senate_district",
            "congressional_district",
            "is_split",
            "precinct_count",
            "data_vintage",
        ]
    ].sort_values(["county_number", "township_number", "house_district", "senate_district"])
    return rows


def main():
    ap = argparse.ArgumentParser(description="Build the township->legislative district crosswalk CSV")
    ap.add_argument("--out", default=os.path.join(OUT_DIR, "legislative_district_xwalk.csv"))
    ap.add_argument("--refresh", action="store_true",
                    help="re-download sources instead of using cached copies")
    args = ap.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    if not os.path.exists(DLGF_CSV):
        sys.exit(f"ERROR: missing {DLGF_CSV} (DLGF township codes).")

    precincts = fetch_precincts(refresh=args.refresh)
    townships = fetch_townships(refresh=args.refresh)
    assigned = assign_precincts_to_townships(precincts, townships)
    rows = build_crosswalk(assigned)

    rows.to_csv(args.out, index=False)
    covered = rows[["county_number", "township_number"]].drop_duplicates()
    dlgf = pd.read_csv(DLGF_CSV, dtype=str)
    dlgf["county_number"] = dlgf["county_number"].str.zfill(2)
    uncovered = dlgf.merge(
        covered, on=["county_number", "township_number"], how="left", indicator=True
    ).query("_merge == 'left_only'")
    print(f"\nWrote {len(rows):,} crosswalk rows -> {args.out}")
    print(f"  DLGF townships covered: {len(covered):,} of {len(dlgf):,}")
    print(f"  split townships:        {rows[rows.is_split=='true'][['county_number','township_number']].drop_duplicates().shape[0]:,}")
    if len(uncovered):
        print(f"  DLGF townships with NO precinct assigned: {len(uncovered)}")
        for _, r in uncovered.head(30).iterrows():
            print(f"    {r['county_number']} {r['township_number']} {r['township_name']} ({r['county_name']})")


if __name__ == "__main__":
    main()
