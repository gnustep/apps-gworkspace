/* lsfd.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: September 2004
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

#include "lsfd.h"
#include "lsfolder.h"
#include "FSNode.h"
#include "FinderModulesProtocol.h"

#include <stdio.h>
#include <unistd.h>
#ifdef __MINGW__
  #include "process.h"
#endif
#include <fcntl.h>
#ifdef HAVE_SYSLOG_H
  #include <syslog.h>
#endif
#include <signal.h>

@implementation	LSFd

- (void)dealloc
{  
  if (conn) {
    [nc removeObserver: self
		              name: NSConnectionDidDieNotification
		            object: conn];
    DESTROY (conn);
  }

  if (finderconn) {
    [nc removeObserver: self
		              name: NSConnectionDidDieNotification
		            object: finderconn];
  	DESTROY (finderconn);
	  DESTROY (finder);                
  }

  RELEASE (modules);
  RELEASE (lsfolders);

  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {    
    fm = [NSFileManager defaultManager];	
    nc = [NSNotificationCenter defaultCenter];
    
    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"lsfd"] == NO) {
	    NSLog(@"unable to register with name server - quiting.");
	    DESTROY (self);
	    return self;
	  }
      
    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
	             name: NSConnectionDidDieNotification
	           object: conn];
             
    finderconn = nil;           
    finder = nil; 
    
    lsfolders = [NSMutableArray new];
    [self loadModules];
  }
  
  return self;    
}

- (void)loadModules
{
  NSString *bundlesDir;
  NSArray *bpaths;
  NSMutableArray *bundlesPaths;
  BOOL isdir;
  int i;
  
  bundlesPaths = [NSMutableArray array];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  bpaths = [self bundlesWithExtension: @"finder" inPath: bundlesDir];
  [bundlesPaths addObjectsFromArray: bpaths];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Finder"];  

  if ([fm fileExistsAtPath: bundlesDir isDirectory: &isdir] && isdir) {
    bpaths = [self bundlesWithExtension: @"finder" inPath: bundlesDir];
    [bundlesPaths addObjectsFromArray: bpaths];
  }
  
  modules = [NSMutableArray new];

  for (i = 0; i < [bundlesPaths count]; i++) {
    NSString *bpath = [bundlesPaths objectAtIndex: i];
    NSBundle *bundle = [NSBundle bundleWithPath: bpath];
     
    if (bundle) {
			Class principalClass = [bundle principalClass];

			if ([principalClass conformsToProtocol: @protocol(FinderModulesProtocol)]) {	
	      [modules addObject: principalClass];
			}
    }
  }
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

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;
{
  [newConn setDelegate: self];

  [nc addObserver: self
         selector: @selector(connectionBecameInvalid:)
	           name: NSConnectionDidDieNotification
	         object: newConn];

  if ((ancestor == conn) && (finder == nil)) {
    ASSIGN (finderconn, newConn);
  }
  
  return YES;
}

- (void)connectionBecameInvalid:(NSNotification *)notification
{
  id connection = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  if (connection == conn) {
    NSLog(@"argh - lsfd server root connection has been destroyed.");
    exit(EXIT_FAILURE);
    
  } else if (connection == finderconn) {
  	DESTROY (finderconn);
	  DESTROY (finder);
	}
}

- (void)registerFinder:(id <LSFdClientProtocol>)fndr
{
  [(id)fndr setProtocolForProxy: @protocol(LSFdClientProtocol)];
  ASSIGN (finder, fndr);
}

- (void)unregisterFinder:(id <LSFdClientProtocol>)fndr
{
	NSConnection *connection = [(NSDistantObject *)fndr connectionForProxy];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];
              
  DESTROY (finderconn);
  DESTROY (finder);
}

- (void)addLiveSearchFolderWithPath:(NSString *)path
{
  LSFolder *folder = [[LSFolder alloc] initWithPath: path];

  if (folder) {
    [lsfolders addObject: folder];
    RELEASE (folder);  
    
    
    [folder updateFoundPaths];
  }
}

@end


int main(int argc, char** argv)
{
	LSFd *lsfd;

	switch (fork()) {
	  case -1:
	    fprintf(stderr, "lsfd - fork failed - bye.\n");
	    exit(1);

	  case 0:
	    setsid();
	    break;

	  default:
	    exit(0);
	}
  
  CREATE_AUTORELEASE_POOL (pool);
	lsfd = [[LSFd alloc] init];
  RELEASE (pool);
  
  if (lsfd) {
	  CREATE_AUTORELEASE_POOL (pool);
    [[NSRunLoop currentRunLoop] run];
  	RELEASE (pool);
  }
  
  exit(0);
}
