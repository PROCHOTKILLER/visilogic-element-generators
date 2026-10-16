# ==============================================================================
# VlxBuilder - All-In-One Generator Klas dla Podprogramow VisiLogic (*.vlx)
# Kompatybilnosc: Sterowniki Unitronics Vision (V350, V120, V570, Samba itp.)
# Wymaganie: PowerShell 32-bit (x86) ze sterownikiem Microsoft.Jet.OLEDB.4.0
# ==============================================================================

# Definicje stalych elementow drabinki (Opcodes VisiLogic)
class VlxOpcodes {
    # Styki (Contacts)
    static [int]$CONTACT_NO = 200 # Normalnie Otwarty ---[ ]---
    static [int]$CONTACT_NC = 201 # Normalnie Zamkniety ---[/]---
    static [int]$CONTACT_P  = 202 # Zbocze Dodatnie ---[P]---
    static [int]$CONTACT_N  = 203 # Zbocze Ujemne ---[N]---

    # Cewki (Coils)
    static [int]$COIL_DIRECT   = 204 # Cewka Zwykla ---( )---
    static [int]$COIL_INVERTED = 205 # Cewka Zanegowana ---(/)---
    static [int]$COIL_SET      = 206 # Cewka Set (Zatrzask) ---(S)---
    static [int]$COIL_RESET    = 207 # Cewka Reset ---(R)---
    static [int]$COIL_TOGGLE   = 212 # Cewka Toggle (Przelacznik) ---(T)---

    # Komparatory (Compare Blocks)
    static [int]$CMP_LT = 300 # Mniejszy niz (<)
    static [int]$CMP_GT = 301 # Wiekszy niz (>)
    static [int]$CMP_EQ = 302 # Rowny (==)
    static [int]$CMP_LE = 303 # Mniejszy lub rowny (<=)
    static [int]$CMP_GE = 304 # Wiekszy lub rowny (>=)
    static [int]$CMP_NE = 305 # Rozny od (<>)

    # Dzialania Matematyczne (Math Blocks)
    static [int]$MATH_SUB = 400 # Odejmowanie (A - B = C)
    static [int]$MATH_DIV = 401 # Dzielenie calkowite (A / B = C)
    static [int]$MATH_ADD = 405 # Dodawanie (A + B = C)
    static [int]$MATH_MUL = 406 # Mnozenie (A * B = C)
    static [int]$MATH_MOD = 407 # Reszta z dzielenia Modulo (A % B = C)

    # Funkcje Danych i Sterowania
    static [int]$CALL_SUB    = 601  # Wywolanie podprogramu
    static [int]$RETURN_STEP = 602  # Zakonczenie podprogramu (Return)
    static [int]$STORE       = 900  # Przepisanie wartosci (Move / Store)
    static [int]$LINEARIZE   = 1300 # Skalowanie liniowe
    static [int]$INC         = 1500 # Inkrementacja (+1)
    static [int]$DEC         = 1501 # Dekrementacja (-1)

    # Przewody (Wires)
    static [int]$WIRE_HORIZ = 100 # Przewod poziomy
    static [int]$WIRE_VERT  = 101 # Przewod pionowy
}

# Typy Operandow VisiLogic (TypeID)
class VlxOperandTypes {
    static [int]$MB    = 1   # Memory Bit (0/1)
    static [int]$SB    = 2   # System Bit
    static [int]$MI    = 3   # Memory Integer (16-bit ze znakiem)
    static [int]$SI    = 4   # System Integer (16-bit)
    static [int]$ML    = 5   # Memory Long (32-bit ze znakiem)
    static [int]$SL    = 6   # System Long (32-bit)
    static [int]$MF    = 7   # Memory Float (32-bit zmiennoprzecinkowy)
    static [int]$O     = 10  # Fizyczne Wyjscie Przekaznikowe / Tranzystorowe
    static [int]$I     = 9   # Fizyczne Wejscie Cyfrowe
    static [int]$T     = 11  # Timer sprzetowy
    static [int]$C     = 12  # Licznik sprzetowy (Counter)
    static [int]$MDW   = 16  # Memory Double Word (32-bit bez znaku)
    static [int]$CONST = 37  # Stala numeryczna
}

class VlxBuilder {
    [string]$TargetPath
    [string]$SubName
    [System.Data.OleDb.OleDbConnection]$Conn
    [int]$FuncID = 4
    [int]$NextStripId = 1
    [int]$NextElmntId = 1
    [int]$CurrentSeqNum = 1
    [System.Collections.Generic.Dictionary[string, object]]$Operands
    [System.Collections.Generic.Dictionary[string, int]]$ConstMap
    [int]$NextConstIdx = 0
    [hashtable]$Dict
    [hashtable]$TmrPresets

    VlxBuilder([string]$targetPath, [string]$subName) {
        $this.Init($targetPath, $subName, @{}, @{})
    }

    VlxBuilder([string]$targetPath, [string]$subName, [hashtable]$dict, [hashtable]$tmrPresets) {
        $this.Init($targetPath, $subName, $dict, $tmrPresets)
    }

    [void]Init([string]$targetPath, [string]$subName, [hashtable]$dict, [hashtable]$tmrPresets) {
        $this.TargetPath = $targetPath
        $this.SubName = $subName
        $this.Dict = if ($dict -ne $null) { $dict } else { @{} }
        $this.TmrPresets = if ($tmrPresets -ne $null) { $tmrPresets } else { @{} }
        $this.Operands = New-Object 'System.Collections.Generic.Dictionary[string, object]'
        $this.ConstMap = New-Object 'System.Collections.Generic.Dictionary[string, int]'
    }

    [void]Open() {
        # Weryfikacja architektury procesu (Jet OLEDB wymaga 32-bit)
        if ([IntPtr]::Size -ne 4) {
            throw "BLAD KRYTYCZNY: Microsoft.Jet.OLEDB.4.0 dziala WYRACZNIE w architekturze 32-bit (x86). Uruchom skrypt przez: C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
        }

        $cs = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$($this.TargetPath);Jet OLEDB:Database Password=UniOpenSesame;"
        $this.Conn = New-Object System.Data.OleDb.OleDbConnection($cs)
        $this.Conn.Open()

        # Czyszczenie roboczych tabel szczebli i elementow z zachowaniem struktury
        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "DELETE FROM expimp_LdrElmsOprs"
        $cmd.ExecuteNonQuery() | Out-Null
        $cmd.CommandText = "DELETE FROM expimp_LdrElements"
        $cmd.ExecuteNonQuery() | Out-Null
        $cmd.CommandText = "DELETE FROM expimp_LdrStrips"
        $cmd.ExecuteNonQuery() | Out-Null
        $cmd.CommandText = "DELETE FROM expimp_LdrOperands"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "SELECT FuncID FROM expimp_LdrFunctions"
        $this.FuncID = [int]$cmd.ExecuteScalar()

        $cmd.CommandText = "UPDATE expimp_LdrFunctions SET FuncName = '$($this.SubName)', VscrlPos = 0"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    [int]GetConstIndex([string]$val) {
        if ($this.ConstMap.ContainsKey($val)) {
            return $this.ConstMap[$val]
        }
        $idx = $this.NextConstIdx
        $this.NextConstIdx++
        $this.ConstMap[$val] = $idx
        $key = "37_$idx"
        $decVal = [decimal]0
        [decimal]::TryParse($val, [ref]$decVal) | Out-Null
        $this.Operands[$key] = [PSCustomObject]@{
            OprndType = 37
            OprndAddress = $idx
            AddressingType = 2
            OprndDescription = ""
            OprndPowerUp = $decVal
            TimerType = 0
            ResetTimerOnPowerUp = 0
        }
        return $idx
    }

    [void]RegisterOperand([int]$type, [int]$addr) {
        $this.RegisterOperand($type, $addr, "")
    }

    [void]RegisterOperand([int]$type, [int]$addr, [string]$customDesc) {
        $key = "$type`_$addr"
        if (-not $this.Operands.ContainsKey($key)) {
            $desc = ""
            $pwrUp = [decimal]0
            if ($type -eq 31) {
                # Subroutine call
                $desc = "MISSING ($($customDesc))"
                $addrType = 6
            } elseif ($type -eq 11) {
                # Timer sprzetowy
                if ($this.Dict.ContainsKey($key)) { $desc = $this.Dict[$key] }
                elseif (-not [string]::IsNullOrEmpty($customDesc)) { $desc = $customDesc }
                if ($this.TmrPresets.ContainsKey($addr)) { $pwrUp = $this.TmrPresets[$addr] }
                $addrType = 1
            } else {
                if ($this.Dict.ContainsKey($key)) { $desc = $this.Dict[$key] }
                elseif (-not [string]::IsNullOrEmpty($customDesc)) { $desc = $customDesc }
                $addrType = 1
            }
            $this.Operands[$key] = [PSCustomObject]@{
                OprndType = $type
                OprndAddress = $addr
                AddressingType = $addrType
                OprndDescription = $desc
                OprndPowerUp = $pwrUp
                TimerType = 0
                ResetTimerOnPowerUp = 0
            }
        }
    }

    # Dodanie szczebla (Strip / Network)
    [int]AddStrip([string]$comment) {
        return $this.AddStrip($comment, 14)
    }

    [int]AddStrip([string]$comment, [int]$height) {
        $sid = $this.NextStripId
        $this.NextStripId++
        $seq = $this.CurrentSeqNum
        $this.CurrentSeqNum++

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrStrips (StripID, FuncID, SeqNum, StrpType, ShowNum, Height, IsLoaded, IsSelected, IsCompilable, IsReturnStrip, CompileDirtyBit, ShowPowerFlow, LblName, LbComment, StrpNote, Comment, TokensInfo, StlViewInfo, ProblemsInfo, ProblemsType, JunctionsInfo, JumpsInfo, RiseFallInfo, TokensAmount, LdrBitsCount, IsCollapsed, OrgHeight, ColorStrip) VALUES ($sid, $($this.FuncID), $seq, 1, $seq, $height, 0, 0, -1, 0, -1, 0, '', '', '', '$comment', 0x00, 0x00000000, 0x00000000, 0, 0x0000, 0x00000000, 0x00000000, 0, 0, 0, 0, 0)"
        $cmd.ExecuteNonQuery() | Out-Null
        return $sid
    }

    # Dodanie obowiazkowego koncowego szczebla Return
    [void]AddReturnStrip() {
        $sid = $this.NextStripId
        $this.NextStripId++
        $seq = $this.CurrentSeqNum
        $this.CurrentSeqNum++

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrStrips (StripID, FuncID, SeqNum, StrpType, ShowNum, Height, IsLoaded, IsSelected, IsCompilable, IsReturnStrip, CompileDirtyBit, ShowPowerFlow, LblName, LbComment, StrpNote, Comment, TokensInfo, StlViewInfo, ProblemsInfo, ProblemsType, JunctionsInfo, JumpsInfo, RiseFallInfo, TokensAmount, LdrBitsCount, IsCollapsed, OrgHeight, ColorStrip) VALUES ($sid, $($this.FuncID), $seq, 1, $seq, 14, 0, 0, -1, -1, -1, 0, '', '', '', '', 0x0000000400000008024500020100020701020000, 0x00000002000000010000000000000002010000000000000000000000000000000000000A000000000000002000000000000000000000000100000000, 0x00000000, 0, 0x0000, 0x00000000, 0x00000000, 4, 0, 0, 0, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $eid = $this.NextElmntId
        $this.NextElmntId++
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, 602, 0, 5, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Dodanie przewodu (Wire)
    [void]AddWire([int]$sid, [int]$xs, [int]$ys, [int]$dx, [int]$dy) {
        $this.AddWire($sid, $xs, $ys, $dx, $dy, $false)
    }

    [void]AddWire([int]$sid, [int]$xs, [int]$ys, [int]$dx, [int]$dy, [bool]$isVert) {
        $eid = $this.NextElmntId
        $this.NextElmntId++
        $type = if ($isVert) { 101 } else { 100 }
        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, $type, $xs, $ys, $dx, $dy, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Dodanie styku (Contact)
    [void]AddContact([int]$sid, [int]$xs, [int]$ys, [int]$typeId, [int]$addr) {
        $this.AddContact($sid, $xs, $ys, $typeId, $addr, [VlxOpcodes]::CONTACT_NO)
    }

    [void]AddContact([int]$sid, [int]$xs, [int]$ys, [int]$typeId, [int]$addr, [int]$contactType) {
        $eid = $this.NextElmntId
        $this.NextElmntId++
        $this.RegisterOperand($typeId, $addr)

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, $contactType, $xs, $ys, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $typeId, $addr, 0, 1, 0)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Dodanie cewki (Coil)
    [void]AddCoil([int]$sid, [int]$xs, [int]$ys, [int]$typeId, [int]$addr) {
        $this.AddCoil($sid, $xs, $ys, $typeId, $addr, [VlxOpcodes]::COIL_DIRECT)
    }

    [void]AddCoil([int]$sid, [int]$xs, [int]$ys, [int]$typeId, [int]$addr, [int]$coilType) {
        $eid = $this.NextElmntId
        $this.NextElmntId++
        $this.RegisterOperand($typeId, $addr)

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, $coilType, $xs, $ys, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $typeId, $addr, 0, 0, 1)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Dodanie timera sprzetowego (Timer)
    [void]AddTimer([int]$sid, [int]$xs, [int]$ys, [int]$timerNum) {
        $eid = $this.NextElmntId
        $this.NextElmntId++
        $this.RegisterOperand([VlxOperandTypes]::T, $timerNum)

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, 204, $xs, $ys, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, 11, $timerNum, 0, 0, 1)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Wywolanie innego podprogramu (Call Subroutine)
    [void]AddCallSub([int]$sid, [int]$xs, [int]$ys, [string]$calledSubName) {
        $eid = $this.NextElmntId
        $this.NextElmntId++
        $this.RegisterOperand(31, 32000, $calledSubName)

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, 601, $xs, $ys, 0, 0, 0, 0, 0, '$calledSubName', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, 31, 32000, 0, 0, 1)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Blok zapisu wartosci (Store / Move)
    [void]AddStore([int]$sid, [int]$xs, [int]$ys, [int]$srcType, [int]$srcAddr, [string]$srcConstVal, [int]$dstType, [int]$dstAddr) {
        $eid = $this.NextElmntId
        $this.NextElmntId++

        $finalSrcType = $srcType
        $finalSrcAddr = $srcAddr
        if ($srcType -eq 37) {
            $finalSrcAddr = $this.GetConstIndex($srcConstVal)
        } else {
            $this.RegisterOperand($srcType, $srcAddr)
        }
        $this.RegisterOperand($dstType, $dstAddr)

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, 900, $xs, $ys, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $finalSrcType, $finalSrcAddr, 0, 1, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $dstType, $dstAddr, 0, 0, 1)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Blok komparatora (Compare)
    [void]AddCompare([int]$sid, [int]$xs, [int]$ys, [int]$cmpType, [int]$op1Type, [int]$op1Addr, [string]$op1Const, [int]$op2Type, [int]$op2Addr, [string]$op2Const) {
        $eid = $this.NextElmntId
        $this.NextElmntId++

        $finalOp1Type = $op1Type
        $finalOp1Addr = $op1Addr
        if ($op1Type -eq 37) {
            $finalOp1Addr = $this.GetConstIndex($op1Const)
        } else {
            $this.RegisterOperand($op1Type, $op1Addr)
        }

        $finalOp2Type = $op2Type
        $finalOp2Addr = $op2Addr
        if ($op2Type -eq 37) {
            $finalOp2Addr = $this.GetConstIndex($op2Const)
        } else {
            $this.RegisterOperand($op2Type, $op2Addr)
        }

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, $cmpType, $xs, $ys, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $finalOp1Type, $finalOp1Addr, 0, 1, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $finalOp2Type, $finalOp2Addr, 0, 2, 0)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Blok arytmetyki (Math)
    [void]AddMath([int]$sid, [int]$xs, [int]$ys, [int]$mathType, [int]$op1Type, [int]$op1Addr, [string]$op1Const, [int]$op2Type, [int]$op2Addr, [string]$op2Const, [int]$dstType, [int]$dstAddr) {
        $eid = $this.NextElmntId
        $this.NextElmntId++

        $finalOp1Type = $op1Type
        $finalOp1Addr = $op1Addr
        if ($op1Type -eq 37) {
            $finalOp1Addr = $this.GetConstIndex($op1Const)
        } else {
            $this.RegisterOperand($op1Type, $op1Addr)
        }

        $finalOp2Type = $op2Type
        $finalOp2Addr = $op2Addr
        if ($op2Type -eq 37) {
            $finalOp2Addr = $this.GetConstIndex($op2Const)
        } else {
            $this.RegisterOperand($op2Type, $op2Addr)
        }
        $this.RegisterOperand($dstType, $dstAddr)

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, $mathType, $xs, $ys, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $finalOp1Type, $finalOp1Addr, 0, 1, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $finalOp2Type, $finalOp2Addr, 0, 2, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $dstType, $dstAddr, 0, 0, 1)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Blok inkrementacji (Increment +1)
    [void]AddInc([int]$sid, [int]$xs, [int]$ys, [int]$typeId, [int]$addr) {
        $eid = $this.NextElmntId
        $this.NextElmntId++
        $this.RegisterOperand($typeId, $addr)

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, 1500, $xs, $ys, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $typeId, $addr, 0, 0, 1)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Blok dekrementacji (Decrement -1)
    [void]AddDec([int]$sid, [int]$xs, [int]$ys, [int]$typeId, [int]$addr) {
        $eid = $this.NextElmntId
        $this.NextElmntId++
        $this.RegisterOperand($typeId, $addr)

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, 1501, $xs, $ys, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $typeId, $addr, 0, 0, 1)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Blok skalowania liniowego (Linearize)
    [void]AddLinearize([int]$sid, [int]$xs, [int]$ys, [int]$xType, [int]$xAddr, [string]$x1Val, [string]$y1Val, [string]$x2Val, [string]$y2Val, [int]$yType, [int]$yAddr) {
        $eid = $this.NextElmntId
        $this.NextElmntId++

        $this.RegisterOperand($xType, $xAddr)
        $this.RegisterOperand($yType, $yAddr)
        $x1Idx = $this.GetConstIndex($x1Val)
        $y1Idx = $this.GetConstIndex($y1Val)
        $x2Idx = $this.GetConstIndex($x2Val)
        $y2Idx = $this.GetConstIndex($y2Val)

        $cmd = $this.Conn.CreateCommand()
        $cmd.CommandText = "INSERT INTO expimp_LdrElements (ElmntID, StripID, ElmntType, Xs, Ys, Dx, Dy, LineFlowDirection, NumberOfInputs, NumberOfOutputs, MoreParamsStr, MoreParamsLng, MoreParamsBin, IsMissing) VALUES ($eid, $sid, 1300, $xs, $ys, 0, 0, 0, 0, 0, '', 0, null, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        # X wejscie: In 5
        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $xType, $xAddr, 0, 5, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        # X1: In 1
        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, 37, $x1Idx, 0, 1, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        # Y1: In 2
        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, 37, $y1Idx, 0, 2, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        # X2: In 3
        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, 37, $x2Idx, 0, 3, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        # Y2: In 4
        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, 37, $y2Idx, 0, 4, 0)"
        $cmd.ExecuteNonQuery() | Out-Null

        # Y wyjscie: Out 1
        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $yType, $yAddr, 0, 0, 1)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Zapis wszystkich zarejestrowanych operandow do bazy
    [void]SaveOperands() {
        foreach ($op in $this.Operands.Values) {
            $cmd = $this.Conn.CreateCommand()
            $cmd.CommandText = "INSERT INTO expimp_LdrOperands (OprndType, OprndAddress, NetworkID, AddressingType, OprndDescription, OprndPowerUp, OprndEnablePowerUp, ReferenceCount, FormatView, ResetTimerOnPowerUp, TimerType) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
            $cmd.Parameters.Add("OprndType", [System.Data.OleDb.OleDbType]::Integer).Value = [int]$op.OprndType
            $cmd.Parameters.Add("OprndAddress", [System.Data.OleDb.OleDbType]::Integer).Value = [int]$op.OprndAddress
            $cmd.Parameters.Add("NetworkID", [System.Data.OleDb.OleDbType]::Integer).Value = 0
            $cmd.Parameters.Add("AddressingType", [System.Data.OleDb.OleDbType]::Integer).Value = [int]$op.AddressingType
            $cmd.Parameters.Add("OprndDescription", [System.Data.OleDb.OleDbType]::VarWChar).Value = [string]$op.OprndDescription
            $cmd.Parameters.Add("OprndPowerUp", [System.Data.OleDb.OleDbType]::Decimal).Value = [decimal]$op.OprndPowerUp
            $cmd.Parameters.Add("OprndEnablePowerUp", [System.Data.OleDb.OleDbType]::Integer).Value = 0
            $cmd.Parameters.Add("ReferenceCount", [System.Data.OleDb.OleDbType]::Integer).Value = 0
            $cmd.Parameters.Add("FormatView", [System.Data.OleDb.OleDbType]::Integer).Value = 0
            $cmd.Parameters.Add("ResetTimerOnPowerUp", [System.Data.OleDb.OleDbType]::Integer).Value = [int]$op.ResetTimerOnPowerUp
            $cmd.Parameters.Add("TimerType", [System.Data.OleDb.OleDbType]::Integer).Value = [int]$op.TimerType
            $cmd.ExecuteNonQuery() | Out-Null
        }
    }

    # Bezpieczne zamkniecie polaczenia z baza OLEDB
    [void]Close() {
        if ($this.Conn -ne $null -and $this.Conn.State -eq [System.Data.ConnectionState]::Open) {
            $this.Conn.Close()
        }
    }
}
