-- Galaxian (J REVA): headless RAM/code profiler for Mesen 2 (--testrunner).
--
-- tools/mesen/run_profile.py prepends a global table CFG to a copy of this script:
--   out      absolute path prefix of the output files
--   frames   number of frames to run
--   seed     seed of the random bot
--   players  1 or 2 (Select on the title menu picks 2 players); 0 = never press Start (title and demo only)
--   lives    keep lives >= 2 until this frame (0 = never), afterwards the bot may lose the game
--   pause    frame of play at which Start pauses the game for 120 frames (0 = never)
--   shots    take a screenshot the first time each gameMode / gameSubMode pair and each stage is seen
--   clear    after this many frames of a wave, empty the formation (0 = never) so that later stages are reached
--   entries  list of routine entry addresses: log the distinct A/X/Y values on entry
--
-- Output:
--   <out>.acc    "R|W pc addr count": RAM accesses by instruction (pc = instruction start)
--   <out>.vals   "addr writes changes min max ndistinct v1 v2 ...": values written to each RAM byte
--   <out>.exec   "pc count modes": executed instructions, modes = bit mask of gameMode values
--   <out>.trace  gameMode / gameSubMode / stage / lives changes with the frame number
--   <out>.args   "pc A=n:v,v X=n:v,v Y=n:v,v": distinct register values on entry to each routine (CFG.entries)
--   <out>_MM_SS.png, <out>_stageNN.png  screenshots (CFG.shots)

local MT = emu.memType.nesMemory
local RAM_MODE, RAM_SUB, RAM_STAGE, RAM_LIVES, RAM_FORMATION = 0xFF, 0xFE, 0x59, 0x42, 0xC3

local rng = (CFG.seed or 1) % 2147483647
if rng == 0 then rng = 1 end
local function rand(n)
  rng = (rng * 48271) % 2147483647
  return rng % n
end

-- instruction tracking ---------------------------------------------------------------------------------------------------
local pc, modeBit = 0, 1
local execN, execModes = {}, {}
emu.addMemoryCallback(function(a)
  pc = a
  execN[a] = (execN[a] or 0) + 1
  execModes[a] = (execModes[a] or 0) | modeBit
end, emu.callbackType.exec, 0xE000, 0xFFFF, emu.cpuType.nes, MT)

local rd, wr = {}, {}
local wN, wChg, wMin, wMax, wVals, last = {}, {}, {}, {}, {}, {}
emu.addMemoryCallback(function(a)
  local k = pc * 2048 + a
  rd[k] = (rd[k] or 0) + 1
end, emu.callbackType.read, 0x0000, 0x07FF, emu.cpuType.nes, MT)
emu.addMemoryCallback(function(a, v)
  local k = pc * 2048 + a
  wr[k] = (wr[k] or 0) + 1
  wN[a] = (wN[a] or 0) + 1
  if last[a] ~= v then wChg[a] = (wChg[a] or 0) + 1 end
  last[a] = v
  if not wMin[a] or v < wMin[a] then wMin[a] = v end
  if not wMax[a] or v > wMax[a] then wMax[a] = v end
  local s = wVals[a]
  if not s then s = {} wVals[a] = s end
  s[v] = true
end, emu.callbackType.write, 0x0000, 0x07FF, emu.cpuType.nes, MT)

-- bot ----------------------------------------------------------------------------------------------------------------------
local frame, playFrame = 0, 0
local held, heldLeft = {}, 0
local selectDone = false
local pauseLeft = -1

local function pickInput()
  local b = {}
  local mode = emu.read(RAM_MODE, MT)
  if mode == 3 then
    playFrame = playFrame + 1
    if heldLeft <= 0 then
      held = {}
      local r = rand(100)
      if r < 40 then held.left = true elseif r < 80 then held.right = true end
      heldLeft = 5 + rand(40)
    end
    heldLeft = heldLeft - 1
    for k, v in pairs(held) do b[k] = v end
    if rand(3) == 0 then b.a = true end
    if CFG.pause and CFG.pause > 0 then
      if playFrame == CFG.pause then b = { start = true } pauseLeft = 120 end
      if pauseLeft > 0 then pauseLeft = pauseLeft - 1 if pauseLeft == 0 then b = { start = true } end end
    end
  elseif mode == 1 and CFG.players > 0 then
    -- title menu (gameSubMode 2): Select/Start must be held for 3 frames (menuHoldTimer); Select = 1P/2P
    if emu.read(RAM_SUB, MT) == 2 then
      local t = frame % 40
      if CFG.players == 2 and not selectDone then
        if t < 6 then b.select = true elseif t == 6 then selectDone = true end
      elseif t >= 20 and t < 26 then
        b.start = true
      end
    end
  end
  return b
end

emu.addEventCallback(function()
  emu.setInput(pickInput(), 0)
end, emu.eventType.inputPolled)

-- per frame ----------------------------------------------------------------------------------------------------------------
local trace = io.open(CFG.out .. ".trace", "w")
local seen = {}
local lastKey = ""
local waveStage, waveFrames = -1, 0

-- routine entries (CFG.entries, list of CPU addresses): distinct A / X / Y values on entry
local args = {}
for _, e in ipairs(CFG.entries or {}) do
  local t = { a = {}, x = {}, y = {} }
  args[e] = t
  emu.addMemoryCallback(function()
    local s = emu.getState()
    t.a[s["cpu.a"]] = true
    t.x[s["cpu.x"]] = true
    t.y[s["cpu.y"]] = true
  end, emu.callbackType.exec, e, e, emu.cpuType.nes, MT)
end

local function setStr(set)
  local v = {}
  for k in pairs(set) do v[#v + 1] = k end
  table.sort(v)
  local o = {}
  for i = 1, #v do o[i] = string.format("%02X", v[i]) end
  return #v .. ":" .. table.concat(o, ",")
end

local function finish()
  local f = io.open(CFG.out .. ".acc", "w")
  for k, n in pairs(rd) do f:write(string.format("R %04X %03X %d\n", k // 2048, k % 2048, n)) end
  for k, n in pairs(wr) do f:write(string.format("W %04X %03X %d\n", k // 2048, k % 2048, n)) end
  f:close()
  f = io.open(CFG.out .. ".vals", "w")
  for a = 0, 0x7FF do
    if wN[a] then
      local vals = {}
      for v in pairs(wVals[a]) do vals[#vals + 1] = v end
      table.sort(vals)
      local shown = {}
      for i = 1, math.min(#vals, 24) do shown[i] = string.format("%02X", vals[i]) end
      f:write(string.format("%03X %d %d %02X %02X %d %s\n", a, wN[a], wChg[a] or 0, wMin[a], wMax[a], #vals,
        table.concat(shown, " ")))
    end
  end
  f:close()
  f = io.open(CFG.out .. ".exec", "w")
  for a, n in pairs(execN) do f:write(string.format("%04X %d %X\n", a, n, execModes[a])) end
  f:close()
  f = io.open(CFG.out .. ".args", "w")
  for e, t in pairs(args) do
    if next(t.a) then f:write(string.format("%04X A=%s X=%s Y=%s\n", e, setStr(t.a), setStr(t.x), setStr(t.y))) end
  end
  f:close()
  trace:close()
  emu.stop(0)
end

emu.addEventCallback(function()
  frame = frame + 1
  local mode, sub = emu.read(RAM_MODE, MT), emu.read(RAM_SUB, MT)
  modeBit = 1 << (mode & 15)
  local key = string.format("mode=%d sub=%d stage=%d lives=%d", mode, sub, emu.read(RAM_STAGE, MT), emu.read(RAM_LIVES, MT))
  if key ~= lastKey then
    trace:write(string.format("%d %s\n", frame, key))
    lastKey = key
  end
  local sk = mode * 256 + sub
  if CFG.shots and not seen[sk] then
    seen[sk] = frame + 20 -- a little later, after the screen was drawn
  end
  for k, at in pairs(seen) do
    if at == frame then
      local name = k >= 0x10000 and string.format("%s_stage%02d.png", CFG.out, k - 0x10000)
        or string.format("%s_%02X_%02X.png", CFG.out, k // 256, k % 256)
      local g = io.open(name, "wb")
      g:write(emu.takeScreenshot())
      g:close()
    end
  end
  if CFG.lives and frame < CFG.lives and mode == 3 and emu.read(RAM_LIVES, MT) < 2 then
    emu.write(RAM_LIVES, 2, MT)
  end
  -- wave clear: after CFG.clear frames of a wave empty the formation, so the next stages are reached
  local stage = emu.read(RAM_STAGE, MT)
  if stage ~= waveStage then
    waveStage, waveFrames = stage, 0
    if CFG.shots and not seen[0x10000 + stage] then seen[0x10000 + stage] = frame + 200 end
  end
  if mode == 3 then waveFrames = waveFrames + 1 end
  if CFG.clear and CFG.clear > 0 and mode == 3 and waveFrames == CFG.clear then
    for a = RAM_FORMATION, RAM_FORMATION + 9 do emu.write(a, 0, MT) end
    trace:write(string.format("%d formation cleared\n", frame))
  end
  if frame >= CFG.frames then finish() end
end, emu.eventType.endFrame)
