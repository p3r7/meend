local musicutil = require("musicutil")
local FilterGraph = require "filtergraph"
local ControlSpec = require "controlspec"
local Formatters = require "formatters"

local NoteSpiral = include('lib/note_spiral')


-- ------------------------------------------------------------------------
-- consts

SPIRAL_H = 60
SPIRAL_W = SPIRAL_H
SPIRAL_X = 34
SPIRAL_Y = 2

VOICES = 6


-- ------------------------------------------------------------------------
-- state

ns = nil

chords = {}
timer = nil

local slew_tick = 0.01
local slew_time = 0.5

local chord_time = 5

target_volts = {0, 0, 0, 0, 0, 0}
current_volts = {0, 0, 0, 0, 0, 0}
slew_volt_steps = {0, 0, 0, 0, 0, 0}

target_a = {0, 0, 0, 0, 0, 0}
current_a = {0, 0, 0, 0, 0, 0}
slew_a_steps = {0, 0, 0, 0, 0, 0}


-- ------------------------------------------------------------------------
-- main

function init()
  screen.aa(1)
  screen.line_width(1)

  crow.ii.jf.play_voice(0, 0, 0)
  crow.ii.jf.mode(1)

  local scale = musicutil.generate_scale(60, "major", 7) -- NB: 60 is a C

  local roman_numerals = {"I", "ii", "iii", "IV", "V", "vi"}

  for _, numeral in ipairs(roman_numerals) do
    for i = 1, #scale - 1 do
      table.insert(chords, musicutil.generate_chord_roman(scale[i], "Major", numeral))
    end
  end

  ns = NoteSpiral.new(SPIRAL_X, SPIRAL_Y, SPIRAL_W, SPIRAL_H, 1)

  timer = metro.init()
  timer.time = chord_time
  timer.event = play_chord
  timer:start()

  play_chord()

  clock.run(function()
      while true do
        clock.sleep(slew_tick)
        for i, target_volt in ipairs(target_volts) do

          if math.abs(current_volts[i] - target_volt) > math.abs(slew_volt_steps[i]) then
            current_volts[i] = current_volts[i] + slew_volt_steps[i]
          else
            current_volts[i] = target_volt
          end
          crow.ii.jf.pitch(i, current_volts[i])

          -- ns.notes[i] = (current_volts[i] * 12) + 60
          ns.notes[i] = (current_volts[i] +5) * 12

          if math.abs(current_a[i] - target_a[i]) > math.abs(slew_a_steps[i]) then
            current_a[i] = current_a[i] + slew_a_steps[i]
          else
            current_a[i] = target_a[i]
          end
          crow.ii.jf.vtrigger(i, current_a[i])
        end
        redraw()
      end
end)end

function cleanup()
  if timer then
    timer:stop()
  end

  crow.ii.jf.play_voice(0, 0, 0)
  crow.ii.jf.mode(0)
end

local function constrain_note(note, min_octave, max_octave)
  local min_note = (min_octave + 2) * 12
  local max_note = (max_octave + 2) * 12
  while note < min_note do
    note = note + 12
  end
  while note > max_note do
    note = note - 12
  end
  return note
end

function play_chord()
  local chord = chords[math.random(1, #chords)]

  -- print("---")
  -- tab.print(chord)

  for i=1,VOICES do

    local ci = i
    local wrapped = false
    while ci > #chord do
      ci = ci - #chord
      wrapped = true
    end

    local oct = math.random(1, 5)
    local note = constrain_note(chord[ci], oct, oct)

    -- local note = constrain_note(chord[ci], math.random(-2, 2), math.random(4, 5))

    if wrapped then
      local effective_oct = math.floor(note / 12)
      if effective_oct > 1 then
        note = note - 12 * math.random(1, 2) + math.random(1, 200) / 1000
      else
        note = note + 12 + math.random(1, 500) / 1000
      end
    end

    -- ns.notes[i] = note

    -- local freq = musicutil.note_num_to_freq(note/10)
    -- local note_v = (note - 60) / 12
    local note_v = (note / 12) - 5

    local st = util.clamp(slew_time + (math.random(0, 10) / 10) - (math.random(0, 5) / 10), 0, 10)
    local st2 = util.clamp(slew_time + (math.random(0, 10) / 10) - (math.random(0, 5) / 10), 0, 10)

    target_volts[i] = note_v
    slew_volt_steps[i] = (target_volts[i] - current_volts[i]) / (st / slew_tick)
    slew_a_steps[i] = (target_a[i] - current_a[i]) / (st2 / slew_tick)

    local off = math.random(1,3) == 3
    if off then
      -- crow.ii.jf.play_voice(i, 0, 0)
      target_a[i] = 0
    else
      -- crow.ii.jf.play_voice(i, note_v, 5)
      -- crow.ii.jf.vtrigger(i, 5)
      target_a[i] = 5
    end

    crow.ii.jf.vtrigger(i, current_a[i])
  end

  redraw()
end

function redraw()
  screen.clear()

  ns:draw()

  screen.update()
end
