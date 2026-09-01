#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SBWDWidgetHost : NSObject

- (void)attachToListView:(UIView *)listView page:(NSUInteger)page;
- (void)reload;
- (void)detach;

@end
