; Galaxian (J) (REVA) - ca65 disassembly. Build: assemble.bat (or make)

.include "defines.inc"
.include "ram.inc"
.include "const.inc"

.segment "HEADER"
  .incbin "../header.bin"

; CPU $C000-$DFFF: 8KB of $FF padding of the assembled ROM (filled by the linker, see config.cfg)

; PRG ROM, CPU $E000-$FFFF (8KB), split into src/prg/*.asm (module lines in tools/labels/rom.txt).
; Line comments: flags C = code (CDL), T = code found by static tracing, D = data read (CDL),
;   J = jump target, S = subroutine entry; then file offset, CPU address, bytes.
; Data that neither the CDL nor the tracer reached is marked "unknown".
.segment "PRG"
.include "prg/demo.asm"         ; $E000 attract-mode AI
.include "prg/flow.asm"         ; $E0E7 intro, new game, death, player swap, game over, spawn, wave setup, scores
.include "prg/game.asm"         ; $E456 game frame, wave end, pause
.include "prg/divers.asm"       ; $E510 diver state machine, metasprites, bullets fired by divers, dive aiming
.include "prg/player.asm"       ; $EA20 ship movement
.include "prg/background.asm"   ; $EA45 formation flapping, VRAM tile queue, stars
.include "prg/attacks.asm"      ; $EBCC flagship and diver launches, peel-off, formation bounce
.include "prg/hits.asm"         ; $EE12 player shot vs formation and divers, kills, scoring
.include "prg/launcher.asm"     ; $EF74 attack timers, difficulty, alien count
.include "prg/sound.asm"        ; $F077 sound effects, music, hidden Music Player
.include "prg/util.asm"         ; $F36C jump tables, motion steps, VRAM rows, controllers
.include "prg/bullets.asm"      ; $F4DB enemy bullets and the player shot
.include "prg/steering.asm"     ; $F57F diver direction, sprite frame/flip, motion tables
.include "prg/hud.asm"          ; $F730 score adding, lives, stage flags
.include "prg/title.asm"        ; $F817 intro text, title scroll, menu, story, score table, screen wipe
.include "prg/text.asm"         ; $FB43 text printer, copyright
.include "prg/reset.asm"        ; $FBB5 RESET, cold boot, palette, attributes
.include "prg/nmi.asm"          ; $FDB1 NMI, game mode dispatch, game over, vectors

.include "chr.asm"
