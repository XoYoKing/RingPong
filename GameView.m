#import "GameView.h"
#import "Metrics.h"


@implementation GameView

- (id)initWithFrame:(NSRect)frameRect {
	NSOpenGLPixelFormatAttribute pixelFormatAttributes [] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFAPixelBuffer,
        NSOpenGLPFASampleBuffers, (NSOpenGLPixelFormatAttribute)8,
        NSOpenGLPFASamples, (NSOpenGLPixelFormatAttribute)32,
        NSOpenGLPFAMultisample,
        NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute)32,
        (NSOpenGLPixelFormatAttribute)nil
    };
	NSOpenGLPixelFormat *pixelFormat = 
		[[[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes] autorelease];
	
    self = [super initWithFrame:frameRect
					pixelFormat:pixelFormat];
    return self;
}


- (void)reshape {
	[scene setViewportRect:[self bounds]];
}


- (void)drawRect:(NSRect)rect {
	// called after a reshape
	// I shouldn't be advancing the scene time... maybe have an alternative render method?
	[scene render];
}


- (void)viewWillStartLiveResize {
	[scene pause];
}


- (void)viewDidEndLiveResize {
	[scene unpause];
}


- (void)dealloc {
	[super dealloc];
}

@end
