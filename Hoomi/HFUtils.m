/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import "HFUtils.h"
#import <CoreText/CoreText.h>

static NSString * const PERSISTENT_FILE_NAME_FORMAT = @"%@.settings";

@implementation HFUtils

+ (NSString *)persistentFileNameWithName:(NSString *)name {
  NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                            NSUserDomainMask,
                                                            YES) firstObject];
  rootPath = [rootPath stringByAppendingPathComponent:@"hoomi"];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  [fileManager createDirectoryAtPath:rootPath
         withIntermediateDirectories:YES
                          attributes:nil
                               error:nil];
  NSString *fileName =[NSString stringWithFormat:PERSISTENT_FILE_NAME_FORMAT, name];
  return [rootPath stringByAppendingPathComponent:fileName];
}

+ (NSMutableDictionary *)persistentDataWithName:(NSString *)name {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  NSString *fileName = [self persistentFileNameWithName:name];
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:fileName]) {
    NSData *data = [NSData dataWithContentsOfFile:fileName];
    NSError *error = nil;
    id deserialized = [NSJSONSerialization JSONObjectWithData:data
                                                      options:NSJSONReadingMutableContainers
                                                        error:&error];
    if (!error) {
      result = deserialized;
    }
  }
  return result;
}

+ (void)commitPersistentData:(NSDictionary *)dict withName:(NSString *)name {
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:dict
                                                 options:0
                                                   error:&error];
  if (!error) {
    [data writeToFile:[self persistentFileNameWithName:name] atomically:YES];
  }
}

/*!
 Converts a dictionary and all of its child dictionaries/arrays to their mutable counterparts.
 */
+ (NSMutableDictionary *)deepCopyToMutableDictionary:(NSDictionary *)dictionary {
  NSMutableDictionary *copy = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
  for (id key in dictionary) {
    copy[key] = [self deepMutableCopyHelper:dictionary[key]];
  }
  return copy;
}

/*!
 Converts an array and all of its child dictionaries/arrays to their mutable counterparts.
 */
+ (NSMutableArray *)deepCopyToMutableArray:(NSArray *)array {
  NSMutableArray *copy = [NSMutableArray arrayWithCapacity:array.count];
  for (id value in array) {
    [copy addObject:[self deepMutableCopyHelper:value]];
  }
  return copy;
}

+ (id)deepMutableCopyHelper:(id)input {
  if ([input isKindOfClass:[NSDictionary class]]) {
    return [self deepCopyToMutableDictionary:input];
  }
  if ([input isKindOfClass:[NSArray class]]) {
    return [self deepCopyToMutableArray:input];
  }
  return input;
}

+ (void)loadFontFromResource:(NSString *)resourceName ofType:(NSString *)ofType bundle:(NSBundle *)bundle {
  NSData *inData = [NSData dataWithContentsOfFile:[bundle pathForResource:resourceName ofType:ofType]];
  CFErrorRef error;
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)inData);
  CGFontRef font = CGFontCreateWithDataProvider(provider);
  if (!CTFontManagerRegisterGraphicsFont(font, &error)) {
    CFStringRef errorDescription = CFErrorCopyDescription(error);
    NSLog(@"Failed to load font: %@", errorDescription);
    CFRelease(errorDescription);
  }
  CFRelease(font);
  CFRelease(provider);
}

+ (UIImage *)imageWithColor:(UIColor *)color {
  CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
  UIGraphicsBeginImageContext(rect.size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  CGContextSetFillColorWithColor(context, [color CGColor]);
  CGContextFillRect(context, rect);
  
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return image;
}

+ (UIImage *)scaleImage:(UIImage *)image size:(CGSize)newSize {
  UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
  [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return newImage;
}

// Encode a string to embed in an URL.
+ (NSString *)encodeToPercentEscapeString:(NSString *)string {
  return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                          (CFStringRef) string,
                                          NULL,
                                          (CFStringRef) @"!*'();:@&=+$,/?%#[]",
                                          kCFStringEncodingUTF8));
}

// Decode a percent escape encoded string.
+ (NSString *)decodeFromPercentEscapeString:(NSString *)string {
  return (NSString *)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL,
                                                          (CFStringRef) string,
                                                          CFSTR(""),
                                                          kCFStringEncodingUTF8));
}

+ (NSDictionary *)queryItemsForComponents:(NSURLComponents *)components {
  NSArray *parts = [components.percentEncodedQuery componentsSeparatedByString:@"&"];
  NSMutableDictionary *queryItems = [NSMutableDictionary dictionaryWithCapacity:parts.count];
  for (NSString *part in parts) {
    NSRange splitter = [part rangeOfString:@"="];
    NSString *rawLhs = [part substringToIndex:splitter.location];
    NSString *rawRhs = [part substringFromIndex:splitter.location + 1];
    NSString *lhs = [HFUtils decodeFromPercentEscapeString:rawLhs];
    NSString *rhs = [HFUtils decodeFromPercentEscapeString:rawRhs];
    queryItems[lhs] = rhs;
  }
  return queryItems;
}

+ (void)setQueryItems:(NSDictionary *)queryItems forComponents:(NSURLComponents *)components {
  NSMutableArray *parts = [NSMutableArray arrayWithCapacity:queryItems.count];
  for (NSString *key in queryItems) {
    NSString *lhs = [HFUtils encodeToPercentEscapeString:key];
    NSString *rhs = [HFUtils encodeToPercentEscapeString:queryItems[key]];
    [parts addObject:[NSString stringWithFormat:@"%@=%@", lhs, rhs]];
  }
  NSString *queryString = [parts componentsJoinedByString:@"&"];
  components.percentEncodedQuery = queryString;
}

@end
