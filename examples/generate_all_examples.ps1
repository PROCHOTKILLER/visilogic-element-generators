<#
.SYNOPSIS
    generate_all_examples.ps1 - Master generator script that compiles and verifies
    all universal examples across all 4 VisiLogic element categories:
    1. HMI Displays (.vld)
    2. Data Tables (.xml)
    3. Operands (.csv)
    4. Ladder Subroutines (.vlx)
#>

[CmdletBinding()]
param()

# Self-relaunch in 32-bit PowerShell (SysWOW64) for Jet 4.0 database compatibility
if ([IntPtr]::Size -eq 8) {
    $sysWow64 = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64) {
        $p = Start-Process -FilePath $sysWow64 -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"") -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

$examplesDir = Split-Path -Parent $PSCommandPath

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   UNITRONICS VISILOGIC MASTER ELEMENT EXAMPLES GENERATOR             " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$scripts = @(
    @{ Name = "HMI Displays"; Path = (Join-Path $examplesDir "hmi-displays\generate_hmi_examples.ps1") },
    @{ Name = "Data Tables";  Path = (Join-Path $examplesDir "data-tables\generate_data_table_examples.ps1") },
    @{ Name = "Operands";     Path = (Join-Path $examplesDir "operands\generate_operand_examples.ps1") },
    @{ Name = "Subroutines";  Path = (Join-Path $examplesDir "subroutines\generate_subroutine_examples.ps1") }
)

foreach ($item in $scripts) {
    Write-Host "`n>>> Running Generator Suite: $($item.Name) <<<" -ForegroundColor Magenta
    if (-not (Test-Path $item.Path)) {
        throw "Script not found: $($item.Path)"
    }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $item.Path
    if ($LASTEXITCODE -ne 0) {
        throw "Execution failed for $($item.Name) with exit code $LASTEXITCODE"
    }
}

Write-Host "`n======================================================================" -ForegroundColor Green
Write-Host "   ALL VISILOGIC ELEMENT EXAMPLES SUCCESSFULLY GENERATED & VERIFIED!  " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
