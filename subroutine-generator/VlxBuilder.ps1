# ==============================================================================
# VlxBuilder - Object-Oriented Ladder Subroutine Generator Engine (*.vlx)
# Compatibility: Unitronics Vision Series PLCs (V120, V130, V350, V570, V1040, V1210, Samba)
# Requirement: 32-bit PowerShell (x86) with Microsoft.Jet.OLEDB.4.0 provider
# ==============================================================================

# VisiLogic Ladder Element Opcodes
class VlxOpcodes {
    # Contacts
    static [int]$CONTACT_NO = 200 # Direct Contact (Normally Open) ---[ ]---
    static [int]$CONTACT_NC = 201 # Inverted Contact (Normally Closed) ---[/]---
    static [int]$CONTACT_P  = 202 # Positive Transition Contact (Rising Edge) ---[P]---
    static [int]$CONTACT_N  = 203 # Negative Transition Contact (Falling Edge) ---[N]---

    # Coils
    static [int]$COIL_DIRECT   = 204 # Direct Coil ---( )---
    static [int]$COIL_INVERTED = 205 # Inverted Coil ---(/)---
    static [int]$COIL_SET      = 206 # Set Coil (Latch) ---(S)---
    static [int]$COIL_RESET    = 207 # Reset Coil (Unlatch) ---(R)---
    static [int]$COIL_TOGGLE   = 212 # Toggle Coil ---(T)---

    # Compare Blocks
    static [int]$CMP_LT = 300 # Less Than (<)
    static [int]$CMP_GT = 301 # Greater Than (>)
    static [int]$CMP_EQ = 302 # Equal (==)
    static [int]$CMP_LE = 303 # Less Than or Equal (<=)
    static [int]$CMP_GE = 304 # Greater Than or Equal (>=)
    static [int]$CMP_NE = 305 # Not Equal (<>)

    # Math Blocks
    static [int]$MATH_SUB = 400 # Subtraction (A - B = C)
    static [int]$MATH_DIV = 401 # Integer Division (A / B = C)
    static [int]$MATH_ADD = 405 # Addition (A + B = C)
    static [int]$MATH_MUL = 406 # Multiplication (A * B = C)
    static [int]$MATH_MOD = 407 # Modulo Remainder (A % B = C)

    # Data & Flow Control Functions
    static [int]$CALL_SUB    = 601  # Call Subroutine
    static [int]$RETURN_STEP = 602  # Subroutine Return
    static [int]$STORE       = 900  # Store Direct (Move / Assignment)
    static [int]$LINEARIZE   = 1300 # Linearization (Linear Scaling)
    static [int]$INC         = 1500 # Increment (+1)
    static [int]$DEC         = 1501 # Decrement (-1)

    # Ladder Interconnect Wires
    static [int]$WIRE_HORIZ = 100 # Horizontal Wire Segment
    static [int]$WIRE_VERT  = 101 # Vertical Wire Segment
}

# VisiLogic Operand Type IDs
class VlxOperandTypes {
    static [int]$MB    = 1   # Memory Bit (Boolean 0/1)
    static [int]$SB    = 2   # System Bit
    static [int]$MI    = 3   # Memory Integer (16-bit signed)
    static [int]$SI    = 4   # System Integer (16-bit signed)
    static [int]$ML    = 5   # Memory Long (32-bit signed)
    static [int]$SL    = 6   # System Long (32-bit signed)
    static [int]$MF    = 7   # Memory Float (32-bit IEEE 754 floating-point)
    static [int]$I     = 9   # Physical Digital Input
    static [int]$O     = 10  # Physical Relay / Transistor Output
    static [int]$T     = 11  # Hardware Timer
    static [int]$C     = 12  # Hardware Counter
    static [int]$MDW   = 16  # Memory Double Word (32-bit unsigned)
    static [int]$CONST = 37  # Numeric Constant
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
        # Verify 32-bit process architecture (Microsoft.Jet.OLEDB.4.0 is 32-bit only)
        if ([IntPtr]::Size -ne 4) {
            throw "CRITICAL ERROR: Microsoft.Jet.OLEDB.4.0 operates exclusively in 32-bit (x86) processes. Launch via: C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe"
        }

        $cs = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$($this.TargetPath);Jet OLEDB:Database Password=UniOpenSesame;"
        $this.Conn = New-Object System.Data.OleDb.OleDbConnection($cs)
        $this.Conn.Open()

        # Clear working ladder tables while preserving schema and indexes
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
                # Subroutine call reference
                $desc = "MISSING ($($customDesc))"
                $addrType = 6
            } elseif ($type -eq 11) {
                # Hardware Timer
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

    # Add a ladder rung / network (Strip)
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

    # Add the mandatory final Return rung
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

    # Add a wire segment (horizontal or vertical)
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

    # Add a ladder contact
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

    # Add a ladder coil
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

    # Add a hardware timer coil
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

    # Add a Call Subroutine block
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

    # Add a Store Direct (Move) block
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

    # Add a Compare block
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

    # Add a Math arithmetic block
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

    # Add an Increment (+1) block
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

    # Add a Decrement (-1) block
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

    # Add a Linearize (linear scaling) block
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

        # X Input: In 5
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

        # Y Output: Out 1
        $cmd.CommandText = "INSERT INTO expimp_LdrElmsOprs (ElmntID, Elmnt_Oprnd_Type, Elmnt_Oprnd_Adrs, Elmnt_Oprnd_NetworkId, OprndInIdx, OprndOutIdx) VALUES ($eid, $yType, $yAddr, 0, 0, 1)"
        $cmd.ExecuteNonQuery() | Out-Null
    }

    # Commit all registered operands to expimp_LdrOperands
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

    # Safely close the OLEDB database connection and compact the Jet 4.0 file
    [void]Close() {
        if ($this.Conn -ne $null -and $this.Conn.State -eq [System.Data.ConnectionState]::Open) {
            $this.Conn.Close()
            $this.Conn.Dispose()
        }
        try {
            $tempCompact = "$($this.TargetPath).compact.vlx"
            if (Test-Path $tempCompact) { Remove-Item $tempCompact -Force }
            $jro = New-Object -ComObject JRO.JetEngine
            $jro.CompactDatabase(
                "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$($this.TargetPath);Jet OLEDB:Database Password=UniOpenSesame;",
                "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=$tempCompact;Jet OLEDB:Database Password=UniOpenSesame;Jet OLEDB:Engine Type=5;"
            )
            Move-Item $tempCompact $this.TargetPath -Force
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($jro) | Out-Null
        } catch {
            # If JRO is unavailable, the uncompacted Jet 4.0 file remains valid
        }
    }
}
