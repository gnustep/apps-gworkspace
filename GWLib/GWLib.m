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
#include <math.h>
#include "GWLib.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "FSWatcher.h"
#include "GWProtocol.h"
#include "GNUstep.h"
#ifndef GNUSTEP 
  #include "OSXCompatibility.h"
#endif

#ifndef CACHED_MAX
  #define CACHED_MAX 20
#endif

#ifndef byname
  #define byname 0
  #define bykind 1
  #define bydate 2
  #define bysize 3
  #define byowner 4
#endif

id instance = nil;

@interface GWLib (PrivateMethods)

+ (GWLib *)instance;

- (NSArray *)sortedDirectoryContentsAtPath:(NSString *)path;

- (NSArray *)checkHiddenFiles:(NSArray *)files atPath:(NSString *)path;

- (NSMutableDictionary *)cachedRepresentationForPath:(NSString *)path;

- (void)addCachedRepresentation:(NSDictionary *)contentsDict
                    ofDirectory:(NSString *)path;

- (void)removeCachedRepresentationForPath:(NSString *)path;

- (void)removeOlderCache;

- (void)clearCache;

- (void)setCachedMax:(int)cmax;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (void)watcherTimeOut:(id)sender;

- (void)removeWatcher:(FSWatcher *)awatcher;

- (FSWatcher *)watcherForPath:(NSString *)path;

- (NSTimer *)timerForPath:(NSString *)path;

- (void)watcherNotification:(NSNotification *)notification;

- (void)lockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path;

- (void)unLockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path;

- (BOOL)isLockedPath:(NSString *)path;

- (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path;

- (NSString *)typeOfFileAt:(NSString *)path;  

- (BOOL)isWritableFileAtPath:(NSString *)path;

- (BOOL)isPakageAtPath:(NSString *)path;

- (int)sortTypeForDirectoryAtPath:(NSString *)path;

- (void)setSortType:(int)type forDirectoryAtPath:(NSString *)path;

- (void)setDefSortType:(int)type;

- (int)defSortType;

- (void)setHideSysFiles:(BOOL)value;

- (BOOL)hideSysFiles;

- (void)setHiddenPaths:(NSArray *)paths;

- (NSArray *)hiddenPaths;

- (void)setHideDotFiles:(NSNotification *)notif;

- (NSImage *)iconForFile:(NSString *)fullPath ofType:(NSString *)type;

- (NSImage *)smallIconForFile:(NSString*)aPath;

- (NSImage *)smallIconForFiles:(NSArray*)pathArray;

- (NSImage *)smallHighlightIcon;

- (NSImage *)thumbnailForPath:(NSString *)path;

- (void)prepareThumbnailsCache;

- (void)thumbnailsDidChange:(NSNotification *)notif;

- (void)setUseThumbnails:(BOOL)value;

- (NSArray *)imageExtensions;

- (id)workspaceApp;

@end

@implementation GWLib (PrivateMethods)

+ (GWLib *)instance
{
	if (instance == nil) {
		instance = [[GWLib alloc] init];
	}	
  return instance;
}

- (void)dealloc
{
  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  [nc removeObserver: self];

  RELEASE (cachedContents);
	RELEASE (watchers);
	RELEASE (watchTimers);
  RELEASE (watchedPaths);
	RELEASE (lockedPaths);
	RELEASE (hiddenPaths);
  RELEASE (tumbsCache);
  RELEASE (thumbnailDir);

	[super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
	  BOOL isdir;
    
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
  
    cachedContents = [NSMutableDictionary new];
    cachedMax = CACHED_MAX;
    defSortType = byname;
    hideSysFiles = NO;
    
    watchers = [NSMutableArray new];	
	  watchTimers = [NSMutableArray new];	
    watchedPaths = [NSMutableArray new];
    hiddenPaths = [NSArray new];
	  lockedPaths = [NSMutableArray new];	
    tumbsCache = [NSMutableDictionary new];
    
    thumbnailDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    thumbnailDir = [thumbnailDir stringByAppendingPathComponent: @"Thumbnails"];
    RETAIN (thumbnailDir);
    if (([fm fileExistsAtPath: thumbnailDir isDirectory: &isdir] && isdir) == NO) {
      [fm createDirectoryAtPath: thumbnailDir attributes: nil];
    }
    usesThumbnails = NO;
    
    [nc addObserver: self 
           selector: @selector(watcherNotification:) 
               name: GWFileWatcherFileDidChangeNotification
             object: nil];

    [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                          selector: @selector(setHideDotFiles:) 
                					    name: GSHideDotFilesDidChangeNotification
                					  object: nil];

    [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(thumbnailsDidChange:) 
                					  name: GWThumbnailsDidChangeNotification
                          object: nil];
                          
    workspaceApp = [self workspaceApp];                        
  }
  
  return self;
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

- (NSArray *)checkHiddenFiles:(NSArray *)files atPath:(NSString *)path
{
  NSArray *checkedFiles;
  NSArray *hiddenFiles;
  NSString *h; 
	int i;
  		
	h = [path stringByAppendingPathComponent: @".hidden"];
  if ([fm fileExistsAtPath: h]) {
	  h = [NSString stringWithContentsOfFile: h];
	  hiddenFiles = [h componentsSeparatedByString: @"\n"];
	} else {
    hiddenFiles = nil;
  }
	
	if (hiddenFiles != nil  ||  hideSysFiles || [hiddenPaths count]) {	
		NSMutableArray *mutableFiles = AUTORELEASE ([files mutableCopy]);
	
		if (hiddenFiles != nil) {
	    [mutableFiles removeObjectsInArray: hiddenFiles];
	  }
	
		if (hideSysFiles) {
      i = [mutableFiles count] - 1;
	    
	    while (i >= 0) {
				NSString *file = [mutableFiles objectAtIndex: i];

				if ([file hasPrefix: @"."]) {
		    	[mutableFiles removeObjectAtIndex: i];
		  	}
				i--;
			}
	  }		
    
    if ([hiddenPaths count]) {
      i = [mutableFiles count] - 1;
    
	    while (i >= 0) {
				NSString *file = [mutableFiles objectAtIndex: i];
        NSString *fullPath = [path stringByAppendingPathComponent: file];

        if ([hiddenPaths containsObject: fullPath]) {
		    	[mutableFiles removeObjectAtIndex: i];
        }
				i--;
			}
    }
    
		checkedFiles = mutableFiles;
    
	} else {
    checkedFiles = files;
  }

  return checkedFiles;
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

- (void)setCachedMax:(int)cmax
{
  cachedMax = cmax;
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

- (void)watcherNotification:(NSNotification *)notification
{
  NSDictionary *notifdict = (NSDictionary *)[notification object];
  NSString *path = [notifdict objectForKey: @"path"];

  if ([self cachedRepresentationForPath: path]) {
    [self removeCachedRepresentationForPath: path];
  }
}

- (void)lockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path
{
	int i;
	  
	for (i = 0; i < [files count]; i++) {
		NSString *file = [files objectAtIndex: i];
		NSString *fpath = [path stringByAppendingPathComponent: file];    
    
		if ([lockedPaths containsObject: fpath] == NO) {
			[lockedPaths addObject: fpath];
		} 
	}
}

- (void)unLockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path
{
	int i;
	  
	for (i = 0; i < [files count]; i++) {
		NSString *file = [files objectAtIndex: i];
		NSString *fpath = [path stringByAppendingPathComponent: file];
	
		if ([lockedPaths containsObject: fpath]) {
			[lockedPaths removeObject: fpath];
		} 
	}
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

- (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path            
{
  BOOL isDir;
  return ([fm fileExistsAtPath: path isDirectory: &isDir] && isDir);
}

- (NSString *)typeOfFileAt:(NSString *)path
{
  NSString *defApp, *type;
  [ws getInfoForFile: path application: &defApp type: &type];
  return type;
}

- (BOOL)isWritableFileAtPath:(NSString *)path
{
  return [fm isWritableFileAtPath: path];
}

- (BOOL)isPakageAtPath:(NSString *)path
{
	NSString *defApp, *type;
	BOOL isdir;
		
	[ws getInfoForFile: path application: &defApp type: &type];  
	
	if (type == NSApplicationFileType) {
		return YES;
	} else if (type == NSPlainFileType) {
	  if ((([fm fileExistsAtPath: path isDirectory: &isdir]) && isdir)) {
		  return YES;
	  }  
  }
	
  return NO;
}

- (int)sortTypeForDirectoryAtPath:(NSString *)path
{
  if ([fm isWritableFileAtPath: path]) {
    NSString *dictPath = [path stringByAppendingPathComponent: @".gwsort"];
    
    if ([fm fileExistsAtPath: dictPath]) {
      NSDictionary *sortDict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
       
      if (sortDict) {
        return [[sortDict objectForKey: @"sort"] intValue];
      }   
    }
  } 
  
	return defSortType;
}

- (void)setSortType:(int)type forDirectoryAtPath:(NSString *)path
{
  if ([fm isWritableFileAtPath: path]) {
    NSString *sortstr = [NSString stringWithFormat: @"%i", type];
    NSDictionary *dict = [NSDictionary dictionaryWithObject: sortstr 
                                                     forKey: @"sort"];
    [dict writeToFile: [path stringByAppendingPathComponent: @".gwsort"] 
           atomically: YES];
  }
  
  [self removeCachedRepresentationForPath: path];
  
	[[NSNotificationCenter defaultCenter]
 				 postNotificationName: GWSortTypeDidChangeNotification
	 								     object: (id)path];  
}

- (void)setDefSortType:(int)type
{
	if (defSortType == type) {
		return;
	} else {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		defSortType = type;
		[defaults setObject: [NSString stringWithFormat: @"%i", defSortType] 
							   forKey: @"defaultsorttype"];
		[defaults synchronize];
	  
    [self clearCache];
      
		[[NSNotificationCenter defaultCenter]
	 				 postNotificationName: GWSortTypeDidChangeNotification
		 								     object: nil]; 
	}
}

- (int)defSortType
{
  return defSortType;
}

- (void)setHideSysFiles:(BOOL)value
{
  if (hideSysFiles != value) {
    [self clearCache];

    hideSysFiles = value;
  }
}

- (BOOL)hideSysFiles
{
  return hideSysFiles;
}

- (void)setHiddenPaths:(NSArray *)paths
{
  ASSIGN (hiddenPaths, paths);
}

- (NSArray *)hiddenPaths
{
  return hiddenPaths;
}

- (void)setHideDotFiles:(NSNotification *)notif
{
  NSString *hideStr = (NSString *)[notif object];
  BOOL hideDot = (BOOL)[hideStr intValue];
  
  if (hideSysFiles != hideDot) {
    [self clearCache];

    hideSysFiles = hideDot;

    [[NSNotificationCenter defaultCenter]
	 		 postNotificationName: GWSortTypeDidChangeNotification
		 								 object: nil];  
  }
}

- (NSImage *)iconForFile:(NSString *)fullPath ofType:(NSString *)type
{
  NSImage *icon;
	NSSize size;
  
  if (usesThumbnails) {
    icon = [self thumbnailForPath: fullPath];
    
    if (icon) {
      return icon;
    }    
  }

  icon = [ws iconForFile: fullPath];
  size = [icon size];
  
  if ((size.width > ICNMAX) || (size.height > ICNMAX)) {
    NSSize newsize;
  
    if (size.width >= size.height) {
      newsize.width = ICNMAX;
      newsize.height = floor(ICNMAX * size.height / size.width + 0.5);
    } else {
      newsize.height = ICNMAX;
      newsize.width  = floor(ICNMAX * size.width / size.height + 0.5);
    }
    
	  [icon setScalesWhenResized: YES];
	  [icon setSize: newsize];  
  }
  
  return icon;
}

- (NSImage *)smallIconForFile:(NSString*)aPath
{
	NSImage *icon = [[self iconForFile: aPath ofType: nil] copy];
  NSSize size = [icon size];
  #ifdef GNUSTEP 
    float fact = 2.0;
  #else
    float fact = 1.33;
  #endif

  [icon setScalesWhenResized: YES];
  [icon setSize: NSMakeSize(size.width / fact, size.height / fact)];

  return AUTORELEASE (icon);
}

- (NSImage *)smallIconForFiles:(NSArray*)pathArray
{
	NSImage *icon = [NSImage imageNamed: @"MultipleSelection.tiff"];
  NSSize size = [icon size];
  [icon setScalesWhenResized: YES];
  [icon setSize: NSMakeSize(size.width / 2, size.height / 2)];
	
	return icon;
}

- (NSImage *)smallHighlightIcon
{
  return [NSImage imageNamed: @"SmallCellHighlightSmall.tiff"];
}

- (NSImage *)thumbnailForPath:(NSString *)path
{
  if (usesThumbnails == NO) {
    return nil;
  } else {
    return [tumbsCache objectForKey: path];
  }

  return nil;
}

- (void)prepareThumbnailsCache
{
  NSString *dictName = @"thumbnails.plist";
  NSString *dictPath = [thumbnailDir stringByAppendingPathComponent: dictName];
  NSDictionary *tdict;
  
  TEST_RELEASE (tumbsCache);
  tumbsCache = [NSMutableDictionary new];
  
  tdict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
    
  if (tdict) {
    NSArray *keys = [tdict allKeys];
    int i;

    for (i = 0; i < [keys count]; i++) {
      NSString *key = [keys objectAtIndex: i];
      NSString *tumbname = [tdict objectForKey: key];
      NSString *tumbpath = [thumbnailDir stringByAppendingPathComponent: tumbname]; 

      if ([fm fileExistsAtPath: tumbpath]) {
        NSImage *tumb = [[NSImage alloc] initWithContentsOfFile: tumbpath];
        
        if (tumb) {
          [tumbsCache setObject: tumb forKey: key];
          RELEASE (tumb);
        }
      }
    }
  } 
}

- (void)thumbnailsDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSArray *deleted = [info objectForKey: @"deleted"];	
  NSArray *created = [info objectForKey: @"created"];	
  int i;

  if (usesThumbnails == NO) {
    return;
  }
  
  if ([deleted count]) {
    for (i = 0; i < [deleted count]; i++) {
      NSString *path = [deleted objectAtIndex: i];
      
      [tumbsCache removeObjectForKey: path];
    }
  }
  
  if ([created count]) {
    NSString *dictName = @"thumbnails.plist";
    NSString *dictPath = [thumbnailDir stringByAppendingPathComponent: dictName];
    NSDictionary *tdict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
  
    for (i = 0; i < [created count]; i++) {
      NSString *key = [created objectAtIndex: i];
      NSString *tumbname = [tdict objectForKey: key];
      NSString *tumbpath = [thumbnailDir stringByAppendingPathComponent: tumbname]; 

      if ([fm fileExistsAtPath: tumbpath]) {
        NSImage *tumb = [[NSImage alloc] initWithContentsOfFile: tumbpath];
        
        if (tumb) {
          [tumbsCache setObject: tumb forKey: key];
          RELEASE (tumb);
        }
      }
    }
  }
}

- (void)setUseThumbnails:(BOOL)value
{
  if (usesThumbnails == value) {
    return;
  }
    
  usesThumbnails = value;
  if (usesThumbnails) {
    [self prepareThumbnailsCache];
  }
}

- (NSArray *)imageExtensions
{
  return [NSArray arrayWithObjects: @"tiff", @"tif", @"TIFF", @"TIF", 
                                    @"png", @"PNG", @"jpeg", @"jpg", 
                                    @"JPEG", @"JPG", @"gif", @"GIF", 
                                    @"xpm", nil];
}

- (id)workspaceApp
{
  if (workspaceApp == nil) {
    NSUserDefaults *defaults;
    NSString *appName;
    NSString *selName;
    Class wkspclass;
    SEL sel;
    
    defaults = [NSUserDefaults standardUserDefaults];
    
    appName = [defaults stringForKey: @"GSWorkspaceApplication"];
    if (appName == nil) {
      appName = @"GWorkspace";
    }

    selName = [defaults stringForKey: @"GSWorkspaceSelName"];
    if (selName == nil) {
      selName = @"gworkspace";
    }
  
    #ifdef GNUSTEP 
		  wkspclass = [[NSBundle mainBundle] principalClass];
    #else
		  wkspclass = [[NSBundle mainBundle] classNamed: appName];
    #endif
    
    sel = NSSelectorFromString(selName);
    
    workspaceApp = [wkspclass performSelector: sel];
  }  

  return workspaceApp;
}

@end


@implementation GWLib

+ (NSArray *)sortedDirectoryContentsAtPath:(NSString *)path
{
  return [[self instance] sortedDirectoryContentsAtPath: path];
}

+ (NSArray *)checkHiddenFiles:(NSArray *)files atPath:(NSString *)path
{
  return [[self instance] checkHiddenFiles: files atPath: path];
}

+ (void)setCachedMax:(int)cmax
{
  [[self instance] setCachedMax: cmax];
}

+ (void)addWatcherForPath:(NSString *)path
{
  [[self instance] addWatcherForPath: path];
}

+ (void)removeWatcherForPath:(NSString *)path
{
  [[self instance] removeWatcherForPath: path];
}

+ (void)lockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path
{
  [[self instance] lockFiles: files inDirectoryAtPath: path];
}

+ (void)unLockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path
{
  [[self instance] unLockFiles: files inDirectoryAtPath: path];
}

+ (BOOL)isLockedPath:(NSString *)path
{
  return [[self instance] isLockedPath: path];
}

+ (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path 
{
  return [[self instance] existsAndIsDirectoryFileAtPath: path];
}

+ (NSString *)typeOfFileAt:(NSString *)path
{
  return [[self instance] typeOfFileAt: path];
}

+ (BOOL)isPakageAtPath:(NSString *)path
{
  return [[self instance] isPakageAtPath: path];
}

+ (int)sortTypeForDirectoryAtPath:(NSString *)path
{
  return [[self instance] sortTypeForDirectoryAtPath: path];
}

+ (void)setSortType:(int)type forDirectoryAtPath:(NSString *)path
{
  [[self instance] setSortType: type forDirectoryAtPath: path];
}

+ (void)setDefSortType:(int)type
{
  [[self instance] setDefSortType: type];
}

+ (int)defSortType
{
  return [[self instance] defSortType];
}

+ (void)setHideSysFiles:(BOOL)value
{
  [[self instance] setHideSysFiles: value];
}

+ (BOOL)hideSysFiles
{
  return [[self instance] hideSysFiles];
}

+ (void)setHiddenPaths:(NSArray *)paths
{
  [[self instance] setHiddenPaths: paths];
}

+ (NSArray *)hiddenPaths
{
  return [[self instance] hiddenPaths];
}

+ (NSImage *)iconForFile:(NSString *)fullPath ofType:(NSString *)type
{
  return [[self instance] iconForFile: fullPath ofType: type];
}

+ (NSImage *)smallIconForFile:(NSString*)aPath
{
  return [[self instance] smallIconForFile: aPath];
}

+ (NSImage *)smallIconForFiles:(NSArray*)pathArray
{
  return [[self instance] smallIconForFiles: pathArray];
}

+ (NSImage *)smallHighlightIcon
{
  return [[self instance] smallHighlightIcon];
}

+ (void)setUseThumbnails:(BOOL)value
{
  [[self instance] setUseThumbnails: value];
}

+ (NSArray *)imageExtensions
{
  return [[self instance] imageExtensions];
}

+ (id)workspaceApp
{
  return [[self instance] workspaceApp];
}

@end
