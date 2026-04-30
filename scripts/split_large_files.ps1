# ============================================================
# Split files over 200MB for Snowflake stage upload
# Snowflake UI has a 250MB upload limit
# Usage: Edit $sourceFile and run
# ============================================================

param(
    [string]$sourceDir = "C:\Users\jburbrink\Downloads\GATEWAY_UPLOAD",
    [string]$outputDir = "C:\Users\jburbrink\Downloads\GATEWAY_UPLOAD_SPLIT",
    [int]$maxMB = 200
)

$maxBytes = $maxMB * 1MB
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$files = Get-ChildItem -Path $sourceDir -Filter "*.txt" | Where-Object { $_.Length -gt ($maxBytes) }

foreach ($file in $files) {
    $sizeMB = [math]::Round($file.Length / 1MB, 0)
    Write-Host "Splitting: $($file.Name) ($sizeMB MB)..."

    $reader  = [System.IO.StreamReader]::new($file.FullName)
    $header  = $reader.ReadLine()
    $partNum = 1
    $bytes   = 0
    $writer  = $null

    while (-not $reader.EndOfStream) {
        if ($null -eq $writer -or $bytes -ge $maxBytes) {
            if ($writer) { $writer.Flush(); $writer.Close() }
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            $outFile  = Join-Path $outputDir "${baseName}_part${partNum}.txt"
            $writer   = [System.IO.StreamWriter]::new($outFile, $false, [System.Text.Encoding]::UTF8)
            $writer.WriteLine($header)
            $bytes    = [System.Text.Encoding]::UTF8.GetByteCount($header + "`n")
            Write-Host "  Writing part $partNum..."
            $partNum++
        }
        $line   = $reader.ReadLine()
        $writer.WriteLine($line)
        $bytes += [System.Text.Encoding]::UTF8.GetByteCount($line + "`n")
    }

    if ($writer) { $writer.Flush(); $writer.Close() }
    $reader.Close()
    Write-Host "  Done — $($partNum - 1) parts"
}

Write-Host "Complete. Upload files from: $outputDir"
