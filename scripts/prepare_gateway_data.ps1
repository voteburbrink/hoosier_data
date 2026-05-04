# prepare_gateway_data.ps1
# Filter statewide Indiana Gateway AFR files to Bartholomew County
# and convert pipe-delimited format to standard CSV for Snowflake upload.
#
# Usage:
#   .\prepare_gateway_data.ps1 -InputDir "C:\path\to\extracted" -OutputDir "C:\path\to\upload_ready"
#
# Input files expected (unzipped from Indiana Gateway bulk downloads):
#   detailedDisburse_fundswithdept.csv  -- pipe-delimited, double-quoted
#   detailedReceipts.csv                -- pipe-delimited, double-quoted
#   form22.csv                          -- pipe-delimited, double-quoted
#   certNav.csv                         -- comma-delimited (no conversion needed)
#
# AFR unit types:
#   '1' = County    '2' = City     '3' = Town
#   '5' = School Corporation         '6' = Library
#   '7' = Township

param(
    [string]$InputDir  = "C:\Users\jburbrink\SynologyDrive\Documents\Data\Gateway\extracted",
    [string]$OutputDir = "C:\Users\jburbrink\SynologyDrive\Documents\Data\Gateway\upload_ready"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

function Convert-PipeToCSV {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [string]$FilterString = "BARTHOLOMEW"
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $reader    = [System.IO.StreamReader]::new($InputFile)
    $writer    = [System.IO.StreamWriter]::new($OutputFile, $false, [System.Text.Encoding]::UTF8)

    $headerLine = $reader.ReadLine()
    if ($null -ne $headerLine) {
        $csvHeader = $headerLine.Replace('"|"', '","').TrimStart('"').TrimEnd('"')
        $writer.WriteLine($csvHeader)
    }

    $kept  = 0
    $total = 0

    while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        $total++
        if ($line -like "*$FilterString*") {
            $csvLine = $line.Replace('"|"', '","').TrimStart('"').TrimEnd('"')
            $writer.WriteLine($csvLine)
            $kept++
        }
    }

    $reader.Close()
    $writer.Close()
    $stopwatch.Stop()

    Write-Host ("  {0}: {1:N0} of {2:N0} rows kept in {3:0.0}s" -f `
        (Split-Path $InputFile -Leaf), $kept, $total, $stopwatch.Elapsed.TotalSeconds)
}

function Copy-CsvFiltered {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [string]$FilterString = "BARTHOLOMEW"
    )

    $reader = [System.IO.StreamReader]::new($InputFile)
    $writer = [System.IO.StreamWriter]::new($OutputFile, $false, [System.Text.Encoding]::UTF8)

    $headerLine = $reader.ReadLine()
    if ($null -ne $headerLine) { $writer.WriteLine($headerLine) }

    $kept = 0
    while (-not $reader.EndOfStream) {
        $line = $reader.ReadLine()
        if ($line -like "*$FilterString*") {
            $writer.WriteLine($line)
            $kept++
        }
    }

    $reader.Close()
    $writer.Close()
    Write-Host ("  {0}: {1:N0} rows kept" -f (Split-Path $InputFile -Leaf), $kept)
}

Write-Host "Filtering Gateway files to Bartholomew County..."
Write-Host "Input:  $InputDir"
Write-Host "Output: $OutputDir"
Write-Host ""

$files = @(
    @{ Name = "detailedDisburse_fundswithdept.csv"; Pipe = $true  },
    @{ Name = "detailedReceipts.csv";                Pipe = $true  },
    @{ Name = "form22.csv";                          Pipe = $true  },
    @{ Name = "certNav.csv";                         Pipe = $false }
)

foreach ($f in $files) {
    $inPath  = Join-Path $InputDir $f.Name
    $outPath = Join-Path $OutputDir $f.Name

    if (-not (Test-Path $inPath)) {
        Write-Warning "Not found, skipping: $inPath"
        continue
    }

    if ($f.Pipe) {
        Convert-PipeToCSV -InputFile $inPath -OutputFile $outPath
    } else {
        Copy-CsvFiltered  -InputFile $inPath -OutputFile $outPath
    }
}

Write-Host ""
Write-Host "Done. Upload the files in $OutputDir to Snowflake:"
Write-Host "  GATEWAY_DISBURSEMENTS_DETAIL <- detailedDisburse_fundswithdept.csv"
Write-Host "  GATEWAY_RECEIPTS_DETAIL      <- detailedReceipts.csv"
Write-Host "  GATEWAY_FORM22               <- form22.csv"
Write-Host "  GATEWAY_CERT_NAV             <- certNav.csv"
Write-Host ""
Write-Host "Snowflake load settings: CSV format, comma delimiter, first row as header, on_error=continue"
