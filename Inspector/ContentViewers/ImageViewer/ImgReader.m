/* ImgReader.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "ImgReader.h"
#include "resize.h"

@implementation ImgReader

- (void)dealloc
{
  [super dealloc];
}

+ (void)createReaderWithPorts:(NSArray *)portArray
{
  NSAutoreleasePool *pool;
  id vwr;
  NSConnection *conn;
  NSPort *port[2];
  ImgReader *reader;
	
  pool = [[NSAutoreleasePool alloc] init];
	  
  port[0] = [portArray objectAtIndex: 0];
  port[1] = [portArray objectAtIndex: 1];
  conn = [NSConnection connectionWithReceivePort: port[0] sendPort: port[1]];
  vwr = (id)[conn rootProxy];
  reader = [[ImgReader alloc] initWithViewerConnection: conn];
  [vwr setReader: reader];
  RELEASE (reader);
	
  [[NSRunLoop currentRunLoop] run];
  [pool release];
}

- (id)initWithViewerConnection:(NSConnection *)conn
{
  self = [super init];
  
  if (self) {
    id vwr = (id)[conn rootProxy];
    [vwr setProtocolForProxy: @protocol(ImageViewerProtocol)];
    viewer = (id <ImageViewerProtocol>)vwr;
  }
  
  return self;
}

- (void)readImageAtPath:(NSString *)path
                setSize:(NSSize)imsize
{
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  NSImage *image = nil;
  NSImageRep *rep = nil;  
  NSData *data = nil;

	NS_DURING
		{
			image = [[NSImage alloc] initWithContentsOfFile: path];
		}
	NS_HANDLER
		{
			[viewer imageReady: [NSArchiver archivedDataWithRootObject: info]];
	  }
	NS_ENDHANDLER

  if (image && [image isValid]) {
    NSSize size = [image size];
    
    [info setObject: [NSNumber numberWithFloat: size.width] forKey: @"width"];
    [info setObject: [NSNumber numberWithFloat: size.height] forKey: @"height"];
    
    if ((imsize.width < size.width) || (imsize.height < size.height)) {
      int rpw; 
      commonInfo *comInfo;
      float rw, rh;
      float xfactor, yfactor;  
	    NSSize newsize;
      commonInfo *newInfo;
      unsigned char *map[MAXPLANE];
      unsigned char *newmap[MAXPLANE];
      NSBitmapImageRep* newBitmapImageRep;
    
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
    
      rw = imsize.width / size.width;
      rh = imsize.height / size.height;

      if (rw <= rh) {
        newsize.width = size.width * rw;
        newsize.height = floor(imsize.width * size.height / size.width + 0.5);
      } else {
        newsize.height = size.height * rh;
        newsize.width = floor(imsize.height * size.width / size.height + 0.5);    
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
          data = [newBitmapImageRep TIFFRepresentation];
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
}

- (void)stopReading
{
 // [NSThread exit];
}

@end
