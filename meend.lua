-- meend.
-- @eigen


-- ------------------------------------------------------------------------
-- deps

local musicutil = require("musicutil")
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

-- NB: retune somewhat works but seem to freeze norns
-- i guess it might take more i2c bw and kill the crow handler
-- TRIG_MODES = {'slew', 'retrig', 'retune'}
TRIG_MODES = {'slew', 'retrig'}

INIT_PITCH = (60 / 12) - 5


-- ------------------------------------------------------------------------
-- state

ns = nil

chords = {}
timer = nil

local slew_tick = 0.01
-- local slew_tick = 0.03

local chord_time = 5

target_pitch = {0, 0, 0, 0, 0, 0}
current_pitch = {INIT_PITCH, INIT_PITCH, INIT_PITCH, INIT_PITCH, INIT_PITCH, INIT_PITCH}
slew_pitch_steps = {0, 0, 0, 0, 0, 0}

target_a = {0, 0, 0, 0, 0, 0}
current_a = {5, 5, 5, 5, 5, 5}
slew_a_steps = {0, 0, 0, 0, 0, 0}


-- ------------------------------------------------------------------------
-- utils

local function rnd_sign()
  return ( math.random(0,1) == 1 ) and 1 or -1
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

function gcd(a, b)
  while b ~= 0 do
    a, b = b, a % b
  end
  return a
end

function float_to_ratio(number, precision)
  local denominator = 10 ^ precision
  local numerator = math.floor(number * denominator + 0.5)

  local divisor = gcd(numerator, denominator)
  numerator = numerator // divisor
  denominator = denominator // divisor

  return util.round(numerator), util.round(denominator)
end

-- ------------------------------------------------------------------------
-- logic

-- slews each note pitch & amplitudes
function slew_notes()
  local base_note = current_pitch[1]

  for i=1,VOICES do

    if math.abs(current_pitch[i] - target_pitch[i]) > math.abs(slew_pitch_steps[i]) then
      current_pitch[i] = current_pitch[i] + slew_pitch_steps[i]
    else
      current_pitch[i] = target_pitch[i]
    end

    if params:string("trig_mode") == 'retune' then
      if i > 2  then
        local ratio = current_pitch[i] / base_note
        local num, den = float_to_ratio(ratio, 2)
        -- print(ratio .. ' -> ' .. num .. '/' .. den)
        crow.ii.jf.retune(i, num, den)
      end
    else
      crow.ii.jf.pitch(i, current_pitch[i])
    end

    ns.notes[i].midi_pitch = (current_pitch[i] +5) * 12

    if params:string("trig_mode") == 'slew' then
      if math.abs(current_a[i] - target_a[i]) > math.abs(slew_a_steps[i]) then
        current_a[i] = current_a[i] + slew_a_steps[i]
      else
        current_a[i] = target_a[i]
      end
      ns.notes[i].a = current_a[i] / 5
      crow.ii.jf.vtrigger(i, current_a[i])
    end
  end
end

-- register a new chord to play
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
    local midi_pitch = constrain_note(chord[ci], oct, oct)

    -- local midi_pitch = constrain_note(chord[ci], math.random(-2, 2), math.random(4, 5))

    if wrapped then
      local effective_oct = math.floor(midi_pitch / 12)
      if effective_oct > 1 then
        midi_pitch = midi_pitch - 12 * math.random(1, 2) + math.random(1, 200) / 1000
      else
        midi_pitch = midi_pitch + 12 + math.random(1, 500) / 1000
      end
    end

    -- ns.notes[i] = note

    -- local freq = musicutil.note_num_to_freq(note/10)
    -- local note_v = (note - 60) / 12
    local note_v = (midi_pitch / 12) - 5

    local st = params:get("slew_time")
    local pitch_st = util.clamp(st + params:get("slew_offness") * ((math.random(0, util.round(st * 20)) / 10) - (math.random(0, util.round(st * 10)) / 10)), 0, 10)
    local amp_st   = util.clamp(st + params:get("slew_offness") * ((math.random(0, util.round(st * 20)) / 10) - (math.random(0, util.round(st * 10)) / 10)), 0, 10)

    target_pitch[i] = note_v
    slew_pitch_steps[i] = (target_pitch[i] - current_pitch[i]) / (pitch_st / slew_tick)
    slew_a_steps[i] = (target_a[i] - current_a[i]) / (amp_st / slew_tick)

    local off = math.random(1,3) == 3
    if off then
      -- crow.ii.jf.play_voice(i, 0, 0)
      target_a[i] = 0
    else
      -- crow.ii.jf.play_voice(i, note_v, 5)
      -- crow.ii.jf.vtrigger(i, 5)
      target_a[i] = 5
    end

    if params:string("trig_mode") == 'retrig' then
      crow.ii.jf.vtrigger(i, target_a[i])
      crow.ii.jf.play_voice(i, current_pitch[i])
    end
  end

  redraw()
end


-- ------------------------------------------------------------------------
-- main

function init()
  screen.aa(1)
  screen.line_width(1)

  -- crow.ii.jf.play_voice(0, 0, 0)
  crow.ii.jf.mode(1)
  crow.ii.jf.vtrigger(0, 5)

  local scale = musicutil.generate_scale(60, "major", 7) -- NB: 60 is a C

  local roman_numerals = {"I", "ii", "iii", "IV", "V", "vi"}

  for _, numeral in ipairs(roman_numerals) do
    for i = 1, #scale - 1 do
      table.insert(chords, musicutil.generate_chord_roman(scale[i], "Major", numeral))
    end
  end

  ns = NoteSpiral.new(SPIRAL_X, SPIRAL_Y, SPIRAL_W, SPIRAL_H, 1)
  for i = 1, VOICES do
    ns.notes[i] = {
      midi_pitch = current_pitch[i],
      a = current_a[i] / 5,
    }
  end

  params:add_separator("meend_main", "meend")
  params:add{type = "option", id = "trig_mode", name = "Trig Mode", options = TRIG_MODES}
  params:set_action("trig_mode", function(v)
                      if TRIG_MODES[v] == 'retune' then
                        crow.ii.jf.mode(0)
                        crow.ii.jf.play_voice(0, 0, 0)
                      else
                        crow.ii.jf.mode(1)
                      end
  end)
  params:add{type = "control", id = "slew_time", name = "Slew",
             controlspec = controlspec.new(0, 7, "lin", 0, 0.5, "")
             -- , formatter = Formatters.format_secs_raw
  }
  params:add{type = "control", id = "slew_offness", name = "Slew Offness",
             controlspec = controlspec.new(0, 1, "lin", 0, 1.0, "")
             -- , formatter = Formatters.percentage
  }

  timer = metro.init()
  timer.time = chord_time
  timer.event = play_chord
  timer:start()

  for i=1,VOICES do
    crow.ii.jf.vtrigger(i, current_a[i])
    crow.ii.jf.pitch(i, current_pitch[i])
  end

  -- play_chord()

  clock.run(function()
      while true do
        clock.sleep(slew_tick)
        slew_notes()
        redraw()
      end
  end)

  gamepad.analog = function(sensor_axis, val, half_reso)
    if val == nil or half_reso == nil then
      -- FIXME: why does this even happen?
      return
    end

    local axis_2_crow_out = {
      lefty=1,
      leftx=2,
      righty=3,
      rightx=4,
    }

    local crow_out = axis_2_crow_out[sensor_axis]

    crow.output[crow_out].volts = util.linlin(0, half_reso*2, -5, 5, val+half_reso)
  end

end

function cleanup()
  if timer then
    timer:stop()
  end

  crow.ii.jf.play_voice(0, 0, 0)
  crow.ii.jf.mode(0)
  -- crow.ii.jf.retune(0, 0, 0)
end

function redraw()
  screen.clear()

  ns:draw()

  screen.update()
end
