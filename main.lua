-- Test bed Lovr app
local letters = require('letters.letters')

function qdiff(q1, q2)
  return lovr.math.quat(q2) * lovr.math.quat(q1):normalize():conjugate()
end

-- state
local drawables = {}
local font = lovr.graphics.newFont(32)

-- movables

box = {
  position = lovr.math.newVec3(-0.25, 1.5, -1.25),
  rotation = lovr.math.newQuat(),
  size = lovr.math.newVec3(0.15, 0.25, 0.40),
  offset = lovr.math.newVec3(),
  distance = 0,
  rOffset = lovr.math.newQuat()
}

function box:draw()
  lovr.graphics.setColor(0.7, 0.7, 0.9)
  lovr.graphics.box('fill', self.position, self.size, self.rotation)
end

function box:select(hand)
  self:deselect(self.heldBy)
  self.heldBy = hand
  self.offset:set(self.position - hand.to)
  local handRot = lovr.math.quat(lovr.headset.getOrientation(self.heldBy.device))
  self.rOffset:set(qdiff(handRot, self.rotation))
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
    self.position:set(distantPoint + self.offset)
    self.rotation:set(lovr.math.quat(self.rOffset) * handRotationQ)
  end
  self.collider:setPosition(self.position)
  self.collider:setOrientation(self.rotation)
end

-- global
function lovr.load()
  letters.load()

  box.collider = letters.world:newBoxCollider(box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z)
  box.collider:setUserData(box)

  shader = lovr.graphics.newShader('standard')

  lovr.graphics.setBackgroundColor(0.95, 0.98, 0.98)
  
  for i, hand in ipairs(letters.hands) do
    table.insert(drawables, hand)
  end
  table.insert(drawables, box)
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
