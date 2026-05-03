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

KaptanPhysics.clear()
print('physics ready after clear', KaptanPhysics.isReady())

KaptanPhysics.destroy()
print('physics ready after destroy', KaptanPhysics.isReady())
