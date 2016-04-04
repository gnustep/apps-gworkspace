/* ImageThumbnailer.m
 *  
 * Copyright (C) 2003-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <math.h>
#import "ImageThumbnailer.h"

#define MIX_LIM 16

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

- (NSData *)makeThumbnailForPath:(NSString *)path
{
  CREATE_AUTORELEASE_POOL(arp);
  NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];

  if (image && [image isValid]) {
    NSData *tiffData = [image TIFFRepresentation];
    NSBitmapImageRep *srcRep = [NSBitmapImageRep imageRepWithData: tiffData];
    int srcSpp = [srcRep samplesPerPixel];
    int bitsPerPixel = [srcRep bitsPerPixel];
    
	  if (((srcSpp == 3) && (bitsPerPixel == 24)) 
        || ((srcSpp == 4) && (bitsPerPixel == 32))
        || ((srcSpp == 1) && (bitsPerPixel == 8))
        || ((srcSpp == 2) && (bitsPerPixel == 16))) {
    
      if (([srcRep pixelsWide] <= TMBMAX) && ([srcRep pixelsHigh]<= TMBMAX) 
                              && ([srcRep pixelsWide] >= (TMBMAX - RESZLIM)) 
                                      && ([srcRep pixelsHigh] >= (TMBMAX - RESZLIM)))
        {
          RETAIN (tiffData);
          RELEASE (image);
          RELEASE (arp);

          return AUTORELEASE (tiffData);
        }
      else
        {
          NSInteger srcBytesPerPixel = [srcRep bitsPerPixel] / 8;
          NSInteger srcBytesPerRow = [srcRep bytesPerRow];
          NSInteger destSamplesPerPixel = srcSpp;
          NSInteger destBytesPerRow;
          NSInteger destBytesPerPixel;
          NSInteger dstsizeW, dstsizeH;
          float fact = ([srcRep pixelsWide] >= [srcRep pixelsHigh]) ? ([srcRep pixelsWide] / TMBMAX) : ([srcRep pixelsHigh] / TMBMAX);
          	        
          float xratio;
          float yratio;
          NSBitmapImageRep *dstRep;
          unsigned char *srcData;
          unsigned char *destData;    
          unsigned x, y;
          unsigned i;
          NSData *tiffData;

          dstsizeW = (NSInteger)floor([srcRep pixelsWide] / fact + 0.5);
          dstsizeH = (NSInteger)floor([srcRep pixelsHigh] / fact + 0.5);
 
          xratio = [srcRep pixelsWide] / (float)dstsizeW;
          yratio = [srcRep pixelsHigh] / (float)dstsizeH;
          
          destSamplesPerPixel = [srcRep samplesPerPixel];
          dstRep = [[NSBitmapImageRep alloc]
                     initWithBitmapDataPlanes:NULL
                                   pixelsWide:dstsizeW
                                   pixelsHigh:dstsizeH
                                bitsPerSample:8
                              samplesPerPixel:destSamplesPerPixel
                                     hasAlpha:[srcRep hasAlpha]
                                     isPlanar:NO
                               colorSpaceName:[srcRep colorSpaceName]
                                  bytesPerRow:0
                                 bitsPerPixel:0];

          srcData = [srcRep bitmapData];
          destData = [dstRep bitmapData];
          
          destBytesPerRow = [dstRep bytesPerRow];
          destBytesPerPixel = [dstRep bitsPerPixel] / 8;
          
          for (y = 0; y < dstsizeH; y++)
            for (x = 0; x < dstsizeW; x++)
              for (i = 0; i < srcSpp; i++)
                destData[destBytesPerRow * y + destBytesPerPixel * x + i] = srcData[srcBytesPerRow * (int)floorf(y * yratio)  + srcBytesPerPixel * (int)floorf(x * xratio) + i];
          
          tiffData = [dstRep TIFFRepresentation];
          RETAIN (tiffData);
          
          RELEASE (image);
          RELEASE (dstRep);
          RELEASE (arp);
          
        return AUTORELEASE (tiffData);
      }
    }
  }    
  
  RELEASE (image);  
  RELEASE (arp);
    
  return nil;
}

/*
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
*/

- (NSString *)fileNameExtension
{
  return @"tiff";
}

- (NSString *)description
{
  return @"Images Thumbnailer";
}

@end
