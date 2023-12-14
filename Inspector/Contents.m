/* Contents.m
 *  
 * Copyright (C) 2004-2023 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Author: Riccardo Mottola <rm@gnu.org>
 *
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <math.h>
#include "config.h"

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Contents.h"
#import "ContentViewersProtocol.h"
#import "Inspector.h"
#import "IconView.h"
#import "Functions.h"
#import "FSNodeRep.h"

#define ICNSIZE 48
#define MAXDATA 1000

#if defined(__MINGW__)
#define SHPATH "/bin/sh"
#define FILEPATH "/bin/file"
#endif

static NSString *nibName = @"Contents";

@implementation Contents

- (void)dealloc
{
  RELEASE (viewers);
  RELEASE (currentPath);
  RELEASE (genericView);
  RELEASE (noContsView);
  RELEASE (textViewer);
  RELEASE (mainBox);
  RELEASE (pboardImage);
      
  [super dealloc];
}

- (id)initForInspector:(id)insp
{
  self = [super init];
  
  if (self)
    {
      NSBundle *bundle;
      NSEnumerator *enumerator;
      NSString *imagepath;
      NSString *bundlesDir;
      NSArray *bnames;
      id label;
      unsigned i;
      NSRect r;

      if ([NSBundle loadNibNamed: nibName owner: self] == NO)
        {
          NSLog(@"failed to load %@!", nibName);
          [NSApp terminate: self];
        }

      RETAIN (mainBox);
      RELEASE (win);

      inspector = insp;
      [iconView setInspector: inspector];
      viewers = [NSMutableArray new];
      currentPath = nil;

      fm = [NSFileManager defaultManager];
      ws = [NSWorkspace sharedWorkspace];

      bundle = [NSBundle bundleForClass: [inspector class]];
      imagepath = [bundle pathForResource: @"Pboard" ofType: @"tiff"];
      pboardImage = [[NSImage alloc] initWithContentsOfFile: imagepath];

      r = [[viewersBox contentView] bounds];

      enumerator = [NSSearchPathForDirectoriesInDomains
                     (NSLibraryDirectory, NSAllDomainsMask, YES) objectEnumerator];
      while ((bundlesDir = [enumerator nextObject]) != nil)
        {
          bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
          bnames = [fm directoryContentsAtPath: bundlesDir];

          for (i = 0; i < [bnames count]; i++)
            {
              NSString *bname = [bnames objectAtIndex: i];
	
              if ([[bname pathExtension] isEqual: @"inspector"])
                {
                  NSString *bpath = [bundlesDir stringByAppendingPathComponent: bname];

                  bundle = [NSBundle bundleWithPath: bpath];

                  if (bundle)
                    {
                      Class principalClass = [bundle principalClass];

                      if ([principalClass conformsToProtocol: @protocol(ContentViewersProtocol)])
                        {
                          CREATE_AUTORELEASE_POOL (pool);
                          id vwr = [[principalClass alloc] initWithFrame: r inspector: self];

                          [viewers addObject: vwr];
                          [vwr release];
                          RELEASE (pool);
                        }
                    }
                }
            }
        }

    // We reorter viewers and put the ImageViewer at the end, so that specialized viewers,
    // e.g. PDF Viewer, can take precedence
    // String comparison, so no class import is needed
    for (i = 0; i < [viewers count]; i++)
      {
        id vwr = [viewers objectAtIndex: i];

        if ([NSStringFromClass([vwr class]) isEqualToString:@"ImageViewer"])
          {
            [viewers removeObjectAtIndex: i];
            [viewers addObject: vwr];
            break;
          }
      }

    textViewer = [[TextViewer alloc] initWithFrame: r forInspector: self];					
    genericView = [[GenericView alloc] initWithFrame: r];					

    noContsView = [[NSView alloc] initWithFrame: r];
    MAKE_LABEL (label, NSMakeRect(2, 125, 254, 65), _(@"No Contents Inspector"), 'c', YES, noContsView);		  
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
    
    items = [NSString stringWithFormat: @"%lu %@", (unsigned long)[paths count], items];
		[titleField setStringValue: items];  
    [iconView setImage: icon];
    
    [viewersBox setContentView: noContsView];
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
  NSInteger i;
  
  if ((path == nil) || ([fm fileExistsAtPath: path] == NO)) {
    return nil;
  }
    
  for (i = 0; i < [viewers count]; i++)
    {
      id vwr = [viewers objectAtIndex: i];		
      if ([vwr canDisplayPath: path])
        {
          return vwr;
        }				
    }
  
  return nil;
}

- (id)viewerForDataOfType:(NSString *)type
{
  NSUInteger i;
  
  for (i = 0; i < [viewers count]; i++)
    {
      id vwr = [viewers objectAtIndex: i];		
      
      if ([vwr respondsToSelector: @selector(canDisplayDataOfType:)])
        {
          if ([vwr canDisplayDataOfType: type])
            {
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
    if ([currentViewer respondsToSelector: @selector(stopTasks)]) {
      [currentViewer stopTasks];  
    }
  }   
    	      
  if (path && [fm fileExistsAtPath: path])
    {
      id viewer = [self viewerForPath: path];

    if (currentPath && ([currentPath isEqual: path] == NO)) {
      [inspector removeWatcherForPath: currentPath];
      DESTROY (currentPath);
    }
        
		if (viewer) {
      currentViewer = viewer;
      winName = [viewer winname];
      [viewersBox setContentView: viewer];
    
      [viewer displayPath: path];
		} else {
      FSNode *node = [FSNode nodeWithPath: path];
      NSImage *icon = [[FSNodeRep sharedInstance] iconOfSize: ICNSIZE forNode: node];

      [iconView setImage: icon];
      [titleField setStringValue: [node name]];

      if ([textViewer tryToDisplayPath: path]) {
        [viewersBox setContentView: textViewer];
        currentViewer = textViewer;
			  winName = NSLocalizedString(@"Text Inspector", @"");      
        if (currentPath == nil) {
          ASSIGN (currentPath, path); 
          [inspector addWatcherForPath: currentPath];
        }
        
      } else {
        [viewersBox setContentView: genericView];
        currentViewer = genericView;
        [genericView showInfoOfPath: path];
			  winName = NSLocalizedString(@"Contents Inspector", @"");
      }  
    }
		
	} else {  
    [iconView setImage: nil];
    [titleField setStringValue: @""];
    [viewersBox setContentView: noContsView];
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
    if ([currentViewer respondsToSelector: @selector(stopTasks)]) {
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
    [viewersBox setContentView: viewer];
    [viewer displayData: data ofType: type];

	} else {	   
    [iconView setImage: pboardImage];
    [titleField setStringValue: @""];  
    [viewersBox setContentView: noContsView];
    currentViewer = noContsView;
	  winName = NSLocalizedString(@"Data Inspector", @"");
  }
	
	[[inspector win] setTitle: winName];
	[viewersBox setNeedsDisplay: YES];
}

- (BOOL)isShowingData
{
  return (currentPath == nil);
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
    if ([event isEqual: @"GWWatchedPathDeleted"]) {
      [self showContentsAt: nil];

    } else if ([event isEqual: @"GWWatchedFileModified"]) {
      if (currentViewer) {
        if ([currentViewer respondsToSelector: @selector(displayPath:)]) {
          [currentViewer displayPath: currentPath];
        } else if (currentViewer == textViewer) {
          [currentViewer tryToDisplayPath: currentPath];
        }
      }
    }
  }
}

- (id)inspector
{
  return inspector;
}

@end


@implementation TextViewer

- (void)dealloc
{
  RELEASE (editPath);	
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
       forInspector:(id)insp
{
  self = [super initWithFrame: frameRect];
  
  if (self) {
    NSRect r = [self bounds];
        
    r.origin.y += 45;
    r.size.height -= 45;
    scrollView = [[NSScrollView alloc] initWithFrame: r];
    [scrollView setBorderType: NSBezelBorder];
    [scrollView setHasHorizontalScroller: NO];
    [scrollView setHasVerticalScroller: YES]; 
    [scrollView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[scrollView contentView] setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[scrollView contentView] setAutoresizesSubviews: YES];
    [self addSubview: scrollView]; 
    RELEASE (scrollView);
    
    r = [[scrollView contentView] bounds];
    textView = [[NSTextView alloc] initWithFrame: r];
    [textView setBackgroundColor: [NSColor whiteColor]];
    [textView setRichText: YES];
    [textView setEditable: NO];
    [textView setSelectable: NO];
    [textView setHorizontallyResizable: NO];
    [textView setVerticallyResizable: YES];
    [textView setMinSize: NSMakeSize (0, 0)];
    [textView setMaxSize: NSMakeSize (1E7, 1E7)];
    [textView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[textView textContainer] setContainerSize: NSMakeSize(r.size.width, 1e7)];
    [[textView textContainer] setWidthTracksTextView: YES];
    [textView setUsesRuler: NO];
    [scrollView setDocumentView: textView];
    RELEASE (textView);
    
    r.origin.x = 141;
    r.origin.y = 10;
    r.size.width = 115;
    r.size.height = 25;
	  editButt = [[NSButton alloc] initWithFrame: r];
	  [editButt setButtonType: NSMomentaryLight];
    [editButt setImage: [NSImage imageNamed: @"common_ret.tiff"]];
    [editButt setImagePosition: NSImageRight];
	  [editButt setTitle: NSLocalizedString(@"Edit", @"")];
	  [editButt setTarget: self];
	  [editButt setAction: @selector(editFile:)];	
    [editButt setEnabled: NO];		
		[self addSubview: editButt]; 
    RELEASE (editButt);
    
    contsinsp = insp;
    editPath = nil;
    ws = [NSWorkspace sharedWorkspace];
  }
	
	return self;
}

- (BOOL)tryToDisplayPath:(NSString *)path
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: YES];
  
  DESTROY (editPath);
  [editButt setEnabled: NO];	

  if (attributes && ([attributes fileType] != NSFileTypeDirectory)) {
	  NSString *app = nil, *type = nil;
    
    [ws getInfoForFile: path application: &app type: &type];
    
    if (type && ((type == NSPlainFileType) || (type == NSShellCommandFileType))) {
      NSData *data = [self textContentsAtPath: path withAttributes: attributes];

      if (data) {
        CREATE_AUTORELEASE_POOL (pool);
        NSString *str = [[NSString alloc] initWithData: data
                                  encoding: [NSString defaultCStringEncoding]];
        NSAttributedString *attrstr = [[NSAttributedString alloc] initWithString: str];

        [[textView textStorage] setAttributedString: attrstr];
		    [[textView textStorage] addAttribute: NSFontAttributeName 
                                       value: [NSFont systemFontOfSize: 8.0] 
                                       range: NSMakeRange(0, [attrstr length])];
        RELEASE (str);
        RELEASE (attrstr);
        [editButt setEnabled: YES];			
        ASSIGN (editPath, path);
        RELEASE (pool);

        return YES;
      }
    }
  }                                                     
    
  return NO;
}

- (NSData *)textContentsAtPath:(NSString *)path 
                withAttributes:(NSDictionary *)attributes
{
  unsigned long long nbytes = [attributes fileSize];
  NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath: path];
  NSData *data;
    
  nbytes = ((nbytes > MAXDATA) ? MAXDATA : nbytes);
  
  NS_DURING
    {
      data = [handle readDataOfLength: nbytes];
    }
  NS_HANDLER
    {
      [handle closeFile];
	    return nil;
    }
  NS_ENDHANDLER
  
  [handle closeFile];
  
  if (data) {
    const char *bytes = [data bytes];
    int i;
    
    for (i = 0; i < nbytes; i++) {
      if (!isascii(bytes[i])) {
        return nil;
      }
    }
    
    return data;
  }

  return nil;
}

- (void)editFile:(id)sender
{
  if (editPath) {
    [[[contsinsp inspector] desktopApp] openFile: editPath];
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
  RELEASE (task);
  RELEASE (pipe);
  RELEASE (shComm);
  RELEASE (fileComm);  
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
    [[textview textContainer] setContainerSize: [textview bounds].size];
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
    str = [NSString stringWithFormat: @"%@ -b \"%@\"", fileComm, path];
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





