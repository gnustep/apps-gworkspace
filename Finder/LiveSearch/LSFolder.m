/* LSFolder.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
 *
 * This file is part of the GNUstep Finder application
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
#include "LSFolder.h"
#include "Finder.h"
#include "FinderModulesProtocol.h"
#include "Functions.h"
#include "config.h"

static NSString *nibName = @"LSFolderWindow";

BOOL isPathInResults(NSString *path, NSArray *results);

@implementation LSFolder

- (void)dealloc
{
  if (watcherSuspended == NO) {
    [finder removeWatcherForPath: [node path]];
  }
  RELEASE (node);
  RELEASE (searchPaths);
  RELEASE (searchCriteria);
  RELEASE (foundPaths);
  RELEASE (lastUpdate);
  TEST_RELEASE (fullCheckModules);
  TEST_RELEASE (dbCheckModules);
         
  [super dealloc];
}

- (id)initForNode:(FSNode *)anode
     contentsInfo:(NSDictionary *)info
{
	self = [super init];

  if (self) {
    ASSIGN (node, anode);

    foundPaths = [NSMutableArray new];
    [foundPaths addObjectsFromArray: [info objectForKey: @"foundpaths"]];
    searchPaths = [[info objectForKey: @"searchpaths"] mutableCopy];
    ASSIGN (searchCriteria, [info objectForKey: @"criteria"]);
    ASSIGN (lastUpdate, [NSDate dateWithString: [info objectForKey: @"lastupdate"]]);
        
    finder = [Finder finder];
    [finder addWatcherForPath: [node path]];
    watcherSuspended = NO;
    fm = [NSFileManager defaultManager];
  }
  
	return self;
}

- (void)setNode:(FSNode *)anode
{
  if (watcherSuspended == NO) {
    [finder removeWatcherForPath: [node path]];
  }
  ASSIGN (node, anode);
  [finder addWatcherForPath: [node path]];
}

- (FSNode *)node
{
  return node;
}

- (BOOL)watcherSuspended
{
  return watcherSuspended;
}

- (void)setWatcherSuspended:(BOOL)value
{
  watcherSuspended = value;
}


- (void)update
{
  int count = [searchPaths count];
  int i;

  [self loadModules];
  
  NSLog(@"QUA 0");
  
  [self checkFoundPaths];
        
  for (i = 0; i < count; i++) {
    NSString *spath = [searchPaths objectAtIndex: i];
    
    if ([fm fileExistsAtPath: spath]) {
      [self searchInSearchPath: spath];
    } else {
      [searchPaths removeObjectAtIndex: i];
      count--;
      i--;
    }
  }
  
  NSLog(@"END");
    
  if ([searchPaths count]) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [dict setObject: searchPaths forKey: @"searchpaths"];	
    [dict setObject: searchCriteria forKey: @"criteria"];	
    [dict setObject: foundPaths forKey: @"foundpaths"];	
    ASSIGN (lastUpdate, [NSDate date]);
    [dict setObject: [lastUpdate description] forKey: @"lastupdate"];	


    if ([dict writeToFile: [node path] atomically: YES] == NO) {
      // BUBA!!!!!!!!!
    }
    
  } else {
    // RIMUOVERE IL FILE
    // AVVISARE IL FINDER
    // ECC.
  }  
}
         
- (void)loadModules
{
  if (fullCheckModules == nil) {
    NSArray *classNames = [searchCriteria allKeys];
    int i;
    
    fullCheckModules = [NSMutableArray new];
    dbCheckModules = [NSMutableArray new];

    for (i = 0; i < [classNames count]; i++) {
      NSString *className = [classNames objectAtIndex: i];
      NSDictionary *moduleCriteria = [searchCriteria objectForKey: className];
      Class moduleClass = NSClassFromString(className);
      id module = [[moduleClass alloc] initWithSearchCriteria: moduleCriteria];

      if ([module needsFullCheck]) {
        [fullCheckModules addObject: module];
      } else {
        [dbCheckModules addObject: module];
      }

      RELEASE (module);  
    }
  } 
}

- (void)checkFoundPaths
{
  NSMutableArray *toremove = [NSMutableArray array];
  int count = [foundPaths count];
  int i;

  for (i = 0; i < count; i++) {
    NSString *path = [foundPaths objectAtIndex: i];
    NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];   
    BOOL remove = NO;
    
    if (attributes == nil) {
      [toremove addObject: path];
      remove = YES;
      
    } else {
      NSDate *lastmod = [attributes fileModificationDate];
      
      if ([lastmod laterDate: lastUpdate] == lastmod) {
        [finder ddbdSetModificationDate: [lastmod description] 
                                forPath: path];
                                
        if ([dbCheckModules count]) {
          if ([self checkPath: path withModules: dbCheckModules] == NO) {        
            remove = YES;
          }
        }
      }
      
      if ([fullCheckModules count] && (remove == NO)) {
        remove = ([self checkPath: path withModules: fullCheckModules] == NO);
      }
    }

    if (remove) {
   //   NSLog(@"removing %@ from the found paths", path);
    
      [foundPaths removeObjectAtIndex: i];
      count--;
      i--;
    }
  }
  
  if ([toremove count]) {
    [finder ddbdRemovePaths: toremove];  // MARE LENTEZZA QUA !!!!!!!!
  }
}

- (void)searchInSearchPath:(NSString *)srcpath
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *pathInfo = [NSMutableDictionary dictionary];
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSArray *results;

  [pathInfo setObject: srcpath forKey: @"path"];
  [pathInfo setObject: [NSArray arrayWithObject: @"path"] forKey: @"columns"];

  [dict setObject: @"type" forKey: @"type"];
  [dict setObject: @"=" forKey: @"operator"];
  [dict setObject: @"NSFileTypeDirectory" forKey: @"arg"];
  [pathInfo setObject: [NSArray arrayWithObject: dict] forKey: @"criteria"];

  NSLog(@"QUA 1");

  results = [finder ddbdGetTreeFromPath: pathInfo];
  
  NSLog(@"QUA 2");
  
  if (results) {  
    NSMutableArray *toinsert = [NSMutableArray array];
    NSMutableArray *toremove = [NSMutableArray array];
    int i;
    
    for (i = 0; i < [results count]; i++) {
      CREATE_AUTORELEASE_POOL(arp1);
      NSDictionary *entry = [results objectAtIndex: i];
      NSData *pathdata = [entry objectForKey: @"path"];
      NSString *dbpath = [NSString stringWithUTF8String: [pathdata bytes]];
      NSDictionary *attributes = [fm fileAttributesAtPath: dbpath traverseLink: NO];

      if (attributes) {  
        NSDate *moddate = [attributes fileModificationDate];
        
        if ([moddate laterDate: lastUpdate] == moddate) {
          NSArray *contents = [fm directoryContentsAtPath: dbpath];
          int j;

     //     NSLog(@"found changed dir at %@", dbpath);
          
          [self check: dbpath];
          
          for (j = 0; j < [contents count]; j++) {
            CREATE_AUTORELEASE_POOL(arp2);
            NSString *fname = [contents objectAtIndex: j];
            NSString *fpath = [dbpath stringByAppendingPathComponent: fname];
            NSDictionary *attr = [fm fileAttributesAtPath: fpath traverseLink: NO];
            NSString *type = [attr fileType];
            NSDate *lastmod = [attr fileModificationDate];
                        
            if (type == NSFileTypeDirectory) { 
              NSArray *founds = [self fullSearchInDirectory: fpath];

        //      NSLog(@"adding %i elements from %@", [founds count], fpath);

              [foundPaths addObjectsFromArray: founds];
              
              [self insertShorterPath: fpath inArray: toinsert];
              
              [self check: fpath];

            } else {
              
              [self check: fpath];
            }
            
            if ([lastmod laterDate: lastUpdate] == lastmod) {
              [finder ddbdSetModificationDate: [lastmod description] 
                                      forPath: fpath];
            }
            
            RELEASE (arp2);
          }
          
          [finder ddbdSetModificationDate: [moddate description] 
                                  forPath: dbpath];
        }
        
      } else {
   //     NSLog(@"%@ doesn't exist - removing from the db", dbpath);
        [self insertShorterPath: dbpath inArray: toremove];
      }
      
      RELEASE (arp1);
    }
     
    for (i = 0; i < [toinsert count]; i++) { 
 //     NSLog(@"INSERT INTO DB %@", [toinsert objectAtIndex: i]);
    } 
    
    if ([toinsert count]) {
      [finder ddbdInsertTreesFromPaths: toinsert];
    }

    for (i = 0; i < [toremove count]; i++) { 
//      NSLog(@"REMOVE FROM DB %@", [toremove objectAtIndex: i]);
    } 
    
    if ([toremove count]) {
      [finder ddbdRemoveTreesFromPaths: toremove];  
    }
       
  } else {
    NSLog(@"%@ not found in the db", srcpath);
    NSLog(@"performing full search at %@", srcpath);
  
    NSArray *founds = [self fullSearchInDirectory: srcpath];
    
    [foundPaths addObjectsFromArray: founds];
    [finder ddbdInsertTreesFromPaths: [NSArray arrayWithObject: srcpath]];
  }
  
  NSLog(@"QUA 3");
  RELEASE (arp);
}

- (NSArray *)fullSearchInDirectory:(NSString *)dirpath
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableArray *founds = [NSMutableArray array];
  NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: dirpath];
  IMP nxtImp = [enumerator methodForSelector: @selector(nextObject)];    
  NSString *path;

  while ((path = (*nxtImp)(enumerator, @selector(nextObject))) != nil) { 
    CREATE_AUTORELEASE_POOL(arp1); 
    NSString *fullPath = [dirpath stringByAppendingPathComponent: path];
    BOOL found;
    
    found = [self checkPath: fullPath withModules: fullCheckModules];
    
    if (found) {
      found = [self checkPath: fullPath withModules: dbCheckModules];
    }

    if (found) {
      [founds addObject: fullPath];
    }
    
    RELEASE (arp1);
  }
  
  RETAIN (founds);
  
  RELEASE (arp);
      
  return AUTORELEASE (founds);
}

- (void)check:(NSString *)path
{
  if ([foundPaths containsObject: path] == NO) {
    BOOL found = [self checkPath: path withModules: fullCheckModules];

    if (found) {
      found = [self checkPath: path withModules: dbCheckModules];
    }

    if (found) {
      [foundPaths addObject: path];
      
  //    NSLog(@"adding %@ to the found paths", path);      
    }
  }
}

- (BOOL)checkPath:(NSString *)path 
      withModules:(NSArray *)modules
{
  BOOL found = YES;
  int i;

  for (i = 0; i < [modules count]; i++) {
    found = [[modules objectAtIndex: i] checkPath: path];
    if (found == NO) {
      break;
    }
  }
  
  return found;  
}

- (void)insertShorterPath:(NSString *)path 
                  inArray:(NSMutableArray *)array
{
  int count = [array count];
  int i;

  for (i = 0; i < [array count]; i++) {
    NSString *str = [array objectAtIndex: i];

    if (subPathOfPath(path, str) || [path isEqual: str]) {
      [array removeObjectAtIndex: i];
      count--;
      i--;
    }
  }
  
  [array addObject: path];
}

@end


BOOL isPathInResults(NSString *path, NSArray *results)
{
  int i;

  for (i = 0; i < [results count]; i++) {
    NSData *pdata = [[results objectAtIndex: i] objectForKey: @"path"];
 
    if (strcmp([pdata bytes], [path UTF8String]) == 0) {
      return YES;
    }
  }
  
  return NO;
}              










