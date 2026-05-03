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

body:setPos(10, 20)
body:setRot(45)
body:setVelocity(30, 40)
body:setAngularVelocity(90)
body:setLinearDamping(0.5)
body:setAngularDamping(0.25)
body:setBullet(true)

local x, y = body:getPos()
local vx, vy = body:getVelocity()
print('body pos', x, y)
print('body rot', body:getRot())
print('body velocity', vx, vy)
print('body angular velocity', body:getAngularVelocity())
print('body linear damping', body:getLinearDamping())
print('body angular damping', body:getAngularDamping())

body:setFixedRotation(true)
print('body fixed rotation', body:isFixedRotation())
print('body bullet', body:isBullet())
print('body enabled before disable', body:isEnabled())

body:setEnabled(false)
print('body enabled after disable', body:isEnabled())
body:setEnabled(true)
print('body enabled after enable', body:isEnabled())

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
