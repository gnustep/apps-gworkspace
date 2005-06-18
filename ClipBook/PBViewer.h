/* PBViewer.h
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef PBVIEWER_H
#define PBVIEWER_H

#include <Foundation/Foundation.h>

@class NSView;
@class NSImageView;
@class NSTextField;
@class NSTextView;
@class NSScrollView;
@class NSBox;
@class NSColor;
@class NSRTFPboardViewer;
@class NSTIFFPboardViewer;
@class NSColorboardViewer;
@class IBViewPboardViewer;

@interface PBViewer : NSObject
{
  NSRTFPboardViewer *RTFViewer;
  NSTIFFPboardViewer *TIFFViewer;
  NSColorboardViewer *ColorViewer;
  IBViewPboardViewer *IBViewViewer;
}

- (id)viewerForData:(NSData *)data ofType:(NSString *)type;

@end

@interface NSRTFPboardViewer : NSView 
{
  NSScrollView *scrollView;
  NSTextView *textView;
}

- (BOOL)displayData:(NSData *)data 
             ofType:(NSString *)type;

@end

@interface NSTIFFPboardViewer : NSBox 
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

@interface GormObjectsView : NSView
@end

@interface IBViewPboardViewer : NSView 
{
  NSScrollView *scroll;
}

- (BOOL)displayData:(NSData *)data 
             ofType:(NSString *)type;

@end

#endif // PBVIEWER_H
