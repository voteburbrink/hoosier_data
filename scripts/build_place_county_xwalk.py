"""
build_place_county_xwalk.py
Build an authoritative Indiana place -> county crosswalk from Census TIGER
geometry, keyed to DLGF alphabetical county_number (not FIPS). This is the
geography bridge that lets IVFA departments (keyed by city) reconcile against
DLGF fire-funding units (keyed by county). KAN-182.

Method: intersect TIGER 2024 IN place polygons with county polygons in an
equal-area projection (EPSG:5070). A place is assigned to every county it
overlaps by >= 2% of its area (drops slivers); the largest-overlap county is
is_primary. Places spanning >1 county get is_multi_county=TRUE (the documented
"flag multi-county cities" requirement, satisfied by real geometry).

Output: censusdata/place_county_xwalk.csv
  place_geoid, place_name, place_namelsad, county_name, county_number,
  overlap_pct, is_primary, is_multi_county

Cities that are NOT Census places (small unincorporated communities) and IVFA
spelling variants are handled separately in
censusdata/ivfa_city_county_supplement.csv (GNIS-resolved + aliases).

Deps: geopandas, shapely, pandas (already in this environment).
Usage: python scripts/build_place_county_xwalk.py
"""

import io
import os
import zipfile
import urllib.request

import geopandas as gpd

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
OUT_CSV = os.path.join(REPO_ROOT, "censusdata", "place_county_xwalk.csv")

PLACE_URL = "https://www2.census.gov/geo/tiger/TIGER2024/PLACE/tl_2024_18_place.zip"
COUNTY_URL = "https://www2.census.gov/geo/tiger/TIGER2024/COUNTY/tl_2024_us_county.zip"

# DLGF alphabetical county_number (source: RAW.TOWNSHIP_POP_AREA). Note non-FIPS.
DLGF = {
 "Adams":"01","Allen":"02","Bartholomew":"03","Benton":"04","Blackford":"05",
 "Boone":"06","Brown":"07","Carroll":"08","Cass":"09","Clark":"10","Clay":"11",
 "Clinton":"12","Crawford":"13","Daviess":"14","Dearborn":"15","Decatur":"16",
 "DeKalb":"17","Delaware":"18","Dubois":"19","Elkhart":"20","Fayette":"21",
 "Floyd":"22","Fountain":"23","Franklin":"24","Fulton":"25","Gibson":"26",
 "Grant":"27","Greene":"28","Hamilton":"29","Hancock":"30","Harrison":"31",
 "Hendricks":"32","Henry":"33","Howard":"34","Huntington":"35","Jackson":"36",
 "Jasper":"37","Jay":"38","Jefferson":"39","Jennings":"40","Johnson":"41",
 "Knox":"42","Kosciusko":"43","LaGrange":"44","Lake":"45","LaPorte":"46",
 "Lawrence":"47","Madison":"48","Marion":"49","Marshall":"50","Martin":"51",
 "Miami":"52","Monroe":"53","Montgomery":"54","Morgan":"55","Newton":"56",
 "Noble":"57","Ohio":"58","Orange":"59","Owen":"60","Parke":"61","Perry":"62",
 "Pike":"63","Porter":"64","Posey":"65","Pulaski":"66","Putnam":"67",
 "Randolph":"68","Ripley":"69","Rush":"70","St. Joseph":"71","Scott":"72",
 "Shelby":"73","Spencer":"74","Starke":"75","Steuben":"76","Sullivan":"77",
 "Switzerland":"78","Tippecanoe":"79","Tipton":"80","Union":"81",
 "Vanderburgh":"82","Vermillion":"83","Vigo":"84","Wabash":"85","Warren":"86",
 "Warrick":"87","Washington":"88","Wayne":"89","Wells":"90","White":"91",
 "Whitley":"92"}

OVERLAP_MIN = 0.02  # ignore sliver overlaps below 2% of place area


def read_tiger(url):
    print("download", url.split("/")[-1])
    data = urllib.request.urlopen(url, timeout=180).read()
    # geopandas can read a shapefile straight from a zip in memory via pyogrio;
    # fall back to extracting if needed.
    tmp = os.path.join(REPO_ROOT, "censusdata", "_tiger_tmp")
    os.makedirs(tmp, exist_ok=True)
    zipfile.ZipFile(io.BytesIO(data)).extractall(tmp)
    gdf = gpd.read_file(tmp)
    return gdf, tmp


def main():
    place, t1 = read_tiger(PLACE_URL)
    cnty, t2 = read_tiger(COUNTY_URL)
    cnty = cnty[cnty.STATEFP == "18"].copy()
    print("IN places:", len(place), "| IN counties:", len(cnty))

    place = place.to_crs(5070)
    cnty = cnty.to_crs(5070)
    place["place_area"] = place.geometry.area
    ov = gpd.overlay(
        place[["GEOID", "NAME", "NAMELSAD", "place_area", "geometry"]],
        cnty[["NAME", "geometry"]].rename(columns={"NAME": "county_name"}),
        how="intersection", keep_geom_type=True)
    ov["overlap_pct"] = ov.geometry.area / ov["place_area"]
    ov = ov[ov.overlap_pct >= OVERLAP_MIN].copy()
    ov["county_number"] = ov.county_name.map(DLGF)
    bad = sorted(set(ov.county_name[ov.county_number.isna()]))
    if bad:
        raise SystemExit("Unmapped counties: %s" % bad)

    ov = ov.sort_values(["GEOID", "overlap_pct"], ascending=[True, False])
    n_counties = ov.groupby("GEOID").size()
    ov["is_multi_county"] = ov.GEOID.map(n_counties > 1)
    ov["is_primary"] = ~ov.duplicated("GEOID")
    ov["overlap_pct"] = (ov.overlap_pct * 100).round(1)

    out = ov[["GEOID", "NAME", "NAMELSAD", "county_name", "county_number",
              "overlap_pct", "is_primary", "is_multi_county"]]
    out.columns = ["place_geoid", "place_name", "place_namelsad", "county_name",
                   "county_number", "overlap_pct", "is_primary", "is_multi_county"]
    out = out.sort_values(["place_name", "is_primary"], ascending=[True, False])
    out.to_csv(OUT_CSV, index=False)
    print("wrote %s | rows %d | places %d | multi-county %d"
          % (OUT_CSV, len(out), out.place_geoid.nunique(),
             out[out.is_multi_county].place_geoid.nunique()))

    for t in (t1, t2):
        for f in os.listdir(t):
            os.remove(os.path.join(t, f))
        os.rmdir(t)


if __name__ == "__main__":
    main()
