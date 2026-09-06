#import "NetCheckController.h"

#import "NetSnapshot.h"

#include <math.h>

static NSUInteger NetCheckCeilDivide(NSUInteger value, NSUInteger divisor)
{
  if (divisor == 0) {
    return 0;
  }
  return (value + divisor - 1) / divisor;
}

@implementation NetCheckController

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  (void)notification;
  [self start];
}

- (void)dealloc
{
  [_timer invalidate];
  [_previousSnapshot release];
  [super dealloc];
}

- (void)start
{
  [self refresh: nil];
  _timer = [NSTimer scheduledTimerWithTimeInterval: 2.0
                                            target: self
                                          selector: @selector(refresh:)
                                          userInfo: nil
                                           repeats: YES];
}

- (NSColor *)receiveColor
{
  return [NSColor colorWithCalibratedRed: 0.12 green: 0.52 blue: 0.74 alpha: 1.0];
}

- (NSColor *)transmitColor
{
  return [NSColor colorWithCalibratedRed: 0.82 green: 0.48 blue: 0.14 alpha: 1.0];
}

- (NSDictionary *)attributesWithFont:(NSFont *)font color:(NSColor *)color alignment:(NSTextAlignment)alignment
{
  NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
  [style setAlignment: alignment];
  [style setLineBreakMode: NSLineBreakByClipping];

  return [NSDictionary dictionaryWithObjectsAndKeys:
    font, NSFontAttributeName,
    color, NSForegroundColorAttributeName,
    style, NSParagraphStyleAttributeName,
    nil];
}

- (void)drawInterfaceBarInRect:(NSRect)rect
                          name:(NSString *)name
                       receive:(double)receiveRatio
                      transmit:(double)transmitRatio
                    attributes:(NSDictionary *)attributes
{
  CGFloat radius = rect.size.height >= 4.0 ? 2.0 : 1.0;
  NSRect receiveRect = rect;
  NSRect transmitRect = rect;

  [[NSColor colorWithCalibratedWhite: 0.18 alpha: 1.0] setFill];
  [[NSBezierPath bezierPathWithRoundedRect: rect xRadius: radius yRadius: radius] fill];

  receiveRect.size.height = floor(rect.size.height / 2.0);
  receiveRect.origin.y += rect.size.height - receiveRect.size.height;
  receiveRect.size.width = floor(rect.size.width * receiveRatio);
  if (receiveRect.size.width > 0.0) {
    [[self receiveColor] setFill];
    [[NSBezierPath bezierPathWithRoundedRect: receiveRect xRadius: radius yRadius: radius] fill];
  }

  transmitRect.size.height = rect.size.height - receiveRect.size.height;
  transmitRect.size.width = floor(rect.size.width * transmitRatio);
  if (transmitRect.size.width > 0.0) {
    [[self transmitColor] setFill];
    [[NSBezierPath bezierPathWithRoundedRect: transmitRect xRadius: radius yRadius: radius] fill];
  }

  if (rect.size.height >= 7.0 && rect.size.width >= 24.0) {
    [name drawInRect: NSInsetRect(rect, 3.0, 0.0) withAttributes: attributes];
  }
}

- (NSArray *)ratesForSnapshot:(NetSnapshot *)snapshot
                 totalReceive:(double *)totalReceive
                totalTransmit:(double *)totalTransmit
{
  NSMutableArray *rates = [NSMutableArray array];
  NSTimeInterval interval = _previousSnapshot == nil
    ? 0.0
    : [snapshot timestamp] - [_previousSnapshot timestamp];
  NSUInteger index;

  if (totalReceive != NULL) {
    *totalReceive = 0.0;
  }
  if (totalTransmit != NULL) {
    *totalTransmit = 0.0;
  }

  for (index = 0; index < [snapshot count]; index++) {
    NetCounters counters = [snapshot countersAtIndex: index];
    NetCounters previous;
    BOOL found = NO;
    double receiveRate = 0.0;
    double transmitRate = 0.0;

    if (_previousSnapshot != nil) {
      previous = [_previousSnapshot countersForName: counters.name found: &found];
      if (found) {
        receiveRate = NetReceiveRateBetweenCounters(previous, counters, interval);
        transmitRate = NetTransmitRateBetweenCounters(previous, counters, interval);
      }
    }

    if (totalReceive != NULL) {
      *totalReceive += receiveRate;
    }
    if (totalTransmit != NULL) {
      *totalTransmit += transmitRate;
    }

    [rates addObject: [NSDictionary dictionaryWithObjectsAndKeys:
      [NSString stringWithUTF8String: counters.name], @"name",
      [NSNumber numberWithDouble: receiveRate], @"receive",
      [NSNumber numberWithDouble: transmitRate], @"transmit",
      nil]];
  }

  return rates;
}

- (NSImage *)iconForSnapshot:(NetSnapshot *)snapshot rates:(NSArray *)rates
{
  NSSize size = NSMakeSize(128.0, 128.0);
  NSImage *image = [[[NSImage alloc] initWithSize: size] autorelease];
  NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes: NULL
                  pixelsWide: (NSInteger)size.width
                  pixelsHigh: (NSInteger)size.height
               bitsPerSample: 8
             samplesPerPixel: 4
                    hasAlpha: YES
                    isPlanar: NO
              colorSpaceName: NSDeviceRGBColorSpace
                 bytesPerRow: 0
                bitsPerPixel: 0] autorelease];
  NSGraphicsContext *oldContext = [NSGraphicsContext currentContext];
  NSGraphicsContext *bitmapContext = [NSGraphicsContext graphicsContextWithBitmapImageRep: rep];
  NSUInteger interfaceCount = [snapshot count];
  NSUInteger barCount = interfaceCount > 0 ? interfaceCount : 1;
  CGFloat barsLeft = 12.0;
  CGFloat barsBottom = 8.0;
  CGFloat barsWidth = 104.0;
  CGFloat barsTopEdge = 72.0;
  CGFloat availableHeight = barsTopEdge - barsBottom;
  CGFloat columnGap = 4.0;
  CGFloat minBarWidth = 24.0;
  CGFloat barHeight = 9.0;
  CGFloat barGap = 3.0;
  CGFloat barWidth;
  NSUInteger rowsPerColumn;
  NSUInteger columnCount;
  NSUInteger maxRows;
  NSUInteger maxColumns;
  double maxRate = 1.0;
  NSUInteger index;
  NSDictionary *labelAttributes = [self attributesWithFont: [NSFont boldSystemFontOfSize: 9.0]
                                                     color: [NSColor whiteColor]
                                                 alignment: NSLeftTextAlignment];
  NSDictionary *titleAttributes = [self attributesWithFont: [NSFont boldSystemFontOfSize: 17.0]
                                                     color: [NSColor whiteColor]
                                                 alignment: NSLeftTextAlignment];
  NSDictionary *summaryAttributes = [self attributesWithFont: [NSFont boldSystemFontOfSize: 14.0]
                                                       color: [NSColor whiteColor]
                                                   alignment: NSLeftTextAlignment];

  for (index = 0; index < [rates count]; index++) {
    NSDictionary *rate = [rates objectAtIndex: index];
    double receiveRate = [[rate objectForKey: @"receive"] doubleValue];
    double transmitRate = [[rate objectForKey: @"transmit"] doubleValue];
    if (receiveRate > maxRate) {
      maxRate = receiveRate;
    }
    if (transmitRate > maxRate) {
      maxRate = transmitRate;
    }
  }

  do {
    maxRows = (NSUInteger)floor((availableHeight + barGap) / (barHeight + barGap));
    if (maxRows < 1) {
      maxRows = 1;
    }
    rowsPerColumn = maxRows;
    columnCount = NetCheckCeilDivide(barCount, rowsPerColumn);
    barWidth = (barsWidth - (CGFloat)(columnCount - 1) * columnGap) / (CGFloat)columnCount;

    if (barWidth >= minBarWidth || barHeight <= 4.0) {
      break;
    }

    if (barHeight > 7.0) {
      barHeight = 7.0;
      barGap = 2.0;
    } else if (barHeight > 5.0) {
      barHeight = 5.0;
      barGap = 1.0;
    } else {
      barHeight = 4.0;
    }
  } while (YES);

  if (barWidth < minBarWidth) {
    maxColumns = (NSUInteger)floor((barsWidth + columnGap) / (minBarWidth + columnGap));
    if (maxColumns < 1) {
      maxColumns = 1;
    }
    columnCount = barCount < maxColumns ? barCount : maxColumns;
    rowsPerColumn = NetCheckCeilDivide(barCount, columnCount);
    if (rowsPerColumn > 1
        && (CGFloat)(rowsPerColumn - 1) * barGap < availableHeight) {
      barHeight = floor((availableHeight - (CGFloat)(rowsPerColumn - 1) * barGap)
                        / (CGFloat)rowsPerColumn);
    }
    if (barHeight < 2.0) {
      barHeight = 2.0;
      barGap = 0.0;
    }
    barWidth = (barsWidth - (CGFloat)(columnCount - 1) * columnGap) / (CGFloat)columnCount;
  }

  [NSGraphicsContext setCurrentContext: bitmapContext];
  [[NSColor colorWithCalibratedWhite: 0.08 alpha: 1.0] setFill];
  NSRectFill(NSMakeRect(0.0, 0.0, size.width, size.height));

  [@"NET" drawInRect: NSMakeRect(12.0, 98.0, 104.0, 20.0) withAttributes: titleAttributes];
  [@"RX blue" drawInRect: NSMakeRect(12.0, 78.0, 52.0, 18.0) withAttributes: summaryAttributes];
  [@"TX amber" drawInRect: NSMakeRect(64.0, 78.0, 52.0, 18.0) withAttributes: summaryAttributes];

  for (index = 0; index < barCount; index++) {
    NSDictionary *rate = index < [rates count] ? [rates objectAtIndex: index] : nil;
    double receiveRatio = rate != nil ? [[rate objectForKey: @"receive"] doubleValue] / maxRate : 0.0;
    double transmitRatio = rate != nil ? [[rate objectForKey: @"transmit"] doubleValue] / maxRate : 0.0;
    NSUInteger column = index / rowsPerColumn;
    NSUInteger row = index % rowsPerColumn;
    CGFloat x = barsLeft + (CGFloat)column * (barWidth + columnGap);
    CGFloat y = barsTopEdge - barHeight - (CGFloat)row * (barHeight + barGap);
    NSString *name = rate != nil ? [rate objectForKey: @"name"] : @"?";

    [self drawInterfaceBarInRect: NSMakeRect(x, y, barWidth, barHeight)
                            name: name
                         receive: receiveRatio
                        transmit: transmitRatio
                      attributes: labelAttributes];
  }

  [bitmapContext flushGraphics];
  [NSGraphicsContext setCurrentContext: oldContext];
  [image addRepresentation: rep];

  return image;
}

- (void)refresh:(id)sender
{
  NetSnapshot *snapshot = nil;
  NSArray *rates;

  (void)sender;

  if (!ReadNetSnapshot(&snapshot)) {
    return;
  }

  rates = [self ratesForSnapshot: snapshot totalReceive: NULL totalTransmit: NULL];
  [NSApp setApplicationIconImage: [self iconForSnapshot: snapshot rates: rates]];

  [_previousSnapshot release];
  _previousSnapshot = snapshot;
}

@end
