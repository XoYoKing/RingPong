#import "AGHIDCalibrator.h"

typedef struct _ElementInfo {
	SInt32 minValue;
	SInt32 maxValue;
	SInt32 lowestValueEncountered;
	SInt32 highestValueEncountered;
} ElementInfo;


@implementation AGHIDCalibrator

+ (AGHIDCalibrator *)calibratorWithDevice:(NSNumber *)locationIDOfDevice {
	AGHIDCalibrator *calibrator = [[AGHIDCalibrator alloc] initWithDevice:locationIDOfDevice];
	return [calibrator autorelease];
}


- (AGHIDCalibrator *)initWithDevice:(NSNumber *)locationIDOfDevice {
	if (self = [super init]) {
		locationID = [locationIDOfDevice retain];
		registry = [[NSMutableDictionary alloc] init];
	}
	return self;
}

/*

- (BOOL)hasPreviouslyEncounteredElement:(NSNumber *)cookie
				   belongingToInterface:(NSNumber *)interfaceNumber {
	NSDictionary *interface = [registry objectForKey:interfaceNumber];
	if (interface == nil) {
		return NO;
	}
	if ([interface objectForKey:cookie] == nil) {
		return NO;
	}
	return YES;
}

*/

// minValue and maxValue only have an effect the first time
// this is called for a given element
- (double)calibratedValueForElement:(NSNumber *)cookie
			   belongingToInterface:(NSNumber *)interfaceNumber
					  givenRawValue:(SInt32)rawValue
					  usingMinValue:(SInt32)minValue
						   maxValue:(SInt32)maxValue {
	NSValue *wrappedElementInfo;
	ElementInfo *elementInfo;
	NSMutableDictionary *interface = [registry objectForKey:interfaceNumber];
	if (interface == nil) {
		interface = [NSMutableDictionary dictionary];
		[registry setObject:interface
					 forKey:interfaceNumber];
	}
	wrappedElementInfo = [interface objectForKey:cookie];
	if (wrappedElementInfo == nil) {
		elementInfo = malloc(sizeof(ElementInfo));
		if (elementInfo == NULL) {
			return 0.0; //the safest value to return in most cases
		}
		elementInfo->minValue = minValue;
		elementInfo->maxValue = maxValue;
		elementInfo->lowestValueEncountered = minValue + ((maxValue - minValue) / 2);
		elementInfo->highestValueEncountered = elementInfo->lowestValueEncountered + 1;	
		wrappedElementInfo = [NSValue valueWithPointer:elementInfo];
		[interface setObject:wrappedElementInfo
					  forKey:cookie];
	} else {
		elementInfo = (ElementInfo *)[wrappedElementInfo pointerValue];
	}
	if (rawValue < elementInfo->lowestValueEncountered) {
		elementInfo->lowestValueEncountered = rawValue;
	}
	else if (rawValue > elementInfo->highestValueEncountered) {
		elementInfo->highestValueEncountered = rawValue;
	}
	double calibratedValue =
		(rawValue - elementInfo->lowestValueEncountered) /
		(double)(elementInfo->highestValueEncountered - elementInfo->lowestValueEncountered);
	calibratedValue = (2 * calibratedValue) - 1.0;
	return calibratedValue;
}


- (void)dealloc {
	NSArray *interfaces = [registry allValues];
	NSUInteger i, count = [interfaces count];
	for (i = 0; i < count; i++) {
		NSDictionary *interface = [interfaces objectAtIndex:i];
		NSArray *elements = [interface allValues];
		NSUInteger j, numElements = [interfaces count];
		for (j = 0; j < numElements; j++) {
			ElementInfo *elementInfo = [[elements objectAtIndex:j] pointerValue];
			free(elementInfo);
		}
	}
	[registry release];
	[locationID release];
	[super dealloc];
}

@end
