/* Resizer.m
 *  
 * Copyright (C) 2005-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "config.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

@protocol ImageViewerProtocol

- (void)setResizer:(id)anObject;

- (void)imageReady:(NSDictionary *)info;

@end


@interface Resizer : NSObject
{
  id viewer;
  NSNotificationCenter *nc; 
}

- (void)readImageAtPath:(NSString *)path
                setSize:(NSSize)imsize;

@end


@implementation Resizer


#define MIX_LIM 16

- (void)readImageAtPath:(NSString *)path
                setSize:(NSSize)imsize
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  NSImage *srcImage = [[NSImage alloc] initWithContentsOfFile: path];
  NSLog(@"Resizer - readImage");
  if (srcImage && [srcImage isValid])
    {
      NSData *srcData = [srcImage TIFFRepresentation];
      NSBitmapImageRep *srcRep;
      NSInteger srcSpp;
      NSInteger bitsPerPixel;
      NSInteger srcsizeW;
      NSInteger srcsizeH;
      NSInteger srcBytesPerPixel;
      NSInteger srcBytesPerRow;
      NSEnumerator *repEnum;
      NSImageRep *imgRep;
    
      repEnum = [[srcImage representations] objectEnumerator];
      srcRep = nil;
      imgRep = nil;
      while (srcRep == nil && (imgRep = [repEnum nextObject]))
        {
          if ([imgRep isKindOfClass:[NSBitmapImageRep class]])
            srcRep = (NSBitmapImageRep *)imgRep;
        }
      
      srcSpp = [srcRep samplesPerPixel];
      bitsPerPixel = [srcRep bitsPerPixel];
      srcsizeW = [srcRep pixelsWide];
      srcsizeH = [srcRep pixelsHigh];
      srcBytesPerPixel = [srcRep bitsPerPixel] / 8;
      srcBytesPerRow = [srcRep bytesPerRow];
      
      [info setObject: [NSNumber numberWithFloat: (float)srcsizeW] forKey: @"width"];
      [info setObject: [NSNumber numberWithFloat: (float)srcsizeH] forKey: @"height"];
      
      if (((imsize.width < srcsizeW) || (imsize.height < srcsizeH))
          && (((srcSpp == 3) && (bitsPerPixel == 24)) 
              || ((srcSpp == 4) && (bitsPerPixel == 32))
              || ((srcSpp == 1) && (bitsPerPixel == 8))
              || ((srcSpp == 2) && (bitsPerPixel == 16))))
        {
          NSInteger destSamplesPerPixel = srcSpp;
          NSInteger destBytesPerRow;
          NSInteger destBytesPerPixel;
          NSInteger dstsizeW, dstsizeH;
          float xratio, yratio;
          NSBitmapImageRep *dstRep;
          NSData *tiffData;
          unsigned char *srcData;
          unsigned char *destData;
          unsigned x, y;
          unsigned i;
          
      if ((imsize.width / srcsizeW) <= (imsize.height / srcsizeH)) {
        dstsizeW = floor(imsize.width + 0.5);
        dstsizeH = floor(dstsizeW * srcsizeH / srcsizeW + 0.5);
      } else {
        dstsizeH = floor(imsize.height + 0.5);
        dstsizeW= floor(dstsizeH * srcsizeW / srcsizeH + 0.5);    
      }

      xratio = (float)srcsizeW / (float)dstsizeW;
      yratio = (float)srcsizeH / (float)dstsizeH;

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
            destData[destBytesPerRow * y + destBytesPerPixel * x + i] = srcData[srcBytesPerRow * (int)(y * yratio)  + srcBytesPerPixel * (int)(x * xratio) + i];
  
      NS_DURING
        {
          tiffData = [dstRep TIFFRepresentation];   
        }
      NS_HANDLER
        {
          tiffData = nil;
        }
      NS_ENDHANDLER

      if (tiffData) {
        [info setObject: tiffData forKey: @"imgdata"];
      } 

      RELEASE (dstRep);
      
    } else {
      [info setObject: srcData forKey: @"imgdata"];
    }
    
    RELEASE (srcImage);
  }
  
  [viewer imageReady: info];
  
  RELEASE (arp);
}


@end
