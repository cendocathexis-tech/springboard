#import "SBWDEditorPresenter.h"
#import "SBWDManager.h"
#import <WebKit/WebKit.h>

@interface SBWDEditorPresenter () <WKNavigationDelegate, WKScriptMessageHandler, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) WKWebView *webView;
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

- (void)presentForPage:(NSUInteger)page listView:(UIView *)listView {
    self.page = page;
    CGRect frame = [UIScreen mainScreen].bounds;
    if (!self.window) {
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = nil;
            for (UIScene *candidate in [UIApplication sharedApplication].connectedScenes) {
                if ([candidate isKindOfClass:[UIWindowScene class]] && candidate.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)candidate;
                    break;
                }
            }
            if (scene) {
                self.window = [[UIWindow alloc] initWithWindowScene:scene];
            }
        }
        if (!self.window) {
            self.window = [[UIWindow alloc] initWithFrame:frame];
        }
        self.window.windowLevel = UIWindowLevelStatusBar + 120.0;
        self.window.backgroundColor = [UIColor blackColor];
    }
    self.window.frame = frame;
    self.window.hidden = NO;

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    WKUserContentController *ucc = [[WKUserContentController alloc] init];
    [ucc addScriptMessageHandler:self name:@"sbwd"];
    config.userContentController = ucc;
    [config.preferences setValue:@YES forKey:@"allowFileAccessFromFileURLs"];
    [config setValue:@YES forKey:@"allowUniversalAccessFromFileURLs"];

    [self.webView removeFromSuperview];
    self.webView = [[WKWebView alloc] initWithFrame:self.window.bounds configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.navigationDelegate = self;
    self.webView.opaque = YES;
    [self.window addSubview:self.webView];
    [self.window makeKeyAndVisible];

    NSURL *url = [[SBWDManager shared] editorIndexURL];
    NSURL *access = [NSURL fileURLWithPath:SBWDSupportPath()];
    [self.webView loadFileURL:url allowingReadAccessToURL:access];
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
        self.window.rootViewController = root;
        [root.view addSubview:self.webView];
        self.webView.frame = root.view.bounds;
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
