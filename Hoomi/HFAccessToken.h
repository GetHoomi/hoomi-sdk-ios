/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import <Foundation/Foundation.h>

/*!
 Represents a Hoomi access token.
 */
@interface HFAccessToken : NSObject

/*!
 The token string that will be used for requests with this token.
 */
@property (nonatomic, readonly, copy) NSString *tokenString;

/*!
 The set of scopes known to be provided by this token. Users may revoke access
 to these scopes.
 */
@property (nonatomic, readonly, copy) NSArray *knownScopes;

/*!
 The expiration known for this token. The token may becoem invalid before its
 expiration date.
 */
@property (nonatomic, readonly, copy) NSDate *knownExpiration;

/*!
 Creates an HFAccessToken given just the token string, in case you are restoring
 a serialized token without additional information or retrieving a token from your
 server.
 
 @param token the token string
 */
+ (instancetype)tokenWithString:(NSString *)token;

/*!
 Creates an HFAccessToken with its known scopes and expiration.
 
 @param token the token string
 @param knownScopes the set of scopes known to be issued for this token
 @param knownExpiration the known expiration time for this token
 */
+ (instancetype)tokenWithString:(NSString *)token
                    knownScopes:(NSArray *)knownScopes
                knownExpiration:(NSDate *)knownExpiration;

@end
