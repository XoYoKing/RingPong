#import "Ball.h"
#import "Metrics.h"
#import "Player.h"
#import "math.h"

static double angleFromCoordinates(double x, double y) {
	double angle;
	if (y >= 0 && x > 0) {
		angle = atan(y/x) * 180 / M_PI;
	} else if (y >= 0 && x < 0) {
		angle = 180 + atan(y/x) * 180 / M_PI;
	} else if (y < 0 && x < 0) {
		angle = 180 + atan(y/x) * 180 / M_PI;
	} else if (y < 0 && x > 0) {
		angle = 360 + atan(y/x) * 180 / M_PI;
	} else if (y > 0 && x == 0) {
		angle = 90;
	} else if (y < 0 && x == 0){
		angle = 270;
	} else {
		// this should never happen
		// case where x = y = 0
		angle = 0;
	}
	return angle;
}


@implementation Ball

- (id)init {
	if (self = [super init]) {
		if (RANDOM_BALL_SPAWNING_IS_ENABLED) {
			x = fmod(random() * M_PI, RING_RADIUS * 0.5) - fmod(random() * M_PI, RING_RADIUS * 0.5);
			y = fmod(random() * M_PI, RING_RADIUS * 0.5) - fmod(random() * M_PI, RING_RADIUS * 0.5);
		}
		speed = MIN_BALL_SPEED;
		direction = random() % 360;
	}
	return self;
}


- (AGPoint)position {
	AGPoint p = {x, y};
	return p;
}


- (void)testForCollisionAgainstPlayer:(Player *)player {
	double distanceOfBallFromCenterOfRing = sqrt(x * x + y * y);
	if (distanceOfBallFromCenterOfRing < RING_RADIUS - BALL_RADIUS - PADDLE_HALF_THICKNESS) {
		// ball is still too close to centre of ring
		// ball needn't change direction
		return;
	}
	AGPlayerState *state = [player state];
	if (distanceOfBallFromCenterOfRing > RING_RADIUS) {
		// ball is out of bounds
		state->code = AG_PLAYER_STATE_LOST;
	}
	if (distanceOfBallFromCenterOfRing > RING_RADIUS + BALL_RADIUS + PADDLE_HALF_THICKNESS) {
		// ball needn't change direction
		return;
	}
	
	//BOOL hitWasAcceptable = YES; // this will be determined by how close the new direction is to being tangential to the ring
	
	double playerStartAngle = state->angle;
	double playerEndAngle = playerStartAngle + PADDLE_LENGTH;
	
	double ballAngle = angleFromCoordinates(x, y);
	if (ballAngle < playerStartAngle) {
		ballAngle += 360;
	}
	
	if (ballAngle >= playerStartAngle &&
		ballAngle <= playerEndAngle) {
		// player hit flat on
		[self advanceTimeBySeconds:-elapsedTime];
		direction = fmod(2 * ballAngle + 180 - direction, 360);
		[self advanceTimeBySeconds:-elapsedTime];
		state->code = AG_PLAYER_STATE_NOT_CURRENT;
		return;
	}

	double playerStartAngleInRadians = playerStartAngle * M_PI / 180;
	double startX = cos(playerStartAngleInRadians) * RING_RADIUS;
	double startY = sin(playerStartAngleInRadians) * RING_RADIUS;
	double distanceFromStart = sqrt((x - startX) * (x - startX) + (y - startY) * (y - startY));
	if (distanceFromStart <= PADDLE_HALF_THICKNESS + BALL_RADIUS) {
		// collision with starting end
		[self advanceTimeBySeconds:-elapsedTime];
		direction = fmod(2 * ballAngle + 180 - direction, 360); // fake
		[self advanceTimeBySeconds:-elapsedTime];
		// I should only do this if the hit was acceptable
		state->code = AG_PLAYER_STATE_NOT_CURRENT;
		return;
	}
	
	double playerEndAngleInRadians = playerEndAngle * M_PI / 180;
	double endX = cos(playerEndAngleInRadians) * RING_RADIUS;
	double endY = sin(playerEndAngleInRadians) * RING_RADIUS;
	double distanceFromEnd = sqrt((x - endX) * (x - endX) + (y - endY) * (y - endY));
	if (distanceFromEnd <= PADDLE_HALF_THICKNESS + BALL_RADIUS) {
		// collision with ending end
		[self advanceTimeBySeconds:-elapsedTime];
		direction = fmod(2 * ballAngle + 180 - direction, 360); // fake
		[self advanceTimeBySeconds:-elapsedTime];
		// I should only do this if the hit was acceptable
		state->code = AG_PLAYER_STATE_NOT_CURRENT;
		return;
	}
}


- (void)advanceTimeBySeconds:(CFAbsoluteTime)seconds {
	elapsedTime = seconds;
	double deltaX, deltaY;
	double directionInRadians = direction * M_PI / 180;
	deltaX = cos(directionInRadians) * speed * elapsedTime;
	deltaY = sin(directionInRadians) * speed * elapsedTime;
	x += deltaX;
	y += deltaY;
}

@end
