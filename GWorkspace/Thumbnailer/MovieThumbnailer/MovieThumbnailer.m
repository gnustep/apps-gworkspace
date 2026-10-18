/* Movie thumbnails provided by an optional external ffmpegthumbnailer tool.
 * Copyright (C) 2026 Free Software Foundation, Inc.
 *
 * This file is part of GWorkspace and is distributed under the GNU General
 * Public License, version 2 or (at your option) any later version, without
 * any warranty. See COPYING for details.
 */

#import <AppKit/AppKit.h>
#import "MovieThumbnailer.h"
#include <signal.h>
#include <stdlib.h>
#include <string.h>

@implementation MovieThumbnailer

- (NSString *)thumbnailerPath
{
  return [NSTask launchPathForTool: @"ffmpegthumbnailer"];
}

- (BOOL)canProvideThumbnailForPath:(NSString *)path
{
  NSArray *extensions = [NSArray arrayWithObjects:
    @"mp4", @"m4v", @"mov", @"mkv", @"webm", @"avi", @"mpg", @"mpeg",
    @"mpe", @"m2v", @"mts", @"m2ts", @"ts", @"vob", @"ogv", @"wmv",
    @"asf", @"flv", @"f4v", @"3gp", @"3g2", nil];
  BOOL isDirectory;

  return ([extensions containsObject: [[path pathExtension] lowercaseString]]
    && [[NSFileManager defaultManager] fileExistsAtPath: path
                                          isDirectory: &isDirectory]
    && !isDirectory && [self thumbnailerPath] != nil);
}

- (NSData *)makeThumbnailForPath:(NSString *)path
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSString *helper = [self thumbnailerPath];

  /* Preserve cleanup state when NS_DURING uses setjmp/longjmp. */
  NSString *volatile directory = nil;
  NSTask *volatile task = nil;
  NSData *volatile result = nil;
  char *volatile temporaryPath = NULL;

  NS_DURING
    {
      if (helper != nil)
        {
          temporaryPath = strdup([[NSTemporaryDirectory()
            stringByAppendingPathComponent: @"GWorkspaceMovie-XXXXXX"]
            fileSystemRepresentation]);
          if (temporaryPath != NULL && mkdtemp(temporaryPath) != NULL)
            {
              NSString *output;
              NSDate *deadline;
              BOOL timedOut;

              directory = [[NSFileManager defaultManager]
                stringWithFileSystemRepresentation: temporaryPath
                                            length: strlen(temporaryPath)];
              output = [directory stringByAppendingPathComponent: @"thumbnail.png"];
              if (![path isAbsolutePath])
                path = [[[NSFileManager defaultManager] currentDirectoryPath]
                  stringByAppendingPathComponent: path];

              task = [NSTask new];
              [task setLaunchPath: helper];
              /* Pass arguments directly: movie names must never reach a shell. */
              [task setArguments: [NSArray arrayWithObjects:
                @"-i", path, @"-o", output, @"-s",
                [NSString stringWithFormat: @"%d", (int)TMBMAX],
                @"-c", @"png", @"-m", nil]];
              [task setStandardInput: [NSFileHandle fileHandleWithNullDevice]];
              [task setStandardOutput: [NSFileHandle fileHandleWithNullDevice]];
              [task setStandardError: [NSFileHandle fileHandleWithNullDevice]];
              [task launch];

              deadline = [NSDate dateWithTimeIntervalSinceNow: 15.0];
              while ([task isRunning] && [deadline timeIntervalSinceNow] > 0)
                [NSThread sleepForTimeInterval: 0.05];
              timedOut = [task isRunning];
              if (timedOut)
                {
                  /* Bound even a decoder which does not respond to SIGTERM. */
                  kill([task processIdentifier], SIGKILL);
                }
              [task waitUntilExit];

              if (!timedOut && [task terminationStatus] == 0)
                {
                  NSData *data = [NSData dataWithContentsOfFile: output];
                  NSBitmapImageRep *image = data != nil
                    ? [NSBitmapImageRep imageRepWithData: data] : nil;
                  if (image != nil && [image pixelsWide] > 0
                    && [image pixelsHigh] > 0
                    && [image pixelsWide] <= (int)TMBMAX
                    && [image pixelsHigh] <= (int)TMBMAX)
                    result = RETAIN(data);
                }
            }
        }
    }
  NS_HANDLER
    {
      /* Missing tools, unreadable movies and invalid output are optional failures. */
      if (task != nil && [task isRunning])
        {
          kill([task processIdentifier], SIGKILL);
          [task waitUntilExit];
        }
    }
  NS_ENDHANDLER;

  RELEASE(task);
  if (directory != nil)
    [[NSFileManager defaultManager] removeFileAtPath: directory handler: nil];
  free(temporaryPath);
  [pool drain];
  return AUTORELEASE(result);
}

- (NSString *)fileNameExtension
{
  return @"png";
}

- (NSString *)description
{
  return @"Movies Thumbnailer";
}

@end
