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
#include <math.h>
#include <unistd.h>
#include <limits.h>
#include "ImageThumbnailer.h"
#include "resize.h"

#define TMBMAX (48.0)
#define RESZLIM 4

@implementation ImageThumbnailer

- (void)dealloc
{
  RELEASE (imageExtensions);
	[super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    NSArray *exts;

    fm = [NSFileManager defaultManager];

    exts = [NSArray arrayWithObjects: @"tiff", @"tif", @"TIFF", @"TIF", 
                                      @"png", @"PNG", @"jpeg", @"jpg", 
                                      @"JPEG", @"JPG", @"gif", @"GIF", 
                                      @"xpm", nil];
    ASSIGN (imageExtensions, exts);
  }

  return self;
}

- (BOOL)canProvideThumbnailForPath:(NSString *)path
{
  NSString *ext = [path pathExtension];
  return (ext && [imageExtensions containsObject: ext]);
}

- (NSData *)makeThumbnailForPath:(NSString *)path
{
  NSImage *image;
	NSImageRep *rep;  
	NSSize size;
  int rpw;  
	NSSize newsize;
  float xfactor;
  float yfactor;
  commonInfo *comInfo;
  commonInfo *newInfo;
  unsigned char *map[MAXPLANE];
  unsigned char *newmap[MAXPLANE];
  NSBitmapImageRep* newBitmapImageRep;
  NSData *data;

  image = [[NSImage alloc] initWithContentsOfFile: path];
  
  if (image == nil) {
    return nil;
  }
  
	rep = [image bestRepresentationForDevice: nil];
  rpw = [rep pixelsWide];
	size = [image size];
	if ((rpw != NSImageRepMatchesDevice) && (rpw != size.width)) {
		size.width = rpw;
		size.height = [rep pixelsHigh];
	}  

	[image setScalesWhenResized: YES];
	[image setSize: size];
	[image setCacheDepthMatchesImageDepth: YES];
	[image recache];

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
    newsize.width = TMBMAX;
    newsize.height = floor(TMBMAX * size.height / size.width + 0.5);
  } else {
    newsize.height = TMBMAX;
    newsize.width  = floor(TMBMAX * size.width / size.height + 0.5);
  }
  
  xfactor = newsize.width / size.width;
  yfactor = newsize.height / size.height;
    
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
  
  [(NSBitmapImageRep *)rep getBitmapDataPlanes: &map[0]];
  
  newInfo = makeBilinearResizedMap(xfactor, yfactor, comInfo, map, newmap);  
    
  newBitmapImageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: &newmap[0]
	pixelsWide: newsize.width
	pixelsHigh: newsize.height
	bitsPerSample: newInfo->bits
	samplesPerPixel: [(NSBitmapImageRep *)rep samplesPerPixel]
	hasAlpha: newInfo->alpha
	isPlanar: newInfo->isplanar
	colorSpaceName: [(NSBitmapImageRep *)rep colorSpaceName]
	bytesPerRow: newInfo->xbytes
	bitsPerPixel: newInfo->pixbits];
    
  data = [newBitmapImageRep TIFFRepresentation];
  
  RELEASE (image);
  NSZoneFree (NSDefaultMallocZone(), comInfo);  
  NSZoneFree (NSDefaultMallocZone(), newInfo);  
  
  return data;
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
