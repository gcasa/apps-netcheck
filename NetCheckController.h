#import <AppKit/AppKit.h>

@class NetSnapshot;

@interface NetCheckController : NSObject
{
  NSTimer *_timer;
  NetSnapshot *_previousSnapshot;
}
- (void)start;
- (void)refresh:(id)sender;
@end
