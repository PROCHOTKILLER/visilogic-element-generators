# ==============================================================================
# SKRYPT KOMPILACJI INSTRUKCJI DTR KOMORY 9 DO FORMATU PDF
# Wykorzystuje Google Chrome w trybie headless do konwersji
# pliku dokumentacja/Instrukcja_Komora9_PLC_HMI.html na dokument PDF wysokiej rozdzielczosci.
# ==============================================================================

param(
    [string]$OutputDir = "$PSScriptRoot\..\dokumentacja",
    [string]$HtmlFilename = "Instrukcja_Komora9_PLC_HMI.html",
    [string]$PdfFilename = "Instrukcja_Komora9_PLC_HMI.pdf"
)

$ErrorActionPreference = "Stop"

$ResolvedOutputDir = (Resolve-Path $OutputDir).Path
$HtmlPath = Join-Path $ResolvedOutputDir $HtmlFilename
$PdfPath = Join-Path $ResolvedOutputDir $PdfFilename

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  KOMPILACJA DOKUMENTACJI DTR DLA KOMORY SUSZARNICZEJ NR 9" -ForegroundColor Cyan
Write-Host "  Unitronics Vision V350 | Czysty Elektryk 72 kW | ANSI/ISA-101" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if (-not (Test-Path $HtmlPath)) {
    throw "Nie znaleziono pliku zrodlowego HTML: $HtmlPath"
}

# Wyszukanie instalacji Google Chrome
$ChromePaths = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

$ChromeExe = $null
foreach ($path in $ChromePaths) {
    if (Test-Path $path) {
        $ChromeExe = $path
        break
    }
}

if (-not $ChromeExe) {
    throw "Nie znaleziono przegladarki Google Chrome w systemie!"
}

Write-Host "Uzycie przegladarki: $ChromeExe" -ForegroundColor Yellow
Write-Host "Plik zrodlowy HTML: $HtmlPath" -ForegroundColor Yellow
Write-Host "Docelowy plik PDF:  $PdfPath" -ForegroundColor Yellow

$tempUserDataDir = Join-Path $env:TEMP "chrome_headless_pdf"
if (-not (Test-Path $tempUserDataDir)) {
    New-Item -ItemType Directory -Path $tempUserDataDir | Out-Null
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $ChromeExe
$psi.Arguments = "--headless=new --disable-gpu --no-pdf-header-footer --run-all-compositor-stages-before-draw --user-data-dir=`"$tempUserDataDir`" --print-to-pdf=`"$PdfPath`" `"$HtmlPath`""
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false

Write-Host "Kompilacja strony HTML i wektorow SVG do pliku PDF..." -ForegroundColor Cyan
$process = [System.Diagnostics.Process]::Start($psi)
$process.WaitForExit(60000)

if ($process.ExitCode -eq 0 -and (Test-Path $PdfPath)) {
    $pdfSize = (Get-Item $PdfPath).Length
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "  SUKCES! INSTRUKCJA PDF ZOSTALA WYGENEROWANA:" -ForegroundColor Green
    Write-Host "  Plik:    $PdfPath" -ForegroundColor Green
    Write-Host "  Rozmiar: $pdfSize bajtow" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
} else {
    $err = $process.StandardError.ReadToEnd()
    throw "Kompilacja PDF zakonczyla sie bledem! Kod: $($process.ExitCode). Blad: $err"
}
