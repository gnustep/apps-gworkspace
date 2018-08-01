/* FSNodeRepIcons.m
 *  
 * Copyright (C) 2005-2018 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola
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

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FSNodeRep.h"
#import "FSNFunctions.h"

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

- (NSImage *)iconOfSize:(int)size 
                forNode:(FSNode *)node
{
  NSString *nodepath = [node path];
  NSImage *icon = nil;
  NSImage *baseIcon = nil;
  NSString *key = nil;

  if ([node isDirectory])
    {  
      if ([node isApplication])
	{
	  key = nodepath;
	}
      else if ([node isMountPoint] || [volumes containsObject: nodepath])
	{
	  key = @"disk";
	  baseIcon = hardDiskIcon;
	}
      else if ([node isPackage] == NO)
	{
	  NSString *iconPath = [nodepath stringByAppendingPathComponent: @".dir.tiff"];

	  if ([fm isReadableFileAtPath: iconPath])
	    {
	      key = iconPath;
	    }
	  else
	    {
	      /* we may have more than one folder icon */
	      key = nodepath;
	    }
	}
      else
        {
          /* a bundle */
          key = nodepath;
        }

      if (key != nil)
	{
	  icon = [self cachedIconOfSize: size forKey: key];
    
	  if (icon == nil)
	    {
              if (baseIcon == nil)
                baseIcon = [ws iconForFile: nodepath];

              if (baseIcon == nil)
                {
                  NSLog(@"no WS icon for %@", nodepath);
                }
	      if ([node isLink])
		{
		  NSImage *linkIcon;

		  linkIcon = [NSImage imageNamed:@"common_linkCursor"];
		  baseIcon = [baseIcon copy];
		  [baseIcon lockFocus];
		  [linkIcon compositeToPoint:NSMakePoint(0,0) operation:NSCompositeSourceOver];
		  [baseIcon unlockFocus];
		  [baseIcon autorelease];
		}
  
	      icon = [self cachedIconOfSize: size forKey: key addBaseIcon: baseIcon];
	    }
	}
    }  
  else
    { // NOT DIRECTORY
      NSString *realPath;

      realPath = [nodepath stringByResolvingSymlinksInPath];
      if (usesThumbnails)
	{
	  icon = [self thumbnailForPath: realPath];
      
	  if (icon) {
	    NSSize icnsize = [icon size];

	    if ([node isLink])
	      {
		NSImage *linkIcon;
		
		linkIcon = [NSImage imageNamed:@"common_linkCursor"];
		icon = [icon copy];
		[icon lockFocus];
		[linkIcon compositeToPoint:NSMakePoint(0,0) operation:NSCompositeSourceOver];
		[icon unlockFocus];
		[icon autorelease];
	      }	    
      
	    if ((icnsize.width > size) || (icnsize.height > size))
	      {
		return [self resizedIcon: icon ofSize: size];
	      }  
	  }
	}
      // no thumbnail found
      if (icon == nil)
	{
          NSString *linkKey;
	  NSString *ext = [[realPath pathExtension] lowercaseString];
      
	  if (ext && [ext length])
	    {
	      key = ext;
	    }
	  else
	    {
	      key = @"unknown";
	    }
          linkKey = nil;
          if ([node isLink])
            {
              linkKey = [key stringByAppendingString:@"_linked"];
              icon = [self cachedIconOfSize: size forKey: linkKey];
            }
          else
            {
              icon = [self cachedIconOfSize: size forKey: key];
            }
          
	  if (icon == nil)
	    {
              // we look up the cache, but only in the full size to composite later
              baseIcon = [self cachedIconOfSize: 48 forKey: key];
              if (baseIcon == nil)
                baseIcon = [ws iconForFile: nodepath];

	      if ([node isLink])
		{
		  NSImage *linkIcon;

		  linkIcon = [NSImage imageNamed:@"common_linkCursor"];
		  baseIcon = [baseIcon copy];
		  [baseIcon lockFocus];
		  [linkIcon compositeToPoint:NSMakePoint(0,0) operation:NSCompositeSourceOver];
		  [baseIcon unlockFocus];
		  [baseIcon autorelease];
                  icon = [self cachedIconOfSize: size forKey: linkKey addBaseIcon: baseIcon];
		}
              else
                {
                  icon = [self cachedIconOfSize: size forKey: key addBaseIcon: baseIcon];
                }
	    }
	}      
    }      

  if (icon == nil)
    {
      NSLog(@"Warning: No icon found for %@", nodepath);
    }

  return icon;
}

- (NSImage *)selectedIconOfSize:(int)size 
                        forNode:(FSNode *)node
{
  return [self darkerIcon: [self iconOfSize: size forNode: node]];
}

- (NSImage *)cachedIconOfSize:(int)size 
                       forKey:(NSString *)key
{
  NSMutableDictionary *dict = [iconsCache objectForKey: key];
  
  if (dict != nil) {
    NSNumber *num = [NSNumber numberWithInt: size];
    NSImage *icon = [dict objectForKey: num];
  
    if (icon == nil) {
      NSImage *baseIcon = [dict objectForKey: [NSNumber numberWithInt: 48]];
    
      icon = [self resizedIcon: baseIcon ofSize: size];
      [dict setObject: icon forKey: num];
    }

    return icon;
  }

  return nil;
}

- (NSImage *)cachedIconOfSize:(int)size
                       forKey:(NSString *)key
                  addBaseIcon:(NSImage *)baseIcon
                    
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSSize icnsize = [baseIcon size];
  int basesize = 48;
  
  if ((icnsize.width > basesize) || (icnsize.height > basesize)) {
    baseIcon = [self resizedIcon: baseIcon ofSize: basesize];
  }  

  [dict setObject: baseIcon forKey: [NSNumber numberWithInt: basesize]];
  [iconsCache setObject: dict forKey: key];
  
  return [self cachedIconOfSize: size forKey: key];
}

- (void)removeCachedIconsForKey:(NSString *)key
{
  [iconsCache removeObjectForKey: key];
}

- (NSImage *)multipleSelectionIconOfSize:(int)size
{
  NSSize icnsize = [multipleSelIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: multipleSelIcon ofSize: size];
  }  
  
  return multipleSelIcon;
}

- (NSImage *)openFolderIconOfSize:(int)size 
                          forNode:(FSNode *)node
{
  NSString *ipath = [[node path] stringByAppendingPathComponent: @".opendir.tiff"];
  NSImage *icon = nil;

  if ([fm isReadableFileAtPath: ipath]) {
    NSImage *img = [[NSImage alloc] initWithContentsOfFile: ipath];

    if (img) {
      icon = AUTORELEASE (img);
    } else {
      icon = [self darkerIcon: [self iconOfSize: size forNode: node]];
    }      
  } else {
    if ([node isMountPoint] || [volumes containsObject: [node path]]) {
      icon = [self darkerIcon: hardDiskIcon];
    } else {
      icon = [self darkerIcon: [self iconOfSize: size forNode: node]];
    }
  }

  if (icon) {
    NSSize icnsize = [icon size];

    if ((icnsize.width > size) || (icnsize.height > size)) {
      return [self resizedIcon: icon ofSize: size];
    }  
  }
  
  return icon;
}


- (NSImage *)trashIconOfSize:(int)size
{
  NSSize icnsize = [trashIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: trashIcon ofSize: size];
  }  
  
  return trashIcon;
}

- (NSImage *)trashFullIconOfSize:(int)size
{
  NSSize icnsize = [trashFullIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: trashFullIcon ofSize: size];
  }  
  
  return trashFullIcon;
}

- (NSBezierPath *)highlightPathOfSize:(NSSize)size
{
  NSSize intsize = NSMakeSize(ceil(size.width), ceil(size.height));
  NSBezierPath *bpath = [NSBezierPath bezierPath];
  float clenght = intsize.height / 4;
  NSPoint p, cp1, cp2;
  
  p = NSMakePoint(clenght, 0);
  [bpath moveToPoint: p];

  p = NSMakePoint(0, clenght);
  cp1 = NSMakePoint(0, 0);
  cp2 = NSMakePoint(0, 0);
  [bpath curveToPoint: p controlPoint1: cp1 controlPoint2: cp2];

  p = NSMakePoint(0, intsize.height - clenght);
  [bpath lineToPoint: p];

  p = NSMakePoint(clenght, intsize.height);
  cp1 = NSMakePoint(0, intsize.height);
  cp2 = NSMakePoint(0, intsize.height);
  [bpath curveToPoint: p controlPoint1: cp1 controlPoint2: cp2];

  p = NSMakePoint(intsize.width - clenght, intsize.height);
  [bpath lineToPoint: p];

  p = NSMakePoint(intsize.width, intsize.height - clenght);
  cp1 = NSMakePoint(intsize.width, intsize.height);
  cp2 = NSMakePoint(intsize.width, intsize.height);
  [bpath curveToPoint: p controlPoint1: cp1 controlPoint2: cp2];

  p = NSMakePoint(intsize.width, clenght);
  [bpath lineToPoint: p];

  p = NSMakePoint(intsize.width - clenght, 0);
  cp1 = NSMakePoint(intsize.width, 0);
  cp2 = NSMakePoint(intsize.width, 0);
  [bpath curveToPoint: p controlPoint1: cp1 controlPoint2: cp2];

  [bpath closePath];
  
  return bpath;
}

- (float)highlightHeightFactor
{
  return 0.8125;
}

- (NSImage *)resizedIcon:(NSImage *)icon 
                  ofSize:(int)size
{
  CREATE_AUTORELEASE_POOL(arp);
  NSSize icnsize = [icon size];
  NSRect srcr = NSMakeRect(0, 0, icnsize.width, icnsize.height);
  float fact = (icnsize.width >= icnsize.height) ? (icnsize.width / size) : (icnsize.height / size);
  NSSize newsize = NSMakeSize(floor(icnsize.width / fact + 0.5), floor(icnsize.height / fact + 0.5));	
  NSRect dstr = NSMakeRect(0, 0, newsize.width, newsize.height);
  NSImage *newIcon = [[NSImage alloc] initWithSize: newsize];
  NSBitmapImageRep *rep = nil;
  
  [newIcon lockFocus];

  [icon drawInRect: dstr 
          fromRect: srcr 
         operation: NSCompositeSourceOver 
          fraction: 1.0];

  rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: dstr];
  [newIcon addRepresentation: rep];
  RELEASE (rep);

  [newIcon unlockFocus];

  RELEASE (arp);

  return AUTORELEASE (newIcon);  
}

/*
// using nearest neighbour algorithm

#define MIX_LIM 16

- (NSImage *)resizedIcon:(NSImage *)icon 
                  ofSize:(int)size
{
  CREATE_AUTORELEASE_POOL(arp);
  NSData *tiffdata = [icon TIFFRepresentation];
  NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData: tiffdata];
  int spp = [rep samplesPerPixel];
  int bitsPerPixel = [rep bitsPerPixel];
  int bpp = bitsPerPixel / 8;
  NSImage *newIcon = nil;

	if (((spp == 3) && (bitsPerPixel == 24)) 
        || ((spp == 4) && (bitsPerPixel == 32))
        || ((spp == 1) && (bitsPerPixel == 8))
        || ((spp == 2) && (bitsPerPixel == 16))) {
    NSSize icnsize = [icon size];
    float fact = (icnsize.width >= icnsize.height) ? (icnsize.width / size) : (icnsize.height / size);
    NSSize newsize = NSMakeSize(floor(icnsize.width / fact + 0.5), floor(icnsize.height / fact + 0.5));	
    float xratio = icnsize.width / newsize.width;
    float yratio = icnsize.height / newsize.height;
    BOOL hasAlpha = [rep hasAlpha];
    BOOL isColor = hasAlpha ? (spp > 2) : (spp > 1);
    NSString *colorSpaceName = isColor ? NSCalibratedRGBColorSpace : NSCalibratedWhiteColorSpace;      
    NSBitmapImageRep *newrep;
    unsigned char *srcData;
    unsigned char *dstData;    
    unsigned x, y;

    newIcon = [[NSImage alloc] initWithSize: newsize];

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

    [newIcon addRepresentation: newrep];
    RELEASE (newrep); 

    srcData = [rep bitmapData];
    dstData = [newrep bitmapData];

    for (y = 0; y < (int)(newsize.height); y++) {
      int px[2], py[2]; 

      py[0] = floor(y * yratio);
      py[1] = ceil((y + 1) * yratio);
      py[1] = ((py[1] > icnsize.height) ? (int)(icnsize.height) : py[1]);

      for (x = 0; x < (int)(newsize.width); x++) {
        int expos = (int)(bpp * (floor(y * yratio) * icnsize.width + floor(x * xratio)));        
        unsigned expix[4] = { 0, 0, 0, 0 };      
        unsigned pix[4] = { 0, 0, 0, 0 };
        int count = 0;
        unsigned char c;
        int i, j;

        expix[0] = srcData[expos];
        
        if (isColor) {
          expix[1] = srcData[expos + 1];
          expix[2] = srcData[expos + 2];
          expix[3] = (hasAlpha ? srcData[expos + 3] : 255);
        } else {
          expix[1] = (hasAlpha ? srcData[expos + 1] : 255);
        }

        px[0] = floor(x * xratio);
        px[1] = ceil((x + 1) * xratio);
        px[1] = ((px[1] > icnsize.width) ? (int)(icnsize.width) : px[1]);

        for (i = px[0]; i < px[1]; i++) {
          for (j = py[0]; j < py[1]; j++) {
            int pos = (int)(bpp * (j * icnsize.width + i));

            pix[0] += srcData[pos];

            if (isColor) {
              pix[1] += srcData[pos + 1];
              pix[2] += srcData[pos + 2];
              pix[3] += (hasAlpha ? srcData[pos + 3] : 255);
            } else {
              pix[1] += (hasAlpha ? srcData[pos + 1] : 255);
            }
            
            count++;
          }
        }

        c = (unsigned char)(pix[0] / count);
        *dstData++ = ((abs(c - expix[0]) < MIX_LIM) ? (unsigned char)expix[0] : c);
        
        if (isColor) {
          c = (unsigned char)(pix[1] / count);
          *dstData++ = ((abs(c - expix[1]) < MIX_LIM) ? (unsigned char)expix[1] : c);

          c = (unsigned char)(pix[2] / count);
          *dstData++ = ((abs(c - expix[2]) < MIX_LIM) ? (unsigned char)expix[2] : c);

          c = (unsigned char)(pix[3] / count);
          *dstData++ = ((abs(c - expix[3]) < MIX_LIM) ? (unsigned char)expix[3] : c);
        
        } else {
          c = (unsigned char)(pix[1] / count);
          *dstData++ = ((abs(c - expix[1]) < MIX_LIM) ? (unsigned char)expix[1] : c);
        }
      }
    }

  } else {
    NSSize icnsize = [icon size];
    NSRect srcr = NSMakeRect(0, 0, icnsize.width, icnsize.height);
    float fact = (icnsize.width >= icnsize.height) ? (icnsize.width / size) : (icnsize.height / size);
    NSSize newsize = NSMakeSize(floor(icnsize.width / fact + 0.5), floor(icnsize.height / fact + 0.5));	
    NSRect dstr = NSMakeRect(0, 0, newsize.width, newsize.height);
    NSBitmapImageRep *rep = nil;
    
    newIcon = [[NSImage alloc] initWithSize: newsize];
    [newIcon lockFocus];

    [icon drawInRect: dstr 
            fromRect: srcr 
           operation: NSCompositeSourceOver 
            fraction: 1.0];

    rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: dstr];
    [newIcon addRepresentation: rep];
    RELEASE (rep);
    
    [newIcon unlockFocus];
  }

  RELEASE (arp);

  return AUTORELEASE (newIcon);  
}
*/

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
  
  if ([fm fileExistsAtPath: dictPath]) {
    tdict = [NSDictionary dictionaryWithContentsOfFile: dictPath];

    if (tdict) {
      NSArray *keys = [tdict allKeys];
      int i;

      for (i = 0; i < [keys count]; i++) {
        NSString *key = [keys objectAtIndex: i];
        NSString *tumbname = [tdict objectForKey: key];
        NSString *tumbpath = [thumbnailDir stringByAppendingPathComponent: tumbname]; 

        if ([fm fileExistsAtPath: tumbpath]) {
          NSImage *tumb = nil;
        
          NS_DURING
            {
          tumb = [[NSImage alloc] initWithContentsOfFile: tumbpath];
          
          if (tumb) {
            [tumbsCache setObject: tumb forKey: key];
            RELEASE (tumb);
          }
            }
          NS_HANDLER
            {
          NSLog(@"BAD IMAGE '%@'", tumbpath);
            }
          NS_ENDHANDLER
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


/*
    // original nearest neighbour algorithm
    
    for (y = 0; y < (int)newsize.height; y++) {
      for (x = 0; x < (int)newsize.width; x++) {
        int pos = (int)(bpp * (floor(y * yratio) * icnsize.width + floor(x * xratio)));

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
    
*/    
