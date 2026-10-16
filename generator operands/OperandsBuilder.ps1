<#
.SYNOPSIS
    Silnik obiektowy generatora plikow definicji operandow (operands.csv) dla Unitronics VisiLogic.
.DESCRIPTION
    Zarzadza tytulami/opisami operandow we wszystkich 17 typach pamieci VisiLogic:
    MB, MI, MF, ML, MDW, SB, SI, SL, SDW, I, O, T, C, XB, XI, XL, XDW.
    Generuje pliki CSV w pelni zgodne ze standardem eksportu/importu VisiLogic (8192 wiersze, 18 kolumn, CP1250/ANSI).
#>

class OperandsBuilder {
    [string]$TemplatePath
    [string[]]$Header
    [hashtable]$Data
    [string[]]$TypeNames = @('MB','MI','MF','ML','MDW','SB','SI','SL','SDW','I','O','T','C','XB','XI','XL','XDW')

    OperandsBuilder() {
        $this.Header = @('Address','MB','MI','MF','ML','MDW','SB','SI','SL','SDW','I','O','T','C','XB','XI','XL','XDW')
        $this.Data = @{}
        foreach ($t in $this.TypeNames) {
            $arr = New-Object string[] 8192
            for ($i = 0; $i -lt 8192; $i++) {
                $arr[$i] = ""
            }
            $this.Data[$t] = $arr
        }
    }

    [void]LoadTemplate([string]$path) {
        $this.TemplatePath = $path
        if (-not (Test-Path $path)) {
            throw "Nie znaleziono pliku szablonu: $path"
        }

        $enc = [System.Text.Encoding]::GetEncoding(1250)
        $lines = [System.IO.File]::ReadAllLines($path, $enc)
        if ($lines.Length -lt 2) {
            throw "Plik szablonu jest pusty lub uszkodzony."
        }

        $limit = [Math]::Min($lines.Length - 1, 8192)
        for ($i = 1; $i -le $limit; $i++) {
            $rowIdx = $i - 1
            $parts = $lines[$i].Split(',')
            for ($c = 0; $c -lt $this.TypeNames.Length; $c++) {
                $colIdx = $c + 1
                if ($colIdx -lt $parts.Length) {
                    $val = $parts[$colIdx].Trim()
                    if ($val -ne "") {
                        $tName = $this.TypeNames[$c]
                        $this.Data[$tName][$rowIdx] = $val
                    }
                }
            }
        }
    }

    [string]SanitizeDescription([string]$text) {
        if ([string]::IsNullOrEmpty($text)) { return "" }
        $clean = $text.Replace(',', '|').Replace("`r", "").Replace("`n", " ")
        $clean = [regex]::Replace($clean, '\s+', ' ').Trim()
        if ($clean.Length -gt 50) {
            $clean = $clean.Substring(0, 50).Trim()
        }
        return $clean
    }

    [void]SetOperand([string]$type, [int]$address, [string]$description) {
        $typeUpper = $type.ToUpper()
        if (-not $this.Data.ContainsKey($typeUpper)) {
            throw "Nieznany typ operandu: '$type'. Dozwolone: $($this.TypeNames -join ', ')"
        }
        if ($address -lt 0 -or $address -ge 8192) {
            throw "Adres operandu $address poza zakresem (0..8191)."
        }
        $sanitized = $this.SanitizeDescription($description)
        $this.Data[$typeUpper][$address] = $sanitized
    }

    [string]GetOperand([string]$type, [int]$address) {
        $typeUpper = $type.ToUpper()
        if (-not $this.Data.ContainsKey($typeUpper) -or $address -lt 0 -or $address -ge 8192) {
            return ""
        }
        return $this.Data[$typeUpper][$address]
    }

    [void]AddBulk([string]$type, [hashtable]$map) {
        foreach ($addr in $map.Keys) {
            $this.SetOperand($type, [int]$addr, [string]$map[$addr])
        }
    }

    [void]MergeExistingCsv([string]$csvPath) {
        if (-not (Test-Path $csvPath)) {
            throw "Nie znaleziono pliku CSV do scalenia: $csvPath"
        }
        $enc = [System.Text.Encoding]::GetEncoding(1250)
        $lines = [System.IO.File]::ReadAllLines($csvPath, $enc)
        $limit = [Math]::Min($lines.Length - 1, 8192)
        for ($i = 1; $i -le $limit; $i++) {
            $rowIdx = $i - 1
            $parts = $lines[$i].Split(',')
            for ($c = 0; $c -lt $this.TypeNames.Length; $c++) {
                $colIdx = $c + 1
                if ($colIdx -lt $parts.Length) {
                    $val = $parts[$colIdx].Trim()
                    if ($val -ne "") {
                        $tName = $this.TypeNames[$c]
                        $this.Data[$tName][$rowIdx] = $this.SanitizeDescription($val)
                    }
                }
            }
        }
    }

    [int]ImportIoList([string]$ioCsvPath) {
        if (-not (Test-Path $ioCsvPath)) {
            return 0
        }
        $enc = [System.Text.Encoding]::GetEncoding(1250)
        $lines = [System.IO.File]::ReadAllLines($ioCsvPath, $enc)
        $count = 0

        for ($i = 1; $i -lt $lines.Length; $i++) {
            $line = $lines[$i].Trim()
            if ($line -eq "") { continue }
            $cols = $line.Split(';')
            if ($cols.Length -lt 5) { continue }

            $plcAddr = $cols[1].Trim().ToUpper()
            $sigName = $cols[4].Trim()

            if ($sigName -eq "" -or $sigName -eq "-" -or $sigName -match "PUSTE" -or $sigName -match "WOLNE") {
                continue
            }

            if ($plcAddr -match '^([A-Z]+)(\d+)$') {
                $prefix = $Matches[1]
                $num = [int]$Matches[2]
                $targetType = ""

                switch ($prefix) {
                    'I'   { $targetType = 'I' }
                    'O'   { $targetType = 'O' }
                    'AI'  { $targetType = 'MI' }
                    'MB'  { $targetType = 'MB' }
                    'MI'  { $targetType = 'MI' }
                    'ML'  { $targetType = 'ML' }
                    'DW'  { $targetType = 'MDW' }
                    'MF'  { $targetType = 'MF' }
                    'T'   { $targetType = 'T' }
                }

                if ($targetType -ne "") {
                    $safeName = $sigName.Replace(' ', '_').Replace('-', '_').Replace('.', '_')
                    $this.SetOperand($targetType, $num, $safeName)
                    $count++
                }
            }
        }
        return $count
    }

    [hashtable]ScanVlxOperands([string]$vlxDirectory) {
        $results = @{
            'Used' = @{};
            'Missing' = [System.Collections.Generic.List[object]]::new()
        }

        if (-not (Test-Path $vlxDirectory)) { return $results }
        $vlxFiles = Get-ChildItem -Path $vlxDirectory -Filter "*.vlx" -Recurse

        $typeMap = @{
            0  = 'MB'
            1  = 'MI'
            2  = 'ML'
            3  = 'MDW'
            4  = 'MF'
            5  = 'T'
            6  = 'C'
            8  = 'XB'
            9  = 'XI'
            10 = 'I'
            11 = 'O'
            14 = 'XL'
            15 = 'XDW'
            18 = 'SB'
            19 = 'SI'
            20 = 'SL'
            21 = 'SDW'
        }

        foreach ($f in $vlxFiles) {
            try {
                $connStr = 'Provider=Microsoft.Jet.OLEDB.4.0;Data Source=' + $f.FullName + ';Jet OLEDB:Database Password=UniOpenSesame;'
                $conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = 'SELECT DISTINCT Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs FROM expimp_LdrElmsOprs WHERE Elmnt_Oprnd_Type <> 37'
                $reader = $cmd.ExecuteReader()
                while ($reader.Read()) {
                    $rawType = $reader.GetInt32(0)
                    $addr = $reader.GetInt32(1)
                    if ($typeMap.ContainsKey($rawType)) {
                        $colName = $typeMap[$rawType]
                        $key = $colName + ':' + $addr.ToString()
                        $results['Used'][$key] = $true

                        $currentDesc = $this.GetOperand($colName, $addr)
                        if ([string]::IsNullOrEmpty($currentDesc)) {
                            $missingItem = [PSCustomObject]@{
                                File = $f.Name
                                Type = $colName
                                Address = $addr
                                RawType = $rawType
                            }
                            $results['Missing'].Add($missingItem)
                        }
                    }
                }
                $reader.Close()
                $conn.Close()
            } catch {
                # Ignoruj ewentualne bledy dostepu w 64-bit
            }
        }
        return $results
    }

    [hashtable]GetStats() {
        $stats = @{}
        foreach ($t in $this.TypeNames) {
            $cnt = 0
            for ($i = 0; $i -lt 8192; $i++) {
                if ($this.Data[$t][$i] -ne "") { $cnt++ }
            }
            $stats[$t] = $cnt
        }
        return $stats
    }

    [void]SaveToCsv([string]$outputPath) {
        $this.SaveToCsv($outputPath, "Windows-1250")
    }

    [void]SaveToCsv([string]$outputPath, [string]$encodingName) {
        $outDir = Split-Path -Parent $outputPath
        if ($outDir -and -not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }

        $enc = [System.Text.Encoding]::GetEncoding($encodingName)
        $outLines = [System.Collections.Generic.List[string]]::new(8193)

        $outLines.Add(($this.Header -join ','))

        for ($addr = 0; $addr -lt 8192; $addr++) {
            $rowValues = [System.Collections.Generic.List[string]]::new(18)
            $rowValues.Add($addr.ToString())

            foreach ($t in $this.TypeNames) {
                $val = $this.Data[$t][$addr]
                $rowValues.Add($val)
            }

            $outLines.Add(($rowValues -join ','))
        }

        [System.IO.File]::WriteAllLines($outputPath, $outLines, $enc)
    }
}
