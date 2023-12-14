/* Resizer.m
 *  
 * Copyright (C) 2005-2023 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <math.h>

#import "Resizer.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

@implementation ImageResizer

+ (void)connectWithPorts:(NSArray *)portArray
{
  NSAutoreleasePool *pool;
  ImageResizer *serverObject;
  NSConnection *serverConnection;

  pool = [[NSAutoreleasePool alloc] init];

  serverConnection = [NSConnection connectionWithReceivePort: [portArray objectAtIndex:0]
                                                    sendPort: [portArray objectAtIndex:1]];

  serverObject = [[self alloc] init];
  if (serverObject)
    {
      [(id)[serverConnection rootProxy] setResizer:serverObject];
      [serverObject release];
      [[NSRunLoop currentRunLoop] run];
    }
  [pool release];
  [NSThread exit];
}


- (void)dealloc
{
  [super dealloc];
}


#define MIX_LIM 16

- (void)setProxy:(id <ImageViewerProtocol>)ivp
{
  imageViewerProxy = ivp;
}

- (void)readImageAtPath:(NSString *)path
                setSize:(NSSize)imsize
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *info = nil;
  NSImage *srcImage = [[NSImage alloc] initWithContentsOfFile: path];

  if (srcImage && [srcImage isValid])
    {
      NSData *srcData = [srcImage TIFFRepresentation];
      NSBitmapImageRep *srcImageRep;
      NSInteger srcSpp;
      NSInteger bitsPerPixel;
      NSInteger srcSizeW;
      NSInteger srcSizeH;
      NSInteger srcBytesPerPixel;
      NSInteger srcBytesPerRow;
      NSEnumerator *repEnum;
      NSImageRep *imgRep;

      info = [NSMutableDictionary dictionary];

      repEnum = [[srcImage representations] objectEnumerator];
      srcImageRep = nil;
      imgRep = nil;
      while (srcImageRep == nil && (imgRep = [repEnum nextObject]))
        {
          if ([imgRep isKindOfClass:[NSBitmapImageRep class]])
            srcImageRep = (NSBitmapImageRep *)imgRep;
        }
      
      srcSpp = [srcImageRep samplesPerPixel];
      bitsPerPixel = [srcImageRep bitsPerPixel];
      srcSizeW = [srcImageRep pixelsWide];
      srcSizeH = [srcImageRep pixelsHigh];
      srcBytesPerPixel = [srcImageRep bitsPerPixel] / 8;
      srcBytesPerRow = [srcImageRep bytesPerRow];
      
      [info setObject: [NSNumber numberWithFloat: (float)srcSizeW] forKey: @"width"];
      [info setObject: [NSNumber numberWithFloat: (float)srcSizeH] forKey: @"height"];
      [info setObject: path forKey: @"imgpath"];
      
      if (((imsize.width < srcSizeW) || (imsize.height < srcSizeH))
          && (((srcSpp == 3) && (bitsPerPixel == 24)) 
              || ((srcSpp == 4) && (bitsPerPixel == 32))
              || ((srcSpp == 1) && (bitsPerPixel == 8))
              || ((srcSpp == 2) && (bitsPerPixel == 16))))
        {
	  NSInteger srcSamplesPerPixel;
          NSInteger destSamplesPerPixel = srcSpp;
          NSInteger destBytesPerRow;
          NSInteger destBytesPerPixel;
          NSInteger dstSizeW, dstSizeH;
          float xRatio, yRatio;
          NSBitmapImageRep *dstRep;
          NSData *tiffData;
          unsigned char *srcData;
          unsigned char *destData;
          unsigned x, y;
          unsigned i;
          
	  if ((imsize.width / srcSizeW) <= (imsize.height / srcSizeH)) {
	    dstSizeW = floor(imsize.width + 0.5);
	    dstSizeH = floor(dstSizeW * srcSizeH / srcSizeW + 0.5);
	  } else {
	    dstSizeH = floor(imsize.height + 0.5);
	    dstSizeW= floor(dstSizeH * srcSizeW / srcSizeH + 0.5);    
	  }

	  xRatio = (float)srcSizeW / (float)dstSizeW;
	  yRatio = (float)srcSizeH / (float)dstSizeH;

	  srcSamplesPerPixel = [srcImageRep samplesPerPixel];
	  destSamplesPerPixel = [srcImageRep samplesPerPixel];
	  dstRep = [[NSBitmapImageRep alloc]
                     initWithBitmapDataPlanes:NULL
				   pixelsWide:dstSizeW
				   pixelsHigh:dstSizeH
				bitsPerSample:8
			      samplesPerPixel:destSamplesPerPixel
				     hasAlpha:[srcImageRep hasAlpha]
				     isPlanar:NO
			       colorSpaceName:[srcImageRep colorSpaceName]
				  bytesPerRow:0
				 bitsPerPixel:0];

	  srcData = [srcImageRep bitmapData];
	  destData = [dstRep bitmapData];

	  destBytesPerRow = [dstRep bytesPerRow];
	  destBytesPerPixel = [dstRep bitsPerPixel] / 8;

	  for (y = 0; y < dstSizeH; y++)
	    {
	      for (x = 0; x < dstSizeW; x++)
		{
		  register NSInteger x0, y0;
		  register float xDiff, yDiff;
		  float xFloat, yFloat;
		  NSInteger x1, y1;
		  int xStep, yStep;

		  // we use integer part of the ratio, so that we can set the next pixel to at least one apart
		  xStep = floorf(xRatio);
		  yStep = floorf(yRatio);
		  if (xStep == 0) xStep = 1;
		  if (yStep == 0) yStep = 1;
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
              
		  for (i = 0; i < srcSamplesPerPixel; i++)
		    {
		      int v1, v2, v3, v4;

		      v1 = srcData[srcBytesPerRow * y0 + srcBytesPerPixel * x0 + i];
		      v2 = srcData[srcBytesPerRow * y0 + srcBytesPerPixel * x1 + i];
		      v3 = srcData[srcBytesPerRow * y1 + srcBytesPerPixel * x0 + i];
		      v4 = srcData[srcBytesPerRow * y1 + srcBytesPerPixel * x1 + i];
                  
		      destData[destBytesPerRow * y + destBytesPerPixel * x + i] = \
			(int)(v1*(1-xDiff)*(1-yDiff) +                            \
			      v2*xDiff*(1-yDiff) +				  \
			      v3*yDiff*(1-xDiff) +		                  \
			      v4*xDiff*yDiff);
		    }
		}
	    }
  
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
	      [info setObject: tiffData forKey:@"imgdata"];
	    } 

	  RELEASE (dstRep);
      
	} else {
        [info setObject: srcData forKey:@"imgdata"];
      }
    
      RELEASE (srcImage);
    }
  [imageViewerProxy imageReady: info];
  RELEASE (arp);
}


@end


