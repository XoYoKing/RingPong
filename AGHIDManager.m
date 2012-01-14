#import "AGHIDManager.h"
#import <IOKit/hid/IOHIDLib.h>
#import <IOKit/IOCFPlugin.h>
#import <pthread.h>

#define AG_MAX_QUEUE_SIZE 16


// a pointer to this will be wrapped in an NSValue
typedef struct _Connector {
	IOHIDDeviceInterface **interface;
	IOHIDQueueInterface **queue;
	CFRunLoopSourceRef runLoopSource;
} Connector;


#pragma mark Class Variables

static NSString *AG_NAME_KEY;
static NSString *AG_INTERFACE_NUMBER_KEY;
static NSString *AG_INTERFACES_KEY;
static NSString *AG_MANAGERS_KEY;
static NSString *AG_CONNECTOR_KEY;
static NSString *AG_ELEMENTS_KEY;
static NSString *AG_ELEMENT_PAGE_KEY;
static NSString *AG_ELEMENT_USAGE_KEY;
static NSString *AG_ELEMENT_MIN_KEY;
static NSString *AG_ELEMENT_MAX_KEY;
static NSString *AG_ELEMENT_IS_RELATIVE_KEY;
static NSMutableDictionary *devices;
static NSMutableSet *currentlyAttachedDevices;
static NSMutableArray *managers;
static CFRunLoopRef notificationRunLoop;


#pragma mark Function Declarations

static void hidWasAddedCallback(void *refCon, io_iterator_t iterator);
static void hidWasRemovedCallback(void *refCon, io_iterator_t iterator);
void eventCallback(void *target, IOReturn result, void *refcon, void *sender);
static void MyCreateHIDDeviceInterface(io_object_t hidDevice,
									   IOHIDDeviceInterface ***hidDeviceInterface);


@interface AGHIDManager (PrivateAPI)
+ (void)connect:(NSNumber *)locationID;
+ (void)disconnect:(NSNumber *)locationID;
+ (BOOL)deviceIsConnected:(NSNumber *)locationID;
+ (void)addDeviceHavingLocationID:(NSNumber *)locationID; //probably better than addInterface(io_object_t interface)
+ (NSNumber *)locationIDOfHIDInterface:(io_object_t *)hidInterface;
- (void)updateDeviceSet;
- (NSSet *)deviceSet;
- (NSSet *)previousDeviceSet;
@end


@implementation AGHIDManager

#pragma mark Class Methods

+ (void)initialize {
	AG_NAME_KEY = [@"name" retain];
	AG_INTERFACE_NUMBER_KEY = [@"interface number" retain];
	AG_INTERFACES_KEY = [@"interfaces" retain];
	AG_MANAGERS_KEY = [@"managers" retain];
	AG_CONNECTOR_KEY = [@"connector" retain];
	AG_ELEMENTS_KEY = [@"elements" retain];
	AG_ELEMENT_PAGE_KEY = [@kIOHIDElementUsagePageKey retain];
	AG_ELEMENT_USAGE_KEY = [@kIOHIDElementUsageKey retain];
	AG_ELEMENT_MIN_KEY = [@kIOHIDElementMinKey retain];
	AG_ELEMENT_MAX_KEY = [@kIOHIDElementMaxKey retain];
	AG_ELEMENT_IS_RELATIVE_KEY = [@kIOHIDElementIsRelativeKey retain];
	
	devices = [[NSMutableDictionary alloc] init];
	currentlyAttachedDevices = [[NSMutableSet alloc] init];
	
	// initialize the managers array in such a way that it will hold
	// weak references to each manager object
	CFArrayCallBacks arrayCallbacks = kCFTypeArrayCallBacks;
	arrayCallbacks.retain = NULL;
	arrayCallbacks.release = NULL;
	managers = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, &arrayCallbacks);
	
	notificationRunLoop = CFRunLoopGetCurrent();
	// Note: kIOMasterPortDefault requires Mac OS 10.2 (Jaguar) or later
	IONotificationPortRef notificationObject = IONotificationPortCreate(kIOMasterPortDefault);
	CFRunLoopSourceRef notificationRunLoopSource = IONotificationPortGetRunLoopSource(notificationObject);
	CFRunLoopAddSource(notificationRunLoop, notificationRunLoopSource, kCFRunLoopDefaultMode);
	CFMutableDictionaryRef hidDeviceMatchingDictionary = IOServiceMatching(kIOHIDDeviceKey);
	// IOServiceAddMatchingNotification consumes a reference to the matching dictionary,
	// so I need to retain hidDeviceMatchingDictionary in order to use it twice
	CFRetain(hidDeviceMatchingDictionary);
	io_iterator_t deviceAddedIterator, deviceRemovedIterator;
	IOServiceAddMatchingNotification(notificationObject,
									 kIOPublishNotification,
									 hidDeviceMatchingDictionary,
									 &hidWasAddedCallback,
									 NULL,
									 &deviceAddedIterator);
	IOServiceAddMatchingNotification(notificationObject,
									 kIOTerminatedNotification,
									 hidDeviceMatchingDictionary,
									 &hidWasRemovedCallback,
									 NULL,
									 &deviceRemovedIterator);
	// add present devices, and arm the notification system
	NSMutableArray *presentLocationIDs = [NSMutableArray array];
	io_object_t hidInterface;
	while (hidInterface = IOIteratorNext(deviceAddedIterator)) {
		NSNumber *locationID = [AGHIDManager locationIDOfHIDInterface:&hidInterface];
		IOObjectRelease(hidInterface);
		if (locationID && ![presentLocationIDs containsObject:locationID]) {
			[presentLocationIDs addObject:locationID];
		}
	}
	while (hidInterface = IOIteratorNext(deviceRemovedIterator)) {
		// we shouldn't ever enter this block
		IOObjectRelease(hidInterface);
	}
	unsigned int i, count = [presentLocationIDs count];
	for (i = 0; i < count; i++) {
		NSNumber *locationID = [presentLocationIDs objectAtIndex:i];
		[AGHIDManager addDeviceHavingLocationID:locationID];
		// only add to currentlyAttachedDevices if +addDeviceHavingLocationID
		// was successful
		if ([devices objectForKey:locationID] != nil) {
			[currentlyAttachedDevices addObject:locationID];
		}
	}
}


// returns nil if device not found
+ (NSString *)nameOfDeviceHavingLocationID:(NSNumber *)locationID {
	return [[devices objectForKey:locationID] valueForKey:AG_NAME_KEY];
}


// Assumtions:
//   - device has been added (so it's not nil)
//   - device is currently disconnected
//   - device is physically attached
//   connector->interface == NULL
//   connector->queue == NULL
+ (void)connect:(NSNumber *)locationID {
	NSDictionary *device = [devices objectForKey:locationID];
	
	//NSLog(@"connecting to %@ (%@)",
	//	  locationID,
	//	  [device valueForKey:AG_NAME_KEY]);
	
	NSArray *interfaces = [device valueForKey:AG_INTERFACES_KEY];
	io_iterator_t iterator;
	io_object_t ioInterface;
	CFMutableDictionaryRef matchLocation = IOServiceMatching(kIOHIDDeviceKey);
	CFDictionarySetValue(matchLocation,
						 CFSTR(kIOHIDLocationIDKey),
						 locationID);
	IOServiceGetMatchingServices(kIOMasterPortDefault,
								 matchLocation,
								 &iterator);
	unsigned int i, count = [interfaces count];
	for (i = 0; i < count; i++) {
		IOReturn result;
		ioInterface = IOIteratorNext(iterator);
		if (ioInterface == 0) {
			break;
		}
		NSDictionary *interface = [interfaces objectAtIndex:i];
		NSDictionary *elements = [interface valueForKey:AG_ELEMENTS_KEY];
		NSValue *wrappedConnector = [interface valueForKey:AG_CONNECTOR_KEY];
		Connector *connector = (Connector *)[wrappedConnector pointerValue];
		MyCreateHIDDeviceInterface(ioInterface, (IOHIDDeviceInterface ***)&(connector->interface));
		IOObjectRelease(ioInterface);
		if (connector->interface == NULL) {
			break;
		}
		// create and set up the queue
		result = (*(connector->interface))->open(connector->interface, 0);
		if (result != kIOReturnSuccess) {
			(*(connector->interface))->Release(connector->interface);
			connector->interface = NULL;
			break;
		}
		connector->queue = (*(connector->interface))->allocQueue(connector->interface);
		result = (*(connector->queue))->create(connector->queue,
											   0,
											   AG_MAX_QUEUE_SIZE);
		if (result != kIOReturnSuccess) {
			(*(connector->queue))->Release(connector->queue);
			(*(connector->interface))->close(connector->interface);
			(*(connector->interface))->Release(connector->interface);
			connector->interface = NULL;
			connector->queue = NULL;
			break;
		}
		result = (*(connector->queue))->createAsyncEventSource(connector->queue,
															   &(connector->runLoopSource));
		if (result != kIOReturnSuccess) {
			(*(connector->queue))->dispose(connector->queue);
			(*(connector->queue))->Release(connector->queue);
			(*(connector->interface))->close(connector->interface);
			(*(connector->interface))->Release(connector->interface);
			connector->interface = NULL;
			connector->queue = NULL;
			break;
		}
		CFRunLoopAddSource(notificationRunLoop,
						   connector->runLoopSource,
						   kCFRunLoopDefaultMode);
		CFRelease(connector->runLoopSource);
		result = (*(connector->queue))->setEventCallout(connector->queue,
														&eventCallback,
														[device valueForKey:AG_MANAGERS_KEY],
														interface);
		if (result != kIOReturnSuccess) {
			CFRunLoopRemoveSource(notificationRunLoop,
								  connector->runLoopSource,
								  kCFRunLoopDefaultMode);
			(*(connector->queue))->dispose(connector->queue);
			(*(connector->queue))->Release(connector->queue);
			(*(connector->interface))->close(connector->interface);
			(*(connector->interface))->Release(connector->interface);
			connector->interface = NULL;
			connector->queue = NULL;
			break;
		}
		// loop through the interface's element's, adding them to the queue
		NSArray *cookies = [elements allKeys];
		unsigned int j, numCookies = [cookies count];
		for (j = 0; j < numCookies; j++) {
			// what size should I use here?
			IOHIDElementCookie cookie =
			(IOHIDElementCookie)[[cookies objectAtIndex:j] unsignedIntValue];
			// don't need error checking here - if an element doesn't get added to the queue,
			// that's not reason enough to completely bail out
			(*(connector->queue))->addElement(connector->queue,
											  cookie,
											  0);
			//NSLog(@"added element %d to queue", cookie);
		}
		result = (*(connector->queue))->start(connector->queue);
		if (result != kIOReturnSuccess) {
			// remove run loop source?
			CFRunLoopRemoveSource(notificationRunLoop,
								  connector->runLoopSource,
								  kCFRunLoopDefaultMode);
			(*(connector->queue))->dispose(connector->queue);
			(*(connector->queue))->Release(connector->queue);
			(*(connector->interface))->close(connector->interface);
			(*(connector->interface))->Release(connector->interface);
			connector->interface = NULL;
			connector->queue = NULL;
			break;
		}
		(*(connector->interface))->close(connector->interface);
	}
	IOObjectRelease(iterator);
}


// Assumtions:
//   - device has been added (so it's not nil)
//   - device is currently connected
+ (void)disconnect:(NSNumber *)locationID {
	//NSLog(@"disconnecting from %@ (%@)",
	//	  locationID,
	//	  [[devices objectForKey:locationID] valueForKey:AG_NAME_KEY]);
	NSArray *interfaces = [[devices objectForKey:locationID] valueForKey:AG_INTERFACES_KEY];
		
	unsigned int i, count = [interfaces count];
	for (i = 0; i < count; i++) {
		NSValue *wrappedConnector = [[interfaces objectAtIndex:i] valueForKey:AG_CONNECTOR_KEY];
		Connector *connector = (Connector *)[wrappedConnector pointerValue];
		(*(connector->interface))->open(connector->interface, 0);
		(*(connector->queue))->stop(connector->queue);
		CFRunLoopRemoveSource(notificationRunLoop,
							  connector->runLoopSource,
							  kCFRunLoopDefaultMode);
		(*(connector->queue))->dispose(connector->queue);
		(*(connector->queue))->Release(connector->queue);
		(*(connector->interface))->close(connector->interface);
		(*(connector->interface))->Release(connector->interface);
		connector->interface = NULL;
		connector->queue = NULL;
	}
}


// looks complete
+ (BOOL)deviceIsConnected:(NSNumber *)locationID {
	NSDictionary *device = [devices objectForKey:locationID];
	if (device == nil) {
		return NO;
	}
	NSDictionary *firstInterface = [[device valueForKey:AG_INTERFACES_KEY] objectAtIndex:0];
	NSValue *wrappedConnector = [firstInterface valueForKey:AG_CONNECTOR_KEY];
	Connector *connector = (Connector *)[wrappedConnector pointerValue];
	if (connector->interface == NULL) {
		return NO;
	}
	return YES;
}


// scrutinize/clean-up this method!
// assumes device has not been previously added (so check before calling it!)
+ (void)addDeviceHavingLocationID:(NSNumber *)locationID {
	//NSLog(@"adding device having location ID %@", locationID);
	// on failure (any error), don't add a key-value pair to the devices dictionary
	
	// - this has to create each interface for the device
	// - an interface has managers, elements, and a connector
	// - this doesn't ever need to call +connect
	
	// make a matching matching dictionary for locationID
	// get iterator for device
	// add each interface to the devices dictionary
	// remember to release both the io_object_ts and the io_iterator_t
	
	NSMutableDictionary *device = [[NSMutableDictionary alloc] init];
	
	// managersForDevice holds weak references to each manager object
	CFArrayCallBacks arrayCallbacks = kCFTypeArrayCallBacks;
	arrayCallbacks.retain = NULL;
	arrayCallbacks.release = NULL;
	NSMutableArray *managersForDevice = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, &arrayCallbacks);
	unsigned int i, count = [managers count];
	for (i = 0; i < count; i++) {
		AGHIDManager *manager = [managers objectAtIndex:i];
		if ([[manager locationIDOfSelectedDevice] isEqualToNumber:locationID]) {
			[managersForDevice addObject:manager];
		}
	}
	[device setValue:managersForDevice
			  forKey:AG_MANAGERS_KEY];
	[managersForDevice release];
	
	NSMutableArray *interfacesOfDevice = [[NSMutableArray alloc] init];
	[device setValue:interfacesOfDevice
			  forKey:AG_INTERFACES_KEY];
	[interfacesOfDevice release];
	
	io_iterator_t interfaceIterator;
	CFMutableDictionaryRef matchLocation = IOServiceMatching(kIOHIDDeviceKey);
	CFDictionarySetValue(matchLocation,
						 CFSTR(kIOHIDLocationIDKey),
						 locationID);
	IOServiceGetMatchingServices(kIOMasterPortDefault,
								 matchLocation,
								 &interfaceIterator);
	NSString *deviceName = nil;
	io_object_t ioInterface;
	unsigned int numberOfInterfaces = 0;
	while( ioInterface = IOIteratorNext(interfaceIterator)) {
		// if something goes wrong, call release everything and return 
		NSMutableDictionary *interface = [[NSMutableDictionary alloc] init];
		[interfacesOfDevice addObject:interface];
		[interface release];
		[interface setValue:[NSNumber numberWithUnsignedInt:numberOfInterfaces]
					 forKey:AG_INTERFACE_NUMBER_KEY];
		numberOfInterfaces++;
		
		if (deviceName == nil) {
			deviceName = (NSString *)IORegistryEntryCreateCFProperty(ioInterface, 
																	 CFSTR(kIOHIDProductKey),
																	 kCFAllocatorDefault,
																	 0);
			[device setValue:deviceName
					  forKey:AG_NAME_KEY];
			[deviceName release];
		}
		
		IOHIDDeviceInterface122 **hidDeviceInterface = NULL;
		MyCreateHIDDeviceInterface(ioInterface, (IOHIDDeviceInterface ***)&hidDeviceInterface);
		IOObjectRelease(ioInterface);
		NSArray *elements;
		(*hidDeviceInterface)->copyMatchingElements(hidDeviceInterface, NULL, (CFArrayRef *)&elements);
		(*hidDeviceInterface)->Release(hidDeviceInterface);
		NSMutableDictionary *inputElements = [[NSMutableDictionary alloc] init];
		unsigned int i, count = [elements count];
		for (i = 0; i < count; i++) {
			NSDictionary *element = [elements objectAtIndex:i];
			//NSLog(@"%@", [element valueForKey:@kIOHIDElementTypeKey]);
			long type = [[element valueForKey:@kIOHIDElementTypeKey] longValue];
			if (type == kIOHIDElementTypeInput_Misc ||
				type == kIOHIDElementTypeInput_Button ||
				type == kIOHIDElementTypeInput_Axis ||
				type == kIOHIDElementTypeInput_ScanCodes) {
				NSNumber *cookie = [element valueForKey:@kIOHIDElementCookieKey];
				[inputElements setObject:element
								  forKey:cookie];
				//NSLog(@"added element %@", cookie);
			}
		}
		[elements release];
		[interface setValue:inputElements
					 forKey:AG_ELEMENTS_KEY];
		[inputElements release];
		
		
		Connector *connector = malloc(sizeof(Connector));
		if (connector == NULL) {
			[device release];
			//[managersForDevice release];
			IOObjectRelease(interfaceIterator);
			return;
		}
		connector->interface = NULL;
		connector->queue = NULL;
		connector->runLoopSource = NULL;
		[interface setValue:[NSValue valueWithPointer:connector]
					 forKey:AG_CONNECTOR_KEY];
	}
	IOObjectRelease(interfaceIterator);
	//[managersForDevice release];
	
	if (numberOfInterfaces > 0) {
		[devices setObject:device
					forKey:locationID];
	}
	
	[device release];
	
	// if no io_object_ts are returned from the iterator, that means someone
	// plugged and unplugged a device very quickly
	// leave the value associated with locationID equal to nil in such a case
	
	// Also iterate through the managers array, checking the location ID of
	// each manager. If manager's location ID is equal to locationID, add
	// the manager to the managers array of each of the devices interfaces
}


+ (NSNumber *)locationIDOfHIDInterface:(io_object_t *)hidInterface {
	NSNumber *locationID;
	locationID = (NSNumber *)IORegistryEntryCreateCFProperty(*hidInterface, 
															 CFSTR(kIOHIDLocationIDKey),
															 kCFAllocatorDefault,
															 0);
	return [locationID autorelease];
}


#pragma mark init/dealloc Methods

- (id) init {
	if (self = [super init]) {
		[managers addObject:self];
		previousDeviceSet = [currentlyAttachedDevices copy];
		deviceSet = [previousDeviceSet retain];
	}
	return self;
}


- (void)dealloc {
	// remove entries of self from the class variable "devices" if necessary
	NSDictionary *device = [devices objectForKey:locationIDOfSelectedDevice];
	if (device != nil) {
		NSMutableArray *managersForDevice = [device valueForKey:AG_MANAGERS_KEY];
		if ([managersForDevice count] == 0 && [self selectedDeviceIsConnected]) {
			[AGHIDManager disconnect:locationIDOfSelectedDevice];
		}
	}
	[managers removeObject:self];
	[locationIDOfSelectedDevice release];
	[super dealloc];
}


#pragma mark Device Methods

- (void)setDeviceMatchingCriteria:(NSDictionary *)criteria {
	[deviceMatchingCriteria release];
	deviceMatchingCriteria = [criteria retain];
	[self updateDeviceSet];
	if (![deviceSet isEqualToSet:previousDeviceSet]) {
		if ([delegate respondsToSelector:@selector(deviceListDidChangeForHIDManager:)]) {
			[delegate deviceListDidChangeForHIDManager:self];
		}
	}
}


- (NSArray *)deviceList {
	return [deviceSet allObjects];
}


// looks complete
- (void)selectDeviceHavingLocationID:(NSNumber *)locationID {
	if ([locationIDOfSelectedDevice isEqualToNumber:locationID]) return;
	
	[locationID retain];
	
	// remove entries of self from the class variable "devices" if necessary
	NSDictionary *oldSelectedDevice = [devices objectForKey:locationIDOfSelectedDevice];
	if (oldSelectedDevice != nil) {
		NSMutableArray *managersForDevice = [oldSelectedDevice valueForKey:AG_MANAGERS_KEY];
		[managersForDevice removeObject:self];
		if ([managersForDevice count] == 0 && [self selectedDeviceIsConnected]) {
			[AGHIDManager disconnect:locationIDOfSelectedDevice];
		}
	}
	[locationIDOfSelectedDevice release];
	locationIDOfSelectedDevice = locationID;
	
	// add entries of self in devices if
	// locationIDOfSelectedDevice exists in devices
	// connect is necessary
	NSDictionary *newSelectedDevice = [devices objectForKey:locationIDOfSelectedDevice];
	if (newSelectedDevice != nil) {
		NSMutableArray *managersForDevice = [newSelectedDevice objectForKey:AG_MANAGERS_KEY];
		[managersForDevice addObject:self];
		if ([managersForDevice count] == 1 && [currentlyAttachedDevices containsObject:locationIDOfSelectedDevice]) {
			[AGHIDManager connect:locationIDOfSelectedDevice];
		}
	}
}


// looks complete
- (NSNumber *)locationIDOfSelectedDevice {
	return [[locationIDOfSelectedDevice retain] autorelease];
}


- (NSString *)nameOfSelectedDevice {
	return [AGHIDManager nameOfDeviceHavingLocationID:locationIDOfSelectedDevice];
}


- (BOOL)selectedDeviceIsConnected {
	return [AGHIDManager deviceIsConnected:locationIDOfSelectedDevice];
}


- (void)updateDeviceSet {
	// use deviceMatchingCriteria to get a new set of device,
	// and replace the old deviceSet
	[previousDeviceSet release];
	previousDeviceSet = deviceSet;
	if (deviceMatchingCriteria == nil) {
		deviceSet = [currentlyAttachedDevices copy];
		return;
	}
	deviceSet = [[NSMutableSet alloc] init];
	io_iterator_t iterator;
	io_object_t interface;	
	CFMutableDictionaryRef matchingDictionary = IOServiceMatching(kIOHIDDeviceKey);
	[(NSMutableDictionary *)matchingDictionary addEntriesFromDictionary:deviceMatchingCriteria];
	IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDictionary, &iterator);
	while (interface = IOIteratorNext(iterator)) {
		CFNumberRef location = IORegistryEntryCreateCFProperty(interface,
															   CFSTR(kIOHIDLocationIDKey),
															   kCFAllocatorDefault,
															   kNilOptions);
		[(NSMutableSet *)deviceSet addObject:(NSNumber *)location];
		CFRelease(location);
		IOObjectRelease(interface);
	}
	IOObjectRelease(iterator);
}


// because this is a private method, I don't need to retain/autorelease
- (NSSet *)deviceSet {
	return deviceSet;
}


// because this is a private method, I don't need to retain/autorelease
- (NSSet *)previousDeviceSet {
	return previousDeviceSet;
}


#pragma mark Delegate Methods

// looks complete
- (void)setDelegate:(id)newDelegate {
	delegate = newDelegate;
}


// looks complete
- (id)delegate {
	return delegate;
}


# pragma mark Callback Functions

// see block starting at line 495 of main.c in USBNotificationExample!!!

// looks complete
static void hidWasAddedCallback(void *refCon, io_iterator_t iterator)
{	
	// add new devices, connect if necessary, and arm the notification system
	NSMutableArray *addedLocationIDs = [NSMutableArray array];
	io_object_t hidInterface;
	while (hidInterface = IOIteratorNext(iterator)) {
		NSNumber *locationID = [AGHIDManager locationIDOfHIDInterface:&hidInterface];
		IOObjectRelease(hidInterface);
		if (![addedLocationIDs containsObject:locationID]) {
			[addedLocationIDs addObject:locationID];
		}
	}
	unsigned int i, count = [addedLocationIDs count];
	for (i = 0; i < count; i++) {
		NSNumber *locationID = [addedLocationIDs objectAtIndex:i];
		NSDictionary *device = [devices objectForKey:locationID];
		if (device == nil) {
			[AGHIDManager addDeviceHavingLocationID:locationID];
			device = [devices objectForKey:locationID];
		}
		// if device is still nil, +addDeviceHavingLocationID failed and
		// we shouldn't do anything
		if (device != nil) {
			[currentlyAttachedDevices addObject:locationID];
			// connect to devices which have managers
			if ([[device valueForKey:AG_MANAGERS_KEY] count] > 0) {
				[AGHIDManager connect:locationID];
			}
		}
	}
	
	// for each manager, invoke the manager's delegate's
	// deviceListDidChangeForHIDManager: method if that manager's
	// device list changed
	// I make a copy of the managers array to account for the case where someone
	// might want to release a manager inside their callback method
	NSArray *snapshotOfManagersArray = [managers copy];
	count = [snapshotOfManagersArray count];
	for (i = 0; i < count; i++) {
		AGHIDManager *manager = (AGHIDManager *)[snapshotOfManagersArray objectAtIndex:i];
		[manager updateDeviceSet];
		if (![[manager deviceSet] isEqualToSet:[manager previousDeviceSet]]) {
			id delegate = [manager delegate];
			if ([delegate respondsToSelector:@selector(deviceListDidChangeForHIDManager:)]) {
				[delegate deviceListDidChangeForHIDManager:manager];
			}
		}
	}
	[snapshotOfManagersArray release];
}


// looks complete
static void hidWasRemovedCallback(void *refCon, io_iterator_t iterator)
{	
	// disconnect removed devices, and re-arm the notification system
	NSMutableArray *removedLocationIDs = [NSMutableArray array];
	io_object_t hidInterface;
	while (hidInterface = IOIteratorNext(iterator)) {
		NSNumber *locationID = [AGHIDManager locationIDOfHIDInterface:&hidInterface];
		IOObjectRelease(hidInterface);
		if (![removedLocationIDs containsObject:locationID]) {
			[removedLocationIDs addObject:locationID];
		}
	}
	unsigned int i, count = [removedLocationIDs count];
	for (i = 0; i < count; i++) {
		NSNumber *locationID = [removedLocationIDs objectAtIndex:i];
		[currentlyAttachedDevices removeObject:locationID];
		if ([AGHIDManager deviceIsConnected:locationID]) {
			[AGHIDManager disconnect:locationID];
		}
	}
	
	// for each manager, invoke the manager's delegate's
	// deviceListDidChangeForHIDManager: method if that manager's
	// device list changed
	// I make a copy of the managers array to account for the case where someone
	// might want to release a manager inside their callback method
	NSArray *snapshotOfManagersArray = [managers copy];
	count = [snapshotOfManagersArray count];
	for (i = 0; i < count; i++) {
		AGHIDManager *manager = (AGHIDManager *)[snapshotOfManagersArray objectAtIndex:i];
		[manager updateDeviceSet];
		if (![[manager deviceSet] isEqualToSet:[manager previousDeviceSet]]) {
			id delegate = [manager delegate];
			if ([delegate respondsToSelector:@selector(deviceListDidChangeForHIDManager:)]) {
				[delegate deviceListDidChangeForHIDManager:manager];
			}
		}
	}
	[snapshotOfManagersArray release];
}


void eventCallback(void *target, IOReturn result, void *refcon, void *sender) {
	NSArray *managers = (NSArray *)target; // managers for device
	NSDictionary *deviceInterface = (NSDictionary *)refcon;
	NSDictionary *elements = [deviceInterface valueForKey:AG_ELEMENTS_KEY];
	NSNumber *interfaceNumber = [deviceInterface valueForKey:AG_INTERFACE_NUMBER_KEY];
	IOHIDQueueInterface **queueInterface = (IOHIDQueueInterface **)sender;
	IOHIDEventStruct event;
	AbsoluteTime maxTime = {0, 0};
	UInt32 timeoutMS = 0;

	while(result == kIOReturnSuccess) {
		result = (*queueInterface)->getNextEvent(queueInterface, 
												 &event, 
												 maxTime, 
												 timeoutMS);
		if (result != kIOReturnSuccess) {
			break;
		}
		// we're only interested in 32-bit values
        if (event.longValueSize != 0) {
			if (event.longValue != NULL) {
				free(event.longValue);
			}
            continue;
        }
		
		NSNumber *cookie = [NSNumber numberWithUnsignedInt:(UInt32)event.elementCookie];
		NSDictionary *element = [elements objectForKey:cookie];
		UInt16 page = [[element valueForKey:AG_ELEMENT_PAGE_KEY] shortValue];
		UInt16 usage = [[element valueForKey:AG_ELEMENT_USAGE_KEY] shortValue];
		SInt32 minValue = [[element valueForKey:AG_ELEMENT_MIN_KEY] intValue];
		SInt32 maxValue = [[element valueForKey:AG_ELEMENT_MAX_KEY] intValue];
		BOOL isRelative = [[element valueForKey:AG_ELEMENT_IS_RELATIVE_KEY] boolValue];
		
		unsigned int i, count = [managers count];
		for (i = 0; i < count; i++) {
			AGHIDManager *manager = [managers objectAtIndex:i];
			id delegate = [manager delegate];
			if ([delegate respondsToSelector:@selector(elementHavingPage:usage:cookie:minValue:maxValue:fromInterfaceNumber:didReportValue:toManager:whereValueIsRelative:)]) {
				[delegate elementHavingPage:page
									  usage:usage
									 cookie:cookie
								   minValue:minValue
								   maxValue:maxValue
						fromInterfaceNumber:interfaceNumber
							 didReportValue:event.value
								  toManager:manager
					   whereValueIsRelative:isRelative];
			}
		}
	}
}


# pragma mark Other Functions

// copied from hidexample (Apple example)
// re-name and re-code
static void MyCreateHIDDeviceInterface(io_object_t hidDevice,
									   IOHIDDeviceInterface ***hidDeviceInterface)
{
	//io_name_t						className;
	IOCFPlugInInterface						**plugInInterface = NULL;
	HRESULT						plugInResult = S_OK;
	SInt32						score = 0;
	IOReturn						ioReturnValue = kIOReturnSuccess;
	
	//ioReturnValue = IOObjectGetClass(hidDevice, className);
	
	ioReturnValue = IOCreatePlugInInterfaceForService(hidDevice,
													  kIOHIDDeviceUserClientTypeID,
													  kIOCFPlugInInterfaceID,
													  &plugInInterface,
													  &score);
	
	if (ioReturnValue == kIOReturnSuccess)
	{
		//Call a method of the intermediate plug-in to create the device 
		//interface
		plugInResult = (*plugInInterface)->QueryInterface(plugInInterface,
														  CFUUIDGetUUIDBytes(kIOHIDDeviceInterfaceID),
														  (LPVOID) hidDeviceInterface);
		
		(*plugInInterface)->Release(plugInInterface);
	}
}

@end
