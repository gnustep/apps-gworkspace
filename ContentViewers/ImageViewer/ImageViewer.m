/* ImageViewer.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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
  #ifdef GNUSTEP 
#include "GWProtocol.h"  
#include "InspectorsProtocol.h"
#include "GWLib.h"
  #else
#include <GWorkspace/GWProtocol.h>  
#include <GWorkspace/InspectorsProtocol.h>
#include <GWorkspace/GWLib.h>
  #endif
#include "ImageViewer.h"
#include "GNUstep.h"
#include <math.h>

@implementation ImageViewer

- (void)dealloc
{
  RELEASE (extsarr);
  TEST_RELEASE (imview);
  TEST_RELEASE (widthResult);
  TEST_RELEASE (heightResult);
  RELEASE (label);
  TEST_RELEASE (editPath);	
  RELEASE (bundlePath);
  [super dealloc];
}

- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
  self = [super init];
  
  if(self) {
    NSTextField *widthLabel, *heightLabel;

    [self setFrame: frame];
    panel = (id<InspectorsProtocol>)apanel;
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    
    index = idx;
    
    ASSIGN (extsarr, [GWLib imageExtensions]);
     
    imrect = NSMakeRect(0, 30, 257, 215);
    imview = [[NSImageView alloc] initWithFrame: imrect];
    [imview setImageFrameStyle: NSImageFrameGrayBezel];
    [imview setImageAlignment: NSImageAlignCenter];
    [self addSubview: imview]; 
    
    widthLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(5,2,40, 20)];	
    [widthLabel setAlignment: NSRightTextAlignment];
    [widthLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [widthLabel setBezeled: NO];
    [widthLabel setEditable: NO];
    [widthLabel setSelectable: NO];
    [widthLabel setStringValue: @"Width :"];
    [self addSubview: widthLabel]; 
    RELEASE(widthLabel);

    widthResult = [[NSTextField alloc] initWithFrame: NSMakeRect(45,2,40, 20)];	
    [widthResult setAlignment: NSRightTextAlignment];
    [widthResult setBackgroundColor: [NSColor windowBackgroundColor]];
    [widthResult setBezeled: NO];
    [widthResult setEditable: NO];
    [widthResult setSelectable: NO];
    [widthResult setStringValue: @""];
    [self addSubview: widthResult]; 

    heightLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(160,2,40, 20)];	
    [heightLabel setAlignment: NSRightTextAlignment];
    [heightLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [heightLabel setBezeled: NO];
    [heightLabel setEditable: NO];
    [heightLabel setSelectable: NO];
    [heightLabel setStringValue: @"Height :"];
    [self addSubview: heightLabel]; 
    RELEASE(heightLabel);

    heightResult = [[NSTextField alloc] initWithFrame: NSMakeRect(200,2,40, 20)];	
    [heightResult setAlignment: NSRightTextAlignment];
    [heightResult setBackgroundColor: [NSColor windowBackgroundColor]];
    [heightResult setBezeled: NO];
    [heightResult setEditable: NO];
    [heightResult setSelectable: NO];
    [heightResult setStringValue: @""];
    [self addSubview:heightResult];

    //label if error
    label = [[NSTextField alloc] initWithFrame: NSMakeRect(2, 133, 255, 25)];	
    [label setFont: [NSFont systemFontOfSize: 18]];
    [label setAlignment: NSCenterTextAlignment];
    [label setBackgroundColor: [NSColor windowBackgroundColor]];
    [label setTextColor: [NSColor grayColor]];	
    [label setBezeled: NO];
    [label setEditable: NO];
    [label setSelectable: NO];
    [label setStringValue: @"Invalid Contents"];
    
    valid = YES;
  }
	
	return self;
}

- (void)setBundlePath:(NSString *)path
{
  ASSIGN (bundlePath, path);
}

- (NSString *)bundlePath
{
  return bundlePath;
}

- (void)setIndex:(int)idx
{
  index = idx;
}

- (void)activateForPath:(NSString *)path
{
  NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];
  
  buttOk = [panel okButton];
  if (buttOk) {
    [buttOk setTarget: self];		
    [buttOk setAction: @selector(editFile:)];	
  }
  
  if (image != nil) {
    NSSize is = [image size];
    NSSize rs = imrect.size;
    NSSize size;
        
    ASSIGN (editPath, path);
    
    if (valid == NO) {
      valid = YES;
      [label removeFromSuperview];
      [self addSubview: imview]; 
    }
    
    if ((is.width <= rs.width) && (is.height <= rs.height)) {
      [imview setImageScaling: NSScaleNone];
    } 
    else {
      [imview setImageScaling: NSScaleProportionally];
    }
    
    [imview setImage: image];
    size = [image size];
    [widthResult setStringValue: [[NSNumber numberWithInt: size.width] stringValue]];
    [heightResult setStringValue:[[NSNumber numberWithInt: size.height] stringValue]];
    
    RELEASE (image);
    [buttOk setEnabled: YES];			
  } else {
    if (valid == YES) {
      valid = NO;
      [imview removeFromSuperview];
			[self addSubview: label];
			[buttOk setEnabled: NO];			
    }
  }
}

- (BOOL)stopTasks
{
  return YES;
}

- (void)deactivate
{
  [self removeFromSuperview];
}

- (BOOL)canDisplayFileAtPath:(NSString *)path
{
  NSDictionary *attributes;
	NSString *defApp, *fileType, *extension;

  attributes = [[NSFileManager defaultManager] fileAttributesAtPath: path
                                                       traverseLink: YES];
  if ([attributes objectForKey: NSFileType] == NSFileTypeDirectory) {
    return NO;
  }		
		
	[ws getInfoForFile: path application: &defApp type: &fileType];
	extension = [path pathExtension];
	
  if(([fileType isEqual: NSPlainFileType] == NO)
                  && ([fileType isEqual: NSShellCommandFileType] == NO)) {
		return NO;
	}

  if ([extsarr containsObject: extension]) {
    return YES;
  }

	return NO;
}

- (int)index
{
	return index;
}

- (NSString *)winname
{
	return NSLocalizedString(@"Image Inspector", @"");	
}

- (void)editFile:(id)sender
{
	NSString *appName;
  NSString *type;

  [ws getInfoForFile: editPath application: &appName type: &type];

	if (appName != nil) {
		[ws openFile: editPath withApplication: appName];
	}
}

@end
