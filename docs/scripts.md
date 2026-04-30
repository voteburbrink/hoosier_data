# Scripts Reference

All scripts live in the `scripts/` folder. PowerShell scripts run on Windows. The Python script requires Python 3.8+ with pandas installed.

---

## Download Scripts

### download_state_expenditures.ps1

Downloads all 26 Indiana state expenditure quarterly CSV files from Indiana Data Hub.

**Output**: `C:\Users\jburbrink\Downloads\EXPENDITURES_UPLOAD\`
**Coverage**: FY2020 Q1 through FY2026 Q2
**Files**: `expenditure_YYYYqQ.csv`
**Target table**: `HOOSIER_DATA.RAW.STATE_EXPENDITURES`

All 26 download URLs are hardcoded with verified GUIDs from Indiana Data Hub. The script skips files that already exist, so it is safe to re-run after interruption.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\download_state_expenditures.ps1
```

---

### download_indiana_vendor_data.ps1

Downloads Indiana state vendor spending quarterly CSV files from Indiana Data Hub.

**Output**: `C:\Users\jburbrink\Downloads\VENDOR_UPLOAD\`
**Target table**: `HOOSIER_DATA.RAW.VENDOR_EXPENDITURES`

Note: The vendor CSV columns load out of order relative to the RAW table definition. The column mapping is corrected in `HOOSIER_DATA.STAGING.VENDOR_EXPENDITURES`. Do not rely on column names from this source -- always verify with `SELECT * LIMIT 5` after loading.

```powershell
.\download_indiana_vendor_data.ps1
```

---

### download_hoosier_data.ps1

Downloads ILRC lobbying Excel files from the Indiana Lobby Registration Commission website.

**Output**: `C:\Users\jburbrink\Downloads\HOOSIER_DATA_SOURCES\LOBBYING\`
**Files**: `employer_lobbyist_total_YYYY.xlsx`, `compensated_lobbyist_total_YYYY.xlsx`
**Coverage**: 2021-2025
**Target tables**: `LOBBYING_EMPLOYER`, `LOBBYING_COMPENSATED`

After download, convert XLSX to CSV using the inline conversion block below before uploading to Snowflake.

```powershell
.\download_hoosier_data.ps1
```

---

## File Preparation Scripts

### organize_gateway_files.ps1

Extracts and organizes Indiana Gateway ZIP downloads into a single upload-ready folder.

**Input**: `C:\Users\jburbrink\Downloads\` (raw Gateway ZIPs)
**Output**:
- `GATEWAY_UPLOAD\` -- all TXT data files
- `GATEWAY_UPLOAD\CONTRACTS\FY####\` -- federal contract CSVs by year

```powershell
.\organize_gateway_files.ps1
```

---

### split_large_files.ps1

Splits files over 200MB into chunks for Snowflake's 250MB UI upload limit. Repeats the header row in each part so COPY INTO works correctly across all chunks.

**Input**: Large TXT files in `GATEWAY_UPLOAD\`
**Output**: `GATEWAY_UPLOAD_SPLIT\` with `_part1`, `_part2` etc. naming

Files that required splitting:

| File | Original Size | Parts |
|---|---|---|
| eca_fund_receipts.txt | 919MB | 5 |
| eca_fund_expenditures.txt | 847MB | 5 |
| detailedDisburse_fundsNOdept.txt | 367MB | 2 |
| detailedReceipts.txt | 363MB | 2 |

```powershell
.\split_large_files.ps1
```

---

### consolidate_contracts.ps1

Moves all federal contract CSVs from their `FY####` subfolders into a single flat folder for upload. Prefixes filenames with the fiscal year if not already present.

**Input**: `GATEWAY_UPLOAD\CONTRACTS\FY####\*.csv`
**Output**: `CONTRACTS_UPLOAD\` (flat folder, all years)

Run this before `filter_indiana_contracts.py`.

```powershell
.\consolidate_contracts.ps1
```

---

### filter_indiana_contracts.py

Filters the full national USASpending federal contracts dataset down to Indiana-only rows. Required before upload -- the raw national files total ~85GB across 44 files.

**Input**: `CONTRACTS_UPLOAD\*.csv` (~85GB, all 50 states)
**Output**: `INDIANA_CONTRACTS\*.csv` (~300K rows, Indiana only)
**Filter logic**: `recipient_state_code = 'IN'` OR `primary_place_of_performance_state_code = 'IN'`
**Target table**: `HOOSIER_DATA.RAW.FEDERAL_CONTRACTS`

Processes files in 50,000-row chunks -- does not load full 2GB files into memory.

```bash
pip install pandas
python filter_indiana_contracts.py
```

---

## Inspection Scripts

These scripts were used during setup to verify file structures before creating Snowflake tables. Keep for future data refreshes.

### check_gateway_headers.ps1

Prints column names and count for every TXT file in `GATEWAY_UPLOAD\`. Auto-detects delimiter (pipe vs comma). Use when adding new Gateway data files to verify schema before creating tables.

```powershell
.\check_gateway_headers.ps1
```

### check_contract_headers.ps1

Same as above but recurses into `GATEWAY_UPLOAD\CONTRACTS\` subfolders. Prints the first 30 column names per file with auto-delimiter detection.

```powershell
.\check_contract_headers.ps1
```

---

## XLSX to CSV Conversion

Lobbying files from ILRC are published as Excel XLSX files. Convert them before uploading to Snowflake using Excel COM (requires Excel installed on Windows):

```powershell
$lobbyDir  = "C:\Users\jburbrink\Downloads\HOOSIER_DATA_SOURCES\LOBBYING"
$outputDir = "C:\Users\jburbrink\Downloads\LOBBYING_UPLOAD"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

Get-ChildItem $lobbyDir -Filter "*.xlsx" | ForEach-Object {
    $wb = $excel.Workbooks.Open($_.FullName)
    $outPath = Join-Path $outputDir ($_.BaseName + ".csv")
    $wb.SaveAs($outPath, 6)
    $wb.Close($false)
    Write-Host "Converted: $($_.Name)"
}

$excel.Quit()
```
