# ============================================================
# HOOSIER_DATA — Indiana Gateway Files Organizer
# Unzips and consolidates all Gateway downloads into one folder
# Output: C:\Users\jburbrink\Downloads\GATEWAY_UPLOAD\
#
# TO RUN:
#   1. Open PowerShell as Administrator
#   2. Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   3. .\organize_gateway_files.ps1
# ============================================================

$sourceDir  = "C:\Users\jburbrink\Downloads"
$outputDir  = "C:\Users\jburbrink\Downloads\GATEWAY_UPLOAD"
$contractDir = "$outputDir\CONTRACTS"

# Create output folders
New-Item -ItemType Directory -Force -Path $outputDir   | Out-Null
New-Item -ItemType Directory -Force -Path $contractDir | Out-Null

Write-Host "==================================================="
Write-Host "  Indiana Gateway Files Organizer"
Write-Host "  Source : $sourceDir"
Write-Host "  Output : $outputDir"
Write-Host "==================================================="

$copied   = 0
$extracted = 0
$skipped  = 0

# ── STEP 1: Copy all .txt files directly (already extracted) ──
Write-Host "`n[1/3] Copying .txt files..."

$gatewayTxtPatterns = @(
    "detailedReceipts_*.txt",
    "detailedDisburse_fundsNOdept_*.txt",
    "detailedDisburse_fundswithdept_*.txt",
    "townshipDisburseByVendor_*.txt"
)

foreach ($pattern in $gatewayTxtPatterns) {
    $files = Get-ChildItem -Path $sourceDir -Filter $pattern -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $dest = Join-Path $outputDir $f.Name
        if (Test-Path $dest) {
            Write-Host "  SKIP: $($f.Name)"
            $skipped++
            continue
        }
        Copy-Item $f.FullName $dest
        $kb = [math]::Round($f.Length / 1KB, 0)
        Write-Host "  Copied: $($f.Name) (${kb} KB)"
        $copied++
    }
}

# ── STEP 2: Extract Gateway data ZIPs (budget/financial data) ──
Write-Host "`n[2/3] Extracting Gateway data ZIPs..."

$gatewayZips = @(
    "detailedReceipts.zip",
    "detailedDisburse_fundsNOdept.zip",
    "detailedDisburse_fundswithdept.zip",
    "townshipDisburseByVendor.zip",
    "eca_fund_expenditures.zip",
    "eca_fund_receipts.zip",
    "eca_fund_balances.zip",
    "e1_entity_funds.zip",
    "form22.zip",
    "ta7.zip"
)

foreach ($zipName in $gatewayZips) {
    $zipPath = Join-Path $sourceDir $zipName
    if (-not (Test-Path $zipPath)) {
        Write-Host "  NOT FOUND: $zipName"
        continue
    }

    Write-Host "  Extracting: $zipName ... " -NoNewline
    try {
        Expand-Archive -Path $zipPath -DestinationPath $outputDir -Force
        Write-Host "OK"
        $extracted++
    } catch {
        Write-Host "FAILED - $_"
    }
}

# ── STEP 3: Extract Contracts ZIPs into their own subfolder ──
Write-Host "`n[3/3] Extracting Contracts ZIPs (large files — may take a few minutes)..."

$contractZips = Get-ChildItem -Path $sourceDir -Filter "FY*_All_Contracts_Full_*.zip"

foreach ($zipFile in $contractZips) {
    # Extract year from filename e.g. FY2022_All_Contracts_Full_20260406.zip -> 2022
    $year = ""
    if ($zipFile.Name -match "FY(\d{4})_") { $year = $matches[1] }
    
    $destFolder = Join-Path $contractDir "FY$year"
    
    if (Test-Path $destFolder) {
        $existing = Get-ChildItem $destFolder -Recurse | Measure-Object
        if ($existing.Count -gt 0) {
            Write-Host "  SKIP (already extracted): $($zipFile.Name)"
            $skipped++
            continue
        }
    }
    
    New-Item -ItemType Directory -Force -Path $destFolder | Out-Null
    $mb = [math]::Round($zipFile.Length / 1MB, 0)
    Write-Host "  Extracting: $($zipFile.Name) (${mb} MB) ... " -NoNewline
    
    try {
        Expand-Archive -Path $zipFile.FullName -DestinationPath $destFolder -Force
        Write-Host "OK"
        $extracted++
    } catch {
        Write-Host "FAILED - $_"
    }
}

# ── STEP 4: Rename any extracted files missing year suffix ──
Write-Host "`n[4/4] Checking for files needing year suffix..."

# Some ZIPs extract files without year in the name
# Check for any bare filenames and report them
$bareFiles = Get-ChildItem -Path $outputDir -File | Where-Object {
    $_.Name -notmatch "\d{4}" -and $_.Extension -in @(".txt", ".csv", ".pipe")
}

if ($bareFiles.Count -gt 0) {
    Write-Host "  WARNING: These files have no year in the name — check manually:"
    foreach ($f in $bareFiles) {
        Write-Host "    $($f.Name)"
    }
} else {
    Write-Host "  All files have year identifiers. Good."
}

# ── SUMMARY ───────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================="
Write-Host "  Copied    : $copied .txt files"
Write-Host "  Extracted : $extracted ZIP files"
Write-Host "  Skipped   : $skipped (already done)"
Write-Host "==================================================="
Write-Host ""
Write-Host "File inventory:"
Write-Host ""
Write-Host "  Budget/Financial data (pipe-delimited .txt):"
Get-ChildItem -Path $outputDir -File | Sort-Object Name | ForEach-Object {
    $kb = [math]::Round($_.Length / 1KB, 0)
    Write-Host "    $($_.Name) (${kb} KB)"
}
Write-Host ""
Write-Host "  Contracts data (large ZIPs extracted to subfolders):"
Get-ChildItem -Path $contractDir -Directory | ForEach-Object {
    $files = Get-ChildItem $_.FullName -Recurse -File
    $totalMB = [math]::Round(($files | Measure-Object -Property Length -Sum).Sum / 1MB, 0)
    Write-Host "    $($_.Name) — $($files.Count) files, ${totalMB} MB"
}
Write-Host ""
Write-Host "Next step: Upload GATEWAY_UPLOAD folder contents to Snowflake stage"
Write-Host "==================================================="
