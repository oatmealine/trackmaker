-- https://github.com/EX-XDRiVER/Chart-Documentation/blob/main/mods.md
-- https://gist.github.com/Kryzarel/bba64622057f21a1d6d44879f9cd7bd4

local sin, cos, pow, sqrt, abs, pi = math.sin, math.cos, math.pow, math.sqrt, math.abs, math.pi

local M = {}

function M.Linear(t) return t end

function M.InQuad(t) return t * t end
function M.OutQuad(t) return 1 - M.InQuad(1 - t) end
function M.InOutQuad(t)
  if t < 0.5 then return M.InQuad(t * 2) / 2 end
  return 1 - M.InQuad((1 - t) * 2) / 2
end

function M.InCubic(t) return t * t * t end
function M.OutCubic(t) return 1 - M.InCubic(1 - t) end
function M.InOutCubic(t)
  if t < 0.5 then return M.InCubic(t * 2) / 2 end
  return 1 - M.InCubic((1 - t) * 2) / 2
end

function M.InQuart(t) return t * t * t * t end
function M.OutQuart(t) return 1 - M.InQuart(1 - t) end
function M.InOutQuart(t)
  if t < 0.5 then return M.InQuart(t * 2) / 2 end
  return 1 - M.InQuart((1 - t) * 2) / 2
end

function M.InQuint(t) return t * t * t * t * t end
function M.OutQuint(t) return 1 - M.InQuint(1 - t) end
function M.InOutQuint(t)
  if t < 0.5 then return M.InQuint(t * 2) / 2 end
  return 1 - M.InQuint((1 - t) * 2) / 2
end

function M.InSine(t) return (1 - cos(t * pi / 2)) end
function M.OutSine(t) return sin(t * pi / 2) end
function M.InOutSine(t) return (-(cos(pi * t) - 1) / 2) end

function M.InExpo(t) return t == 0 and 0 or pow(2, 10 * t - 10) end
function M.OutExpo(t) return 1 - M.InExpo(1 - t) end
function M.InOutExpo(t)
  if t < 0.5 then return M.InExpo(t * 2) / 2 end
  return 1 - M.InExpo((1 - t) * 2) / 2
end

function M.InCirc(t) return -(sqrt(1 - t * t) - 1) end
function M.OutCirc(t) return 1 - M.InCirc(1 - t) end
function M.InOutCirc(t)
  if t < 0.5 then return M.InCirc(t * 2) / 2 end
  return 1 - M.InCirc((1 - t) * 2) / 2
end

function M.InElastic(t) return 1 - M.OutElastic(1 - t) end
function M.OutElastic(t)
  local p = 0.3
  return pow(2, -10 * t) * sin((t - p / 4) * (2 * pi) / p) + 1
end
function M.InOutElastic(t)
  if t < 0.5 then return M.InElastic(t * 2) / 2 end
  return 1 - M.InElastic((1 - t) * 2) / 2
end

function M.InBack(t)
  local s = 1.70158
  return t * t * ((s + 1) * t - s)
end
function M.OutBack(t) return 1 - M.InBack(1 - t) end
function M.InOutBack(t)
  if t < 0.5 then return M.InBack(t * 2) / 2 end
  return 1 - M.InBack((1 - t) * 2) / 2
end

function M.InBounce(t) return 1 - M.OutBounce(1 - t) end
function M.OutBounce(t)
  local div = 2.75
  local mult = 7.5625

  if t < 1 / div then
    return mult * t * t
  elseif t < 2 / div then
    t = t - 1.5 / div
    return mult * t * t + 0.75
  elseif t < 2.5 / div then
    t = t - 2.25 / div
    return mult * t * t + 0.9375
  else
    t = t - 2.625 / div
    return mult * t * t + 0.984375
  end
end
function M.InOutBounce(t)
  if t < 0.5 then return M.InBounce(t * 2) / 2 end
  return 1 - M.InBounce((1 - t) * 2) / 2
end

function M.Bounce(t)
  return 4 * t * (1 - t)
end

function M.Tri(t)
  return 1 - abs(2 * t - 1)
end

function M.Bell(t)
  return M.InOutQuint(M.Tri(t))
end

function M.Pop(t)
  return 3.5 * (1 - t) * (1 - t) * sqrt(t)
end

function M.Tap(t)
  return 3.5 * t * t * sqrt(t)
end

function M.Pulse(t)
  return t < .5 and M.Tap(t * 2) or -M.Pop(t * 2 - 1)
end

function M.Spike(t)
  return math.exp(-10 * abs(2 * t - 1))
end

function M.Inverse(t)
  return t * t * (1 - t) * (1 - t) / (0.5 - t)
end

function M.Instant() return 1 end

function M.SmoothStep(t) return 3 * pow(t, 2) - 2 * pow(t, 3) end

function M.SmootherStep(t) return pow(t, 5) * (5 * t * (t * (7 * t * (2 * t - 9) + 108) - 84) + 126) end

function M.SmoothestStep(t) return pow(t, 7) * 1716 + 7 * pow(t, 8) * (2 * t * (3 * t * (t * (11 * t * (2 * t - 13) + 390) - 572) + 1430) - 1287) end

return M