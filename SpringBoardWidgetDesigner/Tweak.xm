#import "SBWDManager.h"
#import "SBWDEditorPresenter.h"
#import <objc/runtime.h>

@interface SBFolderView : UIView
@property (nonatomic, readonly) NSUInteger currentPageIndex;
- (NSArray *)iconListViews;
@end

@interface SBRootFolderView : SBFolderView
@end

@interface SBIconController : NSObject
- (void)setEditing:(BOOL)editing;
@end

@interface SBIconView : UIView
- (void)_handleAddWidgetRequest:(id)request;
@end

static UIButton *_editorPill;
static char kSBWDGestureKey;
static UIView *_addWidgetDiagnostic;

static void SBWDLayoutEditorPill(void) {
    if (!_editorPill || !_editorPill.superview) {
        return;
    }
    CGFloat width = 168.0;
    CGFloat x = (_editorPill.superview.bounds.size.width - width) / 2.0;
    _editorPill.frame = CGRectMake(x, 54.0, width, 36.0);
}

static void SBWDSetEditingChrome(BOOL editing) {
    if (!editing) {
        [_editorPill removeFromSuperview];
        return;
    }
    UIView *folder = [SBWDManager shared].currentIconListView.superview;
    UIWindow *window = folder.window ?: [SBWDManager shared].currentIconListView.window;
    if (!window) {
        return;
    }
    if (!_editorPill) {
        _editorPill = [UIButton buttonWithType:UIButtonTypeSystem];
        _editorPill.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
        _editorPill.layer.cornerRadius = 18.0;
        _editorPill.clipsToBounds = YES;
        [_editorPill setTitle:@"Edit Widgets" forState:UIControlStateNormal];
        [_editorPill setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _editorPill.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        [_editorPill addTarget:[SBWDManager shared] action:@selector(openEditorForCurrentPage) forControlEvents:UIControlEventTouchUpInside];
    }
    [window addSubview:_editorPill];
    SBWDLayoutEditorPill();
}

static void SBWDShowAddWidgetDiagnostic(UIView *sourceView) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = sourceView.window ?: [SBWDManager shared].currentIconListView.window;
        if (!window) {
            return;
        }

        [_addWidgetDiagnostic removeFromSuperview];

        UIView *box = [[UIView alloc] initWithFrame:CGRectMake(20.0, 90.0, window.bounds.size.width - 40.0, 108.0)];
        box.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.88];
        box.layer.cornerRadius = 16.0;
        box.layer.zPosition = 100000.0;

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectInset(box.bounds, 16.0, 12.0)];
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = UIColor.whiteColor;
        label.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        label.text = @"SUNLIGHT ADD-WIDGET HOOK OK\n_handleAddWidgetRequest: was called.";
        [box addSubview:label];

        UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
        close.frame = CGRectMake(box.bounds.size.width - 70.0, 8.0, 60.0, 32.0);
        [close setTitle:@"Close" forState:UIControlStateNormal];
        [close setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [close addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
            [_addWidgetDiagnostic removeFromSuperview];
            _addWidgetDiagnostic = nil;
        }] forControlEvents:UIControlEventTouchUpInside];
        [box addSubview:close];

        _addWidgetDiagnostic = box;
        [window addSubview:box];
    });
}

static void SBWDWriteLoadMarker(void) {
    NSString *path = @"/var/jb/Library/Application Support/SBWidgetDesigner/sunlight-loaded.txt";
    NSString *contents = [NSString stringWithFormat:@"Sunlight loaded into SpringBoard\n%@\n", [NSDate date]];
    [contents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

%hook SBRootFolderView

- (void)didMoveToWindow {
    %orig;
    [[SBWDManager shared] noteRootFolderView:self];
    if (!objc_getAssociatedObject(self, &kSBWDGestureKey)) {
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:[SBWDManager shared] action:@selector(handleEditorGesture:)];
        gesture.numberOfTouchesRequired = 2;
        gesture.minimumPressDuration = 0.55;
        [self addGestureRecognizer:gesture];
        objc_setAssociatedObject(self, &kSBWDGestureKey, gesture, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)layoutSubviews {
    %orig;
    [[SBWDManager shared] noteRootFolderView:self];
    SBWDLayoutEditorPill();
}

%end

%hook SBIconController

- (void)setEditing:(BOOL)editing {
    %orig;
    SBWDSetEditingChrome(editing);
}

- (void)setEditing:(BOOL)editing fromIconView:(id)iconView {
    %orig;
    SBWDSetEditingChrome(editing);
}

%end

%hook SBIconView

- (void)_handleAddWidgetRequest:(id)request {
    SBWDShowAddWidgetDiagnostic(self);
    %orig;
}

%end

static void SBWDDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSString *n = (__bridge NSString *)name;
    if ([n isEqualToString:SBWDOpenEditorNotification]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[SBWDManager shared] openEditorForCurrentPage];
        });
    } else if ([n isEqualToString:SBWDReloadNotification]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[SBWDManager shared] reloadWidgets];
        });
    }
}

%ctor {
    SBWDWriteLoadMarker();

    CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(darwin, NULL, SBWDDarwinCallback, (__bridge CFStringRef)SBWDOpenEditorNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(darwin, NULL, SBWDDarwinCallback, (__bridge CFStringRef)SBWDReloadNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
