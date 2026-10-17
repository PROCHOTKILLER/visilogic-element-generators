<#
.SYNOPSIS
    Universal CLI Wrapper for the Unitronics VisiLogic Subroutine Generator (*.vlx).
    Automatically detects process architecture and relaunches in 32-bit PowerShell (SysWOW64) when required.

.DESCRIPTION
    Enables creating or compiling VisiLogic ladder subroutines using the VlxBuilder engine.
    Designed to be invoked directly by control engineers or automated AI agents.

.PARAMETER ScriptPath
    Path to a subroutine definition script (e.g., example_demo.ps1).

.PARAMETER SubName
    Subroutine name (when invoked in interactive/basic mode).

.EXAMPLE
    .\generate_subroutine.ps1 -ScriptPath .\example_demo.ps1
#>

param(
    [string]$ScriptPath = "",
    [string]$SubName = ""
)

# 1. Automatic switch to 32-bit PowerShell (required by the Microsoft Jet OLEDB 4.0 driver)
if ([IntPtr]::Size -eq 8) {
    Write-Host "[INFO] 64-bit PowerShell detected. Relaunching in 32-bit environment (SysWOW64)..." -ForegroundColor Yellow
    $sysWow64PowerShell = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64PowerShell) {
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($ScriptPath) { $argList += @("-ScriptPath", "`"$ScriptPath`"") }
        if ($SubName) { $argList += @("-SubName", "`"$SubName`"") }
        
        $process = Start-Process -FilePath $sysWow64PowerShell -ArgumentList $argList -NoNewWindow -Wait -PassThru
        exit $process.ExitCode
    } else {
        Write-Error "[ERROR] 32-bit PowerShell not found at: $sysWow64PowerShell"
        exit 1
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   VISILOGIC SUBROUTINE GENERATOR (*.VLX) - ALL-IN-ONE (AIO)          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$currentDir = Split-Path -Parent $PSCommandPath
$vlxBuilderFile = Join-Path $currentDir "VlxBuilder.ps1"

if (-not (Test-Path $vlxBuilderFile)) {
    Write-Error "[ERROR] Engine library not found: $vlxBuilderFile"
    exit 1
}

. $vlxBuilderFile

if ($ScriptPath -ne "") {
    if (Test-Path $ScriptPath) {
        Write-Host "[INFO] Executing subroutine definition script: $ScriptPath" -ForegroundColor Green
        . $ScriptPath
        exit 0
    } else {
        Write-Error "[ERROR] Specified script file does not exist: $ScriptPath"
        exit 1
    }
}

Write-Host "[INFO] Base mode: VlxBuilder environment initialized." -ForegroundColor Green
Write-Host "Import the VlxBuilder class into your PowerShell script or run:" -ForegroundColor Gray
Write-Host "  .\generate_subroutine.ps1 -ScriptPath .\example_demo.ps1" -ForegroundColor Yellow
