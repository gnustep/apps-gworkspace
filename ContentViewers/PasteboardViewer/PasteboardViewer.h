/* PasteboardViewer.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: Octomber 2003
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

#ifndef PASTEBOARDVIEWER_H
#define PASTEBOARDVIEWER_H

  #ifdef GNUSTEP 
#include "ContentViewersProtocol.h"
  #else
#include <GWorkspace/ContentViewersProtocol.h>
  #endif

@class NSString;
@class NSArray;
@class NSImageView;
@class NSTextField;
@class NSAttributedString;
@class NSTextView;
@class NSScrollView;
@class NSRTFPboardViewer;
@class NSTIFFPboardViewer;
@class NSColorboardViewer;
@class IBViewPboardViewer;

@interface PasteboardViewer : NSView <ContentViewersProtocol>
{
  id panel;
  NSTextField *label;
  id buttOk;
  int index;
  NSString *bundlePath;
  NSRTFPboardViewer *RTFViewer;
  NSTIFFPboardViewer *TIFFViewer;
  NSColorboardViewer *ColorViewer;
  IBViewPboardViewer *IBViewViewer;
  id currentViewer;
}

@end

@interface NSRTFPboardViewer : NSView 
{
  NSScrollView *scrollView;
  NSTextView *textView;
}

- (BOOL)displayData:(NSData *)data 
             ofType:(NSString *)type;

@end

@interface NSTIFFPboardViewer : NSView 
{
  NSImageView *imview;
  NSRect imrect;
  NSTextField *widthResult, *heightResult;
}

- (BOOL)displayData:(NSData *)data 
             ofType:(NSString *)type;

@end

@interface NSColorboardViewer : NSView 
{
  NSRect colorRect;
  NSColor *color;
  NSTextField *redField, *greenField, *blueField, *alphaField;
}

- (BOOL)displayData:(NSData *)data 
             ofType:(NSString *)type;

@end

@interface CustomView : NSTextField
{
}

- (void)setClassName:(NSString *)aName;
- (NSString *)className;

@end

@interface GormNSBrowser : NSBrowser
@end

@interface GormNSTableView : NSTableView
@end

@interface GormNSOutlineView : NSOutlineView
@end

@interface GormNSMenu : NSMenu
@end

@interface GormNSPopUpButtonCell : NSPopUpButtonCell
@end

@interface GormNSPopUpButton : NSPopUpButton
@end

@interface IBViewPboardViewer : NSView 
{
  NSScrollView *scroll;
}

- (BOOL)displayData:(NSData *)data 
             ofType:(NSString *)type;

@end

#endif // PASTEBOARDVIEWER_H
