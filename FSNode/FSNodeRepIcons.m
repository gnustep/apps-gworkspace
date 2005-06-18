/* FSNodeRepIcons.m
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2005
 *
 * This file is part of the GNUstep FSNode framework
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
#include "FSNodeRep.h"
#include "FSNFunctions.h"

/*
 *****************************************************************************
 * lighter icons lookup table
 *****************************************************************************
  
  to regenerate it, define the gamma (HLGH) and put this somewere:
  
  {
    #define HLGH 1.5
    unsigned i, line = 1;

    printf("static unsigned char lighterLUT[256] = { \n");
     
    for (i = 1; i <= 256; i++) {
      printf("%d", (unsigned)floor(255 * pow(((float)i / 256.0f), 1 / HLGH)));
      if (i < 256) printf(", ");
      if (!(line % 16)) printf("\n  ");
      line++;
    }
    
    printf("};\n");
    fflush(stdout);       
  }  
*/

static unsigned char lighterLUT[256] = { 
  6, 10, 13, 15, 18, 20, 23, 25, 27, 29, 31, 33, 34, 36, 38, 40, 
  41, 43, 45, 46, 48, 49, 51, 52, 54, 55, 56, 58, 59, 61, 62, 63, 
  65, 66, 67, 68, 70, 71, 72, 73, 75, 76, 77, 78, 80, 81, 82, 83, 
  84, 85, 86, 88, 89, 90, 91, 92, 93, 94, 95, 96, 98, 99, 100, 101, 
  102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 
  118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 127, 128, 129, 130, 131, 132, 
  133, 134, 135, 136, 137, 138, 138, 139, 140, 141, 142, 143, 144, 145, 146, 146, 
  147, 148, 149, 150, 151, 152, 153, 153, 154, 155, 156, 157, 158, 158, 159, 160, 
  161, 162, 163, 163, 164, 165, 166, 167, 168, 168, 169, 170, 171, 172, 172, 173, 
  174, 175, 176, 176, 177, 178, 179, 180, 180, 181, 182, 183, 184, 184, 185, 186, 
  187, 187, 188, 189, 190, 191, 191, 192, 193, 194, 194, 195, 196, 197, 197, 198, 
  199, 200, 200, 201, 202, 203, 203, 204, 205, 206, 206, 207, 208, 209, 209, 210, 
  211, 211, 212, 213, 214, 214, 215, 216, 217, 217, 218, 219, 219, 220, 221, 222, 
  222, 223, 224, 224, 225, 226, 226, 227, 228, 229, 229, 230, 231, 231, 232, 233, 
  233, 234, 235, 236, 236, 237, 238, 238, 239, 240, 240, 241, 242, 242, 243, 244, 
  244, 245, 246, 246, 247, 248, 248, 249, 250, 250, 251, 252, 253, 253, 254, 255
  };

/*
 *****************************************************************************
 * darker icons lookup table
 *****************************************************************************
  
  to regenerate it, define the gamma (DARK) and put this somewere:
  
  {
    #define DARK 0.5
    unsigned i, line = 1;

    printf("static unsigned char darkerLUT[256] = { \n");

    for (i = 1; i <= 256; i++) {
      printf("%d", (unsigned)floor(255 * pow(((float)i / 256.0f), 1 / DARK)));
      if (i < 256) printf(", ");
      if (!(line % 16)) printf("\n  ");
      line++;
    }
    
    printf("};\n");
    fflush(stdout);       
  }  
*/

static unsigned char darkerLUT[256] = { 
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
  1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 
  4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8, 
  9, 9, 10, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 14, 15, 15, 
  16, 16, 17, 17, 18, 19, 19, 20, 20, 21, 21, 22, 23, 23, 24, 24, 
  25, 26, 26, 27, 28, 28, 29, 30, 30, 31, 32, 32, 33, 34, 35, 35, 
  36, 37, 38, 38, 39, 40, 41, 42, 42, 43, 44, 45, 46, 47, 47, 48, 
  49, 50, 51, 52, 53, 54, 55, 56, 56, 57, 58, 59, 60, 61, 62, 63, 
  64, 65, 66, 67, 68, 69, 70, 71, 73, 74, 75, 76, 77, 78, 79, 80, 
  81, 82, 84, 85, 86, 87, 88, 89, 91, 92, 93, 94, 95, 97, 98, 99, 
  100, 102, 103, 104, 105, 107, 108, 109, 111, 112, 113, 115, 116, 117, 119, 120, 
  121, 123, 124, 126, 127, 128, 130, 131, 133, 134, 136, 137, 138, 140, 141, 143, 
  144, 146, 147, 149, 151, 152, 154, 155, 157, 158, 160, 161, 163, 165, 166, 168, 
  169, 171, 173, 174, 176, 178, 179, 181, 183, 184, 186, 188, 190, 191, 193, 195, 
  196, 198, 200, 202, 204, 205, 207, 209, 211, 213, 214, 216, 218, 220, 222, 224, 
  225, 227, 229, 231, 233, 235, 237, 239, 241, 243, 245, 247, 249, 251, 253, 255
  };

@implementation FSNodeRep (Icons)

- (NSImage *)resizedIcon:(NSImage *)icon 
                  ofSize:(int)size
{
  if (oldresize == NO) {
    CREATE_AUTORELEASE_POOL(arp);
    NSSize icnsize = [icon size];
	  NSRect srcr = NSZeroRect;
	  NSRect dstr = NSZeroRect;  
    float fact;
    NSSize newsize;	
    NSImage *newIcon;
    NSBitmapImageRep *rep;

    if (icnsize.width >= icnsize.height) {
      fact = icnsize.width / size;
    } else {
      fact = icnsize.height / size;
    }

    newsize.width = floor(icnsize.width / fact + 0.5);
    newsize.height = floor(icnsize.height / fact + 0.5);
	  srcr.size = icnsize;
	  dstr.size = newsize;

    newIcon = [[NSImage alloc] initWithSize: newsize];

    NS_DURING
      {
		    [newIcon lockFocus];

        [icon drawInRect: dstr 
                fromRect: srcr 
               operation: NSCompositeSourceOver 
                fraction: 1.0];

        rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: dstr];

        if (rep) {
          [newIcon addRepresentation: rep];
          RELEASE (rep); 
        }

		    [newIcon unlockFocus];
      }
    NS_HANDLER
      {
        newIcon = [icon copy];
	      [newIcon setScalesWhenResized: YES];
	      [newIcon setSize: newsize];  
      }
    NS_ENDHANDLER

    RELEASE (arp);

    return [newIcon autorelease];  
  
  } else {
    CREATE_AUTORELEASE_POOL(arp);
    NSImage *newIcon = [icon copy];
    NSSize icnsize = [icon size];
    float fact;
    NSSize newsize;

    if (icnsize.width >= icnsize.height) {
      fact = icnsize.width / size;
    } else {
      fact = icnsize.height / size;
    }

    newsize.width = floor(icnsize.width / fact + 0.5);
    newsize.height = floor(icnsize.height / fact + 0.5);
	  [newIcon setScalesWhenResized: YES];
	  [newIcon setSize: newsize];  
    RELEASE (arp);

    return [newIcon autorelease];  
  }

  return nil;
}

- (NSImage *)lighterIcon:(NSImage *)icon
{
  CREATE_AUTORELEASE_POOL(arp);
  NSData *tiffdata = [icon TIFFRepresentation];
  NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData: tiffdata];
  int samplesPerPixel = [rep samplesPerPixel];
  int bitsPerPixel = [rep bitsPerPixel];
  NSImage *newIcon;

	if (((samplesPerPixel == 3) && (bitsPerPixel == 24)) 
              || ((samplesPerPixel == 4) && (bitsPerPixel == 32))) {
    int pixelsWide = [rep pixelsWide];
    int pixelsHigh = [rep pixelsHigh];
    int bytesPerRow = [rep bytesPerRow];
    NSBitmapImageRep *newrep;
    unsigned char *srcData;
    unsigned char *dstData;
    unsigned char *psrc;
    unsigned char *pdst;
    unsigned char *limit;

    newIcon = [[NSImage alloc] initWithSize: NSMakeSize(pixelsWide, pixelsHigh)];

    newrep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                pixelsWide: pixelsWide
                                pixelsHigh: pixelsHigh
                                bitsPerSample: 8
                                samplesPerPixel: 4
                                hasAlpha: YES
                                isPlanar: NO
                                colorSpaceName: NSDeviceRGBColorSpace
                                bytesPerRow: 0
                                bitsPerPixel: 0];

    [newIcon addRepresentation: newrep];
    RELEASE (newrep); 

    srcData = [rep bitmapData];
    dstData = [newrep bitmapData];
    psrc = srcData;
    pdst = dstData;

    limit = srcData + pixelsHigh * bytesPerRow;

    while (psrc < limit) {
      *pdst++ = lighterLUT[*(psrc+0)];  
      *pdst++ = lighterLUT[*(psrc+1)];  
      *pdst++ = lighterLUT[*(psrc+2)];  
      *pdst++ = (bitsPerPixel == 32) ? *(psrc+3) : 255;
      psrc += (bitsPerPixel == 32) ? 4 : 3;
    }

  } else {
    newIcon = [icon copy];
  }

  RELEASE (arp);

  return [newIcon autorelease];  
}

- (NSImage *)darkerIcon:(NSImage *)icon
{
  CREATE_AUTORELEASE_POOL(arp);
  NSData *tiffdata = [icon TIFFRepresentation];
  NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData: tiffdata];
  int samplesPerPixel = [rep samplesPerPixel];
  int bitsPerPixel = [rep bitsPerPixel];
  NSImage *newIcon;

	if (((samplesPerPixel == 3) && (bitsPerPixel == 24)) 
              || ((samplesPerPixel == 4) && (bitsPerPixel == 32))) {
    int pixelsWide = [rep pixelsWide];
    int pixelsHigh = [rep pixelsHigh];
    int bytesPerRow = [rep bytesPerRow];
    NSBitmapImageRep *newrep;
    unsigned char *srcData;
    unsigned char *dstData;
    unsigned char *psrc;
    unsigned char *pdst;
    unsigned char *limit;

    newIcon = [[NSImage alloc] initWithSize: NSMakeSize(pixelsWide, pixelsHigh)];

    newrep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                pixelsWide: pixelsWide
                                pixelsHigh: pixelsHigh
                                bitsPerSample: 8
                                samplesPerPixel: 4
                                hasAlpha: YES
                                isPlanar: NO
                                colorSpaceName: NSDeviceRGBColorSpace
                                bytesPerRow: 0
                                bitsPerPixel: 0];

    [newIcon addRepresentation: newrep];
    RELEASE (newrep); 

    srcData = [rep bitmapData];
    dstData = [newrep bitmapData];
    psrc = srcData;
    pdst = dstData;

    limit = srcData + pixelsHigh * bytesPerRow;

    while (psrc < limit) {
      *pdst++ = darkerLUT[*(psrc+0)];  
      *pdst++ = darkerLUT[*(psrc+1)];  
      *pdst++ = darkerLUT[*(psrc+2)];  
      *pdst++ = (bitsPerPixel == 32) ? *(psrc+3) : 255;
      psrc += (bitsPerPixel == 32) ? 4 : 3;
    }

  } else {
    newIcon = [icon copy];
  }

  RELEASE (arp);

  return [newIcon autorelease];  
}

- (void)prepareThumbnailsCache
{
  NSString *dictName = @"thumbnails.plist";
  NSString *dictPath = [thumbnailDir stringByAppendingPathComponent: dictName];
  NSDictionary *tdict;

  DESTROY (tumbsCache);
  tumbsCache = [NSMutableDictionary new];
  
  tdict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
    
  if (tdict) {
    NSArray *keys = [tdict allKeys];
    int i;

    for (i = 0; i < [keys count]; i++) {
      NSString *key = [keys objectAtIndex: i];
      NSString *tumbname = [tdict objectForKey: key];
      NSString *tumbpath = [thumbnailDir stringByAppendingPathComponent: tumbname]; 

      if ([fm fileExistsAtPath: tumbpath]) {
        NSImage *tumb = [[NSImage alloc] initWithContentsOfFile: tumbpath];
        
        if (tumb) {
          [tumbsCache setObject: tumb forKey: key];
          RELEASE (tumb);
        }
      }
    }
  } 
}

- (NSImage *)thumbnailForPath:(NSString *)apath
{
  if (usesThumbnails && tumbsCache) {
    return [tumbsCache objectForKey: apath];
  }
  return nil;
}

@end
