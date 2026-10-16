# Kompletna Biblioteka Kontrolek i Elementów HMI VisiLogic (.VLD)
### Standard ANSI/ISA-101.01 | Sterowniki Unitronics Vision V350 (Matryca 320x240 px, 16-bit Kolor)

Dokument stanowi kompletny, wyczerpujący katalog wszystkich kontrolek wizualizacyjnych, przycisków dotykowych, zmiennych procesowych oraz struktur binarnych (Property Bag) obsługiwanych przez silnik generatora ekranów HMI `HmiDisplayBuilder.ps1` w formacie bazy danych `.vld` (`HMIBufferColorPages.udb`).

---

## 1. Architektura Relacyjna Kontrolek HMI (.VLD)

Plik pakietu ekranów `.vld` jest archiwum ZIP zawierającym relacyjną bazę danych Microsoft Access Jet 4.0 / ACE OLEDB (`HMIBufferColorPages.udb`). Wszystkie kontrolki wizualne i powiązania procesowe rejestrowane są w relacji dwóch kluczowych tabel:

```text
Pages / Pages_all (Ekran HMI)
  └── [1 : N] ── HMI_Elements (Kontrolka Graficzna / Zmienna)
                   └── [1 : N] ── HMI_Operands (Wiązanie ze Zmienną PLC)
```

### 1.1. Pola rekordu `HMI_Elements`:
- **`ID`** (`Long`): Unikalny identyfikator kontrolki w bazie.
- **`DisplayID`** (`Long`): Klucz obcy wskazujący ekran (`Pages.ID`), do którego należy kontrolka.
- **`Type`** (`Integer`): Podstawowy typ elementu graficznego (patrz tabela poniżej).
- **`VarType`** (`Integer`): Podtyp zmiennej procesowej (dla elementów typu 5/8).
- **`Xs`, `Ys`** (`Integer`): Współrzędne lewego górnego rogu w siatce pikseli ($0 \le Xs \le 319$, $0 \le Ys \le 239$).
- **`Dx`, `Dy`** (`Integer`): Szerokość i wysokość kontrolki w pikselach.
- **`ColorFore`, `ColorBack`** (`Integer`): Kolory tekstu/krawędzi oraz tła kontrolki (kody 16-bit palety Unitronics).
- **`Flat3D`** (`Integer`): Styl ramki: `0` = Płaski (Flat), `1` = Wypukły (Raised Button), `2` = Wklęsły (Sunken), `3` = Wyraźna ramka (Bordered).
- **`Alignment`** (`Integer`): Wyrównanie tekstu: `0` = Lewo, `2` = Prawo, `4` = Środek (Center).
- **`TouchOprndAddr`** (`Integer`): Adres fizyczny bitu `MB` ustawianego dotykowo przez operatora (lub `-1` gdy brak).
- **`VarKeyPadEntry`** (`Integer`): Flaga wirtualnej klawiatury dotykowej (`1` = edycja dozwolona po dotknięciu, `0` = tylko odczyt).
- **`[Binary]`** (`OLE Object / Long Binary`): Serializowany strumień parametrów OLE Property Bag (dla zmiennych numerycznych, bargraphów, gauge itp.).

---

## 2. Katalog Kontrolek Statycznych i Przycisków

### 2.1. Etykieta Tekstowa (Label)
Służy do wyświetlania stałych tekstów informacyjnych, tytułów sekcji, nagłówków kolumn oraz jednostek pomiarowych.

- **Identyfikacja:** `Type = 4`, `VarType = 0`, `[Binary] = NULL`.
- **Wymiary:** Dowolne w granicach ekranu ($Dx \ge 10, Dy \ge 10$).
- **Parametry czcionki:** `FontNumber = 282392660`, `Alignment = 4` (wyśrodkowany) lub `0` (do lewej).
- **Wywołanie API `HmiDisplayBuilder`:**
  ```powershell
  $display.AddLabel($x, $y, $w, $h, "TEMPERATURA [C]:", [HmiColor]::Black, [HmiColor]::LightGray, 3)
  ```

### 2.2. Panel / Prostokąt Grupujący (Rectangle)
Służy do budowy tła sekcji, ramek grupujących (np. sekcja grzania, sekcja wentylacji) zgodnie ze standardem ISA-101.

- **Identyfikacja:** `Type = 1`, `VarType = 0`, `[Binary] = NULL`.
- **Parametry:** `ColorFore` = kolor ramki, `ColorBack` = kolor wypełnienia, `Flat3D = 0`.
- **Wywołanie API `HmiDisplayBuilder`:**
  ```powershell
  $display.AddRectangle($x, $y, $w, $h, [HmiColor]::DarkGray, [HmiColor]::LightGray)
  ```

### 2.3. Linia Podziału (Line)
Służy do optycznego rozdzielania bloków synoptycznych lub pasków nawigacji.

- **Identyfikacja:** `Type = 2`, `VarType = 0`, `[Binary] = NULL`.
- **Parametry:** Linia pozioma ($Dy = 1$) lub linia pionowa ($Dx = 1$).
- **Wywołanie API `HmiDisplayBuilder`:**
  ```powershell
  $display.AddLine($x, $y, $w, 1, [HmiColor]::DarkGray)
  ```

### 2.4. Przycisk Dotykowy (Button)
Przycisk z fizycznym efektem wciśnięcia 3D (`Flat3D = 1`), który po dotknięciu przez operatora ustawia zadany bit w sterowniku PLC.

- **Identyfikacja:** `Type = 11`, `VarType = 0`, `[Binary] = NULL`.
- **Wymiary ergonomiczne:** Minimum $Dx \ge 40$ px, $Dy \ge 24$ px (rozmiar opuszka palca).
- **Wiązanie z PLC:** Wpis w tabeli `HMI_Operands` z typem `MB` (`OprndType = 1`) i rolą `FieldRole = 2` (Touch).
- **Wywołanie API `HmiDisplayBuilder`:**
  ```powershell
  $display.AddButton($x, $y, $w, $h, "START CYKLU", 22, [HmiColor]::White, [HmiColor]::Green)
  ```

### 2.5. Przycisk Nawigacyjny (NavButton dla Vision V350)
Służy do przełączania ekranów na panelu dotykowym.
- **Ważna uwaga V350:** Panele dotykowe V350 realizują nawigację wyłącznie poprzez dotykowy bit `MB` (`TouchOprndAddr`). Tabela `HMIJumps` **musi zawierać dokładnie 0 rekordów**!
- **Wywołanie API `HmiDisplayBuilder`:**
  ```powershell
  $display.AddNavButton($x, $y, $w, $h, "[ PROCES ]", 2, 210, [HmiColor]::White, [HmiColor]::Navy)
  ```

---

## 3. Katalog Dynamicznych Zmiennych Procesowych

### 3.1. Zmienna Numeryczna (Numeric Variable)
Wyświetla aktualną wartość liczbową z rejestru PLC (`MI`, `DW`, `ML`) lub otwiera wirtualną klawiaturę dotykową (Keypad) po dotknięciu.

- **Identyfikacja:** `Type = 5` (lub `8`), `VarType = 8`.
- **Struktura binarna:** Wymaga obiektu Property Bag o długości dokładnie **1740 bajtów** (`numeric_propertybag.bin`).
- **Tryby pracy:**
  - **Tylko odczyt (Read-Only PV):** `VarKeyPadEntry = 0`. Wyświetla pomiar bieżący.
  - **Edycja dotykowa (Keypad SP):** `VarKeyPadEntry = 1`. Po dotknięciu wyskakuje klawiatura alfanumeryczna VisiLogic.
- **Wiązanie z PLC:** Wpis w `HMI_Operands` z rolą `FieldRole = 1` (Value).
- **Wywołanie API `HmiDisplayBuilder`:**
  ```powershell
  # Odczyt temperatury bieżącej (MI0):
  $display.AddNumericVariable($x, $y, 60, 20, 0, $false, "MI 0", $numericBag, [HmiColor]::White, [HmiColor]::Navy)

  # Zadawanie nastawy temperatury SP z klawiatury dotykowej (MI31):
  $display.AddNumericVariable($x, $y, 60, 20, 31, $true, "SP 31", $numericBag, [HmiColor]::Black, [HmiColor]::White)
  ```

### 3.2. Dynamiczny Tekst Binarny (BinaryText)
Zmienia wyświetlany tekst oraz kolor tła i tekstu w zależności od logicznego stanu powiązanego bitu PLC (0 lub 1). Idealny dla statusów wentylatorów (STOP/RUN), grzałek (OFF/HEATING) czy awarii.

- **Identyfikacja:** `Type = 5`, `VarType = 2`.
- **Specyfikacja binarna V350:**
  - `FontNumber = 0`
  - `DescriptionFontNumber = 282392660`
  - `DefaultDisplay = 2`
  - `StrStorageOprndAddr = -1`
  - `StrStorageFont = 89352336`
- **Dynamiczne generowanie Property Bag:** Metoda pomocnicza tworzy strumień OLE Property Bag z tekstami i kolorami dla obu stanów:
  ```powershell
  $blob = [HmiDisplayBuilder]::CreateBinaryTextPropertyBag("STOP", [HmiColor]::Black, [HmiColor]::ButtonGray, "RUN", [HmiColor]::White, [HmiColor]::Green)
  $display.AddBinaryText($x, $y, 50, 18, [HmiOperandType]::Output, 3, $blob, [HmiColor]::Black, [HmiColor]::ButtonGray)
  ```

### 3.3. Wskaźnik Słupkowy (Bargraph)
Pionowy lub poziomy dynamiczny słupek analogowy pokazujący wysterowanie procentowe lub wartość pomiarową.

- **Identyfikacja:** `Type = 5`, `VarType = 24`.
- **Struktura binarna:** Property Bag o długości dokładnie **624 bajtów** (`bargraph_propertybag.bin`).
- **Powiązanie z PLC:** Rejestr `MI` (zakres 0..100% lub skalowany w PLC).
- **Wywołanie API `HmiDisplayBuilder`:**
  ```powershell
  $display.AddBargraph($x, $y, 22, 110, 0, "Bargraph_T", $bargraphBag)
  ```

### 3.4. Wskaźnik Zegarowy (Gauge)
Analogowy zegar ze wskazówką obrotową dla ciśnienia, przepływu lub prędkości.

- **Identyfikacja:** `Type = 5`, `VarType = 21`.
- **Struktura binarna:** Property Bag o długości dokładnie **1464 bajtów** (`gauge_propertybag.bin`).
- **Powiązanie z PLC:** Rejestr `MI`.
- **Wywołanie API `HmiDisplayBuilder`:**
  ```powershell
  $display.AddGauge($x, $y, 60, 60, 61, "VFD_Gauge", $gaugeBag)
  ```

### 3.5. Wizualizacja Zbiornika (Tank)
Model zbiornika z dynamicznym poziomem cieczy.

- **Identyfikacja:** `Type = 5`, `VarType = 25`.
- **Struktura binarna:** Property Bag o długości dokładnie **512 bajtów** (`tank_propertybag.bin`).
- **Powiązanie z PLC:** Rejestr `MI`.
- **Wywołanie API `HmiDisplayBuilder`:**
  ```powershell
  $display.AddTank($x, $y, 30, 80, 10, "Tank_Level", $tankBag)
  ```

### 3.6. Kontrolka Trendu w Czasie (Trend / `VarType = 23`)
- **Specyfika VisiLogic:** Kontrolka Trendu odwołuje się bezpośrednio do bazy projektu docelowego zapytaniem `SELECT Name FROM Trends WHERE TrendID=1`.
- **Rekomendacja architektoniczna:** Jeśli projekt docelowy użytkownika nie ma jeszcze wstępnie skonfigurowanego Trendu w drzewie `PLC -> Trends`, import strony z kontrolką `VarType = 23` wywoła błąd krytyczny *Run-time error 9: Subscript out of range*.
- **Najlepsza praktyka:** W gotowych bibliotekach ekranów zaleca się stosowanie zaawansowanych paneli synoptycznych z Bargraphami (`VarType = 24`), odczytami PV/SP oraz historią zapisaną w tabelach Data Tables.

---

## 4. Tabela Typów i Ról Operandów HMI (`HMI_Operands`)

| Kod Typu (`OprndType`) | Symbol | Opis typu rejestru PLC | Typowa rola na HMI |
|:---:|:---:|:---|:---|
| **`1`** | **MB** | Memory Bit (Bit pamięci) | Przyciski dotykowe (`Touch`), statusy binarne |
| **`2`** | **SB** | System Bit (Bit systemowy) | Zezwolenia, statusy pracy CPU |
| **`3`** | **MI** | Memory Integer (16-bit rejestr) | Pomiary temperatur, czasy, nastawy SP, bargraphy |
| **`4`** | **SI** | System Integer (16-bit systemowy)| Zegar czasu rzeczywistego (RTC), stan baterii |
| **`5`** | **ML** | Memory Long (32-bit rejestr) | Liczniki energii, duże wartości |
| **`9`** | **I** | Digital Input (Wejście cyfrowe) | Kontrolki statusu krańcówek, E-Stop |
| **`10`** | **O** | Digital Output (Wyjście cyfrowe)| Kontrolki statusu grzałek SSR, wentylatorów |
| **`16`** | **DW**| Double Word (32-bit bez znaku) | Liczniki czasu pracy motogodzin, receptury |

### Role Powiązania (`FieldRole`):
- **`FieldRole = 1` (Value):** Odczyt lub zapis wartości zmiennej procesowej (MI, DW, MB).
- **`FieldRole = 2` (Touch):** Operand dotykowy przycisku. Ustawiany w stan 1 w momencie naciśnięcia przycisku na ekranie dotykowym.

---

## 5. Tabela Kolorów Palety Unitronics Vision (`HmiColor`)

| Kod Koloru | Nazwa Koloru | Przeznaczenie w standardzie ANSI/ISA-101 |
|:---:|:---|:---|
| **`74`** | **Default Page Background** | Domyślne neutralne szare tło ekranu (brak odblasków) |
| **`103`** | **Light Gray** | Tła paneli grupujących, obramowania sekcji |
| **`104`** | **Button Gray** | Domyślny kolor przycisków w stanie spoczynkowym |
| **`68`** | **Dark Gray** | Ramki konturów, linie podziału, opisy nieaktywne |
| **`0`** | **Black** | Tekst podstawowy na jasnych tłach |
| **`5`** | **White** | Tekst kontrastowy na ciemnych tłach, tła pól edycyjnych SP |
| **`10`** | **Green** | **Stan Normalny / Praca**: Silnik pracuje, grzałka załączona |
| **`14`** | **Yellow** | **Ostrzeżenie (Warning)**: Drzwi otwarte, zbliżenie do limitu |
| **`2`** | **Red** | **Awaria / Alarm (Alarm)**: E-Stop, STB przegrzanie, błąd SSR |
| **`1`** | **Navy (Ciemnoniebieski)** | Paski tytułowe, nagłówki systemowe, przyciski nawigacyjne |
| **`11`** | **Cyan** | Statusy pomocnicze, wartości procesowe specjalne |
| **`13`** | **Orange** | Stan przejściowy, rozbieg falownika |
| **`-1`** | **Transparent** | Przezroczyste tło kontrolki |
