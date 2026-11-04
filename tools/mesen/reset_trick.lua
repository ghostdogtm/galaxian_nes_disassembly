-- Galaxian (J REVA): TCRF method 1 for the hidden music player, headless in Mesen 2 (--testrunner).
-- Resets the game 44 times, holds A+B on controller 2 and resets again; logs RESET / watchdog / $0101 / MusicPlayer.
-- Mesen ignores emu.setInput on port 2 in this setup, so A+B is faked in the $4017 reads.
-- Prepend the config and run with a Mesen copy (see run_profile.py setup), one instance at a time:
--   OUT = [[C:\path\prefix]]   -- writes <OUT>.log and <OUT>_N.png
--   PATCH = true               -- optional: store 1 in $0101 after ResetKeepSignature clears it
--   Mesen.exe --testrunner "galaxian.nes" script.lua --timeout=280
-- Result on REVA: the watchdog takes ResetKeepSignature (resetCounter $2D, joy2 = $C0), which writes 0 to $0101,
-- so the title screen comes back. With PATCH the NMI runs MusicPlayer every frame.
local MT = emu.memType.nesMemory
local log = io.open(OUT .. ".log", "w")
local function L(s) log:write(s .. "\n") log:flush() end
local frame, resets, phase, wait = 0, 0, "boot", 60
local holdAB = false
local function st() local s = emu.getState() return s["cpu.pc"], s["cpu.sp"], s["cpu.a"] end

emu.addMemoryCallback(function(a, v)
  local pc, sp = st()
  L(string.format("f%d write $0101 = %02X  (pc %04X sp %02X)", frame, v, pc or 0, sp or 0))
end, emu.callbackType.write, 0x0101, 0x0101, emu.cpuType.nes, MT)

local watch = { [0xFBC5]="RESET", [0xFDD4]="NmiWatchdogReset", [0xFDDF]="ResetKeepSignature",
  [0xFDF2]="ResetCold", [0xF289]="MusicPlayer", [0xFC03]="cold path (ColdBootInit)" }
local seenMP = 0
for addr, name in pairs(watch) do
  emu.addMemoryCallback(function()
    if addr == 0xF289 then seenMP = seenMP + 1 if seenMP > 3 then return end end
    local pc, sp, a = st()
    L(string.format("f%d %s  sp %02X a %02X resetCounter %02X $0101 %02X", frame, name, sp or 0, a or 0,
      emu.read(0x115, MT), emu.read(0x101, MT)))
  end, emu.callbackType.exec, addr, addr, emu.cpuType.nes, MT)
end

local function setIn() for p = 1, 4 do emu.setInput({ a = holdAB, b = holdAB }, p) end end
emu.addEventCallback(setIn, emu.eventType.inputPolled)
-- Mesen ignores setInput on port 2 here: fake the $4017 serial bits instead (bit 0 = A, B, Select, Start, ...)
local bit2 = 0
emu.addMemoryCallback(function(a, v) if v & 1 == 0 then bit2 = 0 end end,
  emu.callbackType.write, 0x4016, 0x4016, emu.cpuType.nes, MT)
emu.addMemoryCallback(function(a, v)
  bit2 = bit2 + 1
  if holdAB and bit2 <= 2 then return (v & 0xFE) | 1 end
  return v
end, emu.callbackType.read, 0x4017, 0x4017, emu.cpuType.nes, MT)
emu.addEventCallback(setIn, emu.eventType.startFrame)
emu.addEventCallback(setIn, emu.eventType.reset)
emu.addMemoryCallback(function()
  if holdAB then L(string.format("f%d watchdog: joy2 = %02X", frame, emu.read(0xF1, MT))) end
end, emu.callbackType.exec, 0xFDD7, 0xFDD7, emu.cpuType.nes, MT)

-- experiment: what if ResetKeepSignature stored a nonzero value (as LDA #$01 would)?
emu.addMemoryCallback(function()
  if PATCH then emu.write(0x0101, 1, MT) L(string.format("f%d PATCH: $0101 = 01", frame)) end
end, emu.callbackType.exec, 0xFDE4, 0xFDE4, emu.cpuType.nes, MT)
local shots = 0
emu.addEventCallback(function()
  frame = frame + 1
  wait = wait - 1
  if wait > 0 then return end
  if phase == "boot" or phase == "resetting" then
    if resets < 44 then
      resets = resets + 1
      phase = "resetting"
      emu.reset()
      wait = 30
    else
      phase = "ab"
      holdAB = true
      L(string.format("f%d joy2 now %02X", frame, emu.read(0xF1, MT)))
      L(string.format("f%d 44 resets done, resetCounter %02X; holding A+B on pad 2 and resetting", frame, emu.read(0x115, MT)))
      wait = 10
    end
  elseif phase == "ab" then
    phase = "after"
    L(string.format("f%d before reset: joy2 = %02X", frame, emu.read(0xF1, MT)))
    emu.reset()
    wait = 120
  elseif phase == "after" then
    shots = shots + 1
    local g = io.open(OUT .. "_" .. shots .. ".png", "wb") g:write(emu.takeScreenshot()) g:close()
    L(string.format("f%d screenshot %d: $0101 %02X resetCounter %02X MusicPlayer calls %d", frame, shots,
      emu.read(0x101, MT), emu.read(0x115, MT), seenMP))
    wait = 300
    if shots >= 6 then log:close() emu.stop(0) end
  end
end, emu.eventType.endFrame)
