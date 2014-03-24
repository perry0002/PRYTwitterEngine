//
//  ViewController.h
//  PRYTwitterEngineExample
//
//  Created by iosdev on 2/27/13.
//  Copyright (c) 2013 iosdev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PNTwitterEngine.h"


@interface ViewController : UIViewController <PNTwitterEngineDelegate, UITextViewDelegate>
@property (nonatomic, retain) IBOutlet UITextView *textView;
@property (nonatomic, retain) IBOutlet UILabel *label;
@property (nonatomic, retain) IBOutlet UILabel *screenNameLabel;
@property (nonatomic, retain) IBOutlet UIControl *backControl;

@property (nonatomic, retain) PNTwitterEngine *twEngine;

- (IBAction) backControlTapped:(id)sender;
- (IBAction)login:(id)sender;
- (IBAction)logout:(id)sender;

- (IBAction)post:(id)sender;
@end
