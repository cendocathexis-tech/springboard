#import "SBWDEditorPresenter.h"
#import "SBWDManager.h"
#import <WebKit/WebKit.h>

@interface SBWDEditorPresenter () <WKNavigationDelegate, WKScriptMessageHandler, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, assign) NSUInteger page;
@property (nonatomic, copy) void (^pendingImageCallback)(NSString *relativePath);
@end

@implementation SBWDEditorPresenter

+ (instancetype)shared {
    static SBWDEditorPresenter *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[SBWDEditorPresenter alloc] init];
    });
    return instance;
}

- (void)showDiagnostic:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) {
            self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            self.window.windowLevel = UIWindowLevelStatusBar + 120.0;
            self.rootViewController = [[UIViewController alloc] init];
            self.window.rootViewController = self.rootViewController;
        }
        self.rootViewController.view.backgroundColor = [UIColor blackColor];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(self.window.bounds, 24.0, 80.0)];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        label.textColor = [UIColor whiteColor];
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont systemFontOfSize:15.0];
        label.text = message;
        [self.rootViewController.view addSubview:label];
        self.window.hidden = NO;
        [self.window makeKeyAndVisible];
    });
}

- (void)showWindowDiagnostic {
    dispatch_async(dispatch_get_main_queue(), ^{
        CGRect frame = [UIScreen mainScreen].bounds;

        self.window = [[UIWindow alloc] initWithFrame:frame];
        self.window.windowLevel = UIWindowLevelNormal;
        self.window.backgroundColor = [UIColor blackColor];

        UIViewController *root = [[UIViewController alloc] init];
        root.view.backgroundColor = [UIColor blackColor];
        self.rootViewController = root;
        self.window.rootViewController = root;

        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        WKUserContentController *contentController = [[WKUserContentController alloc] init];
        [contentController addScriptMessageHandler:self name:@"sbwd"];
        configuration.userContentController = contentController;
        configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];

        self.webView = [[WKWebView alloc] initWithFrame:root.view.bounds configuration:configuration];
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.webView.navigationDelegate = self;
        self.webView.opaque = YES;
        self.webView.backgroundColor = [UIColor whiteColor];
        [root.view addSubview:self.webView];

        NSString *supportPath = SBWDSupportPath();
        NSURL *indexURL = [NSURL fileURLWithPath:[supportPath stringByAppendingPathComponent:@"editor/index.html"]];
        NSURL *readAccessURL = [NSURL fileURLWithPath:supportPath isDirectory:YES];

        [root.view layoutIfNeeded];
        self.window.hidden = NO;
        [self.window makeKeyAndVisible];

        [self.webView loadFileURL:indexURL allowingReadAccessToURL:readAccessURL];
    });
}

- (void)diagnosticCloseTapped:(UIButton *)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

- (void)presentForPage:(NSUInteger)page listView:(UIView *)listView {
    self.page = page;
    NSString *supportPath = SBWDSupportPath();
    NSString *indexPath = [supportPath stringByAppendingPathComponent:@"editor/index.html"];

    if (![[NSFileManager defaultManager] fileExistsAtPath:indexPath]) {
        [self showDiagnostic:[NSString stringWithFormat:@"Sunlight Editor\n\nindex.html не найден.\n\n%@", indexPath]];
        return;
    }

    [self showWindowDiagnostic];
}

- (void)dismiss {
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"sbwd"];
    [self.webView stopLoading];
    self.webView.navigationDelegate = nil;
    [self.webView removeFromSuperview];
    self.webView = nil;
    [self.window resignKeyWindow];
    self.window.hidden = YES;
    self.window = nil;
    self.rootViewController = nil;
    [[SBWDManager shared] reloadWidgets];
}

- (NSString *)escapeForJS:(NSString *)text {
    NSString *escaped = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    return escaped;
}

- (void)injectState {
    NSDictionary *doc = [[SBWDManager shared] hydratedDocumentForPage:self.page];
    NSArray *fonts = [[SBWDManager shared] availableFonts];
    NSMutableArray *safeFonts = [NSMutableArray array];
    for (NSDictionary *font in fonts) {
        [safeFonts addObject:@{ @"family": font[@"family"] ?: @"", @"preview": font[@"preview"] ?: @"" }];
    }
    NSError *error = nil;
    NSData *docData = [NSJSONSerialization dataWithJSONObject:doc options:0 error:&error];
    NSData *fontData = [NSJSONSerialization dataWithJSONObject:safeFonts options:0 error:&error];
    NSString *docText = [[NSString alloc] initWithData:docData encoding:NSUTF8StringEncoding] ?: @"{}";
    NSString *fontText = [[NSString alloc] initWithData:fontData encoding:NSUTF8StringEncoding] ?: @"[]";
    NSString *css = [self escapeForJS:[[SBWDManager shared] fontCSS]];
    NSString *js = [NSString stringWithFormat:@"window.SBWDBoot && window.SBWDBoot(%@, %@, '%@', %lu);", docText, fontText, css, (unsigned long)self.page];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self injectState];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self showDiagnostic:[NSString stringWithFormat:@"Sunlight Editor\n\nОшибка загрузки страницы:\n%@\n\n%@", error.localizedDescription ?: @"unknown", webView.URL.absoluteString ?: @""]];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    [self showDiagnostic:[NSString stringWithFormat:@"Sunlight Editor\n\nНе удалось открыть editor/index.html:\n%@\n\n%@", error.localizedDescription ?: @"unknown", webView.URL.absoluteString ?: @""]];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.body isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSDictionary *body = message.body;
    NSString *action = body[@"action"];
    if ([action isEqualToString:@"close"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismiss];
        });
    } else if ([action isEqualToString:@"save"]) {
        id document = body[@"document"];
        if ([document isKindOfClass:[NSDictionary class]]) {
            [[SBWDManager shared] saveDocument:document page:self.page error:nil];
        }
    } else if ([action isEqualToString:@"saveAndClose"]) {
        id document = body[@"document"];
        if ([document isKindOfClass:[NSDictionary class]]) {
            [[SBWDManager shared] saveDocument:document page:self.page error:nil];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismiss];
        });
    } else if ([action isEqualToString:@"pickImage"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentImagePicker];
        });
    } else if ([action isEqualToString:@"listFonts"]) {
        [self injectState];
    }
}

- (void)presentImagePicker {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    UIViewController *root = self.window.rootViewController;
    if (!root) {
        return;
    }
    [root presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!image) {
        return;
    }
    NSData *data = UIImageJPEGRepresentation(image, 0.92);
    NSString *name = [NSString stringWithFormat:@"%@.jpg", [NSUUID UUID].UUIDString];
    NSString *path = [SBWDImagesDir() stringByAppendingPathComponent:name];
    [data writeToFile:path atomically:YES];
    NSString *b64 = [data base64EncodedStringWithOptions:0];
    NSString *js = [NSString stringWithFormat:@"window.SBWDDidPickImage && window.SBWDDidPickImage('images/%@', '%@');", name, b64];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

@end
