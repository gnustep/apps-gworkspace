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
#include "resize.h"
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

/*
- (void)readImageAtPath:(NSString *)path
                setSize:(NSSize)imsize
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  NSImage *srcImage = [[NSImage alloc] initWithContentsOfFile: path];

  if (srcImage && [srcImage isValid]) {
    NSData *srcData = [srcImage TIFFRepresentation];
    NSBitmapImageRep *srcRep = [NSBitmapImageRep imageRepWithData: srcData];
    NSSize srcsize = NSMakeSize([srcRep pixelsWide], [srcRep pixelsHigh]);

    [info setObject: [NSNumber numberWithFloat: srcsize.width] forKey: @"width"];
    [info setObject: [NSNumber numberWithFloat: srcsize.height] forKey: @"height"];

    if ((imsize.width < srcsize.width) || (imsize.height < srcsize.height)) {
      int spp = [srcRep samplesPerPixel];
      int bpp = [srcRep bitsPerPixel] / 8;
      BOOL isColor = [srcRep hasAlpha] ? (spp > 2) : (spp > 1);
      NSString *colorSpaceName = isColor ? NSCalibratedRGBColorSpace : NSCalibratedWhiteColorSpace;
      NSSize dstsize;
      float xratio, yratio;
      NSBitmapImageRep *dstRep;
      NSData *tiffData;
      unsigned char *srcData;
      unsigned char *destData;
      unsigned x, y, i;
      
      if ((imsize.width / srcsize.width) <= (imsize.height / srcsize.height)) {
        dstsize.width = floor(imsize.width + 0.5);
        dstsize.height = floor(dstsize.width * srcsize.height / srcsize.width + 0.5);
      } else {
        dstsize.height = floor(imsize.height + 0.5);
        dstsize.width = floor(dstsize.height * srcsize.width / srcsize.height + 0.5);    
      }

      xratio = srcsize.width / dstsize.width * 1.0;
      yratio = srcsize.height / dstsize.height * 1.0;

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

      for (y = 0; y < (int)dstsize.height; y++) {
        for (x = 0; x < (int)dstsize.width; x++) {
          for (i = 0; i < bpp; i++) {
            int dstidx = (int)(bpp * (y * dstsize.width + x) + i);
            int srcidx = (int)(bpp * (floor(y * yratio) * srcsize.width + floor(x * xratio)) + i);
          
            destData[dstidx] = srcData[srcidx];
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
*/

- (void)readImageAtPath:(NSString *)path
                setSize:(NSSize)imsize
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  NSImage *image = [[NSImage alloc] initWithContentsOfFile: path];
  NSImageRep *rep = nil;  
  NSData *data = nil;

  if (image && [image isValid]) {
    NSSize size = [image size];
    
    [info setObject: [NSNumber numberWithFloat: size.width] forKey: @"width"];
    [info setObject: [NSNumber numberWithFloat: size.height] forKey: @"height"];
    
    if ((imsize.width < size.width) || (imsize.height < size.height)) {
      int rpw; 
      commonInfo *comInfo;
      float xfactor, yfactor;  
	    NSSize newsize;
      commonInfo *newInfo;
      unsigned char *map[MAXPLANE];
      unsigned char *newmap[MAXPLANE];
      NSBitmapImageRep *newBitmapImageRep;
    
	    [image setScalesWhenResized: YES];
	    [image setDataRetained: YES];
	    rep = [image bestRepresentationForDevice: nil];
      
      rpw = [rep pixelsWide];
      
	    if ((rpw != NSImageRepMatchesDevice) && (rpw != size.width)) {
		    size.width = rpw;
		    size.height = [rep pixelsHigh];
        [image setSize: size];
	    }  
      
      comInfo = NSZoneMalloc(NSDefaultMallocZone(), sizeof(commonInfo));	
    
	    comInfo->width	= size.width;
	    comInfo->height	= size.height;
	    comInfo->bits	= [rep bitsPerSample];
	    comInfo->numcolors = NSNumberOfColorComponents([rep colorSpaceName]);
	    comInfo->alpha	= [rep hasAlpha];
	    comInfo->palette = NULL;
	    comInfo->palsteps = 0;
	    comInfo->memo[0] = 0;
    
	    if ([rep isKindOfClass: [NSBitmapImageRep class]]) {
		    NSString *w = [(NSBitmapImageRep *)rep colorSpaceName];
        comInfo->cspace	= colorSpaceIdForColorSpaceName(w);
        comInfo->xbytes	= [(NSBitmapImageRep *)rep bytesPerRow];
		    comInfo->isplanar = [(NSBitmapImageRep *)rep isPlanar];
		    comInfo->pixbits = [(NSBitmapImageRep *)rep bitsPerPixel];
	    }
    
      if ((imsize.width / size.width) <= (imsize.height / size.height)) {
        newsize.width = floor(imsize.width + 0.5);
        newsize.height = floor(newsize.width * size.height / size.width + 0.5);
      } else {
        newsize.height = floor(imsize.height + 0.5);
        newsize.width = floor(newsize.height * size.width / size.height + 0.5);    
      }

      xfactor = newsize.width / size.width;
      yfactor = newsize.height / size.height;

      [(NSBitmapImageRep *)rep getBitmapDataPlanes: &map[0]];

      newInfo = makeBilinearResizedMap(xfactor, yfactor, comInfo, map, newmap);  
      
      if (newInfo) {
        newBitmapImageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &newmap[0]
	                  pixelsWide: newInfo->width
	                  pixelsHigh: newInfo->height 
	                  bitsPerSample: newInfo->bits
	                  samplesPerPixel: [(NSBitmapImageRep *)rep samplesPerPixel]
	                  hasAlpha: newInfo->alpha
	                  isPlanar: newInfo->isplanar
	                  colorSpaceName: [(NSBitmapImageRep *)rep colorSpaceName]
	                  bytesPerRow: newInfo->xbytes
	                  bitsPerPixel: newInfo->pixbits];
        
        if (newBitmapImageRep) {
          NS_DURING
		        {
			        data = [newBitmapImageRep TIFFRepresentation];
		        }
	        NS_HANDLER
		        {
			        [viewer imageReady: [NSArchiver archivedDataWithRootObject: info]];
	          }
	        NS_ENDHANDLER
          
          [info setObject: data forKey: @"imgdata"];
          RELEASE (newBitmapImageRep);
        }
        
        NSZoneFree (NSDefaultMallocZone(), newInfo);  
      }
      
      RELEASE (image);
      NSZoneFree (NSDefaultMallocZone(), comInfo);  
      
    } else {
      rep = [image bestRepresentationForDevice: nil];

 	    if ([rep isKindOfClass: [NSBitmapImageRep class]]) {
        data = [(NSBitmapImageRep *)rep TIFFRepresentation];
        [info setObject: data forKey: @"imgdata"];
        RELEASE (image);
      }
    }
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
