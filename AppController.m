#import "AppController.h"


@interface AppController (PrivateAPI)
- (void)refresh:(NSTimer *)timer;
@end


@implementation AppController

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
								   shareContext:[view openGLContext]];
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
	
	
	[scene setCurrentGLContext:[view openGLContext]];
	[scene loadCallLists];
	
	refreshTimer = [[NSTimer scheduledTimerWithTimeInterval:timeBetweenFrames
													 target:self
												   selector:@selector(refresh:)
												   userInfo:nil
													repeats:YES] retain];
}


- (void)refresh:(NSTimer *)timer {
	//if ([scene isAnimated]) {
		[scene render];
	//}
	
	/*
	if ([scene thereIsAGameInProgress]) {
		[scene render];
	}*/
}


- (IBAction)toggleFullScreen:(id)sender {
	if (fullScreen) {
        [fullScreenContext clearDrawable];
		[scene setCurrentGLContext:[view openGLContext]];
		CGDisplayShowCursor(kCGDirectMainDisplay);
        CGReleaseAllDisplays();
		[scene render];
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
		[scene setCurrentGLContext:fullScreenContext];
		NSRect fullScreenRect =
			NSMakeRect(0, 0, CGDisplayPixelsWide(kCGDirectMainDisplay), CGDisplayPixelsHigh(kCGDirectMainDisplay));
		[scene setViewportRect:fullScreenRect];
		[scene render];
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
