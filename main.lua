-- Test bed Lovr app
local letters = require('letters.letters')

function qdiff(q1, q2)
  return lovr.math.quat(q2) * lovr.math.quat(q1):normalize():conjugate()
end

function clamp(val, min, max)
	if val < min then
		val = min
	elseif max < val then
		val = max
	end
	return val
end

-- state
local drawables = {}
local font = lovr.graphics.newFont(32)

-- box and moving

Box = {
  selected = false,
  parent = nil
}

function Box:new(x, y, z, w, h, d)
  o = {}
  setmetatable(o, self)
  self.__index = self
  o.transform = lovr.math.newMat4():translate(x, y, z)
  o.size = lovr.math.newVec3(w, h, d)
  o.offset = lovr.math.newMat4()
  o.collider = letters.world:newBoxCollider(0, 0, 0, o.size.x, o.size.y, o.size.z)
  o.collider:setUserData(o)
  o.children = {}
  return o
end

function Box:addChild(c)
  table.insert(self.children, c)
  c.parent = self
end

function Box:transformInWorld()
  if self.parent then
    return lovr.math.mat4(self.parent:transformInWorld()):mul(self.transform)
  else
    return lovr.math.mat4(self.transform)
  end
end

function convert(m, a, b)
  local worldFromA = a and a:transformInWorld() or lovr.math.mat4()
  local worldFromB = b and b:transformInWorld() or lovr.math.mat4()
  local bFromWorld = worldFromB:invert()
  local bFromA = bFromWorld * worldFromA
  return bFromA * m
end

function Box:draw()
  lovr.graphics.setColor(self.selected and 0.9 or 0.7, 0.7, self.selected and 0.7 or 0.9)
  lovr.graphics.push()
  lovr.graphics.transform(self.transform)
  lovr.graphics.box('fill', 0, 0, 0, self.size)

  for _, child in ipairs(self.children) do
    child:draw()
  end
  lovr.graphics.pop()
end

function Box:select(hand)
  self:deselect(self.heldBy) -- if held by another hand
  self.selected = true
  self.heldBy = hand
  local handTransform = lovr.math.mat4(lovr.headset.getPose(hand.device))
  self.offset:set(handTransform:invert()):mul(self:transformInWorld())
end
function Box:deselect(hand)
  if self.heldBy == hand then
    self.selected = false
    self.heldBy = nil
  end
end
function Box:update()
  if self.heldBy then
    stickX, stickY = lovr.headset.getAxis(self.heldBy.device, "thumbstick")
    local handTransform = lovr.math.mat4(lovr.headset.getPose(self.heldBy.device))
    local newInWorld = handTransform:mul(self.offset)
    local newInLocal = convert(newInWorld, nil, self.parent)
    self.transform:set(newInLocal)
  end
  local x, y, z, w, h, d, a, ax, ay, az = self:transformInWorld():unpack()
  self.collider:setPose(x, y, z, a, ax, ay, az)

  for _, child in ipairs(self.children) do
    child:update()
  end
end

-- grid

local grid = {
  shader = nil
}

function grid:load()
  self.shader = lovr.graphics.newShader([[
    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
      return projection * transform * vertex;
    }
  ]], [[
    const float gridSize = 25.;
    const float cellSize = .5;

    vec4 color(vec4 gcolor, sampler2D image, vec2 uv) {

      // Distance-based alpha (1. at the middle, 0. at edges)
      float alpha = 1. - smoothstep(.15, .50, distance(uv, vec2(.5)));

      // Grid coordinate
      uv *= gridSize;
      uv /= cellSize;
      vec2 c = abs(fract(uv - .5) - .5) / fwidth(uv);
      float line = clamp(1. - min(c.x, c.y), 0., 1.);
      vec3 value = mix(vec3(.01, .01, .011), (vec3(.08)), line);

      return vec4(vec3(value), alpha);
    }
  ]], { flags = { highp = true } })
end
function grid:draw()
  lovr.graphics.setShader(self.shader)
  lovr.graphics.plane('fill', 0, 0, 0, 25, 25, -math.pi / 2, 1, 0, 0)
  lovr.graphics.setShader()
end

-- global
function lovr.load()
  letters.load()
  shader = lovr.graphics.newShader('standard')
  lovr.graphics.setBackgroundColor(0.95, 0.98, 0.98)

  local box = Box:new(-0.25, 1.5, -1.25, 0.15, 0.25, 0.40)
  local head = Box:new(0, 0.15, -0.1,   0.1, 0.1, 0.1)
  local thingie = Box:new(1, 0, 0,   0.05, 0.3, 0.1)
  table.insert(drawables, box)
  box:addChild(head)
  head:addChild(thingie)

  
  for i, hand in ipairs(letters.hands) do
    table.insert(drawables, hand)
  end
  grid:load()
  table.insert(drawables, grid)

end

function lovr.update()
  letters.update()
  for i, thing in ipairs(drawables) do
    if thing.update then thing:update() end
  end
end

function lovr.draw()
  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setDepthTest('lequal', true)
  lovr.graphics.clear()
  lovr.graphics.setShader(shader)

  lovr.graphics.setColor(1,1,1)
  lovr.graphics.sphere(0,0,0, 0.1)

  letters.draw()
  for i, thing in ipairs(drawables) do
    thing:draw()
  end

  -- debug draw colliders
  lovr.graphics.setColor(0, 1, 0, 1)
  for _, collider in ipairs(letters.world:getColliders()) do
    local x, y, z, a, ax, ay, az = collider:getPose()
    local w, h, d = collider:getShapes()[1]:getDimensions()
    lovr.graphics.box("line", x, y, z, w, h, d, a, ax, ay, az)
  end
end
