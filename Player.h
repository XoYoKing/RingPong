#import <Foundation/Foundation.h>
#import "AGHIDManager.h"
#import "AGHIDCalibrator.h"

@class Scene;

enum {
	AG_PLAYER_STATE_NOT_PLAYING = 0, // player hasn't joined, or they disconnected and alpha is now 0.0, or they lost and alpha is now 0.0
	AG_PLAYER_STATE_CURRENT, // transition to green from violet, or stay at green if we're already there
	AG_PLAYER_STATE_NOT_CURRENT, // transition to violet from green, or stay at violet if we're already there
	AG_PLAYER_STATE_LOST, // if not already red, and reduce alpha with each frame. Set to AG_PLAYER_STATE_NOT_PLAYING when alpha reaches 0.0
	AG_PLAYER_STATE_QUIT_CURRENT, // reduce alpha with each frame. Set to AG_PLAYER_STATE_NOT_PLAYING when alpha reaches 0.0
	AG_PLAYER_STATE_QUIT_NOT_CURRENT // reduce alpha with each frame. Set to AG_PLAYER_STATE_NOT_PLAYING when alpha reaches 0.0
};

typedef struct _AGPlayerState {
	unsigned int code; // one of the above codes
	float red, green, blue, alpha;
	double angle, angularSpeed;
} AGPlayerState;

@interface Player : NSObject {
	NSNumber *locationID;
	AGHIDManager *manager;
	AGHIDCalibrator *calibrator;
	
	CFAbsoluteTime elapsedTime;
	CFAbsoluteTime lastSystemActivityUpdate;
	
	Scene *scene;
	
	AGPlayerState state;
}
+ (Player *)playerWithLocationID:(NSNumber *)locationIDOfADevice
						 inScene:(Scene *)theScene;
- (void)advanceTimeBySeconds:(CFAbsoluteTime)seconds;
- (AGPlayerState *)state; // because I'm returning a pointer, the struct can be modified by Scene
- (NSComparisonResult)compareAlpha:(Player *)otherPlayer;
- (NSComparisonResult)compareGreen:(Player *)otherPlayer;
@end
