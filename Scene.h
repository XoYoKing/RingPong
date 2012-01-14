//#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import "Ball.h"
#import "Player.h"


@interface Scene : NSObject {
	AGHIDManager *ceo;
	NSMutableDictionary *allPlayers;
	
	NSArray *playersForThisRound;
	unsigned int numPlayersForThisRound;
	
	Ball *ball;
	BOOL ballIsOutOfBounds;
	double angleOfLoser;
	float presenceOfLoser;
	float presenceOfBall;
	CFAbsoluteTime previousTime;
	BOOL isPaused;
	GLUquadric *quad;
	GLuint ringList, paddleList;
	NSOpenGLContext *currentGLContext;
	
	BOOL thereArePlayersToAnimate;
}

- (void)loadCallLists; // maybe have an internal variable named isPrepared instead...

- (void)startGame;
- (void)serveAnotherBall;

- (Player *)playerAfterPlayer:(Player *)currentPlayer;

- (void)beginAnimationIfNecessary;
- (void)render;
- (void)pause;
- (void)unpause;
- (void)setCurrentGLContext:(NSOpenGLContext *)context;
- (void)setViewportRect:(NSRect)bounds;
//- (BOOL)thereIsAGameInProgress;
- (BOOL)isAnimated;
- (BOOL)gameHasStarted;
//- (void)updateIndexOfCurrentPlayer;
@end
