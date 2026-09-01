#import "SBWDManager.h"
#import "SBWDWidgetHost.h"
#import "SBWDEditorPresenter.h"

@interface SBFolderView : UIView
@property (nonatomic, readonly) NSUInteger currentPageIndex;
- (NSArray *)iconListViews;
@end

@interface SBWDManager ()
@property (nonatomic, strong) SBWDWidgetHost *host;
@property (nonatomic, weak) UIView *rootFolderView;
@property (nonatomic, assign) NSUInteger lastPage;
@end

@implementation SBWDManager

+ (instancetype)shared {
    static SBWDManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[SBWDManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _host = [[SBWDWidgetHost alloc] init];
        _lastPage = NSNotFound;
        [self ensureDirectories];
    }
    return self;
}

- (void)ensureDirectories {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = @[ SBWDPrefsDir(), SBWDFontsDir(), SBWDImagesDir() ];
    for (NSString *dir in dirs) {
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{
                NSFilePosixPermissions: @0755
            } error:nil];
        }
    }
}

- (void)noteRootFolderView:(UIView *)folderView {
    if (!SBWDTweakEnabled()) {
        [self.host detach];
        return;
    }
    self.rootFolderView = folderView;
    NSUInteger page = [self currentPageIndex];
    UIView *list = [self currentIconListView];
    if (!list) {
        return;
    }
    [self.host attachToListView:list page:page];
    self.lastPage = page;
}

- (NSUInteger)currentPageIndex {
    UIView *view = self.rootFolderView;
    if (!view) {
        return 0;
    }
    if ([view respondsToSelector:@selector(currentPageIndex)]) {
        return ((SBFolderView *)view).currentPageIndex;
    }
    return 0;
}

- (UIView *)currentIconListView {
    UIView *view = self.rootFolderView;
    if (![view respondsToSelector:@selector(iconListViews)]) {
        return nil;
    }
    NSArray *lists = [(SBFolderView *)view iconListViews];
    NSUInteger page = [self currentPageIndex];
    if (page < lists.count) {
        return lists[page];
    }
    return lists.firstObject;
}

- (void)openEditorForCurrentPage {
    UIView *list = [self currentIconListView];
    [[SBWDEditorPresenter shared] presentForPage:[self currentPageIndex] listView:list];
}

- (void)reloadWidgets {
    [self.host reload];
}

- (NSDictionary *)emptyDocumentForPage:(NSUInteger)page {
    return @{
        @"version": @1,
        @"page": @(page),
        @"enabled": @YES,
        @"elements": @[]
    };
}

- (void)handleEditorGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [self openEditorForCurrentPage];
    }
}

- (NSDictionary *)hydratedDocumentForPage:(NSUInteger)page {
    NSDictionary *doc = [self documentForPage:page];
    NSArray *elements = doc[@"elements"];
    if (![elements isKindOfClass:[NSArray class]]) {
        return doc;
    }
    NSMutableDictionary *out = [doc mutableCopy];
    NSMutableArray *hydrated = [NSMutableArray array];
    for (NSDictionary *el in elements) {
        if (![el isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSMutableDictionary *item = [el mutableCopy];
        NSString *src = item[@"src"];
        if ([src isKindOfClass:[NSString class]] && [src hasPrefix:@"images/"]) {
            NSString *path = [SBWDImagesDir() stringByAppendingPathComponent:src.lastPathComponent];
            NSData *data = [NSData dataWithContentsOfFile:path];
            if (data) {
                item[@"dataURL"] = [NSString stringWithFormat:@"data:image/jpeg;base64,%@", [data base64EncodedStringWithOptions:0]];
            }
        }
        [hydrated addObject:item];
    }
    out[@"elements"] = hydrated;
    return out;
}

- (NSDictionary *)documentForPage:(NSUInteger)page {
    NSString *path = SBWDPagePath(page);
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        return [self emptyDocumentForPage:page];
    }
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![json isKindOfClass:[NSDictionary class]]) {
        return [self emptyDocumentForPage:page];
    }
    return json;
}

- (BOOL)saveDocument:(NSDictionary *)document page:(NSUInteger)page error:(NSError **)error {
    [self ensureDirectories];
    NSMutableDictionary *mutable = [document mutableCopy] ?: [NSMutableDictionary dictionary];
    mutable[@"page"] = @(page);
    mutable[@"version"] = mutable[@"version"] ?: @1;
    NSArray *elements = mutable[@"elements"];
    if ([elements isKindOfClass:[NSArray class]]) {
        NSMutableArray *clean = [NSMutableArray array];
        for (NSDictionary *el in elements) {
            if (![el isKindOfClass:[NSDictionary class]]) {
                continue;
            }
            NSMutableDictionary *item = [el mutableCopy];
            [item removeObjectForKey:@"dataURL"];
            [clean addObject:item];
        }
        mutable[@"elements"] = clean;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:mutable options:NSJSONWritingPrettyPrinted error:error];
    if (!data) {
        return NO;
    }
    return [data writeToFile:SBWDPagePath(page) options:NSDataWritingAtomic error:error];
}

- (NSArray<NSDictionary *> *)availableFonts {
    NSMutableArray *fonts = [NSMutableArray array];
    [fonts addObject:@{ @"family": @"System", @"file": @"", @"preview": @"System" }];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *search = @[
        SBWDFontsDir(),
        [SBWDSupportPath() stringByAppendingPathComponent:@"Fonts"]
    ];

    for (NSString *dir in search) {
        NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *file in files) {
            NSString *ext = file.pathExtension.lowercaseString;
            if (![ext isEqualToString:@"ttf"] && ![ext isEqualToString:@"otf"] && ![ext isEqualToString:@"woff"] && ![ext isEqualToString:@"woff2"]) {
                continue;
            }
            NSString *family = [file stringByDeletingPathExtension];
            NSString *full = [dir stringByAppendingPathComponent:file];
            [fonts addObject:@{
                @"family": family,
                @"file": full,
                @"preview": family
            }];
        }
    }
    return fonts;
}

- (NSString *)cssFormatForFontPath:(NSString *)path {
    NSString *ext = path.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"otf"]) return @"opentype";
    if ([ext isEqualToString:@"woff"]) return @"woff";
    if ([ext isEqualToString:@"woff2"]) return @"woff2";
    return @"truetype";
}

- (NSString *)fontCSS {
    NSMutableString *css = [NSMutableString string];
    for (NSDictionary *font in [self availableFonts]) {
        NSString *file = font[@"file"];
        NSString *family = font[@"family"];
        if (file.length == 0) {
            continue;
        }
        NSData *data = [NSData dataWithContentsOfFile:file];
        if (!data) {
            continue;
        }
        NSString *b64 = [data base64EncodedStringWithOptions:0];
        NSString *format = [self cssFormatForFontPath:file];
        [css appendFormat:@"@font-face { font-family: '%@'; src: url('data:font/%@;base64,%@') format('%@'); }\n",
            family, format, b64, format];
    }
    return css;
}

- (NSURL *)editorIndexURL {
    return [NSURL fileURLWithPath:[SBWDSupportPath() stringByAppendingPathComponent:@"editor/index.html"]];
}

- (NSURL *)runtimeIndexURL {
    return [NSURL fileURLWithPath:[SBWDSupportPath() stringByAppendingPathComponent:@"runtime/widget.html"]];
}

@end
