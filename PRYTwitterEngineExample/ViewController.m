//
//  ViewController.m
//  PRYTwitterEngineExample
//
//  Created by iosdev on 2/27/13.
//  Copyright (c) 2013 iosdev. All rights reserved.
//

#import "ViewController.h"

#define kOperUserInfo @"userInfo"
#define kOperStatusUpdate @"statusUpdate"

@interface ViewController ()
@property (nonatomic, retain) NSMutableDictionary *operations;
@end

@implementation ViewController
@synthesize textView = _textView;
@synthesize label = _label;
@synthesize screenNameLabel = _screenNameLabel;
@synthesize twEngine = _twEngine;
@synthesize backControl = _backControl;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.operations = [NSMutableDictionary dictionary];
    
    self.twEngine = [[[PNTwitterEngine alloc] initWithConsumerKey:@"XyOCXnX0l9axVPXpQLBcQ" andSecret:@"ZcQlji9o9Wao3InP7Dw8XJGZkV33lFj3MZOZOZR07g"] autorelease];
    self.twEngine.delegate = self;
    [self.twEngine loadAccessToken];
    
    if ([self.twEngine isAuthorized]) {
        NSString *identifier = [self.twEngine getUserInfo:self.twEngine.userID];
        [self.operations setObject:identifier forKey:kOperUserInfo];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)dealloc{
    _twEngine.delegate = nil;
    [_twEngine release];
    [_label release];
    [_textView release];
    [_backControl release];
    [_operations release];
    
    [super dealloc];
}

- (IBAction)login:(id)sender {
    if ([_twEngine isAuthorized]) {
        
        _label.text = @"twitter 已经登陆";
        return;
    }
    
    [self.twEngine showLoginDialog];
}

- (IBAction)logout:(id)sender {
    [self.twEngine clearAccessToken:YES];
}

- (IBAction)post:(id)sender {
    NSString *identifier = [self.twEngine postMessage:self.textView.text latitude:31.222222 longitude:121.333333];
    
    [self.operations setObject:identifier forKey:kOperStatusUpdate];
}


- (IBAction) backControlTapped:(id)sender{
    [self.textView resignFirstResponder];
    self.backControl.hidden = YES;
}


#pragma mark - PRYTwitterEngineDelegate Methods
- (void) saveAccessToken:(NSString *)accessToken{
    [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:@"accessToken"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *) loadAccessToken{
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"accessToken"];
}

// These delegate methods are called after a connection has been established
- (void)requestSucceeded:(NSString *)connectionIdentifier result:(NSDictionary *)objDic{
    if ([connectionIdentifier isEqualToString:[self.operations objectForKey:kOperUserInfo]]) {
        self.screenNameLabel.text = [objDic objectForKey:@"name"];
    }else if ([connectionIdentifier isEqualToString:[self.operations objectForKey:kOperStatusUpdate]]) {
        self.label.text = @"Send OK";
    }
}

- (void)requestFailed:(NSString *)connectionIdentifier withError:(NSError *)error{
    self.label.text = error.domain;
}


#pragma mark - UITextViewDelegate Methods
- (BOOL)textViewShouldBeginEditing:(UITextView *)textView{
    self.backControl.hidden = NO;
    
    return YES;
}
@end
