-- Test bed Lovr app
local letters = require('letters.letters')

-- state
local drawables = {}
local font = lovr.graphics.newFont(32)

-- movables

box = {
  position = lovr.math.newVec3(-0.25, 1.5, -1.25),
  size = lovr.math.newVec3(0.15, 0.25, 0.40),
  offset = lovr.math.newVec3()
}

function box:draw()
  lovr.graphics.setColor(0.7, 0.7, 0.9)
  lovr.graphics.box('fill', box.position, box.size)
end

function box:select(hand)
  self:deselect(self.heldBy)
  self.heldBy = hand
  self.offset:set(self.position - hand.from)
end
function box:deselect(hand)
  if self.heldBy == hand then
    self.heldBy = nil
  end
end
function box:update()
  if self.heldBy then
    self.position:set(self.heldBy.from + self.offset)
  end
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
