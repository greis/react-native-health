//
//  RCTAppleHealthKit+Methods_Workout.m
//  RCTAppleHealthKit
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "RCTAppleHealthKit+Methods_Workout.h"
#import "RCTAppleHealthKit+Utils.h"
#import "RCTAppleHealthKit+Queries.h"

@implementation RCTAppleHealthKit (Methods_Workout)

- (void)workout_getAnchoredQuery:(NSDictionary *)input callback:(RCTResponseSenderBlock)callback
{
    NSUInteger limit = [RCTAppleHealthKit uintFromOptions:input key:@"limit" withDefault:HKObjectQueryNoLimit];
    
    HKSampleType *workoutType = [HKObjectType workoutType];
    HKQueryAnchor *anchor = [RCTAppleHealthKit hkAnchorFromOptions:input];
    NSDate *startDate = [RCTAppleHealthKit dateFromOptions:input key:@"startDate" withDefault:nil];
    NSDate *endDate = [RCTAppleHealthKit dateFromOptions:input key:@"endDate" withDefault:[NSDate date]];
    
    NSPredicate *predicate = [RCTAppleHealthKit predicateForAnchoredQueries:anchor startDate:startDate endDate:endDate];

    void (^completion)(NSDictionary *results, NSError *error);

    completion = ^(NSDictionary *results, NSError *error) {
        if (results){
            callback(@[[NSNull null], results]);

            return;
        } else {
            NSLog(@"error getting samples: %@", error);
            callback(@[RCTMakeError(@"error getting samples", error, nil)]);

            return;
        }
    };

    [self fetchAnchoredWorkouts:workoutType
                      predicate:predicate
                         anchor:anchor
                          limit:limit
                     completion:completion];
}

- (void)workout_save: (NSDictionary *)input callback: (RCTResponseSenderBlock)callback {
    HKWorkoutActivityType type = [RCTAppleHealthKit hkWorkoutActivityTypeFromOptions:input key:@"type" withDefault:HKWorkoutActivityTypeAmericanFootball];
    NSDate *startDate = [RCTAppleHealthKit dateFromOptions:input key:@"startDate" withDefault:nil];
    NSDate *endDate = [RCTAppleHealthKit dateFromOptions:input key:@"endDate" withDefault:nil];
    NSTimeInterval duration = [RCTAppleHealthKit doubleFromOptions:input key:@"duration" withDefault:(NSTimeInterval)0];
    HKQuantity *totalEnergyBurned = [RCTAppleHealthKit hkQuantityFromOptions:input valueKey:@"energyBurned" unitKey:@"energyBurnedUnit"];
    HKQuantity *totalDistance = [RCTAppleHealthKit hkQuantityFromOptions:input valueKey:@"distance" unitKey:@"distanceUnit"];


    HKWorkout *workout = [
                          HKWorkout workoutWithActivityType:type startDate:startDate endDate:endDate workoutEvents:nil totalEnergyBurned:totalEnergyBurned totalDistance:totalDistance metadata: nil
                          ];

    void (^completion)(BOOL success, NSError *error);

    completion = ^(BOOL success, NSError *error){
        if (!success) {
            NSLog(@"An error occured saving the workout %@. The error was: %@.", workout, error);
            callback(@[RCTMakeError(@"An error occured saving the workout", error, nil)]);

            return;
        }

        HKUnit *count = [HKUnit countUnit];
        HKUnit *minute = [HKUnit minuteUnit];
        HKUnit *unit = [RCTAppleHealthKit hkUnitFromOptions:input key:@"unit" withDefault:[count unitDividedByUnit:minute]];
        NSMutableArray *samples = [NSMutableArray array];

        NSArray *hrSamples = [input objectForKey:@"hrSamples"] ?: @[];

        [hrSamples enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            double value = [obj doubleValue];
            if (value > 0) {
                NSDate *date = [startDate dateByAddingTimeInterval:idx];
                HKQuantitySample* heartRate = [HKQuantitySample quantitySampleWithType:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate]
                                                                        quantity:[HKQuantity quantityWithUnit:unit doubleValue:value]
                                                                        startDate:date
                                                                        endDate:date];
                [samples addObject:heartRate];
            }
        }];

        if ([hrSamples count] > 0) {
            [self.healthStore addSamples:samples toWorkout:workout completion:^(BOOL success, NSError * _Nullable error) {
                if (!success) {
                    NSLog(@"An error occured saving the workout samples %@. The error was: %@.", workout, error);

                    return;
                }
            }];
        }

        callback(@[[NSNull null], [[workout UUID] UUIDString]]);
    };

    [self.healthStore saveObject:workout withCompletion:completion];
}
@end
