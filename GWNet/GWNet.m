/* GWNet.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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
#include "GWNet.h"
#include "FTPViewer.h"
#include "SMBViewer.h"
#include "FileOpInfo.h"
#include "OpenUrlDlog.h"
#include "GWNetFunctions.h"
#include "FTPHandler.h"
#include "SMBHandler.h"
#include "Dispatcher.h"
#include "GNUstep.h"

static GWNet *gwnet = nil;

@implementation GWNet

+ (GWNet *)gwnet
{
	if (gwnet == nil) {
		gwnet = [[GWNet alloc] init];
	}	
  return gwnet;
}

+ (void)initialize
{
	static BOOL initialized = NO;
	
	if (initialized == YES) {
		return;
  }
	
	initialized = YES;
}

- (void)dealloc
{
  [nc removeObserver: self];  

  RELEASE (openUrlDlog);  
  RELEASE (viewersClasses);  
  RELEASE (viewers);  
  
  TEST_RELEASE (onStartUrl);
  TEST_RELEASE (onStartSelection);
  TEST_RELEASE (onStartContents);

  RELEASE (handlersClasses);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    viewers = [NSMutableArray new];
      
    viewersClasses = [NSMutableArray new];
    [viewersClasses addObject: [FTPViewer class]];
    [viewersClasses addObject: [SMBViewer class]];
    
    onStartUrl = nil;
    onStartSelection = nil;
    onStartContents = nil;
    started = NO;
    
    handlersClasses = [NSMutableArray new];
    [handlersClasses addObject: [FTPHandler class]];
    [handlersClasses addObject: [SMBHandler class]];
    
    nc = [NSNotificationCenter defaultCenter];

    [nc addObserver: self
           selector: @selector(threadWillExit:)
               name: NSThreadWillExitNotification
             object: nil];    
  }
  
  return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
//  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];			
//  id entry;
  
//  [isa registerForServices];
    
  openUrlDlog = [[OpenUrlDlog alloc] init];  

  if (onStartUrl) {
    [self newViewerForUrl: onStartUrl
        withSelectedPaths: onStartSelection
              preContents: onStartContents];  
  }
  
  started = YES;
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
	int i;

#define TEST_CLOSE(o, w) if ((o) && ([w isVisible])) [w close]

  [self updateDefaults];

	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];
		TEST_CLOSE (vwr, vwr);
  }
	TEST_CLOSE (openUrlDlog, [openUrlDlog urlsWin]);
  		
	return YES;
}

- (BOOL)application:(NSApplication *)application 
           openFile:(NSString *)fileName
{
  return [self openBookmarkFile: fileName];
}

- (id)newViewerForUrl:(NSURL *)url 
    withSelectedPaths:(NSArray *)selpaths
          preContents:(NSDictionary *)preconts
{
  NSString *hostname = [url host];
  NSString *scheme = [url scheme];
  NSString *path = [url path];
  NSHost *host = [NSHost hostWithName: hostname]; 
  id vwr = nil;
  int i;

	for (i = 0; i < [viewers count]; i++) {
    vwr = [viewers objectAtIndex: i];

    if ([[vwr hostname] isEqual: hostname]) {
      [vwr orderFrontRegardless];
      
      if (preconts && [preconts count]) {
        [vwr setPreContents: preconts];
      }
      
      if (selpaths && [selpaths count]) {
        [vwr setPathAndSelection: selpaths];
      } else if (path && [path length] && ([path isEqual: fixPath(@"/", 0)] == NO)) {
        [vwr setPathAndSelection: [NSArray arrayWithObject: path]];
      }

      return vwr;
    }
  }
  
  vwr = nil;
  
  if (host) {
    int result = [openUrlDlog runLoginDialogForHost: hostname];

    if (result == NSAlertDefaultReturn) {
      BOOL found = NO;
    
      for (i = 0; i < [viewersClasses count]; i++) {
        Class c = [viewersClasses objectAtIndex: i];

        if ([c canViewScheme: scheme]) {
          NSString *usr = [openUrlDlog username];
          NSString *passwd = [openUrlDlog password];
                                          
          vwr = [[c alloc] initForUrl: url user: usr password: passwd];

          if (preconts && [preconts count]) {
            [vwr setPreContents: preconts];
          }

          if (selpaths && [selpaths count]) {
            [vwr setPathAndSelection: selpaths];
          } else if (path && [path length] && ([path isEqual: fixPath(@"/", 0)] == NO)) {
            [vwr setPathAndSelection: [NSArray arrayWithObject: path]];
          }

          [viewers insertObject: vwr atIndex: [viewers count]];
          RELEASE (vwr);

          found = YES;
          break;
        }
      }

      if (found == NO) {
        NSString *msg = NSLocalizedString(@"No viewer for ", @"");
        msg = [NSString stringWithFormat: @"%@ \"%@\"", msg, scheme];
        NSRunAlertPanel(NULL, msg, NSLocalizedString(@"Ok", @""), NULL, NULL);   
      }
    }

  } else {
    NSRunAlertPanel(NULL, NSLocalizedString(@"Invalid host name", @""),
                                NSLocalizedString(@"Ok", @""), NULL, NULL);   
  }  
  
  return vwr;
}

- (void)dispatcherForViewerWithScheme:(NSString *)scheme
                       connectionName:(NSString *)conname
{
  int i;
  
  for (i = 0; i < [handlersClasses count]; i++) {
    Class handlerClass = [handlersClasses objectAtIndex: i];

    if ([handlerClass canViewScheme: scheme]) {
      NSMutableDictionary *info = [NSMutableDictionary dictionary];
    
      [info setObject: handlerClass forKey: @"handlerclass"];
      [info setObject: conname forKey: @"conname"];
    
      NS_DURING
      {
        [NSThread detachNewThreadSelector: @selector(newDispatcherWithInfo:)
                                 toTarget: [self class] 
                               withObject: info];
      }
      NS_HANDLER
      {
        NSLog(@"Error! A fatal error occured while detaching the thread.");
      }
      NS_ENDHANDLER
      
      break;
    }
  }
}

+ (void)newDispatcherWithInfo:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL (pool);
  Class handlerClass = [info objectForKey: @"handlerclass"];
  NSString *conname = [info objectForKey: @"conname"];
  NSConnection *conn = [NSConnection connectionWithRegisteredName: conname host: @""];
  id viewer = [conn rootProxy];
  id dispatcher = [Dispatcher new];
                 
  [viewer setProtocolForProxy: @protocol(ViewerProtocol)];
  viewer = (id <ViewerProtocol>)viewer;
    
  [dispatcher setViewer: viewer 
           handlerClass: handlerClass
             connection: conn];
  
  [[NSRunLoop currentRunLoop] run];
  [pool release];
}

- (void)threadWillExit:(NSNotification *)notification
{
  NSLog(@"thread will exit");
}

- (void)setCurrentViewer:(id)viewer
{
  currentViewer = viewer;
}

- (void)viewerHasClosed:(id)vwr
{
  [viewers removeObject: vwr];
}

- (NSRect)rectForFileOpWindow
{
  NSMutableArray *fileOperations = [NSMutableArray array];
  NSRect scr = [[NSScreen mainScreen] visibleFrame];
  NSRect wrect = NSZeroRect;
  int i;  

  #define WMARGIN 50
  #define WSHIFT 50

  scr.origin.x += WMARGIN;
  scr.origin.y += WMARGIN;
  scr.size.width -= (WMARGIN * 2);
  scr.size.height -= (WMARGIN * 2);

	for (i = 0; i < [viewers count]; i++) {
    id vwr = [viewers objectAtIndex: i];
    [fileOperations addObjectsFromArray: [vwr fileOperations]];
  }

	for (i = [fileOperations count] - 1; i >= 0; i--) {
    FileOpInfo *op = [fileOperations objectAtIndex: i];

    if ([op win]) {
      NSRect wr = [op winRect];

      if (NSEqualRects(wr, NSZeroRect) == NO) {
        wrect = NSMakeRect(wr.origin.x + WSHIFT, 
                           wr.origin.y - wr.size.height - WSHIFT,
                           wr.size.width,
                           wr.size.height);

        if (NSContainsRect(scr, wrect) == NO) {
          wrect = NSMakeRect(scr.origin.x, 
                             scr.size.height - wr.size.height,
                             wr.size.width, 
                             wr.size.height);
          break;
        }
      }
    }
  }

  return wrect;
}

- (BOOL)openBookmarkFile:(NSString *)fpath
{
  NSDictionary *bmkDict = [NSDictionary dictionaryWithContentsOfFile: fpath];

  if (bmkDict) {
    NSString *hostname = [bmkDict objectForKey: @"hostname"];
    NSString *scheme = [bmkDict objectForKey: @"scheme"];
    NSArray *selection = [bmkDict objectForKey: @"selection"];
    NSMutableDictionary *preContents = [NSMutableDictionary dictionary];
    NSArray	*subStrings;
    NSString *prgPath;   
    NSString *separator; 
    NSDictionary *pathInfo;
    NSString *path;
    NSString *url;
    int count, i;
    
    if ([selection count] > 1) {
      path = [[selection objectAtIndex: 0] stringByDeletingLastPathComponent];
    } else {
      path = [selection objectAtIndex: 0];
    }

    url = [NSString stringWithFormat: @"%@://%@%@", scheme, hostname, path];
    
    separator = fixPath(@"/", 0);
    subStrings = [path componentsSeparatedByString: separator];
    count = [subStrings count];
    prgPath = [NSString stringWithString: separator];
    
    pathInfo = [bmkDict objectForKey: prgPath];
    if (pathInfo) {
      [preContents setObject: pathInfo forKey: prgPath];
    }

    for (i = 0; i < count; i++) {
		  NSString *str = [subStrings objectAtIndex: i];

		  if ([str isEqualToString: @""] == NO) {
        prgPath = [prgPath stringByAppendingPathComponent: str];
        pathInfo = [bmkDict objectForKey: prgPath];

        if (pathInfo) {
          [preContents setObject: pathInfo forKey: prgPath];
        }
		  }
	  }

    if (started == NO) {
      ASSIGN (onStartUrl, [NSURL URLWithString: url]);
      ASSIGN (onStartSelection, selection);
      ASSIGN (onStartContents, preContents);
    } else {
      [self newViewerForUrl: [NSURL URLWithString: url]
          withSelectedPaths: selection
                preContents: preContents];
    }
    
    return YES;
  }

  return NO;
}

- (void)updateDefaults
{

}


//
// Menu Operations
//
- (void)openNewUrl:(id)sender
{
  [openUrlDlog chooseUrl];
}

- (void)closeMainWin:(id)sender
{
  [[[NSApplication sharedApplication] keyWindow] performClose: sender];
}

- (void)showPreferences:(id)sender
{
//  [prefController activate]; 
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"GWNet" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"-----------------------", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"GWNet 0.1" forKey: @"ApplicationRelease"];
  [d setObject: @"01 2004" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: @"Enrico Sersale <enrico@imago.ro>.", nil]
        forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gwnet", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2004 Free Software Foundation, Inc."
        forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
        forKey: @"CopyrightDescription"];
  
#ifdef GNUSTEP	
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
#else
	[NSApp orderFrontStandardAboutPanel: d];
#endif
}

#ifndef GNUSTEP
- (void)terminate:(id)sender
{
  [NSApp terminate: self];
}
#endif

@end
