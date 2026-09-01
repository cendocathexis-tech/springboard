```objc
#import "SBWDCommon.h"

extern NSString * const SBWDOpenEditorNotification;
extern NSString * const SBWDReloadNotification;
extern NSString * const SBWDRespringNotification;

@interface SBWDManager : NSObject

+ (instancetype)shared;

- (void)ensureDirectories;
- (void)noteRootFolderView:(UIView *)folderView;
- (void)openEditorForCurrentPage;
- (void)handleEditorGesture:(UILongPressGestureRecognizer *)gesture;
- (void)reloadWidgets;

- (NSDictionary *)hydratedDocumentForPage:(NSUInteger)page;
- (NSUInteger)currentPageIndex;
- (UIView *)currentIconListView;
- (NSDictionary *)documentForPage:(NSUInteger)page;
- (BOOL)saveDocument:(NSDictionary *)document
              page:(NSUInteger)page
             error:(NSError **)error;

- (NSArray<NSDictionary *> *)availableFonts;
- (NSString *)fontCSS;

- (NSURL *)editorIndexURL;
- (NSURL *)runtimeIndexURL;

@end
```
