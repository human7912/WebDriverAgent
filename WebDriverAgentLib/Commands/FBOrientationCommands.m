/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBOrientationCommands.h"
#import "XCUIDevice+FBRotation.h"
#import "FBRouteRequest.h"
#import "FBMacros.h"
#import "FBSession.h"
#import "FBApplication.h"
#import "XCUIDevice.h"

extern const struct FBWDOrientationValues {
  FBLiteralString portrait;
  FBLiteralString landscapeLeft;
  FBLiteralString landscapeRight;
  FBLiteralString portraitUpsideDown;
} FBWDOrientationValues;

const struct FBWDOrientationValues FBWDOrientationValues = {
  .portrait = @"PORTRAIT",
  .landscapeLeft = @"LANDSCAPE",
  .landscapeRight = @"UIA_DEVICE_ORIENTATION_LANDSCAPERIGHT",
  .portraitUpsideDown = @"UIA_DEVICE_ORIENTATION_PORTRAIT_UPSIDEDOWN",
};

const NSTimeInterval kFBWebDriverOrientationChangeDelay = 5.0;

@implementation FBOrientationCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/orientation"] respondWithTarget:self action:@selector(handleGetOrientation:)],
    [[FBRoute POST:@"/orientation"] respondWithTarget:self action:@selector(handleSetOrientation:)],
    [[FBRoute GET:@"/rotation"] respondWithTarget:self action:@selector(handleGetRotation:)],
    [[FBRoute POST:@"/rotation"] respondWithTarget:self action:@selector(handleSetRotation:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleGetOrientation:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  return FBResponseWithStatus(FBCommandStatusNoError, [self.class interfaceOrientationForApplication:session.application]);
}

+ (id<FBResponsePayload>)handleSetOrientation:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  if ([self.class setDeviceOrientation:request.arguments[@"orientation"] forApplication:session.application]) {
    return FBResponseWithOK();
  }
  return FBResponseWithStatus(FBCommandStatusRotationNotAllowed, @"Unable To Rotate Device");
}

+ (id<FBResponsePayload>)handleGetRotation:(FBRouteRequest *)request
{
    XCUIDevice *device = [XCUIDevice sharedDevice];
    UIDeviceOrientation orientation = device.orientation;
    return FBResponseWithStatus(FBCommandStatusNoError, device.rotationMapping[@(orientation)]);
}

+ (id<FBResponsePayload>)handleSetRotation:(FBRouteRequest *)request
{
    FBSession *session = request.session;
    if ([self.class setDeviceRotation:request.arguments forApplication:session.application]) {
        return FBResponseWithOK();
    }
    return FBResponseWithStatus(FBCommandStatusRotationNotAllowed, [NSString stringWithFormat:@"Rotation not supported: %@", request.arguments[@"rotation"]]);
}


#pragma mark - Helpers

+ (NSString *)interfaceOrientationForApplication:(FBApplication *)application
{
  NSNumber *orientation = @(application.interfaceOrientation);
  NSSet *keys = [[self _orientationsMapping] keysOfEntriesPassingTest:^BOOL(id key, NSNumber *obj, BOOL *stop) {
    return [obj isEqualToNumber:orientation];
  }];
  if (keys.count == 0) {
    return @"Unknown orientation";
  }
  return keys.anyObject;
}

+ (BOOL)setDeviceRotation:(NSDictionary *)rotationObj forApplication:(FBApplication *)application
{
    if (![[XCUIDevice sharedDevice] setDeviceRotation:rotationObj]) {
        return NO;
    }
    return [self waitUntilApplication:application isOrientation:[XCUIDevice sharedDevice].orientation];
}

+ (BOOL)setDeviceOrientation:(NSString *)orientation forApplication:(FBApplication *)application
{
  NSNumber *orientationValue = [[self _orientationsMapping] objectForKey:orientation];
  if (orientationValue == nil) {
    return NO;
  }
  [XCUIDevice sharedDevice].orientation = orientationValue.integerValue;
  return [self waitUntilApplication:application isOrientation:orientationValue.integerValue];
}

+ (BOOL)waitUntilApplication:(FBApplication *)application isOrientation:(NSInteger)orientation
{
    // We have a busy loop here while we wait for the orientation to change as we do not have any hooks
    // into the event being handled.
    // If we could just hook into the event handler to know when it has been processed..
    NSDate *startDate = [NSDate date];
    while (![@(application.interfaceOrientation) isEqualToNumber:@(orientation)] && (-1 * [startDate timeIntervalSinceNow]) < kFBWebDriverOrientationChangeDelay) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.0, YES);
    }
    
    return [@(application.interfaceOrientation) isEqualToNumber:@(orientation)];
}

+ (NSDictionary *)_orientationsMapping
{
  static NSDictionary *orientationMap;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    orientationMap =
    @{
      FBWDOrientationValues.portrait : @(UIDeviceOrientationPortrait),
      FBWDOrientationValues.portraitUpsideDown : @(UIDeviceOrientationPortraitUpsideDown),
      FBWDOrientationValues.landscapeLeft : @(UIDeviceOrientationLandscapeLeft),
      FBWDOrientationValues.landscapeRight : @(UIDeviceOrientationLandscapeRight),
    };
  });
  return orientationMap;
}



@end
