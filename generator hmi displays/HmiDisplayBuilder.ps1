<#
.SYNOPSIS
    HmiDisplayBuilder - Profesjonalny silnik generowania ekranów HMI (.vld) dla Unitronics VisiLogic (seria Vision V350).
.DESCRIPTION
    Klasa HmiDisplayBuilder zarządza strukturą bazy Jet 4.0 (HMIBufferColorPages.udb),
    tworzy strony HMI (Pages, Pages_all), notatki stron (DisplayNote), elementy graficzne
    (HMI_Elements) oraz powiązania ze zmiennymi PLC (HMI_Operands), a następnie kompresuje
    całość do pliku archiwum .vld gotowego do bezpośredniego importu w programie VisiLogic.
#>

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

class HmiColor {
    static [int]$DefaultPageBackground = 74
    static [int]$White = 5
    static [int]$Black = 0
    static [int]$Red = 2
    static [int]$Green = 10
    static [int]$Blue = 12
    static [int]$Yellow = 14
    static [int]$Navy = 1
    static [int]$DarkGray = 68
    static [int]$LightGray = 103
    static [int]$ButtonGray = 104
    static [int]$Cyan = 11
    static [int]$Orange = 13
    static [int]$Transparent = -1
}

class HmiElementType {
    static [int]$Rectangle = 1
    static [int]$Line = 2
    static [int]$Image = 3
    static [int]$Label = 4
    static [int]$Variable = 5
    static [int]$Button = 11
}

class HmiVarType {
    static [int]$None = 0
    static [int]$BinaryText = 2
    static [int]$Date = 4
    static [int]$TimeDate = 5
    static [int]$Numeric = 8
    static [int]$TextVariable = 15
    static [int]$Gauge = 21
    static [int]$Trend = 23
    static [int]$Bargraph = 24
    static [int]$Tank = 25
}

class HmiJump {
    [int]$PageNum
    [int]$JumpType
    [int]$JumpOpType = 1       # 1 = MB
    [int]$JumpOpAddress        # MB touch address
    [int]$JumpOpNetID = 0
    [int]$DispOpType = 30      # 30 = Jump to HMI Page
    [int]$DispOpAddress        # Target Display ID
    [int]$DispOpNetID = 0

    HmiJump([int]$pageNum, [int]$jumpType, [int]$touchMb, [int]$targetPageId) {
        $this.PageNum = $pageNum
        $this.JumpType = $jumpType
        $this.JumpOpType = 1
        $this.JumpOpAddress = $touchMb
        $this.JumpOpNetID = 0
        $this.DispOpType = 30
        $this.DispOpAddress = $targetPageId
        $this.DispOpNetID = 0
    }
}

class HmiOperandType {
    static [int]$MB = 1
    static [int]$SB = 2
    static [int]$MI = 3
    static [int]$SI = 4
    static [int]$ML = 5
    static [int]$SL = 6
    static [int]$MF = 7
    static [int]$SF = 8
    static [int]$Input = 9
    static [int]$Output = 10
    static [int]$Timer = 11
    static [int]$Counter = 12
    static [int]$DW = 16
    static [int]$DirectConst = 37
}

class HmiOperandLink {
    [int]$OperandType
    [int]$OperandAddress
    [int]$FieldRole

    HmiOperandLink([int]$type, [int]$addr, [int]$role) {
        $this.OperandType = $type
        $this.OperandAddress = $addr
        $this.FieldRole = $role
    }
}

class HmiElement {
    [int]$ID
    [int]$DisplayID
    [int]$GroupID = -1
    [int]$Type = 4
    [int]$Xs = 0
    [int]$Ys = 0
    [int]$Dx = 100
    [int]$Dy = 30
    [int]$ColorBack = 103
    [int]$ColorFore = 5
    [int]$ColorHatch = 0
    [int]$Flat3D = 3
    [int]$PenStyle = 0
    [int]$PenWidth = 0
    [int]$HatchStyle = 0
    [int]$ImageCRC = 0
    [int]$FontNumber = 282392660
    [int]$DescriptionFontNumber = 0
    [string]$Text = ""
    [int]$Alignment = 4
    [byte[]]$BinaryBlob = $null
    [int]$TouchOprndAddr = -1
    [int]$VarType = 0
    [int]$VarKeyPadEntry = 0
    [int]$VarOprndType = 0
    [int]$VarOprndAddr = -1
    [int]$GlobalVarID = 0
    [int]$DefaultDisplay = 0
    [int]$GUID = 0
    [int]$DownLoadDirtyBit = -1
    [int]$EnabledOpAddr = -1
    [int]$VisibleOpAddr = -1
    [int]$HighlightOpAddr = -1
    [int]$KeypadSuccessOpAddr = -1
    [int]$TabIndex = 255
    [int]$ColorBackTouch = 103
    [int]$ColorForeTouch = 5
    [int]$OrderIndex = 1
    [bool]$StorageText = $false
    [int]$StorageLibNum = 0
    [int]$StrStorageOprndType = 0
    [int]$StrStorageOprndAddr = 0
    [int]$StrStorageFont = 0

    [System.Collections.Generic.List[HmiOperandLink]]$Operands

    HmiElement() {
        $this.Operands = [System.Collections.Generic.List[HmiOperandLink]]::new()
    }
}

class HmiDisplay {
    [int]$ID
    [string]$Name
    [bool]$IsStartUp = $false
    [int]$ColorBack = 74
    [int]$GUID = 0
    [System.Collections.Generic.List[HmiElement]]$Elements
    [System.Collections.Generic.List[HmiJump]]$Jumps

    HmiDisplay([int]$id, [string]$name, [bool]$isStartUp) {
        $this.ID = $id
        $this.Name = $name
        $this.IsStartUp = $isStartUp
        $this.GUID = 10 * $id
        $this.Elements = [System.Collections.Generic.List[HmiElement]]::new()
        $this.Jumps = [System.Collections.Generic.List[HmiJump]]::new()
    }

    [HmiJump] AddJump([int]$touchMb, [int]$targetDisplayId) {
        $jumpType = $this.Jumps.Count + 1
        $jump = [HmiJump]::new($this.ID, $jumpType, $touchMb, $targetDisplayId)
        $this.Jumps.Add($jump)
        return $jump
    }

    [HmiElement] AddNavButton([int]$x, [int]$y, [int]$w, [int]$h, [string]$text, [int]$targetDisplayId, [int]$touchMbAddress, [int]$foreColor, [int]$backColor) {
        $btn = $this.AddButton($x, $y, $w, $h, $text, $touchMbAddress, $foreColor, $backColor)
        # Note: Dla sterowników Vision V350 z dotykowym ekranem tabela HMIJumps w archiwum .vld
        # musi zawierać dokładnie 0 rekordów. Nawigacja dotykowa realizowana jest poprzez TouchOprndAddr (MB).
        # Silnik VB6 UnHmPge2.dll przy eksporcie/imporcie V350 posiada sztywną tablicę JumpArray(1 To 4).
        # Dodanie skoków do HMIJumps wywołuje błąd VB6 'Run-time error 9: Subscript out of range'.
        return $btn
    }

    [HmiElement] AddBinaryText([int]$x, [int]$y, [int]$w, [int]$h, [int]$oprndType, [int]$oprndAddr, [byte[]]$propertyBag, [int]$foreColor, [int]$backColor) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Variable
        $el.VarType = [HmiVarType]::BinaryText
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.Text = "Var " + $oprndAddr
        $el.ColorFore = $foreColor
        $el.ColorBack = $backColor
        $el.ColorForeTouch = $foreColor
        $el.ColorBackTouch = $backColor
        $el.Flat3D = 3
        $el.HatchStyle = 4
        $el.Alignment = 4
        $el.FontNumber = 0
        $el.DescriptionFontNumber = 282392660
        $el.DefaultDisplay = 2
        $el.StrStorageOprndAddr = -1
        $el.StrStorageFont = 89352336
        $el.VarOprndType = $oprndType
        $el.VarOprndAddr = $oprndAddr
        $el.VarKeyPadEntry = 0
        $el.BinaryBlob = $propertyBag
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        
        $el.Operands.Add([HmiOperandLink]::new($oprndType, $oprndAddr, 1))
        $this.Elements.Add($el)
        return $el
    }

    [HmiElement] AddTrendControl([int]$x, [int]$y, [int]$w, [int]$h, [int]$statusMiAddress, [byte[]]$propertyBag) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Variable
        $el.VarType = [HmiVarType]::Trend
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.Text = "Trend Status"
        $el.ColorFore = [HmiColor]::Black
        $el.ColorBack = [HmiColor]::ButtonGray
        $el.ColorForeTouch = [HmiColor]::Black
        $el.ColorBackTouch = [HmiColor]::ButtonGray
        $el.Flat3D = 1
        $el.HatchStyle = 4
        $el.FontNumber = 0
        $el.DescriptionFontNumber = 282392660
        $el.Alignment = 4
        $el.VarOprndType = [HmiOperandType]::MI
        $el.VarOprndAddr = $statusMiAddress
        $el.VarKeyPadEntry = 0
        $el.BinaryBlob = $propertyBag
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        
        $el.Operands.Add([HmiOperandLink]::new([HmiOperandType]::MI, $statusMiAddress, 1))
        $this.Elements.Add($el)
        return $el
    }

    [HmiElement] AddLabel([int]$x, [int]$y, [int]$w, [int]$h, [string]$text, [int]$foreColor, [int]$backColor, [int]$flat3d) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Label
        $el.VarType = [HmiVarType]::None
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.Text = $text
        $el.ColorFore = $foreColor
        $el.ColorBack = $backColor
        $el.ColorForeTouch = $foreColor
        $el.ColorBackTouch = $backColor
        $el.Flat3D = $flat3d
        $el.Alignment = 4
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        $this.Elements.Add($el)
        return $el
    }

    [HmiElement] AddButton([int]$x, [int]$y, [int]$w, [int]$h, [string]$text, [int]$touchMbAddress, [int]$foreColor, [int]$backColor) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Button
        $el.VarType = [HmiVarType]::None
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.Text = $text
        $el.ColorFore = $foreColor
        $el.ColorBack = $backColor
        $el.ColorForeTouch = $foreColor
        $el.ColorBackTouch = $backColor
        $el.Flat3D = 1 # 3D raised button
        $el.Alignment = 4
        $el.TouchOprndAddr = $touchMbAddress
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        
        if ($touchMbAddress -ge 0) {
            $el.Operands.Add([HmiOperandLink]::new([HmiOperandType]::MB, $touchMbAddress, 2))
        }
        $this.Elements.Add($el)
        return $el
    }

    [HmiElement] AddNumericVariable([int]$x, [int]$y, [int]$w, [int]$h, [int]$miAddress, [bool]$isKeypad, [string]$labelText, [byte[]]$propertyBag, [int]$foreColor, [int]$backColor) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Variable
        $el.VarType = [HmiVarType]::Numeric
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.Text = if ([string]::IsNullOrEmpty($labelText)) { "MI $miAddress" } else { $labelText }
        $el.ColorFore = $foreColor
        $el.ColorBack = $backColor
        $el.ColorForeTouch = $foreColor
        $el.ColorBackTouch = $backColor
        $el.Flat3D = 0
        $el.Alignment = 4
        $el.VarOprndType = [HmiOperandType]::MI
        $el.VarOprndAddr = $miAddress
        $el.VarKeyPadEntry = if ($isKeypad) { 1 } else { 0 }
        $el.BinaryBlob = $propertyBag
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        
        $el.Operands.Add([HmiOperandLink]::new([HmiOperandType]::MI, $miAddress, 1))
        $this.Elements.Add($el)
        return $el
    }

    [HmiElement] AddBargraph([int]$x, [int]$y, [int]$w, [int]$h, [int]$miAddress, [string]$name, [byte[]]$propertyBag) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Variable
        $el.VarType = [HmiVarType]::Bargraph
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.Text = $name
        $el.ColorFore = [HmiColor]::Black
        $el.ColorBack = [HmiColor]::LightGray
        $el.ColorForeTouch = [HmiColor]::Black
        $el.ColorBackTouch = [HmiColor]::LightGray
        $el.Flat3D = 3
        $el.HatchStyle = 4
        $el.VarOprndType = [HmiOperandType]::MI
        $el.VarOprndAddr = $miAddress
        $el.BinaryBlob = $propertyBag
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        
        $el.Operands.Add([HmiOperandLink]::new([HmiOperandType]::MI, $miAddress, 1))
        $this.Elements.Add($el)
        return $el
    }

    [HmiElement] AddTank([int]$x, [int]$y, [int]$w, [int]$h, [int]$miAddress, [string]$name, [byte[]]$propertyBag) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Variable
        $el.VarType = [HmiVarType]::Tank
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.Text = $name
        $el.ColorFore = [HmiColor]::Black
        $el.ColorBack = [HmiColor]::LightGray
        $el.ColorForeTouch = [HmiColor]::Black
        $el.ColorBackTouch = [HmiColor]::LightGray
        $el.Flat3D = 3
        $el.HatchStyle = 4
        $el.VarOprndType = [HmiOperandType]::MI
        $el.VarOprndAddr = $miAddress
        $el.BinaryBlob = $propertyBag
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        
        $el.Operands.Add([HmiOperandLink]::new([HmiOperandType]::MI, $miAddress, 1))
        $this.Elements.Add($el)
        return $el
    }

    [HmiElement] AddGauge([int]$x, [int]$y, [int]$w, [int]$h, [int]$miAddress, [string]$name, [byte[]]$propertyBag) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Variable
        $el.VarType = [HmiVarType]::Gauge
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.Text = $name
        $el.ColorFore = [HmiColor]::Black
        $el.ColorBack = [HmiColor]::LightGray
        $el.ColorForeTouch = [HmiColor]::Black
        $el.ColorBackTouch = [HmiColor]::LightGray
        $el.Flat3D = 0
        $el.HatchStyle = 4
        $el.VarOprndType = [HmiOperandType]::MI
        $el.VarOprndAddr = $miAddress
        $el.BinaryBlob = $propertyBag
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        
        $el.Operands.Add([HmiOperandLink]::new([HmiOperandType]::MI, $miAddress, 1))
        $this.Elements.Add($el)
        return $el
    }

    [HmiElement] AddRectangle([int]$x, [int]$y, [int]$w, [int]$h, [int]$borderColor, [int]$fillColor) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Rectangle
        $el.VarType = [HmiVarType]::None
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.ColorFore = $borderColor
        $el.ColorBack = $fillColor
        $el.Flat3D = 0
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        $this.Elements.Add($el)
        return $el
    }

    [HmiElement] AddLine([int]$x, [int]$y, [int]$w, [int]$h, [int]$color) {
        $el = [HmiElement]::new()
        $el.DisplayID = $this.ID
        $el.Type = [HmiElementType]::Line
        $el.VarType = [HmiVarType]::None
        $el.Xs = $x; $el.Ys = $y; $el.Dx = $w; $el.Dy = $h
        $el.ColorFore = $color
        $el.ColorBack = $color
        $el.Flat3D = 0
        $el.OrderIndex = $this.Elements.Count + 1
        $el.GUID = 100 * $this.ID + $el.OrderIndex
        $this.Elements.Add($el)
        return $el
    }
}

class HmiDisplayBuilder {
    [System.Collections.Generic.List[HmiDisplay]]$Displays
    [string]$TemplatePath
    [string]$TemplatesDir
    [byte[]]$NumericPropertyBag
    [byte[]]$BargraphPropertyBag
    [byte[]]$TankPropertyBag
    [byte[]]$GaugePropertyBag
    [byte[]]$TrendPropertyBag
    [byte[]]$BinaryTextPropertyBag

    static [byte[]] CreateBinaryTextPropertyBag([string]$txt0, [int]$colorFore0, [int]$colorBack0, [string]$txt1, [int]$colorFore1, [int]$colorBack1) {
        return [HmiDisplayBuilder]::CreateBinaryTextPropertyBag($txt0, $colorFore0, $colorBack0, $txt1, $colorFore1, $colorBack1, 282392660)
    }

    static [byte[]] CreateBinaryTextPropertyBag([string]$txt0, [int]$colorFore0, [int]$colorBack0, [string]$txt1, [int]$colorFore1, [int]$colorBack1, [int]$fontNum) {
        $props = @(
            @{ Name="drawingtext_txt";        VT=8; Hash=0x73AD6DA4; ValStr=$txt1 },
            @{ Name="drawingtext_fontnumber"; VT=3; Hash=0x7E9CEA42; ValInt=$fontNum },
            @{ Name="drawingtext_colorfore";  VT=3; Hash=0x58417851; ValInt=$colorFore1 },
            @{ Name="drawingtext_colorback";  VT=3; Hash=0x60435A5F; ValInt=$colorBack1 },
            @{ Name="listcount";              VT=3; Hash=0x9A215B1E; ValInt=2 },
            @{ Name="txt_1";                  VT=8; Hash=0xD74BDC30; ValStr=$txt0 },
            @{ Name="colorfore_1";            VT=3; Hash=0xE7073473; ValInt=$colorFore0 },
            @{ Name="colorback_1";            VT=3; Hash=0xDFE73CFB; ValInt=$colorBack0 },
            @{ Name="storagestringid_1";      VT=3; Hash=0x0381865D; ValInt=-1 },
            @{ Name="storagestringtype_1";    VT=3; Hash=0x25D5F193; ValInt=0 },
            @{ Name="txt_2";                  VT=8; Hash=0xD74BDC33; ValStr=$txt1 },
            @{ Name="colorfore_2";            VT=3; Hash=0xE7073470; ValInt=$colorFore1 },
            @{ Name="colorback_2";            VT=3; Hash=0xDFE73CF8; ValInt=$colorBack1 },
            @{ Name="storagestringid_2";      VT=3; Hash=0x0381865E; ValInt=-1 },
            @{ Name="storagestringtype_2";    VT=3; Hash=0x25D5F190; ValInt=0 },
            @{ Name="switch";                 VT=3; Hash=0xD77C540F; ValInt=0 },
            @{ Name="storagetext";            VT=3; Hash=0x0CC71474; ValInt=0 },
            @{ Name="storagelibnum";          VT=3; Hash=0xB8FDB10C; ValInt=0 }
        )

        $ms = New-Object System.IO.MemoryStream
        $bw = New-Object System.IO.BinaryWriter($ms)

        $bw.Write([byte]0x93)
        $bw.Write([byte]0xB2)
        $bw.Write([uint16]0x0000)
        $bw.Write([uint32]0)

        for ($i = 0; $i -lt $props.Count; $i++) {
            $p = $props[$i]
            $isLast = ($i -eq ($props.Count - 1))
            $recStartPos = $ms.Position

            $name = $p.Name
            $nameBytes = [System.Text.Encoding]::Unicode.GetBytes($name)
            $nameCharLen = [uint16]($name.Length)

            $bw.Write([uint16]$p.VT)
            $bw.Write([uint16]$nameCharLen)
            $bw.Write([int32]$p.Hash)

            $recLenPos = $ms.Position
            $bw.Write([uint32]0)

            $bw.Write($nameBytes)

            if ($p.VT -eq 3) {
                $bw.Write([int32]$p.ValInt)
            } elseif ($p.VT -eq 8) {
                $valStr = [string]$p.ValStr
                $valBytes = [System.Text.Encoding]::Unicode.GetBytes($valStr)
                $valCharLen = [int32]($valStr.Length)
                $bw.Write([int32]$valCharLen)
                $bw.Write($valBytes)
            }

            $rawLen = $ms.Position - $recStartPos
            $paddedLen = [int]([Math]::Ceiling($rawLen / 4.0) * 4)
            $padCount = $paddedLen - $rawLen
            for ($k = 0; $k -lt $padCount; $k++) {
                $bw.Write([byte]0)
            }

            $endPos = $ms.Position
            $ms.Position = $recLenPos
            if ($isLast) {
                $sentinel = [int32](4 - $recStartPos)
                $bw.Write([int32]$sentinel)
            } else {
                $bw.Write([uint32]$paddedLen)
            }
            $ms.Position = $endPos
        }

        $totalRaw = $ms.Position
        $totalPadded = [int]([Math]::Ceiling($totalRaw / 4.0) * 4)
        for ($k = 0; $k -lt ($totalPadded - $totalRaw); $k++) {
            $bw.Write([byte]0)
        }

        $finalTotal = [uint32]$ms.Position
        $ms.Position = 4
        $bw.Write($finalTotal)
        $ms.Position = $finalTotal

        $bytes = $ms.ToArray()
        $bw.Close()
        return $bytes
    }

    HmiDisplayBuilder() {
        $this.Init("")
    }

    HmiDisplayBuilder([string]$templatesDir) {
        $this.Init($templatesDir)
    }

    [void] Init([string]$templatesDir) {
        $this.Displays = [System.Collections.Generic.List[HmiDisplay]]::new()
        
        if (-not [string]::IsNullOrEmpty($templatesDir)) {
            $this.TemplatesDir = $templatesDir
        } else {
            $candidateDirs = @(
                (Join-Path $PSScriptRoot "templates"),
                "C:\Users\Panasonic\Documents\Agentsroom\Projekt PLC Unitronics V350 Komora 9\narzedzia\generator hmi displays\templates",
                ".\templates"
            )
            foreach ($cd in $candidateDirs) {
                if (-not [string]::IsNullOrEmpty($cd) -and (Test-Path $cd)) {
                    $this.TemplatesDir = (Resolve-Path $cd).Path
                    break
                }
            }
        }
        
        $this.TemplatePath = Join-Path $this.TemplatesDir "template_hmi_buffer.udb"

        # Load binary blobs if available
        $numPath = Join-Path $this.TemplatesDir "numeric_propertybag.bin"
        if (Test-Path $numPath) {
            $this.NumericPropertyBag = [System.IO.File]::ReadAllBytes($numPath)
        }
        $barPath = Join-Path $this.TemplatesDir "bargraph_propertybag.bin"
        if (Test-Path $barPath) {
            $this.BargraphPropertyBag = [System.IO.File]::ReadAllBytes($barPath)
        }
        $tankPath = Join-Path $this.TemplatesDir "tank_propertybag.bin"
        if (Test-Path $tankPath) {
            $this.TankPropertyBag = [System.IO.File]::ReadAllBytes($tankPath)
        }
        $gaugePath = Join-Path $this.TemplatesDir "gauge_propertybag.bin"
        if (Test-Path $gaugePath) {
            $this.GaugePropertyBag = [System.IO.File]::ReadAllBytes($gaugePath)
        }
        $trendPath = Join-Path $this.TemplatesDir "trend_propertybag.bin"
        if (Test-Path $trendPath) {
            $this.TrendPropertyBag = [System.IO.File]::ReadAllBytes($trendPath)
        }
        $btPath = Join-Path $this.TemplatesDir "binarytext_propertybag.bin"
        if (Test-Path $btPath) {
            $this.BinaryTextPropertyBag = [System.IO.File]::ReadAllBytes($btPath)
        }
    }

    [HmiDisplay] AddDisplay([string]$name, [bool]$isStartUp) {
        $id = $this.Displays.Count + 1
        $disp = [HmiDisplay]::new($id, $name, $isStartUp)
        $this.Displays.Add($disp)
        return $disp
    }

    [void] SaveVld([string]$outputPath) {
        if (-not (Test-Path $this.TemplatePath)) {
            throw "Nie znaleziono pliku szablonu bazy: $($this.TemplatePath)"
        }

        # Create temporary working directory
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vld_build_" + [System.Guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        $tempUdb = Join-Path $tempDir "HMIBufferColorPages.udb"

        try {
            Copy-Item $this.TemplatePath $tempUdb -Force

            $connStr = "Provider=Microsoft.ACE.OLEDB.12.0;Data Source=$tempUdb;"
            $conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
            try {
                $conn.Open()
            } catch {
                # Fallback to Jet 4.0 if ACE is not registered
                $connStr = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$tempUdb;"
                $conn = New-Object System.Data.OleDb.OleDbConnection($connStr)
                $conn.Open()
            }

            # Prepare commands for Pages and Pages_all
            $cmdPage = $conn.CreateCommand()
            $cmdPage.CommandText = @"
INSERT INTO [Pages] (
    [Id], [Description], [ConstrID], [FuncID], [DestrID], [ModuleID], [Lock], [ColorBack],
    [PaletteID], [GUID], [DownLoadDirtyBit], [ColorDisabledGradient], [ColorDisabledText],
    [ColorFocusGradient], [ColorFocusText], [ColorMarkingGradient], [ColorMarkingText],
    [IsDisplayedOpType], [IsDisplayedOpAddress]
) VALUES (?, ?, 0, 0, 0, ?, 0, ?, 1, ?, -1, 102, 68, 98, 6, 98, 6, 0, 0)
"@
            $cmdPage.Parameters.Add("Id", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdPage.Parameters.Add("Description", [System.Data.OleDb.OleDbType]::VarWChar) | Out-Null
            $cmdPage.Parameters.Add("ModuleID", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdPage.Parameters.Add("ColorBack", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdPage.Parameters.Add("GUID", [System.Data.OleDb.OleDbType]::Integer) | Out-Null

            $cmdPageAll = $conn.CreateCommand()
            $cmdPageAll.CommandText = $cmdPage.CommandText.Replace("[Pages]", "[Pages_all]")
            $cmdPageAll.Parameters.Add("Id", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdPageAll.Parameters.Add("Description", [System.Data.OleDb.OleDbType]::VarWChar) | Out-Null
            $cmdPageAll.Parameters.Add("ModuleID", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdPageAll.Parameters.Add("ColorBack", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdPageAll.Parameters.Add("GUID", [System.Data.OleDb.OleDbType]::Integer) | Out-Null

            # DisplayNote Command
            $emptyNote = New-Object byte[] 510
            $cmdNote = $conn.CreateCommand()
            $cmdNote.CommandText = "INSERT INTO [DisplayNote] ([PageID], [NoteTxt]) VALUES (?, ?)"
            $cmdNote.Parameters.Add("PageID", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdNote.Parameters.Add("NoteTxt", [System.Data.OleDb.OleDbType]::Binary).Value = $emptyNote

            # HMI_Elements Command
            $cmdElem = $conn.CreateCommand()
            $cmdElem.CommandText = @"
INSERT INTO [HMI_Elements] (
    [ID], [DisplayID], [GroupID], [Type], [Xs], [Ys], [Dx], [Dy],
    [ColorBack], [ColorFore], [ColorHatch], [Flat3D], [PenStyle], [PenWidth], [HatchStyle],
    [ImageCRC], [FontNumber], [DescriptionFontNumber], [Text], [Alignment], [Binary],
    [TouchOprndAddr], [VarType], [VarKeyPadEntry], [VarOprndType], [VarOprndAddr],
    [GlobalVarID], [DefaultDisplay], [GUID], [DownLoadDirtyBit], [EnabledOpAddr],
    [VisibleOpAddr], [HighlightOpAddr], [KeypadSuccessOpAddr], [TabIndex],
    [ColorBackTouch], [ColorForeTouch], [OrderIndex], [StorageText], [StorageLibNum],
    [StrStorageOprndType], [StrStorageOprndAddr], [StrStorageFont]
) VALUES (
    ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?,
    ?, ?, ?, ?,
    ?, ?, ?, ?, ?,
    ?, ?, ?
)
"@
            $paramNames = @(
                "ID", "DisplayID", "GroupID", "Type", "Xs", "Ys", "Dx", "Dy",
                "ColorBack", "ColorFore", "ColorHatch", "Flat3D", "PenStyle", "PenWidth", "HatchStyle",
                "ImageCRC", "FontNumber", "DescriptionFontNumber", "Text", "Alignment", "Binary",
                "TouchOprndAddr", "VarType", "VarKeyPadEntry", "VarOprndType", "VarOprndAddr",
                "GlobalVarID", "DefaultDisplay", "GUID", "DownLoadDirtyBit", "EnabledOpAddr",
                "VisibleOpAddr", "HighlightOpAddr", "KeypadSuccessOpAddr", "TabIndex",
                "ColorBackTouch", "ColorForeTouch", "OrderIndex", "StorageText", "StorageLibNum",
                "StrStorageOprndType", "StrStorageOprndAddr", "StrStorageFont"
            )
            foreach ($pn in $paramNames) {
                if ($pn -eq "Text") {
                    $cmdElem.Parameters.Add($pn, [System.Data.OleDb.OleDbType]::VarWChar) | Out-Null
                } elseif ($pn -eq "Binary") {
                    $cmdElem.Parameters.Add($pn, [System.Data.OleDb.OleDbType]::Binary) | Out-Null
                } elseif ($pn -eq "StorageText") {
                    $cmdElem.Parameters.Add($pn, [System.Data.OleDb.OleDbType]::Boolean) | Out-Null
                } else {
                    $cmdElem.Parameters.Add($pn, [System.Data.OleDb.OleDbType]::Integer) | Out-Null
                }
            }

            # HMI_Operands Command
            $cmdOp = $conn.CreateCommand()
            $cmdOp.CommandText = "INSERT INTO [HMI_Operands] ([ElementID], [OprndType], [OprndAddr], [OprndNetID], [OprndPurpose]) VALUES (?, ?, ?, 0, ?)"
            $cmdOp.Parameters.Add("ElementID", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdOp.Parameters.Add("OprndType", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdOp.Parameters.Add("OprndAddr", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdOp.Parameters.Add("OprndPurpose", [System.Data.OleDb.OleDbType]::Integer) | Out-Null

            # HMIJumps Command
            $cmdJump = $conn.CreateCommand()
            $cmdJump.CommandText = @"
INSERT INTO [HMIJumps] (
    [PageNum], [JumpType], [JumpOpType], [JumpOpAddress], [JumpOpNetID],
    [DispOpType], [DispOpAddress], [DispOpNetID]
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
"@
            $cmdJump.Parameters.Add("PageNum", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdJump.Parameters.Add("JumpType", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdJump.Parameters.Add("JumpOpType", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdJump.Parameters.Add("JumpOpAddress", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdJump.Parameters.Add("JumpOpNetID", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdJump.Parameters.Add("DispOpType", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdJump.Parameters.Add("DispOpAddress", [System.Data.OleDb.OleDbType]::Integer) | Out-Null
            $cmdJump.Parameters.Add("DispOpNetID", [System.Data.OleDb.OleDbType]::Integer) | Out-Null

            $globalElemId = 1

            foreach ($disp in $this.Displays) {
                # Insert Page
                $modId = if ($disp.IsStartUp) { 1 } else { 2 }
                $cmdPage.Parameters["Id"].Value = $disp.ID
                $cmdPage.Parameters["Description"].Value = $disp.Name
                $cmdPage.Parameters["ModuleID"].Value = $modId
                $cmdPage.Parameters["ColorBack"].Value = $disp.ColorBack
                $cmdPage.Parameters["GUID"].Value = $disp.GUID
                $cmdPage.ExecuteNonQuery() | Out-Null

                $cmdPageAll.Parameters["Id"].Value = $disp.ID
                $cmdPageAll.Parameters["Description"].Value = $disp.Name
                $cmdPageAll.Parameters["ModuleID"].Value = $modId
                $cmdPageAll.Parameters["ColorBack"].Value = $disp.ColorBack
                $cmdPageAll.Parameters["GUID"].Value = $disp.GUID
                $cmdPageAll.ExecuteNonQuery() | Out-Null

                # Insert DisplayNote
                $cmdNote.Parameters["PageID"].Value = $disp.ID
                $cmdNote.ExecuteNonQuery() | Out-Null

                # Insert Elements
                foreach ($el in $disp.Elements) {
                    $el.ID = $globalElemId
                    $globalElemId++

                    $cmdElem.Parameters["ID"].Value = $el.ID
                    $cmdElem.Parameters["DisplayID"].Value = $disp.ID
                    $cmdElem.Parameters["GroupID"].Value = $el.GroupID
                    $cmdElem.Parameters["Type"].Value = $el.Type
                    $cmdElem.Parameters["Xs"].Value = $el.Xs
                    $cmdElem.Parameters["Ys"].Value = $el.Ys
                    $cmdElem.Parameters["Dx"].Value = $el.Dx
                    $cmdElem.Parameters["Dy"].Value = $el.Dy
                    $cmdElem.Parameters["ColorBack"].Value = $el.ColorBack
                    $cmdElem.Parameters["ColorFore"].Value = $el.ColorFore
                    $cmdElem.Parameters["ColorHatch"].Value = $el.ColorHatch
                    $cmdElem.Parameters["Flat3D"].Value = $el.Flat3D
                    $cmdElem.Parameters["PenStyle"].Value = $el.PenStyle
                    $cmdElem.Parameters["PenWidth"].Value = $el.PenWidth
                    $cmdElem.Parameters["HatchStyle"].Value = $el.HatchStyle
                    $cmdElem.Parameters["ImageCRC"].Value = $el.ImageCRC
                    $cmdElem.Parameters["FontNumber"].Value = $el.FontNumber
                    $cmdElem.Parameters["DescriptionFontNumber"].Value = $el.DescriptionFontNumber
                    $cmdElem.Parameters["Text"].Value = $el.Text
                    $cmdElem.Parameters["Alignment"].Value = $el.Alignment

                    if ($el.BinaryBlob -ne $null) {
                        $cmdElem.Parameters["Binary"].Value = $el.BinaryBlob
                    } else {
                        $cmdElem.Parameters["Binary"].Value = [System.DBNull]::Value
                    }

                    $cmdElem.Parameters["TouchOprndAddr"].Value = $el.TouchOprndAddr
                    $cmdElem.Parameters["VarType"].Value = $el.VarType
                    $cmdElem.Parameters["VarKeyPadEntry"].Value = $el.VarKeyPadEntry
                    $cmdElem.Parameters["VarOprndType"].Value = $el.VarOprndType
                    $cmdElem.Parameters["VarOprndAddr"].Value = $el.VarOprndAddr
                    $cmdElem.Parameters["GlobalVarID"].Value = $el.GlobalVarID
                    $cmdElem.Parameters["DefaultDisplay"].Value = $el.DefaultDisplay
                    $cmdElem.Parameters["GUID"].Value = $el.GUID
                    $cmdElem.Parameters["DownLoadDirtyBit"].Value = $el.DownLoadDirtyBit
                    $cmdElem.Parameters["EnabledOpAddr"].Value = $el.EnabledOpAddr
                    $cmdElem.Parameters["VisibleOpAddr"].Value = $el.VisibleOpAddr
                    $cmdElem.Parameters["HighlightOpAddr"].Value = $el.HighlightOpAddr
                    $cmdElem.Parameters["KeypadSuccessOpAddr"].Value = $el.KeypadSuccessOpAddr
                    $cmdElem.Parameters["TabIndex"].Value = $el.TabIndex
                    $cmdElem.Parameters["ColorBackTouch"].Value = $el.ColorBackTouch
                    $cmdElem.Parameters["ColorForeTouch"].Value = $el.ColorForeTouch
                    $cmdElem.Parameters["OrderIndex"].Value = $el.OrderIndex
                    $cmdElem.Parameters["StorageText"].Value = $el.StorageText
                    $cmdElem.Parameters["StorageLibNum"].Value = $el.StorageLibNum
                    $cmdElem.Parameters["StrStorageOprndType"].Value = $el.StrStorageOprndType
                    $cmdElem.Parameters["StrStorageOprndAddr"].Value = $el.StrStorageOprndAddr
                    $cmdElem.Parameters["StrStorageFont"].Value = $el.StrStorageFont

                    $cmdElem.ExecuteNonQuery() | Out-Null

                    # Insert Operands
                    foreach ($op in $el.Operands) {
                        $cmdOp.Parameters["ElementID"].Value = $el.ID
                        $cmdOp.Parameters["OprndType"].Value = $op.OperandType
                        $cmdOp.Parameters["OprndAddr"].Value = $op.OperandAddress
                        $cmdOp.Parameters["OprndPurpose"].Value = $op.FieldRole
                        $cmdOp.ExecuteNonQuery() | Out-Null
                    }
                }

                # Insert Jumps
                foreach ($jump in $disp.Jumps) {
                    $cmdJump.Parameters["PageNum"].Value = $jump.PageNum
                    $cmdJump.Parameters["JumpType"].Value = $jump.JumpType
                    $cmdJump.Parameters["JumpOpType"].Value = $jump.JumpOpType
                    $cmdJump.Parameters["JumpOpAddress"].Value = $jump.JumpOpAddress
                    $cmdJump.Parameters["JumpOpNetID"].Value = $jump.JumpOpNetID
                    $cmdJump.Parameters["DispOpType"].Value = $jump.DispOpType
                    $cmdJump.Parameters["DispOpAddress"].Value = $jump.DispOpAddress
                    $cmdJump.Parameters["DispOpNetID"].Value = $jump.DispOpNetID
                    $cmdJump.ExecuteNonQuery() | Out-Null
                }
            }

            $conn.Close()
            $conn.Dispose()

            # Create destination directory if not exists
            $outDir = Split-Path -Parent $outputPath
            if (-not [string]::IsNullOrEmpty($outDir) -and -not (Test-Path $outDir)) {
                New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            }

            if (Test-Path $outputPath) {
                Remove-Item $outputPath -Force
            }

            # Create ZIP archive (.vld)
            $tempZip = Join-Path $tempDir "output.zip"
            Compress-Archive -Path $tempUdb -DestinationPath $tempZip -Force
            Move-Item $tempZip $outputPath -Force

            Write-Host "Pomyslnie wygenerowano plik VLD: $outputPath" -ForegroundColor Green
        } finally {
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
