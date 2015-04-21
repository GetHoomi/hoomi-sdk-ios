/*
 * Copyright (c) 2015. Hoomi, Inc. All Rights Reserved
 */

#import "ViewController.h"
#import <Bolts/Bolts.h>

@interface ViewController () <HFLoginButtonDelegate>

@property (nonatomic, readwrite, strong) HFAppData *appData;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  self.loginButton.redirectUri = [NSURL URLWithString:@"co.hoomi.nyan://login/"];
  self.loginButton.scopes = @[@"user:app:data:read", @"user:app:data:write"];
  self.loginButton.delegate = self;
  self.loginButton.buttonStyle = HFLoginButtonStyleWhiteOnGreen;
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)saveButtonClicked:(id)sender {
  [self.nameTextField resignFirstResponder];
  if (self.activityIndicator.isAnimating) {
    return;
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    HFClient *client = [HFClient currentClient];
    self.appData.data[@"name"] = self.nameTextField.text;
    [self.activityIndicator startAnimating];
    [[client setAppDataAsync:self.appData.data] continueWithExecutor:[BFExecutor mainThreadExecutor]
                                                           withBlock:^id(BFTask *task) {
                                                             [self.activityIndicator stopAnimating];
                                                             return nil;
                                                           }];
  });
}

- (void)buttonWillPerformHoomiAuthorization:(HFLoginButton *)button {
  [self.activityIndicator startAnimating];
}

- (void)button:(HFLoginButton *)button didPerformHoomiAuthorizationWithResult:(HFAccessToken *)token error:(NSError *)error {
  if (!token) {
    NSLog(@"Login failed!");
    [self.activityIndicator stopAnimating];
    return;
  }
  HFClient *client = [HFClient currentClient];
  BFTask *task = [[client tokenInformationAsync:token] continueWithExecutor:[BFExecutor mainThreadExecutor]
                                                                  withBlock:^id(BFTask *task) {
                                                                    self.userIdLabel.text = [task.result userId];
                                                                    return [client appDataAsync];
                                                                  }];
  task = [task continueWithExecutor:[BFExecutor mainThreadExecutor]
                          withBlock:^id(BFTask *task) {
                            self.appData = task.result;
                            self.nameTextField.text = self.appData.data[@"name"];
                            return nil;
                          }];
  task = [task continueWithExecutor:[BFExecutor mainThreadExecutor]
                          withBlock:^id(BFTask *task) {
                            if (task.error) {
                              NSLog(@"Error: %@", task.error);
                            }
                            [self.activityIndicator stopAnimating];
                            return task;
                          }];
}

@end
