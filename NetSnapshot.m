#import "NetSnapshot.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>

@implementation NetSnapshot

- (id)init
{
  self = [super init];
  if (self != nil) {
    _counters = [[NSMutableArray alloc] init];
    _timestamp = [[NSDate date] timeIntervalSinceReferenceDate];
  }
  return self;
}

- (void)dealloc
{
  [_counters release];
  [super dealloc];
}

- (void)addCounters:(NetCounters)counters
{
  NSValue *value = [NSValue valueWithBytes: &counters objCType: @encode(NetCounters)];
  [_counters addObject: value];
}

- (NSUInteger)count
{
  return [_counters count];
}

- (NetCounters)countersAtIndex:(NSUInteger)index
{
  NetCounters counters;
  memset(&counters, 0, sizeof(NetCounters));

  if (index < [_counters count]) {
    [[_counters objectAtIndex: index] getValue: &counters];
  }
  return counters;
}

- (NetCounters)countersForName:(const char *)name found:(BOOL *)found
{
  NSUInteger index;

  if (found != NULL) {
    *found = NO;
  }

  for (index = 0; index < [_counters count]; index++) {
    NetCounters counters = [self countersAtIndex: index];
    if (strcmp(counters.name, name) == 0) {
      if (found != NULL) {
        *found = YES;
      }
      return counters;
    }
  }

  return [self countersAtIndex: NSNotFound];
}

- (NSString *)nameAtIndex:(NSUInteger)index
{
  NetCounters counters = [self countersAtIndex: index];
  return [NSString stringWithUTF8String: counters.name];
}

- (NSTimeInterval)timestamp
{
  return _timestamp;
}

@end

static char *TrimLeadingWhitespace(char *text)
{
  while (*text != '\0' && isspace((unsigned char)*text)) {
    text++;
  }
  return text;
}

BOOL ReadNetSnapshot(NetSnapshot **snapshot)
{
  FILE *file = fopen("/proc/net/dev", "r");
  char line[512];
  NetSnapshot *result;

  if (file == NULL || snapshot == NULL) {
    if (file != NULL) {
      fclose(file);
    }
    return NO;
  }

  result = [[[NetSnapshot alloc] init] autorelease];

  while (fgets(line, sizeof(line), file) != NULL) {
    char *colon = strchr(line, ':');
    char *nameStart;
    NetCounters counters;
    unsigned long long rxErrs, rxDrop, rxFifo, rxFrame, rxCompressed, rxMulticast;
    unsigned long long txErrs, txDrop, txFifo, txColls, txCarrier, txCompressed;
    int matched;

    if (colon == NULL) {
      continue;
    }

    memset(&counters, 0, sizeof(NetCounters));
    *colon = '\0';
    nameStart = TrimLeadingWhitespace(line);
    strncpy(counters.name, nameStart, sizeof(counters.name) - 1);

    matched = sscanf(colon + 1,
      "%llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu",
      &counters.receiveBytes,
      &counters.receivePackets,
      &rxErrs,
      &rxDrop,
      &rxFifo,
      &rxFrame,
      &rxCompressed,
      &rxMulticast,
      &counters.transmitBytes,
      &counters.transmitPackets,
      &txErrs,
      &txDrop,
      &txFifo,
      &txColls,
      &txCarrier,
      &txCompressed);

    if (matched == 16 && counters.name[0] != '\0') {
      [result addCounters: counters];
    }
  }

  fclose(file);

  if ([result count] == 0) {
    return NO;
  }

  *snapshot = [result retain];
  return YES;
}

static double NetRateBetweenValues(unsigned long long previous,
                                   unsigned long long current,
                                   NSTimeInterval interval)
{
  if (interval <= 0.0 || current < previous) {
    return 0.0;
  }
  return (double)(current - previous) / interval;
}

double NetReceiveRateBetweenCounters(NetCounters previous, NetCounters current, NSTimeInterval interval)
{
  return NetRateBetweenValues(previous.receiveBytes, current.receiveBytes, interval);
}

double NetTransmitRateBetweenCounters(NetCounters previous, NetCounters current, NSTimeInterval interval)
{
  return NetRateBetweenValues(previous.transmitBytes, current.transmitBytes, interval);
}

NSString *ShortNetworkRate(double bytesPerSecond)
{
  if (bytesPerSecond >= 1024.0 * 1024.0 * 1024.0) {
    return [NSString stringWithFormat: @"%.1fG/s", bytesPerSecond / (1024.0 * 1024.0 * 1024.0)];
  }
  if (bytesPerSecond >= 1024.0 * 1024.0) {
    return [NSString stringWithFormat: @"%.1fM/s", bytesPerSecond / (1024.0 * 1024.0)];
  }
  if (bytesPerSecond >= 1024.0) {
    return [NSString stringWithFormat: @"%.0fK/s", bytesPerSecond / 1024.0];
  }
  return [NSString stringWithFormat: @"%.0fB/s", bytesPerSecond];
}
