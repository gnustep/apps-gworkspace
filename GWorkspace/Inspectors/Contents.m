/*  -*-objc-*-
 *  Contents.m: Implementation of the Contents Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWLib.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
#include "ContentViewersProtocol.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/ContentViewersProtocol.h>
  #endif
#include "Contents.h"
#include "GWorkspace.h"
#include "GNUstep.h"

static NSString *nibName = @"ContentsPanel";

@implementation Contents

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
	TEST_RELEASE (inspBox);
  TEST_RELEASE (searchPaths);
	TEST_RELEASE (insppaths);
	TEST_RELEASE (currentPath);
  TEST_RELEASE (genericView);
  TEST_RELEASE (noContsView);
	TEST_RELEASE (viewers);
  [super dealloc];
}

- (id)init
{	
  self = [super init];
  
  if(self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"Attribute Inspector: failed to load %@!", nibName);
    } else {    
      NSMutableArray *bundlesPaths;
      NSString *home;
      id label;
      int i, j, index;
		  BOOL exists;

      RETAIN (inspBox);
      RELEASE (win); 

      fm = [NSFileManager defaultManager];
      ws = [NSWorkspace sharedWorkspace];
		  gw = [GWorkspace gworkspace];

      winName = NSLocalizedString(@"Contents Inspector", @"");

      //load all default Inspector
      searchPaths = [[NSMutableArray alloc] initWithCapacity: 1];
      [searchPaths addObject: [[NSBundle mainBundle] resourcePath]];

      bundlesPaths = [self bundlesWithExtension: @"inspector" inPath: 
			    														  [[NSBundle mainBundle] resourcePath]];

      //load user Inspectors
      home = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, 
                                        NSUserDomainMask, YES) lastObject];

      [bundlesPaths addObjectsFromArray: [self bundlesWithExtension: @"inspector" 
			         inPath: [home stringByAppendingPathComponent: @"GWorkspace"]]];

      [searchPaths addObject: [home stringByAppendingPathComponent: @"GWorkspace"]];
      
      viewers = [[NSMutableArray alloc] initWithCapacity: 1];
      index = 0;

      for (i = 0; i < [bundlesPaths count]; i++) {
        NSString *bpath = [bundlesPaths objectAtIndex: i];
        NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 

        if (bundle != nil) {
				  Class principalClass = [bundle principalClass];
				  if ([principalClass conformsToProtocol: @protocol(ContentViewersProtocol)]) {	
	  			  id <ContentViewersProtocol>vwr = [[principalClass alloc] initInPanel: self 
													  withFrame: NSMakeRect(0, 0, 257, 245) index: index];
	  			  NSString *name = [vwr winname];

					  exists = NO;				
					  for (j = 0; j < [viewers count]; j++) {
						  if ([name isEqual: [[viewers objectAtIndex: j] winname]]) {
							  exists = YES;
							  break;
						  }
					  }

					  if (exists == NO) {
              [vwr setBundlePath: bpath];            
              [self addViewer: vwr];            
	  			    index++;
            }

	  			  RELEASE ((id)vwr);					
				  }
        }
      }

      [[NSNotificationCenter defaultCenter] addObserver: self 
                		  selector: @selector(watcherNotification:) 
                				  name: GWFileWatcherFileDidChangeNotification
                			  object: nil];

      for (i = 0; i < [searchPaths count]; i++) {
        NSString *spath = [searchPaths objectAtIndex: i];
        [gw addWatcherForPath: spath];
      }

      genericView = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 257, 245)];		
      MAKE_LABEL (genericField, NSMakeRect(2, 103, 255, 65), nil, 'c', YES, genericView);		  
      [genericField setFont: [NSFont systemFontOfSize: 18]];
      [genericField setTextColor: [NSColor grayColor]];				

      noContsView = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 257, 245)];
      MAKE_LOCALIZED_LABEL (label, NSMakeRect(2, 103, 255, 65), @"No Contents Inspector\nFor Multiple Selection", @"", 'c', YES, noContsView);		  
      [label setFont: [NSFont systemFontOfSize: 18]];
      [label setTextColor: [NSColor grayColor]];				

      [revertButt setEnabled: NO];	
      [okButt setEnabled: NO];

      insppaths = nil;
      currentViewer = nil;   
    }
  }
  
  return self;
}

// From Preferences.app (BundleController.m) 
// Authors Jeff Teunissen <deek@d2dc.net>
- (NSMutableArray *)bundlesWithExtension:(NSString *)extension 
																	inPath:(NSString *)path
{
  NSMutableArray *bundleList = [[NSMutableArray alloc] initWithCapacity: 10];
  NSEnumerator *enumerator;
  NSString *dir;
  BOOL isDir;
  
  // ensure path exists, and is a directory
  if (!(([fm fileExistsAtPath: path isDirectory: &isDir]) && isDir)) {
		return nil;
  }
	  
  // scan for bundles matching the extension in the dir
  enumerator = [[fm directoryContentsAtPath: path] objectEnumerator];
  while ((dir = [enumerator nextObject])) {
    if ([[dir pathExtension] isEqualToString: extension]) {
			[bundleList addObject: [path stringByAppendingPathComponent: dir]];
		}
  }
  return bundleList;
}

- (void)addViewer:(id)vwr
{
	[viewers addObject: vwr];
}

- (void)removeViewer:(id)vwr
{
  [viewers removeObject: vwr];
  [self activateForPaths: insppaths];
}

- (void)watcherNotification:(NSNotification *)notification
{
  NSDictionary *notifdict = (NSDictionary *)[notification object];
  NSString *path = [notifdict objectForKey: @"path"];
 
  if ([searchPaths containsObject: path] == NO) {
    return;    

  } else {
    NSString *event = [notifdict objectForKey: @"event"];
    int i, j, count;

    if (event == GWFileDeletedInWatchedDirectory) {
      NSArray *files = [notifdict objectForKey: @"files"];
      
      count = [files count];
      for (i = 0; i < count; i++) { 
        NSString *fname = [files objectAtIndex: i];
        NSString *dpath = [path stringByAppendingPathComponent: fname];
        id vwr = [self viewerWithBundlePath: dpath];
        
        if (vwr) { 
          [self removeViewer: vwr];          
          i--;
          count--;
        }
      }
      
    } else if (event == GWFileCreatedInWatchedDirectory) {
      NSArray *files = [notifdict objectForKey: @"files"];
      int index = [viewers count];
      BOOL added = NO;

      for (i = 0; i < [files count]; i++) { 
        NSString *fname = [files objectAtIndex: i];
        NSString *bpath = [path stringByAppendingPathComponent: fname];
        NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 
        BOOL exists = NO;
        
        if (bundle) {
				  Class principalClass = [bundle principalClass];
				  if ([principalClass conformsToProtocol: @protocol(ContentViewersProtocol)]) {	
	  			  id <ContentViewersProtocol>vwr = [[principalClass alloc] initInPanel: self 
													  withFrame: NSMakeRect(0, 0, 257, 245) index: index];
	  			  NSString *name = [vwr winname];
					
					  for (j = 0; j < [viewers count]; j++) {
						  if ([name isEqual: [[viewers objectAtIndex: j] winname]]) {
							  exists = YES;
							  break;
						  }
					  }
					
					  if (exists == NO) {
              [vwr setBundlePath: bpath];            
              [self addViewer: vwr];      
              added = YES;
	  			    index++;
            }
					
	  			  RELEASE ((id)vwr);					
				  }

        }
      }
      
      if (added) {
        [self activateForPaths: insppaths];
      }
    }
  }
}

- (void)activateForPaths:(NSArray *)paths
{
	id viewer;
	NSWindow *w;
	BOOL stopped;
  
	[okButt setTarget: self];
	[okButt setAction: @selector(doNothing:)];
	[okButt setEnabled: NO];
	[revertButt setTarget: self];
	[revertButt setAction: @selector(doNothing:)];
  [revertButt setEnabled: NO];
	
	ASSIGN (insppaths, paths);
	pathscount = [insppaths count];
	ASSIGN (currentPath, [insppaths objectAtIndex: 0]);

  [(NSBox *)vwrsBox setContentView: nil];

	if (pathscount == 1) {   // Single Selection
		viewer = [self viewerForFileAtPath: currentPath];
        
    if (currentViewer) {
      stopped = [currentViewer stopTasks];  
      currentViewer = nil;
    }
    
		if (viewer != nil) {
      currentViewer = viewer;
			winName = [viewer winname];
      [(NSBox *)vwrsBox setContentView: viewer];
			[viewer activateForPath: currentPath];
		} else {		
      NSString *appName, *type;
      
      [ws getInfoForFile: [insppaths objectAtIndex: 0] 
             application: &appName type: &type];
      
      currentViewer = nil;
      
      if (type == NSPlainFileType) {
        NSDictionary *attributes = [fm fileAttributesAtPath: [insppaths objectAtIndex: 0] 
                                               traverseLink: NO];
        NSString *fmtype = [attributes fileType];                                       
        
        if (fmtype != NSFileTypeRegular) {
          type = fmtype;
        }
      }
      
      [genericField setStringValue: type];
      [(NSBox *)vwrsBox setContentView: genericView];
			winName = NSLocalizedString(@"Contents Inspector", @"");
		}
		
	} else {	   // Multiple Selection
    if (currentViewer) {
      stopped = [currentViewer stopTasks];
      currentViewer = nil;
    }   
    [(NSBox *)vwrsBox setContentView: noContsView];
		winName = NSLocalizedString(@"Contents Inspector", @"");
	}
	
  w = [inspBox window];	
	[w setTitle: winName];
	[inspBox setNeedsDisplay: YES];
}

- (void)deactivate
{
  [inspBox removeFromSuperview];
}

- (NSString *)inspname
{
	return NSLocalizedString(@"Contents", @"");
}

- (NSString *)winname
{
	return winName;
}

- (id)viewerWithBundlePath:(NSString *)path
{
	int i;
			
	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];		
		if([[vwr bundlePath] isEqual: path]) {
			return vwr;	
    }	
	}

	return nil;
}

- (id)viewerForFileAtPath:(NSString *)path
{
	int i;
  
  if (path == nil) {
    return nil;
  }
  
  if ([fm fileExistsAtPath: path] == NO) {
    return nil;
  }
  
	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];		
		if([vwr canDisplayFileAtPath: path]) {
			return vwr;
    }				
	}

	return nil;
}

- (id)inspView
{
  return inspBox;
}

- (IBAction)doNothing:(id)sender
{
}

- (NSButton *)revertButton
{
	return revertButt;
}

- (NSButton *)okButton
{
	return okButt;
}

@end
