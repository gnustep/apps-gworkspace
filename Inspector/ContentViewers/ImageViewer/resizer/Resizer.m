/* Resizer.m
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
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

- (oneway void)setResizer:(id)anObject;

- (oneway void)imageReady:(NSData *)data;

@end


@interface Resizer : NSObject
{
  id viewer;
  NSNotificationCenter *nc; 
}

- (id)initWithConnectionName:(NSString *)cname;

- (void)connectionDidDie:(NSNotification *)notification;

- (void)readImageAtPath:(NSString *)path
                setSize:(NSSize)imsize;

- (void)terminate;

@end


@implementation Resizer

- (void)dealloc
{
  [nc removeObserver: self];
	DESTROY (viewer);
  [super dealloc];
}

- (id)initWithConnectionName:(NSString *)cname
{
  self = [super init];
  
  if (self) {
    NSConnection *conn;
    id anObject;

    nc = [NSNotificationCenter defaultCenter];
            
    conn = [NSConnection connectionWithRegisteredName: cname host: nil];
    
    if (conn == nil) {
      NSLog(@"failed to contact the Image Viewer - bye.");
	    exit(1);           
    } 

    [nc addObserver: self
           selector: @selector(connectionDidDie:)
               name: NSConnectionDidDieNotification
             object: conn];    
    
    anObject = [conn rootProxy];
    [anObject setProtocolForProxy: @protocol(ImageViewerProtocol)];
    viewer = (id <ImageViewerProtocol>)anObject;
    RETAIN (viewer);

    [viewer setResizer: self];
  }
  
  return self;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  id conn = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: conn];

  NSLog(@"Image Viewer connection has been destroyed.");
  exit(0);
}

#define MIX_LIM 16

- (void)readImageAtPath:(NSString *)path
                setSize:(NSSize)imsize
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  NSImage *srcImage = [[NSImage alloc] initWithContentsOfFile: path];

  if (srcImage && [srcImage isValid]) {
    NSData *srcData = [srcImage TIFFRepresentation];
    NSBitmapImageRep *srcRep = [NSBitmapImageRep imageRepWithData: srcData];
    int spp = [srcRep samplesPerPixel];
    int bitsPerPixel = [srcRep bitsPerPixel];
    NSSize srcsize = NSMakeSize([srcRep pixelsWide], [srcRep pixelsHigh]);

    [info setObject: [NSNumber numberWithFloat: srcsize.width] forKey: @"width"];
    [info setObject: [NSNumber numberWithFloat: srcsize.height] forKey: @"height"];

    if (((imsize.width < srcsize.width) || (imsize.height < srcsize.height))
                                && (((spp == 3) && (bitsPerPixel == 24)) 
                                    || ((spp == 4) && (bitsPerPixel == 32))
                                    || ((spp == 1) && (bitsPerPixel == 8))
                                    || ((spp == 2) && (bitsPerPixel == 16)))) {            
      int bpp = bitsPerPixel / 8;
      BOOL hasAlpha = [srcRep hasAlpha];
      BOOL isColor = hasAlpha ? (spp > 2) : (spp > 1);
      NSString *colorSpaceName = isColor ? NSCalibratedRGBColorSpace : NSCalibratedWhiteColorSpace;
      NSSize dstsize;
      float xratio, yratio;
      NSBitmapImageRep *dstRep;
      NSData *tiffData;
      unsigned char *srcData;
      unsigned char *destData;
      unsigned x, y;
      
      if ((imsize.width / srcsize.width) <= (imsize.height / srcsize.height)) {
        dstsize.width = floor(imsize.width + 0.5);
        dstsize.height = floor(dstsize.width * srcsize.height / srcsize.width + 0.5);
      } else {
        dstsize.height = floor(imsize.height + 0.5);
        dstsize.width = floor(dstsize.height * srcsize.width / srcsize.height + 0.5);    
      }

      xratio = srcsize.width / dstsize.width;
      yratio = srcsize.height / dstsize.height;
    
      dstRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                              pixelsWide: (int)dstsize.width
                              pixelsHigh: (int)dstsize.height
                              bitsPerSample: 8
                              samplesPerPixel: (isColor ? 3 : 1)
                              hasAlpha: NO
                              isPlanar: NO
                              colorSpaceName: colorSpaceName
                              bytesPerRow: 0
                              bitsPerPixel: 0];

      srcData = [srcRep bitmapData];
      destData = [dstRep bitmapData];

      for (y = 0; y < (int)(dstsize.height); y++) {
        int px[2], py[2]; 
        
        py[0] = floor(y * yratio);
        py[1] = ceil((y + 1) * yratio);
        py[1] = ((py[1] > srcsize.height) ? (int)(srcsize.height) : py[1]);
                        
        for (x = 0; x < (int)(dstsize.width); x++) {
          int expos = (int)(bpp * (floor(y * yratio) * srcsize.width + floor(x * xratio)));        
          unsigned expix[4] = { 0, 0, 0, 0 };
          unsigned pix[4] = { 0, 0, 0, 0 };
          int count = 0;
          unsigned char c;
          int i, j;

          expix[0] = srcData[expos];

          if (isColor) {
            expix[1] = srcData[expos + 1];
            expix[2] = srcData[expos + 2];
          }

          px[0] = floor(x * xratio);
          px[1] = ceil((x + 1) * xratio);
          px[1] = ((px[1] > srcsize.width) ? (int)(srcsize.width) : px[1]);
          
          for (i = px[0]; i < px[1]; i++) {
            for (j = py[0]; j < py[1]; j++) {
              int pos = (int)(bpp * (j * srcsize.width + i));

              pix[0] += srcData[pos];
              
              if (isColor) {
                pix[1] += srcData[pos + 1];
                pix[2] += srcData[pos + 2];
              }

              count++;
            }
          }

          c = (unsigned char)(pix[0] / count);
          
          if (abs(c - expix[0]) < MIX_LIM) {
            *destData++ = (unsigned char)(expix[0]);
          } else {
            *destData++ = c;
          }
          
          if (isColor) {
            c = (unsigned char)(pix[1] / count);

            if (abs(c - expix[1]) < MIX_LIM) {
              *destData++ = (unsigned char)(expix[1]);
            } else {
              *destData++ = c;
            }

            c = (unsigned char)(pix[2] / count);

            if (abs(c - expix[2]) < MIX_LIM) {
              *destData++ = (unsigned char)(expix[2]);
            } else {
              *destData++ = c;            
            }
          }
        }
      }
  
  /*
      for (y = 0; y < (int)dstsize.height; y++) {
        for (x = 0; x < (int)dstsize.width; x++) {
          int pos = (int)(bpp * (floor(y * yratio) * srcsize.width + floor(x * xratio)));

          *destData++ = srcData[pos];

          if (isColor) {
            *destData++ = srcData[pos + 1];
            *destData++ = srcData[pos + 2];
          }
        }
      }
  */    
  
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
  
  [viewer imageReady: [NSArchiver archivedDataWithRootObject: info]];
  
  RELEASE (arp);
}

- (void)terminate
{
  exit(0);
}

@end


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL (pool);
  
  if (argc > 1) {
    NSString *conname = [NSString stringWithCString: argv[1]];
    Resizer *resizer = [[Resizer alloc] initWithConnectionName: conname];
    
    if (resizer) {
      [[NSRunLoop currentRunLoop] run];
    }
  } else {
    NSLog(@"no connection name.");
  }
  
  RELEASE (pool);  
  exit(0);
}

