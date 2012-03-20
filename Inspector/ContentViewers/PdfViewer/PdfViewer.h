/* PdfViewer.h
 *  
 * Copyright (C) 2004-2012 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
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
#import <AppKit/NSView.h>
#import "ContentViewersProtocol.h"

@class NSImageView;
@class NSTextField;
@class NSButton;
@class NSWorkspace;

@protocol ContentInspectorProtocol

- (void)contentsReadyAt:(NSString *)path;

@end 

@class NSScrollView;
@class NSMatrix;
@class NSImageView;
@class NSTextField;
@class NSWorkspace;
@class NSButton;
@class PDFDocument;
@class PDFImageRep;
@class NSImage;

@interface PdfViewer : NSView <ContentViewersProtocol>
{
  BOOL valid;
  
  NSButton *backButt, *nextButt;
  NSScrollView *scroll;
  NSMatrix *matrix;
  NSImageView *imageView;
  NSTextField *errLabel;
  NSButton *editButt;

  NSString *pdfPath;
  PDFDocument *pdfDoc;
  PDFImageRep *imageRep;
  
  id <ContentInspectorProtocol>inspector;
  NSFileManager *fm;
  NSNotificationCenter *nc;
  NSWorkspace *ws;
}

- (void)goToPage:(id)sender;

- (void)nextPage:(id)sender;

- (void)previousPage:(id)sender;

- (void)editFile:(id)sender;

- (void)setContextHelp;

@end

