/* Inspector.m
 *  
 * Copyright (C) 2004-2013 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "Inspector.h"
#import "ContentViewersProtocol.h"
#import "Contents.h"
#import "Attributes.h"
#import "Tools.h"
#import "Annotations.h"
#import "IconView.h"
#import "Functions.h"

#define ATTRIBUTES   0
#define CONTENTS     1
#define TOOLS        2
#define ANNOTATIONS  3

static NSString *nibName = @"InspectorWin";

@implementation Inspector

- (void)dealloc
{
  [nc removeObserver: self];
  RELEASE (watchedPath);
  RELEASE (currentPaths);
  RELEASE (inspectors);
  RELEASE (win);
   
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSString *appName = [defaults stringForKey: @"DesktopApplicationName"];
    NSString *selName = [defaults stringForKey: @"DesktopApplicationSelName"];
  
    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    } 
    
    if (appName && selName) {
		  Class desktopAppClass = [[NSBundle mainBundle] classNamed: appName];
      SEL sel = NSSelectorFromString(selName);
      desktopApp = [desktopAppClass performSelector: sel];
    }
   
    [win setFrameUsingName: @"inspector"];
    [win setDelegate: self];
  
    inspectors = [NSMutableArray new];
    watchedPath = nil;
    currentPaths = nil;
    nc = [NSNotificationCenter defaultCenter];

    while ([[popUp itemArray] count] > 0) {
      [popUp removeItemAtIndex: 0];
    }

    currentInspector = [[Attributes alloc] initForInspector: self];
    [inspectors insertObject: currentInspector atIndex: ATTRIBUTES]; 
    [popUp insertItemWithTitle: NSLocalizedString(@"Attributes", @"") 
                       atIndex: ATTRIBUTES];
    [[popUp itemAtIndex: ATTRIBUTES] setKeyEquivalent: @"1"];
    DESTROY (currentInspector);

    currentInspector = [[Contents alloc] initForInspector: self];
    [inspectors insertObject: currentInspector atIndex: CONTENTS]; 
    [popUp insertItemWithTitle: NSLocalizedString(@"Contents", @"") 
                       atIndex: CONTENTS];
    [[popUp itemAtIndex: CONTENTS] setKeyEquivalent: @"2"];
    DESTROY (currentInspector);

    currentInspector = [[Tools alloc] initForInspector: self];
    [inspectors insertObject: currentInspector atIndex: TOOLS]; 
    [popUp insertItemWithTitle: NSLocalizedString(@"Tools", @"") 
                       atIndex: TOOLS];
    [[popUp itemAtIndex: TOOLS] setKeyEquivalent: @"3"];
    DESTROY (currentInspector);

    currentInspector = [[Annotations alloc] initForInspector: self];
    [inspectors insertObject: currentInspector atIndex: ANNOTATIONS]; 
    [popUp insertItemWithTitle: NSLocalizedString(@"Annotations", @"") 
                       atIndex: ANNOTATIONS];
    [[popUp itemAtIndex: ANNOTATIONS] setKeyEquivalent: @"4"];
    DESTROY (currentInspector);

    [nc addObserver: self 
           selector: @selector(watcherNotification:) 
               name: @"GWFileWatcherFileDidChangeNotification"
             object: nil];    
  }
  
  return self;
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];

  if (currentInspector == nil) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id entry = [defaults objectForKey: @"last_active_inspector"];
    int index = 0;
    
    if (entry) {
      index = [entry intValue];
      index = ((index < 0) ? 0 : index);
    }
    
    [popUp selectItemAtIndex: index];
    [self activateInspector: popUp];
  }
}

- (void)setCurrentSelection:(NSArray *)selection
{
  if (selection) {
    ASSIGN (currentPaths, selection);
    if (currentInspector) {
      [currentInspector activateForPaths: currentPaths];
    }
  }
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return [[self contents] canDisplayDataOfType: type];
}

- (void)showData:(NSData *)data 
          ofType:(NSString *)type
{
  [[self contents] showData: data ofType: type];
}

- (IBAction)activateInspector:(id)sender
{
  id insp = [inspectors objectAtIndex: [sender indexOfSelectedItem]];
  
	if (currentInspector != insp) {
    currentInspector = insp;
	  [win setTitle: [insp winname]];
	  [inspBox setContentView: [insp inspView]];	 
	}
  
  if (currentPaths) {
	  [insp activateForPaths: currentPaths];
  }
}

- (void)showAttributes
{
  if ([win isVisible] == NO) {
    [self activate];
  }
  [popUp selectItemAtIndex: ATTRIBUTES];
  [self activateInspector: popUp];
}

- (id)attributes
{
  return [inspectors objectAtIndex: ATTRIBUTES];
}

- (void)showContents
{
  if ([win isVisible] == NO) {
    [self activate];
  }
  [popUp selectItemAtIndex: CONTENTS];
  [self activateInspector: popUp];
}

- (id)contents
{
  return [inspectors objectAtIndex: CONTENTS];
}

- (void)showTools
{
  if ([win isVisible] == NO) {
    [self activate];
  }
  [popUp selectItemAtIndex: TOOLS];
  [self activateInspector: popUp];
}

- (id)tools
{
  return [inspectors objectAtIndex: TOOLS];
}

- (void)showAnnotations
{
  if ([win isVisible] == NO) {
    [self activate];
  }
  [popUp selectItemAtIndex: ANNOTATIONS];
  [self activateInspector: popUp];
}

- (id)annotations
{
  return [inspectors objectAtIndex: ANNOTATIONS];
}

- (NSWindow *)win
{
  return win;
}

- (void)updateDefaults
{
  NSNumber *index = [NSNumber numberWithInt: [popUp indexOfSelectedItem]];

  [[NSUserDefaults standardUserDefaults] setObject: index 
                                            forKey: @"last_active_inspector"];
  [[self attributes] updateDefaults];
  [win saveFrameUsingName: @"inspector"];
}

- (BOOL)windowShouldClose:(id)sender
{
  [win saveFrameUsingName: @"inspector"];
	return YES;
}

- (void)addWatcherForPath:(NSString *)path
{
  if ((watchedPath == nil) || ([watchedPath isEqual: path] == NO)) {
    [desktopApp addWatcherForPath: path];
    ASSIGN (watchedPath, path);
  }
}

- (void)removeWatcherForPath:(NSString *)path
{
  if (watchedPath && [watchedPath isEqual: path]) {
    [desktopApp removeWatcherForPath: path];
    DESTROY (watchedPath);
  }
}

- (void)watcherNotification:(NSNotification *)notif
{
  NSDictionary *info = (NSDictionary *)[notif object];
  NSString *path = [info objectForKey: @"path"];
  
  if (watchedPath && [watchedPath isEqual: path]) {
    int i;

    for (i = 0; i < [inspectors count]; i++) {
      [[inspectors objectAtIndex: i] watchedPathDidChange: info];
    }
  }
}

- (id)desktopApp
{
  return desktopApp;
}

@end


@implementation Inspector (CustomDirectoryIcons)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
                        inIconView:(IconView *)iview
{
  FSNode *dstnode;

  [iview setDndTarget: NO];

  if ((currentPaths == nil) || ([currentPaths count] > 1)) {
    return NSDragOperationNone;
  } 

  dstnode = [FSNode nodeWithPath: [currentPaths objectAtIndex: 0]];
  
  if ([dstnode isWritable] == NO) {
    return NSDragOperationNone;
  }
  if (([dstnode isDirectory] == NO) || [dstnode isPackage]) {
    return NSDragOperationNone;
  }

  if ([NSImage canInitWithPasteboard: [sender draggingPasteboard]]) {
    [iview setDndTarget: YES];
    return NSDragOperationAll;
  }    
  
  return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
            inIconView:(IconView *)iview
{
  [iview setDndTarget: NO];
}

#define TMBMAX (48.0)
#define RESZLIM 4

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender 
                   inIconView:(IconView *)iview
{
  CREATE_AUTORELEASE_POOL(arp);
  NSPasteboard *pb = [sender draggingPasteboard];  
  NSImage *image = [[NSImage alloc] initWithPasteboard: pb];
  NSData *data = nil;

  if (image && [image isValid]) {
    NSSize size = [image size];
    NSImageRep *rep = [image bestRepresentationForDevice: nil];

    if ((size.width <= TMBMAX) && (size.height <= TMBMAX) 
                            && (size.width >= (TMBMAX - RESZLIM)) 
                                    && (size.height >= (TMBMAX - RESZLIM))) {
 	    if ([rep isKindOfClass: [NSBitmapImageRep class]]) {
        data = [(NSBitmapImageRep *)rep TIFFRepresentation];
      }
    }
  
    if (data == nil) {
      NSRect srcr = NSMakeRect(0, 0, size.width, size.height);
	    NSRect dstr = NSZeroRect;  
      NSImage *newimage = nil;
      NSBitmapImageRep *newBitmapImageRep = nil;

      if (size.width >= size.height) {
        dstr.size.width = TMBMAX;
        dstr.size.height = TMBMAX * size.height / size.width;
      } else {
        dstr.size.height = TMBMAX;
        dstr.size.width = TMBMAX * size.width / size.height;
      }  

      newimage = [[NSImage alloc] initWithSize: dstr.size];
      [newimage lockFocus];

      [image drawInRect: dstr 
               fromRect: srcr 
              operation: NSCompositeSourceOver 
               fraction: 1.0];

      newBitmapImageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: dstr];
      [newimage unlockFocus];

      data = [newBitmapImageRep TIFFRepresentation];
      
      RELEASE (newimage);  
      RELEASE (newBitmapImageRep);
    }
    
  } 

  [image release];

  if (data) {  
    NSString *dirpath = [currentPaths objectAtIndex: 0];
    NSString *imgpath = [dirpath stringByAppendingPathComponent: @".dir.tiff"];
    
    if ([data writeToFile: imgpath atomically: YES]) {
      NSMutableDictionary *info = [NSMutableDictionary dictionary];
      
      [info setObject: dirpath forKey: @"path"];
      [info setObject: imgpath forKey: @"icon_path"];      
      
	    [[NSDistributedNotificationCenter defaultCenter] 
            postNotificationName: @"GWCustomDirectoryIconDidChangeNotification"
	 								        object: nil 
                        userInfo: info];
    }
  }

  [iview setDndTarget: NO];

  RELEASE (arp);
}

@end



