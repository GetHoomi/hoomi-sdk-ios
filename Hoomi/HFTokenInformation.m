/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import "HFTokenInformation.h"

@implementation HFTokenInformation

@synthesize token = _token;
@synthesize applicationId = _applicationId;
@synthesize issued = _issued;
@synthesize userId = _userId;
@synthesize issuedToAuthenticatedClient = _issuedToAuthenticatedClient;

- (instancetype)initWithToken:(HFAccessToken *)token
                applicationId:(NSString *)applicationId
                       issued:(NSDate *)issued
                       userId:(NSString *)userId
  issuedToAuthenticatedClient:(BOOL)issuedToAuthenticatedClient {
  if (self = [super init]) {
    _token = token;
    _applicationId = [applicationId copy];
    _issued = [issued copy];
    _userId = [userId copy];
    _issuedToAuthenticatedClient = issuedToAuthenticatedClient;
  }
  return self;
}

+ (instancetype)tokenInformationWithToken:(HFAccessToken *)token
                            applicationId:(NSString *)applicationId
                                   issued:(NSDate *)issued
                                   userId:(NSString *)userId
              issuedToAuthenticatedClient:(BOOL)issuedToAuthenticatedClient{
  return [[self alloc] initWithToken:token
                       applicationId:applicationId
                              issued:issued
                              userId:userId
         issuedToAuthenticatedClient:issuedToAuthenticatedClient];
}

@end
