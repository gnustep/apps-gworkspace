/* FileOpInfo.m
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
#include "FileOpInfo.h"
#include "GWNet.h"
#include "GWNetFunctions.h"
#include "GNUstep.h"

static NSString *nibName = @"FileOpIndicator";

@implementation FileOpInfo

- (void)dealloc
{
  RELEASE (source);
  RELEASE (destination);
  RELEASE (files);
  TEST_RELEASE (win);
  
  [super dealloc];
}

+ (id)fileOpInfoForViewer:(id)vwr
                     type:(int)tp
                      ref:(int)rf
                   source:(NSString *)src
              destination:(NSString *)dst
                    files:(NSArray *)fls
                usewindow:(BOOL)uwnd
                  winrect:(NSRect)wrect
{
  return AUTORELEASE ([[self alloc] initForViewer: vwr type: tp ref: rf
      source: src destination: dst files: fls usewindow: uwnd winrect: wrect]);
}

- (id)initForViewer:(id)vwr
               type:(int)tp
                ref:(int)rf
             source:(NSString *)src
        destination:(NSString *)dst
              files:(NSArray *)fls
          usewindow:(BOOL)uwnd
            winrect:(NSRect)wrect
{
	self = [super init];

  if (self) {
    viewer = (id <ViewerProtocol>)vwr;
    
    ASSIGN (source, src);
    ASSIGN (destination, dst);
    ASSIGN (files, fls);
        
    type = tp;
    ref = rf;
    
    if (uwnd) {
		  if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
        NSLog(@"failed to load %@!", nibName);
        DESTROY (self);
        return self;
      } else {   
        /* Internationalization */
        [stopButt setTitle: NSLocalizedString(@"Stop", @"")];      

        if (NSEqualRects(wrect, NSZeroRect) == NO) {
          [win setFrame: wrect display: NO];
        } else if ([win setFrameUsingName: @"fopind"] == NO) {
          [win setFrame: NSMakeRect(300, 300, 280, 108) display: NO];
        }
        [self checkWinFrame];
        [win setDelegate: self];  
	    }			
    } else {
      win = nil;
    }
  }
  
	return self;
}

- (void)showWindowWithTitle:(NSString *)title 
                 filesCount:(int)fcount
{
  if (win) {
    if ([win isVisible] == NO) {
      if ((type != DOWNLOAD) && (type != UPLOAD)) {
        NSRect r;
        
        [fileProgInd removeFromSuperview];
        [sizeField removeFromSuperview];
    
        r = [win frame];
        r.size.height -= 22;
        [win setFrame: r display: NO];
    
        r = [nameField frame];
        r.origin.y += 24;
        r.size.width += 50;
        [nameField setFrame: r];

        r = [stopButt frame];
        r.origin.y += 24;
        [stopButt setFrame: r];        
    
      } else {
        [fileProgInd setDoubleValue: 0.0];
      }
    
      [win setTitle: title];
      [globProgInd setMinValue: 0.0];
      [globProgInd setMaxValue: fcount * 1.0];
    }
  
    [win orderFrontRegardless];
  }
}
                 
- (void)updateGlobalProgress:(NSString *)fname
{
  if (win) {
    [nameField setStringValue: cutFileLabelText(fname, nameField, 105)];
    [globProgInd incrementBy: 1.0];
    
    if ((type == DOWNLOAD) || (type == UPLOAD)) {
      [fileProgInd setDoubleValue: 0.0];
      [sizeField setStringValue: @""];
    }
  }
}

- (void)startFileProgress:(int)fsize
{
  if (win) {
    [fileProgInd setMinValue: 0.0];
    [fileProgInd setMaxValue: fsize * 1.0];
    [fileProgInd setDoubleValue: 0.0];
    [sizeField setStringValue: fileSizeDescription(fsize)];
  }
}

- (void)updateFileProgress:(int)increment
{
  if (win) {
    [fileProgInd incrementBy: increment * 1.0];
  }
}

- (IBAction)stopAction:(id)sender
{
  [viewer stopOperation: self];
}

- (void)closeWindow
{
  if (win && [win isVisible]) {
    [self checkWinFrame];
    [win saveFrameUsingName: @"fopind"];
    [win close];
  }
}

- (NSString *)source
{
  return source;
}

- (NSString *)destination
{
  return destination;
}

- (NSArray *)files
{
  return files;
}

- (NSDictionary *)description
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  [dict setObject: source forKey: @"source"];
  [dict setObject: destination forKey: @"destination"];
  [dict setObject: files forKey: @"files"];
  [dict setObject: [NSNumber numberWithInt: ref] forKey: @"ref"];
  [dict setObject: [NSNumber numberWithInt: type] forKey: @"type"];

  return dict;
}

- (int)ref
{
  return ref;
}

- (int)type
{
  return type;
}

- (NSWindow *)win
{
  return win;
}

- (NSRect)winRect
{
  if (win && [win isVisible]) {
    return [win frame];
  }
  return NSZeroRect;
}

- (void)checkWinFrame
{
  NSRect r = [win frame];
        
  if (r.size.height != 108) {
    r.size.height = 108;
    [win setFrame: r display: NO];
  }
}

- (BOOL)windowShouldClose:(id)sender
{
  [self checkWinFrame];
  [win saveFrameUsingName: @"fopind"];
	return YES;
}

@end
