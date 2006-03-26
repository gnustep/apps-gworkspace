/* updater.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: February 2006
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "mdextractor.h"
#include "config.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#define SKIP_EXPIRE (1.0)

@implementation GMDSExtractor (fswatcher_update)

- (void)setupFswatcherUpdater
{
  fswupdatePaths = [NSMutableArray new];
  fswupdateSkipBuff = [NSMutableDictionary new];
     
  fswupdateTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 
						                         target: self 
                                   selector: @selector(processPendingChanges:) 
																   userInfo: nil 
                                    repeats: YES];
  RETAIN (fswupdateTimer);     
     
  fswatcher = nil;
  [self connectFSWatcher];
}

- (oneway void)globalWatchedPathDidChange:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *path = [info objectForKey: @"path"];
  NSString *event = [info objectForKey: @"event"];
  NSNumber *exists;
  NSDictionary *dict;  
  
  if ([event isEqual: @"GWWatchedFileModified"]) {
    exists = [NSNumber numberWithBool: YES];
    
  } else if ([event isEqual: @"GWWatchedPathDeleted"]) {
    exists = [NSNumber numberWithBool: NO];
    
  } else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
    NSString *fname = [[info objectForKey: @"files"] objectAtIndex: 0];
    
    path = [path stringByAppendingPathComponent: fname];
    exists = [NSNumber numberWithBool: YES];
    
  } else if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
    NSString *fname = [[info objectForKey: @"files"] objectAtIndex: 0];
    
    path = [path stringByAppendingPathComponent: fname];
    exists = [NSNumber numberWithBool: NO];
  }
            
  dict = [NSDictionary dictionaryWithObjectsAndKeys: path, @"path", exists, @"exists", nil]; 

  if ([fswupdatePaths containsObject: dict] == NO) {
    NSDictionary *skipInfo = [fswupdateSkipBuff objectForKey: path];
    BOOL caninsert = YES;
    
    if (skipInfo != nil) {
      NSNumber *didexist = [skipInfo objectForKey: @"exists"];
    
      if ([didexist isEqual: exists]) {
        caninsert = NO;
      } else {
        skipInfo = [NSDictionary dictionaryWithObjectsAndKeys: exists, 
                                                               @"exists", 
                                                               [NSDate date], 
                                                               @"stamp", 
                                                               nil];     
        [fswupdateSkipBuff setObject: skipInfo forKey: path];
      }
    } else {
      skipInfo = [NSDictionary dictionaryWithObjectsAndKeys: exists, 
                                                             @"exists", 
                                                             [NSDate date], 
                                                             @"stamp", 
                                                             nil];     
      [fswupdateSkipBuff setObject: skipInfo forKey: path];
    }
  
    if (caninsert) {
      [fswupdatePaths insertObject: dict atIndex: 0];
      GWDebugLog(@"inserting: %@", path);
    }
  }
    
  RELEASE (arp);                       
}

- (void)processPendingChanges:(id)sender
{
  CREATE_AUTORELEASE_POOL(arp);
  
  while ([fswupdatePaths count] > 0) {
    NSDictionary *dict = [fswupdatePaths lastObject];
    NSString *path = [dict objectForKey: @"path"];    
    BOOL exists = [[dict objectForKey: @"exists"] boolValue];
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 0.001];
        
    [[NSRunLoop currentRunLoop] runUntilDate: date]; 
    
    if (exists) {
      NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
      
      if (attributes) {
        GWDebugLog(@"db update: %@", path);
        if ([self updatePath: path attributes: attributes] == NO) {      
          NSLog(@"An error occurred while processing %@", path);
        }
      }
    } else {
      GWDebugLog(@"db remove: %@", path);
      [self removePath: path];
    }
    
    [fswupdatePaths removeLastObject];    
  }
  
  {
    NSArray *skipPaths = [fswupdateSkipBuff allKeys];
    NSDate *now = [NSDate date];
    unsigned i;
    
    RETAIN (skipPaths);
    
    for (i = 0; i < [skipPaths count]; i++) {
      NSString *path = [skipPaths objectAtIndex: i];
      NSDictionary *skipInfo = [fswupdateSkipBuff objectForKey: path];
      NSDate *stamp = [skipInfo objectForKey: @"stamp"];
      
      if ([now timeIntervalSinceDate: stamp] > SKIP_EXPIRE) {
        [fswupdateSkipBuff removeObjectForKey: path];
        GWDebugLog(@"expired skip-info %@", path);
      }
    }
    
    RELEASE (skipPaths);
  }  
    
  RELEASE (arp);  
}

- (BOOL)updatePath:(NSString *)path
        attributes:(NSDictionary *)attributes
{
  id extractor;
  
  if ([self insertOrUpdatePath: path withAttributes: attributes] == NO) {
    return NO;
  }

  extractor = [self extractorForPath: path withAttributes: attributes];

  if (extractor) {
    if ([extractor extractMetadataAtPath: path
                          withAttributes: attributes
                            usingStemmer: stemmer
                               stopWords: stopWords] == NO) {
      return NO;
    }
  }

  return YES;
}

- (void)connectFSWatcher
{
  if (fswatcher == nil) {
    id fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                               host: @""];

    if (fsw) {
      NSConnection *c = [fsw connectionForProxy];

	    [nc addObserver: self
	           selector: @selector(fswatcherConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: c];
      
      fswatcher = fsw;
	    [fswatcher setProtocolForProxy: @protocol(FSWatcherProtocol)];
      RETAIN (fswatcher);
                                   
	    [fswatcher registerClient: (id <FSWClientProtocol>)self 
                isGlobalWatcher: YES];
      
      NSLog(@"fswatcher connected!");
      
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
          cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"fswatcher"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        DESTROY (cmd);
        
        for (i = 1; i <= 40; i++) {
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                                  host: @""];                  
          if (fsw) {
            break;
          }
        }
        
	      recursion = YES;
	      [self connectFSWatcher];
	      recursion = NO;
        
	    } else { 
        DESTROY (cmd);
	      recursion = NO;
        NSLog(@"unable to contact fswatcher!");  
      }
	  }
  }
}

- (void)fswatcherConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  NSAssert(connection == [fswatcher connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (fswatcher);
  fswatcher = nil;

  NSLog(@"The fswatcher connection died!");

  [self connectFSWatcher];                
}

@end










