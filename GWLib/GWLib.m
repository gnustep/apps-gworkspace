/* GWLib.m
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
#include "GWLib.h"
#include "GWFunctions.h"
#include "FSWatcher.h"
#include "GWProtocol.h"
#include "GNUstep.h"
#ifndef GNUSTEP 
  #include "OSXCompatibility.h"
#endif

#define CHECKGW \
if (gwapp == nil) \
gwapp = (id <GWProtocol>)[[GWLib class] gworkspaceApplication]; \
if (gwapp == nil) return

#define CHECKGW_RET(x) \
if (gwapp == nil) \
gwapp = (id <GWProtocol>)[[GWLib class] gworkspaceApplication]; \
if (gwapp == nil) return x

#ifndef CACHED_MAX
  #define CACHED_MAX 20;
#endif

#ifndef byname
  #define byname 0
  #define bykind 1
  #define bydate 2
  #define bysize 3
  #define byowner 4
#endif

id instance = nil;
static id gwapp = nil;
static NSString *gwName = @"GWorkspace";

@interface GWLib (PrivateMethods)

- (void)setCachedMax:(int)cmax;

- (NSMutableDictionary *)cachedRepresentationForPath:(NSString *)path;

- (void)addCachedRepresentation:(NSDictionary *)contentsDict
                    ofDirectory:(NSString *)path;

- (void)removeCachedRepresentationForPath:(NSString *)path;

- (void)removeOlderCache;

- (void)clearCache;

- (NSArray *)sortedDirectoryContentsAtPath:(NSString *)path;

- (BOOL)isLockedPath:(NSString *)path;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (void)watcherTimeOut:(id)sender;

- (void)removeWatcher:(FSWatcher *)awatcher;

- (FSWatcher *)watcherForPath:(NSString *)path;

- (NSTimer *)timerForPath:(NSString *)path;

- (int)sortTypeForDirectoryAtPath:(NSString *)aPath;

- (void)setDefSortType:(int)type;

@end

@implementation GWLib (PrivateMethods)

- (void)setCachedMax:(int)cmax
{
  cachedMax = cmax;
}

- (NSMutableDictionary *)cachedRepresentationForPath:(NSString *)path
{
  NSMutableDictionary *contents = [cachedContents objectForKey: path];

  if (contents) {
    NSDate *modDate = [contents objectForKey: @"moddate"];
    NSDictionary *attributes = [fm fileAttributesAtPath: path 
                                           traverseLink: YES];  
    NSDate *date = [attributes fileModificationDate];

    if ([modDate isEqualToDate: date]) {
      return contents;
    } else {
      [cachedContents removeObjectForKey: path];
    }
  }
   
  return nil;
}

- (void)addCachedRepresentation:(NSDictionary *)contentsDict
                    ofDirectory:(NSString *)path
{
  [cachedContents setObject: contentsDict forKey: path];
  
  if ([watchedPaths containsObject: path] == NO) {
    [watchedPaths addObject: path];
    [self addWatcherForPath: path];
  }
}

- (void)removeCachedRepresentationForPath:(NSString *)path
{
  [cachedContents removeObjectForKey: path];
  
  if ([watchedPaths containsObject: path]) {
    [watchedPaths removeObject: path];
    [self removeWatcherForPath: path];
  }
}

- (void)removeOlderCache
{
  NSArray *keys = [cachedContents allKeys];
  NSDate *date = [NSDate date];
  NSString *removeKey = nil;
  int i;
  
  if ([keys count]) {
    for (i = 0; i < [keys count]; i++) {
      NSString *key = [keys objectAtIndex: i];
      NSDate *stamp = [[cachedContents objectForKey: key] objectForKey: @"datestamp"];
      NSDate *d = [date earlierDate: stamp];
      
      if ([date isEqualToDate: d] == NO) {
        date = d;
        removeKey = key;
      }
    }
    
    if (removeKey == nil) {
      removeKey = [keys objectAtIndex: 0];
    }

    [cachedContents removeObjectForKey: removeKey];

    if ([watchedPaths containsObject: removeKey]) {
      [watchedPaths removeObject: removeKey];
      [self removeWatcherForPath: removeKey];
    }
  }
}

- (void)clearCache
{
  NSArray *keys = [cachedContents allKeys];
  int i;
  
  for (i = 0; i < [keys count]; i++) {
    [self removeWatcherForPath: [keys objectAtIndex: i]];
  }

  DESTROY (cachedContents);
  cachedContents = [NSMutableDictionary new];
}

- (NSArray *)sortedDirectoryContentsAtPath:(NSString *)path
{
  NSMutableDictionary *contentsDict = [self cachedRepresentationForPath: path];
  
  if (contentsDict) {
    return [contentsDict objectForKey: @"files"];
    
  } else {
    NSArray *files = [fm directoryContentsAtPath: path];
    int stype = [self sortTypeForDirectoryAtPath: path]; 
    int count = [files count];
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity: count];
    NSMutableArray *sortfiles = [NSMutableArray arrayWithCapacity: count];
    NSArray *sortPaths = nil;
    NSDictionary *attributes = nil;
    NSDate *date = nil;
    SEL appendPathCompSel = @selector(stringByAppendingPathComponent:);
    IMP appendPathComp = [[NSString class] instanceMethodForSelector: appendPathCompSel];
    SEL lastPathCompSel = @selector(lastPathComponent);
    IMP lastPathComp = [[NSString class] instanceMethodForSelector: lastPathCompSel];  
    int i;

    for (i = 0; i < count; i++) {
      NSString *s = (*appendPathComp)(path, appendPathCompSel, [files objectAtIndex: i]);
      [paths addObject: s];
    }

    sortPaths = [paths sortedArrayUsingFunction: (int (*)(id, id, void*))comparePaths
                                        context: (void *)stype];

    for (i = 0; i < count; i++) {
      NSString *s = (*lastPathComp)([sortPaths objectAtIndex: i], lastPathCompSel);
      [sortfiles addObject: s];
    }

    contentsDict = [NSMutableDictionary dictionary];
    [contentsDict setObject: [NSDate date] forKey: @"datestamp"];
    attributes = [fm fileAttributesAtPath: path traverseLink: YES];
    date = [attributes fileModificationDate];
    [contentsDict setObject: date forKey: @"moddate"];
    [contentsDict setObject: sortfiles forKey: @"files"];
    
    if ([cachedContents count] >= cachedMax) {
      [self removeOlderCache];
    }
    
    [self addCachedRepresentation: contentsDict ofDirectory: path];
   
    return sortfiles;
  }
  
  return nil;
}

- (BOOL)isLockedPath:(NSString *)path
{
	int i;  
  
	if ([lockedPaths containsObject: path]) {
		return YES;
	}
	
	for (i = 0; i < [lockedPaths count]; i++) {
		NSString *lpath = [lockedPaths objectAtIndex: i];
	
    if (subPathOfPath(lpath, path)) {
			return YES;
		}
	}
	
	return NO;
}

- (void)addWatcherForPath:(NSString *)path
{
  FSWatcher *watcher = [self watcherForPath: path];
	  
  if ((watcher != nil) && ([watcher isOld] == NO)) { 
    [watcher addListener];   
    return;
  } else {
    BOOL isdir;
    
    if ([fm fileExistsAtPath: path isDirectory: &isdir] && isdir) {
		  NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 
												  target: self selector: @selector(watcherTimeOut:) 
																								  userInfo: path repeats: YES];
		  [watchTimers addObject: timer];
																								
  	  watcher = [[FSWatcher alloc] initForWatchAtPath: path];      
  	  [watchers addObject: watcher];
  	  RELEASE (watcher);  
    }
	}
}

- (void)removeWatcherForPath:(NSString *)path
{
  FSWatcher *watcher = [self watcherForPath: path];
	
  if ((watcher != nil) && ([watcher isOld] == NO)) {
  	[watcher removeListener];   
  }
}

- (void)watcherTimeOut:(id)sender
{
	NSString *watchedPath = (NSString *)[sender userInfo];
	
	if (watchedPath != nil) {
		FSWatcher *watcher = [self watcherForPath: watchedPath];
	
		if (watcher != nil) {
			if ([watcher isOld]) {
				[self removeWatcher: watcher];
			} else {
				[watcher watchFile];
			}
		}
	}
}

- (void)removeWatcher:(FSWatcher *)awatcher
{
	NSString *watchedPath = [awatcher watchedPath];
	NSTimer *timer = [self timerForPath: watchedPath];

	if (timer && [timer isValid]) {
		[timer invalidate];
		[watchTimers removeObject: timer];
	}
	
	[watchers removeObject: awatcher];
}

- (FSWatcher *)watcherForPath:(NSString *)path
{
  int i;

  for (i = 0; i < [watchers count]; i++) {
    FSWatcher *watcher = [watchers objectAtIndex: i];    
    if ([watcher isWathcingPath: path]) { 
      return watcher;
    }
  }
  
  return nil;
}

- (NSTimer *)timerForPath:(NSString *)path
{
	int i;

  for (i = 0; i < [watchTimers count]; i++) {
		NSTimer *t = [watchTimers objectAtIndex: i];    
	
		if (([t isValid]) && ([(NSString *)[t userInfo] isEqual: path])) {
			return t;
		}
	}
	
	return nil;
}

- (int)sortTypeForDirectoryAtPath:(NSString *)aPath
{
  if ([fm isWritableFileAtPath: aPath]) {
    NSString *dictPath = [aPath stringByAppendingPathComponent: @".gwsort"];
    
    if ([fm fileExistsAtPath: dictPath]) {
      NSDictionary *sortDict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
       
      if (sortDict) {
        return [[sortDict objectForKey: @"sort"] intValue];
      }   
    }
  } 
  
	return defSortType;
}

- (void)setDefSortType:(int)type
{
  defSortType = type;
}

@end


@implementation GWLib

+ (GWLib *)instance
{
	if (instance == nil) {
		instance = [[GWLib alloc] init];
	}	
  return instance;
}

- (void)dealloc
{
  [nc removeObserver: self];

  RELEASE (cachedContents);
	RELEASE (watchers);
	RELEASE (watchTimers);
  RELEASE (watchedPaths);
	RELEASE (lockedPaths);
  RELEASE (tumbsCache);
  RELEASE (thumbnailDir);

	[super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    cachedContents = [NSMutableDictionary new];
    cachedMax = CACHED_MAX;
    defSortType = byname;
    
    watchers = [NSMutableArray new];	
	  watchTimers = [NSMutableArray new];	
    watchedPaths = [NSMutableArray new];

	  lockedPaths = [NSMutableArray new];	

    tumbsCache = [NSMutableDictionary new];
    thumbnailDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    thumbnailDir = [thumbnailDir stringByAppendingPathComponent: @"Thumbnails"];
    RETAIN (thumbnailDir);
    usesThumbnails = NO;
    
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
  }
  
  return self;
}

+ (void)setCachedMax:(int)cmax
{
  [[self instance] setCachedMax: cmax];
}

+ (void)setDefSortType:(int)type
{
  [[self instance] setDefSortType: type];
}

+ (BOOL)isLockedPath:(NSString *)path
{
  return [[self instance] isLockedPath: path];
}


+ (id)gworkspaceApplication
{
	if (gwapp == nil) {
    NSString *host;
    NSString *port;
    NSDate *when = nil;
    BOOL done = NO;

    while (done == NO) {
      host = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSHost"];
      
      if (host == nil) {
	      host = @"";        
	    } else {
	      NSHost *h = [NSHost hostWithName: host];
        
	      if ([h isEqual: [NSHost currentHost]]) {
	        host = @"";
	      }
	    }
      
      port = gwName;

      NS_DURING
        {
	    gwapp = (id <GWProtocol>)[NSConnection rootProxyForConnectionWithRegisteredName: port host: host];
	    RETAIN (gwapp);  
        }
      NS_HANDLER
	      {
	    gwapp = nil;
	      }
      NS_ENDHANDLER
      
      if (gwapp) {
        done = YES;
      }
            
      if (gwapp == nil) {
	      [[NSWorkspace sharedWorkspace] launchApplication: gwName];
        
	      if (when == nil) {
		      when = [[NSDate alloc] init];
		      done = NO;
		    } else if ([when timeIntervalSinceNow] > 5.0) {
		      int result;

		      DESTROY (when);
		      result = NSRunAlertPanel(gwName,
		                @"Application seems to have hung",
		                      @"Continue", @"Terminate", @"Wait");

		      if (result == NSAlertDefaultReturn) {
		        done = YES;
		      } else if (result == NSAlertOtherReturn) {
		        done = NO;
		      } else {
		        done = YES;
		      }
		    }

	      if (done == NO) {
		      NSDate *limit = [[NSDate alloc] initWithTimeIntervalSinceNow: 0.5];
		      [[NSRunLoop currentRunLoop] runUntilDate: limit];
		      RELEASE(limit);
		    }
	    }
    }
  
    TEST_RELEASE (when);
 	}	
  
  return gwapp;
}

+ (BOOL)selectFile:(NSString *)fullPath
							inFileViewerRootedAtPath:(NSString *)rootFullpath
{
  CHECKGW_RET(NO);
  return [gwapp selectFile: fullPath inFileViewerRootedAtPath: rootFullpath];
  return NO;
}

+ (oneway void)rootViewerSelectFiles:(NSArray *)paths
{
  CHECKGW;
  [gwapp rootViewerSelectFiles: paths];
}

+ (oneway void)openSelectedPaths:(NSArray *)paths
{
  CHECKGW;
  [gwapp openSelectedPaths: paths];
}

+ (oneway void)addWatcherForPath:(NSString *)path
{
  CHECKGW;
  [gwapp addWatcherForPath: path];
}

+ (oneway void)removeWatcherForPath:(NSString *)path
{
  CHECKGW;
  [gwapp removeWatcherForPath: path];
}

+ (BOOL)isPakageAtPath:(NSString *)path
{
  CHECKGW_RET(NO);
  return [gwapp isPakageAtPath: path];
  return NO;
}

+ (oneway void)performFileOperationWithDictionary:(NSDictionary *)dict
{
  CHECKGW;
  [gwapp performFileOperationWithDictionary: dict];
}

+ (oneway void)performServiceWithName:(NSString *)sname 
                           pasteboard:(NSPasteboard *)pboard
{
  NSPerformService(sname, pboard);
}

+ (NSString *)trashPath
{
  CHECKGW_RET(nil);
  return [gwapp trashPath];
  return nil;
}

@end
