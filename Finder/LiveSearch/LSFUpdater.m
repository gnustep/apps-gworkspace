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
  if (srchPathsTmr && [srchPathsTmr isValid]) {
    [srchPathsTmr invalidate];
    DESTROY (srchPathsTmr);
  }
  if (fndPathsTmr && [fndPathsTmr isValid]) {
    [fndPathsTmr invalidate];
    DESTROY (fndPathsTmr);
  }

  DESTROY (ddbd);
  RELEASE (searchPaths);
  TEST_RELEASE (directories);
  RELEASE (searchCriteria);
  RELEASE (foundPaths);
  RELEASE (lastUpdate);
  TEST_RELEASE (startSearch);
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
    startSearch = nil;
    foundPaths = [NSMutableArray new];
    directories = nil;
    
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
    
    if (autoupdate) {
      [self setAutoupdate: autoupdate];      
    }
  }
  
  return self;
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
  
  if (value) {
    if ([foundPaths count] == 0) {
      [self getFoundPaths];
    }

    if (fndPathsTmr == nil) {
      fndPathsTmr = [NSTimer scheduledTimerWithTimeInterval: 0.1
                                       target: self 
                                     selector: @selector(checkNextFoundPath:) 
                                     userInfo: nil 
                                     repeats: YES];
      RETAIN (fndPathsTmr);
    }

    if (srchPathsTmr == nil) {    
      srchPathsTmr = [NSTimer scheduledTimerWithTimeInterval: 0.1
                                       target: self 
                                     selector: @selector(searchInNextDirectory:) 
                                     userInfo: nil 
                                      repeats: YES];
      RETAIN (srchPathsTmr);
    }                                    
                                    
       // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!                             
       // CALCOLARE I TEMPI !!!!!!!!!!!!!!!!!!!!!!!!!!
       // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!                             
                                    
                                    
                                    
  } else {
    if (srchPathsTmr && [srchPathsTmr isValid]) {
      [srchPathsTmr invalidate];
      DESTROY (srchPathsTmr);
    }
    if (fndPathsTmr && [fndPathsTmr isValid]) {
      [fndPathsTmr invalidate];
      DESTROY (fndPathsTmr);
    }
  }

  autoupdate = value;
}

- (void)notifyEndAction:(id)sender
{
  if (lsfolder) {
    [lsfolder updaterDidEndAction];
  }
}

- (void)exitThread
{
  if (srchPathsTmr && [srchPathsTmr isValid]) {
    [srchPathsTmr invalidate];
    DESTROY (srchPathsTmr);
  }
  if (fndPathsTmr && [fndPathsTmr isValid]) {
    [fndPathsTmr invalidate];
    DESTROY (fndPathsTmr);
  }

  [NSThread exit];
}


- (void)fastUpdate
{
  int count = [searchPaths count];
  BOOL lsfdone = YES;
  int i;

  NSLog(@"starting fast update");

  [self getFoundPaths];

  NSLog(@"got %i found paths. checking...", [foundPaths count]);

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

  NSLog(@"fast update done.");

  if ([searchPaths count]) {
    ASSIGN (lastUpdate, [NSDate date]);
    lsfdone = [self saveResults];
  } else {
    lsfdone = NO;
  }  

  if (lsfdone == NO) {
    [lsfolder updaterError: NSLocalizedString(@"cannot save the folder!", @"")];
  }

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
  
  NSLog(@"getting directories from the db...");
  
  results = [self ddbdGetDirectoryTreeFromPath: srcpath];
  
  if (results && [foundPaths count]) {
    NSMutableArray *toinsert = [NSMutableArray array];
    int count = [results count];
    int i;
        
    results = [results arrayByAddingObject: srcpath];

    NSLog(@"%i directories", [results count]);
    NSLog(@"updating in %@", srcpath);    
    
    for (i = 0; i <= count; i++) {
      CREATE_AUTORELEASE_POOL(arp1);
      NSString *dbpath = [results objectAtIndex: i];
      NSDictionary *attributes = [fm fileAttributesAtPath: dbpath traverseLink: NO];
      NSDate *moddate = [attributes fileModificationDate];


      if ([dbpath isEqual: @"/home/enrico/Butt/GNUstep/Pixmaps/CartaNuova/CooopyPix/CVS/Startup/config/CVS"]) {
        NSLog(@"TROVATA!!!!!!!!!!!!!!!!!!!!!!!");
      }
            
      
      if ([moddate laterDate: lastUpdate] == moddate) {
        NSArray *contents;
        int j, m;

        if ([self checkPath: dbpath attributes: attributes]
                      && ([foundPaths containsObject: dbpath] == NO)) {
          [foundPaths addObject: dbpath];
          [lsfolder addFoundPath: dbpath];
          NSLog(@"adding %@", dbpath);
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
            NSLog(@"adding %@", fpath);
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
                  NSLog(@"adding %@", found);
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
      NSLog(@"%@ not found in the db", srcpath);
    } else {
      NSLog(@"no found paths");
    }
    NSLog(@"performing full search in %@", srcpath);
  
    founds = [self fullSearchInDirectory: srcpath];
    
    for (i = 0; i < [founds count]; i++) {
      NSString *found = [founds objectAtIndex: i];

      [foundPaths addObject: found];
      [lsfolder addFoundPath: found];
    }
    
    [self ddbdInsertDirectoryTreesFromPaths: [NSArray arrayWithObject: srcpath]];
  }
  
  NSLog(@"searching done.");
  
  RELEASE (arp);
}

- (BOOL)saveResults
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  [dict setObject: searchPaths forKey: @"searchpaths"];	
  [dict setObject: searchCriteria forKey: @"criteria"];	
  [dict setObject: [lastUpdate description] forKey: @"lastupdate"];	
  [dict setObject: [NSNumber numberWithBool: autoupdate] 
           forKey: @"autoupdate"];	

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
  ddbdactive = NO;

  [lsfolder updaterError: @"ddbd connection died!"];
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

@end


@implementation	LSFUpdater (scheduled)

- (void)checkNextFoundPath:(id)sender
{
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
  
  NSLog(@"checkNextFoundPath %i", fpathindex);
}

- (void)searchInNextDirectory:(id)sender
{
  NSString *spath;
  BOOL isdir;
  NSArray *results;

  if (directories == nil) {
    ASSIGN (startSearch, [NSDate date]);
    spathindex = 0;
    dirindex = 0;
    
    NSLog(@"searchInNextDirectory START");
    
    spath = [searchPaths objectAtIndex: spathindex];
    
    if ([fm fileExistsAtPath: spath isDirectory: &isdir]) {
      if (isdir) {
        results = [self ddbdGetDirectoryTreeFromPath: spath];
    
        if (results) {
          directories = [results mutableCopy];
          [directories addObject: spath];
          
          NSLog(@"got directories count = %i", [directories count]);
          
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
        
        if ([startSearch laterDate: lastUpdate] == startSearch) {
          lastUpdate = [startSearch copy];

          if ([self saveResults] == NO) {
            [lsfolder updaterError: NSLocalizedString(@"cannot save the folder!", @"")];
          }
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
      if ([startSearch laterDate: lastUpdate] == startSearch) {
        lastUpdate = [startSearch copy];

        if ([self saveResults] == NO) {
          [lsfolder updaterError: NSLocalizedString(@"cannot save the folder!", @"")];
        } else {
          NSLog(@"AUTOUPDATE CYCLE DONE - AUTOUPDATE CYCLE DONE - AUTOUPDATE CYCLE DONE ");
        }
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
  
    if ([moddate laterDate: lastUpdate] == moddate) {
      NSArray *contents;
      int j, m;
      
      if ([self checkPath: directory attributes: attributes]
                    && ([foundPaths containsObject: directory] == NO)) {
        [foundPaths addObject: directory];
        [lsfolder addFoundPath: directory];
      }
      
      contents = [fm directoryContentsAtPath: directory];
      
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
  
    NSLog(@"dirindex %i", dirindex);
  
    dirindex++;
    
    if ([toinsert count]) {
      [self ddbdInsertDirectoryTreesFromPaths: toinsert];
    }
    
    RELEASE (arp1);
  }
}

@end

