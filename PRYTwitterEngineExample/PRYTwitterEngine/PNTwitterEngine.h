//
//  PRYTwitterEngine.h
//  PRYTwitterEngineExample
//
//  Created by iosdev on 2/27/13.
//  Copyright (c) 2013 iosdev. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PNTwitterEngineDelegate <NSObject>
- (void) saveAccessToken:(NSString *)accessToken;
- (NSString *) loadAccessToken;
// These delegate methods are called after a connection has been established
- (void)requestSucceeded:(NSString *)connectionIdentifier result:(NSDictionary *)objDic;
- (void)requestFailed:(NSString *)connectionIdentifier withError:(NSError *)error;

@optional
- (void) loginDialogDidShow;
- (void) loginDialogDidDismiss;
@end

@interface PNTwitterEngine : NSObject
@property (nonatomic, assign) id<PNTwitterEngineDelegate> delegate;
@property (nonatomic, retain) NSString *userID;
@property (nonatomic, retain) NSString *userName;


//
// Authorizition&init method
//

- (id)initWithConsumerKey:(NSString *)consumerKey andSecret:(NSString *)consumerSecret;

- (void) setAccessToken:(NSString *)accessToken;
- (void) clearAccessToken:(BOOL)clearCookie;
- (void) loadAccessToken;
- (BOOL) isAuthorized;

- (void) showLoginDialog; // just one less line of code

//
// REST API
//

// Tweets
// status/update
- (NSString *) postMessage:(NSString *)message;
- (NSString *) postMessage:(NSString *)message latitude:(double)lat longitude:(double)lng;

// Users
// users/show
- (NSString *) getUserInfo:(NSString *) userID;
@end





