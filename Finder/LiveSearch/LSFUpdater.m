/* LSFUpdater.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2004
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

#include <AppKit/AppKit.h>
#include "LSFUpdater.h"
#include "FinderModulesProtocol.h"
#include "Functions.h"

@implementation LSFUpdater

- (void)dealloc
{
  DESTROY (ddbd);
  RELEASE (searchPaths);
  RELEASE (searchCriteria);
  RELEASE (foundPaths);
  RELEASE (lastUpdate);
  RELEASE (modules);
  
	[super dealloc];
}

+ (void)newUpdater:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL(arp);
  NSArray *ports = [info objectForKey: @"ports"];
  NSConnection *conn;
  LSFUpdater *updater;
                              
  conn = [NSConnection connectionWithReceivePort: [ports objectAtIndex: 0]
                                        sendPort: [ports objectAtIndex: 1]];
  updater = [[self alloc] initWithLSFolderInfo: info];
  [updater connectDDBd]; 
  [(id)[conn rootProxy] setUpdater: updater];
  RELEASE (updater);
                              
  [[NSRunLoop currentRunLoop] run];
  RELEASE (arp);
}

- (id)initWithLSFolderInfo:(NSDictionary *)info
{
  self = [super init];
  
  if (self) {
    NSArray *ports = [info objectForKey: @"ports"];
    NSDictionary *lsfinfo = [info objectForKey: @"lsfinfo"];
    id entry = [lsfinfo objectForKey: @"autoupdate"];
    NSArray *classNames;
    NSConnection *conn;
    id anObject;
    int i;
  
    conn = [NSConnection connectionWithReceivePort: [ports objectAtIndex: 0]
                                          sendPort: [ports objectAtIndex: 1]];
    anObject = (id)[conn rootProxy];
    [anObject setProtocolForProxy: @protocol(LSFolderProtocol)];
    lsfolder = (id <LSFolderProtocol>)anObject;

    searchPaths = [[lsfinfo objectForKey: @"searchpaths"] mutableCopy];
    ASSIGN (searchCriteria, [lsfinfo objectForKey: @"criteria"]);
    ASSIGN (lastUpdate, [NSDate dateWithString: [lsfinfo objectForKey: @"lastupdate"]]);
    foundPaths = [NSMutableArray new];
    
    modules = [NSMutableArray new];
    classNames = [searchCriteria allKeys];

    for (i = 0; i < [classNames count]; i++) {
      NSString *className = [classNames objectAtIndex: i];
      NSDictionary *moduleCriteria = [searchCriteria objectForKey: className];
      Class moduleClass = NSClassFromString(className);
      id module = [[moduleClass alloc] initWithSearchCriteria: moduleCriteria];

      [modules addObject: module];
      RELEASE (module); 
    }
  
    if (entry) {
      autoupdate = [entry boolValue];
    }
  
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    ddbd = nil;
    ddbdactive = NO;
  }
  
  return self;
}

- (id)init
{
  self = [super init];
  
  if (self) {
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    ddbd = nil;
    ddbdactive = NO;
  }
  
  return self;
}

- (void)notifyEndAction:(id)sender
{
  if (lsfolder) {
    [lsfolder updaterDidEndAction];
  }
}

- (void)exitThread
{
  [NSThread exit];
}

- (void)setAutoupdate:(BOOL)value
{
  NSString *infopath = [lsfolder infoPath];
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: infopath];
    
  if (dict) {
    NSMutableDictionary *updated = [dict mutableCopy];
    [updated setObject: [NSNumber numberWithBool: value] 
                forKey: @"autoupdate"];	
    [updated writeToFile: infopath atomically: YES];
  }
  
  autoupdate = value;
}




- (void)fastUpdate
{
  int count = [searchPaths count];
  BOOL lsfdone = YES;
  int i;

  NSLog(@"QUA -1");

  [self getFoundPaths];

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
    ASSIGN (lastUpdate, [NSDate date]);
    [dict setObject: [lastUpdate description] forKey: @"lastupdate"];	
    [dict setObject: [NSNumber numberWithBool: autoupdate] 
             forKey: @"autoupdate"];	

    lsfdone = [dict writeToFile: [lsfolder infoPath] atomically: YES];
    lsfdone = [foundPaths writeToFile: [lsfolder foundPath] atomically: YES];
  } else {
    lsfdone = NO;
  }  

  if (lsfdone == NO) {
  
  
    NSLog(@"AAAAAAAAARRRRRRRRRRRGGGGGGGGGGGGGGG!!!!!!!!");

    // RIMUOVERE IL FILE
    // AVVISARE IL FINDER
    // ECC.
  }

//  [self endUpdate];

  [self notifyEndAction: nil];
}

- (void)getFoundPaths
{
  NSString *fpath = [lsfolder foundPath];

  [foundPaths removeAllObjects];

  if ([fm fileExistsAtPath: fpath]) {
    NSArray *founds = [NSArray arrayWithContentsOfFile: fpath];

    if (founds) {
      [foundPaths addObjectsFromArray: founds];

      NSLog(@"getFoundPaths: %i found", [foundPaths count]);
    } else {
      NSLog(@"NO FOUNDPATS FOUND!!!");
    }
  } else {
    NSLog(@"NO FOUNDPATS FOUND!!!");
  }
}

- (void)checkFoundPaths
{
  int count = [foundPaths count];
  int i;
  
  NSLog(@"%i foundPaths", count);
    
  for (i = 0; i < count; i++) {
    NSString *path = [foundPaths objectAtIndex: i];
    NSDictionary *attrs = [fm fileAttributesAtPath: path traverseLink: NO];   
    BOOL remove = NO;
    
    if (attrs) {
      remove = ([self checkPath: path attributes: attrs fullCheck: YES] == NO);
    } else {
      remove = YES;
    }

    if (remove) {
      [foundPaths removeObjectAtIndex: i];
      count--;
      i--;
    } else {
      [lsfolder addFoundPath: path];
    }
  }
}

- (void)searchInSearchPath:(NSString *)srcpath
{
  CREATE_AUTORELEASE_POOL(arp);
          NSLog(@"QUA 1");
  NSArray *results = [self ddbdGetDirectoryTreeFromPath: srcpath];
  
  NSLog(@"QUA 2");
  
  if (results && [foundPaths count]) {
    NSMutableArray *toinsert = [NSMutableArray array];
    int count = [results count];
    int i;
    
    results = [results arrayByAddingObject: srcpath];
    
    for (i = 0; i <= count; i++) {
      CREATE_AUTORELEASE_POOL(arp1);
      NSString *dbpath = [results objectAtIndex: i];
      NSDictionary *attributes = [fm fileAttributesAtPath: dbpath traverseLink: NO];
      NSDate *moddate = [attributes fileModificationDate];


      if ([dbpath isEqual: @"/home/enrico/Butt/GNUstep/Pixmaps/CartaNuova/CooopyPix/CVS/Startup/config/CVS"]) {
        NSLog(@"TROVATA!!!!!!!!!!!!!!!!!!!!!!!");
      }
            
      
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

          if ((type == NSFileTypeDirectory) 
                                && ([results containsObject: fpath] == NO)) { 
            NSArray *founds = [self fullSearchInDirectory: fpath];

      //      NSLog(@"adding %i elements from %@", [founds count], fpath);

            [foundPaths addObjectsFromArray: founds];

            [self insertShorterPath: fpath inArray: toinsert];

            [self check: fpath];

          } else {
            [self check: fpath];
          }

          RELEASE (arp2);
        }
      }
      
      RELEASE (arp1);
    }
     
    if ([toinsert count]) {
      [self ddbdInsertDirectoryTreesFromPaths: toinsert];
    }

  } else {
    NSArray *founds;
    
    if (results == nil) {
      NSLog(@"%@ not found in the db", srcpath);
    } else {
      NSLog(@"no found paths");
    }
    NSLog(@"performing full search at %@", srcpath);
  
    founds = [self fullSearchInDirectory: srcpath];
    
    [foundPaths addObjectsFromArray: founds];
    [self ddbdInsertDirectoryTreesFromPaths: [NSArray arrayWithObject: srcpath]];
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
    NSDictionary *attrs = [enumerator fileAttributes];
    
    if ([self checkPath: fullPath attributes: attrs fullCheck: YES]) {    
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
    NSDictionary *attrs = [fm fileAttributesAtPath: path traverseLink: NO];

    if ([self checkPath: path attributes: attrs fullCheck: YES]) {
      [foundPaths addObject: path];
      
      if (lsfolder) {
        [lsfolder addFoundPath: path];
      }
      
  //    NSLog(@"adding %@ to the found paths", path);      
    }
  }
}

- (BOOL)checkPath:(NSString *)path 
       attributes:(NSDictionary *)attrs
        fullCheck:(BOOL)fullck
{
  BOOL found = YES;
  int i;

  for (i = 0; i < [modules count]; i++) {
    id module = [modules objectAtIndex: i];
      
    if (fullck == NO) {
      if ([module reliesOnDirModDate]) {
        found = [self checkPath: path attributes: attrs withModule: module];       
      } else {
        found = NO;
      }
    } else {
      found = [self checkPath: path attributes: attrs withModule: module];
    }
  
    if (found == NO) {
      break;
    }
  }
  
  return ([modules count] == 0) ? NO : found;  
}

- (BOOL)checkPath:(NSString *)path 
       attributes:(NSDictionary *)attrs
       withModule:(id)module
{
  if ([module reliesOnModDate]) {
    NSDate *lastmod = [attrs fileModificationDate];

    if ([lastmod laterDate: lastUpdate] == lastmod) {
      return [module checkPath: path withAttributes: attrs];
    } else {
      return [foundPaths containsObject: path];
    }

  } else {
    return [module checkPath: path withAttributes: attrs];
  }
  
  return NO;
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




















- (void)ddbdInsertTrees
{
  [self connectDDBd];
  if (ddbdactive) {
    NSData *info = [NSArchiver archivedDataWithRootObject: searchPaths];
    
    [NSTimer scheduledTimerWithTimeInterval: 10
                                     target: self 
                                   selector: @selector(notifyEndAction:) 
                                   userInfo: nil 
                                    repeats: NO];
                                    
    [ddbd insertDirectoryTreesFromPaths: info];
  }
}

- (void)ddbdInsertDirectoryTreesFromPaths:(NSArray *)paths
{
  [self connectDDBd];
  if (ddbdactive) {
    NSData *info = [NSArchiver archivedDataWithRootObject: paths];
    [ddbd insertDirectoryTreesFromPaths: info];
  }
}

- (NSArray *)ddbdGetDirectoryTreeFromPath:(NSString *)path
{
  [self connectDDBd];
  if (ddbdactive) {
    NSData *data = [ddbd directoryTreeFromPath: path];  

    if (data) {
      return [NSUnarchiver unarchiveObjectWithData: data];
    }
  }
  
  return nil;
}

- (void)ddbdRemoveTreesFromPaths:(NSArray *)paths
{
  [self connectDDBd];
  if (ddbdactive) {
    [ddbd removeTreesFromPaths: [NSArchiver archivedDataWithRootObject: paths]];
  }
}

- (void)connectDDBd
{
  if (ddbd == nil) {
    id db = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                              host: @""];

    if (db) {
      NSConnection *c = [db connectionForProxy];

	    [nc addObserver: self
	           selector: @selector(ddbdConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: c];
      
      ddbd = db;
	    [ddbd setProtocolForProxy: @protocol(DDBd)];
      RETAIN (ddbd);
      ddbdactive = [ddbd dbactive];
      
      NSLog(@"ddbd connected!");
      
                                         
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
            cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"ddbd"]);
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        DESTROY (cmd);
        
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
        DESTROY (cmd);
	      recursion = NO;
        ddbdactive = NO;
        
        NSLog(@"unable to contact ddbd.");
        // [lsfolder dbError: @"sdfsdfsdf"];
      }
	  }
  }
}

- (void)ddbdConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  NSAssert(connection == [ddbd connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (ddbd);
  ddbd = nil;
  ddbdactive = NO;
  
  // [lsfolder dbError: @"sdfsdfsdf"];
}

@end


