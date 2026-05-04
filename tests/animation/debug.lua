print('animation once', KaptanAnimation.ONCE)
print('animation loop', KaptanAnimation.LOOP)
print('animation ping pong', KaptanAnimation.PING_PONG)
print('animation constants ordered', KaptanAnimation.ONCE < KaptanAnimation.LOOP and KaptanAnimation.LOOP < KaptanAnimation.PING_PONG)
