/* Watcher.m
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
  #ifdef GNUSTEP 
#include "GWLib.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "FSWatcher.h"
#include "GNUstep.h"

@implementation FSWatcher

- (void)dealloc
{  
  RELEASE (watchedPath);  
  TEST_RELEASE (pathContents);
  RELEASE (date);  
  [super dealloc];
}

- (id)initForWatchAtPath:(NSString *)path
{
  self = [super init];
  
  if (self) { 
		NSDictionary *attributes;
				
		fm = [NSFileManager defaultManager];	
    attributes = [fm fileAttributesAtPath: path traverseLink: YES];
    ASSIGN (watchedPath, path);    
		ASSIGN (pathContents, ([fm directoryContentsAtPath: watchedPath]));
		ASSIGN (date, [attributes fileModificationDate]);		
    listeners = 1;
		isOld = NO;
  }
  
  return self;
}

- (void)watchFile
{
  NSDictionary *attributes;
  NSDate *moddate;
  NSMutableDictionary *notifdict;

#define FW_NOTIFY(o) { \
NSNotification *notif = [NSNotification notificationWithName: \
GWFileWatcherFileDidChangeNotification object: o]; \
[[NSNotificationQueue defaultQueue] \
enqueueNotification: notif postingStyle: NSPostASAP \
coalesceMask: NSNotificationNoCoalescing \
forModes: nil]; \
AUTORELEASE (o); \
} 
 
	if (isOld) {
		return;
	}
	
	attributes = [fm fileAttributesAtPath: watchedPath traverseLink: YES];

  if (attributes == nil) {
    notifdict = [NSMutableDictionary dictionaryWithCapacity: 1];
    [notifdict setObject: GWWatchedDirectoryDeleted forKey: @"event"];
    [notifdict setObject: watchedPath forKey: @"path"];
    FW_NOTIFY ([notifdict copy]);
		isOld = YES;
    return;
  }
  	
  moddate = [attributes fileModificationDate];

  if ([date isEqualToDate: moddate] == NO) {
    NSArray *oldconts = [pathContents copy];
    NSArray *newconts = [fm directoryContentsAtPath: watchedPath];	
    NSMutableArray *diffFiles = [NSMutableArray array];
    int i;

    ASSIGN (date, moddate);	
    ASSIGN (pathContents, newconts);

    notifdict = [NSMutableDictionary dictionary];
    [notifdict setObject: watchedPath forKey: @"path"];

		/* if there is an error in fileAttributesAtPath */
		/* or watchedPath doesn't exist anymore         */
		if (newconts == nil) {		
			[notifdict setObject: GWWatchedDirectoryDeleted forKey: @"event"];
    	FW_NOTIFY ([notifdict copy]);
      RELEASE (oldconts);
			isOld = YES;
    	return;
		}
		
    for (i = 0; i < [oldconts count]; i++) {
      NSString *fname = [oldconts objectAtIndex: i];
      if ((newconts) && ([newconts containsObject: fname] == NO)) {
        [diffFiles addObject: fname];
      }
    }

    if ([diffFiles count] > 0) {
			BOOL locked = NO;
			
			for (i = 0; i < [diffFiles count]; i++) {
				NSString *fname = [diffFiles objectAtIndex: i];
				NSString *fpath = [watchedPath stringByAppendingPathComponent: fname];
			
				if ([GWLib isLockedPath: fpath]) {
					locked = YES;
					break;
				}
			}
			
			if (locked == NO) {
      	[notifdict setObject: GWFileDeletedInWatchedDirectory forKey: @"event"];
      	[notifdict setObject: diffFiles forKey: @"files"];
      	FW_NOTIFY ([notifdict copy]);
        RELEASE (oldconts);
        return;
			}
    }

    diffFiles = [NSMutableArray array];

		if (newconts) {
    	for (i = 0; i < [newconts count]; i++) {
      	NSString *fname = [newconts objectAtIndex: i];
      	if ([oldconts containsObject: fname] == NO) {   
        	[diffFiles addObject: fname];
      	}
    	}
		}
		
    if ([diffFiles count] > 0) {
			BOOL locked = NO;
			
			for (i = 0; i < [diffFiles count]; i++) {
				NSString *fname = [diffFiles objectAtIndex: i];
				NSString *fpath = [watchedPath stringByAppendingPathComponent: fname];
			
				if ([GWLib isLockedPath: fpath]) {
					locked = YES;
					break;
				}
			}
			
			if (locked == NO) {
      	[notifdict setObject: watchedPath forKey: @"path"];
      	[notifdict setObject: GWFileCreatedInWatchedDirectory forKey: @"event"];
      	[notifdict setObject: diffFiles forKey: @"files"];
      	FW_NOTIFY ([notifdict copy]);
        RELEASE (oldconts);
        return;        
			}
    }
    
    TEST_RELEASE (oldconts);		
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

- (BOOL)isWathcingPath:(NSString *)apath
{
  return ([apath isEqualToString: watchedPath]);
}

- (NSString *)watchedPath
{
	return watchedPath;
}

- (BOOL)isOld
{
	return isOld;
}

- (void)setIsOld
{
	isOld = YES;
}

@end

