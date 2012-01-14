#import "Scene.h"
#import "Metrics.h"


@interface Scene (PrivateAPI)
- (void)endGame;
@end


@implementation Scene

- (id)init {
	if (self = [super init]) {
        srandomdev();
		allPlayers = [[NSMutableDictionary alloc] init];
		ceo = [[AGHIDManager alloc] init];
		[ceo setDelegate:self];
		[ceo setDeviceMatchingCriteria:AG_CRITERIA_FOR_JOYSTICKS_AND_GAMEPADS];
		
		previousTime = CFAbsoluteTimeGetCurrent();
		
		//[self prepare]; //maybe...
	}
	return self;
}


- (void)deviceListDidChangeForHIDManager:(AGHIDManager *)manager {
	NSArray *newLocationIDs = [manager deviceList];
	NSUInteger i, count = [newLocationIDs count];
	for (i = 0; i < count; i++) {
		NSNumber *locationID = [newLocationIDs objectAtIndex:i];
		if ([allPlayers objectForKey:locationID] == nil) {
			[allPlayers setObject:[Player playerWithLocationID:locationID
													   inScene:self]
						   forKey:locationID];
		}
	}
}


// must have a context first!
- (void)loadCallLists {
	// begin ringList
	ringList = glGenLists(1);
	glNewList(ringList, GL_COMPILE);
	glColor3f(0.0, 0.5, 1.0);
	gluDisk(quad,
			RING_RADIUS - RING_HALF_THICKNESS,
			RING_RADIUS + RING_HALF_THICKNESS,
			96,
			1);
	glEndList();
	// end ringList
	// begin paddleList
	paddleList = glGenLists(1);
	glNewList(paddleList, GL_COMPILE);
	gluPartialDisk(quad,
				   RING_RADIUS - PADDLE_HALF_THICKNESS,
				   RING_RADIUS + PADDLE_HALF_THICKNESS,
				   8,
				   1,
				   90 - PADDLE_LENGTH,
				   PADDLE_LENGTH);
	// begin round ends
	glTranslated(0.4, 0.0, 0.0);
	gluPartialDisk(quad,
				   0,
				   PADDLE_HALF_THICKNESS,
				   16,
				   1,
				   90,
				   180);
	glTranslated(-0.4, 0.0, 0.0);
	glRotated(PADDLE_LENGTH, 0.0, 0.0, 1.0);
	glTranslated(0.4, 0.0, 0.0);
	gluPartialDisk(quad,
				   0,
				   PADDLE_HALF_THICKNESS,
				   16,
				   1,
				   270,
				   180);
	glTranslated(-0.4, 0.0, 0.0);
	glRotated(-PADDLE_LENGTH, 0.0, 0.0, 1.0);
	// end round ends
	glEndList();
	// end paddleList
}


- (void)startGame {
	playersForThisRound = [[allPlayers allValues] retain];
	numPlayersForThisRound = [playersForThisRound count];
	//indexOfCurrentPlayer = 0;
	ball = [[Ball alloc] init];
}


- (void)endGame {
	[playersForThisRound release];
	playersForThisRound = nil;
	[ball release];
	ball = nil;
}


- (void)serveAnotherBall {
	[ball release];
	ball = [[Ball alloc] init];
}


// returns the next available player, or nil if none are available
- (Player *)playerAfterPlayer:(Player *)currentPlayer {
	NSUInteger indexOfCurrentPlayer = [playersForThisRound indexOfObject:currentPlayer];
	NSUInteger i;
	for (i = 0; i < numPlayersForThisRound; i++) {
		NSUInteger indexToCheck = (i + indexOfCurrentPlayer + 1) % numPlayersForThisRound;
		Player *playerToCheck = [playersForThisRound objectAtIndex:indexToCheck];
		unsigned int code = [playerToCheck state]->code;
		if (code == AG_PLAYER_STATE_NOT_CURRENT) {
			return playerToCheck;
		}
	}
	return nil;
}


- (void)beginAnimationIfNecessary {
	thereArePlayersToAnimate = YES;
}


// needs to be have ballIsOutOfBounds code scrutinized
- (void)render {
	glClear(GL_COLOR_BUFFER_BIT);
	glLoadIdentity();
	
	gluLookAt(0.0, 0.0, 1.0,
			  0.0, 0.0, 0.0,
			  0.0, 1.0, 0.0);
	
	CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
	CFAbsoluteTime elapsedTime = currentTime - previousTime;
	if (elapsedTime > 0.25 || isPaused) {
		// 0.25 could be substituted for another value > 0.0 and < 1.0, but 1/4 of a second seems to work well
		// pause game
		elapsedTime = 0.0;
	}
	previousTime = currentTime;
	
	float ballAlpha = 1.0;
	[ball advanceTimeBySeconds:elapsedTime];
	
	Player *currentPlayer = nil;
	Player *quitterCurrent = nil;
	Player *loser = nil;
	NSMutableArray *playersToRender = [[NSMutableArray alloc] init];
	NSEnumerator *playerEnumerator;
	if (playersForThisRound == nil) {
		playerEnumerator = [allPlayers objectEnumerator];
	} else {
		playerEnumerator = [playersForThisRound objectEnumerator];
	}
	Player *player;
	while (player = [playerEnumerator nextObject]) {
		[player advanceTimeBySeconds:elapsedTime];
		unsigned int code = [player state]->code;
		if (code == AG_PLAYER_STATE_NOT_PLAYING) {
			// don't do anything
		} else if (code == AG_PLAYER_STATE_LOST) {
			loser = [player retain];
		} else {
			[playersToRender addObject:player];
			if (code == AG_PLAYER_STATE_CURRENT) {
				currentPlayer = [player retain];
			}
			if (code == AG_PLAYER_STATE_QUIT_CURRENT) {
				quitterCurrent = [player retain];
			}
		}
	}
	
	if ([playersToRender count] == 0 && loser == nil) {
		[self endGame];
	} else {
		
		// sorts in ascending order (I might need descending instead)
		[playersToRender sortUsingSelector:@selector(compareGreen:)];
		
		
		// render the loser (if there is one)
		if (loser != nil) {
			AGPlayerState *state = [loser state];
			double angle = state->angle;
			// match ball's alpha to that of the loser
			ballAlpha = state->alpha;
			// set the colour for the player I'm about to render
			glColor4f(state->red,
					  state->green,
					  state->blue,
					  state->alpha);
			float sizeOfLoser = 1.0 - state->alpha;
			float paddleThicknessDifference = sizeOfLoser * PADDLE_HALF_THICKNESS * 0.5;
			gluPartialDisk(quad,
						   RING_RADIUS - PADDLE_HALF_THICKNESS - paddleThicknessDifference,
						   RING_RADIUS + PADDLE_HALF_THICKNESS + paddleThicknessDifference,
						   8,
						   1,
						   90 - angle - PADDLE_LENGTH - (sizeOfLoser * 10),
						   PADDLE_LENGTH + (sizeOfLoser * 20));
			// begin round ends
			glPushMatrix();
			glRotated(angle - (sizeOfLoser * 10), 0.0, 0.0, 1.0);
			glPushMatrix();
			glTranslated(0.4, 0.0, 0.0);
			gluPartialDisk(quad,
						   0,
						   PADDLE_HALF_THICKNESS + paddleThicknessDifference,
						   16,
						   1,
						   90,
						   180);
			glPopMatrix();
			glRotated(PADDLE_LENGTH + (sizeOfLoser * 20), 0.0, 0.0, 1.0);
			glTranslated(0.4, 0.0, 0.0);
			gluPartialDisk(quad,
						   0,
						   PADDLE_HALF_THICKNESS + paddleThicknessDifference,
						   16,
						   1,
						   270,
						   180);
			glPopMatrix();
		}
		
		// render all remaining players
		NSUInteger i, numberOfPlayersToRender = [playersToRender count];
		for (i = 0; i < numberOfPlayersToRender; i++) {
			Player *player = [playersToRender objectAtIndex:i];
			AGPlayerState *state = [player state];
			glColor4f(state->red,
					  state->green,
					  state->blue,
					  state->alpha);
			double angle = state->angle;
			glRotated(angle, 0.0, 0.0, 1.0);
			glCallList(paddleList);
			glRotated(-angle, 0.0, 0.0, 1.0);
		}
		
		if (currentPlayer != nil) {
			AGPlayerState *currentPlayerState = [currentPlayer state];
			if (currentPlayerState->code == AG_PLAYER_STATE_CURRENT) {
				[ball testForCollisionAgainstPlayer:currentPlayer];
				if (currentPlayerState->code == AG_PLAYER_STATE_NOT_CURRENT) {
					Player *nextPlayer = [self playerAfterPlayer:currentPlayer];
					if (nextPlayer != nil) {
						[nextPlayer state]->code = AG_PLAYER_STATE_CURRENT;
					}
				}
			}
		}
		
		if (quitterCurrent != nil) {
			ballAlpha = [quitterCurrent state]->alpha;
		}
		
		if (ball != nil) {
			// draw ball
			AGPoint ballPosition = [ball position];
			glColor4f(0.5, 1.0, 1.0, ballAlpha);
			glPushMatrix();
			glTranslated(ballPosition.x, ballPosition.y, 0);
			gluDisk(quad,
					0,
					BALL_RADIUS,
					16, // can be as low as 12
					1);
			glPopMatrix();
		}
		
	}
	
	// draw the ring
	glCallList(ringList);
	
	// flush to screen
	[currentGLContext flushBuffer];
	
	// memory cleanup
	[playersToRender release];
	[loser release];
	[quitterCurrent release];
	[currentPlayer release];
}


- (void)pause {
	isPaused = YES;
}


- (void)unpause {
	isPaused = NO;
}


- (void)setCurrentGLContext:(NSOpenGLContext *)context {
	gluDeleteQuadric(quad); // quadrics can't be shared between contexts
	[currentGLContext release];
	currentGLContext = [context retain];
	[currentGLContext makeCurrentContext];
	quad = gluNewQuadric(); // quadrics can't be shared between contexts
							// Clear the front and back framebuffers before switching out of FullScreen mode.
							// This avoids an untidy flash of garbage.
	glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    [currentGLContext flushBuffer];
    glClear(GL_COLOR_BUFFER_BIT);
    [currentGLContext flushBuffer];
	
	// sync to vertical refresh rate
	GLint newVBLState = 1;
	[currentGLContext setValues:&newVBLState
				   forParameter:NSOpenGLCPSwapInterval];
	
	glBlendFunc(GL_SRC_ALPHA_SATURATE, GL_ONE);
	glEnable(GL_BLEND);
	glEnable(GL_POLYGON_SMOOTH);
	//glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
	glHint(GL_POLYGON_SMOOTH_HINT, GL_FASTEST);
}


- (void)setViewportRect:(NSRect)bounds {
    glViewport( bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluPerspective(50.0, bounds.size.width/bounds.size.height, 0.1, 50.0);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}


- (BOOL)isAnimated {
	return thereArePlayersToAnimate;
}


- (BOOL)gameHasStarted {
	return (playersForThisRound != nil);
}


- (void)dealloc {
	[ball release];
	gluDeleteQuadric(quad);
	glDeleteLists(ringList, 1);
	glDeleteLists(paddleList, 1);
	[super dealloc];
}

@end
