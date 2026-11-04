# Galaxian (Famicom, J REVA) — a disassembly for ca65

🇺🇦 [Українська версія (основна)](README.md)

A disassembly of **Galaxian** (Namco, 1984, revision J REVA) for ca65/ld65. The result assembles byte for byte into
the original `Galaxian (J) (REVA) [!].nes`: `compare.bat` (`tools/compare.py`) drops the padding and compares the
header, the PRG and the CHR.

## ROM

The ROM is an iNES NROM-128: 16 KB PRG + 8 KB CHR. The original game has only 8 KB of PRG, so the first 8 KB of PRG
(file offsets `$0010–$200F`, CPU `$C000–$DFFF`) are `$FF` padding, added so that the game runs in emulators.
The code and data of the game are at file offsets `$2010–$400F`, CPU `$E000–$FFFF`. The padding is created by the
linker (`config.cfg`, region `PAD`); it is not in the sources.

## Build

```
assemble.bat        # or: make        -> galaxian.nes, galaxian.map, galaxian_labels.txt
compare.bat         # or: make check  -> IDENTICAL
make test           # check + lint_labels + reloc_test + selftest
```

`ca65`/`ld65` in PATH and Python 3 are required.

## Files

| File | What it is |
|---|---|
| `src/main.asm` | entry point: header, the `prg/*.asm` modules in order, `chr.asm` |
| `src/prg/*.asm` | code and data of `$E000–$FFFF`, 18 modules (`demo`, `flow`, `game`, `divers`, `player`, `background`, `attacks`, `hits`, `launcher`, `sound`, `util`, `bullets`, `steering`, `hud`, `title`, `text`, `reset`, `nmi`) |
| `src/defines.inc`, `src/ram.inc`, `src/const.inc` | PPU/APU/joypad registers; RAM labels; named constants |
| `src/chr.asm` | CHR ROM: tiles (`.incbin`) and the disassembled game data — songs 1–3, texts, pointers (`tools/chrdata.py`) |
| `src/chr/chr_0.chr`, `chr_1.chr` | PPU pattern tables `$0000` and `$1000` |
| `gfx/sheet_00.png` | CHR as a 2-bit 128×256 PNG (edit it and import with `chr_tool.py png2chr`) |
| `config.cfg` | ld65: HDR + PAD (`$C000`, FF) + PRG (`$E000`) + CHR |
| `galaxian.mlb` | labels for Mesen (Debugger → Import labels) |
| `docs/coverage.txt` | report: how much code/data, what the tracer found, tables, raw operands |
| `docs/xref.txt` | cross references of subroutines and RAM (+ Mesen profiling data) — `tools/xref.py` |
| `tools/labels/rom.txt`, `ram.txt`, `const.txt` | **names and directives** — all markup edits go here |

Every line of `prg/*.asm` carries a comment `;CDJS 0xFILE ADDR: bytes`, where
`C` — code according to the CDL, `T` — code found by static tracing (missing from the CDL), `D` — data read according
to the CDL, `J` — jump target, `S` — start of a subroutine.

## Tools (`tools/`)

- `disasm.py` — the generator: ROM + CDL (Mesen2 `CDLv2`) + `labels/*.txt` → `src/`, `config.cfg`, `.bat`,
  `galaxian.mlb`, `docs/coverage.txt`. **Overwrites `src/`.** After hand edits of `src/*.asm` run it only with
  `--out DIR`. What it does: parses the CDL, traces branches the CDL does not cover from the known code, looks for
  `.word` tables (including inline tables after `JSR JumpTableDispatch`) and `#<label/#>label` pairs, and gives
  automatic names `sub_/loc_/dat_/tbl_/ram_/ptr_`. Internal jumps (branches/JMPs referenced only from the same
  procedure) become ca65 local labels `@loop`/`@skip`/`@rts` (`@loop` — there is a jump back). You can also write
  your own `@name` in `rom.txt`: the generator checks that all references lie between the same two global labels.
  In `galaxian.mlb` local labels are exported as `Procedure_loop2`, because Mesen does not know ca65 scopes.
- `compare.py` — compares the assembled ROM (with the padding) with the original dump (header, PRG, CHR).
- `chr_tool.py` — `split` (ROM → `src/chr/*.chr` + PNG) and `png2chr` (PNG → `.chr`).
- `chrdata.py` — called from `disasm.py`: writes `src/chr.asm` with the game data stored in CHR (see below).
- `lint_labels.py` — checks `labels/*.txt` (duplicates, addresses outside `$E000–$FFFF`, code/data overlaps, modules).
- `reloc_test.py` — links the PRG shifted and checks that only operand addresses and tables changed (i.e. there are
  no hard-coded address numbers in the code; bytes can be inserted/removed).
- `selftest.py` — generates into temporary directories with and without labels, checks identity and relocatability.
- `opcodes.py` — the 6502 opcode table (from the Mighty Final Fight project).
- `xref.py` — the naming report `docs/xref.txt`. For each subroutine: who calls it, whom it calls and which RAM it
  writes/reads. For each RAM byte: who writes/reads it. With `--logs DIR` it adds Mesen data: how many times and in
  which `gameMode` the code ran, which values were written to a byte, who accessed it through an index
  (`formation,X`). `--unnamed` keeps only what is still unnamed.
- `mesen/run_profile.py` + `mesen/profile.lua` — profiling in Mesen 2 without the GUI (`--testrunner`), one instance
  at a time. Mesen is copied to `--out DIR/mesen`; the installed `mesen\` is not touched. A bot plays through intro →
  menu (1P/2P) → game (pause, death, game over) or the demo and writes `.acc/.vals/.exec/.args/.trace` plus
  screenshots of every new `gameMode/gameSubMode` and every new stage (`_stageNN.png`). `.args` holds the A/X/Y values
  on entry to every subroutine (the `on entry` line in `xref.txt`). About 100 frames/s outside the game, ~30 with
  argument logging.

```
python tools/mesen/run_profile.py --out tmp/prof --frames 20000 --runs c1:7:1:20000:2500:700 c2:8:2:14000:0:900 demo:3:0:0:0:0
python tools/xref.py --logs tmp/prof [--unnamed]
```
`--runs` = `name:seed:players(0 = demo only):keep_lives_until_frame:pause_frame[:clear]`; `clear` = N — N frames into
a wave the bot zeroes `formation` (`$C3–$CC`) so that the game goes on to the next stage (0 — off).

### The format of `tools/labels/rom.txt`

```
AAAA name [; comment]               label (CPU $E000-$FFFF)
code|data|words|rtswords AAAA-AAAA  force a classification (rtswords: stored address = target-1)
table AAAA-AAAA N [header]          a table with N bytes per row; references into it become name+offset
text AAAA-AAAA                      ASCII string, .byte "..."
split LO HI N [adj] [prefix]        separate lo/hi address tables of N entries
imm AAAA AAAA                       the operands of these two instructions = #<target / #>target
note AAAA ; text                    a comment line printed before the line at AAAA
bitskip AAAA                        BIT abs ($2C) skips a 2-byte instruction: AAAA = .byte OP_BIT_ABS,
                                    AAAA+1 is the hidden instruction with a label of its own
module AAAA name [; description]    the file src/prg/name.asm starts at AAAA (the first one at $E000)
dbyt AAAA-AAAA                      16-bit numbers, big-endian: .dbyt $054D (Music Player note periods)
numwords AAAA-AAAA                  16-bit numbers (not addresses), little-endian: .word $013E (NotePeriod)
```

`ram.txt`: `ADDR NAME [SIZE] ; comment` (SIZE > 1 → `ADDR+n` is printed as `NAME+n`).

`const.txt` — names for immediate operands (`CMP #$C8` → `CMP #SHOT_READY_Y`); they end up in `src/const.inc`:
```
NAME = EXPR [@var ...] [; comment]   constant; @var (RAM/register, may be name+N) - automatic substitution where the
                                     value is stored into var (LDx #v / STx var) or compared with it
                                     (LDx var / CMP|CPx|AND|ORA|EOR #v, and later CMPs with only branches between)
use AAAA [AAAA ...] EXPR             the operand of these instructions = EXPR (the generator checks it against the byte)
data AAAA EXPR[, EXPR ...] [; c]     data bytes from AAAA on are printed as these expressions (also checked)
    ; continuation                   an indented comment line right after NAME = ... continues its comment
struct Name field[:size] ... [; c]  .struct in const.inc (fields are bytes unless :size)
array var Name                      RAM var is an array of structures: var+N is printed as var+element+Name::field
enum [; c] ... endenum              the constants between them become an anonymous .enum (names stay global)
```
EXPR is a ca65 expression: `$hex %bin 'c'`, names, `+ - * / & | ^ ~ << >>`, a leading `<`/`>` takes the low/high byte
(`AND #<~PPUCTRL_INC32`, `LDA #>oamBuffer`). The same value with a different meaning (0, 1, $10…) is not substituted
automatically — only through a binding to a variable or an explicit `use`.

Sizes are expressed through base constants rather than separate numbers (`LDX #(DIVER_SLOTS-1)*DIVER_OAM_SIZE`,
`CMP #FORMATION_RIGHT_X`, `LDA #<TEXT_PTR_BIAS`), so changing one constant is visible everywhere in the code at once.
Only idioms are deliberately left as numbers: `#0`/`#1` for clearing, a flag or a step, negation `EOR #$FF` + `ADC #1`,
a loop that starts at −1 (`LDX #$FF` / `INX`) and the sector numbers 0–6 in `DirectionFromDelta`. A `(?)` in a comment
would mark an assumption; there are none now — everything has been checked against the code.

### Data in CHR (`src/chr.asm`)

`RESET` copies two CHR ranges into RAM, so they are disassembled as `.org` blocks with RAM addresses (the labels are
usable from the code: `STA TxtPause+1`, `LDA songTable,X`):

- CHR `$098E–$0A3F` → RAM `$014E–$01FF`: `songTable` and songs 1–3 (`TuneFlagshipHit`, `TuneAlienHit`,
  `TuneGameStart`). A note byte is `DUR_x | NOTE_y` (`const.txt`), `SONG_END` = `$FF`, the first byte of a song is not
  played. That is why the stack lives below `$014E`.
- CHR `$1480–$17FF` → RAM `$0300–$067F`: `textPtrs` (35 pointers) and the text records `Txt*`:
  `.byte row, column, "TEXT", TEXT_END`. A character is tile + `'0'`; in the font `: ; < = > ?` are the alternative
  digits 1 2 4 7 8 9, `]` is ©, `CHAR_PTS` is "PTS". The logo and the border are raw tiles (bias 0). The tiles
  `$60–$6F` (`chrTiles`, RAM `$0480–$057F`) are real graphics inside this range.

Also used: `.struct Sprite` for `oamBuffer` (`STA oamBuffer+4+Sprite::tile,Y` — the tile of the second sprite of a slot;
the start of an element, like `oamBuffer+128`, stays without a field), `.enum` for `gameMode` (`MODE_*`),
`diverState` (`DIVER_*`) and `playerState` (`PLAYER_*`), `.dbyt` for `MusicSq1Period`/`MusicSq2Period`.

Work cycle: edit `labels/*.txt` → `python tools/disasm.py --build` → `IDENTICAL`.

## What is known about the game

- **Vectors:** NMI = `$FDB1`, RESET = IRQ = `$FBC5`. The whole game runs in the NMI; the scroll split between the
  status row and the playfield is done with timing loops (`$FE2D`, `$FE4F`), without a sprite-0 hit.
- **Game state:** `GameModeDispatch` (`$FF64`) jumps by `gameMode` (`$FF`) through `JumpTableDispatch` (`$F36C`): the
  subroutine takes the return address of the `JSR` as the start of a `.word` table. Sub-modes — `gameSubMode` (`$FE`).
- **Data in CHR ROM:** at start `RESET` copies PPU `$1480–$17FF` (CHR) into RAM `$0300–$067F` through `PPUDATA`
  (texts, `textPtrs,Y` in `PrintText`), and `$098E–$0A3F` into `$014E–$01FF` (songs). See "Data in CHR" above.
- **Warm reset:** `$0105–$0114` holds "HARUHISA UDAGAWA" (`ResetSignature`, `$FBB5`); if the signature is in place
  after RESET, `resetCounter` (`$0115`) is incremented, otherwise it is a cold start (`ColdBootInit`, `$FD3C`).
- **Hidden Music Player** (TCRF): `MusicPlayer` (`$F289`), called from the NMI when `musicPlayerFlag` (`$0101`) ≠ 0.
  According to TCRF it is enabled (it does not work in REVA — see below) by 44 resets + A+B on joypad 2 + a reset
  (`$FDC9`: `resetCounter == $2D`), or by 10 resets and 4 "shouts" into the microphone of joypad 2
  (`ReadControllers`, `$F46E`: `$4016` bit 2, `micShoutCount`). The notes are CHR bytes read through `PPUDATA`
  (`mpVramHi`:`$00`): the low nibble is the SQ1 note, the high nibble the SQ2 note, the periods are in
  `MusicSq1Period` (`$F34C`) and `MusicSq2Period` (`$F32C`), big-endian. When the address reaches the end of the page
  the player clears `$0100–$01FF` and restarts the game. This code is absent from the CDL — the tracer found it
  (lines with the flag `T`).
- **GameHacking.org:** the RAM codes were used (`lives $42`, `stage $59`, `$44`, `$4F`, `$78D`); the Game Genie codes
  from the site (`SXEYUZVG`, `EIOYYGEY`, `AANNLTTZ`) do not match the bytes of this revision (REVA) — probably they
  are for REV0.
- **Game modes** (`GameModeTable`): 0 `IntroMode` (`$E0E7`), 1 `TitleMode` (`$F8BB`, the 1P/2P menu — `menuSelect`),
  2 `DemoMode` (`$E000`, the demo: the AI `DemoAiInput` synthesizes `curJoy`), 3 `GameMode` (`$E456`),
  4 `GameOverFlyIn` (`$FF81`: 8 letter sprites of "GAMEOVER" fly in from random places to Y=`$A0` in `$3C` frames,
  `StartGameOverLetters` `$E2DD`), 5 `GameOverMode` (`$FFC7`, GAME OVER / end of the demo, `lives` as a timer, the
  `ScreenWipe` curtain, return to the title). `PlayModeIndex` (`$FF79`) = 3 — `gameMode` is compared with it
  everywhere. Pause — `pauseFlag` (`$4E`), handled by `PauseOrGameMode` (`$FF18`) in the NMI. Steps inside a
  sub-mode — `subStep` (`$FD`).
- **The formation is background (BG), not sprites.** Tile changes go through the NMI queue
  `vramQueueHi/Lo/Tile1/Tile2` (`$0778/$0768/$0758/$0748`, up to 16 entries per frame, `vramQueueCount` `$E1`).
  Columns to redraw are a ring buffer `eventQueue` (`$A0`). The player's ship is on the background too: the lower
  part of the screen is scrolled by `playerX`.
- **Divers** — 8 slots of 4 sprites (OAM `$0200 + slot*16`). Slot 0 is the flagship, 1–2 are escorts, 7 is the
  explosion of an alien shot in the formation. Arrays `diver*` (`$06E8–$0747`), state — `diverState`:
  1 `DiverPeelOff` (a loop out of the formation), 2/7 `DiverDive` (diving, shooting, collision with the ship),
  3/8 `DiverReenter` (left the screen: dives again when fewer than 7 aliens are left, otherwise returns from the top),
  4/9 `DiverRejoin`, 6 `DiverLoop` (a turn when the formation is empty), 11 `DiverExplode`, 12 `DiverShowScore`
  (flagship bonus: 150 alone, 200 / 300 with escorts, 800 if both escorts were shot first).
  `diverIsFlagship` (`$0708`) = `$60` for the flagship (also the tile offset). The direction `diverDir / 4`
  (0–`$18`) indexes the tables `DirFrame`/`DirQuadrant`/`DirDx*`/`DirDy*` (`$F69A`). Column 0 is the left one;
  `FlagshipAttackFromLeft` takes the flagship from column 3/4, `FlagshipAttackFromRight` from 6/5.
- **Motion objects** (`UpdateMotionSteps`, `$F381`): 24 objects with a fractional speed
  (`motionDir/Div/Num/Rem/Step`, `$0788–$07FF`): `motionRem += motionNum`, the step is the quotient of the division
  by `motionDiv`, the remainder stays — so the speed is `motionNum / motionDiv` pixels per frame. 0–6 are enemy
  bullets, 9–15 / 16–22 are dx / dy of slots 0–6, 23 is the formation drift (`formationDir` `$079F`,
  `formationDx` `$07FF`).
- **Difficulty:** `difficulty` = min(stage, 7) at the start of a wave, then +1 every 20 s (`difficultyTimer`).
  Attacks are launched by `attackTimers` (`$5B`) with the masks `DifficultyAttackMask`; the flagship attacks by
  `flagshipAttackTimer`.
- **Game:** a frame is `GameFrame` (`$E473`). The formation is 10 column bit masks `formation` (`$C3–$CC`; bits 0–2
  blue, 3 purple, 4 red, 5 flagship); in a two-player game the other copy is `formationOther` (`$CD–$D6`), swapped by
  `SwapPlayers`. Divers are 8 slots with a state machine `diverState,X` (`$0738`) through `DiverStateDispatch`
  (`$E528`). The player is `playerX` (`$E4`), the shot is the OAM sprite `$0280` (`UpdatePlayerShot`), enemy bullets
  are 7 sprites from `$0284`.
- **Score:** BCD digits `scoreP1` (`$0117`), `hiScore` (`$0120`, 5000 after power-on), `scoreP2` (`$0129`); adding —
  `AddScore` (`$F754`), an extra life at 5000. Text — `PrintText` (`$FB4F`), the row `textBuf` (`$06BC`).
- **Sound:** `UpdateSound` (`$F089`), shot/explosion effects, the diving siren, music — `MusicChannelUpdate`
  (`$F130`) with the tables `NotePeriod`/`NoteDuration`/`SongPtr`.
- **Music:** a note byte = duration index (`NoteDuration`, bits 7–5) << 5 | note (`NotePeriod`, 0–`$1F`, `$1F` is a
  rest), `$FF` is the end. Song 0 (extra life) is in the ROM (`SongData` `$F1CF`), songs 1–3 are in CHR, copied into
  RAM `$014E–$01FF` together with the table `songTable`. The shot sound has a flaw (TCRF): after the first step
  `UpdateShotSound` zeroes `shotSound` at once.
- There are no `(?)` marks left in `labels/*.txt`: everything was confirmed by the code and by profiling in Mesen.
- **The `BIT $xxxx` trick:** in `AddScore` (`$F768`) the byte `$2C` skips `LDY #scoreP2+4-scoreArea`
  (`AddScoreP2`), so in the source it is `.byte OP_BIT_ABS` and a separate label for the hidden instruction (the
  `bitskip` directive).
- **The Music Player is unavailable in this revision (REVA).** Checked in Mesen (`tools/mesen/reset_trick.lua`): after
  44 resets `resetCounter = $2C`; the 45th reset with A+B on joypad 2 → the watchdog in the NMI
  (`resetCounter == $2D`) → `ResetKeepSignature`, but it writes **0** to `musicPlayerFlag` (`$0101`)
  (`LDA #$00 / STA $0101`), and the game returns to the title. The microphone method ends with the same
  `JMP ResetKeepSignature`. If 1 is written to `$0101`, the NMI calls `MusicPlayer` every frame at once. So in REVA
  the player is disabled by a single byte (`$FDE0`); probably another revision has a non-zero value there.
- Unused: entry 6 of `GameModeTable` (`UnusedGameMode6`, `$FF7C`), the dead code at `$F0EC`, a few extra `RTS`.
