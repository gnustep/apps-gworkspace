/* ImageThumbnailer.m
 *  
 * Copyright (C) 2003-2020 Free Software Foundation, Inc.
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

  if (image && [image isValid])
    {
      NSData *tiffData;
      NSEnumerator *repEnum;
      NSBitmapImageRep *srcRep;
      NSInteger srcSpp;
      NSImageRep *imgRep;
 
      repEnum = [[image representations] objectEnumerator];
      srcRep = nil;
      imgRep = nil;
      while (srcRep == nil && (imgRep = [repEnum nextObject]))
        {
          if ([imgRep isKindOfClass:[NSBitmapImageRep class]])
            srcRep = (NSBitmapImageRep *)imgRep;
        }
      if (nil == srcRep)
        return nil;
      
      srcSpp = [srcRep samplesPerPixel];
    
      if (([srcRep pixelsWide] <= TMBMAX) && ([srcRep pixelsHigh]<= TMBMAX) 
                              && ([srcRep pixelsWide] >= (TMBMAX - RESZLIM)) 
                                      && ([srcRep pixelsHigh] >= (TMBMAX - RESZLIM)))
        {
          tiffData = [srcRep TIFFRepresentation];
          RETAIN (tiffData);
          RELEASE (image);
          RELEASE (arp);

          return AUTORELEASE (tiffData);
        }
      else
        {
          NSInteger dstSizeW, dstSizeH;
          float fact = ([srcRep pixelsWide] >= [srcRep pixelsHigh]) ? ([srcRep pixelsWide] / TMBMAX) : ([srcRep pixelsHigh] / TMBMAX);
          	        
          float xRatio;
          float yRatio;
          NSBitmapImageRep *dstRep;
          unsigned x, y;
          NSInteger i;
          NSData *tiffData;
	  NSInteger srcSizeW;
	  NSInteger srcSizeH;

	  srcSizeW = [srcRep pixelsWide];
	  srcSizeH = [srcRep pixelsHigh];

          dstSizeW = (NSInteger)floor([srcRep pixelsWide] / fact + 0.5);
          dstSizeH = (NSInteger)floor([srcRep pixelsHigh] / fact + 0.5);
 
          xRatio = (float)[srcRep pixelsWide] / (float)dstSizeW;
          yRatio = (float)[srcRep pixelsHigh] / (float)dstSizeH;
          
          dstRep = [[NSBitmapImageRep alloc]
                     initWithBitmapDataPlanes:NULL
                                   pixelsWide:dstSizeW
                                   pixelsHigh:dstSizeH
                                bitsPerSample:[srcRep bitsPerSample]
                              samplesPerPixel:[srcRep samplesPerPixel]
                                     hasAlpha:[srcRep hasAlpha]
                                     isPlanar:[srcRep isPlanar]
                               colorSpaceName:[srcRep colorSpaceName]
                                  bytesPerRow:0
                                 bitsPerPixel:0];
          
          for (y = 0; y < dstSizeH; y++)
	    {
	      for (x = 0; x < dstSizeW; x++)
		{
		  register NSInteger x0, y0;
		  register float xDiff, yDiff;
		  float xFloat, yFloat;
		  NSInteger x1, y1;
		  int xStep, yStep;
		  NSUInteger srcPixel1[5];
                  NSUInteger srcPixel2[5];
                  NSUInteger srcPixel3[5];
                  NSUInteger srcPixel4[5];
                  NSUInteger destPixel[5];

		  // we use integer part of the ratio, so that we can set the next pixel to at least one apart
		  xStep = floorf(xRatio);
		  yStep = floorf(yRatio);
		  if (xStep == 0)
		    xStep = 1;
		  if (yStep == 0)
		    yStep = 1;
		  xFloat = (float)x * xRatio;
		  yFloat = (float)y * yRatio;
		  x0 = (NSInteger)floorf(xFloat);
		  y0 = (NSInteger)floorf(yFloat);
		  x1 = x0 + xStep;
		  y1 = y0 + yStep;

		  // these are the weight w and h, normalized to the distance 1 : x1-x0
		  xDiff = (xFloat - (float)x0)/(float)xStep;
		  yDiff = (yFloat - (float)y0)/(float)yStep;

		  if (x1 >= srcSizeW )
		    {
		      x1 = srcSizeW-1;
		      xDiff = 0;
		    }
		  if (y1 >= srcSizeH )
		    {
		      y1 = srcSizeH-1;
		      yDiff = 0;
		    }

		  [srcRep getPixel: srcPixel1 atX:x0 y:y0];
                  [srcRep getPixel: srcPixel2 atX:x1 y:y0];
                  [srcRep getPixel: srcPixel3 atX:x0 y:y1];
                  [srcRep getPixel: srcPixel4 atX:x1 y:y1];

		  destPixel[0] = 0;
		  destPixel[1] = 0;
		  destPixel[2] = 0;
		  destPixel[3] = 0;
		  destPixel[4] = 0;
		  for (i = 0; i < srcSpp; i++)
		    {
		      destPixel[i] = \
			(NSUInteger)(srcPixel1[i]*(1-xDiff)*(1-yDiff) + \
				     srcPixel2[i]*xDiff*(1-yDiff) +	\
				     srcPixel3[i]*yDiff*(1-xDiff) +	\
				     srcPixel4[i]*xDiff*yDiff);
		    }
                  [dstRep setPixel: destPixel atX: x y:y];
		}
	    }
          
          tiffData = [dstRep TIFFRepresentation];
          RETAIN (tiffData);
          
          RELEASE (image);
          RELEASE (dstRep);
          RELEASE (arp);
          
	  return AUTORELEASE (tiffData);
	}
    }
  else
    {
      NSLog(@"Invalid image: %@", path);
    }
  
  RELEASE (image);  
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
