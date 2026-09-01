#import <UIKit/UIKit.h>

@interface SBWDEditorPresenter : NSObject
+ (instancetype)shared;
- (void)presentForPage:(NSUInteger)page listView:(UIView *)listView;
- (void)dismiss;
@end
