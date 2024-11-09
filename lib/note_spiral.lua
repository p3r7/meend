-- note spiral

local NoteSpiral = {}
NoteSpiral.__index = NoteSpiral

-- ------------------------------------------------------------------------
-- deps


-- ------------------------------------------------------------------------
-- constructors

function NoteSpiral.new(x, y, w, h, octaves_per_layer)
  local o = setmetatable({}, NoteSpiral)

  o.x = x
  o.y = y
  o.w = w
  o.h = h
  o.octaves_per_layer = octaves_per_layer or 1

  o.notes = {}

  return o
end


-- ------------------------------------------------------------------------
-- API

function NoteSpiral:midi_note_coord(note)
  local radius_max = math.min(self.w, self.h) / 2
  local theta_offset = -math.pi / 2  -- top instead of right

  local radius = radius_max - (note / 127) * radius_max
  -- local theta = theta_offset - (math.pi / (6 * self.octaves_per_layer)) * note
  local theta = theta_offset + note * (math.pi / (6 * self.octaves_per_layer))

  local nx = self.x + self.w / 2 + radius * math.cos(theta)
  local ny = self.y + self.h / 2 + radius * math.sin(theta)
  return nx, ny, radius, theta
end

function NoteSpiral:draw()
  local midi_range = 127
  local radius_max = math.min(self.w, self.h) / 2
  local radius_step = radius_max / (midi_range / 12)

  if octaves_per_layer == nil then
    octaves_per_layer = 1
  end

  screen.level(15)

  for note = 0, midi_range do
    local nx, ny, radius, theta = self:midi_note_coord(note)
    local theta_next = theta + (math.pi / (6 * self.octaves_per_layer))

    if note == 0 then
      screen.move(nx, ny)
    end
    screen.arc(self.x + self.w / 2, self.y + self.h / 2, radius, theta, theta_next)
  end
  screen.stroke()

  -- notes
  for _, note in ipairs(self.notes) do
    -- NB: like `musicutil.freq_to_note_num` but not rounded
    -- local note = 12 * math.log(hz / 440.0) / math.log(2) + 69.5

    local nx, ny, _, _ = self:midi_note_coord(note)

    screen.level(15)
    screen.circle(nx, ny, 2)
    screen.fill()
  end

end


-- ------------------------------------------------------------------------

return NoteSpiral
