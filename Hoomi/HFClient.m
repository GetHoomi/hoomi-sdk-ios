/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import <Bolts/Bolts.h>
#import <StoreKit/StoreKit.h>
#import "HFClient.h"
#import "HFAccessToken+Internal.h"
#import "HFTokenInformation.h"
#import "HFAppData.h"
#import "HFUtils.h"

static NSString * const BASE_API_URL = @"https://api.hoomi.co/";
static NSString * const BASE_DIALOG_URL = @"https://dialog.hoomi.co/";
static NSString * const BASE_APP_URL = @"hoomi://hoomi/";

static NSString * const HFCLIENT_SETTINGS_KEY_FORMAT = @"co.hoomi.HFClient|%@";
static NSString * const HFCLIENT_AUTH_REQUESTS_KEY = @"co.hoomi.HFClient.authorizationRequests";

const NSInteger kHoomiHttpError = 1;
const NSInteger kHoomiLoginError = 2;

// Keys for the shared data dictionary.
static NSString * const CURRENT_TOKEN_KEY = @"currentToken";

static HFClient *currentClient;

@interface HFApiResponse : NSObject

@property (nonatomic, readwrite, strong) NSDictionary *jsonData;
@property (nonatomic, readwrite, strong) NSDictionary *headers;

@end

@implementation HFApiResponse

@end

@interface HFReceiptRefresher : NSObject<SKRequestDelegate>

@property (nonatomic, strong) BFTaskCompletionSource *tcs;
@property (nonatomic, strong) SKReceiptRefreshRequest *request;
@property (nonatomic, strong) HFReceiptRefresher *retainer;

+ (BFTask *)refreshAppReceiptAsync;

@end

@implementation HFReceiptRefresher

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
  [self.tcs setError:error];
  NSLog(@"WARNING(Hoomi): Unable to request an App Receipt.  Ensure your bundle ID has been registered "
        "as an app on iTunes Connect and you are signed into the App Store with a sandbox user or an account "
        "that is linked to your iTunes Connect account.");
  self.request = nil;
  self.retainer = nil;
}

- (void)requestDidFinish:(SKRequest *)request {
  [self.tcs setResult:[NSData dataWithContentsOfURL:[NSBundle mainBundle].appStoreReceiptURL]];
  self.request = nil;
  self.retainer = nil;
}

+ (BFTask *)refreshAppReceiptAsync {
  HFReceiptRefresher *refresher = [[HFReceiptRefresher alloc] init];
  refresher.tcs = [BFTaskCompletionSource taskCompletionSource];
  SKReceiptRefreshRequest *request = [[SKReceiptRefreshRequest alloc] init];
  refresher.request = request;
  refresher.retainer = refresher;
  request.delegate = refresher;
  [request start];
  return refresher.tcs.task;
}

@end

@interface HFClient ()

@property (readwrite, strong) NSString *applicationId;
@property (readonly, strong) NSURLSession *urlSession;
@property (readwrite, strong) BFTask *clientIdTask;
@property (readonly, strong) NSObject *lock;
@property (readonly, strong) NSMutableDictionary *persistentData;
@property (readonly, strong) NSMutableDictionary *pendingAuthorizeTasks;
@property (readwrite, assign) BOOL clientAuthenticationEnabled;
@property (readwrite, assign) BOOL requestAppReceipt;

@end

@implementation HFClient

@synthesize currentToken = _currentToken;
@synthesize urlSession = _urlSession;
@synthesize lock = _lock;
@synthesize persistentData = _persistentData;
@synthesize pendingAuthorizeTasks = _pendingAuthorizeTasks;

- (instancetype)initWithApplicationId:(NSString *)applicationId {
  if (self = [super init]) {
    _lock = [[NSObject alloc] init];
    _urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    self.applicationId = applicationId;
    _pendingAuthorizeTasks = [NSMutableDictionary dictionary];
    if (!currentClient) {
      [HFClient setCurrentClient:self];
    }
    
    // Dispatch so that this happens after any other configuration
    dispatch_async(dispatch_get_main_queue(), ^{
      [self provisionClientIdAsync];
    });
  }
  return self;
}

+ (instancetype)clientWithApplicationId:(NSString *)applicationId {
  return [[self alloc] initWithApplicationId:applicationId];
}

+ (HFClient *)currentClient {
  return currentClient;
}

+ (void)setCurrentClient:(HFClient *)client {
  currentClient = client;
}

- (void)enableClientAuthentication {
  self.clientAuthenticationEnabled = YES;
}

- (void)requireClientAuthentication {
  [self enableClientAuthentication];
  if ([[UIDevice currentDevice].model rangeOfString:@"Simulator"].location == NSNotFound) {
    self.requestAppReceipt = YES;
  } else {
    NSLog(@"WARNING(Hoomi): You are running in the simulator and Client Authentication cannot be enabled. "
          "Please run on a device with a sandbox account.");
  }
}

- (NSString *)persistentDataName {
  return [NSString stringWithFormat:HFCLIENT_SETTINGS_KEY_FORMAT, self.applicationId];
}

- (NSMutableDictionary *)persistentData {
  @synchronized (self.lock) {
    return _persistentData = _persistentData ?: [HFUtils persistentDataWithName:[self persistentDataName]];
  }
}

- (void)commitPersistentData {
  @synchronized (self.lock) {
    [HFUtils commitPersistentData:self.persistentData withName:[self persistentDataName]];
  }
}

#pragma mark Requests

- (NSURL *)urlByAddingQuery:(NSDictionary *)parameters toURL:(NSURL *)url {
  NSURLComponents *components = [NSURLComponents componentsWithURL:url
                                           resolvingAgainstBaseURL:YES];
  NSMutableDictionary *queryItems = [[HFUtils queryItemsForComponents:components] mutableCopy] ?: [NSMutableDictionary dictionary];
  for (NSString *key in parameters) {
    queryItems[key] = parameters[key];
  }
  [HFUtils setQueryItems:queryItems forComponents:components];
  return components.URL;
}

- (NSString *)formEncodeParameters:(NSDictionary *)parameters {
  NSURLComponents *components = [NSURLComponents componentsWithString:@""];
  [HFUtils setQueryItems:parameters forComponents:components];
  return components.percentEncodedQuery;
}

- (BFTask *)requestAsyncWithPath:(NSString *)path
                          method:(NSString *)method
                           token:(HFAccessToken *)token
                      parameters:(NSDictionary *)parameters {
  return [self requestAsyncWithPath:path
                             method:method
                              token:token
                         parameters:parameters
                    useFormEncoding:NO];
}

- (BFTask *)requestAsyncWithPath:(NSString *)path
                          method:(NSString *)method
                           token:(HFAccessToken *)token
                      parameters:(NSDictionary *)parameters
                 useFormEncoding:(BOOL)useFormEncoding {
  return [self requestAsyncWithPath:path
                             method:method
                              token:token
                         parameters:parameters
                    useFormEncoding:useFormEncoding
                       extraHeaders:nil
                        mutableData:NO];
}

- (BFTask *)requestAsyncWithPath:(NSString *)path
                          method:(NSString *)method
                           token:(HFAccessToken *)token
                      parameters:(NSDictionary *)parameters
                 useFormEncoding:(BOOL)useFormEncoding
                    extraHeaders:(NSDictionary *)extraHeaders
                     mutableData:(BOOL)mutableData {
  BFTaskCompletionSource *tcs = [BFTaskCompletionSource taskCompletionSource];
  NSURL *url = [NSURL URLWithString:path relativeToURL:[NSURL URLWithString:BASE_API_URL]];
  if ([method isEqualToString:@"GET"] && parameters) {
    url = [self urlByAddingQuery:parameters toURL:url];
  }
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  
  request.HTTPMethod = method;
  
  if (extraHeaders) {
    for (NSString *key in extraHeaders) {
      id value = extraHeaders[key];
      if ([value isKindOfClass:[NSString class]]) {
        [request addValue:value forHTTPHeaderField:key];
      } else {
        for (NSString *innerValue in value) {
          [request addValue:innerValue forHTTPHeaderField:key];
        }
      }
    }
  }
  
  if (![method isEqualToString:@"GET"] && parameters) {
    if (useFormEncoding) {
      [request addValue:@"application/x-www-form-urlencoded"
     forHTTPHeaderField:@"Content-Type"];
      NSString *formEncoded = [self formEncodeParameters:parameters];
      request.HTTPBody = [formEncoded dataUsingEncoding:NSUTF8StringEncoding];
    } else {
      NSError *error = nil;
      [request addValue:@"application/json"
     forHTTPHeaderField:@"Content-Type"];
      request.HTTPBody = [NSJSONSerialization dataWithJSONObject:parameters
                                                         options:0
                                                           error:&error];
      if (error) {
        [tcs setError:error];
        return tcs.task;
      }
    }
  }
  
  if (token) {
    [request addValue:[NSString stringWithFormat:@"Bearer %@", token.tokenString]
   forHTTPHeaderField:@"Authorization"];
  }
  
  NSURLSessionDataTask *dataTask = [self.urlSession dataTaskWithRequest:request
                                                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                        if (error) {
                                                          [tcs setError:error];
                                                          return;
                                                        }
                                                        NSJSONReadingOptions readOptions = 0;
                                                        if (mutableData) {
                                                          readOptions |= NSJSONReadingMutableContainers;
                                                        }
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                                                        HFApiResponse *apiResponse = [[HFApiResponse alloc] init];
                                                        apiResponse.jsonData = [NSJSONSerialization JSONObjectWithData:data
                                                                                                               options:readOptions
                                                                                                                 error:&error];
                                                        apiResponse.headers = httpResponse.allHeaderFields;
                                                        if (error) {
                                                          [tcs setError:error];
                                                          return;
                                                        }
                                                        
                                                        if (httpResponse.statusCode < 200 || httpResponse.statusCode > 399) {
                                                          [tcs setError:[NSError errorWithDomain:@"hoomi"
                                                                                            code:kHoomiHttpError
                                                                                        userInfo:apiResponse.jsonData]];
                                                          return;
                                                        }
                                                        
                                                        [tcs setResult:apiResponse];
                                                      }];
  [dataTask resume];
  
  return tcs.task;
}

#pragma mark Token Management

- (HFAccessToken *)currentToken {
  @synchronized (self.lock) {
    if (!_currentToken) {
      _currentToken = [HFAccessToken tokenWithJSON:self.persistentData[CURRENT_TOKEN_KEY]];
    }
    return _currentToken;
  }
}

- (void)setCurrentToken:(HFAccessToken *)currentToken {
  @synchronized (self.lock) {
    if (currentToken) {
      self.persistentData[CURRENT_TOKEN_KEY] = [currentToken JSON];
    } else {
      [self.persistentData removeObjectForKey:CURRENT_TOKEN_KEY];
    }
    [self commitPersistentData];
    _currentToken = currentToken;
  }
}

- (void)logOut {
  [self setCurrentToken:nil];
}

- (BFTask *)getAppReceiptAsync {
  NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
  if (data) {
    return [BFTask taskWithResult:data];
  }
  
  if (!self.requestAppReceipt) {
    return [BFTask taskWithResult:nil];
  }
  
  return [HFReceiptRefresher refreshAppReceiptAsync];
}

- (BFTask *)provisionClientIdAsync {
  @synchronized (self.lock) {
    if (!self.clientIdTask) {
      self.clientIdTask = [BFTask taskWithResult:self.persistentData[@"cachedClientId"]];
    }
  }
  self.clientIdTask = [self.clientIdTask continueWithBlock:^id(BFTask *task) {
    NSDictionary *current = task.result;
    if (current && [current[@"expires"] doubleValue] > [NSDate date].timeIntervalSince1970) {
      if (self.clientAuthenticationEnabled && !current[@"client_secret"]) {
        // We should try again to authenticate the client
      } else {
        return task;
      }
    }
    id (^continuation)(BFTask *) = ^id(BFTask *task) {
      HFApiResponse *response = task.result;
      NSMutableDictionary *copy = [response.jsonData mutableCopy];
      long long expiresIn = [(copy[@"expires_in"] ?: @(60 * 60)) longLongValue];
      expiresIn -= 60 * 60;
      copy[@"expires"] = @([NSDate dateWithTimeIntervalSinceNow:expiresIn].timeIntervalSince1970);
      @synchronized (self.lock) {
        self.persistentData[@"cachedClientId"] = copy;
        [self commitPersistentData];
      }
      return copy;
    };
    BFTask *(^normalProvisioningAsync)() = ^BFTask * {
      return [[self requestAsyncWithPath:@"1/authz/provision_client"
                                  method:@"POST"
                                   token:nil
                              parameters:@{ @"application_id": self.applicationId }] continueWithSuccessBlock:continuation];
    };
    if (self.clientAuthenticationEnabled) {
      return [[self getAppReceiptAsync] continueWithSuccessBlock:^id(BFTask *task) {
        NSData *receiptData = task.result;
        if (receiptData) {
          return [[self requestAsyncWithPath:@"1/authz/provision_ios_client"
                                      method:@"POST"
                                       token:nil
                                  parameters:@{ @"application_id": self.applicationId,
                                                @"receipt": [receiptData base64EncodedStringWithOptions:0] }] continueWithSuccessBlock:continuation];
        } else {
          return normalProvisioningAsync();
        }
      }];
    }
    return normalProvisioningAsync();
  }];
  return self.clientIdTask;
}

- (void)registerLoginRequestWithState:(NSString *)state
                          redirectUri:(NSString *)redirectUri
                             clientId:(NSString *)clientId
                         clientSecret:(NSString *)clientSecret
                 taskCompletionSource:(BFTaskCompletionSource *)tcs {
  @synchronized (self.pendingAuthorizeTasks) {
    self.pendingAuthorizeTasks[state] = tcs;
  }
  NSMutableDictionary *authRequests = [HFUtils persistentDataWithName:HFCLIENT_AUTH_REQUESTS_KEY];
  NSMutableDictionary *authRequestData = [@{ @"clientId": clientId,
                                             @"redirectUri": redirectUri } mutableCopy];
  if (clientSecret) {
    authRequestData[@"clientSecret"] = clientSecret;
  }
  
  authRequests[state] = authRequestData;
  [HFUtils commitPersistentData:authRequests withName:HFCLIENT_AUTH_REQUESTS_KEY];
}

- (BFTask *)authorizeAsyncWithRedirectUrl:(NSURL *)redirectUrl scopes:(NSArray *)scopes {
  BFTaskCompletionSource *tcs = [BFTaskCompletionSource taskCompletionSource];
  
  [[self provisionClientIdAsync] continueWithSuccessBlock:^id(BFTask *task) {
    NSString *state = [[NSUUID UUID] UUIDString];
    NSString *clientId = task.result[@"client_id"];
    NSURL *launchUrl;
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:BASE_APP_URL]]) {
      launchUrl = [NSURL URLWithString:BASE_APP_URL];
    } else {
      launchUrl = [NSURL URLWithString:BASE_DIALOG_URL];
    }
    launchUrl = [NSURL URLWithString:@"login/auth" relativeToURL:launchUrl];
    
    NSMutableDictionary *loginParameters = [NSMutableDictionary dictionary];
    loginParameters[@"platform"] = @"ios";
    loginParameters[@"client_id"] = clientId;
    loginParameters[@"response_type"] = @"code";
    loginParameters[@"state"] = state;
    loginParameters[@"redirect_uri"] = redirectUrl.absoluteString;
    if (scopes) {
      loginParameters[@"scope"] = [scopes componentsJoinedByString:@" "];
    }
    
    launchUrl = [self urlByAddingQuery:loginParameters toURL:launchUrl];
    
    [self registerLoginRequestWithState:state
                            redirectUri:redirectUrl.absoluteString
                               clientId:clientId
                           clientSecret:task.result[@"client_secret"]
                   taskCompletionSource:tcs];
    
    [[UIApplication sharedApplication] openURL:launchUrl];
    return nil;
  }];
  
  return tcs.task;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
  NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
  NSDictionary *queryParams = [HFUtils queryItemsForComponents:components];
  
  if (!queryParams[@"state"]) {
    return NO;
  }
  
  NSMutableDictionary *authRequests = [HFUtils persistentDataWithName:HFCLIENT_AUTH_REQUESTS_KEY];
  NSDictionary *authRequest = authRequests[queryParams[@"state"]];
  if (!authRequest) {
    return NO;
  }
  NSString *prefix = authRequest[@"redirectUri"];
  if (![prefix rangeOfString:@"?"].length) {
    // Don't allow any extra path components before the query string.
    prefix = [prefix stringByAppendingString:@"?"];
  }
  if (![url.absoluteString hasPrefix:prefix]) {
    return NO;
  }
  [authRequests removeObjectForKey:queryParams[@"state"]];
  [HFUtils commitPersistentData:authRequests withName:HFCLIENT_AUTH_REQUESTS_KEY];
  
  [self completeLoginWithParameters:queryParams authRequest:authRequest];
  
  return YES;
}

- (void)completeLoginWithParameters:(NSDictionary *)parameters
                        authRequest:(NSDictionary *)authRequest {
  BFTaskCompletionSource *tcs = nil;
  @synchronized (self.pendingAuthorizeTasks) {
    tcs = self.pendingAuthorizeTasks[parameters[@"state"]];
    [self.pendingAuthorizeTasks removeObjectForKey:parameters[@"state"]];
  }
  
  if (parameters[@"error"]) {
    [tcs setError:[NSError errorWithDomain:@"hoomi"
                                      code:kHoomiLoginError
                                  userInfo:parameters]];
    return;
  }
  NSMutableDictionary *tokenParameters = [@{@"client_id": authRequest[@"clientId"],
                                            @"grant_type": @"authorization_code",
                                            @"code": parameters[@"code"],
                                            @"redirect_uri": authRequest[@"redirectUri"]} mutableCopy];
  if (authRequest[@"clientSecret"]) {
    tokenParameters[@"client_secret"] = authRequest[@"clientSecret"];
  }
  [[self requestAsyncWithPath:@"1/authz/token"
                       method:@"POST"
                        token:nil
                   parameters:tokenParameters
              useFormEncoding:YES] continueWithBlock:^id(BFTask *task) {
    if (task.error) {
      [tcs setError:task.error];
    }
    if (task.exception) {
      [tcs setException:task.exception];
    }
    if (task.isCancelled) {
      [tcs cancel];
    }
    
    HFApiResponse *response = task.result;
    NSString *tokenString = response.jsonData[@"access_token"];
    NSString *scopeString = response.jsonData[@"scope"];
    long long expiresIn = [response.jsonData[@"expires_in"] longLongValue];
    NSArray *scopes = [scopeString componentsSeparatedByString:@" "];
    HFAccessToken *token = [HFAccessToken tokenWithString:tokenString
                                              knownScopes:scopes
                                          knownExpiration:[NSDate dateWithTimeIntervalSinceNow:expiresIn]];
    self.currentToken = token;
    [tcs setResult:token];
    return nil;
  }];
}

- (NSDate *)parseIso8601Date:(NSString *)date {
  static NSDateFormatter *formatter = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    formatter = [NSDateFormatter new];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
    NSLocale* posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.locale = posix;
  });
  return [formatter dateFromString:date];
}

- (BFTask *)tokenInformationAsync:(HFAccessToken *)token {
  return [[self requestAsyncWithPath:@"1/token/current"
                              method:@"GET"
                               token:token
                          parameters:nil] continueWithSuccessBlock:^id(BFTask *task) {
    HFApiResponse *response = task.result;
    NSString *tokenString = response.jsonData[@"token"];
    NSString *applicationId = response.jsonData[@"application_id"];
    NSDate *issued = [self parseIso8601Date:response.jsonData[@"issued"]];
    NSDate *expires = [self parseIso8601Date:response.jsonData[@"expires"]];
    NSString *userId = response.jsonData[@"user_id"];
    NSArray *scopes = response.jsonData[@"scopes"];
    BOOL issuedToAuthenticatedClient = [response.jsonData[@"issued_to_authenticated_client"] boolValue];
    
    HFAccessToken *token = [HFAccessToken tokenWithString:tokenString
                                              knownScopes:scopes
                                          knownExpiration:expires];
    // If this is already the current token, we'd might as well store the latest data locally.
    if (self.currentToken &&
        [applicationId isEqualToString:self.applicationId] &&
        [token.tokenString isEqualToString:self.currentToken.tokenString]) {
      self.currentToken = token;
    }
    
    return [HFTokenInformation tokenInformationWithToken:token
                                           applicationId:applicationId
                                                  issued:issued
                                                  userId:userId
                             issuedToAuthenticatedClient:issuedToAuthenticatedClient];
  }];
}

#pragma mark App Data

- (BFTask *)appDataAsync {
  return [self appDataAsyncWithToken:self.currentToken];
}

- (BFTask *)appDataAsyncWithToken:(HFAccessToken *)token {
  return [[self requestAsyncWithPath:@"1/user/current/app/data"
                              method:@"GET"
                               token:token
                          parameters:nil
                     useFormEncoding:NO
                        extraHeaders:nil
                         mutableData:YES] continueWithSuccessBlock:^id(BFTask *task) {
    HFApiResponse *response = task.result;
    return [HFAppData appDataWithData:(NSMutableDictionary *)response.jsonData[@"data"]
                                 ETag:response.headers[@"ETag"]];
  }];
}

- (BFTask *)setAppDataAsync:(NSDictionary *)jsonData {
  return [self setAppDataAsync:jsonData token:self.currentToken];
}

- (BFTask *)setAppDataAsync:(NSDictionary *)jsonData token:(HFAccessToken *)token {
  return [self setAppDataAsync:jsonData ETag:@"*" token:token];
}

- (BFTask *)setAppDataAsync:(NSDictionary *)jsonData ETag:(NSString *)ETag {
  return [self setAppDataAsync:jsonData
                          ETag:ETag
                         token:self.currentToken];
}


- (BFTask *)setAppDataAsync:(NSDictionary *)jsonData ETag:(NSString *)ETag token:(HFAccessToken *)token {
  return [[self requestAsyncWithPath:@"1/user/current/app/data"
                              method:@"PUT"
                               token:token
                          parameters:jsonData
                     useFormEncoding:NO
                        extraHeaders:@{@"If-Match": ETag}
                         mutableData:NO] continueWithSuccessBlock:^id(BFTask *task) {
    HFApiResponse *response = task.result;
    return [HFAppData appDataWithData:[HFUtils deepCopyToMutableDictionary:jsonData]
                                 ETag:response.headers[@"ETag"]];
  }];
}

@end
