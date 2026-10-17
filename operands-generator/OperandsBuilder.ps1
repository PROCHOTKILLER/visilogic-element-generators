<#
.SYNOPSIS
    OperandsBuilder.ps1 - Object-Oriented Operands Database Generator Engine (.csv) for Unitronics VisiLogic.
.DESCRIPTION
    Manages the full 8,192-row x 18-column VisiLogic operand address space (MB, MI, MF, ML, MDW,
    SB, SI, SL, SDW, I, O, T, C, XB, XI, XL, XDW), preserves factory Unitronics system tag descriptions,
    sanitizes commas and length limits, scans compiled ladder subroutines (*.vlx) for unlabelled variables,
    and writes Windows-1250 (ANSI) CSV files ready for direct import into Unitronics VisiLogic.
#>

class OperandsBuilder {
    [string[]]$Columns = @(
        "Address", "MB", "MI", "MF", "ML", "MDW",
        "SB", "SI", "SL", "SDW",
        "I", "O", "T", "C",
        "XB", "XI", "XL", "XDW"
    )
    [int]$MaxAddress = 8191
    [int]$MaxDescLength = 50
    [hashtable]$Grid

    OperandsBuilder() {
        $this.InitGrid()
    }

    OperandsBuilder([string]$templatePath) {
        $this.InitGrid()
        if (-not [string]::IsNullOrWhiteSpace($templatePath)) {
            $this.LoadCsv($templatePath, $true)
        }
    }

    [void] InitGrid() {
        $this.Grid = @{}
        foreach ($col in $this.Columns) {
            if ($col -ne "Address") {
                $this.Grid[$col] = New-Object string[] ($this.MaxAddress + 1)
            }
        }
    }

    [void] LoadTemplate([string]$templatePath) {
        $this.LoadCsv($templatePath, $true)
    }

    [string] SanitizeDescription([string]$raw, [bool]$isSystemColumn) {
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return ""
        }
        $clean = $raw -replace "[\r\n]+", " "
        $clean = $clean.Trim()
        # Replace commas with pipe '|' because VisiLogic's CSV parser splits unconditionally on ','
        if ($clean.Contains(",")) {
            $clean = $clean.Replace(",", "|")
        }
        if (-not $isSystemColumn -and $clean.Length -gt $this.MaxDescLength) {
            $clean = $clean.Substring(0, $this.MaxDescLength).Trim()
        }
        return $clean
    }

    [void] SetOperand([string]$type, [int]$address, [string]$description) {
        $col = $type.Trim().ToUpperInvariant()
        if (-not $this.Grid.ContainsKey($col)) {
            throw "Unsupported operand type: $col"
        }
        if ($address -lt 0 -or $address -gt $this.MaxAddress) {
            throw "Operand address out of range (0..$($this.MaxAddress)): $col $address"
        }
        $isSys = $col -in @("SB", "SI", "SL", "SDW")
        $this.Grid[$col][$address] = $this.SanitizeDescription($description, $isSys)
    }

    [string] GetOperand([string]$type, [int]$address) {
        $col = $type.Trim().ToUpperInvariant()
        if (-not $this.Grid.ContainsKey($col)) {
            return ""
        }
        if ($address -lt 0 -or $address -gt $this.MaxAddress) {
            return ""
        }
        return [string]$this.Grid[$col][$address]
    }

    [void] LoadCsv([string]$csvPath, [bool]$overwriteSystem) {
        if (-not (Test-Path $csvPath)) {
            throw "CSV file does not exist: $csvPath"
        }
        $enc = [System.Text.Encoding]::GetEncoding(1250)
        $lines = [System.IO.File]::ReadAllLines($csvPath, $enc)
        if ($lines.Count -lt 2) {
            return
        }

        for ($i = 1; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $parts = $line.Split(',')
            $addr = 0
            if (-not [int]::TryParse($parts[0].Trim(), [ref]$addr)) { continue }
            if ($addr -lt 0 -or $addr -gt $this.MaxAddress) { continue }

            for ($cIdx = 1; $cIdx -lt $this.Columns.Count; $cIdx++) {
                if ($cIdx -ge $parts.Count) { break }
                $colName = $this.Columns[$cIdx]
                $val = $parts[$cIdx]
                if ([string]::IsNullOrWhiteSpace($val)) { continue }

                $isSys = $colName -in @("SB", "SI", "SL", "SDW")
                if ($isSys -and -not $overwriteSystem -and -not [string]::IsNullOrWhiteSpace($this.Grid[$colName][$addr])) {
                    continue
                }
                $this.Grid[$colName][$addr] = $this.SanitizeDescription($val, $isSys)
            }
        }
    }

    [int] ImportIoMap([string]$ioCsvPath) {
        if (-not (Test-Path $ioCsvPath)) {
            throw "I/O map CSV file does not exist: $ioCsvPath"
        }
        $enc = [System.Text.Encoding]::GetEncoding(1250)
        $lines = [System.IO.File]::ReadAllLines($ioCsvPath, $enc)
        $imported = 0

        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $delim = if ($line.Contains(";")) { ';' } else { ',' }
            $parts = $line.Split($delim)
            if ($parts.Count -lt 3) { continue }

            $rawType = $parts[0].Trim().ToUpperInvariant()
            $rawAddr = $parts[1].Trim()
            $rawDesc = $parts[2].Trim()

            if ($rawDesc -match "(?i)^(EMPTY|FREE|SPARE|RESERVED|UNUSED|-+)$") {
                continue
            }

            $addr = 0
            if ($rawAddr -match "^(MB|MI|MF|ML|MDW|I|O|T|C)\s*(\d+)$") {
                $rawType = $Matches[1].ToUpperInvariant()
                $addr = [int]$Matches[2]
            } elseif (-not [int]::TryParse($rawAddr, [ref]$addr)) {
                continue
            }

            if ($this.Grid.ContainsKey($rawType) -and $addr -ge 0 -and $addr -le $this.MaxAddress -and -not [string]::IsNullOrWhiteSpace($rawDesc)) {
                $this.SetOperand($rawType, $addr, $rawDesc)
                $imported++
            }
        }
        return $imported
    }

    [int] ScanVlxDirectory([string]$vlxDir, [bool]$autoNameMissing) {
        if (-not (Test-Path $vlxDir)) {
            return 0
        }
        if ([IntPtr]::Size -ne 4) {
            throw "Scanning *.vlx databases requires 32-bit PowerShell (x86) for Microsoft.Jet.OLEDB.4.0."
        }

        $typeMap = @{
            1  = "MB"
            2  = "SB"
            3  = "MI"
            4  = "SI"
            5  = "ML"
            6  = "SL"
            7  = "MF"
            9  = "I"
            10 = "O"
            11 = "T"
            12 = "C"
            16 = "MDW"
        }

        $missingFilled = 0
        $vlxFiles = Get-ChildItem -Path $vlxDir -Filter "*.vlx" -File -Recurse

        foreach ($file in $vlxFiles) {
            $cs = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$($file.FullName);Jet OLEDB:Database Password=UniOpenSesame;"
            $conn = New-Object System.Data.OleDb.OleDbConnection($cs)
            try {
                $conn.Open()
                $cmd = $conn.CreateCommand()

                # First import any explicit descriptions stored inside expimp_LdrOperands
                $cmd.CommandText = "SELECT OprndType, OprndAddress, OprndDescription FROM expimp_LdrOperands"
                $reader = $cmd.ExecuteReader()
                while ($reader.Read()) {
                    $tId = [int]$reader["OprndType"]
                    $addr = [int]$reader["OprndAddress"]
                    $desc = if ($reader["OprndDescription"] -is [System.DBNull]) { "" } else { [string]$reader["OprndDescription"] }
                    if ($typeMap.ContainsKey($tId) -and $addr -ge 0 -and $addr -le $this.MaxAddress) {
                        $col = $typeMap[$tId]
                        if (-not ($col -in @("SB", "SI", "SL", "SDW")) -and -not [string]::IsNullOrWhiteSpace($desc)) {
                            if ([string]::IsNullOrWhiteSpace($this.GetOperand($col, $addr))) {
                                $this.SetOperand($col, $addr, $desc)
                            }
                        }
                    }
                }
                $reader.Close()

                # Next scan expimp_LdrElmsOprs for any used operands lacking descriptions
                $cmd.CommandText = "SELECT DISTINCT Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs FROM expimp_LdrElmsOprs"
                $reader2 = $cmd.ExecuteReader()
                while ($reader2.Read()) {
                    if ($reader2[0] -is [System.DBNull] -or $reader2[1] -is [System.DBNull]) { continue }
                    $tId = [int]$reader2[0]
                    $addr = [int]$reader2[1]
                    if ($typeMap.ContainsKey($tId) -and $addr -ge 0 -and $addr -le $this.MaxAddress) {
                        $col = $typeMap[$tId]
                        if ($col -in @("SB", "SI", "SL", "SDW")) { continue }
                        $existing = $this.GetOperand($col, $addr)
                        if ([string]::IsNullOrWhiteSpace($existing) -and $autoNameMissing) {
                            $this.SetOperand($col, $addr, "Auto_${col}_${addr}")
                            $missingFilled++
                        }
                    }
                }
                $reader2.Close()
            } finally {
                $conn.Close()
            }
        }
        return $missingFilled
    }

    [void] SaveCsv([string]$outputPath) {
        $sb = New-Object System.Text.StringBuilder(1048576)
        # Header (18 columns, no trailing comma)
        [void]$sb.AppendLine(($this.Columns -join ","))

        # 8,192 rows (0..8191), each ending with a trailing comma per VisiLogic's native export format
        for ($addr = 0; $addr -le $this.MaxAddress; $addr++) {
            [void]$sb.Append($addr)
            [void]$sb.Append(",")
            for ($cIdx = 1; $cIdx -lt $this.Columns.Count; $cIdx++) {
                $col = $this.Columns[$cIdx]
                $val = $this.Grid[$col][$addr]
                if (-not [string]::IsNullOrEmpty($val)) {
                    [void]$sb.Append($val)
                }
                [void]$sb.Append(",")
            }
            [void]$sb.AppendLine()
        }

        $parentDir = Split-Path -Parent $outputPath
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $enc = [System.Text.Encoding]::GetEncoding(1250)
        [System.IO.File]::WriteAllText($outputPath, $sb.ToString(), $enc)
    }

    [void] SaveToCsv([string]$outputPath) {
        $this.SaveCsv($outputPath)
    }
}
