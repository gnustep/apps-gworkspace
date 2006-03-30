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

#define PERFORM_QUERY(d, q) \
do { \
  if (performWriteQuery(d, q) == NO) { \
    NSLog(@"error at: %@", q); \
    RELEASE (path); \
    return NO; \
  } \
} while (0)

#define SKIP_EXPIRE (1.0)


@implementation GMDSExtractor (updater)

- (BOOL)addPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
      
  if (attributes) {
    id extractor = nil;

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

    if ([attributes fileType] == NSFileTypeDirectory) {
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: path];
      
      while (1) {
        CREATE_AUTORELEASE_POOL(arp); 
        NSString *entry = [enumerator nextObject];
        NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 0.001];
        BOOL skip = NO;

        [[NSRunLoop currentRunLoop] runUntilDate: date];

        if (entry) {
          NSString *subpath = [path stringByAppendingPathComponent: entry];

          skip = (isDotFile(subpath) 
                    || inTreeFirstPartOfPath(subpath, excludedPathsTree));
        
          attributes = [fm fileAttributesAtPath: subpath traverseLink: NO];
        
          if (attributes) {
            if (skip == NO) {
              if ([self insertOrUpdatePath: subpath withAttributes: attributes] == NO) {
                RELEASE (arp);
                return NO;
              }

              extractor = [self extractorForPath: subpath withAttributes: attributes];
                  
              if (extractor) {
                if ([extractor extractMetadataAtPath: subpath
                                      withAttributes: attributes
                                        usingStemmer: stemmer
                                           stopWords: stopWords] == NO) {
                  RELEASE (arp);
                  return NO;
                }
              }
            }
          
            if (([attributes fileType] == NSFileTypeDirectory) && skip) {
              GWDebugLog(@"skipping %@", subpath); 
              [enumerator skipDescendents];
            }
          }
          
        } else {
          RELEASE (arp);
          break;
        }
        
        TEST_RELEASE (arp);
      }
    }
    
    return YES;
  }
  
  return NO;
}

- (BOOL)updatePath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
      
  if (attributes) {
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
  
  return NO;
}

- (BOOL)updateRenamedPath:(NSString *)path 
                  oldPath:(NSString *)oldpath
{











  return YES;
}

/*
    [query appendFormat: @"FROM files WHERE path > '%@", stringForQuery(path)];

    if ([path isEqual: path_separator()] == NO) {
      [query appendString: path_separator()];
    }
    [query appendString: @"' "];
    
    if ([path isEqual: path_separator()] == NO) {
      [query appendFormat: @"AND path < '%@0' ", stringForQuery(path)];
    } else {
      [query appendString: @"AND path < '0' "];
    }


select path_id from postings 
where path_id = (SELECT id FROM paths WHERE path = '/root/AA');



CREATE TABLE id_tmp (id INTEGER PRIMARY KEY);

INSERT INTO id_tmp (id) SELECT id FROM paths WHERE path = '/root/Mailboxes/GNUstep';


SELECT path FROM paths 
  WHERE path > '/root/Mailboxes/'
  AND path < '/root/Mailboxes0';
  
SELECT path FROM paths 
  WHERE path > '/root/Desktop/AA/'
  AND path < '/root/Desktop/AA0';
  

DELETE FROM postings WHERE path_id IN (SELECT id FROM id_tmp);

DROP TABLE id_tmp;
*/


- (BOOL)removePath:(NSString *)path
{
  NSMutableString *query;

  PERFORM_QUERY (db, @"BEGIN");

  PERFORM_QUERY (db, @"CREATE TABLE id_tmp (id INTEGER PRIMARY KEY)");
  
  query = [NSMutableString stringWithCapacity: 128];
  [query appendString: @"INSERT INTO id_tmp (id) SELECT id FROM paths "];
  [query appendFormat: @"WHERE path = '%@'", stringForQuery(path)];
  PERFORM_QUERY (db, query);
  
  query = [NSMutableString stringWithCapacity: 128];
  [query appendString: @"INSERT INTO id_tmp (id) SELECT id FROM paths "];
  [query appendFormat: @"WHERE path > '%@", stringForQuery(path)];

  if ([path isEqual: path_separator()] == NO) {
    [query appendString: path_separator()];
  }
  [query appendString: @"' "];

  if ([path isEqual: path_separator()] == NO) {
    [query appendFormat: @"AND path < '%@0' ", stringForQuery(path)];
  } else {
    [query appendString: @"AND path < '0' "];
  }
  
  PERFORM_QUERY (db, query);

  PERFORM_QUERY (db, @"DELETE FROM postings WHERE path_id IN (SELECT id FROM id_tmp)");
  PERFORM_QUERY (db, @"DELETE FROM attributes WHERE path_id IN (SELECT id FROM id_tmp)");
  PERFORM_QUERY (db, @"DELETE FROM paths WHERE id IN (SELECT id FROM id_tmp)");

  PERFORM_QUERY (db, @"DROP TABLE id_tmp");

  PERFORM_QUERY (db, @"COMMIT");

  return YES;
}

@end


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
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];  
  
  [dict setObject: path forKey: @"path"];
  [dict setObject: event forKey: @"event"];
  
  if ([event isEqual: @"GWWatchedPathRenamed"]) {
    NSString *oldpath = [info objectForKey: @"oldpath"];
 
    if (oldpath != nil) {
      [dict setObject: oldpath forKey: @"oldpath"];
    } 
  } 

  if ([fswupdatePaths containsObject: dict] == NO) {
    NSDictionary *skipInfo = [fswupdateSkipBuff objectForKey: path];
    BOOL caninsert = YES;
    
    if (skipInfo != nil) {
      NSString *lastevent = [skipInfo objectForKey: @"event"];
    
      if ([lastevent isEqual: event]) {
        caninsert = NO;
      } else {
        skipInfo = [NSDictionary dictionaryWithObjectsAndKeys: event, 
                                                               @"event", 
                                                               [NSDate date], 
                                                               @"stamp", 
                                                               nil];     
        [fswupdateSkipBuff setObject: skipInfo forKey: path];
      }
    } else {
      skipInfo = [NSDictionary dictionaryWithObjectsAndKeys: event, 
                                                             @"event", 
                                                             [NSDate date], 
                                                             @"stamp", 
                                                             nil];     
      [fswupdateSkipBuff setObject: skipInfo forKey: path];
    }
  
    if (caninsert) {
      [fswupdatePaths insertObject: dict atIndex: 0];
      GWDebugLog(@"inserting: %@ - %@", path, event);
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
    NSString *event = [dict objectForKey: @"event"];
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow: 0.001];
        
    [[NSRunLoop currentRunLoop] runUntilDate: date]; 
    
    if ([event isEqual: @"GWWatchedFileModified"]) {
      GWDebugLog(@"db update: %@", path);
      
      if ([self updatePath: path] == NO) {      
        NSLog(@"An error occurred while processing %@", path);
      }
      
    } else if ([event isEqual: @"GWWatchedPathDeleted"]) {
      GWDebugLog(@"db remove: %@", path);
      
      [self removePath: path];

    } else if ([event isEqual: @"GWWatchedPathRenamed"]) {
      NSString *oldpath = [dict objectForKey: @"oldpath"];
 
      if (oldpath != nil) {
        GWDebugLog(@"db rename: %@ -> %@", oldpath, path);
        
        if ([self updateRenamedPath: path oldPath: oldpath] == NO) { 
          NSLog(@"An error occurred while processing %@", path);
        }
        
      } else {
        GWDebugLog(@"db update renamed: %@", path);
        
        if ([self addPath: path] == NO) {      
          NSLog(@"An error occurred while processing %@", path);
        }
      }
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










