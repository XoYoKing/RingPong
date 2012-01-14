//
//  AGAppDelegate.h
//  RingPong
//
//  Created by splicer on 12-01-13.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GameView.h"
#import "Scene.h"

@interface AGAppDelegate : NSObject <NSApplicationDelegate> {
    NSTimer *refreshTimer;
	float timeBetweenFrames;
	NSOpenGLContext *fullScreenContext;
	BOOL fullScreen;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet GameView *view;
@property (assign) IBOutlet Scene *scene;

- (IBAction)toggleFullScreen:(id)sender;
@end

