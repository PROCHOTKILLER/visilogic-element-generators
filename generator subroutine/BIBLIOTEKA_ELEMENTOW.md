# Kompletna Biblioteka Elementów Podprogramów Drabinkowych VisiLogic (.VLX)
### Generator Podprogramów PLC Unitronics Vision (V350, V120, V570, Samba)

Dokument stanowi kompletny, wyczerpujący katalog wszystkich rozkazów, bloków funkcyjnych, elementów graficznych oraz operandów obsługiwanych przez silnik generatora podprogramów drabinkowych `VlxBuilder.ps1` dla środowiska **Unitronics VisiLogic**.

---

## 1. Architektura Relacyjna Elementu Drabinki

W formacie eksportu/importu `.vlx` (relacyjna baza danych Jet 4.0 / Access 97) każdy element drabinki reprezentowany jest przez rekord w tabeli `expimp_LdrElements` oraz powiązane z nim rekordy operandów w tabeli `expimp_LdrElmsOprs`.

### 1.1. Pola rekordu `expimp_LdrElements`:
- **`ElmntID`** (`Long`): Unikalny identyfikator numeryczny elementu w obrębie podprogramu (generowany sekwencyjnie od 1).
- **`StripID`** (`Long`): Klucz obcy wskazujący na szczebel (`Strip`), w którym znajduje się element.
- **`ElmntType`** (`Integer`): Kod rozkazu / typu elementu (Opcode VisiLogic, patrz katalog poniżej).
- **`Xs`** (`Integer`): Początkowa współrzędna pozioma na siatce szczebla ($0 \le Xs \le 80$).
- **`Ys`** (`Integer`): Początkowa współrzędna pionowa na siatce szczebla (dla linii głównej ściśle $Ys = 4$).
- **`Dx`** (`Integer`): Długość przewodu w osi X (używane głównie dla `Wire`, dla pozostałych wynosi 0).
- **`Dy`** (`Integer`): Długość przewodu w osi Y (używane dla pionowego `Wire`).
- **`MoreParamsStr`** (`Text`): Dodatkowy ciąg znaków (np. nazwa wywoływanego podprogramu dla `Call Subroutine`).

### 1.2. Pola relacji operandów `expimp_LdrElmsOprs`:
- **`ElmntID`** (`Long`): Odwołanie do elementu drabinki.
- **`Elmnt_Oprnd_Type`** (`Integer`): Typ operandu (MB=1, MI=3, CONST=37 itd.).
- **`Elmnt_Oprnd_Adrs`** (`Integer`): Adres fizyczny operandu w sterowniku (lub indeks stałej w tabeli operandów).
- **`OprndInIdx`** (`Integer`): Numer indeksu wejściowego (1, 2, 3... dla wejść bloku; 0 jeśli brak).
- **`OprndOutIdx`** (`Integer`): Numer indeksu wyjściowego (1 dla wyjścia bloku/cewki; 0 jeśli brak).

---

## 2. Katalog Rozkazów i Elementów Drabinki (Opcodes Matrix)

### 2.1. Łączniki i Przewody Sygnałowe (Wires)

| Opcode | Nazwa Elementu | Symbol LAD | Szerokość ($Xe - Xs$) | Zastosowanie |
|:---:|:---|:---:|:---:|:---|
| **`100`** | **Wire Horizontal** | `-------` | Zmienna ($Dx$) | Poziome połączenie logiczne łączące wyjście poprzedniego elementu z wejściem kolejnego. |
| **`101`** | **Wire Vertical** | `│` | $0$ ($Dy$ w pionie) | Pionowe połączenie gałęzi równoległych (mostkowanie linii $Ys=4$ z $Ys=14, 24\dots$). |

#### Metody w API `VlxBuilder.ps1`:
```powershell
# Dodanie przewodu poziomego (od Xs do Xs+Dx na wysokości Ys):
$builder.AddWire($stripId, $xs, $ys, $dx, 0, $false)

# Dodanie przewodu pionowego (w dół od Ys o długości Dy na pozycji Xs):
$builder.AddWire($stripId, $xs, $ys, 0, $dy, $true)
```

---

### 2.2. Styki Wejściowe (Contacts)

Wszystkie styki zajmują dokładnie **6 jednostek szerokości siatki** ($Xe = Xs + 6$). Wejście i wyjście leżą na tej samej wysokości $Ys$.

| Opcode | Nazwa Rozkazu | Symbol LAD | Typ Warunku | Dopuszczalne Operandy |
|:---:|:---|:---:|:---|:---|
| **`200`** | **Direct Contact (NO)** | `---| |---` | Stan wysoki (1 / TRUE) | `MB`, `SB`, `I`, `O`, `T`, `C` |
| **`201`** | **Inverted Contact (NC)** | `---|/|---` | Stan niski (0 / FALSE) | `MB`, `SB`, `I`, `O`, `T`, `C` |
| **`202`** | **Positive Transition (P)** | `---|P|---` | Zbocze narastające ($0 \to 1$) | `MB`, `SB`, `I`, `O` |
| **`203`** | **Negative Transition (N)** | `---|N|---` | Zbocze opadające ($1 \to 0$) | `MB`, `SB`, `I`, `O` |

#### Metody w API `VlxBuilder.ps1`:
```powershell
# Styk normalnie otwarty (NO):
$builder.AddContact($stripId, $xs, $ys, [VlxOperandTypes]::MB, 100)

# Styk z podaniem typu (NO, NC, P, N):
$builder.AddContact($stripId, $xs, $ys, [VlxOperandTypes]::I, 0, [VlxOpcodes]::CONTACT_NC)
$builder.AddContact($stripId, $xs, $ys, [VlxOperandTypes]::MB, 50, [VlxOpcodes]::CONTACT_P)
$builder.AddContact($stripId, $xs, $ys, [VlxOperandTypes]::MB, 51, [VlxOpcodes]::CONTACT_N)
```

---

### 2.3. Cewki Wyjściowe (Coils)

Wszystkie cewki zajmują dokładnie **6 jednostek szerokości siatki** ($Xe = Xs + 6$) i są pozycjonowane na prawej szynie prądowej ($Xs = 74, Xe = 80$).

| Opcode | Nazwa Rozkazu | Symbol LAD | Działanie | Dopuszczalne Operandy |
|:---:|:---|:---:|:---|:---|
| **`204`** | **Direct Coil** | `---( )---` | Przypisanie stanu logicznego szczebla | `MB`, `SB`, `O` |
| **`205`** | **Inverted Coil** | `---(/)---` | Przypisanie zanegowanego stanu szczebla | `MB`, `SB`, `O` |
| **`206`** | **Set Coil (Latch)** | `---(S)---` | Ustawienie bitu w stan 1 (zatrzask) | `MB`, `SB`, `O` |
| **`207`** | **Reset Coil (Unlatch)**| `---(R)---` | Skasowanie bitu w stan 0 | `MB`, `SB`, `O` |
| **`212`** | **Toggle Coil** | `---(T)---` | Zmiana stanu bitu na przeciwny ($0 \leftrightarrow 1$) | `MB`, `SB`, `O` |

#### Metody w API `VlxBuilder.ps1`:
```powershell
# Cewka zwykła bezpośrednia:
$builder.AddCoil($stripId, 74, 4, [VlxOperandTypes]::O, 3)

# Cewki specjalne (SET / RESET / TOGGLE / INVERTED):
$builder.AddCoil($stripId, 74, 4, [VlxOperandTypes]::MB, 200, [VlxOpcodes]::COIL_SET)
$builder.AddCoil($stripId, 74, 4, [VlxOperandTypes]::MB, 200, [VlxOpcodes]::COIL_RESET)
$builder.AddCoil($stripId, 74, 4, [VlxOperandTypes]::MB, 201, [VlxOpcodes]::COIL_TOGGLE)
```

---

### 2.4. Komparatory Liczbowe (Compare Blocks)

Komparatory zajmują **13 jednostek szerokości** ($Xe = Xs + 13$). Posiadają 2 wejścia operandów: $A$ (`OprndInIdx = 1`) oraz $B$ (`OprndInIdx = 2`).

| Opcode | Relacja Porównania | Symbol Bloku | Warunek Zezwolenia |
|:---:|:---|:---:|:---|
| **`300`** | **Less Than** | `[ A < B ]` | Wejście A jest ściśle mniejsze od B |
| **`301`** | **Greater Than** | `[ A > B ]` | Wejście A jest ściśle większe od B |
| **`302`** | **Equal** | `[ A = B ]` | Wejście A jest równe wejściu B |
| **`303`** | **Less or Equal** | `[ A <= B ]`| Wejście A jest mniejsze bądź równe B |
| **`304`** | **Greater or Equal** | `[ A >= B ]`| Wejście A jest większe bądź równe B |
| **`305`** | **Not Equal** | `[ A <> B ]`| Wejście A jest różne od wejścia B |

#### Dopuszczalne typy danych:
- Wejście A: `MI`, `SI`, `ML`, `SL`, `MDW`, `CONST`
- Wejście B: `MI`, `SI`, `ML`, `SL`, `MDW`, `CONST`

#### Metoda w API `VlxBuilder.ps1`:
```powershell
# Porównanie rejestru MI0 ze stałą 50 (MI0 > 50):
$builder.AddCompare($stripId, $xs, 4, [VlxOpcodes]::CMP_GT, `
    [VlxOperandTypes]::MI, 0, "", `
    [VlxOperandTypes]::CONST, 0, "50")
```

---

### 2.5. Bloki Arytmetyczne (Math Blocks)

Bloki arytmetyczne zajmują **13 jednostek szerokości** ($Xe = Xs + 13$). Posiadają wejście zezwalające EN, dwa wejścia wartości $A$ i $B$ oraz wyjście wyniku $C$.

| Opcode | Działanie | Równanie | Wejście 1 (`In 1`) | Wejście 2 (`In 2`) | Wyjście (`Out 1`) |
|:---:|:---|:---:|:---:|:---:|:---:|
| **`400`** | **Subtract** | $A - B = C$ | Odjemna ($A$) | Odjemnik ($B$) | Różnica ($C$) |
| **`401`** | **Divide** | $A / B = C$ | Dzielna ($A$) | Dzielnik ($B$) | Iloraz całkowity ($C$) |
| **`405`** | **Add** | $A + B = C$ | Składnik 1 ($A$) | Składnik 2 ($B$) | Suma ($C$) |
| **`406`** | **Multiply** | $A \times B = C$ | Czynnik 1 ($A$) | Czynnik 2 ($B$) | Iloczyn ($C$) |
| **`407`** | **Modulo** | $A \pmod B = C$ | Dzielna ($A$) | Dzielnik ($B$) | Reszta z dzielenia ($C$) |
| **`1500`** | **Increment** | $A + 1 \to A$ | - | - | Zmienna docelowa ($A$) |
| **`1501`** | **Decrement** | $A - 1 \to A$ | - | - | Zmienna docelowa ($A$) |

#### Metody w API `VlxBuilder.ps1`:
```powershell
# Dodawanie MI10 + 15 = MI20:
$builder.AddMath($stripId, $xs, 4, [VlxOpcodes]::MATH_ADD, `
    [VlxOperandTypes]::MI, 10, "", `
    [VlxOperandTypes]::CONST, 0, "15", `
    [VlxOperandTypes]::MI, 20)

# Inkrementacja licznika cykli MI5:
$builder.AddInc($stripId, $xs, 4, [VlxOperandTypes]::MI, 5)

# Dekrementacja pozostałego czasu MI30:
$builder.AddDec($stripId, $xs, 4, [VlxOperandTypes]::MI, 30)
```

---

### 2.6. Bloki Pamięci, Danych i Skalowania

| Opcode | Nazwa Rozkazu | Szerokość | Wejścia | Wyjścia | Opis |
|:---:|:---|:---:|:---:|:---:|:---|
| **`900`** | **Store (Move)** | 13 | 1 ($A$) | 1 ($B$) | Przepisanie wartości ze źródła $A$ do rejestru docelowego $B$ ($A \to B$). |
| **`1300`** | **Linearize** | 17 | 5 ($X, X_1, Y_1, X_2, Y_2$) | 1 ($Y$) | Przeskalowanie liniowe wejścia $X$ do zakresu wyjściowego $Y$: $Y = \frac{(X - X_1)(Y_2 - Y_1)}{X_2 - X_1} + Y_1$. |

#### Metody w API `VlxBuilder.ps1`:
```powershell
# Przepisanie stałej 75 do rejestru MI31 (Nastawa SP):
$builder.AddStore($stripId, $xs, 4, [VlxOperandTypes]::CONST, 0, "75", [VlxOperandTypes]::MI, 31)

# Skalowanie przetwornika 4..20mA (MI10: 819..4095 -> MI0: 0..100 °C):
$builder.AddLinearize($stripId, $xs, 4, `
    [VlxOperandTypes]::MI, 10, `
    "819", "0", "4095", "100", `
    [VlxOperandTypes]::MI, 0)
```

---

### 2.7. Sterowanie Przepływem i Rozkazy Systemowe

| Opcode | Nazwa Rozkazu | Szerokość | Opis i Zastosowanie |
|:---:|:---|:---:|:---|
| **`601`** | **Call Subroutine** | 13 | Bezwarunkowe lub warunkowe wywołanie innego podprogramu. W polu `MoreParamsStr` podaje się dokładną nazwę podprogramu docelowego. |
| **`602`** | **Return** | 6 | Zakończenie wykonywania podprogramu. Umieszczane wyłącznie w specjalnym szczeblu `IsReturnStrip = -1`. |
| **`204` (T)** | **Timer Hardware** | 6 | Cewka timera sprzętowego (`TypeID = 11`). Czas zadany definiowany w polu `OprndPowerUp` w formacie setnych sekundy. |

#### Metody w API `VlxBuilder.ps1`:
```powershell
# Wywołanie podprogramu "RegulacjaPID":
$builder.AddCallSub($stripId, $xs, 4, "RegulacjaPID")

# Timer programowy T1:
$builder.AddTimer($stripId, 74, 4, 1)

# Zamknięcie podprogramu obowiązkowym szczeblem Return:
$builder.AddReturnStrip()
```

---

## 3. Kompletna Tabela Typów Pamięci PLC Unitronics (`VlxOperandTypes`)

| Typ ID | Symbol | Nazwa Rejestru / Pamięci | Dostępność bit/słowo | Rozmiar w pamięci | Zakres wartości |
|:---:|:---:|:---|:---:|:---:|:---|
| **`1`** | **MB** | Memory Bit | Bit | 1 bit | `0` lub `1` |
| **`2`** | **SB** | System Bit | Bit | 1 bit | `0` lub `1` (np. SB13 zbocze 1s) |
| **`3`** | **MI** | Memory Integer | Słowo (Word) | 16-bit ze znakiem | `-32 768` .. `+32 767` |
| **`4`** | **SI** | System Integer | Słowo (Word) | 16-bit ze znakiem | `-32 768` .. `+32 767` (np. SI30 RTC) |
| **`5`** | **ML** | Memory Long Integer | Podwójne słowo | 32-bit ze znakiem | `-2 147 483 648` .. `+2 147 483 647` |
| **`6`** | **SL** | System Long | Podwójne słowo | 32-bit ze znakiem | `-2 147 483 648` .. `+2 147 483 647` |
| **`7`** | **MF** | Memory Float | Liczba zmiennoprzec. | 32-bit IEEE 754 | $\pm 1.18 \times 10^{-38} .. \pm 3.4 \times 10^{38}$ |
| **`9`** | **I** | Digital Input | Bit sprzętowy | 1 bit | `0` lub `1` (I0 .. I17 w V350-RA22) |
| **`10`** | **O** | Digital / Relay Output | Bit sprzętowy | 1 bit | `0` lub `1` (O0 .. O13 w V350-RA22) |
| **`11`** | **T** | Hardware Timer | Specjalny | Struktura TMR | Wartość bieżąca, nastawa, flaga |
| **`12`** | **C** | Counter | Słowo | 16-bit | `0` .. `32 767` |
| **`16`** | **MDW**| Memory Double Word | Podwójne słowo | 32-bit bez znaku | `0` .. `4 294 967 295` |
| **`31`** | **SUB**| Subroutine Name Pointer| Wskaźnik | - | Referencja do nazwy podprogramu |
| **`37`** | **CONST**| Constant Value (Immediate)| Wartość stała | Zmienna | Liczba wprowadzona w skrypcie |
