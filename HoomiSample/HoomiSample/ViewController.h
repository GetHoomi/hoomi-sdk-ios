/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import <UIKit/UIKit.h>
#import <Hoomi/Hoomi.h>

@interface ViewController : UIViewController

@property (strong, nonatomic) IBOutlet HFLoginButton *loginButton;
@property (strong, nonatomic) IBOutlet UILabel *userIdLabel;
@property (strong, nonatomic) IBOutlet UITextField *nameTextField;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
- (IBAction)saveButtonClicked:(id)sender;

@end

