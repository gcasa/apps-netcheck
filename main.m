#import <AppKit/AppKit.h>

#import "NetCheckController.h"

int main(int argc, const char **argv)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NetCheckController *controller = [[NetCheckController alloc] init];

  (void)argc;
  (void)argv;

  [NSApplication sharedApplication];
  [NSApp setDelegate: controller];
  [NSApp run];

  [controller release];
  [pool release];
  return 0;
}
