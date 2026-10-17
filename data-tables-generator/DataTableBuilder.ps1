<#
.SYNOPSIS
    DataTableBuilder.ps1 - Object-Oriented XML Data Tables Generator Engine for Unitronics VisiLogic.
.DESCRIPTION
    Provides classes for defining data table schemas, columns, and rows (DataTableColumn, DataTableDef, DataTableBuilder)
    with full support for VisiLogic data types (Integer, Long, Boolean, String, Timer) and automatic generation
    of native CellsData Base64 payloads and DataTables XML files compatible with VisiLogic import/export.
#>

enum VisiDataType {
    Byte    = 1 # Unsigned 8-bit integer (0..255), 1 byte per element
    Integer = 2 # Signed 16-bit integer (-32768..32767), 2 bytes Little-Endian
    UInt16  = 3 # Unsigned 16-bit integer (0..65535), 2 bytes Little-Endian
    Long    = 4 # Signed 32-bit integer (-2147483648..2147483647), 4 bytes Little-Endian
    UInt32  = 5 # Unsigned 32-bit integer (0..4294967295), 4 bytes Little-Endian
    Float   = 6 # 32-bit IEEE 754 floating-point number, 4 bytes Little-Endian
    Boolean = 7 # Boolean flag (0 or 1), 2 bytes Little-Endian (0x0000 or 0x0001)
    String  = 8 # ASCII string padded with spaces (0x20) to column length
    Timer   = 9 # Hardware timer preset in 10ms ticks, 4 bytes Little-Endian
}

class DataTableColumn {
    [string]$Description
    [int]$DataType
    [int]$Size
    [int]$Format

    DataTableColumn([string]$desc, [VisiDataType]$type, [int]$size, [int]$format = 0) {
        if ([string]::IsNullOrWhiteSpace($desc)) {
            throw "Column description cannot be empty."
        }
        $this.Description = $desc.Trim()
        $this.DataType = [int]$type
        $this.Size = [Math]::Max(1, $size)
        $this.Format = $format
    }

    [int] GetByteWidth() {
        switch ($this.DataType) {
            1 { return 1 * $this.Size } # Byte
            2 { return 2 * $this.Size } # Integer (16-bit)
            3 { return 2 * $this.Size } # UInt16
            4 { return 4 * $this.Size } # Long (32-bit)
            5 { return 4 * $this.Size } # UInt32
            6 { return 4 * $this.Size } # Float
            7 { return 2 * $this.Size } # Boolean (stored as 16-bit word in VisiLogic binary image)
            8 { return 1 * $this.Size } # String (1 byte per character)
            9 { return 4 * $this.Size } # Timer (32-bit preset value)
        }
        throw "Unsupported column DataType ID: $($this.DataType)"
    }

    [byte[]] EncodeCellValue([object]$val) {
        $width = $this.GetByteWidth()
        $buf = New-Object byte[] $width

        if ($this.DataType -eq 8) {
            # ASCII string padded with spaces (0x20)
            $str = if ($null -eq $val) { "" } else { [string]$val }
            if ($str.Length -gt $this.Size) {
                $str = $str.Substring(0, $this.Size)
            }
            $str = $str.PadRight($this.Size, ' ')
            $asciiBytes = [System.Text.Encoding]::GetEncoding(1250).GetBytes($str)
            [Array]::Copy($asciiBytes, 0, $buf, 0, [Math]::Min($asciiBytes.Length, $width))
            return $buf
        }

        # Array or scalar handling for numeric/boolean columns
        $values = @()
        if ($val -is [System.Array] -and -not ($val -is [string])) {
            $values = $val
        } elseif ($val -is [string] -and $val.Contains(";")) {
            $values = $val.Split(";")
        } else {
            $values = @($val)
        }

        $elemWidth = [int]($width / $this.Size)
        for ($i = 0; $i -lt $this.Size; $i++) {
            $itemVal = if ($i -lt $values.Count) { $values[$i] } else { 0 }
            $elemBytes = $this.EncodeSingleNumeric($itemVal)
            [Array]::Copy($elemBytes, 0, $buf, $i * $elemWidth, $elemWidth)
        }

        return $buf
    }

    hidden [byte[]] EncodeSingleNumeric([object]$v) {
        if ($null -eq $v -or ([string]$v).Trim() -eq "") {
            $v = 0
        }
        switch ($this.DataType) {
            1 {
                $num = [byte][Math]::Min(255, [Math]::Max(0, [int]$v))
                return @($num)
            }
            2 {
                $num = [int16][Math]::Min(32767, [Math]::Max(-32768, [int]$v))
                return [BitConverter]::GetBytes($num)
            }
            3 {
                $num = [uint16][Math]::Min(65535, [Math]::Max(0, [int]$v))
                return [BitConverter]::GetBytes($num)
            }
            4 {
                $num = [int32][long]$v
                return [BitConverter]::GetBytes($num)
            }
            5 {
                $num = [uint32][Math]::Max(0L, [long]$v)
                return [BitConverter]::GetBytes($num)
            }
            6 {
                $num = [single][double]$v
                return [BitConverter]::GetBytes($num)
            }
            7 {
                $boolInt = 0
                if ($v -is [bool]) {
                    $boolInt = if ($v) { 1 } else { 0 }
                } else {
                    $s = ([string]$v).Trim().ToUpperInvariant()
                    if ($s -in @("1", "TRUE", "YES", "ON", "T")) { $boolInt = 1 }
                }
                return [BitConverter]::GetBytes([int16]$boolInt)
            }
            9 {
                $num = [uint32][Math]::Max(0L, [long]$v)
                return [BitConverter]::GetBytes($num)
            }
        }
        return @(0, 0)
    }
}

class DataTableDef {
    [string]$Name
    [int]$NumOfRows
    [int]$PartOfProject = 0
    [int]$CreateOperands = 0
    [int]$ReadOnly = 0
    [System.Collections.Generic.List[DataTableColumn]]$Columns
    [System.Collections.Generic.List[object[]]]$Rows

    DataTableDef([string]$name, [int]$numOfRows) {
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Data Table name cannot be empty."
        }
        $this.Name = $name.Trim()
        $this.NumOfRows = [Math]::Max(1, $numOfRows)
        $this.Columns = New-Object 'System.Collections.Generic.List[DataTableColumn]'
        $this.Rows = New-Object 'System.Collections.Generic.List[object[]]'
    }

    [DataTableColumn] AddColumn([string]$desc, [VisiDataType]$type, [int]$size, [int]$format = 0) {
        $col = [DataTableColumn]::new($desc, $type, $size, $format)
        $this.Columns.Add($col)
        return $col
    }

    # Convenience helper methods for standard column types
    [DataTableColumn] AddIntColumn([string]$desc) {
        return $this.AddColumn($desc, [VisiDataType]::Integer, 1, 0)
    }

    [DataTableColumn] AddInteger([string]$desc) {
        return $this.AddColumn($desc, [VisiDataType]::Integer, 1, 0)
    }

    [DataTableColumn] AddInteger([string]$desc, [int]$min, [int]$max) {
        return $this.AddColumn($desc, [VisiDataType]::Integer, 1, 0)
    }

    [DataTableColumn] AddLongColumn([string]$desc) {
        return $this.AddColumn($desc, [VisiDataType]::Long, 1, 0)
    }

    [DataTableColumn] AddLong([string]$desc) {
        return $this.AddColumn($desc, [VisiDataType]::Long, 1, 0)
    }

    [DataTableColumn] AddLong([string]$desc, [long]$min, [long]$max) {
        return $this.AddColumn($desc, [VisiDataType]::Long, 1, 0)
    }

    [DataTableColumn] AddByte([string]$desc) {
        return $this.AddColumn($desc, [VisiDataType]::Byte, 1, 0)
    }

    [DataTableColumn] AddByte([string]$desc, [int]$min, [int]$max) {
        return $this.AddColumn($desc, [VisiDataType]::Byte, 1, 0)
    }

    [DataTableColumn] AddBoolColumn([string]$desc) {
        return $this.AddColumn($desc, [VisiDataType]::Boolean, 1, 0)
    }

    [DataTableColumn] AddBoolean([string]$desc) {
        return $this.AddColumn($desc, [VisiDataType]::Boolean, 1, 0)
    }

    [DataTableColumn] AddFlags([string]$desc) {
        return $this.AddColumn($desc, [VisiDataType]::Boolean, 1, 0)
    }

    [DataTableColumn] AddStringColumn([string]$desc, [int]$length) {
        return $this.AddColumn($desc, [VisiDataType]::String, $length, 0)
    }

    [DataTableColumn] AddString([string]$desc, [int]$length) {
        return $this.AddColumn($desc, [VisiDataType]::String, $length, 0)
    }

    [void] AddRow([object[]]$cellValues) {
        if ($this.Rows.Count -ge $this.NumOfRows) {
            throw "Cannot add row $($this.Rows.Count + 1): table '$($this.Name)' is configured for a maximum of $($this.NumOfRows) rows."
        }
        $this.Rows.Add($cellValues)
    }

    [int] GetRowByteSize() {
        $sum = 0
        foreach ($col in $this.Columns) {
            $sum += $col.GetByteWidth()
        }
        return $sum
    }

    [string] BuildCellsDataBase64() {
        # VisiLogic requires CellsData to cover the entire declared table matrix (NumOfRows * RowByteSize)
        $rowSize = $this.GetRowByteSize()
        $totalBytes = $this.NumOfRows * $rowSize
        $ms = New-Object System.IO.MemoryStream($totalBytes)

        for ($r = 0; $r -lt $this.NumOfRows; $r++) {
            $rowVals = if ($r -lt $this.Rows.Count) { $this.Rows[$r] } else { @() }
            for ($c = 0; $c -lt $this.Columns.Count; $c++) {
                $col = $this.Columns[$c]
                $val = if ($c -lt $rowVals.Count) { $rowVals[$c] } else { $null }
                $bytes = $col.EncodeCellValue($val)
                $ms.Write($bytes, 0, $bytes.Length)
            }
        }

        $rawBytes = $ms.ToArray()
        $ms.Dispose()
        return [Convert]::ToBase64String($rawBytes)
    }
}

class DataTableBuilder {
    [string]$TemplatePath
    [System.Collections.Generic.List[DataTableDef]]$Tables

    DataTableBuilder() {
        $this.Tables = New-Object 'System.Collections.Generic.List[DataTableDef]'
    }

    DataTableBuilder([string]$templatePath) {
        if (-not (Test-Path $templatePath)) {
            throw "XML template file does not exist: $templatePath"
        }
        $this.TemplatePath = $templatePath
        $this.Tables = New-Object 'System.Collections.Generic.List[DataTableDef]'
    }

    [DataTableDef] AddTable([string]$name, [int]$numOfRows) {
        $tbl = [DataTableDef]::new($name, $numOfRows)
        $this.Tables.Add($tbl)
        return $tbl
    }

    [DataTableDef] NewTable([string]$name, [int]$numOfRows) {
        return $this.AddTable($name, $numOfRows)
    }

    [DataTableDef] NewTable([int]$id, [string]$name, [int]$numOfRows) {
        return $this.AddTable($name, $numOfRows)
    }

    [void] SaveXml([string]$outputPath) {
        if ($this.Tables.Count -eq 0) {
            throw "No Data Tables have been defined in DataTableBuilder."
        }

        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
        [void]$sb.AppendLine('<DataTables Version="1.0.0">')

        foreach ($tbl in $this.Tables) {
            [void]$sb.AppendLine('  <DataTable>')
            [void]$sb.AppendLine("    <Name>$([System.Security.SecurityElement]::Escape($tbl.Name))</Name>")
            [void]$sb.AppendLine("    <NumOfRows>$($tbl.NumOfRows)</NumOfRows>")
            [void]$sb.AppendLine("    <PartOfProject>$($tbl.PartOfProject)</PartOfProject>")
            [void]$sb.AppendLine("    <CreateOperands>$($tbl.CreateOperands)</CreateOperands>")
            [void]$sb.AppendLine("    <ReadOnly>$($tbl.ReadOnly)</ReadOnly>")
            [void]$sb.AppendLine('    <Columns>')

            foreach ($col in $tbl.Columns) {
                [void]$sb.AppendLine('      <Column>')
                [void]$sb.AppendLine("        <Description>$([System.Security.SecurityElement]::Escape($col.Description))</Description>")
                [void]$sb.AppendLine("        <DataType>$($col.DataType)</DataType>")
                [void]$sb.AppendLine("        <Size>$($col.Size)</Size>")
                [void]$sb.AppendLine("        <Format>$($col.Format)</Format>")
                [void]$sb.AppendLine('      </Column>')
            }

            [void]$sb.AppendLine('    </Columns>')

            # CellsData Base64 block AND explicit Rows XML structure
            $b64 = $tbl.BuildCellsDataBase64()
            [void]$sb.AppendLine("    <CellsData>$b64</CellsData>")
            [void]$sb.AppendLine('    <Rows>')

            for ($r = 0; $r -lt $tbl.NumOfRows; $r++) {
                [void]$sb.AppendLine('      <Row>')
                $rowVals = if ($r -lt $tbl.Rows.Count) { $tbl.Rows[$r] } else { @() }
                for ($c = 0; $c -lt $tbl.Columns.Count; $c++) {
                    $col = $tbl.Columns[$c]
                    $val = if ($c -lt $rowVals.Count) { $rowVals[$c] } else { $null }
                    $cellText = ""
                    if ($col.DataType -eq 8) {
                        $cellText = if ($null -eq $val) { "" } else { [string]$val }
                    } else {
                        $cellText = if ($null -eq $val -or ([string]$val) -eq "") { "0" } else { [string]$val }
                    }
                    [void]$sb.AppendLine("        <Cell>$([System.Security.SecurityElement]::Escape($cellText))</Cell>")
                }
                [void]$sb.AppendLine('      </Row>')
            }

            [void]$sb.AppendLine('    </Rows>')
            [void]$sb.AppendLine('  </DataTable>')
        }

        [void]$sb.AppendLine('</DataTables>')

        $parentDir = Split-Path -Parent $outputPath
        if ($parentDir -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($outputPath, $sb.ToString(), $utf8NoBom)
    }
}
