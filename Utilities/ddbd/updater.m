/* updater.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
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

#include "updater.h"
#include "ddbd.h"
#include "SQLite.h"
#include "functions.h"

@implementation	DDBdUpdater

- (void)dealloc
{
  if (sqlite) {
    [sqlite closedb];
    RELEASE (sqlite);
  }
  RELEASE (updinfo);
  RELEASE (lock);
  DESTROY (ddbd);
  
	[super dealloc];
}

+ (void)updaterForTask:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL(arp);
  DDBdUpdater *updater = [[self alloc] init];
  
  [updater setUpdaterTask: info];
  RELEASE (updater);
                              
  [[NSRunLoop currentRunLoop] run];
  RELEASE (arp);
}

- (id)init
{
  self = [super init];

  if (self) {
    fm = [NSFileManager defaultManager];	
    ddbd = nil;
  }
  
  return self;
}

- (void)setUpdaterTask:(NSDictionary *)info
{
  NSString *dbpath = [info objectForKey: @"dbpath"];
  NSDictionary *dict = [info objectForKey: @"taskdict"];
  int type = [[info objectForKey: @"type"] intValue];
  
  ASSIGN (updinfo, dict);
  
  sqlite = [[SQLite alloc] initWithDatabasePath: dbpath];
  
  RETAIN (self);
    
  [self connectDDBd];  
  
  if ([sqlite opendb] == NO) {
    NSLog(@"updater error");
    [self done];
  }
  
  NSLog(@"starting Desktop database update");

  switch(type) {
    case DDBdFileOperationUpdate:
      [self fileSystemDidChange];
      break;

    case DDBdDaylyUpdate:
      [self daylyUpdate];
      break;

    default:
      [self done];
      break;
  }
}

- (void)done
{
  if (ddbd) {
    NSConnection *ddbdconn = [(NSDistantObject *)ddbd connectionForProxy];
  
    if (ddbdconn && [ddbdconn isValid]) {
      [[NSNotificationCenter defaultCenter] removeObserver: self
	                        name: NSConnectionDidDieNotification
	                      object: ddbdconn];
      DESTROY (ddbd);
    }
  }

  [sqlite closedb];
  DESTROY (sqlite);
  RELEASE (self);
  
  [NSThread exit];
}

- (BOOL)checkPath:(NSString *)path
{
  return (sqlite && [self infoOfType: @"path" forPath: path]);
}

- (NSData *)infoOfType:(NSString *)type
               forPath:(NSString *)path
{
  if (sqlite && [fm fileExistsAtPath: path]) {
    NSArray *results = nil;
    NSString *query = [NSString stringWithFormat: 
                          @"SELECT %@ FROM files WHERE path = '%@'", 
                                              type, stringForQuery(path)];
    results = [sqlite performQuery: query];
    
    if (results && [results count]) {
      NSDictionary *dict = [results objectAtIndex: 0];
      return [dict objectForKey: type];
    }
  }
  
  return nil;
}

- (void)connectDDBd
{
  if (ddbd == nil) {
    id db = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                              host: @""];

    if (db) {
      NSConnection *c = [db connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(ddbdConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      ddbd = db;
	    [ddbd setProtocolForProxy: @protocol(DDBdProtocol)];
      RETAIN (ddbd);
                                         
	  } else {
	    static BOOL recursion = NO;

      if (recursion == NO) {
        int i;
        
        for (i = 1; i <= 40; i++) {
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          db = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                                 host: @""];                  
          if (db) {
            break;
          }
        }
        
	      recursion = YES;
	      [self connectDDBd];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        NSLog(@"updater: unable to connect ddbd");
        [self done];
      }
	  }
  }
}

- (void)ddbdConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [[NSNotificationCenter defaultCenter] removeObserver: self
	                    name: NSConnectionDidDieNotification
	                  object: connection];

  NSAssert(connection == [ddbd connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (ddbd);
  ddbd = nil;
  NSLog(@"updater: ddbd connection died");
  [self done];
}

- (void)fileSystemDidChange
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *operation = [updinfo objectForKey: @"operation"];
  NSString *source = [updinfo objectForKey: @"source"];
  NSString *destination = [updinfo objectForKey: @"destination"];
  NSArray *files = [updinfo objectForKey: @"files"];
  NSArray *origfiles = [updinfo objectForKey: @"origfiles"];
  NSMutableArray *srcpaths = [NSMutableArray array];
  NSMutableArray *dstpaths = [NSMutableArray array];
  NSMutableString *query;
  NSArray *results;
  BOOL copy, remove; 
  int i, j;
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    srcpaths = [NSArray arrayWithObject: source];
    dstpaths = [NSArray arrayWithObject: destination];
  } else {
    if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) { 
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [origfiles objectAtIndex: i];
        [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
        fname = [files objectAtIndex: i];
        [dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
      }
    } else {  
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
        [dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
      }
    }
  }

  copy = ([operation isEqual: @"NSWorkspaceMoveOperation"] 
                || [operation isEqual: @"NSWorkspaceCopyOperation"]
                || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
                || [operation isEqual: @"GWorkspaceRenameOperation"]); 

  remove = ([operation isEqual: @"NSWorkspaceMoveOperation"]
                || [operation isEqual: @"NSWorkspaceDestroyOperation"]
				        || [operation isEqual: @"NSWorkspaceRecycleOperation"]);
    
  for (i = 0; i < [srcpaths count]; i++) {
    CREATE_AUTORELEASE_POOL(pool1);
    NSString *srcpath = [srcpaths objectAtIndex: i];
    NSString *dstpath = [dstpaths objectAtIndex: i];
    NSDictionary *attrs = [fm fileAttributesAtPath: dstpath traverseLink: NO];
    
    query = (NSMutableString *)[NSMutableString string];
    [query appendFormat: @"SELECT path FROM files WHERE path = '%@'", 
                                                  stringForQuery(srcpath)];
    results = [sqlite performQuery: query];
    
    if (results && [results count]) { 
      if (attrs && copy) {
        if ([ddbd setInfoOfPath: srcpath toPath: dstpath] == NO) {
           NSLog(@"updater: error at path: %@", dstpath);
          [sqlite closedb];
           RELEASE (pool1);
          [self done];
        }
      }
      
      if (remove && ([fm fileExistsAtPath: srcpath] == NO)) {
        if ([ddbd removePath: srcpath] == NO) {
          NSLog(@"updater: error at path: %@", srcpath);
          [sqlite closedb];
           RELEASE (pool1);
          [self done];
        }      
      }
    } 
 
    if (attrs && ([attrs fileType] == NSFileTypeDirectory)) {
      query = [NSString stringWithFormat: 
                      @"SELECT path FROM files WHERE path GLOB '%@%@*'", 
                                    stringForQuery(srcpath), path_separator()];

      results = [sqlite performQuery: query];
      
      if (results && [results count]) {                 
        for (j = 0; j < [results count]; j++) {
          CREATE_AUTORELEASE_POOL(pool2);
          NSDictionary *dict = [results objectAtIndex: j];
          NSData *data = [dict objectForKey: @"path"];      
          NSString *oldpath = [NSString stringWithUTF8String: [data bytes]];
          NSString *newpath;

          newpath = pathRemovingPrefix(oldpath, srcpath);
          newpath = [dstpath stringByAppendingPathComponent: newpath];

          if ([fm fileExistsAtPath: newpath] && copy) {
            if ([ddbd setInfoOfPath: oldpath toPath: newpath] == NO) {
              NSLog(@"updater: error at path: %@", newpath);
              [sqlite closedb];
              RELEASE (pool2);
              RELEASE (pool1);
              [self done];
            }
          }

          if (remove && ([fm fileExistsAtPath: oldpath] == NO)) {
            if ([ddbd removePath: oldpath] == NO) {
              NSLog(@"updater: error at path: %@", srcpath);
              [sqlite closedb];
              RELEASE (pool2);
              RELEASE (pool1);
              [self done];
            }      
          }
          
          RELEASE (pool2);
        }
      }
    }

    RELEASE (pool1);
  }  
  
  RELEASE (arp);

  [self done];
}

- (void)daylyUpdate
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *query = @"SELECT path FROM files";
  NSArray *results = [sqlite performQuery: query];

  if (results && [results count]) { 
    int i;

    for (i = 0; i < [results count]; i++) {
      NSDictionary *dict = [results objectAtIndex: i];
      NSData *data = [dict objectForKey: @"path"];      
      NSString *path = [NSString stringWithUTF8String: [data bytes]];
      
      if ([fm fileExistsAtPath: path] == NO) {
        if ([ddbd removePath: path] == NO) {
          NSLog(@"updater: error at path: %@", path);
          [sqlite closedb];
          RELEASE (arp);
          [self done];
        } else {
          NSLog(@"removing unexisting path: %@", path);
        }            
      }
    }
  }
  
  RELEASE (arp);
  [self done];
}

@end

