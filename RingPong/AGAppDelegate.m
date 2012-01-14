//
//  AGAppDelegate.m
//  RingPong
//
//  Created by splicer on 12-01-13.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AGAppDelegate.h"

@interface AGAppDelegate (PrivateAPI)
- (void)refresh:(NSTimer *)timer;
@end

@implementation AGAppDelegate

@synthesize window = _window;
@synthesize view = _view;
@synthesize scene = _scene;


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

- (id)init {
	if (self = [super init]) {
	}
	return self;
}


- (void)awakeFromNib {
	// Create the full screen context
	NSOpenGLPixelFormatAttribute attrs[] = {
		NSOpenGLPFAFullScreen,
        NSOpenGLPFASingleRenderer,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
        NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		0
	};
	NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
	fullScreenContext =
    [[NSOpenGLContext alloc] initWithFormat:pixelFormat
                               shareContext:[_view openGLContext]];
	[pixelFormat release];
	
	// see file:///Developer/ADC%20Reference%20Library/documentation/Performance/Conceptual/Drawing/Articles/FlushingContent.html
	float refreshRate = 60; // Assume LCD screen
    /*
     //CGDisplayModeRef displayMode = CGDisplayCopyDisplayMode(CGMainDisplayID());
     CGDisplayModeRef displayMode = CGDisplayCopyDisplayMode(kCGDirectMainDisplay);
     if (modeInfo) {
     CFNumberRef value = (CFNumberRef) CFDictionaryGetValue(modeInfo, kCGDisplayRefreshRate);
     if (value) {
     CFNumberGetValue(value, kCFNumberFloatType, &refreshRate);
     if (refreshRate == 0) refreshRate = 60; // Assume LCD screen
     CFRelease(value);
     }
     }*/
	timeBetweenFrames = 1.0 / refreshRate;
	
	
	[_scene setCurrentGLContext:[_view openGLContext]];
	[_scene loadCallLists];
	
	refreshTimer = [[NSTimer scheduledTimerWithTimeInterval:timeBetweenFrames
													 target:self
												   selector:@selector(refresh:)
												   userInfo:nil
													repeats:YES] retain];
}


- (void)refresh:(NSTimer *)timer {
	//if ([_scene isAnimated]) {
    [_scene render];
	//}
	
	/*
     if ([_scene thereIsAGameInProgress]) {
     [_scene render];
     }*/
}


- (IBAction)toggleFullScreen:(id)sender {
	if (fullScreen) {
        [fullScreenContext clearDrawable];
		[_scene setCurrentGLContext:[_view openGLContext]];
		CGDisplayShowCursor(kCGDirectMainDisplay);
        CGReleaseAllDisplays();
		[_scene render];
        fullScreen = NO;
		/*
         DMRemoveExtendedNotifyProc(<#DMExtendedNotificationUPP notifyProc#>,
         <#void * notifyUserData#>,
         <#DMProcessInfoPtr whichPSN#>,
         NULL);*/
    } else {
        CGCaptureAllDisplays();
		CGDisplayHideCursor(kCGDirectMainDisplay);
        [fullScreenContext setFullScreen];
		[_scene setCurrentGLContext:fullScreenContext];
		NSRect fullScreenRect =
        NSMakeRect(0, 0, CGDisplayPixelsWide(kCGDirectMainDisplay), CGDisplayPixelsHigh(kCGDirectMainDisplay));
		[_scene setViewportRect:fullScreenRect];
		[_scene render];
        fullScreen = YES;
		/*
         // use kDMNotifyDisplayWillSleep in proc
         DMRegisterExtendedNotifyProc(<#DMExtendedNotificationUPP notifyProc#>,
         <#void * notifyUserData#>,
         <#unsigned short nofifyOnFlags#>,
         <#DMProcessInfoPtr whichPSN#>);*/
    }
}


// Note: I needed to set this AppController to be the delegate of NSApp (File's Owner) in Interface Builder
- (void)applicationWillTerminate:(NSNotification *)aNotification {
	if (fullScreen) {
		CGDisplayShowCursor(kCGDirectMainDisplay); // unnecessary, but I might as well be explicit
		// Clear the front and back framebuffers before switching out of FullScreen mode.
		// This avoids an untidy flash of garbage.
		glClearColor(0.0, 0.0, 0.0, 0.0);
		glClear(GL_COLOR_BUFFER_BIT);
		[fullScreenContext flushBuffer];
		glClear(GL_COLOR_BUFFER_BIT);
		[fullScreenContext flushBuffer];
	}
}

/*
 - (void)applicationDidChangeScreenParameters:(NSNotification *)aNotification {
 
 }
 */

- (void)dealloc {
	[refreshTimer invalidate];
	[refreshTimer release];
	[super dealloc];
}

@end
