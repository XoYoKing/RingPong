#import <Foundation/Foundation.h>

@interface AGHIDCalibrator : NSObject {
	NSNumber *locationID;
	NSMutableDictionary *registry;
}

+ (AGHIDCalibrator *)calibratorWithDevice:(NSNumber *)locationIDOfDevice;

- (AGHIDCalibrator *)initWithDevice:(NSNumber *)locationIDOfDevice;

/*
- (BOOL)hasPreviouslyEncounteredElement:(NSNumber *)cookie
				   belongingToInterface:(NSNumber *)interfaceNumber;
*/

- (double)calibratedValueForElement:(NSNumber *)cookie
			   belongingToInterface:(NSNumber *)interfaceNumber
					  givenRawValue:(SInt32)rawValue
					  usingMinValue:(SInt32)minValue
						   maxValue:(SInt32)maxValue;
@end
