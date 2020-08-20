-- Test bed Lovr app
local letters = require('letters.letters')

function qdiff(q1, q2)
  return lovr.math.quat(q2) * lovr.math.quat(q1):normalize():conjugate()
end

-- state
local drawables = {}
local font = lovr.graphics.newFont(32)

-- box and moving

box = {
  transform = lovr.math.newMat4():translate(-0.25, 1.5, -1.25),
  size = lovr.math.newVec3(0.15, 0.25, 0.40),
  offset = lovr.math.newVec3(),
  distance = 0,
  rOffset = lovr.math.newQuat()
}

function box:draw()
  lovr.graphics.setColor(0.7, 0.7, 0.9)

  local x, y, z, w, d, h, a, ax, ay, az = self.transform:unpack()
  lovr.graphics.box('fill', x, y, z, self.size, a, ax, ay, az)
end

function box:select(hand)
  local position = lovr.math.vec3() * self.transform
  local rotation = lovr.math.quat() * self.transform
  self:deselect(self.heldBy)
  self.heldBy = hand
  self.offset:set(position - hand.to)
  local handRot = lovr.math.quat(lovr.headset.getOrientation(self.heldBy.device))
  self.rOffset:set(qdiff(handRot, rotation))
  self.distance = (hand.to - hand.from):length()
end
function box:deselect(hand)
  if self.heldBy == hand then
    self.heldBy = nil
  end
end
function box:update()
  if self.heldBy then
    local straightAhead = lovr.math.vec3(0, 0, -1)
    local handRotationQ = lovr.math.quat(lovr.headset.getOrientation(self.heldBy.device))
    local handRotation = lovr.math.mat4():rotate(handRotationQ)
    local pointedDirection = handRotation:mul(straightAhead)
    local distantPoint = lovr.math.newVec3(pointedDirection):mul(self.distance):add(self.heldBy.from)

    self.transform.set(
      lovr.math.mat4():translate(distantPoint + self.offset) *
      lovr.math.quat(self.rOffset) * 
      handRotation
    )
  end
  self.collider:setPose(self.transform:unpack())
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
  box.collider = letters.world:newBoxCollider(0, 0, 0, box.size.x, box.size.y, box.size.z)
  box.collider:setUserData(box)

  shader = lovr.graphics.newShader('standard')

  lovr.graphics.setBackgroundColor(0.95, 0.98, 0.98)
  
  for i, hand in ipairs(letters.hands) do
    table.insert(drawables, hand)
  end
  table.insert(drawables, box)
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

  letters.draw()
  for i, thing in ipairs(drawables) do
    thing:draw()
  end
end
