<#
.SYNOPSIS
    inspect_elements.ps1 - Diagnostic inspector for Unitronics VisiLogic HMI Display (.vld) archives.
.DESCRIPTION
    Extracts HMIBufferColorPages.udb from a .vld ZIP package and prints all HMI displays,
    elements, and jumps stored in the Microsoft Jet 4.0 database.
#>

param(
    [string]$VldPath = "..\examples\hmi-displays\WATER_TREATMENT_PUMPING.vld"
)

if ([IntPtr]::Size -eq 8) {
    $sysWow64 = Join-Path $env:windir "SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $sysWow64) {
        $p = Start-Process -FilePath $sysWow64 -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"", "-VldPath", "`"$VldPath`"") -NoNewWindow -Wait -PassThru
        exit $p.ExitCode
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$resolvedVld = if ([System.IO.Path]::IsPathRooted($VldPath)) { $VldPath } else { Join-Path $PSScriptRoot $VldPath }
if (-not (Test-Path $resolvedVld)) {
    throw "VLD file not found: $resolvedVld"
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vld_inspect_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($resolvedVld, $tempDir)
    $udbFile = Join-Path $tempDir "HMIBufferColorPages.udb"

    $connStr = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$udbFile;"
    $conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
    $conn.Open()

    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT ID, Text, VarType, Xs, Ys, Dx, Dy, OprndType, OprndAddr, TouchOprndType, TouchOprndAddr, ColorFore, ColorBack, FontIndex, ButtonStyle FROM HMI_Elements WHERE DisplayID = 1 ORDER BY ID"
    $adapter = New-Object System.Data.OleDb.OleDbDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    $adapter.Fill($dt) | Out-Null
    $dt | Format-Table -AutoSize

    $cmd.CommandText = "SELECT * FROM HMIJumps WHERE PageNum <= 5"
    $adapter = New-Object System.Data.OleDb.OleDbDataAdapter($cmd)
    $dt2 = New-Object System.Data.DataTable
    $adapter.Fill($dt2) | Out-Null
    Write-Host "--- JUMPS ---"
    $dt2 | Format-Table -AutoSize

    $conn.Close()
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
