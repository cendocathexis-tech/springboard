#import "SBWDRootListController.h"
#import <UIKit/UIKit.h>
#import <spawn.h>
#import <unistd.h>

static NSString *SBWDPrefsDir(void) {
    return @"/var/mobile/Library/Preferences/com.sunlight.designer";
}

static void SBWDPost(NSString *name) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)name, NULL, NULL, true);
}

static void SBWDRespring(void) {
    pid_t pid;
    const char *killall = NULL;
    if (access("/var/jb/usr/bin/sbreload", X_OK) == 0) {
        posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *[]){ "sbreload", NULL }, NULL);
        return;
    }
    if (access("/var/jb/usr/bin/killall", X_OK) == 0) {
        killall = "/var/jb/usr/bin/killall";
    } else if (access("/usr/bin/killall", X_OK) == 0) {
        killall = "/usr/bin/killall";
    }
    if (killall) {
        posix_spawn(&pid, killall, NULL, NULL, (char *[]){ "killall", "SpringBoard", NULL }, NULL);
    }
}

@implementation SBWDRootListController

- (NSArray *)specifiers {
    if (_specifiers) {
        return _specifiers;
    }

    NSMutableArray *specs = [NSMutableArray array];

    PSSpecifier *enableGroup = [PSSpecifier preferenceSpecifierNamed:@"Твик" target:self set:NULL get:NULL detail:Nil cell:PSGroupCell edit:Nil];
    [enableGroup setProperty:@"Виджеты рисуются в SBIconListView под иконками. Пустые ячейки сетки работают как холст." forKey:@"footerText"];
    [specs addObject:enableGroup];

    PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"Включено" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:Nil cell:PSSwitchCell edit:Nil];
    [enabled setProperty:@"enabled" forKey:@"key"];
    [enabled setProperty:@"com.sunlight.designer" forKey:@"defaults"];
    [enabled setProperty:@YES forKey:@"default"];
    [enabled setProperty:@"com.sunlight.designer/reload" forKey:@"PostNotification"];
    [specs addObject:enabled];

    PSSpecifier *actionGroup = [PSSpecifier preferenceSpecifierNamed:@"Действия" target:self set:NULL get:NULL detail:Nil cell:PSGroupCell edit:Nil];
    [actionGroup setProperty:@"Редактор открывается поверх SpringBoard. Двумя пальцами удерживайте домашний экран или войдите в режим покачивания икон и нажмите Edit Widgets." forKey:@"footerText"];
    [specs addObject:actionGroup];

    PSSpecifier *openEditor = [PSSpecifier preferenceSpecifierNamed:@"Открыть редактор" target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
    openEditor.buttonAction = @selector(openEditor);
    [specs addObject:openEditor];

    PSSpecifier *respring = [PSSpecifier preferenceSpecifierNamed:@"Respring" target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
    respring.buttonAction = @selector(respring);
    [specs addObject:respring];

    PSSpecifier *ioGroup = [PSSpecifier preferenceSpecifierNamed:@"Пресеты" target:self set:NULL get:NULL detail:Nil cell:PSGroupCell edit:Nil];
    [ioGroup setProperty:[NSString stringWithFormat:@"JSON страниц: %@/page_N.json\nШрифты: %@/Fonts", SBWDPrefsDir(), SBWDPrefsDir()] forKey:@"footerText"];
    [specs addObject:ioGroup];

    PSSpecifier *exportBtn = [PSSpecifier preferenceSpecifierNamed:@"Экспорт текущих страниц" target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
    exportBtn.buttonAction = @selector(exportPresets);
    [specs addObject:exportBtn];

    PSSpecifier *importBtn = [PSSpecifier preferenceSpecifierNamed:@"Импорт JSON" target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
    importBtn.buttonAction = @selector(importPreset);
    [specs addObject:importBtn];

    PSSpecifier *pagesGroup = [PSSpecifier preferenceSpecifierNamed:@"Страницы с виджетами" target:self set:NULL get:NULL detail:Nil cell:PSGroupCell edit:Nil];
    [specs addObject:pagesGroup];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [[fm contentsOfDirectoryAtPath:SBWDPrefsDir() error:nil] sortedArrayUsingSelector:@selector(compare:)];
    BOOL any = NO;
    for (NSString *file in files) {
        if (![file hasPrefix:@"page_"] || ![file.pathExtension isEqualToString:@"json"]) {
            continue;
        }
        any = YES;
        NSString *label = file;
        NSData *data = [NSData dataWithContentsOfFile:[SBWDPrefsDir() stringByAppendingPathComponent:file]];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSUInteger count = 0;
        if ([json isKindOfClass:[NSDictionary class]] && [json[@"elements"] isKindOfClass:[NSArray class]]) {
            count = [json[@"elements"] count];
        }
        label = [NSString stringWithFormat:@"%@  (%lu элементов)", file, (unsigned long)count];
        PSSpecifier *row = [PSSpecifier preferenceSpecifierNamed:label target:self set:NULL get:NULL detail:Nil cell:PSStaticTextCell edit:Nil];
        [specs addObject:row];
    }
    if (!any) {
        PSSpecifier *empty = [PSSpecifier preferenceSpecifierNamed:@"Пока нет сохранённых страниц" target:self set:NULL get:NULL detail:Nil cell:PSStaticTextCell edit:Nil];
        [specs addObject:empty];
    }

    _specifiers = specs;
    return _specifiers;
}

- (void)openEditor {
    SBWDPost(@"com.sunlight.designer/openEditor");
}

- (void)respring {
    SBWDRespring();
}

- (void)exportPresets {
    NSString *destDir = @"/var/mobile/Documents/SBWidgetDesignerExport";
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray *files = [fm contentsOfDirectoryAtPath:SBWDPrefsDir() error:nil];
    NSUInteger copied = 0;
    for (NSString *file in files) {
        if (![file.pathExtension isEqualToString:@"json"]) {
            continue;
        }
        NSString *from = [SBWDPrefsDir() stringByAppendingPathComponent:file];
        NSString *to = [destDir stringByAppendingPathComponent:file];
        [fm removeItemAtPath:to error:nil];
        if ([fm copyItemAtPath:from toPath:to error:nil]) {
            copied += 1;
        }
    }
    NSString *message = [NSString stringWithFormat:@"Скопировано файлов: %lu\n%@", (unsigned long)copied, destDir];
    [self showAlert:@"Экспорт" message:message];
}

- (void)importPreset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Импорт JSON" message:@"Полный путь к page_N.json" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"/var/mobile/Documents/page_0.json";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Импорт" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *path = alert.textFields.firstObject.text;
        if (path.length == 0) {
            return;
        }
        NSData *data = [NSData dataWithContentsOfFile:path];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![json isKindOfClass:[NSDictionary class]]) {
            [self showAlert:@"Ошибка" message:@"Файл не прочитан или это не JSON-объект."];
            return;
        }
        NSNumber *page = json[@"page"] ?: @0;
        NSString *dest = [SBWDPrefsDir() stringByAppendingFormat:@"/page_%@.json", page];
        [data writeToFile:dest atomically:YES];
        SBWDPost(@"com.sunlight.designer/reload");
        [self reloadSpecifiers];
        [self showAlert:@"Готово" message:[NSString stringWithFormat:@"Записано в %@", dest]];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
