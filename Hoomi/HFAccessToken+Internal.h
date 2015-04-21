/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import "HFAccessToken.h"

@interface HFAccessToken (Internal)

+ (instancetype)tokenWithJSON:(NSDictionary *)json;
- (NSDictionary *)JSON;

@end
