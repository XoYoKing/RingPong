#import <Foundation/Foundation.h>

@class Player;

typedef struct _AGPoint {
	double x;
	double y;
} AGPoint;

enum {
	PLAYER_HIT_BALL = 0,
	PLAYER_CAN_TRY_AGAIN,
	PLAYER_MISSED_BALL
};

@interface Ball : NSObject {
	double speed, direction, x, y;
	CFAbsoluteTime elapsedTime;
}
- (AGPoint)position;
- (void)testForCollisionAgainstPlayer:(Player *)player;
- (void)advanceTimeBySeconds:(CFAbsoluteTime)seconds;
@end
