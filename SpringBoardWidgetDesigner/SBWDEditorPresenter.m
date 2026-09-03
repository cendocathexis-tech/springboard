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

        // Stage A diagnostic: deliberately avoid UIWindowScene and WKWebView.
        // The goal is to prove that SpringBoard can display and dismiss our own window.
        self.window = [[UIWindow alloc] initWithFrame:frame];
        self.window.windowLevel = UIWindowLevelNormal;
        self.window.backgroundColor = [UIColor blackColor];

        UIViewController *root = [[UIViewController alloc] init];
        root.view.backgroundColor = [UIColor blackColor];
        self.rootViewController = root;
        self.window.rootViewController = root;

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20.0, 120.0, frame.size.width - 40.0, 80.0)];
        title.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        title.text = @"SUNLIGHT WINDOW OK";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont boldSystemFontOfSize:28.0];
        title.textAlignment = NSTextAlignmentCenter;
        [root.view addSubview:title];

        UILabel *detail = [[UILabel alloc] initWithFrame:CGRectMake(30.0, 220.0, frame.size.width - 60.0, 120.0)];
        detail.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        detail.text = @"Stage A\nUIWindow + UIViewController работают.\nWKWebView пока не используется.";
        detail.textColor = [UIColor whiteColor];
        detail.numberOfLines = 0;
        detail.textAlignment = NSTextAlignmentCenter;
        detail.font = [UIFont systemFontOfSize:17.0];
        [root.view addSubview:detail];

        UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
        close.frame = CGRectMake(40.0, frame.size.height - 120.0, frame.size.width - 80.0, 54.0);
        close.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [close setTitle:@"Закрыть" forState:UIControlStateNormal];
        close.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
        [close addTarget:self action:@selector(diagnosticCloseTapped:) forControlEvents:UIControlEventTouchUpInside];
        [root.view addSubview:close];

        // Prepare the complete view hierarchy before exposing the window.
        [root.view layoutIfNeeded];
        self.window.hidden = NO;
        [self.window makeKeyAndVisible];
    });
}

- (void)diagnosticCloseTapped:(UIButton *)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.window resignKeyWindow];
        self.window.hidden = YES;
        self.window = nil;
        self.rootViewController = nil;
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

    // TEMPORARY STAGE A DIAGNOSTIC.
    // Do not involve WKWebView or UIWindowScene until the native window itself is proven stable.
    [self showWindowDiagnostic];
}

- (void)dismiss {
    [self.webView.configuration.userContentController removeScriptMessageHandlerForName:@"sbwd"];
    [self.webView removeFromSuperview];
    self.webView = nil;
    self.window.hidden = YES;
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
        root = [[UIViewController alloc] init];
        root.view.backgroundColor = [UIColor blackColor];
        self.rootViewController = root;
        self.window.rootViewController = root;
        [root.view addSubview:self.webView];
        self.webView.frame = root.view.bounds;
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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
