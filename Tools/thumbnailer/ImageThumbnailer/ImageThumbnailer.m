/* ImageThumbnailer.m
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
#include "ImageThumbnailer.h"

#define TMBMAX (48.0)
#define RESZLIM 4

@implementation ImageThumbnailer

- (void)dealloc
{
	[super dealloc];
}

- (BOOL)canProvideThumbnailForPath:(NSString *)path
{
  NSString *ext = [path pathExtension];
  return (ext && [[NSImage imageFileTypes] containsObject: ext]);
}

- (NSData *)makeThumbnailForPath:(NSString *)path
{
  NSImage *image;

	NS_DURING
		{
			image = [[NSImage alloc] initWithContentsOfFile: path];
		}
	NS_HANDLER
		{
			return nil;
	  }
	NS_ENDHANDLER

  if (image && [image isValid]) {
    NSSize size = [image size];
    NSRect r = NSZeroRect;
    NSImageRep *rep = [image bestRepresentationForDevice: nil];
    NSImage *newimage = nil;
    NSBitmapImageRep *newBitmapImageRep = nil;
    NSData *data = nil;

    if ((size.width <= TMBMAX) && (size.height <= TMBMAX) 
                            && (size.width >= (TMBMAX - RESZLIM)) 
                                    && (size.height >= (TMBMAX - RESZLIM))) {
 	    if ([rep isKindOfClass: [NSBitmapImageRep class]]) {
        data = [(NSBitmapImageRep *)rep TIFFRepresentation];
        if (data) {
          RELEASE (image);
          return data;
        }
      }
    }

    if (size.width >= size.height) {
      r.size.width = TMBMAX;
      r.size.height = TMBMAX * size.height / size.width;
    } else {
      r.size.height = TMBMAX;
      r.size.width = TMBMAX * size.width / size.height;
    }  
      
    r = NSIntegralRect(r);   
    
    [image setScalesWhenResized: YES];
    [image setSize: r.size];

    newimage = [[NSImage alloc] initWithSize: r.size];
    [newimage lockFocus];

    [image compositeToPoint: NSZeroPoint 
                operation: NSCompositeSourceOver];

    newBitmapImageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: r];
    [newimage unlockFocus];

    data = [newBitmapImageRep TIFFRepresentation];
  
    RELEASE (image);
    RELEASE (newimage);
    RELEASE (newBitmapImageRep);
    
    return data;
  }
  
  return nil;
}

- (NSString *)fileNameExtension
{
  return @"tiff";
}

- (NSString *)description
{
  return @"Images Thumbnailer";
}

@end
