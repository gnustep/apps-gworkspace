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
#include "functions.h"

@implementation	DDBdUpdater

- (void)dealloc
{
  if (db != NULL) {
    closedb(db);
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
  
  RETAIN (self);
    
  [self connectDDBd];  
  
  db = opendbAtPath(dbpath);
  
  if (db == NULL) {
    NSLog(@"updater error");
    [self done];
  }
  
  NSLog(@"starting Desktop database update");

  switch(type) {
    case DDBdInsertTreeUpdate:
      [self insertTrees];
      break;

    case DDBdRemoveTreeUpdate:
      [self removeTrees];
      break;

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

  closedb(db);
  RELEASE (self);
  
  [NSThread exit];
}

- (BOOL)checkPath:(NSString *)path
{
  return ((db != NULL) && checkPathInDb(db, path));
}

- (NSData *)infoOfType:(NSString *)type
               forPath:(NSString *)path
{
  if ((db != NULL) && [fm fileExistsAtPath: path]) {
    NSArray *results = nil;
    NSString *query = [NSString stringWithFormat: 
                          @"SELECT %@ FROM files WHERE path = '%@'", 
                                              type, stringForQuery(path)];
    results = performQueryOnDb(db, query);
    
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
    id remote = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                                   host: @""];

    if (remote) {
      NSConnection *c = [remote connectionForProxy];

	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(ddbdConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: c];
      
      ddbd = remote;
	    [ddbd setProtocolForProxy: @protocol(DDBdProtocol)];
      RETAIN (ddbd);
                                         
	  } else {
	    static BOOL recursion = NO;

      if (recursion == NO) {
        int i;
        
        for (i = 1; i <= 40; i++) {
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
                           
          remote = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                                     host: @""];                  
          if (remote) {
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

- (void)insertTrees
{
  NSArray *basePaths = [updinfo objectForKey: @"paths"];
  int i;

  for (i = 0; i < [basePaths count]; i++) {
    CREATE_AUTORELEASE_POOL(arp);
    NSString *base = [basePaths objectAtIndex: i];  
    NSDictionary *attributes = [fm fileAttributesAtPath: base traverseLink: NO];
    NSString *type = [attributes fileType];
    NSString *query;
    NSArray *results;

    if (type == NSFileTypeDirectory) {
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: base];
      IMP nxtImp = [enumerator methodForSelector: @selector(nextObject)];  
      NSString *path;    
        
      while ((path = (*nxtImp)(enumerator, @selector(nextObject))) != nil) {
        CREATE_AUTORELEASE_POOL(arp1);
        NSString *fullPath = [base stringByAppendingPathComponent: path];        

        if ([[enumerator fileAttributes] fileType] == NSFileTypeDirectory) {
          query = [NSString stringWithFormat: 
                      @"SELECT path FROM files WHERE path = '%@'", 
                                                  stringForQuery(fullPath)];
          results = performQueryOnDb(db, query);

          if ((results == nil) || ([results count] == 0)) {
            [ddbd insertPath: fullPath];
          }
        }
        
        DESTROY (arp1);
      }
      
      query = [NSString stringWithFormat: 
                  @"SELECT path FROM files WHERE path = '%@'", 
                                              stringForQuery(base)];
      results = performQueryOnDb(db, query);
    
      if ((results == nil) || ([results count] == 0)) {
        [ddbd insertPath: base];
      }
    } 
    
    DESTROY (arp);
  }
  
  [self done];
}

- (void)removeTrees
{
  NSArray *basePaths = [updinfo objectForKey: @"paths"];
  int i;
    
  for (i = 0; i < [basePaths count]; i++) {
    CREATE_AUTORELEASE_POOL(arp);
    NSString *path = stringForQuery([basePaths objectAtIndex: i]);  
    NSMutableString *query = [NSMutableString string];
    
    [query appendFormat: @"DELETE FROM files WHERE path = '%@'", path];
    
    if ([ddbd performWriteQuery: query] == NO) {
      NSLog(@"error accessing the Desktop database (-removeTrees)");
    }  
    
    query = (NSMutableString *)[NSMutableString string];
    [query appendFormat: @"DELETE FROM files WHERE path > '%@", path];
    
    if ([path isEqual: path_separator()] == NO) {
      [query appendString: path_separator()];
    }
    [query appendString: @"' "];
    
    if ([path isEqual: path_separator()] == NO) {
      [query appendFormat: @"AND path < '%@0' ", path];
    } else {
      [query appendString: @"AND path < '0' "];
    }
    
    if ([ddbd performWriteQuery: query] == NO) {
      NSLog(@"error accessing the Desktop database (-removeTrees)");
    }  
    
    DESTROY (arp);
  }
  
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
  NSMutableArray *pathsToRemove = [NSMutableArray array];
  NSMutableString *query;
  NSArray *results;
  BOOL copy, remove; 
  int i, j;
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    srcpaths = [NSArray arrayWithObject: source];
    dstpaths = [NSArray arrayWithObject: destination];
  } else {
    if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]
            || [operation isEqual: @"NSWorkspaceRecycleOperation"]) { 
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
    NSString *srcpath = [srcpaths objectAtIndex: i];
    NSString *dstpath = [dstpaths objectAtIndex: i];

    if (remove && ([fm fileExistsAtPath: srcpath] == NO)) {
      [pathsToRemove addObject: srcpath];
    }
    
    if (copy) {
      CREATE_AUTORELEASE_POOL(pool);
      NSDictionary *attrs = [fm fileAttributesAtPath: dstpath traverseLink: NO];

      query = (NSMutableString *)[NSMutableString string];
      [query appendFormat: @"SELECT path FROM files WHERE path = '%@'", 
                                                    stringForQuery(srcpath)];
      results = performQueryOnDb(db, query);

      if (results && [results count]) { 
        if ([ddbd setInfoOfPath: srcpath toPath: dstpath] == NO) {
          NSLog(@"updater: error at path: %@", dstpath);
          closedb(db);
           RELEASE (pool);
           RELEASE (arp);
          [self done];
        }
      } 

      if ([attrs fileType] == NSFileTypeDirectory) {
        query = [NSString stringWithFormat: 
                        @"SELECT path FROM files WHERE path GLOB '%@%@*'", 
                                      stringForQuery(srcpath), path_separator()];

        results = performQueryOnDb(db, query);

        if (results && [results count]) {                 
          for (j = 0; j < [results count]; j++) {
            NSDictionary *dict = [results objectAtIndex: j];
            NSData *data = [dict objectForKey: @"path"];      
            NSString *oldpath = [NSString stringWithUTF8String: [data bytes]];
            NSString *newpath;

            newpath = pathRemovingPrefix(oldpath, srcpath);
            newpath = [dstpath stringByAppendingPathComponent: newpath];

            if ([fm fileExistsAtPath: newpath]) {
              if ([ddbd setInfoOfPath: oldpath toPath: newpath] == NO) {
                NSLog(@"updater: error at path: %@", newpath);
                closedb(db);
                RELEASE (pool);
                RELEASE (arp);
                [self done];
              }
            }
          }
        }
      }

      RELEASE (pool);
    }
  }  
  
  if ([pathsToRemove count]) {
    [ddbd removeTreesFromPaths: [NSArchiver archivedDataWithRootObject: pathsToRemove]];
 
      // QUA !!!!!!!!!!!!!!!!
 
  }
  
  RELEASE (arp);

  [self done];
}

- (void)daylyUpdate
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableArray *toremove = [NSMutableArray array];
  const char *query = "SELECT path FROM files WHERE (pathExists(path) = 0)";
  struct sqlite3_stmt *stmt;
    
  if (sqlite3_prepare(db, query, strlen(query), &stmt, NULL)) {
    NSLog(@"sqlite3_prepare error");
    [self done];
  }

  while(sqlite3_step(stmt) == SQLITE_ROW) { 
    NSString *path = [NSString stringWithUTF8String: sqlite3_column_text(stmt, 0)];
    [toremove addObject: path];
  }
  
  sqlite3_finalize(stmt);

  if ([toremove count]) {
    int i;

    for (i = 0; i < [toremove count]; i++) {
      NSString *rmpath = [toremove objectAtIndex: i];

      if ([ddbd removePath: rmpath]) {
        NSLog(@"removing from db unexisting path: %@", rmpath);
      } else {
        NSLog(@"updater: error at path: %@", rmpath);
      }
    }
  }
  
  RELEASE (arp);
  [self done];
}

@end

