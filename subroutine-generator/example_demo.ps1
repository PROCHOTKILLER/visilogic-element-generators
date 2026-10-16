<#
.SYNOPSIS
    Przykladowy skrypt demonstracyjny wykorzystujacy VlxBuilder do wygenerowania podprogramu DEMO_EXAMPLE.vlx.
#>

$currentDir = Split-Path -Parent $PSCommandPath
$vlxBuilderPath = Join-Path $currentDir "VlxBuilder.ps1"
. $vlxBuilderPath

$templatePath = Join-Path $currentDir "templates\template.vlx"
$outputFile   = Join-Path $currentDir "DEMO_EXAMPLE.vlx"
$subName      = "DEMO_EXAMPLE"

Write-Host "Tworzenie podprogramu: $subName w $outputFile" -ForegroundColor Cyan
Copy-Item $templatePath $outputFile -Force

$b = [VlxBuilder]::new($outputFile, $subName)
$b.Open()

# -----------------------------------------------------------------------------
# Szczebel 1: Zwykle zalaczenie wyjscia z podtrzymaniem (Start / Stop)
# -----------------------------------------------------------------------------
$s1 = $b.AddStrip("Uklad Start / Stop dla pompy", 18)
# Wiersz 1 (Ys = 4): Przycisk Start (MB 100) lub podtrzymanie (O 10), Przycisk Stop (NC MB 101) -> Cewka O 10
$b.AddContact($s1, 0, 4, [VlxOperandTypes]::MB, 100, [VlxOpcodes]::CONTACT_NO)  # Start
$b.AddContact($s1, 6, 4, [VlxOperandTypes]::MB, 101, [VlxOpcodes]::CONTACT_NC)  # Stop NC
$b.AddWire($s1, 12, 4, 18, 0, $false)                                          # Przewod do cewki (12..30)
$b.AddCoil($s1, 30, 4, [VlxOperandTypes]::O, 10, [VlxOpcodes]::COIL_DIRECT)    # Pompa O 10

# Wiersz 2 (Ys = 11): Podtrzymanie stykiem NO Pompy (O 10)
$b.AddContact($s1, 0, 11, [VlxOperandTypes]::O, 10, [VlxOpcodes]::CONTACT_NO)  # Podtrzymanie O 10
$b.AddWire($s1, 6, 4, 0, 7, $true)                                             # Przewod pionowy zamykajacy galezie

# -----------------------------------------------------------------------------
# Szczebel 2: Arytmetyka i Komparator (Zabezpieczenie przed przegrzaniem)
# -----------------------------------------------------------------------------
$s2 = $b.AddStrip("Obliczenie delty temperatur i zalaczenie chlodzenia", 24)
# Wiersz 1: Math SUB (MI 50 - MI 51 -> MI 52)
$b.AddContact($s2, 0, 4, [VlxOperandTypes]::SB, 2, [VlxOpcodes]::CONTACT_NO)   # Styk rozruchowy SB 2
$b.AddMath($s2, 6, 4, [VlxOpcodes]::MATH_SUB, [VlxOperandTypes]::MI, 50, "", [VlxOperandTypes]::MI, 51, "", [VlxOperandTypes]::MI, 52)

# Wiersz 2: Jesli Delta MI 52 > 10, Ustaw Cewke Alarmu Chlodzenia (MB 105)
$b.AddCompare($s2, 0, 18, [VlxOpcodes]::CMP_GT, [VlxOperandTypes]::MI, 52, "", [VlxOperandTypes]::CONST, 0, "10")
$b.AddWire($s2, 13, 18, 17, 0, $false)
$b.AddCoil($s2, 30, 18, [VlxOperandTypes]::MB, 105, [VlxOpcodes]::COIL_SET)

# -----------------------------------------------------------------------------
# Zakonczenie podprogramu (Zawsze wymagane!)
# -----------------------------------------------------------------------------
$b.AddReturnStrip()
$b.SaveOperands()
$b.Close()

Write-Host "[OK] Podprogram $subName zostal pomyslnie wygenerowany!" -ForegroundColor Green
