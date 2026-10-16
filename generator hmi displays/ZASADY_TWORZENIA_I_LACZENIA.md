# Kompletna Lista Zasad Projektowania, Układu i Łączenia Ekranów HMI VisiLogic (.VLD)
### Standard Inżynierski | Sterowniki Unitronics Vision V350 (Matryca 320x240 px, Dotyk)

Dokument określa bezwzględne reguły projektowe, geometryczne, bazodanowe oraz ergonomiczne dla automatycznego generowania pakietów ekranów operatorskich HMI w formacie `.vld`. Zastosowanie się do tych zasad gwarantuje 100% stabilności importu w oprogramowaniu VisiLogic oraz pełną zgodność ze standardem **ANSI/ISA-101.01 (High Performance HMI)**.

---

## 1. Ograniczenia Fizyczne i Geometria Matrycy Unitronics Vision V350

Sterownik PLC Unitronics Vision V350 wyposażony jest w kolorowy wyświetlacz TFT o parametrach:
- **Rozdzielczość:** dokładnie **320 pikseli szerokości (X)** na **240 pikseli wysokości (Y)**.
- **Głębia kolorów:** 16-bit (65 536 kolorów, paleta Unitronics).
- **Interfejs użytkownika:** Rezystancyjny ekran dotykowy (Touch Screen) + 5 programowalnych klawiszy funkcyjnych.

```text
(0,0) ------------------------------------------------------------- (319,0)
|  Pasek Tytułowy / Nagłówek Ekranu (Y = 0 .. 24 px)                      |
|-------------------------------------------------------------------------|
|                                                                         |
|  Obszar Roboczy Procesu / Karty Synoptyczne                             |
|  (Y = 25 .. 205 px)                                                     |
|                                                                         |
|-------------------------------------------------------------------------|
|  Dolny Pasek Nawigacyjny "One-Click" (Y = 206 .. 239 px)                |
(0,239) --------------------------------------------------------- (319,239)
```

### 1.1. Bezwzględne Granice Geometrii Kontrolek
Żadna kontrolka ani jej cień/ramka nie może wykraczać poza obszar roboczy wyświetlacza:
$$0 \le Xs \le 319$$
$$0 \le Ys \le 239$$
$$Xs + Dx \le 320$$
$$Ys + Dy \le 240$$
Naruszenie powyższych granic powoduje obcięcie kontrolki lub błąd alokacji bufora graficznego w VisiLogic.

### 1.2. Ergonomia Przycisków Dotykowych
- Minimalne wymiary przycisku dotykowego pod palec operatora w rękawicy przemysłowej wynoszą: **$Dx \ge 40$ px, $Dy \ge 24$ px**.
- Odstęp (margines) pomiędzy sąsiadującymi przyciskami dotykowymi: minimum **4 piksele**, aby wyeliminować przypadkowe naciśnięcie sąsiedniej strefy.

---

## 2. Żelazne Zasady Stabilności Bazy Danych .VLD (Zero-Crash Policy)

VisiLogic wykorzystuje 32-bitowe biblioteki ActiveX/COM napisane w Visual Basic 6 (`UnHmPge2.dll`). Nieprawidłowości w relacjach bazy Jet 4.0 prowadzą do błędu *Run-time error '9': Subscript out of range* lub natychmiastowego zamknięcia programu (Crash).

### Zasada 1: Zerowa Liczba Wpisów w Tabeli `HMIJumps` dla Paneli Dotykowych V350
- **Mechanizm błędu:** Biblioteka `UnHmPge2.dll` alokuje wewnętrzną tablicę `JumpArray(1 To 4)` przeznaczoną wyłącznie dla sterowników z fizyczną klawiaturą (np. V120, V280). Dodanie wpisów do tabeli `HMIJumps` przepełnia bufor i wyrzuca krytyczny błąd VB6 Error 9.
- **Wymóg bezwzględny:** Dla ekranów sterownika Vision V350 tabela `HMIJumps` w pliku `HMIBufferColorPages.udb` **musi zawierać dokładnie 0 rekordów**!
- **Sposób nawigacji:** Nawigacja dotykowa na panelach V350 odbywa się wyłącznie poprzez pole `TouchOprndAddr` w kontrolce przycisku (powiązanie z bitem `MB`, który w logice drabinkowej wywołuje skok ekranu).

### Zasada 2: Wyeliminowanie Zależności od Niezainicjalizowanych Trendów (`VarType = 23`)
- **Mechanizm błędu:** Wklejenie kontrolki Trendu powoduje wykonanie zapytania SQL do projektu docelowego: `SELECT Name FROM Trends WHERE TrendID=1`. Jeśli użytkownik nie utworzył wcześniej obiektu `Trend 1` w drzewie PLC, VisiLogic próbuje odczytać pusty indeks kolekcji i ulega awarii.
- **Rozwiązanie inżynierskie:** W uniwersalnych pakietach HMI należy stosować natywne **Bargraphy procesowe (`VarType = 24`)**, dynamiczne wskaźniki synoptyczne i multizmienne numeryczne. Są one w 100% samowystarczalne i nie wymagają prekonfiguracji projektu PLC.

### Zasada 3: Obowiązkowy Rekord Bufora w Tabeli `DisplayNote`
- Dla każdego zdefiniowanego ekranu (`PageID`) w tabeli `Pages` **musi istnieć dokładnie jeden rekord w tabeli `DisplayNote`**.
- Rekord ten zawiera wyzerowany bufor binarny o długości **dokładnie 510 bajtów**. Brak tego rekordu powoduje naruszenie pamięci (Memory Access Violation) przy próbie otwarcia właściwości strony.

### Zasada 4: Lustrzana Spójność Tabel `Pages` i `Pages_all`
- Tabele `Pages` oraz `Pages_all` muszą zawierać dokładnie ten sam zestaw rekordów o identycznych identyfikatorach `ID`, nazwach, kolorach tła i flagach `ModuleID` (1 dla Start-Up Display, 2 dla stron podrzędnych).

### Zasada 5: Integralność Binarna Obiektów Property Bag
Wszystkie kontrolki procesowe wymagają strumienia bajtów OLE Property Bag o ściśle zdefiniowanej długości:
- **Numeric Variable (`VarType = 8`):** dokładnie **1740 bajtów** (`numeric_propertybag.bin`).
- **Bargraph (`VarType = 24`):** dokładnie **624 bajty** (`bargraph_propertybag.bin`).
- **Gauge (`VarType = 21`):** dokładnie **1464 bajty** (`gauge_propertybag.bin`).
- **Tank (`VarType = 25`):** dokładnie **512 bajtów** (`tank_propertybag.bin`).
- **Dynamic Binary Text (`VarType = 2`):** wygenerowany przez dedykowany generator nagłówków OLE `CreateBinaryTextPropertyBag()`.

---

## 3. Zasady Łączenia Kontrolek ze Zmiennymi PLC (Operand Binding Rules)

Każde powiązanie kontrolki ze zmienną PLC musi być zarejestrowane w tabeli `HMI_Operands` z zachowaniem poniższych reguł:

### 3.1. Przyciski Dotykowe (Touch Buttons)
- Pole `TouchOprndAddr` w tabeli `HMI_Elements` musi wskazywać numer bitu pamięci `MB` (np. `22`).
- W tabeli `HMI_Operands` musi zostać dodany rekord:
  - `ElementID` = ID przycisku
  - `OperandType` = `1` (`MB`)
  - `OperandAddress` = numer bitu `MB`
  - `FieldRole` = `2` (Touch Operand)

### 3.2. Odczyt Wartości Procesowych (Process Values - PV)
- Dotyczy zmiennych numerycznych odczytu (`VarKeyPadEntry = 0`), słupków bargraph, zegarów gauge i wskaźników zbiornika.
- W tabeli `HMI_Operands` dodawany jest rekord z rolą:
  - `FieldRole` = `1` (Value Operand)
  - `OperandType` = `3` (`MI`) lub `16` (`DW`) lub `5` (`ML`)

### 3.3. Zadawanie Parametrów z Klawiatury Dotykowej (Setpoints - SP)
- Dotyczy pól nastaw technologicznych (temperatura zadana, wilgotność zadana, czas cyklu).
- Kontrolka musi mieć ustawioną flagę: **`VarKeyPadEntry = 1`**.
- W tabeli `HMI_Operands` dodawany jest rekord z rolą `FieldRole = 1` dla docelowego rejestru `MI`. Po dotknięciu operator otrzymuje systemowe okno klawiatury numerycznej VisiLogic z walidacją limitów Min/Max.

### 3.4. Dynamiczny Tekst Binarny (BinaryText Status)
- Służy do wizualizacji stanu pracy napędów i sekcji (np. wentylatory W1..W6, grzałki G1..G6).
- Rejestrowany w `HMI_Operands` z:
  - `FieldRole` = `1` (Value)
  - `OperandType` = `10` (Wyjście fizyczne `O`) lub `1` (`MB`) lub `9` (Wejście `I`)
- Właściwości binarne kontrolki w `HMI_Elements` muszą posiadać:
  - `DescriptionFontNumber = 282392660`
  - `DefaultDisplay = 2`
  - `StrStorageOprndAddr = -1`
  - `StrStorageFont = 89352336`

---

## 4. Zasady Projektowania Zgodnego z ANSI/ISA-101.01

Interfejs HMI musi być zaprojektowany zgodnie ze standardem **High Performance HMI (ANSI/ISA-101.01)**:

1. **Stonowane Tło i Redukcja Zmęczenia Wzroku:**
   - Domyślne tło ekranu: neutralna szarość (`ColorBack = 74`).
   - Unikać jaskrawych teł (czarnych o wysokim kontraście lub białych rażących operatora).
2. **Rezerwacja Barw Wyłącznie dla Informacji Stanowych:**
   - **Czerwony (`2`):** Zarezerwowany **wyłącznie** dla awarii, E-Stop i alarmów krytycznych (ISA-18.2 Priority 1).
   - **Żółty (`14`):** Zarezerwowany dla ostrzeżeń technologicznych (otwarte drzwi, zbliżenie do limitu).
   - **Zielony (`10`):** Praca urządzeń (silnik RUN, grzałka HEATING).
   - **Szary (`103` / `104`):** Stan wyłączenia / spoczynku / gotowości (STOP, OFF).
3. **Pasek Nawigacyjny "One-Click":**
   - Na dole każdego ekranu ($Y=206..239$ px) znajduje się stały pasek z dużymi przyciskami umożliwiającymi bezpośrednie przejście do głównych obszarów funkcjonalnych bez błądzenia po zagnieżdżonych menu.
4. **Hierarchia 3 Poziomów Dostępu:**
   - **Poziom 1 (Operator):** Dostęp bezpośredni, bez hasła. Start, Pauza, Stop, podgląd parametrów i trendów.
   - **Poziom 2 (Technolog):** Dostęp chroniony kodem PIN. Modyfikacja receptur, czasów faz, nastaw histerezy i temperatur.
   - **Poziom 3 (Serwis):** Dostęp chroniony kodem PIN. Ręczne testy wyjść, parametry rozruchu, konfiguracja Auto-Resume po zaniku zasilania.

---

## 5. Procedura Walidacji i Testowania Pakietu VLD

Przed importem pakietu do oprogramowania VisiLogic, wykonaj procedurę audytu w 32-bitowym PowerShell:

```powershell
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "narzedzia\generator hmi displays\verify_displays.ps1" -VldPath "KOMORA9_HMI_ISA101.vld"
```

### Kryteria Odbioru Technicznego Pakietu:
- [x] Sprawdzenie archiwum ZIP i bazy `HMIBufferColorPages.udb` – Status OK.
- [x] Spójność tabel stron `Pages` i `Pages_all` – 11 ekranów, identyczne ID.
- [x] Obecność buforów `DisplayNote` – 11 rekordów po 510 B.
- [x] Poprawność geometrii kontrolek w siatce 320x240 – 0 przekroczeń.
- [x] Integralność relacji `HMI_Operands` – brak wiszących referencji.
- [x] Tabela `HMIJumps` – dokładnie 0 wpisów.
- [x] Błędy krytyczne: **0**, Ostrzeżenia: **0**.
