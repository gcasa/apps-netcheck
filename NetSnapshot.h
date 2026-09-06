#import <Foundation/Foundation.h>

typedef struct {
  char name[32];
  unsigned long long receiveBytes;
  unsigned long long receivePackets;
  unsigned long long transmitBytes;
  unsigned long long transmitPackets;
} NetCounters;

@interface NetSnapshot : NSObject
{
  NSMutableArray *_counters;
  NSTimeInterval _timestamp;
}
- (NSUInteger)count;
- (NetCounters)countersAtIndex:(NSUInteger)index;
- (NetCounters)countersForName:(const char *)name found:(BOOL *)found;
- (NSString *)nameAtIndex:(NSUInteger)index;
- (NSTimeInterval)timestamp;
@end

BOOL ReadNetSnapshot(NetSnapshot **snapshot);
double NetReceiveRateBetweenCounters(NetCounters previous, NetCounters current, NSTimeInterval interval);
double NetTransmitRateBetweenCounters(NetCounters previous, NetCounters current, NSTimeInterval interval);
NSString *ShortNetworkRate(double bytesPerSecond);
