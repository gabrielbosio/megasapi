require("systems.animation")
require("systems.camera")
require("systems.terrain")
require("systems.mruv")
require("systems.control")
require("systems.items")
require("systems.goals")
require("systems.state")
require("systems.living")
require("systems.attack")


local M = {}

function M.update(currentLevel, dt)
  camera.update(componentsTable, dt)

  items.update(componentsTable)

  control.player(componentsTable)
  attack.collision(componentsTable)
  currentLevel = goals.update(componentsTable, currentLevel)

  mruv.gravity(componentsTable, dt)
  terrain.collision(componentsTable, currentLevel.terrain, dt)
  control.playerAfterTerrainCollisionChecking(componentsTable)
  mruv.movement(componentsTable, dt)
  living.staminaSupply(componentsTable, dt)
  animation.animator(componentsTable, dt)
  state.finiteStateMachineRunner(componentsTable, dt)

  return currentLevel
end

return M
