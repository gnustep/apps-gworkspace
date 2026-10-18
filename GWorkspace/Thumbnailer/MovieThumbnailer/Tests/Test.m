#import <AppKit/AppKit.h>
#import "MovieThumbnailer.h"

static BOOL overrideHelper = NO;
static NSString *helperPath = nil;
static int failures = 0;

@interface MovieThumbnailer (Testing)
- (NSString *)thumbnailerPath;
@end

@interface TestThumbnailer: MovieThumbnailer
@end
@implementation TestThumbnailer
- (NSString *)thumbnailerPath
{
  return overrideHelper ? helperPath : [super thumbnailerPath];
}
@end

static void check(BOOL condition, NSString *message)
{
  if (!condition)
    {
      NSLog(@"FAIL: %@", message);
      failures++;
    }
}

static NSSet *temporaryDirectories(void)
{
  NSMutableSet *names = [NSMutableSet set];
  for (NSString *name in [[NSFileManager defaultManager]
                          directoryContentsAtPath: NSTemporaryDirectory()])
    if ([name hasPrefix: @"GWorkspaceMovie-"])
      [names addObject: name];
  return names;
}

static void checkThumbnail(TestThumbnailer *provider, NSString *path,
                           BOOL artwork)
{
  check([provider canProvideThumbnailForPath: path], @"Recognizes movie");
  NSData *data = [provider makeThumbnailForPath: path];
  NSBitmapImageRep *image = data ? [NSBitmapImageRep imageRepWithData: data] : nil;
  check(image != nil, [@"Produces image: " stringByAppendingString: path]);
  if (image)
    {
      check([image pixelsWide] <= 64 && [image pixelsHigh] <= 64,
            @"Thumbnail fits cache dimensions");
      NSColor *color = [[image colorAtX: [image pixelsWide] / 2
                                    y: [image pixelsHigh] / 2]
                         colorUsingColorSpaceName: NSDeviceRGBColorSpace];
      check(artwork ? [color redComponent] > 0.8 && [color greenComponent] < 0.2
                    : [color greenComponent] > 0.3 && [color redComponent] < 0.2,
            artwork ? @"Uses embedded cover rather than video"
                    : @"Falls back to video frame");
      check(artwork ? [image pixelsHigh] > [image pixelsWide]
                    : [image pixelsWide] > [image pixelsHigh],
            @"Preserves aspect ratio");
    }
}

int main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSString *root = [NSString stringWithUTF8String: argv[1]];
  NSString *movie = [root stringByAppendingPathComponent: @"plain.mp4"];
  TestThumbnailer *provider = [TestThumbnailer new];
  NSSet *before = [temporaryDirectories() copy];

  check([[provider fileNameExtension] isEqual: @"png"], @"Cache extension");
  checkThumbnail(provider, movie, NO);
  checkThumbnail(provider, [root stringByAppendingPathComponent:
    @"cover ' $(touch UNEXPECTED) ;.MP4"], YES);
  checkThumbnail(provider, [root stringByAppendingPathComponent: @"cover.mkv"], YES);
  check(![[NSFileManager defaultManager] fileExistsAtPath: @"UNEXPECTED"],
        @"Filename is never interpreted as shell code");
  check(![provider canProvideThumbnailForPath:
    [root stringByAppendingPathComponent: @"directory.mp4"]], @"Rejects directories");
  check(![provider canProvideThumbnailForPath:
    [root stringByAppendingPathComponent: @"cover.jpg"]], @"Leaves still images alone");
  check(![provider canProvideThumbnailForPath: @"/nonexistent/movie.mp4"],
        @"Rejects missing files");
  check([provider makeThumbnailForPath:
    [root stringByAppendingPathComponent: @"broken.mp4"]] == nil,
        @"Corrupt media fails cleanly");

  overrideHelper = YES;
  check(![provider canProvideThumbnailForPath: movie], @"Missing helper disables provider");
  check([provider makeThumbnailForPath: movie] == nil, @"Missing helper returns nil");
  helperPath = @"/nonexistent/ffmpegthumbnailer";
  check([provider makeThumbnailForPath: movie] == nil, @"Launch failure returns nil");
  for (NSString *name in [NSArray arrayWithObjects: @"fail", @"empty", @"invalid", nil])
    {
      helperPath = [root stringByAppendingPathComponent: name];
      check([provider makeThumbnailForPath: movie] == nil,
            [@"Rejects helper output: " stringByAppendingString: name]);
    }
  helperPath = [root stringByAppendingPathComponent: @"hang"];
  NSDate *start = [NSDate date];
  check([provider makeThumbnailForPath: movie] == nil, @"Timeout returns nil");
  NSTimeInterval elapsed = -[start timeIntervalSinceNow];
  check(elapsed >= 14 && elapsed < 20, @"Hung helper has bounded execution");
  check([before isEqual: temporaryDirectories()], @"Temporary files cleaned on all paths");

  [before release];
  [provider release];
  NSLog(@"MovieThumbnailer: %d failures", failures);
  [pool drain];
  return failures ? 1 : 0;
}
