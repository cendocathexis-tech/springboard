#import "SBWDWidgetHost.h"
#import "SBWDManager.h"

@interface SBWDWidgetHost () <WKNavigationDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, weak) UIView *listView;
@property (nonatomic, assign) NSUInteger page;
@property (nonatomic, assign) BOOL loaded;
@end

@implementation SBWDWidgetHost

- (WKWebView *)webView {
    if (_webView) {
        return _webView;
    }
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *ucc = [[WKUserContentController alloc] init];
    [ucc addScriptMessageHandler:self name:@"sbwd"];
    config.userContentController = ucc;
    config.allowsInlineMediaPlayback = YES;
    
    // Используйте более безопасный способ установки параметров
    if (@available(iOS 14.5, *)) {
        config.defaultWebpagePreferences.allowsContentJavaScript = YES;
    }
    
    WKWebView *view = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    view.opaque = NO;
    view.backgroundColor = [UIColor clearColor];
    view.scrollView.backgroundColor = [UIColor clearColor];
    view.scrollView.scrollEnabled = NO;
    view.scrollView.bounces = NO;
    view.userInteractionEnabled = NO;
    view.navigationDelegate = self;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (@available(iOS 11.0, *)) {
        view.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    _webView = view;
    return _webView;
}

- (void)attachToListView:(UIView *)listView page:(NSUInteger)page {
    if (!listView) {
        return;
    }
    BOOL pageChanged = (self.listView != listView) || (self.page != page);
    self.listView = listView;
    self.page = page;

    WKWebView *web = self.webView;
    if (web.superview != listView) {
        [web removeFromSuperview];
        [listView insertSubview:web atIndex:0];
    }
    web.frame = listView.bounds;

    if (!self.loaded) {
        NSURL *url = [[SBWDManager shared] runtimeIndexURL];
        NSURL *access = [NSURL fileURLWithPath:SBWDSupportPath()];
        [web loadFileURL:url allowingReadAccessToURL:access];
        self.loaded = YES;
    } else if (pageChanged) {
        [self injectDocument];
    }
}

- (void)reload {
    self.loaded = NO;
    if (self.listView) {
        [self attachToListView:self.listView page:self.page];
    }
}

- (void)detach {
    [_webView removeFromSuperview];
}

- (void)injectDocument {
    NSDictionary *doc = [[SBWDManager shared] hydratedDocumentForPage:self.page];
    if ([doc[@"enabled"] respondsToSelector:@selector(boolValue)] && ![doc[@"enabled"] boolValue]) {
        doc = @{ @"version": @1, @"page": @(self.page), @"elements": @[] };
    }
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:doc options:0 error:&error];
    NSString *jsonText = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] ?: @"{}";
    NSString *css = [self escapeForJS:[[SBWDManager shared] fontCSS]];
    NSString *js = [NSString stringWithFormat:@"window.SBWDApply && window.SBWDApply(%@, '%@');", jsonText, css];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

- (NSString *)escapeForJS:(NSString *)text {
    NSString *escaped = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    return escaped;
}

// MARK: - WKNavigationDelegate
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self injectDocument];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"WebView navigation error: %@", error);
}

// MARK: - WKScriptMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController 
   didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"sbwd"]) {
        NSLog(@"Received SBWD message: %@", message.body);
        // Обработайте сообщение от JavaScript
    }
}

@end
