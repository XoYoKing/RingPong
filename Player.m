#import "Player.h"
#import "Scene.h"
#import "Metrics.h"

// used only for UpdateSystemActivity(UsrActivity);
// #import <CoreServices/CoreServices.h>


@interface Player (PrivateAPI)
- (Player *)initWithLocationID:(NSNumber *)locationIDOfADevice
					   inScene:(Scene *)theScene;
@end


@implementation Player

// looks done
+ (Player *)playerWithLocationID:(NSNumber *)locationIDOfADevice
						 inScene:(Scene *)theScene {
	return [[[Player alloc] initWithLocationID:locationIDOfADevice
									   inScene:theScene] autorelease];
}


// looks done
- (Player *)initWithLocationID:(NSNumber *)locationIDOfADevice
					   inScene:(Scene *)theScene {
	if (self = [super init]) {
		locationID = [locationIDOfADevice retain];
		scene = [theScene retain];
		calibrator = [[AGHIDCalibrator calibratorWithDevice:locationID] retain];
		manager = [[AGHIDManager alloc] init];
		[manager selectDeviceHavingLocationID:locationID];
		[manager setDelegate:self];
		state.code = AG_PLAYER_STATE_NOT_PLAYING;
		state.angle = random() % 360;
	}
	return self;
}


// looks done
- (void)advanceTimeBySeconds:(CFAbsoluteTime)seconds {
	elapsedTime = seconds;
	// this will freeze the player's position if they lost
	if (state.code == AG_PLAYER_STATE_CURRENT ||
		state.code == AG_PLAYER_STATE_NOT_CURRENT) {
		state.angle = fmod(state.angle + (state.angularSpeed * elapsedTime * MAX_PADDLE_SPEED), 360);
		if (state.angle < 0) {
			state.angle += 360;
		}
	}
	
	// Be careful of time reversals here!
	// Don't call this method to do a time reversal.
	// Instead, inline the above 4 lines.
	
	// toothpaste green
	// glColor4f(0.5, 1.0, 1.0, 1.0);
	
	// 75% transparent violet
	// glColor4f(0.5, 0.25, 1.0, 0.75);
	
	switch (state.code) {
		case AG_PLAYER_STATE_CURRENT:
		{
			if (state.green == 1.0) {
				if (state.alpha != 1.0) {
					// increase alpha at 100% rate
					state.alpha += AG_FADE_RATE * elapsedTime;
					if (state.alpha > 1.0) {
						state.alpha = 1.0;
					}
				}
			} else {
				// x-fade from violet to green
				state.green += 0.75 * AG_FADE_RATE * elapsedTime;
				if (state.green > 1.0) {
					state.green = 1.0;
				}
				// increase alpha... I have yet to determine a rate! (what if alpha is currently 15%)
				// I could just use 75%.... it should be close enough (it will take a little longer to fade in)
				state.alpha += 0.75 * AG_FADE_RATE * elapsedTime;
				if (state.alpha > 1.0) {
					state.alpha = 1.0;
				}
			}
			break;
		}
		case AG_PLAYER_STATE_NOT_CURRENT:
		{
			if (state.green == 0.25) {
				if (state.alpha != 0.75) {
					// increase alpha at 75% rate
					state.alpha += 0.75 * AG_FADE_RATE * elapsedTime;
					if (state.alpha > 0.75) {
						state.alpha = 0.75;
					}
				}
			} else {
				// x-fade from green to violet
				state.green -= 0.75 * AG_FADE_RATE * elapsedTime;
				if (state.green < 0.25) {
					state.green = 0.25;
				}
				// decrease alpha at 25% rate
				state.alpha -= 0.25 * AG_FADE_RATE * elapsedTime;
				if (state.alpha < 0.75) {
					state.alpha = 0.75;
				}
			}
			break;
		}
		case AG_PLAYER_STATE_LOST:
		{
			if (state.red != 1.0) {
				state.red = 1.0;
				state.green = 0.0;
				state.blue = 0.0;
			}
			// decrease alpha at a slow rate (EG. 10%)
			state.alpha -= AG_LOSER_FADE_RATE * elapsedTime;
			if (state.alpha < 0.0) {
				state.alpha = 0.0;
				state.code = AG_PLAYER_STATE_NOT_PLAYING;
				Player *nextPlayer = [scene playerAfterPlayer:self];
				if (nextPlayer != nil) {
					[nextPlayer state]->code = AG_PLAYER_STATE_CURRENT;
					[scene serveAnotherBall];
				}
			}
			break;
		}
		case AG_PLAYER_STATE_QUIT_CURRENT:
		{
			// reduce alpha at different rates depending on color (between 75% and 100%)
			state.alpha -= (1.0 - (state.green - 1.0) * 0.3333) * AG_LOSER_FADE_RATE * elapsedTime;
			if (state.alpha < 0.0) {
				state.alpha = 0.0;
				state.code = AG_PLAYER_STATE_NOT_PLAYING;
				Player *nextPlayer = [scene playerAfterPlayer:self];
				if (nextPlayer != nil) {
					[nextPlayer state]->code = AG_PLAYER_STATE_CURRENT;
					[scene serveAnotherBall];
				}
			}
		}
		case AG_PLAYER_STATE_QUIT_NOT_CURRENT:
		{
			// reduce alpha at different rates depending on color (between 75% and 100%)
			state.alpha -= (1.0 - (state.green - 1.0) * 0.3333) * AG_LOSER_FADE_RATE * elapsedTime;
			if (state.alpha < 0.0) {
				state.alpha = 0.0;
				state.code = AG_PLAYER_STATE_NOT_PLAYING;
			}
		}
	}
}


// done
- (AGPlayerState *)state {
	return &state;
}


// maybe I should use greeness instead, or a combination of the two?
- (NSComparisonResult)compareAlpha:(Player *)otherPlayer {
	float alphaOfSelf = state.alpha;
	float alphaOfOther = [otherPlayer state]->alpha;
	if (alphaOfSelf > alphaOfOther) return NSOrderedAscending;
	if (alphaOfSelf == alphaOfOther) return NSOrderedSame;
	return NSOrderedDescending;
}

// alternative to alpha compare
- (NSComparisonResult)compareGreen:(Player *)otherPlayer {
	float greenOfSelf = state.green;
	float greenOfOther = [otherPlayer state]->green;
	if (greenOfSelf > greenOfOther) return NSOrderedAscending;
	if (greenOfSelf == greenOfOther) return NSOrderedSame;
	return NSOrderedDescending;
}


- (void)elementHavingPage:(UInt16)page
					usage:(UInt16)usage
				   cookie:(NSNumber *)cookie
				 minValue:(SInt32)minValue
				 maxValue:(SInt32)maxValue
	  fromInterfaceNumber:(NSNumber *)interfaceNumber
		   didReportValue:(SInt32)value
				toManager:(AGHIDManager *)manager
	 whereValueIsRelative:(BOOL)isRelative {
	
	if (page == kHIDPage_Button && value == 1) {
		if (![scene gameHasStarted]) {
			if (state.code == AG_PLAYER_STATE_NOT_PLAYING) {
				// join game
				state.code = AG_PLAYER_STATE_NOT_CURRENT;
				// violet, 0% opacity
				state.red = 0.5;
				state.green = 0.25;
				state.blue = 1.0;
				state.alpha = 0.0;
				[scene beginAnimationIfNecessary];
			} else {
				state.code = AG_PLAYER_STATE_CURRENT; // the player who initiates the game gets to play first
				[scene startGame];
			}
		}
		CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
		if (now - lastSystemActivityUpdate > 30.0) {
			// prevent system from going to sleep
			UpdateSystemActivity(UsrActivity);
			lastSystemActivityUpdate = now;
		}
	} else if (page == kHIDPage_GenericDesktop && usage == kHIDUsage_GD_X) {
		if (state.code != AG_PLAYER_STATE_NOT_PLAYING) {
			CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
			if (now - lastSystemActivityUpdate > 30.0) {
				// prevent system from going to sleep
				UpdateSystemActivity(UsrActivity);
				lastSystemActivityUpdate = now;
			}
		}
		
		double calibratedValue;
		
		// display message about moving joystick if the game hasn't started yet?
		/*
		 // this block is optional:
		 [calibrator calibratedValueForElement:cookie
						  belongingToInterface:interfaceNumber
								 givenRawValue:minValue + (maxValue / 4)
								 usingMinValue:minValue
									  maxValue:maxValue];
		 [calibrator calibratedValueForElement:cookie
						  belongingToInterface:interfaceNumber
								 givenRawValue:maxValue - (maxValue / 4)
								 usingMinValue:minValue
									  maxValue:maxValue];
		 
		 calibratedValue = [calibrator calibratedValueForElement:cookie
											belongingToInterface:interfaceNumber
												   givenRawValue:value
												   usingMinValue:minValue
														maxValue:maxValue];
		 */
		// bypass the calibration mechanism for now:
		calibratedValue = (2 * (value / (double)255)) - 1.0;
		state.angularSpeed = -calibratedValue * calibratedValue * calibratedValue;
	}
}


- (void)deviceListDidChangeForHIDManager:(AGHIDManager *)m {
	NSArray *newLocationIDs = [manager deviceList];
	if (![newLocationIDs containsObject:locationID]) {
		if (state.code == AG_PLAYER_STATE_NOT_CURRENT) {
			state.code = AG_PLAYER_STATE_QUIT_NOT_CURRENT;
		} else if (state.code == AG_PLAYER_STATE_CURRENT) {
			state.code = AG_PLAYER_STATE_QUIT_CURRENT;
		}
	}
}


- (void)dealloc {
	[manager release];
	[calibrator release];
	[scene release];
	[locationID release];
	[super dealloc];
}

@end
