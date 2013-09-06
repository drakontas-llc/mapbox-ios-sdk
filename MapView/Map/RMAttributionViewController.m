//
//  RMAttributionViewController.m
//  MapView
//
//  Created by Justin Miller on 6/19/12.
//  Copyright (c) 2012 MapBox / Development Seed. All rights reserved.
//

#import "RMAttributionViewController.h"

#import "RMMapView.h"
#import "RMTileSource.h"

@interface RMMapView (RMAttributionViewControllerPrivate)

@property (nonatomic, assign) UIViewController *viewControllerPresentingAttribution;

@end

#pragma mark -

@interface RMAttributionViewController () <UIWebViewDelegate>

@property (nonatomic, weak) RMMapView *mapView;

@end

#pragma mark -

@implementation RMAttributionViewController

- (id)initWithMapView:(RMMapView *)mapView
{
    self = [super initWithNibName:nil bundle:nil];
    
    if (self)
        _mapView = mapView;

    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.title = @"Map Attribution";

    self.view.backgroundColor = (RMPostVersion7 ? [UIColor colorWithWhite:1 alpha:0.9] : [UIColor darkGrayColor]);

    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss:)]];

    UIWebView *webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    webView.delegate = self;
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;

    // don't bounce for page curled presentation
    //
    if (RMPreVersion7)
    {
        if ([webView respondsToSelector:@selector(scrollView)])
        {
            webView.scrollView.bounces = NO;
        }
        else
        {
            for (id subview in webView.subviews)
                if ([[subview class] isSubclassOfClass:[UIScrollView class]])
                    ((UIScrollView *)subview).bounces = NO;
        }
    }

    // build up attribution from tile sources
    //
    NSMutableString *attribution = [NSMutableString string];

    for (id <RMTileSource>tileSource in _mapView.tileSources)
    {
        if ([tileSource respondsToSelector:@selector(shortAttribution)])
        {
            if ([attribution length])
                [attribution appendString:@" "];

            if ([tileSource shortAttribution])
                [attribution appendString:[tileSource shortAttribution]];
        }
    }

    // fallback to generic OSM attribution
    //
    if ( ! [attribution length])
        [attribution setString:@"Map data © OpenStreetMap contributors<br/><a href=\"http://mapbox.com/about/maps/\">More</a>"];

    // build up HTML styling
    //
    NSMutableString *contentString = [NSMutableString string];

    [contentString appendString:@"<style type='text/css'>"];

    NSString *linkColor, *textColor, *fontSize, *margin;

    if (RMPostVersion7)
    {
        CGFloat r,g,b;
        [self.view.tintColor getRed:&r green:&g blue:&b alpha:nil];
        linkColor = [NSString stringWithFormat:@"rgb(%i,%i,%i)", (NSUInteger)(r * 255.0), (NSUInteger)(g * 255.0), (NSUInteger)(b * 255.0)];
        textColor = @"black";
        fontSize  = [NSString stringWithFormat:@"font-size: %i; ", (NSUInteger)[[UIFont preferredFontForTextStyle:UIFontTextStyleBody] pointSize]];
        margin    = @"margin: 20px; ";
    }
    else
    {
        linkColor = @"white";
        textColor = @"lightgray";
        fontSize  = @"";
        margin    = @"";
    }

    [contentString appendString:[NSString stringWithFormat:@"a:link { color: %@; text-decoration: none; }", linkColor]];
    [contentString appendString:[NSString stringWithFormat:@"body { color: %@; font-family: Helvetica Neue; %@text-align: center; %@}", textColor, fontSize, margin]];
    [contentString appendString:@"</style>"];

    // add SDK info
    //
    [attribution insertString:[NSString stringWithFormat:@"%@ uses the MapBox iOS SDK © 2013 MapBox, Inc.<br/><a href='http://mapbox.com/mapbox-ios-sdk'>More</a><br/><br/>", [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleDisplayName"]]  atIndex:0];

    // add tinted logo
    //
    UIImage *logoImage = [RMMapView resourceImageNamed:@"mapbox-logo.png"];
    UIGraphicsBeginImageContextWithOptions(logoImage.size, NO, [[UIScreen mainScreen] scale]);
    [logoImage drawAtPoint:CGPointMake(0, 0)];
    CGContextSetBlendMode(UIGraphicsGetCurrentContext(), kCGBlendModeSourceIn);
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [self.view.tintColor CGColor]);
    CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, logoImage.size.width, logoImage.size.height));
    NSString *tempFile = [[NSTemporaryDirectory() stringByAppendingString:@"/"] stringByAppendingString:[NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]]];
    [UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext()) writeToFile:tempFile atomically:YES];
    UIGraphicsEndImageContext();
    [attribution insertString:[NSString stringWithFormat:@"<img src='file://%@' width='100' height='100'/><br/><br/>", tempFile] atIndex:0];

    // add attribution
    //
    [contentString appendString:attribution];

    [webView loadHTMLString:contentString baseURL:nil];
    [self.view addSubview:webView];

    // add activity indicator
    //
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    spinner.center = webView.center;
    spinner.tag = 1;
    [self.view insertSubview:spinner atIndex:0];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [_mapView.viewControllerPresentingAttribution shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

#pragma mark -

- (void)dismiss:(id)sender
{
    self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self.presentingViewController dismissModalViewControllerAnimated:YES];
}

#pragma mark -

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        [[UIApplication sharedApplication] openURL:request.URL];
        
        [self performSelector:@selector(dismiss:) withObject:nil afterDelay:0];
    }
    
    return [[request.URL scheme] isEqualToString:@"about"];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [[self.view viewWithTag:1] removeFromSuperview];
}

@end
