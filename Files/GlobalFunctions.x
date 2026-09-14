#import "Headers.h"
#import <dlfcn.h>

// YouMod's bundle (For localizations)
//
// The bundle used to be looked for in exactly two places: inside the host app (merged
// ipa) and under the jailbreak root. In a container that is neither -- LiveContainer,
// where the dylib is loaded out of a tweak folder and there is no /var/jb -- both miss,
// LOC() then returns nil and every `@{@"title": LOC(...)}` in the settings blows up with
// "attempt to insert nil object from objects[0]". So also look next to the dylib itself,
// which is where a tweak's resources can actually be placed in that setup.
NSBundle *YouModBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSMutableArray<NSString *> *candidates = [NSMutableArray array];

        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"];
        if (tweakBundlePath) [candidates addObject:tweakBundlePath];
        [candidates addObject:[NSString stringWithFormat:jbroot(@"/Library/Application Support/%@.bundle"), @"YouMod"]];

        Dl_info info;
        if (dladdr((const void *)&YouModBundle, &info) && info.dli_fname) {
            NSString *dir = [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
            [candidates addObject:[dir stringByAppendingPathComponent:@"YouMod.bundle"]];
            [candidates addObject:[dir stringByAppendingPathComponent:@"Application Support/YouMod.bundle"]];
        }

        for (NSString *path in candidates) {
            if (![fm fileExistsAtPath:path]) continue;
            bundle = [NSBundle bundleWithPath:path];
            if (bundle) break;
        }
    });
    return bundle;
}

// YouTube icon image (YTIIcon)
UIImage *YouModYTIconImage(NSInteger iconType, BOOL useCustomColor, UIColor *customColor) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    UIColor *targetColor = (useCustomColor && customColor) ? customColor : [UIColor labelColor];
    return [icon iconImageWithColor:targetColor];
}

// Language list
NSArray *getAllSystemLanguageTitles() {
    NSMutableArray *titles = [NSMutableArray array];
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSMutableSet *seenLanguages = [NSMutableSet set];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        
        if (langCode && ![seenLanguages containsObject:langCode]) {
            [seenLanguages addObject:langCode];
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) [titles addObject:displayName];
        }
    }
    return [titles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

NSArray *getAllSystemLanguageValues() {
    NSArray *sortedTitles = getAllSystemLanguageTitles();
    NSMutableArray *sortedCodes = [NSMutableArray array];
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    NSMutableDictionary *titleToCodeMap = [NSMutableDictionary dictionary];
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        if (langCode) {
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) titleToCodeMap[displayName] = langCode;
        }
    }
    
    for (NSString *title in sortedTitles) {
        [sortedCodes addObject:titleToCodeMap[title] ? titleToCodeMap[title] : @"en"];
    }
    return [sortedCodes copy];
}

// Get TopViewController
UIViewController *YouModTopViewController(UIViewController *root) {
    if (!root) {
        UIWindow *keyWindow = nil;
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        root = keyWindow.rootViewController;
    }
    while (root.presentedViewController) root = root.presentedViewController;
    if ([root isKindOfClass:UINavigationController.class])
        return YouModTopViewController(((UINavigationController *)root).topViewController);
    if ([root isKindOfClass:UITabBarController.class])
        return YouModTopViewController(((UITabBarController *)root).selectedViewController);
    return root;
}

// OLEDKeyboard (https://github.com/dayanch96/OledKeyboard)
BOOL isDarkMode(UIView *view) {
    if ([view respondsToSelector:@selector(_mapkit_isDarkModeEnabled)]) {
        return view._mapkit_isDarkModeEnabled;
    }
    return view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

BOOL isPad() {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}