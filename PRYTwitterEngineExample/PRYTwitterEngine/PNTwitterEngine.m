//
//  PRYTwitterEngine.m
//  PRYTwitterEngineExample
//
//  Created by iosdev on 2/27/13.
//  Copyright (c) 2013 iosdev. All rights reserved.
//

#import "PNTwitterEngine.h"
#import "OAuthConsumer.h"
#import "PNTwitterHttpURLConnection.h"
#import "JSON.h"


#define TWITTER_API_BASEURL @"https://api.twitter.com/1.1/"
#define TWITTER_TIMEOUT  20

#define GCDBackgroundThread dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
#define GCDMainThread dispatch_get_main_queue()

@interface PNTwitterDialog : UIView <UIWebViewDelegate>

@property (strong, nonatomic) PNTwitterEngine *engine;
@property (strong, nonatomic) UIWebView *theWebView;
@property (strong, nonatomic) UIActivityIndicatorView *spinner;
@property (strong, nonatomic) OAToken *requestToken;

- (id)initWithEngine:(PNTwitterEngine *)theEngine;
- (NSString *)locatePin;

//- (void)showPinCopyPrompt;
//- (void)removePinCopyPrompt;

- (void) show;

@end


@interface NSString (PNTwitterEngine)
+ (NSString*)stringWithNewUUID;
- (NSString *)trimForTwitter;
- (BOOL)isNumeric;
@end

@implementation NSString (PNTwitterEngine)

- (NSString *)trimForTwitter {
    NSString *string = [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return (string.length > 140)?[string substringToIndex:140]:string;
}

- (BOOL)isNumeric {
	const char *raw = (const char *)[self UTF8String];
    
	for (int i = 0; i < strlen(raw); i++) {
		if (raw[i] < '0' || raw[i] > '9') {
            return NO;
        }
	}
	return YES;
}

+ (NSString*)stringWithNewUUID
{
    // Create a new UUID
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    
    // Get the string representation of the UUID
    NSString *newUUID = (NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return [newUUID autorelease];
}

@end


@interface PNTwitterEngine ()
@property (nonatomic, retain) OAConsumer *consumer;
@property (nonatomic, retain) OAToken *token;
@property (nonatomic, retain) NSMutableDictionary *connections;
@end

@implementation PNTwitterEngine
@synthesize delegate = _delegate;
@synthesize consumer = _consumer;
@synthesize token = _token;
@synthesize userID = _userID;
@synthesize userName = _userName;
@synthesize connections = _connections;


- (void) dealloc{
    [_consumer release];
    [_token release];
    [_userID release];
    [_userName release];
    
    NSArray *cons = [_connections allValues];
    for (NSURLConnection *connection in cons) {
        [connection cancel];
    }
    [_connections release];
    [super dealloc];
}

#pragma mark - Outh&init Methods
- (id)initWithConsumerKey:(NSString *)consumerKey andSecret:(NSString *)consumerSecret{
    self = [super init];
    if (self) {
        _consumer = [[OAConsumer alloc]initWithKey:consumerKey secret:consumerSecret];
        _connections = [[NSMutableDictionary alloc] initWithCapacity:0];
    }
    return self;
}


- (NSString *)extractUsernameFromHTTPBody:(NSString *)body {
	if (!body) {
        return nil;
    }
	
	NSArray *tuples = [body componentsSeparatedByString:@"&"];
	if (tuples.count < 1) {
        return nil;
    }
	
	for (NSString *tuple in tuples) {
		NSArray *keyValueArray = [tuple componentsSeparatedByString:@"="];
		
		if (keyValueArray.count == 2) {
			NSString *key = [keyValueArray objectAtIndex: 0];
			NSString *value = [keyValueArray objectAtIndex: 1];
			
			if ([key isEqualToString:@"screen_name"]) {
                return value;
            }
		}
	}
	
	return nil;
}

- (NSString *)extractUserIDFromHTTPBody:(NSString *)body {
    if (!body) {
        return nil;
    }
	
	NSArray *tuples = [body componentsSeparatedByString:@"&"];
	if (tuples.count < 1) {
        return nil;
    }
	
	for (NSString *tuple in tuples) {
		NSArray *keyValueArray = [tuple componentsSeparatedByString:@"="];
		
		if (keyValueArray.count == 2) {
			NSString *key = [keyValueArray objectAtIndex: 0];
			NSString *value = [keyValueArray objectAtIndex: 1];
			
			if ([key isEqualToString:@"user_id"]) {
                return value;
            }
		}
	}
	
	return nil;
}

- (void) setAccessToken:(NSString *)accessToken{
    self.token = [[[OAToken alloc] initWithHTTPResponseBody:accessToken] autorelease];
    
    self.userName = [self extractUsernameFromHTTPBody:accessToken];
    self.userID = [self extractUserIDFromHTTPBody:accessToken];
    
    if ([_delegate respondsToSelector:@selector(saveAccessToken:)]) {
        [_delegate saveAccessToken:accessToken];
    }
}

- (void) clearAccessToken:(BOOL)clearCookie{
    [self setAccessToken:@""];
    
    if (clearCookie) {
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
        NSMutableArray *twCookies = [NSMutableArray arrayWithCapacity:0];
        for (NSHTTPCookie *cookie in cookies) {
            if ([cookie.domain hasSuffix:@"twitter.com"]) {
                [twCookies addObject:cookie];
            }
        }
        for (NSHTTPCookie *cookie in twCookies) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
        }
    }
}

- (void) loadAccessToken{
    if ([_delegate respondsToSelector:@selector(loadAccessToken)]) {
        NSString *accessToken = [_delegate loadAccessToken];
        
        self.token = [[[OAToken alloc] initWithHTTPResponseBody:accessToken] autorelease];
        
        self.userName = [self extractUsernameFromHTTPBody:accessToken];
        self.userID = [self extractUserIDFromHTTPBody:accessToken];
    }
    
}

- (BOOL)isAuthorized {
    if (!self.consumer) {
        return NO;
    }
    
	if (self.token.key && self.token.secret) {
        if (self.token.key.length > 0 && self.token.secret.length > 0) {
            return YES;
        }
    }
    
	return NO;
}

- (void) showLoginDialog {
    PNTwitterDialog *dialog = [[PNTwitterDialog alloc] initWithEngine:self];
    [dialog show];
    [dialog release];    
}


#pragma mark - REST API Methods
- (NSString *) getUserInfo:(NSString *) userID{
    if (nil == userID) {
        return nil;
    }
    

    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.json", TWITTER_API_BASEURL, @"users/show"]];
    OAMutableURLRequest *request = [[[OAMutableURLRequest alloc]initWithURL:baseURL consumer:self.consumer token:self.token realm:nil signatureProvider:nil] autorelease];

    OARequestParameter *param_userID = [OARequestParameter requestParameterWithName:@"user_id" value:userID];
    
    return [self sendGETRequest:request withParameters:[NSArray arrayWithObjects:param_userID, nil]];
}


- (NSString *) postMessage:(NSString *)message{
    return [self postMessage:message latitude:MAXFLOAT longitude:MAXFLOAT];
}

- (NSString *) postMessage:(NSString *)message latitude:(double)lat longitude:(double)lng {
    if (message.length == 0) {
        return [NSError errorWithDomain:@"Bad Request: The request you are trying to make is missing parameters." code:400 userInfo:nil];
    }
    
    message = [message trimForTwitter];
    
    NSURL *baseURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@.json",TWITTER_API_BASEURL,@"statuses/update"]];
    
    OARequestParameter *paramStatus = [OARequestParameter requestParameterWithName:@"status" value:message];
    
    
    OAMutableURLRequest *request = [[[OAMutableURLRequest alloc]initWithURL:baseURL consumer:self.consumer token:self.token realm:nil signatureProvider:nil] autorelease];
    
    NSMutableArray *params = [NSMutableArray array];
    [params addObject:paramStatus];
    if (lat != MAXFLOAT && lng != MAXFLOAT) {
        OARequestParameter *paramLat = [OARequestParameter requestParameterWithName:@"lat" value:[NSString stringWithFormat:@"%lf", lat]];
        OARequestParameter *paramLng = [OARequestParameter requestParameterWithName:@"long" value:[NSString stringWithFormat:@"%lf", lng]];
        
        [params addObject:paramLat];
        [params addObject:paramLng];
    }
    
    // PARAMETERS WERE MALFORMED due to setting the params before the HTTP method... lulz
    
    return [self sendPOSTRequest:request withParameters:params];
}


#pragma mark - NSURLConnectionDelegate Methods
#pragma mark NSURLConnection delegate methods

/*
- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}
*/

- (void)connection:(PNTwitterHttpURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [connection resetDataLength];
    
    // Get response code.
    NSHTTPURLResponse *resp = (NSHTTPURLResponse *)response;
    [connection setResponse:resp];
    NSInteger statusCode = [resp statusCode];
    NSLog(@"status code:%d", statusCode);
/*    
    if (statusCode == 304 || [connection responseType] == MGTwitterGeneric) {
        
        // Not modified, or generic success.
		if ([self _isValidDelegateForSelector:@selector(requestSucceeded:)])
			[_delegate requestSucceeded:[connection identifier]];
        if (statusCode == 304) {
            [self parsingSucceededForRequest:[connection identifier]
                              ofResponseType:[connection responseType]
                           withParsedObjects:[NSArray array]];
        }
        
        // Destroy the connection.
        [connection cancel];
		NSString *connectionIdentifier = [connection identifier];
		[_connections removeObjectForKey:connectionIdentifier];
		if ([self _isValidDelegateForSelector:@selector(connectionFinished:)])
			[_delegate connectionFinished:connectionIdentifier];
         
    }
*/    
}


- (void)connection:(PNTwitterHttpURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to the receivedData.
    [connection appendData:data];
}


- (void)connection:(PNTwitterHttpURLConnection *)connection didFailWithError:(NSError *)error
{
    // Inform delegate.
	if ([_delegate respondsToSelector:@selector(requestFailed:withError:)]){
		[_delegate requestFailed:[connection identifier]
					   withError:error];
	}
    
    [self.connections removeObjectForKey:[connection identifier]];
}


- (void)connectionDidFinishLoading:(PNTwitterHttpURLConnection *)connection
{
    NSString *result = [[[NSString alloc] initWithData:connection.data encoding:NSUTF8StringEncoding] autorelease];
    
    id obj = [result JSONValue];
    if (![obj isKindOfClass:[NSDictionary class]]) {
        if ([_delegate respondsToSelector:@selector(requestFailed:withError:)]) {
            [_delegate requestFailed:[connection identifier] withError:[NSError errorWithDomain:@"Data wrong" code:555 userInfo:nil]];
        }
        return;
    }
    
    if ([_delegate respondsToSelector:@selector(requestSucceeded:result:)]){
        [_delegate requestSucceeded:[connection identifier] result:obj];
    }
    
    [self.connections removeObjectForKey:[connection identifier]];
}

#pragma mark - Private Methos
- (NSString *)sendGETRequest:(OAMutableURLRequest *)request withParameters:(NSArray *)params {
    
    if (![self isAuthorized]) {
        return [NSError errorWithDomain:@"You are not authorized with Twitter. Please sign in." code:401 userInfo:[NSDictionary dictionaryWithObject:request forKey:@"request"]];
    }
    
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setTimeoutInterval:TWITTER_TIMEOUT];
    
    [request setHTTPMethod:@"GET"];
    [request setParameters:params];
    [request prepare];

    
    PNTwitterHttpURLConnection *connection = [[[PNTwitterHttpURLConnection alloc] initWithRequest:request delegate:self] autorelease];
    [connection start];
    [self.connections setObject:connection forKey:[connection identifier]];
    return [connection identifier];
}


//
// sendRequest:
//

- (NSString *)sendPOSTRequest:(OAMutableURLRequest *)request withParameters:(NSArray *)params {
    
    if (![self isAuthorized]) {
        return [NSError errorWithDomain:@"You are not authorized via OAuth" code:401 userInfo:[NSDictionary dictionaryWithObject:request forKey:@"request"]];
    }
    
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setTimeoutInterval:TWITTER_TIMEOUT];
    
    [request setHTTPMethod:@"POST"];
    [request setParameters:params];
    [request prepare];

    
    PNTwitterHttpURLConnection *connection = [[[PNTwitterHttpURLConnection alloc] initWithRequest:request delegate:self] autorelease];
    [connection start];
    [self.connections setObject:connection forKey:[connection identifier]];
    return [connection identifier];
}

@end




@implementation PNTwitterDialog

@synthesize theWebView = _theWebView, spinner = _spinner;
@synthesize requestToken = _requestToken, engine = _engine;

- (id)initWithEngine:(PNTwitterEngine *)theEngine{
    
    if (self = [super initWithFrame:CGRectMake(0, 20, 320, 460)]) {
        self.engine = theEngine;
        
        if (self = [super initWithFrame:CGRectZero]) {         
            self.backgroundColor = [UIColor colorWithRed:100/255.0 green:100/255.0 blue:100/255.0 alpha:0.6];
            //self.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.6];
            self.autoresizesSubviews = NO;
            //self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            //self.contentMode = UIViewContentModeRedraw;
            
            UIImage* closeImage = [UIImage imageNamed:@"tclose1.png"];
            
            UIColor* color = [UIColor colorWithRed:167.0/255 green:184.0/255 blue:216.0/255 alpha:1];
            
            CGRect rect = CGRectMake(0, 0, 320, 460);
            _theWebView = [[UIWebView alloc] initWithFrame:CGRectMake(10, 10, rect.size.width-20, rect.size.height-20)];
            _theWebView.delegate = self;
            _theWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _theWebView.dataDetectorTypes = UIDataDetectorTypeNone;
            [self addSubview:_theWebView];
            
            _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
                        UIActivityIndicatorViewStyleGray];
            _spinner.autoresizingMask =
            UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin
            | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
            [self addSubview:_spinner];
            
            UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
            closeButton.frame = CGRectMake(3, 3, closeImage.size.width, closeImage.size.height);
            [closeButton setImage:closeImage forState:UIControlStateNormal];
            [closeButton setTitleColor:color forState:UIControlStateNormal];
            [closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
            [closeButton addTarget:self action:@selector(dismiss)
                  forControlEvents:UIControlEventTouchUpInside];
            
            closeButton.showsTouchWhenHighlighted = YES;
            closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin
            | UIViewAutoresizingFlexibleBottomMargin;
            [self addSubview:closeButton];

            _spinner.transform = CGAffineTransformMakeScale(1.5, 1.5);
            _spinner.center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
            _spinner.hidesWhenStopped = YES;
        }
    }
    return self;
}


- (void)gotPin:(NSString *)pin {
    [self.requestToken setVerifier:pin];
    [self finishAuthWithPin:pin andRequestToken:self.requestToken];
    [self dismiss];
}

- (void)pasteboardChanged:(NSNotification *)note {
	UIPasteboard *pb = [UIPasteboard generalPasteboard];
	
	if ([note.userInfo objectForKey:UIPasteboardChangedTypesAddedKey] == nil) {
        return;
    }
	
	NSString *copied = pb.string;
	
	if (copied.length != 7 || !copied.isNumeric) {
        return;
    }
	
	[self gotPin:copied];
}

- (NSString *)locatePin {
    // JavaScript for the newer Twitter PIN image
	NSString *js = @"var d = document.getElementById('oauth-pin'); if (d == null) d = document.getElementById('oauth_pin'); " \
    "if (d) { var d2 = d.getElementsByTagName('code'); if (d2.length > 0) d2[0].innerHTML; }";
	NSString *pin = [[self.theWebView stringByEvaluatingJavaScriptFromString:js]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if (pin.length == 7) {
		return pin;
	} else {
		// Older version of Twitter PIN Image
        js = @"var d = document.getElementById('oauth-pin'); if (d == null) d = document.getElementById('oauth_pin'); if (d) d = d.innerHTML; d;";
		pin = [[self.theWebView stringByEvaluatingJavaScriptFromString:js]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if (pin.length == 7) {
			return pin;
		}
	}
	
	return nil;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    //self.theWebView.userInteractionEnabled = YES;
    NSString *authPin = [self locatePin];
    
    if (authPin.length) {
        [self gotPin:authPin];
        return;
    }
    
    NSString *formCount = [webView stringByEvaluatingJavaScriptFromString:@"document.forms.length"];
    
    if ([formCount isEqualToString:@"0"]) {
        //[self showPinCopyPrompt];
    }
	
	[self endLoad];
    
    self.theWebView.hidden = NO;
}
/*
- (void)showPinCopyPrompt {
	if (self.pinCopyPromptBar.superview) {
        return;
    }
    
	self.pinCopyPromptBar.center = CGPointMake(self.pinCopyPromptBar.bounds.size.width/2, self.pinCopyPromptBar.bounds.size.height/2);
	[self.view insertSubview:self.pinCopyPromptBar belowSubview:navBar];
	
	[UIView beginAnimations:nil context:nil];
    self.pinCopyBar.center = CGPointMake(self.pinCopyPromptBar.bounds.size.width/2, navBar.bounds.size.height+pinCopyBar.bounds.size.height/2);
	[UIView commitAnimations];
}

- (void)removePinCopyPrompt {
    if (self.pinCopyBar.superview) {
        [self.pinCopyBar removeFromSuperview];
    }
}

- (UIView *)pinCopyPromptBar {
	if (self.pinCopyBar == nil) {
		self.pinCopyBar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 44, self.view.bounds.size.width, 44)];
		self.pinCopyBar.barStyle = UIBarStyleBlackTranslucent;
		self.pinCopyBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
        self.pinCopyBar.items = [NSArray arrayWithObjects:[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], [[UIBarButtonItem alloc]initWithTitle:@"Select and Copy the PIN" style: UIBarButtonItemStylePlain target:nil action: nil], [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], nil];
        
	}
	return self.pinCopyBar;
}
*/
- (void)webViewDidStartLoad:(UIWebView *)webView {
    //self.theWebView.userInteractionEnabled = NO;
    [self startLoad];
    //[self.theWebView setHidden:YES];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    BOOL isNotCancelLink = !strstr([[NSString stringWithFormat:@"%@",request.URL]UTF8String], "denied=");
    
	NSData *data = [request HTTPBody];
	char *raw = data?(char *)[data bytes]:"";
    
    if (!isNotCancelLink) {
        [self dismiss];
        return NO;
    }
	
	if (raw && (strstr(raw, "cancel=") || strstr(raw, "deny="))) {
		[self dismiss];
		return NO;
	}
	return YES;
}

- (void) close {
    [self dismiss];
}

- (void) show {
    UIWindow* window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];    
    [window addSubview:self];
    
    CGRect frame = [UIScreen mainScreen].applicationFrame;
    /*
    CGPoint center = CGPointMake(
                                 frame.origin.x + ceil(frame.size.width/2),
                                 frame.origin.y + ceil(frame.size.height/2));
    */
    self.frame = frame;
    
    self.transform = CGAffineTransformMakeScale(0.001, 0.001);
    [UIView animateWithDuration:0.2 animations:^{
        self.transform = CGAffineTransformMakeScale(1.1, 1.1);
    } completion:^(BOOL finished) {
        [self startLoad];
        
        dispatch_async(GCDBackgroundThread, ^{
            @autoreleasepool {
                NSString *reqString = [self getRequestTokenString];
                
                if (reqString.length == 0) {
                    [self dismiss];
                    return;
                }
                
                self.requestToken = [[[OAToken alloc]initWithHTTPResponseBody:reqString] autorelease];
                NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://api.twitter.com/oauth/authorize?oauth_token=%@",self.requestToken.key]]];
                
                dispatch_sync(GCDMainThread, ^{
                    @autoreleasepool {
                        [self.theWebView loadRequest:request];
                    }
                });
            }
        });
        
        [UIView animateWithDuration:0.15 animations:^{
            self.transform = CGAffineTransformMakeScale(0.9, 0.9);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.15 animations:^{
                self.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                if ([self.engine.delegate respondsToSelector:@selector(loginDialogDidShow)]) {
                    [self.engine.delegate loginDialogDidShow];
                }
            }];
        }];
    }];
}

- (void) dismiss {
    [self endLoad];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if ([self.engine.delegate respondsToSelector:@selector(loginDialogDidDismiss)]) {
            [self.engine.delegate loginDialogDidDismiss];
        }
    }];
}


#pragma mark - Private Methods
- (void) startLoad {
    [self.spinner startAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void) endLoad {
    [self.spinner stopAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (NSString *)getRequestTokenString {
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/oauth/request_token"];
    
    OAMutableURLRequest *request = [[[OAMutableURLRequest alloc]initWithURL:url consumer:self.engine.consumer token:nil realm:nil signatureProvider:nil] autorelease];
    
    [request setHTTPMethod:@"POST"];
    [request prepare];
    
    NSError *error = nil;
    NSHTTPURLResponse *response = nil;
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (response == nil || responseData == nil || error != nil) {
        return nil;
    }
    
    if (response.statusCode >= 304) {
        return nil;
    }
    
    NSString *responseBody = [[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
    
    return responseBody;
}


- (int)finishAuthWithPin:(NSString *)pin andRequestToken:(OAToken *)reqToken {
    if (pin.length != 7) {
        return 1;
    }
    
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/oauth/access_token"];
    
    OAMutableURLRequest *request = [[[OAMutableURLRequest alloc]initWithURL:url consumer:self.engine.consumer token:reqToken realm:nil signatureProvider:nil] autorelease];
    [request setHTTPMethod:@"POST"];
    [request prepare];
    
    NSError *error = nil;
    NSHTTPURLResponse *response = nil;
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (response == nil || responseData == nil || error != nil) {
        return 1;
    }
    
    if (response.statusCode >= 304) {
        return 1;
    }
    
    NSString *responseBody = [[[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
    
    if (responseBody.length == 0) {
        return 1;
    }
    
    [self.engine setAccessToken:responseBody];
    
    return 0;
}
@end

