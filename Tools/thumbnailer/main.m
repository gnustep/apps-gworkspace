/* main.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWorkspace application
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include <unistd.h>
#include <limits.h>
#include "GNUstep.h"

#define TMBMAX (48.0)
#define RESZLIM 4

static NSString *GWThumbnailsDidChangeNotification = @"GWThumbnailsDidChangeNotification";

@protocol TMBProtocol

- (BOOL)canProvideThumbnailForPath:(NSString *)path;

- (NSData *)makeThumbnailForPath:(NSString *)path;

- (NSString *)fileNameExtension;

- (NSString *)description;

@end

@protocol ThumbnailerProtocol

- (BOOL)registerExternalProvider:(id<TMBProtocol>)provider;

@end

@interface Thumbnailer: NSObject <ThumbnailerProtocol>
{
  NSMutableArray *thumbnailers;
  NSMutableDictionary *extProviders;
  id current;
  NSString *thumbnailDir;
  NSString *dictPath;
  NSMutableDictionary *thumbsDict;
  long thumbref; 
  NSTimer *timer; 
  NSConnection *conn;
  NSFileManager *fm;
}

- (void)loadThumbnailers;

- (BOOL)addThumbnailer:(id)tmb;

- (id)thumbnailerForPath:(NSString *)path;

- (NSString *)nextThumbName;

- (void)checkThumbnails:(id)sender;

- (BOOL)registerThumbnailData:(NSData *)data 
                      forPath:(NSString *)path
                nameExtension:(NSString *)ext;

- (BOOL)removeThumbnailForPath:(NSString *)path;

- (void)makeThumbnail:(NSPasteboard *)pb
	           userData:(NSString *)ud
	              error:(NSString **)err;

- (void)removeThumbnail:(NSPasteboard *)pb
	             userData:(NSString *)ud
	                error:(NSString **)err;

- (void)thumbnailData:(NSPasteboard *)pb
	           userData:(NSString *)ud
	              error:(NSString **)err;

- (NSArray *)bundlesWithExtension:(NSString *)extension 
											inDirectory:(NSString *)dirpath;

- (void)connectionDidDie:(NSNotification *)notification;

@end

@implementation Thumbnailer

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  if (timer && [timer isValid]) {
    [timer invalidate];
  }
  
  RELEASE (thumbnailers);
  RELEASE (extProviders);
  RELEASE (thumbnailDir);
  TEST_RELEASE (dictPath);
  TEST_RELEASE (thumbsDict);
  DESTROY (conn);
	[super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id entry;
    BOOL isdir;
       
    fm = [NSFileManager defaultManager];
    extProviders = [NSMutableDictionary new];
    [self loadThumbnailers];

    entry = [defaults objectForKey: @"thumbref"];
    if (entry) {
      thumbref = [(NSNumber *)entry longValue];
    } else {
      thumbref = 0;
    }
    
    thumbnailDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    thumbnailDir = [thumbnailDir stringByAppendingPathComponent: @"Thumbnails"];
    RETAIN (thumbnailDir);

    if (([fm fileExistsAtPath: thumbnailDir isDirectory: &isdir] && isdir) == NO) {
      if ([fm createDirectoryAtPath: thumbnailDir attributes: nil] == NO) {
        NSLog(@"no thumbnails directory");
        exit(0);
      }
    }
    
    ASSIGN (dictPath, [thumbnailDir stringByAppendingPathComponent: @"thumbnails.plist"]);    
    
    if ([fm fileExistsAtPath: dictPath]) {
      NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
    
      if (dict) {
        thumbsDict = [dict mutableCopy];
      } else {
        thumbsDict = [NSMutableDictionary new];
      }
    } else {
      thumbsDict = [NSMutableDictionary new];
    }  

    [thumbsDict writeToFile: dictPath atomically: YES];

    conn = [[NSConnection alloc] initWithReceivePort: (NSPort *)[NSPort port] 
																			      sendPort: nil];
    [conn setRootObject: self];
    [conn registerName: @"thumbnailer"];
    [conn setDelegate: self];

    [[NSNotificationCenter defaultCenter] addObserver: self
           selector: @selector(connectionDidDie:)
               name: NSConnectionDidDieNotification
             object: conn];    
        
    timer = [NSTimer scheduledTimerWithTimeInterval: 10.0 target: self 
          										      selector: @selector(checkThumbnails:) 
                                                userInfo: nil repeats: YES];                                             
  }

  return self;
}

- (void)loadThumbnailers
{
  NSString *bundlesDir;
	NSMutableArray *bundlesPaths;
	NSArray *bPaths;
  int i;
  
  TEST_RELEASE (thumbnailers);
  thumbnailers = [NSMutableArray new];
  
  bundlesPaths = [NSMutableArray array]; 

  bPaths = [self bundlesWithExtension: @"thumb" 
                          inDirectory: [[NSBundle mainBundle] resourcePath]];
	[bundlesPaths addObjectsFromArray: bPaths];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  [bundlesPaths addObjectsFromArray: [self bundlesWithExtension: @"thumb" 
			                                              inDirectory: bundlesDir]];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  [bundlesPaths addObjectsFromArray: [self bundlesWithExtension: @"thumb" 
			                                              inDirectory: bundlesDir]];

  for (i = 0; i < [bundlesPaths count]; i++) {
		NSString *bpath = [bundlesPaths objectAtIndex: i];
		NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 
		
		if (bundle) {
			Class principalClass = [bundle principalClass];
			
			if (principalClass) {
				if ([principalClass conformsToProtocol: @protocol(TMBProtocol)]) {	
					id<TMBProtocol> tmb = [[principalClass alloc] init];

          [self addThumbnailer: tmb];
          RELEASE ((id)tmb);
				}
			}
  	}
	}
}

- (BOOL)addThumbnailer:(id)tmb
{
	NSString *description = [tmb description];
  BOOL found = NO;
  int i = 0;
  
  if ([tmb conformsToProtocol: @protocol(TMBProtocol)]) {
	  for (i = 0; i < [thumbnailers count]; i++) {
		  id<TMBProtocol> thumb = [thumbnailers objectAtIndex: i];

      if ([[thumb description] isEqual: description]) {
        found = YES;
        break;
      }
	  }

    if (found == NO) {
      [thumbnailers addObject: tmb];
      return YES;
    }
  }
  
  return NO;
}

- (id)thumbnailerForPath:(NSString *)path
{
  int i;

	for (i = 0; i < [thumbnailers count]; i++) {
		id<TMBProtocol> thumb = [thumbnailers objectAtIndex: i];
        
    if ([thumb canProvideThumbnailForPath: path]) {
      return thumb;
    }
	}  

  return nil;
}

- (void)checkThumbnails:(id)sender
{
  if (thumbsDict && [thumbsDict count]) {
    NSArray *paths = RETAIN ([thumbsDict allKeys]);
    NSMutableArray *deleted = [NSMutableArray array];
    int i;

    for (i = 0; i < [paths count]; i++) {
      NSString *path = [paths objectAtIndex: i];
      NSString *tname = [thumbsDict objectForKey: path];

      if ([fm fileExistsAtPath: path] == NO) {
        NSString *tpath = [thumbnailDir stringByAppendingPathComponent: tname];

        if ([fm fileExistsAtPath: tpath]) {
          [fm removeFileAtPath: tpath handler: nil];
        }
        
        [deleted addObject: path];
        [thumbsDict removeObjectForKey: path];
      }
    }

    RELEASE (paths); 
    
    if ([deleted count]) {
      NSMutableDictionary *info = [NSMutableDictionary dictionary];

	    [info setObject: deleted forKey: @"deleted"];	
      [info setObject: [NSArray array] forKey: @"created"];	
      
      [thumbsDict writeToFile: dictPath atomically: YES];
      
	    [[NSDistributedNotificationCenter defaultCenter] 
            postNotificationName: GWThumbnailsDidChangeNotification
	 								        object: nil 
                        userInfo: info];
    }
  }   
}

- (NSString *)nextThumbName
{
  thumbref++;
  if (thumbref >= (LONG_MAX - 1)) {
    thumbref = 0;
  }
  return [NSString stringWithFormat: @"%x", thumbref];
}

- (void)makeThumbnail:(NSPasteboard *)pb
	           userData:(NSString *)ud
	              error:(NSString **)err
{
  if ([[pb types] indexOfObject: NSFilenamesPboardType] == NSNotFound) {
    *err = @"No file name supplied on pasteboard";
    return;
  } else {
	  NSArray *paths;
    NSData *data;
    NSMutableArray *added;
    BOOL isdir;
    int i;
    
    paths = [pb propertyListForType: NSFilenamesPboardType];
    if (paths == nil) {
      *err = @"invalid pasteboard";
      return;
    }

    added = [NSMutableArray array];

    if ([paths count] == 1) {
      NSString *path = [paths objectAtIndex: 0];

      if ([fm fileExistsAtPath: path isDirectory: &isdir]) {
        if (isdir) {
          NSArray *contents = [fm directoryContentsAtPath: path];

          for (i = 0; i < [contents count]; i++) {
            NSString *fname = [contents objectAtIndex: i];
            NSString *fullPath = [path stringByAppendingPathComponent: fname];
            id<TMBProtocol> tmb = [self thumbnailerForPath: fullPath];
            
            if (tmb) {
              data = [tmb makeThumbnailForPath: fullPath];
              
              if (data && [self registerThumbnailData: data 
                                              forPath: fullPath
                                        nameExtension: [tmb fileNameExtension]]) {
                [added addObject: fullPath];
              }
            }
          }
        } else {
          id<TMBProtocol> tmb = [self thumbnailerForPath: path];

          if (tmb) {
            data = [tmb makeThumbnailForPath: path];

            if (data && [self registerThumbnailData: data
                                            forPath: path
                                      nameExtension: [tmb fileNameExtension]]) {
              [added addObject: path];
            }
          }
        }
      }
      
    } else {
      for (i = 0; i < [paths count]; i++) {
        NSString *path = [paths objectAtIndex: i];
        id<TMBProtocol> tmb = [self thumbnailerForPath: path];

        if (tmb) {
          data = [tmb makeThumbnailForPath: path];

          if (data && [self registerThumbnailData: data 
                                          forPath: path
                                    nameExtension: [tmb fileNameExtension]]) {
            [added addObject: path];
          }
        }
      }   
    }

    if ([added count]) {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      NSMutableDictionary *info = [NSMutableDictionary dictionary];

      [defaults setObject: [NSNumber numberWithLong: thumbref] 
                   forKey: @"thumbref"];
      [defaults synchronize];

	    [info setObject: [NSArray array] forKey: @"deleted"];	
      [info setObject: added forKey: @"created"];	

      [thumbsDict writeToFile: dictPath atomically: YES];

	    [[NSDistributedNotificationCenter defaultCenter] 
            postNotificationName: GWThumbnailsDidChangeNotification
	 								        object: nil 
                        userInfo: info];
    }
  }
}

- (void)removeThumbnail:(NSPasteboard *)pb
	             userData:(NSString *)ud
	                error:(NSString **)err
{
  if ([[pb types] indexOfObject: NSFilenamesPboardType] == NSNotFound) {
    *err = @"No file name supplied on pasteboard";
    return;
  } else {
	  NSArray *paths;
    NSMutableArray *deleted;
    BOOL isdir;
    int i;
    
    paths = [pb propertyListForType: NSFilenamesPboardType];
    if (paths == nil) {
      *err = @"invalid pasteboard";
      return;
    }
    
    if ((thumbsDict == nil) || ([thumbsDict count] == 0)) {
      return;
    }
    
    deleted = [NSMutableArray array];
    
    if ([paths count] == 1) {
      NSString *path = [paths objectAtIndex: 0];

      if ([fm fileExistsAtPath: path isDirectory: &isdir]) {
        if (isdir) {
          NSArray *contents = [fm directoryContentsAtPath: path];
          
          for (i = 0; i < [contents count]; i++) {
            NSString *fname = [contents objectAtIndex: i];
            NSString *fullPath = [path stringByAppendingPathComponent: fname];

            if ([self removeThumbnailForPath: fullPath]) {
              [deleted addObject: fullPath];
            }
          }
        } else {
          if ([self removeThumbnailForPath: path]) {
            [deleted addObject: path];
          }
        }
      }
    } else {
      for (i = 0; i < [paths count]; i++) {
        NSString *path = [paths objectAtIndex: i];

        if ([self removeThumbnailForPath: path]) {
          [deleted addObject: path];
        }
      }   
    }
        
    if ([deleted count]) {
      NSMutableDictionary *info = [NSMutableDictionary dictionary];

	    [info setObject: deleted forKey: @"deleted"];	
      [info setObject: [NSArray array] forKey: @"created"];	
      
      [thumbsDict writeToFile: dictPath atomically: YES];
      
	    [[NSDistributedNotificationCenter defaultCenter] 
            postNotificationName: GWThumbnailsDidChangeNotification
	 								        object: nil 
                        userInfo: info];
    }
  }
}

- (void)thumbnailData:(NSPasteboard *)pb
	           userData:(NSString *)ud
	              error:(NSString **)err
{
  if ([[pb types] indexOfObject: NSFilenamesPboardType] == NSNotFound) {
    *err = @"No file name supplied on pasteboard";
    return;
  } else {
	  NSArray *paths;
    NSString *path;
    NSData *data;
    BOOL isdir;
    
    paths = [pb propertyListForType: NSFilenamesPboardType];
    if (paths == nil) {
      *err = @"invalid pasteboard";
      return;
    }

    if ([paths count] > 1) {
      return;
    }
    
    path = [paths objectAtIndex: 0];

    if ([fm fileExistsAtPath: path isDirectory: &isdir]) {
      if (isdir) {
        return;    
      } else {
        id<TMBProtocol> tmb = [self thumbnailerForPath: path];

        if (tmb) {
          data = [tmb makeThumbnailForPath: path];

          if (data) {
            [pb declareTypes: [NSArray arrayWithObject: NSTIFFPboardType] 
                       owner: nil];
            [pb setData: data forType: NSTIFFPboardType];           
          }
        }
      }
    }
  }  
}

- (BOOL)registerThumbnailData:(NSData *)data 
                      forPath:(NSString *)path
                nameExtension:(NSString *)ext
{
  if (data && [data length]) {
    NSString *tname;
    NSString *tpath;

    tname = [self nextThumbName];    
    tname = [tname stringByAppendingPathExtension: ext];
    tpath = [thumbnailDir stringByAppendingPathComponent: tname];
    
    if ([data writeToFile: tpath atomically: YES]) {
      if ([[thumbsDict allKeys] containsObject: path]) {
        NSString *oldtname = [thumbsDict objectForKey: path];
        NSString *oldtpath = [thumbnailDir stringByAppendingPathComponent: oldtname];
        
        if ([fm fileExistsAtPath: oldtpath]) {
          [fm removeFileAtPath: oldtpath handler: nil];
        }
      }
    
      [thumbsDict setObject: tname forKey: path];
      return YES;
    } else {
      return NO;
    }
  }
  
  return NO;
}

- (BOOL)removeThumbnailForPath:(NSString *)path
{
  NSArray *keys = RETAIN ([thumbsDict allKeys]);

  if ([keys containsObject: path]) {
    NSString *tname = [thumbsDict objectForKey: path];
    NSString *tpath = [thumbnailDir stringByAppendingPathComponent: tname];

    if ([fm fileExistsAtPath: tpath]) {
      [fm removeFileAtPath: tpath handler: nil];
    }
    [thumbsDict removeObjectForKey: path];
    RELEASE (keys);
    return YES;
  }

  RELEASE (keys);
  return NO;
}          

- (NSArray *)bundlesWithExtension:(NSString *)extension 
											inDirectory:(NSString *)dirpath
{
  NSMutableArray *bundleList = [NSMutableArray array];
  NSEnumerator *enumerator;
  NSString *dir;
  BOOL isDir;
    
  if ((([fm fileExistsAtPath: dirpath isDirectory: &isDir]) && isDir) == NO) {
    return nil;
  }
	  
  enumerator = [[fm directoryContentsAtPath: dirpath] objectEnumerator];
  while ((dir = [enumerator nextObject])) {
    if ([[dir pathExtension] isEqualToString: extension]) {
			[bundleList addObject: [dirpath stringByAppendingPathComponent: dir]];
		}
  }
  
  return bundleList;
}

- (BOOL)registerExternalProvider:(id<TMBProtocol>)provider
{
  if ([self addThumbnailer: provider]) {
 	  NSConnection *connection = [(NSDistantObject*)provider connectionForProxy];
    [extProviders setObject: provider forKey: connection];
    return YES;
  }

  return NO;  
}

- (BOOL)connection:(NSConnection*)ancestor 
								shouldMakeNewConnection:(NSConnection*)newConn
{
	if (ancestor == conn) {
    [newConn setDelegate: self];

  	[[NSNotificationCenter defaultCenter] addObserver: self 
									selector: @selector(connectionDidDie:)
	    								name: NSConnectionDidDieNotification object: newConn];
    return YES;
  }
		
  return NO;
}

- (void)connectionDidDie:(NSNotification *)notification
{
	id diedconn = [notification object];
	
  [[NSNotificationCenter defaultCenter] removeObserver: self
	                      name: NSConnectionDidDieNotification object: diedconn];

  if (diedconn == conn) {
		NSLog(@"argh - thumbnailer root connection has been destroyed.");
		exit(1);
	} else {
    id provider = [extProviders objectForKey: diedconn];
  
    if (provider) {
      [thumbnailers removeObject: provider];
      [extProviders removeObjectForKey: diedconn];
    }
  }
}

@end

int main(int argc, char** argv, char **env_c)
{
  NSAutoreleasePool *pool;
	Thumbnailer *thumbnailer;

	switch (fork()) {
	  case -1:
	    fprintf(stderr, "Thumbnailer - fork failed - bye.\n");
	    exit(1);

	  case 0:
	    setsid();
	    break;

	  default:
	    exit(0);
	}
  
  pool = [NSAutoreleasePool new];
	thumbnailer = [[Thumbnailer alloc] init];
  RELEASE (pool);
  
  if (thumbnailer != nil) {
    pool = [NSAutoreleasePool new];
    
    [NSApplication sharedApplication];
    NSRegisterServicesProvider(thumbnailer, @"Thumbnailer");
    [[NSRunLoop currentRunLoop] run];
    
  	RELEASE (pool);
  }
  
  exit(0);
}
