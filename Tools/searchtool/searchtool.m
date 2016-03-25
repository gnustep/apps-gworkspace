/* searchtool.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2004
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FinderModulesProtocol.h"
#import "config.h"



@protocol	Finder

- (oneway void)registerSearchTool:(id)tool;

- (oneway void)nextResult:(NSString *)path;

- (oneway void)endOfSearch;

@end


@protocol	DDBd

- (NSString *)annotationsForPath:(NSString *)path;

@end


@interface SearchTool: NSObject 
{
  BOOL stopped;  
  BOOL done;
  id finder;
  id ddbd;
  NSFileManager *fm;
  NSNotificationCenter *nc; 
}

- (id)initWithConnectionName:(NSString *)cname;

- (void)connectionDidDie:(NSNotification *)notification;

- (void)searchWithInfo:(NSData *)srcinfo;

- (void)stop;

- (void)done;

- (void)terminate;

- (NSArray *)bundlesWithExtension:(NSString *)extension 
													 inPath:(NSString *)path;
      
@end


@interface SearchTool (ddbd)

- (void)connectDDBd;
- (void)ddbdConnectionDidDie:(NSNotification *)notif;
- (NSString *)ddbdGetAnnotationsForPath:(NSString *)path;

@end


@implementation	SearchTool

- (void)dealloc
{
  [nc removeObserver: self];
  DESTROY (finder);
  DESTROY (ddbd);
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
            
    conn = [NSConnection connectionWithRegisteredName: cname host: nil];
    
    if (conn == nil) {
      NSLog(@"failed to contact Finder - bye.");
      exit(1);           
    } 

    [nc addObserver: self
           selector: @selector(connectionDidDie:)
               name: NSConnectionDidDieNotification
             object: conn];    
    
    anObject = [conn rootProxy];
    [anObject setProtocolForProxy: @protocol(Finder)];
    finder = (id <Finder>)anObject;
    RETAIN (finder);

    stopped = NO;    
    done = NO;

    [finder registerSearchTool: self];
  }
  
  return self;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  id conn = [notification object];

  [nc removeObserver: self
		name: NSConnectionDidDieNotification
  	      object: conn];

  if (done == NO) {
    NSLog(@"finder connection has been destroyed.");
    exit(0);
  }
}

- (void)searchWithInfo:(NSData *)srcinfo
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *srcdict = [NSUnarchiver unarchiveObjectWithData: srcinfo];
  NSArray *paths = [srcdict objectForKey: @"paths"];
  id recursionObj = [srcdict objectForKey: @"recursion"];
  BOOL recursion;
  NSDictionary *criteria = [srcdict objectForKey: @"criteria"];
  NSArray *classNames = [criteria allKeys];
  NSMutableArray *modules = [NSMutableArray array];
  NSString *bundlesDir;
  BOOL isdir;
  NSMutableArray *bundlesPaths;
  NSEnumerator *enumerator;
  NSUInteger i;

  recursion = NO;
  if (recursionObj)
      recursion = [recursionObj boolValue];

  bundlesPaths = [NSMutableArray array];
  enumerator = [NSSearchPathForDirectoriesInDomains
    (NSLibraryDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((bundlesDir = [enumerator nextObject]) != nil)
    {
      bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
      [bundlesPaths addObjectsFromArray:
	[self bundlesWithExtension: @"finder" inPath: bundlesDir]];
    }

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"GWorkspace"];

  if ([fm fileExistsAtPath: bundlesDir isDirectory: &isdir] && isdir) {
    [bundlesPaths addObjectsFromArray: [self bundlesWithExtension: @"finder" 
                                                           inPath: bundlesDir]];
  }

  for (i = 0; i < [bundlesPaths count]; i++) {
    NSString *bpath = [bundlesPaths objectAtIndex: i];
    NSBundle *bundle = [NSBundle bundleWithPath: bpath];
     
    if (bundle) {
      Class principalClass = [bundle principalClass];
      NSString *className = NSStringFromClass(principalClass);

      if ([classNames containsObject: className]) {
        NSDictionary *moduleCriteria = [criteria objectForKey: className];
        id module = [[principalClass alloc] initWithSearchCriteria: moduleCriteria
                                                        searchTool: self];
        [modules addObject: module];
        RELEASE (module);  
      }
    }
  }

  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];
    NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: YES];
    NSString *type = [attributes fileType];
    NSUInteger j;
    
    if (type == NSFileTypeDirectory) {
      CREATE_AUTORELEASE_POOL(arp1);
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: path];
      
      while (!stopped) {
        CREATE_AUTORELEASE_POOL(arp2);
        NSString *currentPath = [enumerator nextObject];
      
        if (currentPath) {
          NSString *fullPath = [path stringByAppendingPathComponent: currentPath];
          NSDictionary *attrs = [enumerator fileAttributes];
          BOOL found = YES;
        
          for (j = 0; j < [modules count]; j++) {
            id module = [modules objectAtIndex: j];

            found = [module checkPath: fullPath withAttributes: attrs];

            if (found == NO) {
              break;
            }

            if (stopped) {
              break;
            }
          }

          if (found) {
            [finder nextResult: fullPath];
          }

          if (stopped) {
            RELEASE (arp2);
            break;
          }

          if (([attrs fileType] == NSFileTypeDirectory) && !recursion) {
            [enumerator skipDescendents];
          }
        
        } else {
          RELEASE (arp2);
          break;
        }
        
        RELEASE (arp2);  
      }
      
      RELEASE (arp1);

    } else {
      BOOL found = YES;
      
      for (j = 0; j < [modules count]; j++) {
        id module = [modules objectAtIndex: j];
        
        found = [module checkPath: path withAttributes: attributes];

        if (found == NO) {
          break;
        }
        
        if (stopped) {
          break;
        }
      }
      
      if (found) {
        [finder nextResult: path];
      }
    }
    
    if (stopped) {
      break;
    }
  }

  RELEASE (arp);

  [self done];
}

- (void)stop
{
  stopped = YES;
}

- (void)done
{
  [finder endOfSearch];  
}

- (void)terminate
{
  exit(0);
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

@end


@implementation	SearchTool (ddbd)

- (void)connectDDBd
{
  if (ddbd == nil) {
    ddbd = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                             host: @""];

    if (ddbd == nil) {
      NSString *cmd;
      int i;
    
      cmd = [NSTask launchPathForTool: @"ddbd"];    
              
      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
   
      for (i = 0; i < 40; i++) {
        [[NSRunLoop currentRunLoop] runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow: 0.1]];

        ddbd = [NSConnection rootProxyForConnectionWithRegisteredName: @"ddbd" 
                                                                 host: @""];                  
        if (ddbd) {
          break;
        }
      }
    }
    
    if (ddbd) {
      RETAIN (ddbd);
      [ddbd setProtocolForProxy: @protocol(DDBd)];
    
      [[NSNotificationCenter defaultCenter] addObserver: self
					       selector: @selector(ddbdConnectionDidDie:)
		                     		   name: NSConnectionDidDieNotification
		                   		 object: [ddbd connectionForProxy]];
                       
    } else {
      NSLog(@"unable to contact ddbd.");
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
}

- (NSString *)ddbdGetAnnotationsForPath:(NSString *)path
{
  [self connectDDBd];
  if (ddbd != nil) {
    return [ddbd annotationsForPath: path];
  }
  return nil;
}

@end


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL (pool);
  
  if (argc > 1) {
    NSString *conname = [NSString stringWithCString: argv[1]];
    SearchTool *srchtool = [[SearchTool alloc] initWithConnectionName: conname];
    
    if (srchtool) {
      [[NSRunLoop currentRunLoop] run];
    }
  } else {
    NSLog(@"no connection name.");
  }
  
  RELEASE (pool);  
  exit(0);
}

