local components = require "components"
local M = {}


local function checkBottomBoundary(collisionBox, position, velocity, x1, y1, x2, y2, dt)
  local box = collisionBox:translated(position)

  if box:right() > x1 and box:left() < x2 and box:bottom() + velocity.y*dt > y1
      and box:center() < y2 then
    velocity.y = 0
    position.y = y1
  end
end


local function checkTopBoundary(collisionBox, position, velocity, x1, y1, x2, y2, dt)
  local box = collisionBox:translated(position)

  if box:right() + velocity.x*dt > x1 and box:left() + velocity.x*dt< x2
      and box:top() >= y2 and box:top() + velocity.y*dt < y2 then
    -- Y-velocity cannot be set to zero
    -- The player "thinks" that it is on the ground and can jump in the air
    velocity.y = 1
    position.y = y2 - collisionBox:top()
  end
end


local function checkLeftBoundary(collisionBox, position, velocity, x1, y1, x2, y2, dt)
  local box = collisionBox:translated(position)

  if box:right() <= x1 and box:right() + velocity.x*dt > x1 and box:top() < y2
      and box:bottom() > y1 then
    velocity.x = 0
    position.x = x1 - collisionBox:right()
  end
end


local function checkRightBoundary(collisionBox, position, velocity, x1, y1, x2, y2, dt)
  local box = collisionBox:translated(position)

  if box:left() >= x2 and box:left() + velocity.x*dt < x2 and box:top() < y2
      and box:bottom() > y1 then
    velocity.x = 0
    position.x = x2 - collisionBox:left()
  end
end


local function mustCheckSides(collisionBox, position, terrain, x1, y1, x2, y2)
    -- Decide if collision with boundary sides must be checked.
    local mustCheckLeft = true
    local mustCheckRight = true

    -- Verify that there are no slopes around.
    for i in pairs(terrain.slopes or {}) do
      local sx1, sy1, sx2, sy2 = unpack(terrain.slopes[i])
      local xLeft, xRight = math.min(sx1, sx2), math.max(sx1, sx2)
      local yTop, yBottom = math.min(sy1, sy2), math.max(sy1, sy2)

      local box = collisionBox:translated(position)
      local slopeId = collisionBox.slopeId

      if slopeId == i then
        if xRight == math.min(x1, x2) and yTop == math.min(y1, y2)
            and box:left() >= xLeft then
          mustCheckLeft = false
          break
        end

        if xLeft == math.max(x1, x2) and yTop == math.min(y1, y2)
            and box:right() <= xRight then
          mustCheckRight = false
          break
        end
      end
    end

    return mustCheckLeft, mustCheckRight
end


local function checkBoundaries(collisionBox, position, velocity, terrain, dt)
  for i in pairs(terrain.boundaries) do
    local boundaries = terrain.boundaries[i]
    local x1 = math.min(boundaries[1], boundaries[3])
    local y1 = math.min(boundaries[2], boundaries[4])
    local x2 = math.max(boundaries[1], boundaries[3])
    local y2 = math.max(boundaries[2], boundaries[4])

    checkBottomBoundary(collisionBox, position, velocity, x1, y1, x2, y2, dt)
    checkTopBoundary(collisionBox, position, velocity, x1, y1, x2, y2, dt)

    local mustCheckLeft, mustCheckRight = mustCheckSides(collisionBox,
                                                         position, terrain,
                                                         x1, y1, x2, y2)

    if mustCheckLeft then
      checkLeftBoundary(collisionBox, position, velocity, x1, y1, x2, y2, dt)
    end

    if mustCheckRight then
      checkRightBoundary(collisionBox, position, velocity, x1, y1, x2, y2, dt)
    end
  end
end


local function checkSlopes(collisionBox, position, velocity, terrain, dt)
  for i in pairs(terrain.slopes or {}) do
    local x1, y1, x2, y2 = unpack(terrain.slopes[i])
    local xLeft, xRight = math.min(x1, x2), math.max(x1, x2)
    local yTop, yBottom = math.min(y1, y2), math.max(y1, y2)

    local box = collisionBox:translated(position)

    if position.x >= xLeft and position.x <= xRight 
        and box:bottom() >= yTop and box:bottom() <= yBottom then
      local m = (y2-y1) / (x2-x1)
      local ySlope = m*(position.x-x1) + y1

      -- if pointing up
      if y1 > y2 then
        if box:bottom() + velocity.y*dt >= ySlope then
          position.y = ySlope
          velocity.y = 0
          collisionBox.slopeId = i
        end

        -- snap position to slope, in order to avoid "rolling down the hill"
        if velocity.x ~= 0 and velocity.y == 0 then
          local xNew = position.x + velocity.x*dt
          position.y = m*(xNew-x1) + y1
        end
      end
    end

  end  -- for
end


local function checkClouds(collisionBox, position, velocity, terrain, dt)
  if collisionBox.reactingWithClouds then
    for i in pairs(terrain.clouds or {}) do
      local clouds = terrain.clouds[i]
      local x1 = math.min(clouds[1], clouds[3])
      local y1 = clouds[2]
      local x2 = math.max(clouds[1], clouds[3])

      local box = collisionBox:translated(position)

      if box:right() > x1 and box:left() < x2 and box:bottom() <= y1
          and box:bottom() + velocity.y*dt > y1 and velocity.y > 0 then
        velocity.y = 0
        position.y = y1
      end
    end
  else
    collisionBox.reactingWithClouds = true
  end
end


function M.collision(componentsTable, terrain, dt)
  -- solid depends on collisionBox, position and velocity
  components.assertDependency(componentsTable, "solids", "collisionBoxes",
                              "positions", "velocities")

  for entity, solidComponent in pairs(componentsTable.solids or {}) do
    local collisionBox = componentsTable.collisionBoxes[entity]
    local position = componentsTable.positions[entity]
    local velocity = componentsTable.velocities[entity]
    components.assertExistence(entity, "solid", {collisionBox, "collisionBox"},
                               {position, "position"}, {velocity, "velocity"})

    checkBoundaries(collisionBox, position, velocity, terrain, dt)
    checkSlopes(collisionBox, position, velocity, terrain, dt)
    checkClouds(collisionBox, position, velocity, terrain, dt)
  end
end

return M
