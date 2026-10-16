# Kompletna Lista Zasad Tworzenia, Łączenia i Geometrii Podprogramów VisiLogic (.VLX)
### Standard Inżynierski | Generator Drabinki PLC Unitronics Vision (V350, V120, Samba)

Dokument zawiera bezwzględne reguły geometryczne, elektryczne, logiczne i bazodanowe, które muszą być zachowane podczas generowania plików podprogramów `*.vlx`. Niezastosowanie się do poniższych zasad skutkuje błędami kompilacji w VisiLogic, "wiszącymi" przewodami lub krytycznym wyłączeniem programu (Crash / Fatal Memory Violation).

---

## 1. Zasady Geometrii Siatki Roboczej (Grid 0..80 x 0..60)

Edytor drabinkowy VisiLogic operuje na dyskretnej siatce współrzędnych wyrażonej w jednostkach umownych:
- **Oś pozioma ($X$):** Zakres od `0` do `80`.
  - Szyna prądowa lewa (zasilanie logiczne): $X = 0$.
  - Szyna prądowa prawa (zakończenie cewek): $X = 80$.
- **Oś pionowa ($Y$):** Zakres od `0` do `60`.
  - Standardowa wysokość pojedynczego szczebla wynosi 14 jednostek (`Height = 14`).

```text
X=0                                                                     X=74      X=80
 |                                                                        |        |
 |--[ NO Contact ]------[ Compare Block ]------[ Math ADD ]---------------( Coil )--|
 |   (Xs=0, Xe=6)        (Xs=10, Xe=23)         (Xs=28, Xe=41)          (Xs=74,Xe=80)
 |
 Ys=4 ----------------- Główna Oś Magistrali Sygnałowej ------------------------- Ys=4
```

### 1.1. Żelazna Reguła Osi Sygnałowej: $Ys = 4$
- Wszystkie styki (NO, NC, P, N) oraz wejścia zezwalające `EN` bloków funkcyjnych (Math, Store, Compare, Call Sub) w pierwszym wierszu szczebla **muszą mieć bezwzględnie współrzędną $Ys = 4$**.
- Zastosowanie innej współrzędnej (np. $Ys=0$, $Ys=5$, $Ys=10$) tworzy na schemacie załamania ("schodki"), rozłącza piny elementów lub uniemożliwia przepływ prądu logicznego.

### 1.2. Reguła Pozycjonowania Cewek: $Xs = 74, Xe = 80$
- Każda cewka (`Direct`, `Inverted`, `Set`, `Reset`, `Toggle`) oraz cewka Timera **musi być umieszczona ściśle przy prawej szynie zasilającej**.
- Współrzędne cewki wynoszą zawsze: $Xs = 74, Ys = 4$ (szerokość elementu wynosi 6, więc $Xe = 74 + 6 = 80$).
- Umieszczenie cewki w środku szczebla (np. $Xs=30$) jest w VisiLogic błędem składni i uniemożliwia kompilację programu PLC.

---

## 2. Zasady Łączenia Elementów Przewodami (Wiring Rules)

### 2.1. Ciągłość Linii Poziomej (Brak Luk w Przepływie Energii)
- Wszelkie puste przestrzenie pomiędzy kolejnymi elementami drabinki muszą być wypełnione poziomym przewodem `Wire Horizontal` (Opcode `100`).
- Jeśli element $A$ kończy się na $Xe_A$, a kolejny element $B$ zaczyna się na $Xs_B$, gdzie $Xs_B > Xe_A$, **wymagane jest wstawienie przewodu:**
  $$\text{AddWire}(sid, Xs = Xe_A, Ys = 4, Dx = Xs_B - Xe_A, Dy = 0, \text{isVert} = \text{false})$$
- Od wyjścia ostatniego bloku logicznego do wejścia cewki na $Xs=74$ **musi zawsze biec przewód domykający**:
  $$\text{AddWire}(sid, Xs = Xe_{ostatni}, Ys = 4, Dx = 74 - Xe_{ostatni}, 0, \text{false})$$

### 2.2. Rozgałęzienia Równoległe (Branches)
W przypadku budowania gałęzi alternatywnych (funkcja logiczna OR):
1. **Węzeł rozgałęzienia (Split):** Na pozycji $X$ węzła wstawiany jest przewód pionowy w dół:
   $$\text{AddWire}(sid, Xs = X_{split}, Ys = 4, Dx = 0, Dy = 10, \text{isVert} = \text{true})$$
2. **Dolna gałąź:** Elementy alternatywne umieszczane są na linii $Ys = 14$ ($4 + 10$).
3. **Węzeł zbiegu (Join):** Za ostatnim elementem dolnej gałęzi wstawiany jest przewód pionowy w górę do linii głównej ($Ys=4$).
4. **Wysokość szczebla:** Przy gałęziach równoległych parametr szczebla `Height` musi wynosić minimum `24` (lub `34` dla 3 gałęzi).

---

## 3. Matryca Wymiarów Geometrycznych Elementów

Podczas obliczania współrzędnych kolejnych elementów na linii $Ys=4$, stosuj poniższe stałe wymiarowe:

| Kategoria Elementu | Opcodes | Szerokość $\Delta X$ | Współrzędna Początkowa | Współrzędna Końcowa |
|:---|:---:|:---:|:---:|:---:|
| **Styk (Contact)** | `200` .. `203` | **6** | $Xs$ | $Xe = Xs + 6$ |
| **Komparator (Compare)** | `300` .. `305` | **13** | $Xs$ | $Xe = Xs + 13$ |
| **Arytmetyka (Math)** | `400` .. `407` | **13** | $Xs$ | $Xe = Xs + 13$ |
| **Przepisanie (Store)** | `900` | **13** | $Xs$ | $Xe = Xs + 13$ |
| **Wywołanie (Call Sub)**| `601` | **13** | $Xs$ | $Xe = Xs + 13$ |
| **Skalowanie (Linearize)**| `1300` | **17** | $Xs$ | $Xe = Xs + 17$ |
| **Inkrement / Dekrement**| `1500`, `1501`| **13** | $Xs$ | $Xe = Xs + 13$ |
| **Cewka (Coil)** | `204` .. `212` | **6** | $74$ | $80$ |
| **Przewód Poziomy** | `100` | $Dx$ | $Xs$ | $Xe = Xs + Dx$ |

---

## 4. Zasady Struktury Szczebli (Strips / Networks)

### 4.1. Unikalność i Sekwencja Szczebli
- Każdy szczebel w tabeli `expimp_LdrStrips` musi posiadać unikalne `StripID`.
- Pola `SeqNum` oraz `ShowNum` muszą tworzyć ciągłą numerację od 1 do $N$.
- Flaga `IsCompilable` musi mieć wartość `-1` (w notacji Jet SQL oznacza to logiczne TRUE).

### 4.2. Obowiązkowy Szczebel Return (End of Subroutine)
- **Każdy podprogram w VisiLogic MUSI kończyć się specjalnym szczeblem powrotu:**
  - W rekordzie `expimp_LdrStrips`: `IsReturnStrip = -1`.
  - W rekordzie `expimp_LdrElements`: Dokładnie jeden element typu `ElmntType = 602` na pozycji $Xs=0, Ys=5$.
  - W tabeli powiązań operandów: Brak wpisów dla elementu 602.
- Brak szczebla Return skutkuje błędem kompilacji projektu PLC (*Subroutine must terminate with Return*).

---

## 5. Spójność Relacyjna Bazy Danych Jet 4.0

### 5.1. Zakaz wartości NULL w tabeli `expimp_LdrElmsOprs`
- **Przyczyna 95% crashy VisiLogic:** VisiLogic jest aplikacją 32-bitową napisaną w Visual Basic 6. Przy deserializacji rekordów drabinki funkcja VB6 próbuje odczytać właściwości operandów. Napotkanie wartości `DBNull` w kolumnach `Elmnt_Oprnd_Type` lub `Elmnt_Oprnd_Adrs` wywołuje natychmiastowy wyjątek pamięci (*Runtime Error 440: Automation Error / Memory Access Violation*) i zamknięcie programu.
- Wszystkie rekordy w `expimp_LdrElmsOprs` muszą mieć jawnie określony typ oraz poprawny adres numeryczny.

### 5.2. Rejestracja Stałych Numerycznych (`CONST` / Typ 37)
- Jeśli w bloku matematycznym, komparatorze lub funkcji Store używana jest stała liczbowa (np. `100`, `0`, `3600`):
  1. Stała **musi** zostać zarejestrowana w tabeli `expimp_LdrOperands` z typem `OprndType = 37`.
  2. Wartość stałej musi być wpisana do kolumny `OprndPowerUp` jako liczba dziesiętna.
  3. Indeks porządkowy stałej ($0, 1, 2\dots$) musi zostać wpisany jako `OprndAddress` w `expimp_LdrOperands` oraz jako `Elmnt_Oprnd_Adrs` w `expimp_LdrElmsOprs`.
  4. Pominięcie rejestracji stałej powoduje, że blok po imporcie otrzymuje wartość `0` zamiast zadanej liczby.

---

## 6. Wymogi Środowiska Wykonawczego (Runtime & OLEDB)

### 6.1. Architektura 32-bit (x86)
- Sterownik `Microsoft.Jet.OLEDB.4.0` oraz silnik DAO/Access 97 **istnieją wyłącznie w wersji 32-bitowej**.
- Uruchomienie generatora w standardowym 64-bitowym PowerShell (`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`) wyrzuci błąd:
  `The 'Microsoft.Jet.OLEDB.4.0' provider is not registered on the local machine`.
- **Wymóg bezwzględny:** Wszystkie operacje bazodanowe na plikach `.vlx` muszą być wykonywane przez 32-bitowy interpreter:
  `C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`

### 6.2. Hasło Bazy Danych Unitronics
- Pliki `.vlx` są zabezpieczone hasłem systemowym Jet OLEDB.
- Ciąg połączeniowy musi zawierać parametr: `Jet OLEDB:Database Password=UniOpenSesame;`.

---

## 7. Katalog 6 Krytycznych Błędów i Procedury Zapobiegawcze

| # | Błąd / Objaw | Przyczyna źródłowa | Jak zapobiegać |
|:---:|:---|:---|:---|
| **1** | **VisiLogic Crash przy imporcie** | Wartości NULL w tabeli `expimp_LdrElmsOprs` | Zawsze używać `VlxBuilder.ps1` i uruchamiać `verify_vlx.ps1` przed importem. |
| **2** | **"Failed to import subroutine"** | W drzewie projektu istnieje już pusty podprogram o identycznej nazwie | Przed kliknięciem Import usunąć z drzewa podprogram o tej samej nazwie. |
| **3** | **Czerwone linie błędu (Brak połączeń)** | Luka we współrzędnych $X$ pomiędzy blokami | Sprawdzać, czy przewód poziomy łączy $Xe$ poprzedniego z $Xs$ kolejnego elementu. |
| **4** | **Schodki na liniach połączeń** | Niezgodność osi pionowej (np. styk na $Y=0$, blok na $Y=4$) | Ściśle stosować współrzędną $Ys = 4$ dla całej linii głównej. |
| **5** | **Wartości w blokach równe 0** | Użyto stałej, ale nie wpisano jej do `expimp_LdrOperands` | Korzystać z automatycznej metody `GetConstIndex()` w klasie `VlxBuilder`. |
| **6** | **Błąd Provider OLEDB w PowerShell** | Skrypt wywołany w 64-bit PowerShell | Wywoływać przez wrapper `generate_subroutine.ps1` lub jawnie z `SysWOW64`. |

---

## 8. Procedura Walidacji i Kontroli Jakości (Przed Importem)

Przed dostarczeniem pliku `.vlx` inżynier lub skrypt musi wykonać weryfikację automatyczną:

```powershell
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "narzedzia\generator subroutine\verify_vlx.ps1" -VlxPath "MojPodprogram.vlx"
```

**Kryteria odbioru technicznego:**
- `IsReturnStrip obecny: TAK`
- `Liczba bledow krytycznych: 0`
- `Liczba ostrzezen: 0`
- Weryfikacja wizualna: Czysty schemat drabinkowy bez załamań, z kompletnymi połączeniami do prawej szyny $X=80$.
