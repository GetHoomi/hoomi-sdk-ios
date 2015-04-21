/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import <Bolts/Bolts.h>
#import "HFLoginButton.h"
#import "HFUtils.h"
#import "HFClient.h"

static NSString * const hoomiFontName = @"Comfortaa-Bold";

@interface HFLoginButton ()

@property (nonatomic, readonly, strong) UIButton *button;

@property (nonatomic, readwrite, strong) UIColor *buttonBackgroundColor;
@property (nonatomic, readwrite, strong) UIColor *buttonForegroundColor;

@end

@implementation HFLoginButton

@synthesize button = _button;
@synthesize buttonStyle = _buttonStyle;

+ (NSBundle *)hoomiBundle {
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *hoomiBundle = [mainBundle pathForResource:@"Hoomi" ofType:@"bundle"];
  return [NSBundle bundleWithPath:hoomiBundle];
}

+ (void)initialize {
  [HFUtils loadFontFromResource:@"Comfortaa-Bold"
                         ofType:@"ttf"
                         bundle:[self hoomiBundle]];
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    [self setup];
  }
  return self;
}

- (instancetype)init {
  if (self = [super init]) {
    [self setup];
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  if (self = [super initWithCoder:aDecoder]) {
    [self setup];
  }
  return self;
}

- (void)setup {
  _button = [UIButton buttonWithType:UIButtonTypeCustom];
  self.button.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.button];
  [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_button]|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(_button)]];
  [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_button]|"
                                                               options:0
                                                               metrics:nil
                                                                 views:NSDictionaryOfVariableBindings(_button)]];
  
  self.button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
  self.button.titleLabel.textAlignment = NSTextAlignmentLeft;
  
  [self configureButton];
  
  [self.button addTarget:self action:@selector(buttonClicked) forControlEvents:UIControlEventTouchUpInside];
}

- (void)buttonClicked {
  id<HFLoginButtonDelegate> delegate = self.delegate;
  if ([delegate respondsToSelector:@selector(buttonWillPerformHoomiAuthorization:)]) {
    [delegate buttonWillPerformHoomiAuthorization:self];
  }
  HFClient *client = self.client ?: [HFClient currentClient];
  if (!client) {
    [NSException raise:@"Hoomi" format:@"No HFClient has been provided for this HFLoginButton."];
  }
  if (!self.redirectUri) {
    [NSException raise:@"Hoomi" format:@"You must provide a redirectUri for this HFLoginButton."];
  }
  [[client authorizeAsyncWithRedirectUrl:self.redirectUri
                                  scopes:self.scopes] continueWithBlock:^id(BFTask *task) {
    id<HFLoginButtonDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(button:didPerformHoomiAuthorizationWithResult:error:)]) {
      [delegate button:self didPerformHoomiAuthorizationWithResult:task.result error:task.error];
    }
    return nil;
  }];
}

- (void)configureButton {
  switch (self.buttonStyle) {
    case HFLoginButtonStyleGreenOnWhite:
      self.buttonBackgroundColor = [UIColor whiteColor];
      self.buttonForegroundColor = [UIColor colorWithRed:0 green:(110.0 / 255.0) blue:(46.0 / 255.0) alpha:1];
      break;
    case HFLoginButtonStyleWhiteOnGreen:
      self.buttonForegroundColor = [UIColor whiteColor];
      self.buttonBackgroundColor = [UIColor colorWithRed:0 green:(110.0 / 255.0) blue:(46.0 / 255.0) alpha:1];
      break;
    default:
      break;
  }
  
  [self.button setAttributedTitle:[self titleText] forState:UIControlStateNormal];
  [self.button setAttributedTitle:[self darkTitleText] forState:UIControlStateHighlighted];
  
  CGFloat imageHeight = self.frame.size.height * 0.8;
  CGSize imageSize = CGSizeMake(imageHeight, imageHeight);
  [self.button setBackgroundImage:[HFUtils imageWithColor:self.buttonBackgroundColor]
                         forState:UIControlStateNormal];
  [self.button setTitleColor:self.buttonForegroundColor forState:UIControlStateNormal];
  [self.button setImage:[HFUtils scaleImage:[self normalImage] size:imageSize]
               forState:UIControlStateNormal];
  
  [self.button setBackgroundImage:[HFUtils imageWithColor:[self darkBackgroundColor]]
                         forState:UIControlStateHighlighted];
  [self.button setTitleColor:[self darkForegroundColor] forState:UIControlStateHighlighted];
  [self.button setImage:[HFUtils scaleImage:[self darkImage] size:imageSize]
               forState:UIControlStateHighlighted];
  
  self.button.layer.cornerRadius = self.button.frame.size.height * 0.05;
  self.button.layer.borderWidth = 1;
  self.button.layer.borderColor = self.buttonForegroundColor.CGColor;
  self.button.clipsToBounds = YES;
  
  [self.button.imageView setContentMode:UIViewContentModeScaleAspectFit];
  
  self.button.contentEdgeInsets = UIEdgeInsetsMake(self.frame.size.height * 0.1,
                                                   self.frame.size.height * 0.1,
                                                   self.frame.size.height * 0.1,
                                                   self.frame.size.height * 0.1);
  [self.button.titleLabel sizeToFit];
  
  CGFloat titleInsetAmount = (self.frame.size.width - self.button.titleLabel.frame.size.width) / 2 - self.button.imageView.frame.size.width - self.button.contentEdgeInsets.left;
  
  self.button.titleEdgeInsets = UIEdgeInsetsMake(0, titleInsetAmount, 0, 0);
}


- (void)setButtonStyle:(HFLoginButtonStyle)buttonStyle {
  _buttonStyle = buttonStyle;
  [self configureButton];
}

- (NSMutableAttributedString *)rawTitleText {
  NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@"Continue with "];
  
  UIFont *font = [UIFont fontWithName:hoomiFontName size:([UIFont systemFontSize] * 1.25)];
  
  [text appendAttributedString:[[NSAttributedString alloc] initWithString:@"hoomi"
                                                               attributes:@{NSFontAttributeName: font}]];
  return text;
}

- (NSAttributedString *)titleText {
  NSMutableAttributedString *text = [self rawTitleText];
  [text addAttributes:@{NSForegroundColorAttributeName: self.buttonForegroundColor}
                range:NSMakeRange(0, text.length)];
  return text;
}

- (NSAttributedString *)darkTitleText {
  NSMutableAttributedString *text = [self rawTitleText];
  [text addAttributes:@{NSForegroundColorAttributeName: [self darkForegroundColor]}
                range:NSMakeRange(0, text.length)];
  return text;
}

- (void)layoutSubviews {
  [self configureButton];
  [super layoutSubviews];
}

- (UIImage *)normalImage {
  NSBundle *bundle = [[self class] hoomiBundle];
  NSString *resourceName;
  switch (self.buttonStyle) {
    case HFLoginButtonStyleGreenOnWhite:
      resourceName = @"hoomi-icon-green";
      break;
    case HFLoginButtonStyleWhiteOnGreen:
      resourceName = @"hoomi-icon-white";
    default:
      break;
  }
  NSString *path = [bundle pathForResource:resourceName ofType:@"png"];
  return [UIImage imageWithContentsOfFile:path];
}

- (UIImage *)darkImage {
  NSBundle *bundle = [[self class] hoomiBundle];
  NSString *resourceName;
  switch (self.buttonStyle) {
    case HFLoginButtonStyleGreenOnWhite:
      resourceName = @"hoomi-icon-green-dark";
      break;
    case HFLoginButtonStyleWhiteOnGreen:
      resourceName = @"hoomi-icon-white-dark";
    default:
      break;
  }
  NSString *path = [bundle pathForResource:resourceName ofType:@"png"];
  return [UIImage imageWithContentsOfFile:path];
}

- (UIColor *)darken:(UIColor *)color {
  CGFloat hue;
  CGFloat saturation;
  CGFloat brightness;
  CGFloat alpha;
  [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
  brightness *= 0.8;
  return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

- (UIColor *)darkBackgroundColor {
  return [self darken:self.buttonBackgroundColor];
}

- (UIColor *)darkForegroundColor {
  return [self darken:self.buttonForegroundColor];
}

@end
