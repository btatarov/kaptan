local interface = {}
interface.__index = interface

function interface:init(value)
    self.value = value
end

function interface:double()
    return self.value * 2
end

function interface:sampleNative(time)
    return self:sample(time)
end

local curve = KaptanAnimationCurve.new()
curve:setInterface(interface)
curve:init(21)
print('custom field after init', curve.value)
print('custom method double', curve:double())

curve.value = 7
print('custom field after assign', curve.value)
print('custom method after assign', curve:double())

curve:addKey(0, 0)
curve:addKey(1, 10)
print('native method fallback', curve:sample(0.5))
print('native method from custom method', curve:sampleNative(0.5))

local override_interface = {}
override_interface.__index = override_interface

function override_interface:getKeyCount()
    return 999
end

curve:setInterface(override_interface)
print('lua method overrides native', curve:getKeyCount())
