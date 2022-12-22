/* ImageViewer.h
 *  
 * Copyright (C) 2004-2020 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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

#ifndef IMAGEVIEWER_H
#define IMAGEVIEWER_H

#import <Foundation/Foundation.h>
#import <AppKit/NSView.h>
#import "ContentViewersProtocol.h"

@class NSImage;
@class NSImageView;
@class NSTextField;
@class NSButton;
@class NSWorkspace;
@class ProgressView;
@class ImageResizer;

@protocol ContentInspectorProtocol

- (void)contentsReadyAt:(NSString *)path;

@end 

@protocol ImageResizerProtocol

- (oneway void)readImageAtPath:(NSString *)path
                       setSize:(NSSize)imsize;

- (oneway void)terminate;

@end

@interface ImageViewer : NSView <ContentViewersProtocol, ImageViewerProtocol>
{
  NSArray *extsarr;
  BOOL valid;	
  
  NSImageView *imview;
  NSImage *image;
  NSTextField *errLabel;
  NSTextField *widthLabel;
  NSTextField *heightLabel;  
  ProgressView *progView;
  NSButton *editButt;
  
  NSString *imagePath;
  NSString *editPath;
  
  NSConnection *conn;  
  ImageResizer *resizer;
  
  id <ContentInspectorProtocol>inspector;
  NSFileManager *fm;
  NSWorkspace *ws;
}

- (oneway void)setResizer:(id)anObject;

- (oneway void)imageReady:(NSDictionary *)imginfo;

- (void)editFile:(id)sender;

- (void)setContextHelp;

@end


@interface ProgressView : NSView 
{
  NSMutableArray *images;
  NSUInteger index;
  NSTimeInterval rfsh;
  NSTimer *progTimer;
  BOOL animating;
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(NSTimeInterval)refresh;

- (void)start;

- (void)stop;

- (void)animate:(id)sender;

- (BOOL)animating;

@end

#endif // IMAGEVIEWER_H
