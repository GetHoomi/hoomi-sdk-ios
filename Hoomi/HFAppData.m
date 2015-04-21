/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import "HFAppData.h"

@implementation HFAppData

@synthesize data = _data;
@synthesize ETag = _ETag;

- (instancetype)initWithData:(NSMutableDictionary *)data ETag:(NSString *)ETag {
  if (self = [super init]) {
    _data = data;
    _ETag = [ETag copy];
  }
  return self;
}

+ (instancetype)appDataWithData:(NSMutableDictionary *)data ETag:(NSString *)ETag {
  return [[self alloc] initWithData:data ETag:ETag];
}

@end
