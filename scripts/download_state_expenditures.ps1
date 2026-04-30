# ============================================================
# HOOSIER_DATA — Indiana State Expenditures Downloader
# Source: Indiana Data Hub (Indiana Transparency Portal)
# URL: hub.mph.in.gov/dataset/expenditures-data
# Output: C:\Users\jburbrink\Downloads\EXPENDITURES_UPLOAD\
#
# Covers: FY2020 Q1 through FY2026 Q2 (all available quarters)
# Files: expenditure_YYYYqQ.csv
# Note: Indiana fiscal year runs July 1 - June 30
#       FY2020 = July 2019 - June 2020, files named 2020q1-q4
#
# TO RUN:
#   1. Open PowerShell as Administrator
#   2. Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#   3. .\download_state_expenditures.ps1
# ============================================================

$outputDir  = "C:\Users\jburbrink\Downloads\EXPENDITURES_UPLOAD"
$baseUrl    = "https://hub.mph.in.gov/dataset/9972712c-d1e8-4b66-811f-fb10967914af/resource"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

Write-Host "==================================================="
Write-Host "  Indiana State Expenditures Downloader"
Write-Host "  Output: $outputDir"
Write-Host "==================================================="

# All confirmed direct download URLs from Indiana Data Hub
# Grouped by fiscal year for clarity
$files = @(

    # ── FY 2019-2020 ──────────────────────────────────────
    @{ url = "$baseUrl/eac0955c-46b7-497a-aee2-440fe179b171/download/expenditure_2020q1.csv"; name = "expenditure_2020q1.csv" },
    @{ url = "$baseUrl/3a827586-e78f-4166-8dfe-691fb3d1fda4/download/expenditure_2020q2.csv"; name = "expenditure_2020q2.csv" },
    @{ url = "$baseUrl/adab7c80-84d5-4ba0-ae8f-86196087a117/download/expenditure_2020q3.csv"; name = "expenditure_2020q3.csv" },
    @{ url = "$baseUrl/3337b9cd-3f58-4330-8a17-459f60658405/download/expenditure_2020q4.csv"; name = "expenditure_2020q4.csv" },

    # ── FY 2020-2021 ──────────────────────────────────────
    @{ url = "$baseUrl/c34924d3-d3cb-4695-98f4-96420067eb69/download/expenditure_2021q1.csv"; name = "expenditure_2021q1.csv" },
    @{ url = "$baseUrl/4bfba9cd-a47e-4492-b210-a157fa01cdcc/download/expenditure_2021q2.csv"; name = "expenditure_2021q2.csv" },
    @{ url = "$baseUrl/54f10271-f91f-4281-90dc-29f025f0e130/download/expenditure_2021q3.csv"; name = "expenditure_2021q3.csv" },
    @{ url = "$baseUrl/88d46d3f-7f52-435e-9e9e-25db55daa814/download/expenditure_2021q4.csv"; name = "expenditure_2021q4.csv" },

    # ── FY 2021-2022 ──────────────────────────────────────
    @{ url = "$baseUrl/0ebaf43a-5396-465c-9939-384e6f65822f/download/expenditure_2022q1.csv"; name = "expenditure_2022q1.csv" },
    @{ url = "$baseUrl/8e63ea9e-be86-4b77-af5c-b5163ad80526/download/expenditure_2022q2.csv"; name = "expenditure_2022q2.csv" },
    @{ url = "$baseUrl/f20fa127-b90a-4e04-8c47-8d10d364e876/download/expenditure_2022q3.csv"; name = "expenditure_2022q3.csv" },
    @{ url = "$baseUrl/1f837243-b56c-4af6-a43f-b09fd22849e1/download/expenditure_2022q4.csv"; name = "expenditure_2022q4.csv" },

    # ── FY 2022-2023 ──────────────────────────────────────
    @{ url = "$baseUrl/bf4eec30-5722-4f5f-9017-d6b4a6f21b7d/download/expenditure_2023q1.csv"; name = "expenditure_2023q1.csv" },
    @{ url = "$baseUrl/9b07a66d-e068-498a-9d01-c9b7a25aadc4/download/expenditure_2023q2.csv"; name = "expenditure_2023q2.csv" },
    @{ url = "$baseUrl/0ee99a8c-7fe0-47d3-a3b3-882ceb476e16/download/expenditure_2023q3.csv"; name = "expenditure_2023q3.csv" },
    @{ url = "$baseUrl/b45c3fca-680f-4a0c-aeaf-6f134c5981d0/download/expenditure_2023q4.csv"; name = "expenditure_2023q4.csv" },

    # ── FY 2023-2024 ──────────────────────────────────────
    @{ url = "$baseUrl/be5922e3-9dd8-4278-a83b-4681d4be3774/download/expenditure_2024q1.csv"; name = "expenditure_2024q1.csv" },
    @{ url = "$baseUrl/99194aad-5f8a-44ae-a934-bdf67b83a861/download/expenditure_2024q2.csv"; name = "expenditure_2024q2.csv" },
    @{ url = "$baseUrl/0fbc0fd9-b1ac-4b98-ab5e-020ac30a6442/download/expenditure_2024q3.csv"; name = "expenditure_2024q3.csv" },
    @{ url = "$baseUrl/5dfac08d-9219-4f55-9fe6-703d15f87f36/download/expenditure_2024q4.csv"; name = "expenditure_2024q4.csv" },

    # ── FY 2024-2025 ──────────────────────────────────────
    @{ url = "$baseUrl/a078ebd7-e008-473b-b8b2-779420b76fff/download/expenditure_2025q1.csv"; name = "expenditure_2025q1.csv" },
    @{ url = "$baseUrl/d7ea2681-bace-4cf1-8297-71e752041eeb/download/expenditure_2025q2.csv"; name = "expenditure_2025q2.csv" },
    @{ url = "$baseUrl/5ed73f6c-6533-4e0c-b144-a9febe2871ca/download/expenditure_2025q3.csv"; name = "expenditure_2025q3.csv" },
    @{ url = "$baseUrl/8f01785f-04c1-492e-bcf2-b4ff1e9d60e2/download/expenditure_2025q4.csv"; name = "expenditure_2025q4.csv" },

    # ── FY 2025-2026 (partial year) ───────────────────────
    @{ url = "$baseUrl/f3dc14ab-7eb9-4962-b619-0c0664b6a2ed/download/expenditure_2026q1.csv"; name = "expenditure_2026q1.csv" },
    @{ url = "$baseUrl/4aa5f7d8-a67e-44f7-8e33-8bcd7bc29985/download/expenditure_2026q2.csv"; name = "expenditure_2026q2.csv" }
)

$downloaded = 0
$skipped    = 0
$failed     = 0

foreach ($f in $files) {
    $dest = Join-Path $outputDir $f.name

    if (Test-Path $dest) {
        Write-Host "  SKIP (exists): $($f.name)"
        $skipped++
        continue
    }

    Write-Host "  Downloading: $($f.name) ... " -NoNewline

    try {
        Invoke-WebRequest -Uri $f.url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        $mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
        Write-Host "OK (${mb} MB)"
        $downloaded++
    } catch {
        if (Test-Path $dest) { Remove-Item $dest }
        Write-Host "FAILED"
        $failed++
    }
}

Write-Host ""
Write-Host "==================================================="
Write-Host "  Downloaded : $downloaded files"
Write-Host "  Skipped    : $skipped files (already existed)"
Write-Host "  Failed     : $failed files"
Write-Host "==================================================="
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Create Snowflake stage: EXPENDITURE_STAGE"
Write-Host "  2. Upload files from: $outputDir"
Write-Host "  3. Run COPY INTO HOOSIER_DATA.RAW.STATE_EXPENDITURES"
Write-Host "==================================================="
