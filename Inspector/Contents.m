/* Contents.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
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
#include <math.h>
#include "Contents.h"
#include "ContentViewersProtocol.h"
#include "Inspector.h"
#include "Functions.h"
#include "FSNodeRep.h"
#include "config.h"

#define ICNSIZE 48

static NSString *nibName = @"Contents";

@implementation Contents

- (void)dealloc
{
  RELEASE (viewers);
  TEST_RELEASE (currentPath);
  TEST_RELEASE (genericView);
  TEST_RELEASE (noContsView);
  TEST_RELEASE (mainBox);
  TEST_RELEASE (pboardImage);
      
	[super dealloc];
}

- (id)initForInspector:(id)insp
{
  self = [super init];
  
  if (self) {
    NSBundle *bundle;
    NSString *imagepath;
    NSString *bundlesDir;
    NSArray *bnames;
    id label;
    unsigned i;
    NSRect r;

    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      [NSApp terminate: self];
    } 

    RETAIN (mainBox);
    RELEASE (win);
    
    inspector = insp;
    viewers = [NSMutableArray new];
    currentPath = nil;

    fm = [NSFileManager defaultManager];	
    ws = [NSWorkspace sharedWorkspace];

    bundle = [NSBundle bundleForClass: [inspector class]];
    imagepath = [bundle pathForResource: @"Pboard" ofType: @"tiff"];
    pboardImage = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
        
    r = [[(NSBox *)viewersBox contentView] frame];

    bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
    bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
    bnames = [fm directoryContentsAtPath: bundlesDir];

    for (i = 0; i < [bnames count]; i++) {
      NSString *bname = [bnames objectAtIndex: i];
    
      if ([[bname pathExtension] isEqual: @"inspector"]) {
        NSString *bpath = [bundlesDir stringByAppendingPathComponent: bname];
        
        bundle = [NSBundle bundleWithPath: bpath]; 
      
        if (bundle) {
          Class principalClass = [bundle principalClass];
        
          if ([principalClass conformsToProtocol: @protocol(ContentViewersProtocol)]) {	
	          CREATE_AUTORELEASE_POOL (pool);
            id vwr = [[principalClass alloc] initWithFrame: r inspector: self];
        
            [viewers addObject: vwr];            
            RELEASE ((id)vwr);	
            RELEASE (pool);		
          }
        }
		  }
    }

    genericView = [[GenericView alloc] initWithFrame: r];					

    noContsView = [[NSView alloc] initWithFrame: r];
    MAKE_LOCALIZED_LABEL (label, NSMakeRect(2, 125, 254, 65), @"No Contents Inspector", @"", 'c', YES, noContsView);		  
    [label setFont: [NSFont systemFontOfSize: 18]];
    [label setTextColor: [NSColor grayColor]];				

    currentViewer = nil;
  }
  
  return self;
}

- (NSView *)inspView
{
  return mainBox;
}

- (NSString *)winname
{
  return NSLocalizedString(@"Contents Inspector", @"");
}

- (void)activateForPaths:(NSArray *)paths
{
  if ([paths count] == 1) {
    [self showContentsAt: [paths objectAtIndex: 0]];
    
  } else {
    NSImage *icon = [[FSNodeRep sharedInstance] multipleSelectionIconOfSize: ICNSIZE];
    NSString *items = NSLocalizedString(@"items", @"");
    
    items = [NSString stringWithFormat: @"%i %@", [paths count], items];
		[titleField setStringValue: items];  
    [iconView setImage: icon];
    
    [(NSBox *)viewersBox setContentView: noContsView];
    currentViewer = noContsView;
    
    if (currentPath) {
      [inspector removeWatcherForPath: currentPath];
      DESTROY (currentPath);
    }    
	
	  [[inspector win] setTitle: [self winname]];    
  }
}

- (id)viewerForPath:(NSString *)path
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
		if ([vwr canDisplayPath: path]) {
			return vwr;
    }				
	}

	return nil;
}

- (id)viewerForDataOfType:(NSString *)type
{
  int i;
  
	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];		
    
    if ([vwr respondsToSelector: @selector(canDisplayDataOfType:)]) {
      if ([vwr canDisplayDataOfType: type]) {
			  return vwr;
      }
    } 				
	}
  
  return nil;
}

- (void)showContentsAt:(NSString *)path
{
	NSString *winName;

  if (currentViewer) {
    if ([currentViewer conformsToProtocol: @protocol(ContentViewersProtocol)]) {
      [currentViewer stopTasks];  
    }
  }   
    	      
	if (path && [fm fileExistsAtPath: path]) {
		id viewer = [self viewerForPath: path];

    if (currentPath && ([currentPath isEqual: path] == NO)) {
      [inspector removeWatcherForPath: currentPath];
      DESTROY (currentPath);
    }
        
		if (viewer) {
      currentViewer = viewer;
      winName = [viewer winname];
      [(NSBox *)viewersBox setContentView: viewer];
    
      if ([path isEqual: [viewer currentPath]]) {
        [viewer displayLastPath: NO];
      } else {
			  [viewer displayPath: path];
      }
		} else {
      FSNode *node = [FSNode nodeWithPath: path];
      NSImage *icon = [[FSNodeRep sharedInstance] iconOfSize: ICNSIZE forNode: node];

      [iconView setImage: icon];
      [titleField setStringValue: [node name]];

      [(NSBox *)viewersBox setContentView: genericView];
      currentViewer = genericView;
      [genericView showInfoOfPath: path];
      
			winName = NSLocalizedString(@"Contents Inspector", @"");
    }
		
	} else {  
    [iconView setImage: nil];
    [titleField setStringValue: @""];
    [(NSBox *)viewersBox setContentView: noContsView];
    currentViewer = noContsView;
		winName = NSLocalizedString(@"Contents Inspector", @"");
    
    if (currentPath) {
      [inspector removeWatcherForPath: currentPath];
      DESTROY (currentPath);
    }    
	}
	
	[[inspector win] setTitle: winName];
}

- (void)contentsReadyAt:(NSString *)path
{
  FSNode *node = [FSNode nodeWithPath: path];
  NSImage *icon = [[FSNodeRep sharedInstance] iconOfSize: ICNSIZE forNode: node];

  [iconView setImage: icon];
  [titleField setStringValue: [node name]];

  if (currentPath == nil) {
    ASSIGN (currentPath, path); 
    [inspector addWatcherForPath: currentPath];
  }
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return ([self viewerForDataOfType: type] != nil);
}

- (void)showData:(NSData *)data 
          ofType:(NSString *)type
{
	NSString *winName;
	id viewer;

  if (currentViewer) {
    if ([currentViewer conformsToProtocol: @protocol(ContentViewersProtocol)]) {
      [currentViewer stopTasks]; 
    }
  }   

  if (currentPath) {
    [inspector removeWatcherForPath: currentPath];
    DESTROY (currentPath);
  }
  
  viewer = [self viewerForDataOfType: type];
  
	if (viewer) {   
    currentViewer = viewer;
    winName = [viewer winname];
    [(NSBox *)viewersBox setContentView: viewer];
    [viewer displayData: data ofType: type];

	} else {	   
    [iconView setImage: pboardImage];
    [titleField setStringValue: @""];  
    [(NSBox *)viewersBox setContentView: noContsView];
    currentViewer = noContsView;
	  winName = NSLocalizedString(@"Data Inspector", @"");
  }
	
	[[inspector win] setTitle: winName];
	[viewersBox setNeedsDisplay: YES];
}

- (void)dataContentsReadyForType:(NSString *)typeDescr
                         useIcon:(NSImage *)icon
{
  [iconView setImage: icon];
  [titleField setStringValue: typeDescr];
}


- (void)watchedPathDidChange:(NSDictionary *)info
{
  NSString *path = [info objectForKey: @"path"];
  NSString *event = [info objectForKey: @"event"];

  if (currentPath && [currentPath isEqual: path]) {
    if ([event isEqual: @"GWWatchedFileDeleted"]) {
      [self showContentsAt: nil];

    } else if ([event isEqual: @"GWWatchedFileModified"]) {
      if (currentViewer 
              && [currentViewer conformsToProtocol: @protocol(ContentViewersProtocol)]) {
        if ([currentPath isEqual: [currentViewer currentPath]]) {
          [currentViewer displayLastPath: YES];
        }
      }
    }
  }
}

@end


@implementation GenericView

- (void)dealloc
{
  [nc removeObserver: self];
  if (task && [task isRunning]) {
    [task terminate];
	}
  TEST_RELEASE (task);
  TEST_RELEASE (pipe);
  TEST_RELEASE (shComm);
  TEST_RELEASE (fileComm);  
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame: frameRect];
	
	if (self) {	
    NSString *comm;
    NSRect r;
          
    shComm = nil;      
    fileComm = nil;  
        
    comm = [NSString stringWithCString: SHPATH];
    if ([comm isEqual: @"none"] == NO) {
      ASSIGN (shComm, comm);
    } 
    comm = [NSString stringWithCString: FILEPATH];
    if ([comm isEqual: @"none"] == NO) {
      ASSIGN (fileComm, comm);
    }
    
		nc = [NSNotificationCenter defaultCenter];
    
    r = NSMakeRect(0, 60, frameRect.size.width, 140);
    textview = [[NSTextView alloc] initWithFrame: r];
    [[textview textContainer] setContainerSize: [textview frame].size];
		[textview setDrawsBackground: NO];
    [textview setRichText: NO];
    [textview setSelectable: NO];
    [textview setVerticallyResizable: NO];
    [textview setHorizontallyResizable: NO];
    
    [self addSubview: textview];
    RELEASE (textview);
	}
	
	return self;
}

- (void)showInfoOfPath:(NSString *)path
{
  [self showString: @""];

  if (shComm && fileComm) {  
    CREATE_AUTORELEASE_POOL (pool);
    NSString *str;
	  NSFileHandle *handle;  
  
    [nc removeObserver: self];
    if (task && [task isRunning]) {
		  [task terminate];
	  }
    DESTROY (task);		
    
    task = [NSTask new]; 
    [task setLaunchPath: shComm];
    str = [NSString stringWithFormat: @"%@ -b %@", fileComm, path];
    [task setArguments: [NSArray arrayWithObjects: @"-c", str, nil]];
    ASSIGN (pipe, [NSPipe pipe]);
    [task setStandardOutput: pipe];

    handle = [pipe fileHandleForReading];
    [nc addObserver: self
    		   selector: @selector(dataFromTask:)
    				   name: NSFileHandleReadToEndOfFileCompletionNotification
    			   object: handle];

    [handle readToEndOfFileInBackgroundAndNotify];    

    [task launch];   
       
    RELEASE (pool);   
  } else {  
    [self showString: NSLocalizedString(@"No Contents Inspector", @"")];
  }        
}

- (void)dataFromTask:(NSNotification *)notif
{
  CREATE_AUTORELEASE_POOL (pool);
  NSDictionary *userInfo = [notif userInfo];
  NSData *data = [userInfo objectForKey: NSFileHandleNotificationDataItem];
  NSString *str;
  
  if (data && [data length]) {
    str = [[NSString alloc] initWithData: data 
                                encoding: [NSString defaultCStringEncoding]];
  } else {
    str = [[NSString alloc] initWithString: NSLocalizedString(@"No Contents Inspector", @"")];
  }
  
  [self showString: str];
  
  RELEASE (str);
  RELEASE (pool);   
}

- (void)showString:(NSString *)str
{
  CREATE_AUTORELEASE_POOL (pool);
  NSAttributedString *attrstr = [[NSAttributedString alloc] initWithString: str];      
  NSRange range = NSMakeRange(0, [attrstr length]);
  NSTextStorage *storage = [textview textStorage];
  NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
  
  [storage setAttributedString: attrstr];
  
  [style setParagraphStyle: [NSParagraphStyle defaultParagraphStyle]];   
  [style setAlignment: NSCenterTextAlignment];
  
  [storage addAttribute: NSParagraphStyleAttributeName 
                  value: style 
                  range: range];
  
  [storage addAttribute: NSFontAttributeName 
                  value: [NSFont systemFontOfSize: 18] 
                  range: range];

	[storage addAttribute: NSForegroundColorAttributeName 
										value: [NSColor darkGrayColor] 
										range: range];			

  RELEASE (attrstr);
  RELEASE (style);
  RELEASE (pool);   
}

@end





