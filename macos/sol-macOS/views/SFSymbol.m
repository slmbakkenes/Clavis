#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE (SFSymbolManager, RCTViewManager)
RCT_EXPORT_VIEW_PROPERTY(name, NSString)
RCT_EXPORT_VIEW_PROPERTY(size, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(weight, NSString)
RCT_EXPORT_VIEW_PROPERTY(color, NSString)
@end
