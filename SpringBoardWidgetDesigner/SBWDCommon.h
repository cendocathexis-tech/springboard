#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

static inline NSString *SBWDPrefsDir(void) {
    return @"/var/mobile/Library/Preferences/com.yourname.designer";
}

static inline NSString *SBWDFontsDir(void) {
    return [SBWDPrefsDir() stringByAppendingPathComponent:@"Fonts"];
}

static inline NSString *SBWDImagesDir(void) {
    return [SBWDPrefsDir() stringByAppendingPathComponent:@"Images"];
}

static inline NSString *SBWDPagePath(NSUInteger page) {
    return [SBWDPrefsDir() stringByAppendingFormat:@"/page_%lu.json", (unsigned long)page];
}

static inline NSString *SBWDSupportPath(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *rootless = @"/var/jb/Library/Application Support/SBWidgetDesigner";
    if ([fm fileExistsAtPath:rootless]) {
        return rootless;
    }
    return @"/Library/Application Support/SBWidgetDesigner";
}

static inline BOOL SBWDTweakEnabled(void) {
    Boolean exists = false;
    Boolean value = CFPreferencesGetAppBooleanValue(CFSTR("enabled"), CFSTR("com.yourname.designer"), &exists);
    return exists ? (BOOL)value : YES;
}

extern NSString * const SBWDOpenEditorNotification;
extern NSString * const SBWDReloadNotification;
extern NSString * const SBWDRespringNotification;
