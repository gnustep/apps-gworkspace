/* ClipBookWindow.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2003
 *
 * This file is part of the GNUstep ClipBook application
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
#include "ClipBookWindow.h"
#include "PBViewer.h"
#include "ClipBook.h"
#include "Functions.h"
#include "GNUstep.h"

#define WINHEIGHT 415
#define VWRHEIGHT 300

static NSString *nibName = @"ClipBookWindow.gorm";

@implementation ClipBookWindow

- (void)dealloc
{
	TEST_RELEASE (win);
	TEST_RELEASE (viewersBox);
	TEST_RELEASE (viewer);
	TEST_RELEASE (emptyBox);
	TEST_RELEASE (invalidBox);
	TEST_RELEASE (iconView);
  TEST_RELEASE (pbdir);
  TEST_RELEASE (pbDescrName);
  TEST_RELEASE (pbDescrPath);
  TEST_RELEASE (pbDescr);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
    
  if(self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"ClipBookWindow Controller: failed to load %@!", nibName);
    } else {   
      NSUserDefaults *defaults;
      NSTextField *label;
      NSArray *arr;

      defaults = [NSUserDefaults standardUserDefaults];
      hideContents = [defaults boolForKey: @"hidecontents"];
      
      if ([win setFrameUsingName: @"clipbookwindow"] == NO) {
        NSRect r = [win frame];
        r.origin.x = 200;
        r.origin.x = 300;
        [win setFrame: r display: NO];
      } else {
        if (hideContents == NO) {
          NSRect r = [win frame];
          if (r.size.height != WINHEIGHT) {
            r.size.height = WINHEIGHT;
            [win setFrame: r display: NO];
          }
        }
      }
            
      [win setDelegate: self];  
      clipbook = [ClipBook clipbook];
  	  [win registerForDraggedTypes: [clipbook pbTypes]];
            
      RETAIN (viewersBox);

      if (hideContents) {
        [viewersBox removeFromSuperview];
        [showHideButt setImage: [NSImage imageNamed: @"common_3DArrowRight.tiff"]];
      } else {
        [showHideButt setImage: [NSImage imageNamed: @"common_3DArrowDown.tiff"]];
      }
            
      viewer = [PBViewer new];
      viewerRect = [[viewersBox contentView] frame];

		  emptyBox = [[NSBox alloc] initWithFrame: viewerRect];	
      [emptyBox setBorderType: NSGrooveBorder];
		  [emptyBox setTitlePosition: NSNoTitle];
		  [emptyBox setContentViewMargins: NSMakeSize(0, 0)]; 
      label = [[NSTextField alloc] initWithFrame: NSMakeRect(2, 133, 255, 50)];	
      [label setFont: [NSFont systemFontOfSize: 32]];
      [label setAlignment: NSCenterTextAlignment];
      [label setBackgroundColor: [NSColor windowBackgroundColor]];
      [label setTextColor: [NSColor grayColor]];	
      [label setBezeled: NO];
      [label setEditable: NO];
      [label setSelectable: NO];
      [label setStringValue: NSLocalizedString(@"empty", @"")];
      [emptyBox setContentView: label];
      RELEASE (label);

		  invalidBox = [[NSBox alloc] initWithFrame: viewerRect];	
      [invalidBox setBorderType: NSGrooveBorder];
		  [invalidBox setTitlePosition: NSNoTitle];
		  [invalidBox setContentViewMargins: NSMakeSize(0, 0)]; 
      label = [[NSTextField alloc] initWithFrame: NSMakeRect(2, 133, 255, 25)];	
      [label setFont: [NSFont systemFontOfSize: 18]];
      [label setAlignment: NSCenterTextAlignment];
      [label setBackgroundColor: [NSColor windowBackgroundColor]];
      [label setTextColor: [NSColor grayColor]];	
      [label setBezeled: NO];
      [label setEditable: NO];
      [label setSelectable: NO];
      [label setStringValue: NSLocalizedString(@"Invalid Contents", @"")];
      [invalidBox addSubview: label];
      RELEASE (label);
     
      iconView = [[PBIconView alloc] initWithFrame: [[iconBox contentView] frame]];
      [(NSBox *)iconBox setContentView: iconView];
      
      fm = [NSFileManager defaultManager];
      
      ASSIGN (pbdir, [clipbook pdDir]);
      ASSIGN (pbDescrName, @"pbDescr.plist");
      ASSIGN (pbDescrPath, [pbdir stringByAppendingPathComponent: pbDescrName]);

      if ([fm fileExistsAtPath: pbDescrPath] == NO) {
        if ([[NSArray array] writeToFile: pbDescrPath atomically: YES] == NO) {
          NSLog(@"Can't create the main dictionary! Quitting now.");                                     
          [NSApp terminate: self];
        }
      }

      arr = [NSArray arrayWithContentsOfFile: pbDescrPath];

      if (arr == nil) {
        NSLog(@"invalid array! Quitting now.");                                     
        [fm movePath: pbDescrPath toPath: [pbDescrPath stringByAppendingString: @"_old"] handler: nil];
        [NSApp terminate: self];
      } else {
        pbDescr = [arr mutableCopy];
      }
            
      index = 0;
      isDragTarget = NO;
      [(NSBox *)viewersBox setContentView: emptyBox];
      [self showPbData];
    }
  }
  
  return self;
}

- (void)activate
{
  [win orderFront: nil];
}

- (NSData *)readSelectionFromPasteboard:(NSPasteboard *)pboard 
                                 ofType:(NSString **)pbtype
{
  NSArray *types = [pboard types];
  NSData *data;
  NSString *type;
  int i;
  
  if ((types == nil) || ([types count] == 0)) {
    return nil;
  }

  for (i = 0; i < [types count]; i++) {
    type = [types objectAtIndex: 0];
    data = [pboard dataForType: type];
    if (data) {
      *pbtype = type;
      return data;
    }
  }
  
  return nil;
}

- (void)doCut
{
  NSDictionary *dict = [pbDescr objectAtIndex: index];
  NSString *path = [dict objectForKey: @"path"];

  RETAIN (path);
  [self doCopy];
  [pbDescr removeObjectAtIndex: index];
  [pbDescr writeToFile: pbDescrPath atomically: YES];
  [fm removeFileAtPath: path handler: nil];
  RELEASE (path);
  
  if (index > 0) {
    index--;
  }
  [self showPbData];  
}

- (void)doCopy
{
  NSDictionary *dict = [pbDescr objectAtIndex: index];
  NSString *path = [dict objectForKey: @"path"];
  NSString *type = [dict objectForKey: @"type"];
  NSData *data = [NSData dataWithContentsOfFile: path];

  if (data) {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb declareTypes: [NSArray arrayWithObject: type] owner: self];
    [pb setData: data forType: type];
  }
}

- (void)doPaste
{
  NSData *data;
  NSString *type;
  
  data = [self readSelectionFromPasteboard: [NSPasteboard generalPasteboard]
                                    ofType: &type];
     
  if (data) {
    NSString *dpath = [clipbook pbFilePath];
      
    if ([data writeToFile: dpath atomically: YES]) {
      NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: 
                                        dpath, @"path", type, @"type", nil];

      if (index < [pbDescr count]) {
        index++;
      }          
      [pbDescr insertObject: dict atIndex: index];
      [pbDescr writeToFile: pbDescrPath atomically: YES];
      [self showPbData];
    }
  }
}

- (void)showPbData
{
  [self checkStoredData];

  if ([pbDescr count] == 0) {
    [(NSBox *)viewersBox setContentView: emptyBox];
    [self showPbInfo: nil];
  } else {
    NSDictionary *dict = [pbDescr objectAtIndex: index];
    NSString *path = [dict objectForKey: @"path"];
    NSString *type = [dict objectForKey: @"type"];  
    NSData *data = [NSData dataWithContentsOfFile: path];
  
    if (data) {
      id bpviewer = [viewer viewerForData: data ofType: type];
      
      if (bpviewer) {
        [(NSBox *)viewersBox setContentView: bpviewer];
        [self showPbInfo: dict];
      } else {
        [(NSBox *)viewersBox setContentView: invalidBox];
        [self showPbInfo: nil];
      } 
    }
  }

  [self updateTotalSizeLabels];
}

- (NSData *)currentPBDataOfType:(NSString **)dtype
{
  [self checkStoredData];

  if ([pbDescr count]) {
    NSDictionary *dict = [pbDescr objectAtIndex: index];
    NSString *path = [dict objectForKey: @"path"];
    NSString *type = [dict objectForKey: @"type"];  
    NSData *data = [NSData dataWithContentsOfFile: path];
  
    if (data) {
      *dtype = type;
      return data;
    }
  }

  return nil;
}

- (IBAction)forwardBackwardAction:(id)sender
{
  [self showNext: ((sender == fwdButt) ? YES : NO)];
}

- (void)showNext:(BOOL)fwd
{
  if (fwd) {
    if (index < ([pbDescr count] -1)) {
      index++;
      [self showPbData];
    }
  } else {
    if (index > 0) {
      index--;
      [self showPbData];
    }  
  }  
}

- (void)checkStoredData
{
  NSArray *contents = [fm directoryContentsAtPath: pbdir];
  int count = [pbDescr count];
  BOOL found = NO;
  int i, j;
  
  for (i = count -1; i >= 0; i--) {
    NSDictionary *dict = [pbDescr objectAtIndex: i];
    NSString *dataPath = [dict objectForKey: @"path"];

    if ([fm fileExistsAtPath: dataPath] == NO) {
      [pbDescr removeObjectAtIndex: i];
      found = YES;
    }
  }
  
  if (found) {
    [pbDescr writeToFile: pbDescrPath atomically: YES];
  }
 
  for (i = 0; i < [contents count]; i++) {
    NSString *fname = [contents objectAtIndex: i];
    NSString *fpath = [pbdir stringByAppendingPathComponent: fname];
    
    found = ! [pbDescr count];
    for (j = 0; j < [pbDescr count]; j++) {
      NSDictionary *dict = [pbDescr objectAtIndex: j];
      NSString *dataPath = [dict objectForKey: @"path"];
      
      if ([dataPath isEqual: fpath] || [fpath isEqual: pbDescrPath]) {
        found = YES;
        break;
      }
    }
    
    if (found == NO) {
      [fm removeFileAtPath: fpath handler: nil];
    }
  }
  
  index = (index > ([pbDescr count] -1)) ? ([pbDescr count] -1) : index;
  index = (index < 0) ? 0 : index;
}

- (void)showPbInfo:(NSDictionary *)info
{
  if (info) {
    NSString *type = [info objectForKey: @"type"];
    NSString *path = [info objectForKey: @"path"];
	  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
    unsigned long size = [[attributes objectForKey: NSFileSize] longValue];
    NSString *str;
 
    str = NSLocalizedString(@"index: ", @"");
    str = [str stringByAppendingFormat: @"%i", index];
    [pbIndexField setStringValue: str];
    str = NSLocalizedString(@"size: ", @"");
    str = [str stringByAppendingString: fileSizeDescription(size)];
    [pbSizeField setStringValue: str];
    [pbNameField setStringValue: type];
    
    if ([type isEqual: NSStringPboardType]) {
      [iconView setImage: [NSImage imageNamed: @"stringPboard.tiff"]];
    } else if ([type isEqual: NSRTFPboardType]) {
      [iconView setImage: [NSImage imageNamed: @"rtfPboard.tiff"]];
    } else if ([type isEqual: NSRTFDPboardType]) {
      [iconView setImage: [NSImage imageNamed: @"rtfdPboard.tiff"]];
    } else if ([type isEqual: NSTIFFPboardType]) {
      [iconView setImage: [NSImage imageNamed: @"tiffPboard.tiff"]];
    } else if ([type isEqual: NSFileContentsPboardType]) {
      [iconView setImage: [NSImage imageNamed: @"filecontsPboard.tiff"]];
    } else if ([type isEqual: NSColorPboardType]) {
      [iconView setImage: [NSImage imageNamed: @"colorPboard.tiff"]];
    } else if ([type isEqual: @"IBViewPboardType"]) {
      [iconView setImage: [NSImage imageNamed: @"gormPboard.tiff"]];
    } else {
      [iconView setImage: [NSImage imageNamed: @"Pboard.tiff"]];
    }    
    
  } else {
    [pbIndexField setStringValue: @""];
    [pbNameField setStringValue: @""];
    [pbSizeField setStringValue: @""];
    [iconView setImage: [NSImage imageNamed: @"Pboard.tiff"]];
  }
}

- (void)updateTotalSizeLabels
{
  unsigned long size = 0;
  NSString *str;
  int i;

  for (i = 0; i < [pbDescr count]; i++) {
    NSDictionary *dict = [pbDescr objectAtIndex: i];
    NSString *path = [dict objectForKey: @"path"];
	  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
  	NSNumber *sznum = [attributes objectForKey: NSFileSize];
    
    size += [sznum longValue];
  }
  
  str = fileSizeDescription(size);
  str = [str stringByAppendingString: NSLocalizedString(@" used", @"")];
  [totalSizeField setStringValue: str]; 
  
  str = [NSString stringWithFormat: @"%i %@", [pbDescr count], NSLocalizedString(@" elements", @"")];
  [elementsField setStringValue: str]; 
}

- (IBAction)showHideContents:(id)sender
{
  NSRect r = [win frame];
  
  if (hideContents) {
    r.size.height += VWRHEIGHT;
    [win setFrame: r display: NO];
    [[win contentView] addSubview: viewersBox];
    [showHideButt setImage: [NSImage imageNamed: @"common_3DArrowDown.tiff"]];
    hideContents = NO;
  } else {
    r.size.height -= VWRHEIGHT;
    [viewersBox removeFromSuperview];
    [win setFrame: r display: NO];
    [showHideButt setImage: [NSImage imageNamed: @"common_3DArrowRight.tiff"]];
    hideContents = YES;
  }
}  

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setBool: hideContents forKey: @"hidecontents"];
  [defaults synchronize];
  
  [win saveFrameUsingName: @"clipbookwindow"];
}

- (id)myWin
{
  return win;
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}

@end

@implementation ClipBookWindow (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSArray *types = [pb types];
        
  if (([types indexOfObject: NSStringPboardType] != NSNotFound)
        || ([types indexOfObject: NSRTFPboardType] != NSNotFound)
        || ([types indexOfObject: NSRTFDPboardType] != NSNotFound)
        || ([types indexOfObject: NSTIFFPboardType] != NSNotFound)
        || ([types indexOfObject: NSFileContentsPboardType] != NSNotFound)
        || ([types indexOfObject: NSColorPboardType] != NSNotFound)
        || ([types indexOfObject: @"IBViewPboardType"] != NSNotFound)) {

    isDragTarget = YES;	
    return NSDragOperationCopy;
  }
        
  isDragTarget = NO;	  
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
	if (isDragTarget) {
		return NSDragOperationCopy;
	}
	return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{ 
	isDragTarget = NO;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb = [sender draggingPasteboard];
  NSData *data;
  NSString *type;

  isDragTarget = NO;

  data = [self readSelectionFromPasteboard: pb ofType: &type];

  if (data) {         
    NSString *dpath = [clipbook pbFilePath];
      
    if ([data writeToFile: dpath atomically: YES]) {
      NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: 
                                        dpath, @"path", type, @"type", nil];

      if (index < [pbDescr count]) {
        index++;
      }       
      [pbDescr insertObject: dict atIndex: index];
      [pbDescr writeToFile: pbDescrPath atomically: YES];
      [self showPbData];      
    }
  }
}

@end

@implementation PBIconView

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];
  [self setEditable: NO];
  [self setImageFrameStyle: NSImageFrameNone];
  [self setImageAlignment: NSImageAlignCenter];
  dragdelay = 0;
  
  return self;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if ([theEvent clickCount] == 1) { 
	  NSEvent *nextEvent;
    BOOL startdnd = NO;
   
    while (1) {
	    nextEvent = [[self window] nextEventMatchingMask:
    							              NSLeftMouseUpMask | NSLeftMouseDraggedMask];

      if ([nextEvent type] == NSLeftMouseUp) {
        break;
      } else if ([nextEvent type] == NSLeftMouseDragged) {
	      if(dragdelay < 5) {
          dragdelay++;
        } else {      
          startdnd = YES;        
          break;
        }
      }
    }

    if (startdnd == YES) {  
      [self startExternalDragOnEvent: nextEvent];    
    }    
  }           
}

@end

@implementation PBIconView (DraggingSource)

- (void)startExternalDragOnEvent:(NSEvent *)event
{
  NSPasteboard *pb = [NSPasteboard pasteboardWithName: NSDragPboard];	
  NSPoint dragPoint;
	
  if ([self declareAndSetShapeOnPasteboard: pb]) {
    ICONCENTER (self, [self image], dragPoint);
  	  
    [self dragImage: [self image]
                 at: dragPoint 
             offset: NSZeroSize
              event: event
         pasteboard: pb
             source: self
          slideBack: NO];
  }
}

- (BOOL)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb
{
  NSData *data;
  NSString *type;
  
  data = [(ClipBookWindow *)[[self window] delegate] currentPBDataOfType: &type];
  
  if (data) {
    [pb declareTypes: [NSArray arrayWithObject: type] owner: nil];
    [pb setData: data forType: type];
    return YES;
  }
  
  return NO;
}

- (void)draggedImage:(NSImage *)anImage 
						 endedAt:(NSPoint)aPoint 
					 deposited:(BOOL)flag
{
  dragdelay = 0;
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)flag
{
  return NSDragOperationCopy;
}

@end

