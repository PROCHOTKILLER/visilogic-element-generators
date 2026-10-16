<#
.SYNOPSIS
    Uniwersalny skrypt uruchomieniowy (CLI Wrapper) dla Generatora Podprogramow VisiLogic (*.vlx).
    Automatycznie wykrywa architekture i w razie potrzeby przelacza sie na 32-bitowy PowerShell (SysWOW64).

.DESCRIPTION
    Narzedzie umozliwia latwe tworzenie lub kompilowanie podprogramow VisiLogic za pomoca silnika VlxBuilder.
    Moze byc wywolywane bezposrednio przez inzyniera (czlowieka) lub autonomicznego agenta AI.

.PARAMETER ScriptPath
    Sciezka do wlasnego skryptu budujacego podprogram (np. example_demo.ps1).

.PARAMETER SubName
    Nazwa podprogramu (jesli uzywany jest tryb interaktywny/prosty).

.EXAMPLE
    .\generate_subroutine.ps1 -ScriptPath .\example_demo.ps1
#>

param(
    [string]$ScriptPath = "",
    [string]$SubName = ""
)

# 1. Automatyczne przelaczenie na 32-bitowy PowerShell (wymagany przez sterownik Microsoft Jet OLEDB 4.0)
if ([IntPtr]::Size -eq 8) {
    Write-Host "[INFO] Wykryto PowerShell 64-bit. Automatyczne uruchomienie w srodowisku 32-bit (SysWOW64)..." -ForegroundColor Yellow
    $sysWow64PowerShell = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64PowerShell) {
        $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($ScriptPath) { $argList += @("-ScriptPath", "`"$ScriptPath`"") }
        if ($SubName) { $argList += @("-SubName", "`"$SubName`"") }
        
        $process = Start-Process -FilePath $sysWow64PowerShell -ArgumentList $argList -NoNewWindow -Wait -PassThru
        exit $process.ExitCode
    } else {
        Write-Error "[BLAD] Nie znaleziono 32-bitowego PowerShell pod sciezka: $sysWow64PowerShell"
        exit 1
    }
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   GENERATOR PODPROGRAMOW VISILOGIC (*.VLX) - ALL-IN-ONE (AIO)        " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$currentDir = Split-Path -Parent $PSCommandPath
$vlxBuilderFile = Join-Path $currentDir "VlxBuilder.ps1"

if (-not (Test-Path $vlxBuilderFile)) {
    Write-Error "[BLAD] Nie znaleziono biblioteki silnika: $vlxBuilderFile"
    exit 1
}

. $vlxBuilderFile

if ($ScriptPath -ne "") {
    if (Test-Path $ScriptPath) {
        Write-Host "[INFO] Uruchamianie dedykowanego skryptu definicji: $ScriptPath" -ForegroundColor Green
        . $ScriptPath
        exit 0
    } else {
        Write-Error "[BLAD] Podany plik skryptu nie istnieje: $ScriptPath"
        exit 1
    }
}

Write-Host "[INFO] Tryb bazowy: Uruchomiono srodowisko VlxBuilder." -ForegroundColor Green
Write-Host "Mozesz zaimportowac klase VlxBuilder do wlasnego skryptu PowerShell lub uruchomic:" -ForegroundColor Gray
Write-Host "  .\generate_subroutine.ps1 -ScriptPath .\example_demo.ps1" -ForegroundColor Yellow
