#import <AppKit/AppKit.h>
#import "GWThumbnailer.h"

@interface Thumbnailer (AutomaticTesting)
- (void)thumbnailRequested:(NSNotification *)notification;
@end

/* Exercise the real startup initializer without changing the cache index. */
@interface StartupThumbnailer : Thumbnailer
- (long)counter;
@end
@implementation StartupThumbnailer
- (void)loadThumbnailers {}
- (void)writeDictToFile {}
- (long)counter { return thumbref; }
@end

@interface FakeProvider : NSObject <TMBProtocol>
{
@public
  NSUInteger calls;
  BOOL fail;
}
@end
@implementation FakeProvider
- (BOOL)canProvideThumbnailForPath:(NSString *)path { return YES; }
- (NSData *)makeThumbnailForPath:(NSString *)path
{
  calls++;
  return fail ? nil : [@"thumbnail" dataUsingEncoding: NSUTF8StringEncoding];
}
- (NSString *)fileNameExtension { return @"test"; }
@end

@interface TestThumbnailer : Thumbnailer
- (id)initWithDirectory:(NSString *)directory provider:(id)provider;
- (void)wait;
@end
@implementation TestThumbnailer
- (id)initWithDirectory:(NSString *)directory provider:(id)provider
{
  /* Isolate the queue and cache from the user's real thumbnail directory. */
  thumbnailers = [[NSMutableArray alloc] initWithObjects: provider, nil];
  thumbnailDir = [directory copy];
  dictPath = [[directory stringByAppendingPathComponent: @"thumbnails.plist"] copy];
  thumbsDict = [NSMutableDictionary new];
  dictLock = [NSLock new];
  pathsInProcessing = [NSMutableArray new];
  automaticAttempts = [NSMutableDictionary new];
  generationQueue = [NSOperationQueue new];
  [generationQueue setMaxConcurrentOperationCount: 1];
  fm = [NSFileManager defaultManager];
  return self;
}
- (void)wait { [generationQueue waitUntilAllOperationsAreFinished]; }
@end

static void request(TestThumbnailer *thumbnailer, NSString *path)
{
  [thumbnailer thumbnailRequested: [NSNotification
    notificationWithName: @"GWThumbnailRequestedNotification" object: path]];
}
static void check(BOOL condition, NSString *message)
{
  if (!condition) { NSLog(@"FAIL: %@", message); exit(1); }
}
int main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *arguments = [[[defaults volatileDomainForName:
    NSArgumentDomain] mutableCopy] autorelease];
  if (arguments == nil) arguments = [NSMutableDictionary dictionary];
  [arguments setObject: @"12345" forKey: @"thumbref"];
  [defaults setVolatileDomain: arguments forName: NSArgumentDomain];
  StartupThumbnailer *startup = [StartupThumbnailer new];
  check([startup counter] == 12345, @"Startup accepts a string thumbnail counter");
  [[NSNotificationCenter defaultCenter] removeObserver: startup];
  NSString *directory = [NSString stringWithUTF8String: argv[1]];
  NSString *path = [directory stringByAppendingPathComponent: @"source.mp4"];
  FakeProvider *provider = [FakeProvider new];
  TestThumbnailer *thumbnailer = [[TestThumbnailer alloc]
    initWithDirectory: directory provider: provider];
  [@"source" writeToFile: path atomically: YES];
  for (NSUInteger i = 0; i < 30; i++) request(thumbnailer, path);
  [thumbnailer wait];
  check(provider->calls == 1, @"Repeated icon requests convert only once");
  NSDictionary *cache = [NSDictionary dictionaryWithContentsOfFile:
    [directory stringByAppendingPathComponent: @"thumbnails.plist"]];
  check([cache objectForKey: path] != nil, @"Generated thumbnail is registered");
  [@"changed source" writeToFile: path atomically: YES];
  request(thumbnailer, path);
  [thumbnailer wait];
  check(provider->calls == 1, @"Existing cached thumbnail is reused");
  path = [directory stringByAppendingPathComponent: @"broken.mp4"];
  [@"broken" writeToFile: path atomically: YES];
  provider->fail = YES;
  request(thumbnailer, path);
  [thumbnailer wait];
  request(thumbnailer, path);
  [thumbnailer wait];
  check(provider->calls == 2, @"Failed conversion is not repeated on redraw");
  [@"changed broken file" writeToFile: path atomically: YES];
  request(thumbnailer, path);
  [thumbnailer wait];
  check(provider->calls == 3, @"Changed failed source is retried");
  NSLog(@"Automatic thumbnail tests passed");
  [pool drain];
  return 0;
}
