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
