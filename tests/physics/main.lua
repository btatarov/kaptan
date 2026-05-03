print('physics ready before init', KaptanPhysics.isReady())

KaptanPhysics.setUnitsPerMeter(64)
KaptanPhysics.setSubsteps(2)
KaptanPhysics.init()

print('physics ready after init', KaptanPhysics.isReady())

KaptanPhysics.setGravity(0, 0)
local gx, gy = KaptanPhysics.getGravity()
print('gravity', gx, gy)
print('substeps', KaptanPhysics.getSubsteps())
print('units per meter', KaptanPhysics.getUnitsPerMeter())

local body = KaptanBody.new(KaptanBody.DYNAMIC)
print('body valid after create', body:isValid())
print('body type after create', body:getType())

body:setType(KaptanBody.KINEMATIC)
print('body type after set', body:getType())

body:destroy()
print('body valid after destroy', body:isValid())

local cleared_body = KaptanBody.new(KaptanBody.STATIC)
print('cleared body valid before clear', cleared_body:isValid())

KaptanPhysics.clear()
print('physics ready after clear', KaptanPhysics.isReady())
print('cleared body valid after clear', cleared_body:isValid())

KaptanPhysics.destroy()
print('physics ready after destroy', KaptanPhysics.isReady())
