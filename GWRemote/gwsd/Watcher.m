/* Watcher.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep gwsd tool
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "Watcher.h"
#include "gwsd.h"
#include "externs.h"
#include "GNUstep.h"

@implementation GWSd (Watchers)

- (void)_addWatcherForPath:(NSString *)path
{
  Watcher *watcher = [self watcherForPath: path];
	      
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
  	  watcher = [[Watcher alloc] initForforGWSd: self watchAtPath: path];   
  	  [watchers addObject: watcher];
  	  RELEASE (watcher);  
    }
	}
}

- (void)_removeWatcherForPath:(NSString *)path
{
  Watcher *watcher = [self watcherForPath: path];
  
  if ((watcher != nil) && ([watcher isOld] == NO)) {
  	[watcher removeListener];   
  }
}

- (void)suspendWatchingForPath:(NSString *)path
{
  Watcher *watcher = [self watcherForPath: path];

  if ((watcher != nil) && ([watcher isOld] == NO)) {
    [watcher setSuspended: YES];
  }
}

- (void)restartWatchingForPath:(NSString *)path
{
  Watcher *watcher = [self watcherForPath: path];

  if (watcher) {
    NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: YES];

    if (attributes) {
      [watcher setDate: [attributes fileModificationDate]];
      [watcher setPathContents: [fm directoryContentsAtPath: path]];
      [watcher setSuspended: NO];
    } else {
      [self removeWatcher: watcher];
    }
  } else {
    [self _addWatcherForPath: path];
  }
}

- (Watcher *)watcherForPath:(NSString *)path
{
  int i;

  for (i = 0; i < [watchers count]; i++) {
    Watcher *watcher = [watchers objectAtIndex: i];    
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

- (void)watcherTimeOut:(id)sender
{
	NSString *watchedPath = (NSString *)[sender userInfo];
	
	if (watchedPath != nil) {
		Watcher *watcher = [self watcherForPath: watchedPath];
	
		if (watcher != nil) {
			if ([watcher isOld]) {
				[self removeWatcher: watcher];
			} else {
				[watcher watchFile];
			}
		}
	}
}

- (void)removeWatcher:(Watcher *)awatcher
{
	NSString *watchedPath = [awatcher watchedPath];
	NSTimer *timer = [self timerForPath: watchedPath];

	if (timer && [timer isValid]) {
		[timer invalidate];
		[watchTimers removeObject: timer];
	}
	
	[watchers removeObject: awatcher];
}

- (void)watcherNotification:(NSDictionary *)dict
{
  [gwsdClient server: self fileSystemDidChange: dict];  
}

@end

@implementation Watcher

- (void)dealloc
{  
  RELEASE (watchedPath);  
  TEST_RELEASE (pathContents);
  RELEASE (date);  
  [super dealloc];
}

- (id)initForforGWSd:(GWSd *)gw watchAtPath:(NSString *)path
{
  self = [super init];
  
  if (self) { 
		NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: YES];  
		
		ASSIGN (date, [attributes fileModificationDate]);				
    ASSIGN (watchedPath, path);    
		fm = [NSFileManager defaultManager];	
		ASSIGN (pathContents, ([fm directoryContentsAtPath: watchedPath]));
    listeners = 1;
		isOld = NO;
    suspended = NO;
    
		gwsd = gw;
    clientLock = [gwsd clientLock];
  }
  
  return self;
}

- (void)watchFile
{
  NSDictionary *attributes;
  NSDate *moddate;
  NSMutableDictionary *notifdict;

#define NOTIFY \
[gwsd watcherNotification: notifdict]
 
	if (isOld || suspended) {
		return;
	}
	
	attributes = [fm fileAttributesAtPath: watchedPath traverseLink: YES];

  if (attributes == nil) {
    notifdict = [NSMutableDictionary dictionaryWithCapacity: 1];
    [notifdict setObject: GWWatchedDirectoryDeleted forKey: @"event"];
    [notifdict setObject: watchedPath forKey: @"path"];
    
    NOTIFY;
		isOld = YES;
    return;
  }
  	
  moddate = [attributes fileModificationDate];

  if ([date isEqualToDate: moddate] == NO) {
    NSArray *newconts = [fm directoryContentsAtPath: watchedPath];
    NSMutableArray *diffFiles = [NSMutableArray arrayWithCapacity: 1];
    int i;

    notifdict = [NSMutableDictionary dictionaryWithCapacity: 1];
    [notifdict setObject: watchedPath forKey: @"path"];

		/* if there is an error in fileAttributesAtPath */
		/* or watchedPath doesn't exist anymore         */
		if (newconts == nil) {		
			[notifdict setObject: GWWatchedDirectoryDeleted forKey: @"event"];
      NOTIFY;
			isOld = YES;
    	return;
		}
		
    for (i = 0; i < [pathContents count]; i++) {
      NSString *fname = [pathContents objectAtIndex: i];
      if ((newconts) && ([newconts containsObject: fname] == NO)) {
        [diffFiles addObject: fname];
      }
    }

    if ([diffFiles count] > 0) {
      [notifdict setObject: GWFileDeletedInWatchedDirectory forKey: @"event"];
      [notifdict setObject: [[diffFiles copy] autorelease] forKey: @"files"];
      NOTIFY;
    }              

    [diffFiles removeAllObjects];

		if (newconts) {
    	for (i = 0; i < [newconts count]; i++) {
      	NSString *fname = [newconts objectAtIndex: i];
      	if ([pathContents containsObject: fname] == NO) {   
        	[diffFiles addObject: fname];
      	}
    	}
		}
		
    if ([diffFiles count] > 0) {
      [notifdict setObject: GWFileCreatedInWatchedDirectory forKey: @"event"];
      [notifdict setObject: [[diffFiles copy] autorelease] forKey: @"files"];
      NOTIFY;
    }
		
		ASSIGN (pathContents, newconts);
    ASSIGN (date, moddate);		
	}   
}

- (void)addListener
{
  listeners++;
}

- (void)removeListener
{ 
  listeners--;
  if (listeners == 0) { 
		isOld = YES;
  } 
}

- (int)listeners
{
  return listeners;
}

- (BOOL)isWathcingPath:(NSString *)apath
{
  return ([apath isEqualToString: watchedPath]);
}

- (NSString *)watchedPath
{
	return watchedPath;
}

- (void)setPathContents:(NSArray *)conts
{
  ASSIGN (pathContents, conts);
}

- (void)setDate:(NSDate *)d
{
  ASSIGN (date, d);
}

- (BOOL)isOld
{
	return isOld;
}

- (void)setIsOld
{
	isOld = YES;
}

- (BOOL)isSuspended
{
  return suspended;
}

- (void)setSuspended:(BOOL)value
{
  suspended = value;
}

@end

