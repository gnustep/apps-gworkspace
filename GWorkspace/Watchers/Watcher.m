/*  -*-objc-*-
 *  Watcher.m: Implementation of the Watcher Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWProtocol.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "Watcher.h"
#include "GNUstep.h"

@implementation Watcher

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
    #ifdef GNUSTEP 
		  Class gwclass = [[NSBundle mainBundle] principalClass];
    #else
		  Class gwclass = [[NSBundle mainBundle] classNamed: @"GWorkspace"];
    #endif
		NSDictionary *attributes;
		
		gworkspace = (id<GWProtocol>)[gwclass gworkspace];
		
		fm = [NSFileManager defaultManager];	
    ASSIGN (watchedPath, path);    
		ASSIGN (pathContents, ([fm directoryContentsAtPath: watchedPath]));
		attributes = [fm fileAttributesAtPath: path traverseLink: YES];  
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
[[NSNotificationCenter defaultCenter] \
postNotificationName: GWFileWatcherFileDidChangeNotification object: o]; \
} 
 
	if (isOld) {
		return;
	}
	
	attributes = [fm fileAttributesAtPath: watchedPath traverseLink: YES];

  if (attributes == nil) {
    notifdict = [NSMutableDictionary dictionaryWithCapacity: 1];
    [notifdict setObject: GWWatchedDirectoryDeleted forKey: @"event"];
    [notifdict setObject: watchedPath forKey: @"path"];
    FW_NOTIFY (notifdict);
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
    	FW_NOTIFY (notifdict);
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
			BOOL locked = NO;
			
			for (i = 0; i < [diffFiles count]; i++) {
				NSString *fname = [diffFiles objectAtIndex: i];
				NSString *fpath = [watchedPath stringByAppendingPathComponent: fname];
			
				if ([gworkspace isLockedPath: fpath]) {
					locked = YES;
					break;
				}
			}
			
			if (locked == NO) {
      	[notifdict setObject: GWFileDeletedInWatchedDirectory forKey: @"event"];
      	[notifdict setObject: diffFiles forKey: @"files"];
      	FW_NOTIFY (notifdict);
			}
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
			BOOL locked = NO;
			
			for (i = 0; i < [diffFiles count]; i++) {
				NSString *fname = [diffFiles objectAtIndex: i];
				NSString *fpath = [watchedPath stringByAppendingPathComponent: fname];
			
				if ([gworkspace isLockedPath: fpath]) {
					locked = YES;
					break;
				}
			}
			
			if (locked == NO) {
      	[notifdict setObject: watchedPath forKey: @"path"];
      	[notifdict setObject: GWFileCreatedInWatchedDirectory forKey: @"event"];
      	[notifdict setObject: diffFiles forKey: @"files"];
      	FW_NOTIFY (notifdict);
			}
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

