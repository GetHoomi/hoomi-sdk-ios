/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import <Foundation/Foundation.h>

/*!
 Represents a app data stored with a user.
 */
@interface HFAppData : NSObject

/*!
 The data for the user. This is mutable so that it can be easily modified and
 used to set the data for the user.
 */
@property (nonatomic, readonly, strong) NSMutableDictionary *data;

/*!
 Gets the ETag used for optimistic concurrency for this app data.
 */
@property (nonatomic, readonly, copy) NSString *ETag;

/*!
 Creates an HFAppData instance with the given data and ETag.
 
 @param data the app data for the user
 @param ETag the ETag of the app data (used for optimistic concurrency)
 */
+ (instancetype)appDataWithData:(NSMutableDictionary *)data ETag:(NSString *)ETag;

@end
