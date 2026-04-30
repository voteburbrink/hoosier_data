"""
HOOSIER_DATA — Filter Federal Contracts to Indiana Only
Reads each large USASpending CSV and extracts Indiana rows only.
Filters on: recipient_state_code = 'IN'
         OR primary_place_of_performance_state_code = 'IN'

Input:  CONTRACTS_UPLOAD/*.csv  (~85GB national data)
Output: INDIANA_CONTRACTS/*.csv (~1-2GB Indiana only)

Usage:
    python filter_indiana_contracts.py
"""

import pandas as pd
import os
import glob

source_dir = r"C:\Users\jburbrink\Downloads\CONTRACTS_UPLOAD"
output_dir = r"C:\Users\jburbrink\Downloads\INDIANA_CONTRACTS"
os.makedirs(output_dir, exist_ok=True)

csv_files = sorted(glob.glob(os.path.join(source_dir, "*.csv")))
print(f"Found {len(csv_files)} files to process")

for csv_file in csv_files:
    out_file = os.path.join(output_dir, os.path.basename(csv_file))
    if os.path.exists(out_file):
        print(f"SKIP: {os.path.basename(csv_file)}")
        continue

    print(f"\nProcessing: {os.path.basename(csv_file)} ({os.path.getsize(csv_file)//1024//1024} MB)")

    first_chunk = True
    total = 0
    kept  = 0

    for chunk in pd.read_csv(csv_file, chunksize=50000,
                             dtype=str,
                             on_bad_lines='skip',
                             low_memory=False):
        total += len(chunk)

        mask = (
            (chunk.get('recipient_state_code', pd.Series()) == 'IN') |
            (chunk.get('primary_place_of_performance_state_code', pd.Series()) == 'IN')
        )
        indiana = chunk[mask]
        kept += len(indiana)

        if len(indiana) > 0:
            indiana.to_csv(out_file,
                          mode='w' if first_chunk else 'a',
                          header=first_chunk,
                          index=False)
            first_chunk = False

        if total % 500000 == 0:
            print(f"  ...{total:,} rows processed, {kept:,} Indiana kept")

    out_mb = os.path.getsize(out_file) / 1024 / 1024 if os.path.exists(out_file) else 0
    print(f"  Done: {kept:,} Indiana rows from {total:,} total ({out_mb:.1f} MB)")

print("\nAll done! Upload INDIANA_CONTRACTS to CONTRACTS_STAGE")
