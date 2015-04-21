/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HFUtils : NSObject

+ (NSMutableDictionary *)persistentDataWithName:(NSString *)name;
+ (void)commitPersistentData:(NSDictionary *)dict withName:(NSString *)name;
+ (NSMutableArray *)deepCopyToMutableArray:(NSArray *)array;
+ (NSMutableDictionary *)deepCopyToMutableDictionary:(NSDictionary *)dictionary;
+ (void)loadFontFromResource:(NSString *)resourceName ofType:(NSString *)ofType bundle:(NSBundle *)bundle;
+ (UIImage *)imageWithColor:(UIColor *)color;
+ (UIImage *)scaleImage:(UIImage *)image size:(CGSize)newSize;
+ (NSDictionary *)queryItemsForComponents:(NSURLComponents *)components;
+ (void)setQueryItems:(NSDictionary *)queryItems forComponents:(NSURLComponents *)components;

@end
