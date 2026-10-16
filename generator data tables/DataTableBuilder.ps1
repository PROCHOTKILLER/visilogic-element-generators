<#
.SYNOPSIS
    DataTableBuilder.ps1 - Zorientowany obiektowo silnik do tworzenia i manipulacji
    strukturą tabel baz danych (Data Tables XML) dla oprogramowania Unitronics VisiLogic.
.DESCRIPTION
    Klasa generuje pliki XML zgodne z natywnym schematem <PLC_DB> wykorzystywanym
    przez moduł Data Tables w VisiLogic oraz bibliotekę COM UnPlcDB1.clsDBServices.
#>

enum VisiLogicFieldType {
    Flags = 1        # Memory Bit (MB / Bit) [1 bajt, Min: 0, Max: 1]
    Integer = 2      # Memory Integer (MI / 16-bit signed) [2 bajty, Min: -32768, Max: 32767]
    Long = 3         # Memory Long (ML / 32-bit signed) [4 bajty, Min: -2147483648, Max: 2147483647]
    DWord = 4        # Memory DWord (MDW / 32-bit unsigned) [4 bajty, Min: 0, Max: 4294967295]
    Byte = 5         # Byte (8-bit unsigned) [1 bajt, Min: 0, Max: 255]
    String = 6       # ASCII String (zmienna dlugosc) [N bajtow, Min: -32768, Max: 32767]
}

class DataColumnDefinition {
    [string]$Name
    [int]$FieldType
    [int]$Size
    [int]$ElementsCount = 1
    [int]$Key = 1
    [int]$StringLength = 10
    [bool]$ReadOnly = $false
    [bool]$PartOfProject = $false
    [int]$FormatView = 1
    [long]$MinValue = -32768
    [long]$MaxValue = 32767
    [string]$ElementsDescriptions = ""

    DataColumnDefinition([string]$name, [int]$fieldType, [int]$size, [long]$min, [long]$max, [int]$strLen) {
        $this.Name = $name
        $this.FieldType = $fieldType
        $this.Size = $size
        $this.MinValue = $min
        $this.MaxValue = $max
        $this.StringLength = $strLen
    }

    DataColumnDefinition() {}

    static [DataColumnDefinition] NewInteger([string]$name, [long]$min = -32768, [long]$max = 32767) {
        $col = [DataColumnDefinition]::new($name, [int][VisiLogicFieldType]::Integer, 2, $min, $max, 10)
        return $col
    }

    static [DataColumnDefinition] NewLong([string]$name, [long]$min = -2147483648, [long]$max = 2147483647) {
        $col = [DataColumnDefinition]::new($name, [int][VisiLogicFieldType]::Long, 4, $min, $max, 0)
        return $col
    }

    static [DataColumnDefinition] NewFlags([string]$name) {
        $col = [DataColumnDefinition]::new($name, [int][VisiLogicFieldType]::Flags, 1, 0, 1, 10)
        return $col
    }

    static [DataColumnDefinition] NewDWord([string]$name, [long]$min = 0, [long]$max = 4294967295) {
        $col = [DataColumnDefinition]::new($name, [int][VisiLogicFieldType]::DWord, 4, $min, $max, 10)
        return $col
    }

    static [DataColumnDefinition] NewByte([string]$name, [int]$min = 0, [int]$max = 255) {
        $col = [DataColumnDefinition]::new($name, [int][VisiLogicFieldType]::Byte, 1, $min, $max, 10)
        return $col
    }

    static [DataColumnDefinition] NewString([string]$name, [int]$length = 16) {
        $col = [DataColumnDefinition]::new($name, [int][VisiLogicFieldType]::String, $length, -32768, 32767, $length)
        return $col
    }

    # Adaptery dla zmiennych czasowych i zmiennoprzecinkowych:
    # VisiLogic Data Tables (UnPlcDB1.dll) nie posiada wbudowanych typow kolumn 'Timer' ani 'Float'.
    # Wartosci te w architekturze PLC Vision przechowuje sie w pamieci Long (32-bit ze znakiem) lub DWord (32-bit bez znaku).
    static [DataColumnDefinition] NewTimer([string]$name, [long]$minMs = 0, [long]$maxMs = 2147483647) {
        $col = [DataColumnDefinition]::new($name, [int][VisiLogicFieldType]::Long, 4, $minMs, $maxMs, 0)
        return $col
    }

    static [DataColumnDefinition] NewFloat([string]$name, [long]$min = 0, [long]$max = 4294967295) {
        $col = [DataColumnDefinition]::new($name, [int][VisiLogicFieldType]::DWord, 4, $min, $max, 10)
        return $col
    }

    static [DataColumnDefinition] NewUINT16([string]$name, [long]$min = 0, [long]$max = 65535) {
        $col = [DataColumnDefinition]::new($name, [int][VisiLogicFieldType]::DWord, 4, $min, $max, 10)
        return $col
    }
}

class DataTableDefinition {
    [int]$TableId = 1
    [string]$Description = "DataTable"
    [int]$RowsCount = 20
    [System.Collections.Generic.List[DataColumnDefinition]]$Columns

    DataTableDefinition() {
        $this.Columns = [System.Collections.Generic.List[DataColumnDefinition]]::new()
    }

    DataTableDefinition([int]$tableId, [string]$description, [int]$rowsCount) {
        $this.TableId = $tableId
        $this.Description = $description
        $this.RowsCount = $rowsCount
        $this.Columns = [System.Collections.Generic.List[DataColumnDefinition]]::new()
    }

    [DataColumnDefinition] AddColumn([DataColumnDefinition]$col) {
        $col.Key = $this.Columns.Count + 1
        $this.Columns.Add($col)
        return $col
    }

    [DataColumnDefinition] AddInteger([string]$name, [long]$min = -32768, [long]$max = 32767) {
        $col = [DataColumnDefinition]::NewInteger($name, $min, $max)
        return $this.AddColumn($col)
    }

    [DataColumnDefinition] AddLong([string]$name, [long]$min = -2147483648, [long]$max = 2147483647) {
        $col = [DataColumnDefinition]::NewLong($name, $min, $max)
        return $this.AddColumn($col)
    }

    [DataColumnDefinition] AddFlags([string]$name) {
        $col = [DataColumnDefinition]::NewFlags($name)
        return $this.AddColumn($col)
    }

    [DataColumnDefinition] AddDWord([string]$name, [long]$min = 0, [long]$max = 4294967295) {
        $col = [DataColumnDefinition]::NewDWord($name, $min, $max)
        return $this.AddColumn($col)
    }

    [DataColumnDefinition] AddByte([string]$name, [int]$min = 0, [int]$max = 255) {
        $col = [DataColumnDefinition]::NewByte($name, $min, $max)
        return $this.AddColumn($col)
    }

    [DataColumnDefinition] AddString([string]$name, [int]$length = 16) {
        $col = [DataColumnDefinition]::NewString($name, $length)
        return $this.AddColumn($col)
    }

    [DataColumnDefinition] AddTimer([string]$name, [long]$minMs = 0, [long]$maxMs = 2147483647) {
        $col = [DataColumnDefinition]::NewTimer($name, $minMs, $maxMs)
        return $this.AddColumn($col)
    }

    [DataColumnDefinition] AddFloat([string]$name, [long]$min = 0, [long]$max = 4294967295) {
        $col = [DataColumnDefinition]::NewFloat($name, $min, $max)
        return $this.AddColumn($col)
    }

    [DataColumnDefinition] AddFloatScaled([string]$name, [long]$min = -32768, [long]$max = 32767) {
        $col = [DataColumnDefinition]::NewInteger($name, $min, $max)
        return $this.AddColumn($col)
    }

    [DataColumnDefinition] AddUINT16([string]$name, [long]$min = 0, [long]$max = 65535) {
        $col = [DataColumnDefinition]::NewUINT16($name, $min, $max)
        return $this.AddColumn($col)
    }
}

class DataTableBuilder {
    [System.Collections.Generic.List[DataTableDefinition]]$Tables

    DataTableBuilder() {
        $this.Tables = [System.Collections.Generic.List[DataTableDefinition]]::new()
    }

    [DataTableDefinition] AddTable([DataTableDefinition]$table) {
        $this.Tables.Add($table)
        return $table
    }

    [DataTableDefinition] NewTable([int]$id, [string]$description, [int]$rowsCount) {
        $table = [DataTableDefinition]::new($id, $description, $rowsCount)
        $this.Tables.Add($table)
        return $table
    }

    [System.Xml.XmlDocument] ToXmlDocument() {
        $doc = [System.Xml.XmlDocument]::new()
        $root = $doc.CreateElement("PLC_DB")
        $doc.AppendChild($root) | Out-Null

        foreach ($tbl in $this.Tables) {
            $tableElem = $doc.CreateElement("Table")
            $tableElem.SetAttribute("TABLE_ID", "$($tbl.TableId)")
            $root.AppendChild($tableElem) | Out-Null

            $fc = $doc.CreateElement("FieldsCount")
            $fc.InnerText = "$($tbl.Columns.Count)"
            $tableElem.AppendChild($fc) | Out-Null

            $rc = $doc.CreateElement("RowsCount")
            $rc.InnerText = "$($tbl.RowsCount)"
            $tableElem.AppendChild($rc) | Out-Null

            $desc = $doc.CreateElement("Description")
            $desc.InnerText = $tbl.Description
            $tableElem.AppendChild($desc) | Out-Null

            for ($i = 0; $i -lt $tbl.Columns.Count; $i++) {
                $col = $tbl.Columns[$i]
                $colElem = $doc.CreateElement("Column")
                $colElem.SetAttribute("COL_ID", "Column $i")

                $ft = $doc.CreateElement("FieldType"); $ft.InnerText = "$($col.FieldType)"; $colElem.AppendChild($ft) | Out-Null
                $sz = $doc.CreateElement("Size"); $sz.InnerText = "$($col.Size)"; $colElem.AppendChild($sz) | Out-Null
                $ec = $doc.CreateElement("ElementsCount"); $ec.InnerText = "$($col.ElementsCount)"; $colElem.AppendChild($ec) | Out-Null
                $k = $doc.CreateElement("Key"); $k.InnerText = "$($col.Key)"; $colElem.AppendChild($k) | Out-Null
                $sl = $doc.CreateElement("StringLength"); $sl.InnerText = "$($col.StringLength)"; $colElem.AppendChild($sl) | Out-Null
                $ro = $doc.CreateElement("ReadOnly"); $ro.InnerText = $(if ($col.ReadOnly) { "True" } else { "False" }); $colElem.AppendChild($ro) | Out-Null
                $pop = $doc.CreateElement("PartOfProject"); $pop.InnerText = $(if ($col.PartOfProject) { "True" } else { "False" }); $colElem.AppendChild($pop) | Out-Null

                # VisiLogic wymaga specyficznego uklad FormatView -> Min -> Max -> FormatView
                $fv1 = $doc.CreateElement("FormatView"); $fv1.InnerText = "$($col.FormatView)"; $colElem.AppendChild($fv1) | Out-Null
                $min = $doc.CreateElement("MinValue"); $min.InnerText = "$($col.MinValue)"; $colElem.AppendChild($min) | Out-Null
                $max = $doc.CreateElement("MaxValue"); $max.InnerText = "$($col.MaxValue)"; $colElem.AppendChild($max) | Out-Null
                $fv2 = $doc.CreateElement("FormatView"); $fv2.InnerText = "$($col.FormatView)"; $colElem.AppendChild($fv2) | Out-Null

                $d = $doc.CreateElement("Description"); $d.InnerText = $col.Name; $colElem.AppendChild($d) | Out-Null
                $ed = $doc.CreateElement("ElementsDescriptions"); $ed.InnerText = $col.ElementsDescriptions; $colElem.AppendChild($ed) | Out-Null

                $tableElem.AppendChild($colElem) | Out-Null
            }
        }

        return $doc
    }

    [void] SaveXml([string]$filePath) {
        $parentDir = [System.IO.Path]::GetDirectoryName($filePath)
        if (-not [string]::IsNullOrEmpty($parentDir) -and -not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $doc = $this.ToXmlDocument()
        
        $settings = [System.Xml.XmlWriterSettings]::new()
        $settings.Indent = $true
        $settings.IndentChars = "  "
        $settings.OmitXmlDeclaration = $true
        $settings.Encoding = [System.Text.Encoding]::ASCII

        $writer = [System.Xml.XmlWriter]::Create($filePath, $settings)
        try {
            $doc.Save($writer)
        } finally {
            $writer.Close()
        }
    }

    [void] LoadFromTemplate([string]$templatePath) {
        if (-not (Test-Path $templatePath)) {
            throw "Szablon XML nie istnieje: $templatePath"
        }

        $doc = [System.Xml.XmlDocument]::new()
        $doc.Load($templatePath)

        $this.Tables.Clear()

        $tableNodes = $doc.SelectNodes("//PLC_DB/Table")
        foreach ($tNode in $tableNodes) {
            $tableId = [int]$tNode.GetAttribute("TABLE_ID")
            $desc = $tNode.SelectSingleNode("Description").InnerText
            $rowsCount = [int]$tNode.SelectSingleNode("RowsCount").InnerText

            $tbl = $this.NewTable($tableId, $desc, $rowsCount)

            $colNodes = $tNode.SelectNodes("Column")
            foreach ($cNode in $colNodes) {
                $col = [DataColumnDefinition]::new()
                $col.Name = $cNode.SelectSingleNode("Description").InnerText
                $col.FieldType = [int]$cNode.SelectSingleNode("FieldType").InnerText
                $col.Size = [int]$cNode.SelectSingleNode("Size").InnerText
                $col.ElementsCount = [int]$cNode.SelectSingleNode("ElementsCount").InnerText
                $col.Key = [int]$cNode.SelectSingleNode("Key").InnerText
                $col.StringLength = [int]$cNode.SelectSingleNode("StringLength").InnerText
                $col.ReadOnly = ($cNode.SelectSingleNode("ReadOnly").InnerText -eq "True")
                $col.PartOfProject = ($cNode.SelectSingleNode("PartOfProject").InnerText -eq "True")
                $col.FormatView = [int]$cNode.SelectSingleNode("FormatView").InnerText
                $col.MinValue = [long]$cNode.SelectSingleNode("MinValue").InnerText
                $col.MaxValue = [long]$cNode.SelectSingleNode("MaxValue").InnerText
                $edNode = $cNode.SelectSingleNode("ElementsDescriptions")
                $col.ElementsDescriptions = if ($null -ne $edNode) { $edNode.InnerText } else { "" }

                $tbl.AddColumn($col) | Out-Null
            }
        }
    }
}
