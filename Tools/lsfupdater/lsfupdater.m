/* lsfupdater.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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
#include "FinderModulesProtocol.h"

#define gw_debug 1

#define GWDebugLog(format, args...) \
  do { if (gw_debug) \
    NSLog(format , ## args); } while (0)

BOOL subPathOfPath(NSString *p1, NSString *p2);

@protocol LSFolderProtocol

- (oneway void)setUpdater:(id)anObject;
- (oneway void)updaterDidEndAction;
- (oneway void)updaterError:(NSString *)err;
- (oneway void)addFoundPath:(NSString *)path;
- (oneway void)removeFoundPath:(NSString *)path;
- (oneway void)clearFoundPaths;
- (NSString *)infoPath;
- (NSString *)foundPath;
- (BOOL)isOpen;
                          
@end


@protocol	DDBd

- (BOOL)dbactive;
- (oneway void)insertPath:(NSString *)path;
- (oneway void)insertDirectoryTreesFromPaths:(NSData *)info;
- (oneway void)removeTreesFromPaths:(NSData *)info;
- (NSData *)directoryTreeFromPath:(NSString *)path;
- (NSString *)annotationsForPath:(NSString *)path;
- (NSTimeInterval)timestampOfPath:(NSString *)path;

@end


@interface LSFUpdater: NSObject
{
  NSMutableArray *searchPaths;
  unsigned spathindex;
  
  NSMutableArray *directories;
  unsigned dirindex;
  unsigned dircounter;
  unsigned dircount;

  NSMutableArray *modules;  
  BOOL metadataModule;
  NSDictionary *searchCriteria;
  BOOL newcriteria;
  
  NSMutableArray *foundPaths;
  int fpathindex;
  
  NSDate *lastUpdate;
  NSDate *startSearch;
  unsigned autoupdate;
  NSTimeInterval updateInterval;
  NSTimer *autoupdateTmr;
  
  id lsfolder;
  id ddbd;
  NSFileManager *fm;
  NSNotificationCenter *nc;
}

- (id)initWithConnectionName:(NSString *)cname;
- (void)connectionDidDie:(NSNotification *)notification;
- (void)setFolderInfo:(NSData *)data;
- (void)updateSearchCriteria:(NSData *)data;
- (void)loadModules;
- (NSArray *)bundlesWithExtension:(NSString *)extension 
													 inPath:(NSString *)path;

- (void)setAutoupdate:(unsigned)value;
- (void)resetTimer;
- (void)notifyEndAction:(id)sender;
- (void)terminate;
- (void)fastUpdate;
- (void)getFoundPaths;
- (void)checkFoundPaths;
- (void)updateSearchPath:(NSString *)srcpath;
- (BOOL)saveResults;
- (NSArray *)fullSearchInDirectory:(NSString *)dirpath;
- (BOOL)checkPath:(NSString *)path;
- (BOOL)checkPath:(NSString *)path 
       attributes:(NSDictionary *)attrs;
- (BOOL)checkPath:(NSString *)path 
       attributes:(NSDictionary *)attrs
       withModule:(id)module;
- (void)insertShorterPath:(NSString *)path 
                  inArray:(NSMutableArray *)array;

@end


@interface LSFUpdater (ddbd)

- (void)connectDDBd;
- (void)ddbdConnectionDidDie:(NSNotification *)notif;
- (void)ddbdInsertTrees;
- (void)ddbdInsertDirectoryTreesFromPaths:(NSArray *)paths;
- (NSArray *)ddbdGetDirectoryTreeFromPath:(NSString *)path;
- (void)ddbdRemoveTreesFromPaths:(NSArray *)paths;
- (NSString *)ddbdGetAnnotationsForPath:(NSString *)path;
- (NSTimeInterval)ddbdGetTimestampOfPath:(NSString *)path;

@end


@interface LSFUpdater (scheduled)

- (void)searchInNextDirectory:(id)sender;
- (void)checkNextFoundPath;

@end


@implementation	LSFUpdater

- (void)dealloc
{
  [nc removeObserver: self];
  
  if (autoupdateTmr && [autoupdateTmr isValid]) {
    [autoupdateTmr invalidate];
    DESTROY (autoupdateTmr);
  }
  
	DESTROY (lsfolder);
  DESTROY (ddbd);

  RELEASE (modules);
  TEST_RELEASE (searchPaths);
  TEST_RELEASE (searchCriteria);
  TEST_RELEASE (lastUpdate);
  TEST_RELEASE (startSearch);
  RELEASE (foundPaths);
  TEST_RELEASE (directories);
  
  [super dealloc];
}

- (id)initWithConnectionName:(NSString *)cname
{
  self = [super init];
  
  if (self) {
    NSConnection *conn;
    id anObject;

    fm = [NSFileManager defaultManager];    
    nc = [NSNotificationCenter defaultCenter];
    lsfolder = nil;
    ddbd = nil;

    modules = [NSMutableArray new];
    searchPaths = nil;
    searchCriteria = nil;
    lastUpdate = nil;
    startSearch = nil;
    foundPaths = [NSMutableArray new];
    directories = nil;

    autoupdateTmr = nil;
    autoupdate = 0;
    updateInterval = 0.0;
    fpathindex = 0;
    spathindex = 0;
    dirindex = 0;
    dircounter = 0;
    dircount = 0;
    
    conn = [NSConnection connectionWithRegisteredName: cname host: nil];

    if (conn == nil) {
      NSLog(@"failed to contact the lsfolder - bye.");
      DESTROY (self);
      return self;
    } 

    [nc addObserver: self
           selector: @selector(connectionDidDie:)
               name: NSConnectionDidDieNotification
             object: conn];    

    anObject = [conn rootProxy];
    [anObject setProtocolForProxy: @protocol(LSFolderProtocol)];
    lsfolder = (id <LSFolderProtocol>)anObject;
    RETAIN (lsfolder);

    [lsfolder setUpdater: self];
  }
  
  return self;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: [notification object]];
  NSLog(@"the lsfolder connection has been destroyed.");
  [self terminate];
}

- (void)setFolderInfo:(NSData *)data
{
  NSDictionary *lsfinfo = [NSUnarchiver unarchiveObjectWithData: data];

  searchPaths = [[lsfinfo objectForKey: @"searchpaths"] mutableCopy];
  ASSIGN (searchCriteria, [lsfinfo objectForKey: @"criteria"]);
  ASSIGN (lastUpdate, [NSDate dateWithString: [lsfinfo objectForKey: @"lastupdate"]]);
  [self loadModules];
}

- (void)updateSearchCriteria:(NSData *)data
{
  ASSIGN (searchCriteria, [NSUnarchiver unarchiveObjectWithData: data]);
  [self loadModules];
  
  newcriteria = YES;
  
  if (autoupdate != 0) {
    fpathindex = 0;
    spathindex = 0;
    dirindex = 0;
    dircounter = 0;
  }
}

- (void)loadModules
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *bundlesDir;
  BOOL isdir;
  NSMutableArray *bundlesPaths;
  NSArray *classNames;
  int i;

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  bundlesPaths = [NSMutableArray array];
  [bundlesPaths addObjectsFromArray: [self bundlesWithExtension: @"finder" 
                                                         inPath: bundlesDir]];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"GWorkspace"];

  if ([fm fileExistsAtPath: bundlesDir isDirectory: &isdir] && isdir) {
    [bundlesPaths addObjectsFromArray: [self bundlesWithExtension: @"finder" 
                                                           inPath: bundlesDir]];
  }

  [modules removeAllObjects];
  classNames = [searchCriteria allKeys];
  
  metadataModule = NO;
  
  for (i = 0; i < [bundlesPaths count]; i++) {
    NSString *bpath = [bundlesPaths objectAtIndex: i];
    NSBundle *bundle = [NSBundle bundleWithPath: bpath];
     
    if (bundle) {
			Class principalClass = [bundle principalClass];
      NSString *className = NSStringFromClass(principalClass);

      if ([classNames containsObject: className]) {
        NSDictionary *moduleCriteria = [searchCriteria objectForKey: className];
        id module = [[principalClass alloc] initWithSearchCriteria: moduleCriteria
                                                        searchTool: self];

        if ([module metadataModule]) {
          metadataModule = YES;
        }
        
        [modules addObject: module];
        RELEASE (module);  
      }
    }
  }

  RELEASE (arp);
}

- (NSArray *)bundlesWithExtension:(NSString *)extension 
													 inPath:(NSString *)path
{
  NSMutableArray *bundleList = [NSMutableArray array];
  NSEnumerator *enumerator;
  NSString *dir;
  BOOL isDir;
  
  if ((([fm fileExistsAtPath: path isDirectory: &isDir]) && isDir) == NO) {
		return nil;
  }
	  
  enumerator = [[fm directoryContentsAtPath: path] objectEnumerator];
  while ((dir = [enumerator nextObject])) {
    if ([[dir pathExtension] isEqualToString: extension]) {
			[bundleList addObject: [path stringByAppendingPathComponent: dir]];
		}
  }
  
  return bundleList;
}

- (void)setAutoupdate:(unsigned)value
{
  NSString *infopath = [lsfolder infoPath];
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: infopath];
  
  GWDebugLog(@"setAutoupdate %i", value);  

  autoupdate = value;
  
  if (autoupdate == 0) {
    fpathindex = 0;
    spathindex = 0;
    dirindex = 0;
    dircounter = 0;
  }

  if (dict) {
    NSMutableDictionary *updated = [dict mutableCopy];
    
    if (dircount == 0) {
      id countnmb = [dict objectForKey: @"dircount"];
    
      if (countnmb) {
        dircount = [countnmb unsignedLongValue];
      }
    }
    
    [updated setObject: [NSNumber numberWithLong: autoupdate] 
                forKey: @"autoupdate"];	
    [updated writeToFile: infopath atomically: YES];
    RELEASE (updated);
  }

  if (autoupdateTmr && [autoupdateTmr isValid]) {
    [autoupdateTmr invalidate];
    DESTROY (autoupdateTmr);
    GWDebugLog(@"removing autoupdateTmr");
  }
  
  if (autoupdate > 0) {
    NSTimeInterval interval;
    
    if ([foundPaths count] == 0) {
      [self getFoundPaths];
    }

    if (dircount > 0) {
      unsigned fcount = [foundPaths count];
      unsigned count = (fcount > dircount) ? fcount : dircount;
      updateInterval = (autoupdate * 1.0) / count;
    }

    interval = (updateInterval == 0) ? 0.1 : updateInterval;
    
    autoupdateTmr = [NSTimer scheduledTimerWithTimeInterval: interval
                               target: self 
                             selector: @selector(searchInNextDirectory:) 
                             userInfo: nil 
                              repeats: YES];
    RETAIN (autoupdateTmr);
  } 
}

- (void)resetTimer
{
  if (autoupdateTmr && [autoupdateTmr isValid]) {
    [autoupdateTmr invalidate];
    DESTROY (autoupdateTmr);
  }

  if (autoupdate > 0) {
    unsigned fcount = [foundPaths count];
    unsigned count = (fcount > dircount) ? fcount : dircount;
    NSTimeInterval interval;

    updateInterval = (autoupdate * 1.0) / count;
    interval = (updateInterval == 0) ? 0.1 : updateInterval;

    GWDebugLog(@"\nresetTimer");
    GWDebugLog(@"autoupdate %i", autoupdate);
    GWDebugLog(@"dircount %i", dircount);  
    GWDebugLog(@"updateInterval %.2f", updateInterval);

    autoupdateTmr = [NSTimer scheduledTimerWithTimeInterval: interval
                               target: self 
                             selector: @selector(searchInNextDirectory:) 
                             userInfo: nil 
                              repeats: YES];
    RETAIN (autoupdateTmr);
  }
}

- (void)notifyEndAction:(id)sender
{
  if (lsfolder) {
    [lsfolder updaterDidEndAction];
  }
}

- (void)terminate
{
  if (autoupdateTmr && [autoupdateTmr isValid]) {
    [autoupdateTmr invalidate];
    DESTROY (autoupdateTmr);
  }
  
  [nc removeObserver: self];
  DESTROY (ddbd);
  exit(0);
}

- (void)fastUpdate
{
  int count = [searchPaths count];
  BOOL lsfdone = YES;
  int i;

  GWDebugLog(@"starting fast update");

  [self getFoundPaths];

  GWDebugLog(@"got %i found paths. checking...", [foundPaths count]);
  
  [self checkFoundPaths];
  
  for (i = 0; i < count; i++) {
    NSString *spath = [searchPaths objectAtIndex: i];
    BOOL isdir;
    
    if ([fm fileExistsAtPath: spath isDirectory: &isdir]) {
      if (isdir) {
        [self updateSearchPath: spath];
      } else if ([self checkPath: spath]
                      && ([foundPaths containsObject: spath] == NO)) {
        [foundPaths addObject: spath];
        [lsfolder addFoundPath: spath];
      }
    } else {
      [searchPaths removeObjectAtIndex: i];
      count--;
      i--;
    }
  }
    
  GWDebugLog(@"fast update done.");  

  if ([searchPaths count]) {
    ASSIGN (lastUpdate, [NSDate date]);
    lsfdone = [self saveResults];
  } else {
    lsfdone = NO;
  }  

  if (lsfdone == NO) {
    [lsfolder updaterError: NSLocalizedString(@"cannot save the folder!", @"")];
  }

  newcriteria = NO;

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
    } 
  }
}

- (void)checkFoundPaths
{
  int count = [foundPaths count];
  int i;
    
  for (i = 0; i < count; i++) {
    NSString *path = [foundPaths objectAtIndex: i];
    NSDictionary *attrs = [fm fileAttributesAtPath: path traverseLink: NO];   
    BOOL remove = NO;
    
    if (attrs) {
      remove = ([self checkPath: path attributes: attrs] == NO);
    } else {
      remove = YES;
    }

    if (remove) {
      [lsfolder removeFoundPath: path];
      [foundPaths removeObjectAtIndex: i];
      count--;
      i--;
    } else {
      [lsfolder addFoundPath: path];
    }
  }
}

- (void)updateSearchPath:(NSString *)srcpath
{
  CREATE_AUTORELEASE_POOL(arp);
  NSArray *results;
  
  GWDebugLog(@"getting directories from the db...");
  
  results = [self ddbdGetDirectoryTreeFromPath: srcpath];
  
  if (results && [foundPaths count]) {
    NSMutableArray *toinsert = [NSMutableArray array];
    unsigned count = [results count];
    unsigned i;
        
    results = [results arrayByAddingObject: srcpath];

    GWDebugLog(@"%i directories", [results count]);
    GWDebugLog(@"updating in %@", srcpath);    
    
    for (i = 0; i <= count; i++) {
      CREATE_AUTORELEASE_POOL(arp1);
      NSString *dbpath = [results objectAtIndex: i];
      NSDictionary *attributes = [fm fileAttributesAtPath: dbpath traverseLink: NO];
      NSDate *moddate = [attributes fileModificationDate];
      BOOL mustcheck;
      
      mustcheck = (([moddate laterDate: lastUpdate] == moddate) || newcriteria);
      
      if ((mustcheck == NO) && metadataModule) {
        NSTimeInterval interval = [lastUpdate timeIntervalSinceReferenceDate];
        mustcheck = ([self ddbdGetTimestampOfPath: dbpath] > interval);      
        if (mustcheck) {
          GWDebugLog(@"metadata modification date changed at %@", dbpath);
        }
      }
      
      if (mustcheck) {
        NSArray *contents;
        unsigned j, m;

        if ([self checkPath: dbpath attributes: attributes]
                      && ([foundPaths containsObject: dbpath] == NO)) {
          [foundPaths addObject: dbpath];
          [lsfolder addFoundPath: dbpath];
          GWDebugLog(@"adding %@", dbpath);
        }
        
        contents = [fm directoryContentsAtPath: dbpath];
        
        for (j = 0; j < [contents count]; j++) {
          CREATE_AUTORELEASE_POOL(arp2);
          NSString *fname = [contents objectAtIndex: j];
          NSString *fpath = [dbpath stringByAppendingPathComponent: fname];
          NSDictionary *attr = [fm fileAttributesAtPath: fpath traverseLink: NO];

          if ([self checkPath: fpath attributes: attr]
                              && ([foundPaths containsObject: fpath] == NO)) {
            [foundPaths addObject: fpath];
            [lsfolder addFoundPath: fpath];
            GWDebugLog(@"adding %@", fpath);
          }

          if (([attr fileType] == NSFileTypeDirectory) 
                                && ([results containsObject: fpath] == NO)) { 
            NSArray *founds = [self fullSearchInDirectory: fpath];

            if (founds && [founds count]) {
              for (m = 0; m < [founds count]; m++) {
                NSString *found = [founds objectAtIndex: m];

                if ([foundPaths containsObject: found] == NO) {
                  [foundPaths addObject: found];
                  [lsfolder addFoundPath: found];
                  GWDebugLog(@"adding %@", found);
                }
              }
            }

            [self insertShorterPath: fpath inArray: toinsert];
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
    int i;
    
    if (results == nil) {
      GWDebugLog(@"%@ not found in the db", srcpath);
    } else {
      GWDebugLog(@"no found paths");
    }
    GWDebugLog(@"performing full search in %@", srcpath);
  
    founds = [self fullSearchInDirectory: srcpath];
    
    for (i = 0; i < [founds count]; i++) {
      NSString *found = [founds objectAtIndex: i];
      
      if ([foundPaths containsObject: found] == NO) {
        [foundPaths addObject: found];
        [lsfolder addFoundPath: found];
      }
    }
    
    [self ddbdInsertDirectoryTreesFromPaths: [NSArray arrayWithObject: srcpath]];
  }
  
  GWDebugLog(@"searching done.");
  
  RELEASE (arp);
}

- (BOOL)saveResults
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  [dict setObject: searchPaths forKey: @"searchpaths"];	
  [dict setObject: searchCriteria forKey: @"criteria"];	
  [dict setObject: [lastUpdate description] forKey: @"lastupdate"];	
  [dict setObject: [NSNumber numberWithLong: autoupdate] 
           forKey: @"autoupdate"];	
  if (dircount > 0) {
    [dict setObject: [NSNumber numberWithLong: dircount] 
            forKey: @"dircount"];	
  }
  
  if ([dict writeToFile: [lsfolder infoPath] atomically: YES] == NO) {
    return NO;
  }
  if ([foundPaths writeToFile: [lsfolder foundPath] atomically: YES] == NO) {
    return NO;
  }

  return YES;
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
    
    if ([self checkPath: fullPath attributes: attrs]) {    
      [founds addObject: fullPath];
    }
    
    RELEASE (arp1);
  }
  
  RETAIN (founds);
  RELEASE (arp);
      
  return AUTORELEASE (founds);
}

- (BOOL)checkPath:(NSString *)path
{
  NSDictionary *attrs = [fm fileAttributesAtPath: path traverseLink: NO];
  return (attrs && [self checkPath: path attributes: attrs]);
}

- (BOOL)checkPath:(NSString *)path 
       attributes:(NSDictionary *)attrs
{
  BOOL found = YES;
  int i;

  for (i = 0; i < [modules count]; i++) {
    id module = [modules objectAtIndex: i];
      
    found = [self checkPath: path attributes: attrs withModule: module];
  
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
  if ([module reliesOnModDate] && (newcriteria == NO)) {
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

@end


@implementation	LSFUpdater (ddbd)

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
      
      GWDebugLog(@"ddbd connected!");     
                                         
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
        ddbd = nil;
        
        [lsfolder updaterError: @"unable to contact ddbd."];
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

  [lsfolder updaterError: @"ddbd connection died!"];
}

- (void)ddbdInsertTrees
{
  [self connectDDBd];
  if (ddbd && [ddbd dbactive]) {
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
  if (ddbd && [ddbd dbactive]) {
    NSData *info = [NSArchiver archivedDataWithRootObject: paths];
    [ddbd insertDirectoryTreesFromPaths: info];
  }
}

- (NSArray *)ddbdGetDirectoryTreeFromPath:(NSString *)path
{
  [self connectDDBd];
  if (ddbd && [ddbd dbactive]) {
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
  if (ddbd && [ddbd dbactive]) {
    [ddbd removeTreesFromPaths: [NSArchiver archivedDataWithRootObject: paths]];
  }
}

- (NSString *)ddbdGetAnnotationsForPath:(NSString *)path
{
  [self connectDDBd];
  if (ddbd && [ddbd dbactive]) {
    return [ddbd annotationsForPath: path];
  }
  return nil;
}

- (NSTimeInterval)ddbdGetTimestampOfPath:(NSString *)path
{
  [self connectDDBd];
  if (ddbd && [ddbd dbactive]) {
    return [ddbd timestampOfPath: path];
  }
  return 0.0;
}

@end


@implementation	LSFUpdater (scheduled)

- (void)searchInNextDirectory:(id)sender
{
  NSString *spath;
  BOOL isdir;
  NSArray *results;
  BOOL reset = NO;
  
  [self checkNextFoundPath];
  
  if (directories == nil) {
    ASSIGN (startSearch, [NSDate date]);
    spathindex = 0;
    dirindex = 0;
    dircounter = 0;
    
    spath = [searchPaths objectAtIndex: spathindex];
    
    if ([fm fileExistsAtPath: spath isDirectory: &isdir]) {
      if (isdir) {
        results = [self ddbdGetDirectoryTreeFromPath: spath];
    
        if (results) {
          directories = [results mutableCopy];
          [directories addObject: spath];
        }
      } else {
        if ([self checkPath: spath]
                      && ([foundPaths containsObject: spath] == NO)) {
          [foundPaths addObject: spath];
          [lsfolder addFoundPath: spath];
        }

        return;
      }
    }
    
  } else if (dirindex >= [directories count]) {
    dirindex = 0;

    if ([searchPaths count] > 1) {
      spathindex++;
    
      if (spathindex >= [searchPaths count]) {
        spathindex = 0;
        dircount = dircounter;
        dircounter = 0;
        reset = YES;
        
        if ([startSearch laterDate: lastUpdate] == startSearch) {
          lastUpdate = [startSearch copy];
        }
        if ([self saveResults] == NO) {
          [lsfolder updaterError: NSLocalizedString(@"cannot save the folder!", @"")];
        }
      
        ASSIGN (startSearch, [NSDate date]);
      }
      
      spath = [searchPaths objectAtIndex: spathindex];
      
      if ([fm fileExistsAtPath: spath isDirectory: &isdir]) {
        if (isdir) {
          results = [self ddbdGetDirectoryTreeFromPath: spath];

          if (results) {
            RELEASE (directories);
            directories = [results mutableCopy];
            [directories addObject: spath];
          }
        } else {
          if ([self checkPath: spath]
                        && ([foundPaths containsObject: spath] == NO)) {
            [foundPaths addObject: spath];
            [lsfolder addFoundPath: spath];
          } 
      
          return;
        }
      }
      
    } else {
      dircount = dircounter;
      dircounter = 0;
      reset = YES;
    
      if ([startSearch laterDate: lastUpdate] == startSearch) {
        lastUpdate = [startSearch copy];
      }
      if ([self saveResults] == NO) {
        [lsfolder updaterError: NSLocalizedString(@"cannot save the folder!", @"")];
      }
      
      ASSIGN (startSearch, [NSDate date]);
    }
  }
  
  if (directories) {
    CREATE_AUTORELEASE_POOL(arp1);
    NSMutableArray *toinsert = [NSMutableArray array];
    NSString *directory = [directories objectAtIndex: dirindex];
    NSDictionary *attributes = [fm fileAttributesAtPath: directory traverseLink: NO];
    NSDate *moddate = [attributes fileModificationDate];
    BOOL mustcheck;

    mustcheck = (([moddate laterDate: lastUpdate] == moddate) || newcriteria);

    if ((mustcheck == NO) && metadataModule) {
      NSTimeInterval interval = [lastUpdate timeIntervalSinceReferenceDate];
      mustcheck = ([self ddbdGetTimestampOfPath: directory] > interval);
      if (mustcheck) {
        GWDebugLog(@"metadata modification date changed at %@", directory);
      }
    }
  
    if (mustcheck) {
      NSArray *contents;
      int j, m;
      
      if ([self checkPath: directory attributes: attributes]
                    && ([foundPaths containsObject: directory] == NO)) {
        [foundPaths addObject: directory];
        [lsfolder addFoundPath: directory];
      }
      
      contents = [fm directoryContentsAtPath: directory];
      
      if (contents) {
        for (j = 0; j < [contents count]; j++) {
          CREATE_AUTORELEASE_POOL(arp2);
          NSString *fname = [contents objectAtIndex: j];
          NSString *fpath = [directory stringByAppendingPathComponent: fname];
          NSDictionary *attr = [fm fileAttributesAtPath: fpath traverseLink: NO];

          if ([self checkPath: fpath attributes: attr]
                              && ([foundPaths containsObject: fpath] == NO)) {
            [foundPaths addObject: fpath];
            [lsfolder addFoundPath: fpath];
          }

          if (([attr fileType] == NSFileTypeDirectory) 
                                && ([directories containsObject: fpath] == NO)) { 
            NSArray *founds = [self fullSearchInDirectory: fpath];

            if (founds && [founds count]) {
              for (m = 0; m < [founds count]; m++) {
                NSString *found = [founds objectAtIndex: m];

                if ([foundPaths containsObject: found] == NO) {
                  [foundPaths addObject: found];
                  [lsfolder addFoundPath: found];
                }
              }
            }

            [directories addObject: fpath];
            [self insertShorterPath: fpath inArray: toinsert];
          } 

          RELEASE (arp2);
        }  
      }  
    }
  
    GWDebugLog(@"dirindex %i", dirindex);
  
    dirindex++;
    dircounter++;
    
    if ([toinsert count]) {
      [self ddbdInsertDirectoryTreesFromPaths: toinsert];
    }
    
    if (reset) {
      newcriteria = NO;
      [self resetTimer];
    }
    
    RELEASE (arp1);
  }
}

- (void)checkNextFoundPath
{
  if ([foundPaths count]) {
    NSString *path;
    NSDictionary *attrs;
    BOOL remove = NO;
  
    if (fpathindex >= [foundPaths count]) {
      fpathindex = 0;
    }

    path = [foundPaths objectAtIndex: fpathindex];
    attrs = [fm fileAttributesAtPath: path traverseLink: NO];  

    if (attrs) {
      remove = ([self checkPath: path attributes: attrs] == NO);
    } else {
      remove = YES;
    }

    if (remove) {
      [lsfolder removeFoundPath: path];
      [foundPaths removeObject: path];
    } 

    fpathindex++;
    GWDebugLog(@"checkNextFoundPath %i", fpathindex);
  }
}

@end


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL (pool);
  
  if (argc > 1) {
    NSString *conname = [NSString stringWithCString: argv[1]];
    LSFUpdater *updater = [[LSFUpdater alloc] initWithConnectionName: conname];
    
    if (updater) {
		  [[[NSProcessInfo processInfo] debugSet] addObject: @"dflt"];
      [[NSRunLoop currentRunLoop] run];
    }
  } else {
    NSLog(@"no connection name.");
  }
  
  RELEASE (pool);  
  exit(0);
}

BOOL subPathOfPath(NSString *p1, NSString *p2)
{
  int l1 = [p1 length];
  int l2 = [p2 length];  

  if ((l1 > l2) || ([p1 isEqual: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqual: p1]) {
    if ([[p2 pathComponents] containsObject: [p1 lastPathComponent]]) {
      return YES;
    }
  }

  return NO;
}



