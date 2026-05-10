local Class = {}
setmetatable(Class, Class)

function Class:__call(...)
    local cls = {}
    for key, value in pairs(self) do
        cls[key] = value
    end

    cls.__class = cls
    cls.__call = function(self, ...)
        return self:__new(...)
    end
    cls.__interface = {__index = cls}
    setmetatable(cls.__interface, cls.__interface)
    return setmetatable(cls, cls)
end

function Class:__new(...)
    local obj
    if self.__factory then
        obj = self.__factory(...)
        obj:setInterface(self.__interface)
    else
        obj = setmetatable({}, self.__interface)
    end

    if obj.init then
        obj:init(...)
    end

    return obj
end

local CurveActor = Class()

CurveActor.__factory = function(value)
    return KaptanAnimationCurve.new()
end

function CurveActor:init(value)
    self.value = value
    self:addKey(0, 0)
    self:addKey(1, value)
end

function CurveActor:half()
    return self:sample(0.5)
end

local actor = CurveActor(20)
print('class native fallback', actor:getKeyCount())
print('class custom field', actor.value)
print('class custom method', actor:half())
