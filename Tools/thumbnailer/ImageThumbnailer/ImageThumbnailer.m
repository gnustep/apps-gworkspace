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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
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
  NSString *ext = [[path pathExtension] lowercaseString];
  return (ext && [[NSImage imageFileTypes] containsObject: ext]);
}

/*
- (NSData *)makeThumbnailForPath:(NSString *)path
{
  CREATE_AUTORELEASE_POOL(arp);
  NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];

  if (image && [image isValid]) {
    NSData *tiffdata = [image TIFFRepresentation];
    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData: tiffdata];
    int spp = [rep samplesPerPixel];
    int bitsPerPixel = [rep bitsPerPixel];
    int bpp = bitsPerPixel / 8; 
    
	  if (((spp == 3) && (bitsPerPixel == 24)) 
        || ((spp == 4) && (bitsPerPixel == 32))
        || ((spp == 1) && (bitsPerPixel == 8))
        || ((spp == 2) && (bitsPerPixel == 16))) {
      NSSize imsize = [image size];
    
      if ((imsize.width <= TMBMAX) && (imsize.height <= TMBMAX) 
                              && (imsize.width >= (TMBMAX - RESZLIM)) 
                                      && (imsize.height >= (TMBMAX - RESZLIM))) {
        RETAIN (tiffdata);
        RELEASE (image);
        RELEASE (arp);

        return AUTORELEASE (tiffdata);
        
      } else {
        float fact = (imsize.width >= imsize.height) ? (imsize.width / TMBMAX) : (imsize.height / TMBMAX);
        NSSize newsize = NSMakeSize(floor(imsize.width / fact + 0.5), floor(imsize.height / fact + 0.5));	        
        float xratio = imsize.width / newsize.width;
        float yratio = imsize.height / newsize.height;
        BOOL hasAlpha = [rep hasAlpha];
        BOOL isColor = hasAlpha ? (spp > 2) : (spp > 1);
        NSString *colorSpaceName = isColor ? NSCalibratedRGBColorSpace : NSCalibratedWhiteColorSpace;      
        NSBitmapImageRep *newrep;
        unsigned char *srcData;
        unsigned char *dstData;    
        unsigned x, y;
        NSData *data = nil;
  
        newrep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                pixelsWide: (int)newsize.width
                                pixelsHigh: (int)newsize.height
                                bitsPerSample: 8
                                samplesPerPixel: (isColor ? 4 : 2)
                                hasAlpha: YES
                                isPlanar: NO
                                colorSpaceName: colorSpaceName
                                bytesPerRow: 0
                                bitsPerPixel: 0];
  
        srcData = [rep bitmapData];
        dstData = [newrep bitmapData];

        for (y = 0; y < (int)newsize.height; y++) {
          for (x = 0; x < (int)newsize.width; x++) {
            int pos = (int)(bpp * (floor(y * yratio) * imsize.width + floor(x * xratio)));

            *dstData++ = srcData[pos];

            if (isColor) {
              *dstData++ = srcData[pos + 1];
              *dstData++ = srcData[pos + 2];
            }

            if (hasAlpha) {
              if (isColor) {
                *dstData++ = srcData[pos + 3];
              } else {
                *dstData++ = srcData[pos + 1];
              }
            } else {
              *dstData++ = 255;
            }
          }
        }
  
        data = [newrep TIFFRepresentation];
        RETAIN (data);

        RELEASE (image);
        RELEASE (newrep);
        RELEASE (arp);

        return AUTORELEASE (data);
      }
    }
  }    
  
  RELEASE (image);  
  RELEASE (arp);
    
  return nil;
}
*/

- (NSData *)makeThumbnailForPath:(NSString *)path
{
  CREATE_AUTORELEASE_POOL(arp);
  NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];

  if (image && [image isValid]) {
    NSSize size = [image size];
    NSRect srcr = NSMakeRect(0, 0, size.width, size.height);
	  NSRect dstr = NSZeroRect;  
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
          RETAIN (data);
          RELEASE (arp);
          
          return [data autorelease];
        }
      }
    }

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
    RETAIN (data);
    
    RELEASE (image);
    RELEASE (newimage);
    RELEASE (newBitmapImageRep);
    RELEASE (arp);
    
    return [data autorelease];
  }

  RELEASE (arp);
    
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
