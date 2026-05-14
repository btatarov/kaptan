print('gc logging before', KaptanEnvironment.isLuaGCLogging())
KaptanEnvironment.setLuaGCLogging(true)
print('gc logging after enable', KaptanEnvironment.isLuaGCLogging())

local count = collectgarbage('count')
print('gc count type', type(count))
collectgarbage('collect')

KaptanEnvironment.setLuaGCLogging(false)
print('gc logging after disable', KaptanEnvironment.isLuaGCLogging())
collectgarbage('collect')
