# Galaxian (Famicom, J REVA) — дизасембль для ca65

🇬🇧 [English version](README.en.md)

Дизасембль **Galaxian** (Namco, 1984, ревізія J REVA) для ca65/ld65. Результат збирається байт-у-байт
в оригінальний `Galaxian (J) (REVA) [!].nes`: `compare.bat` (`tools/compare.py`) відкидає падінг і порівнює заголовок,
PRG і CHR.

## ROM

ROM — це iNES NROM-128: 16 KB PRG + 8 KB CHR. Оригінальна гра має лише 8 KB PRG, тому перші 8 KB PRG
(файлові офсети `$0010–$200F`, CPU `$C000–$DFFF`) — це падінг `$FF`, доданий, щоб гра запускалась в емуляторах.
Код і дані гри — файлові офсети `$2010–$400F`, CPU `$E000–$FFFF`. Падінг створює лінкер (`config.cfg`, область `PAD`),
у вихідниках його немає.

## Збірка

```
assemble.bat        # або: make        -> galaxian.nes, galaxian.map, galaxian_labels.txt
compare.bat         # або: make check  -> IDENTICAL
make test           # check + lint_labels + reloc_test + selftest
```

Потрібні `ca65`/`ld65` у PATH і Python 3.

## Файли

| Файл | Що це |
|---|---|
| `src/main.asm` | точка входу: заголовок, модулі `prg/*.asm` по порядку, `chr.asm` |
| `src/prg/*.asm` | код і дані `$E000–$FFFF`, 18 модулів (`demo`, `flow`, `game`, `divers`, `player`, `background`, `attacks`, `hits`, `launcher`, `sound`, `util`, `bullets`, `steering`, `hud`, `title`, `text`, `reset`, `nmi`) |
| `src/defines.inc`, `src/ram.inc`, `src/const.inc` | регістри PPU/APU/джойпадів; мітки RAM; іменовані константи |
| `src/chr.asm` | CHR ROM: тайли (`.incbin`) і дизасембльовані дані гри — пісні 1–3, тексти, вказівники (`tools/chrdata.py`) |
| `src/chr/chr_0.chr`, `chr_1.chr` | таблиці шаблонів PPU `$0000` і `$1000` |
| `gfx/sheet_00.png` | CHR як 2-бітний PNG 128×256 (редагувати й імпортувати `chr_tool.py png2chr`) |
| `config.cfg` | ld65: HDR + PAD (`$C000`, FF) + PRG (`$E000`) + CHR |
| `galaxian.mlb` | мітки для Mesen (Debugger → Import labels) |
| `docs/coverage.txt` | звіт: скільки коду/даних, що знайшло трасування, таблиці, сирі операнди |
| `docs/xref.txt` | перехресні посилання підпрограм і RAM (+ дані профілювання Mesen) — `tools/xref.py` |
| `tools/labels/rom.txt`, `ram.txt`, `const.txt` | **імена й директиви** — сюди вносяться всі правки розмітки |

Коментар у кожному рядку `prg/*.asm`: `;CDJS 0xFILE ADDR: bytes`, де
`C` — код за CDL, `T` — код, знайдений статичним трасуванням (у CDL не потрапив), `D` — дані, прочитані за CDL,
`J` — ціль переходу, `S` — початок підпрограми.

## Інструменти (`tools/`)

- `disasm.py` — генератор: ROM + CDL (Mesen2 `CDLv2`) + `labels/*.txt` → `src/`, `config.cfg`, `.bat`, `galaxian.mlb`,
  `docs/coverage.txt`. **Перезаписує `src/`.** Після ручних правок у `src/*.asm` запускай його лише з `--out DIR`.
  Що робить: розбирає CDL, трасує незалоговані гілки від відомого коду, шукає `.word`-таблиці (у т.ч. інлайн-таблиці
  після `JSR JumpTableDispatch`), пари `#<label/#>label`, дає автоімена `sub_/loc_/dat_/tbl_/ram_/ptr_`.
  Внутрішні переходи (гілки/JMP, на які посилаються лише з тієї ж процедури) стають локальними мітками ca65
  `@loop`/`@skip`/`@rts` (`@loop` — є перехід назад). У `rom.txt` можна писати й власні імена `@name`: генератор
  перевіряє, що всі посилання лежать між тими самими двома глобальними мітками. У `galaxian.mlb` локальні мітки
  експортуються як `Процедура_loop2`, бо Mesen не знає області видимості ca65.
- `chr_tool.py` — `split` (ROM → `src/chr/*.chr` + PNG) і `png2chr` (PNG → `.chr`).
- `chrdata.py` — викликається з `disasm.py`: пише `src/chr.asm` з даними гри, що лежать у CHR (див. нижче).
- `lint_labels.py` — перевірка `labels/*.txt` (дублікати, вихід за `$E000–$FFFF`, перекриття code/data).
- `reloc_test.py` — лінкує PRG зі зсувом і перевіряє, що змінились лише адреси-операнди й таблиці
  (тобто в коді немає зашитих чисел-адрес; можна вставляти/видаляти байти).
- `selftest.py` — генерує у тимчасові каталоги з мітками й без них, перевіряє ідентичність і переміщуваність.
- `opcodes.py` — таблиця опкодів 6502 (з проєкту Mighty Final Fight).
- `xref.py` — звіт для іменування `docs/xref.txt`. Для кожної підпрограми показує, хто її викликає, кого вона
  викликає і яку RAM пише/читає. Для кожного байта RAM — хто його пише/читає. З `--logs DIR` додає дані з Mesen:
  скільки разів і в яких `gameMode` виконувався код, які значення писались у байт, хто звертався до нього через
  індекс (`formation,X`). `--unnamed` лишає тільки безіменне.
- `mesen/run_profile.py` + `mesen/profile.lua` — профілювання в Mesen 2 без GUI (`--testrunner`), по одному
  екземпляру за раз. Mesen копіюється в `--out DIR/mesen`, встановлений `mesen\` не змінюється. Бот проходить
  інтро → меню (1P/2P) → гру (пауза, смерть, game over) або демо й пише `.acc/.vals/.exec/.args/.trace` + скріншоти
  кожного нового `gameMode/gameSubMode` і кожного нового рівня (`_stageNN.png`). `.args` — значення A/X/Y на вході
  в кожну підпрограму (у `xref.txt` рядок `on entry`). Близько 100 кадрів/с поза грою; із записом аргументів ~30.

```
python tools/mesen/run_profile.py --out tmp/prof --frames 20000 --runs c1:7:1:20000:2500:700 c2:8:2:14000:0:900 demo:3:0:0:0:0
python tools/xref.py --logs tmp/prof [--unnamed]
```
`--runs` = `ім'я:seed:гравців(0 = лише демо):тримати_життя_до_кадру:кадр_паузи[:зачистка]`; `зачистка` = N — через
N кадрів хвилі бот обнуляє `formation` (`$C3–$CC`), щоб гра перейшла на наступний рівень (0 — вимкнено).

### Формат `tools/labels/rom.txt`

```
AAAA name [; comment]               мітка (CPU $E000-$FFFF)
code|data|words|rtswords AAAA-AAAA  примусова класифікація (rtswords: збережено адресу-1)
table AAAA-AAAA N [header]          таблиця по N байт у рядку; посилання всередину -> name+offset
text AAAA-AAAA                      ASCII-рядок, .byte "..."
split LO HI N [adj] [prefix]        роздільні lo/hi таблиці адрес на N елементів
imm AAAA AAAA                       операнди цих двох інструкцій = #<target / #>target
note AAAA ; text                    рядок-коментар перед рядком за адресою AAAA
bitskip AAAA                        BIT abs ($2C) перескакує 2-байтну інструкцію: AAAA = .byte OP_BIT_ABS,
                                    з AAAA+1 — прихована інструкція зі своєю міткою
module AAAA name [; опис]           з AAAA починається файл src/prg/name.asm (перший — з $E000)
dbyt AAAA-AAAA                      16-бітні числа big-endian: .dbyt $054D (періоди нот Music Player)
numwords AAAA-AAAA                  16-бітні числа (не адреси) little-endian: .word $013E (NotePeriod)
```

`ram.txt`: `ADDR NAME [SIZE] ; comment` (SIZE > 1 → `ADDR+n` друкується як `NAME+n`).

`const.txt` — імена для безпосередніх операндів (`CMP #$C8` → `CMP #SHOT_READY_Y`), потрапляють у `src/const.inc`:
```
NAME = EXPR [@var ...] [; comment]   константа; @var (RAM/регістр, можна name+N) - автозаміна там, де значення
                                     записують у var (LDx #v / STx var) або порівнюють з ним
                                     (LDx var / CMP|CPx|AND|ORA|EOR #v, і далі CMP через самі лише гілки)
use AAAA [AAAA ...] EXPR             операнд цих інструкцій = EXPR (генератор звіряє значення з байтом)
data AAAA EXPR[, EXPR ...] [; c]     байти даних від AAAA друкуються цими виразами (теж звіряються)
    ; продовження                    рядок-коментар з відступом одразу після NAME = ... продовжує його коментар
struct Name field[:size] ... [; c]  .struct у const.inc (поля — байти, якщо не :size)
array var Name                      RAM var — масив структур: var+N друкується як var+елемент+Name::поле
enum [; c] ... endenum              константи між ними стають анонімним .enum (імена лишаються глобальними)
```
EXPR — вираз ca65: `$hex %bin 'c'`, імена, `+ - * / & | ^ ~ << >>`, на початку `<`/`>` — молодший/старший байт
(`AND #<~PPUCTRL_INC32`, `LDA #>oamBuffer`). Значення однакове з різним змістом (0, 1, $10…) автоматично
не підставляється — лише за прив'язкою до змінної або явним `use`.

Розмірності виражено через базові константи, а не окремими числами (`LDX #(DIVER_SLOTS-1)*DIVER_OAM_SIZE`,
`CMP #FORMATION_RIGHT_X`, `LDA #<TEXT_PTR_BIAS`), тож зміна однієї константи в коді видна одразу.
Числами навмисно лишено тільки ідіоми: `#0`/`#1` для очищення, прапорця чи кроку, заперечення `EOR #$FF` + `ADC #1`,
старт циклу з −1 (`LDX #$FF` / `INX`) і номери секторів 0–6 у `DirectionFromDelta`. Позначка `(?)`
у коментарі означала б припущення; зараз таких немає — усі перевірено кодом.

### Дані в CHR (`src/chr.asm`)

`RESET` копіює дві ділянки CHR у RAM, тому вони дизасембльовані як `.org`-блоки з RAM-адресами (мітки
доступні з коду: `STA TxtPause+1`, `LDA songTable,X`):

- CHR `$098E–$0A3F` → RAM `$014E–$01FF`: `songTable` і пісні 1–3 (`TuneFlagshipHit`, `TuneAlienHit`,
  `TuneGameStart`). Байт ноти — `DUR_x | NOTE_y` (`const.txt`), `SONG_END` = `$FF`, перший байт пісні не грає.
  Стек тому живе нижче `$014E`.
- CHR `$1480–$17FF` → RAM `$0300–$067F`: `textPtrs` (35 вказівників) і записи текстів `Txt*`:
  `.byte рядок, стовпець, "ТЕКСТ", TEXT_END`. Символ = тайл + `'0'`; у шрифті `: ; < = > ?` — альтернативні
  цифри 1 2 4 7 8 9, `]` — ©, `CHAR_PTS` — «PTS». Логотип і рамка — сирі тайли (зсув 0). Тайли `$60–$6F`
  (`chrTiles`, RAM `$0480–$057F`) — справжня графіка всередині цієї ділянки.

Так оформлено: `.struct Sprite` для `oamBuffer` (`STA oamBuffer+4+Sprite::tile,Y` — тайл другого спрайта
слота; початок елемента, як `oamBuffer+128`, лишається без поля), `.enum` для `gameMode` (`MODE_*`),
`diverState` (`DIVER_*`) і `playerState` (`PLAYER_*`), `.dbyt` для `MusicSq1Period`/`MusicSq2Period`.

Робочий цикл: правиш `labels/*.txt` → `python tools/disasm.py --build` → `IDENTICAL`.

## Що відомо про гру

- **Вектори:** NMI = `$FDB1`, RESET = IRQ = `$FBC5`. Уся гра працює в NMI; розщеплення скролу між рядком
  статусу та полем зроблено таймінговими циклами (`$FE2D`, `$FE4F`), без sprite-0 hit.
- **Стан гри:** `GameModeDispatch` (`$FF64`) переходить за `gameMode` (`$FF`) через `JumpTableDispatch` (`$F36C`):
  підпрограма бере адресу повернення `JSR` як початок `.word`-таблиці. Підрежими — `gameSubMode` (`$FE`).
- **Дані в CHR ROM:** при старті `RESET` копіює PPU `$1480–$17FF` (CHR) у RAM `$0300–$067F` через `PPUDATA`
  (тексти, `textPtrs,Y` у `PrintText`), а `$098E–$0A3F` — у `$014E–$01FF` (пісні). Див. «Дані в CHR» вище.
- **Тепле скидання:** `$0105–$0114` містить «HARUHISA UDAGAWA» (`ResetSignature`, `$FBB5`); якщо після RESET підпис
  на місці, `resetCounter` (`$0115`) збільшується, інакше — холодний старт (`ColdBootInit`, `$FD3C`).
- **Прихований Music Player** (TCRF): `MusicPlayer` (`$F289`), викликається з NMI, коли `musicPlayerFlag` (`$0101`) ≠ 0.
  За TCRF вмикається (у REVA не працює — див. нижче): 44 скидання + A+B на джойпаді 2 + скидання (`$FDC9`: `resetCounter == $2D`), або 10 скидань і
  4 «крики» в мікрофон джойпада 2 (`ReadControllers`, `$F46E`: `$4016` біт 2, `micShoutCount`).
  Ноти — байти CHR, що читаються через `PPUDATA` (`mpVramHi`:`$00`): молодша тетрада — нота SQ1, старша — SQ2,
  періоди — `MusicSq1Period` (`$F34C`) і `MusicSq2Period` (`$F32C`), big-endian. Коли адреса доходить до кінця
  сторінки, плеєр чистить `$0100–$01FF` і перезапускає гру. Цей код відсутній у CDL — його знайшов трасувальник
  (рядки з прапорцем `T`).
- **GameHacking.org:** RAM-коди використано (`lives $42`, `stage $59`, `$44`, `$4F`, `$78D`); коди Game Genie
  з сайту (`SXEYUZVG`, `EIOYYGEY`, `AANNLTTZ`) не збігаються з байтами цієї ревізії (REVA) — ймовірно, вони для REV0.
- **Режими гри** (`GameModeTable`): 0 `IntroMode` (`$E0E7`), 1 `TitleMode` (`$F8BB`, меню 1P/2P — `menuSelect`),
  2 `DemoMode` (`$E000`, демо: ШІ `DemoAiInput` синтезує `curJoy`), 3 `GameMode` (`$E456`),
  4 `GameOverFlyIn` (`$FF81`: 8 спрайтів-літер «GAMEOVER» з випадкових місць злітаються до Y=`$A0` за `$3C` кадрів,
  `StartGameOverLetters` `$E2DD`), 5 `GameOverMode` (`$FFC7`, GAME OVER / кінець демо, `lives` як таймер,
  «шторка» `ScreenWipe`, повернення на титулку). `PlayModeIndex` (`$FF79`) = 3 — з ним порівнюють `gameMode` скрізь.
  Пауза — `pauseFlag` (`$4E`), обробляє `PauseOrGameMode` (`$FF18`) з NMI. Кроки всередині підрежиму — `subStep` (`$FD`).
- **Формація — це фон (BG), а не спрайти.** Зміни тайлів ідуть через чергу NMI `vramQueueHi/Lo/Tile1/Tile2`
  (`$0778/$0768/$0758/$0748`, до 16 записів за кадр, `vramQueueCount` `$E1`). Стовпці на перемальовку — кільце
  `eventQueue` (`$A0`). Корабель гравця теж на фоні: нижня частина екрана скролиться на `playerX`.
- **Пікіруючі прибульці** — 8 слотів по 4 спрайти (OAM `$0200 + slot*16`). Слот 0 — флагман, 1–2 — ескорт,
  7 — вибух прибульця, збитого у формації. Масиви `diver*` (`$06E8–$0747`), стан — `diverState`:
  1 `DiverPeelOff` (петля з формації), 2/7 `DiverDive` (пікірування, стрільба, зіткнення з кораблем),
  3/8 `DiverReenter` (вилетів за екран: ще раз пікірує, коли прибульців < 7, інакше повертається згори),
  4/9 `DiverRejoin`, 6 `DiverLoop` (розворот, коли формація порожня), 11 `DiverExplode`, 12 `DiverShowScore`
  (бонус флагмана: 150 сам, 200 / 300 з ескортом, 800 — якщо обидва ескорти збиті першими).
  `diverIsFlagship` (`$0708`) = `$60` для флагмана (це ще й зсув тайла). Напрямок `diverDir / 4` (0–`$18`) індексує
  таблиці `DirFrame`/`DirQuadrant`/`DirDx*`/`DirDy*` (`$F69A`). Стовпець 0 — лівий; `FlagshipAttackFromLeft`
  бере флагмана зі стовпця 3/4, `FlagshipAttackFromRight` — з 6/5.
- **Об'єкти руху** (`UpdateMotionSteps`, `$F381`): 24 об'єкти з дробовою швидкістю (`motionDir/Div/Num/Rem/Step`,
  `$0788–$07FF`): `motionRem += motionNum`, крок = частка від ділення на `motionDiv`, остача лишається — тобто
  швидкість `motionNum / motionDiv` пікселів за кадр. 0–6 — кулі ворогів, 9–15 / 16–22 — dx / dy слотів 0–6,
  23 — дрейф формації (`formationDir` `$079F`, `formationDx` `$07FF`).
- **Складність:** `difficulty` = min(stage, 7) на початку хвилі, потім +1 кожні 20 с (`difficultyTimer`).
  Атаки запускають `attackTimers` (`$5B`) за масками `DifficultyAttackMask`; флагман атакує за `flagshipAttackTimer`.
- **Гра:** кадр — `GameFrame` (`$E473`). Формація — 10 стовпців-бітмасок `formation` (`$C3–$CC`; біти 0–2 сині,
  3 фіолетові, 4 червоні, 5 флагман), у грі вдвох друга копія — `formationOther` (`$CD–$D6`), обмін — `SwapPlayers`.
  Пікіруючі прибульці — 8 слотів, автомат станів `diverState,X` (`$0738`) через `DiverStateDispatch` (`$E528`).
  Гравець — `playerX` (`$E4`), постріл — спрайт OAM `$0280` (`UpdatePlayerShot`), кулі ворогів — 7 спрайтів з `$0284`.
- **Рахунок:** BCD-цифри `scoreP1` (`$0117`), `hiScore` (`$0120`, 5000 після ввімкнення), `scoreP2` (`$0129`);
  додавання — `AddScore` (`$F754`), додаткове життя на 5000. Текст — `PrintText` (`$FB4F`), рядок `textBuf` (`$06BC`).
- **Звук:** `UpdateSound` (`$F089`), ефекти пострілу/вибуху, сирена пікірування, музика — `MusicChannelUpdate`
  (`$F130`) з таблицями `NotePeriod`/`NoteDuration`/`SongPtr`.
- **Музика:** байт ноти = індекс тривалості (`NoteDuration`, біти 7–5) << 5 | нота (`NotePeriod`, 0–`$1F`, `$1F` — пауза),
  `$FF` — кінець. Пісня 0 (додаткове життя) — у ROM (`SongData` `$F1CF`), пісні 1–3 — у CHR, копіюються в RAM
  `$014E–$01FF` разом з таблицею `songTable`. Звук пострілу має ваду (TCRF): `UpdateShotSound` після першого кроку
  одразу обнуляє `shotSound`.
- Позначок `(?)` у `labels/*.txt` не лишилось: усе підтверджено кодом і профілюванням у Mesen.
- **Трюк `BIT $xxxx`:** у `AddScore` (`$F768`) байт `$2C` перескакує `LDY #scoreP2+4-scoreArea` (`AddScoreP2`),
  тому в джерелі це `.byte OP_BIT_ABS` і окрема мітка для прихованої інструкції (директива `bitskip`).
- **Music Player у цій ревізії (REVA) недоступний.** Перевірено в Mesen (`tools/mesen/reset_trick.lua`): після
  44 скидань `resetCounter = $2C`; 45-те скидання з A+B на джойпаді 2 → watchdog у NMI (`resetCounter == $2D`) →
  `ResetKeepSignature`, але той пише в `musicPlayerFlag` (`$0101`) **0** (`LDA #$00 / STA $0101`), і гра вертається на
  титулку. Метод із мікрофоном закінчується тим самим `JMP ResetKeepSignature`. Якщо записати в `$0101` 1, NMI
  одразу викликає `MusicPlayer` щокадру. Тобто в REVA плеєр вимкнено одним байтом (`$FDE0`); ймовірно, в іншій
  ревізії там ненульове значення.
- Невикористане: запис 6 у `GameModeTable` (`UnusedGameMode6`, `$FF7C`), мертвий код `$F0EC`, кілька зайвих `RTS`.
