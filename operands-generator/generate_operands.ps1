<#
.SYNOPSIS
    generate_operands.ps1 - Universal CLI Generator for Unitronics VisiLogic Operand Databases (.csv).
.DESCRIPTION
    Loads the baseline 8,192-row VisiLogic operand template (preserving SB/SI/SL/SDW factory descriptions),
    merges custom operand CSVs and hardware I/O maps, optionally scans compiled ladder subroutines (*.vlx)
    to auto-tag undeclared variables, and outputs a verified Windows-1250 CSV file.
.EXAMPLE
    .\generate_operands.ps1 -OutputPath ".\project_operands.csv" -InputCsv ".\base_operands.csv" -IoCsv ".\io_map.csv" -VlxDir "..\subroutines" -AutoNameMissing
#>

param(
    [string]$OutputPath = "",
    [string]$TemplatePath = "",
    [string]$InputCsv = "",
    [string]$IoCsv = "",
    [string]$VlxDir = "",
    [switch]$AutoNameMissing
)

if (-not [string]::IsNullOrWhiteSpace($VlxDir) -and [IntPtr]::Size -eq 8) {
    $sysWow64 = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64) {
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($OutputPath) { $argList += @("-OutputPath", "`"$OutputPath`"") }
        if ($TemplatePath) { $argList += @("-TemplatePath", "`"$TemplatePath`"") }
        if ($InputCsv) { $argList += @("-InputCsv", "`"$InputCsv`"") }
        if ($IoCsv) { $argList += @("-IoCsv", "`"$IoCsv`"") }
        if ($VlxDir) { $argList += @("-VlxDir", "`"$VlxDir`"") }
        if ($AutoNameMissing) { $argList += "-AutoNameMissing" }
        $p = Start-Process -FilePath $sysWow64 -ArgumentList $argList -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "OperandsBuilder.ps1")

if ([string]::IsNullOrWhiteSpace($TemplatePath)) {
    $TemplatePath = Join-Path $scriptDir "templates\template_operands.csv"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptDir "GENERATED_OPERANDS.csv"
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   UNITRONICS VISILOGIC OPERANDS DATABASE GENERATOR (.CSV)            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

Write-Host "[INFO] Loading baseline template: $TemplatePath" -ForegroundColor Yellow
$builder = [OperandsBuilder]::new($TemplatePath)

if (-not [string]::IsNullOrWhiteSpace($InputCsv)) {
    Write-Host "[INFO] Merging input operands CSV: $InputCsv" -ForegroundColor Yellow
    $builder.LoadCsv($InputCsv, $false)
}

if (-not [string]::IsNullOrWhiteSpace($IoCsv)) {
    Write-Host "[INFO] Importing physical I/O map: $IoCsv" -ForegroundColor Yellow
    $countIo = $builder.ImportIoMap($IoCsv)
    Write-Host "  -> Mapped $countIo I/O tags." -ForegroundColor Green
}

if (-not [string]::IsNullOrWhiteSpace($VlxDir)) {
    Write-Host "[INFO] Scanning ladder subroutines (*.vlx) in: $VlxDir" -ForegroundColor Yellow
    $countAuto = $builder.ScanVlxDirectory($VlxDir, [bool]$AutoNameMissing)
    Write-Host "  -> Auto-named $countAuto previously untagged operands." -ForegroundColor Green
}

$builder.SaveCsv($OutputPath)
Write-Host "[SUCCESS] Saved VisiLogic operands database: $OutputPath" -ForegroundColor Green

$verifier = Join-Path $scriptDir "verify_operands.ps1"
if (Test-Path $verifier) {
    $vArgs = @{ CsvPath = $OutputPath }
    if (-not [string]::IsNullOrWhiteSpace($VlxDir)) { $vArgs["VlxDir"] = $VlxDir }
    & $verifier @vArgs
}
