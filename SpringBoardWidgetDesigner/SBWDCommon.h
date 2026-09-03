#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <rootless.h>

static inline NSString *SBWDPrefsDir(void) {
    return @"/var/mobile/Library/Preferences/com.sunlight.designer";
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
    return ROOT_PATH_NS(@"/Library/Application Support/SBWidgetDesigner");
}

static inline BOOL SBWDTweakEnabled(void) {
    Boolean exists = false;
    Boolean value = CFPreferencesGetAppBooleanValue(CFSTR("enabled"), CFSTR("com.sunlight.designer"), &exists);
    return exists ? (BOOL)value : YES;
}

extern NSString * const SBWDOpenEditorNotification;
extern NSString * const SBWDReloadNotification;
extern NSString * const SBWDRespringNotification;
