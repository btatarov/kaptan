KaptanWindow.open("Kaptan TextBox", 1024, 768)
KaptanWindow.setVsync(false)
KaptanWindow.setMaxFPS(120)

KaptanRenderer.setClearColor(40, 42, 48, 255)

local layer = KaptanLayer.new()
KaptanRenderer.add(layer)

local content = 'Text boxes wrap to a fixed rectangle.\nExplicit new lines are preserved, and longwordwithoutspacesisstillsplit.'

local left = KaptanTextBox.new('tests/text/unitblock.ttf', content, 28, 280, 180)
left:setAlignment(KaptanTextBox.ALIGN_LEFT)
left:setPos(-320, -120)
left:setColor(240, 240, 240, 255)
layer:add(left)

local center = KaptanTextBox.new('tests/text/unitblock.ttf', content, 28, 280, 180)
center:setAlignment(KaptanTextBox.ALIGN_CENTER)
center:setPos(0, -120)
center:setColor(120, 220, 255, 255)
layer:add(center)

local right = KaptanTextBox.new('tests/text/unitblock.ttf', content, 28, 280, 180)
right:setAlignment(KaptanTextBox.ALIGN_RIGHT)
right:setPos(320, -120)
right:setColor(255, 210, 120, 255)
layer:add(right)

local rotated = KaptanTextBox.new('tests/text/unitblock.ttf', 'Transforms apply to the text box as a whole.', 28, 320, 120)
rotated:setAlignment(KaptanTextBox.ALIGN_CENTER)
rotated:setPos(0, 180)
rotated:setRot(-12)
rotated:setScl(1.25)
rotated:setColor(190, 255, 150, 255)
layer:add(rotated)
