// AGHIDManager requires Mac OS X v10.3 or later, as well as IOHIDLib v1.2.2 or later

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDKeys.h>
#import <IOKit/hid/IOHIDUsageTables.h>

// convenient macro
#define AG_CRITERIA_FOR_JOYSTICKS_AND_GAMEPADS \
[NSDictionary dictionaryWithObject:\
	[NSArray arrayWithObjects:\
		[NSDictionary dictionaryWithObjectsAndKeys:\
			[NSNumber numberWithLong:kHIDPage_GenericDesktop], @kIOHIDDeviceUsagePageKey,\
			[NSNumber numberWithLong:kHIDUsage_GD_GamePad], @kIOHIDDeviceUsageKey, nil],\
		[NSDictionary dictionaryWithObjectsAndKeys:\
			[NSNumber numberWithLong:kHIDPage_GenericDesktop], @kIOHIDDeviceUsagePageKey,\
			[NSNumber numberWithLong:kHIDUsage_GD_Joystick], @kIOHIDDeviceUsageKey, nil], nil]\
							forKey:@kIOHIDDeviceUsagePairsKey]


@interface AGHIDManager : NSObject {
	NSNumber *locationIDOfSelectedDevice;
	id delegate;
	NSDictionary *deviceMatchingCriteria;
	NSSet *deviceSet;
	NSSet *previousDeviceSet;
}
+ (NSString *)nameOfDeviceHavingLocationID:(NSNumber *)locationID;
- (void)setDeviceMatchingCriteria:(NSDictionary *)criteria;
- (NSArray *)deviceList;
- (void)selectDeviceHavingLocationID:(NSNumber *)locationID;
- (NSNumber *)locationIDOfSelectedDevice;
- (NSString *)nameOfSelectedDevice;
- (BOOL)selectedDeviceIsConnected;
- (void)setDelegate:(id)newDelegate;
- (id)delegate;
@end


// methods which the delegate should implement
@interface NSObject (AGHIDManagerDelegate)
- (void)deviceListDidChangeForHIDManager:(AGHIDManager *)manager;
- (void)elementHavingPage:(UInt16)page
					usage:(UInt16)usage
				   cookie:(NSNumber *)cookie
				 minValue:(SInt32)minValue
				 maxValue:(SInt32)maxValue
	  fromInterfaceNumber:(NSNumber *)interfaceNumber
		   didReportValue:(SInt32)value
				toManager:(AGHIDManager *)manager
	 whereValueIsRelative:(BOOL)isRelative;
@end
