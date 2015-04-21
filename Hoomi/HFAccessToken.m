/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import "HFAccessToken+Internal.h"

@implementation HFAccessToken

@synthesize tokenString = _tokenString;
@synthesize knownScopes = _knownScopes;
@synthesize knownExpiration = _knownExpiration;

- (instancetype)initWithString:(NSString *)token
                   knownScopes:(NSArray *)knownScopes
               knownExpiration:(NSDate *)knownExpiration {
  if (self = [super init]) {
    _tokenString = [token copy];
    _knownScopes = [knownScopes copy];
    _knownExpiration = [knownExpiration copy];
  }
  return self;
}

+ (instancetype)tokenWithString:(NSString *)token {
  return [self tokenWithString:token knownScopes:nil knownExpiration:nil];
}

+ (instancetype)tokenWithString:(NSString *)token
                    knownScopes:(NSArray *)knownScopes
                knownExpiration:(NSDate *)knownExpiration {
  return [[self alloc] initWithString:token knownScopes:knownScopes knownExpiration:knownExpiration];
}

#pragma mark Internal

+ (instancetype)tokenWithJSON:(NSDictionary *)json {
  NSDate *knownExpiration = json[@"knownExpiration"] ? [NSDate dateWithTimeIntervalSince1970:[json[@"knownExpiration"] doubleValue]] : nil;
  return [self tokenWithString:json[@"tokenString"]
                   knownScopes:json[@"knownScopes"]
               knownExpiration:knownExpiration];
}

- (NSDictionary *)JSON {
  NSMutableDictionary *json = [NSMutableDictionary dictionary];
  json[@"tokenString"] = self.tokenString;
  if (self.knownExpiration) {
    json[@"knownExpiration"] = @([self.knownExpiration timeIntervalSince1970]);
  }
  if (self.knownScopes) {
    json[@"knownScopes"] = [self.knownScopes copy];
  }
  return json;
}

@end
