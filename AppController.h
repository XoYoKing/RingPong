#import <Cocoa/Cocoa.h>
#import "GameView.h"
#import "Scene.h"


@interface AppController : NSObject {
    IBOutlet GameView *view;
	IBOutlet Scene *scene;
	NSTimer *refreshTimer;
	float timeBetweenFrames;
	NSOpenGLContext *fullScreenContext;
	BOOL fullScreen;
}
- (IBAction)toggleFullScreen:(id)sender;
@end
