/* resize.m
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
#include <stdio.h>
#include <stdlib.h>
#include "common.h"
#include "getpixel.h"

#define DELTA (1.0/512.0)

enum ns_colorspace colorSpaceIdForColorSpaceName(NSString *name)
{
  if (name) {
    if ([name isEqual: NSCalibratedWhiteColorSpace]) {
      return CS_White;
    } else if ([name isEqual: NSCalibratedBlackColorSpace]) {
      return CS_Black;
    } else if ([name isEqual: NSCalibratedRGBColorSpace]) {
      return CS_RGB;
    } else if ([name isEqual: NSDeviceWhiteColorSpace]) {
      return CS_White;
    } else if ([name isEqual: NSDeviceBlackColorSpace]) {
      return CS_Black;
    } else if ([name isEqual: NSDeviceRGBColorSpace]) {
      return CS_RGB;
    } else if ([name isEqual: NSDeviceCMYKColorSpace]) {
      return CS_CMYK;
    } else if ([name isEqual: NSNamedColorSpace]) {
      return CS_Other;
    } else if ([name isEqual: NSCustomColorSpace]) {
      return CS_Other;
    }
  } 

  return CS_Other;
}

int byte_length(int bits, int width)
{
  switch (bits) {
	  case 1: 
      return ((width + 7) >> 3);
	  case 2: 
      return ((width + 3) >> 2);
	  case 4: 
      return ((width + 1) >> 1);
	  case 8:
	  default:
		  break;
	}
  
	return width;
}

BOOL allocImage(unsigned char **planes, 
                  int width, int height, int repbits, int pnum)
{
	int i, xbyte, wd;
	unsigned char *p;

	xbyte = byte_length(repbits, width);
	wd = xbyte * height;
	if ((p = NSZoneMalloc(NSDefaultMallocZone(), wd * pnum)) == NULL) {
		return NO;
  }
	for (i = 0; i < pnum; i++) {
		planes[i] = p;
		p += wd;
	}
	if (pnum < 5) {
    planes[pnum] = NULL;
  }
  
	return YES;
}

commonInfo *makeBilinearResizedMap(float xfactor, float yfactor, commonInfo *cinf,
		unsigned char *map[], unsigned char *newmap[])
{
	commonInfo *newinf = NULL;
	unsigned char *planes[MAXPLANE];
	float **wbuf[2];	// buffer for Bilinear
	float *w1[MAXPLANE], *w2[MAXPLANE];
	unsigned char *wrd[MAXPLANE];
	int	i, j, x, y;
	int	pn;
	int	wy;	// y-axis index of wbuf;

#define ERR_RETURN \
if (w1[0]) NSZoneFree(NSDefaultMallocZone(), w1[0]); \
if (w2[0]) NSZoneFree(NSDefaultMallocZone(), w2[0]); \
if (wrd[0]) NSZoneFree(NSDefaultMallocZone(), wrd[0]); \
if (newinf) NSZoneFree(NSDefaultMallocZone(), newinf); \
if (planes[0]) NSZoneFree(NSDefaultMallocZone(), planes[0]); \
return NULL

	pn = (cinf->numcolors == 1) ? 1 : 3;
	planes[0] = NULL;
	w1[0] = w2[0] = NULL;
	wbuf[0] = w1;
	wbuf[1] = w2;
	wrd[0] = NULL;

	if ((newinf = NSZoneMalloc(NSDefaultMallocZone(), sizeof(commonInfo))) == NULL) {
		ERR_RETURN;
  }
	*newinf = *cinf;
	newinf->width = (int)(cinf->width * xfactor);
	newinf->height = (int)(cinf->height * yfactor);
	if (newinf->width > MAXWidth || newinf->width <= 0
	                || newinf->height > MAXWidth || newinf->height <= 0) {
		ERR_RETURN;
  }
	if (allocImage(wrd, cinf->width + 1, 1, 8, pn) == NO) {
		ERR_RETURN;
  }
	for (i = 0; i < 2; i++) {
		float **wp = wbuf[i];	// w1 & w2
		wp[0] = NSZoneMalloc(NSDefaultMallocZone(), sizeof(float) * newinf->width * pn);
		if (wp[0] == NULL) {
			ERR_RETURN;
    }
		for (j = 1; j < pn; j++) {
			wp[j] = wp[0] + newinf->width * j;
    }
	}

	newinf->bits = 8;
	newinf->xbytes = byte_length(newinf->bits, newinf->width);
	newinf->palette = NULL;
	newinf->palsteps = 0;
	newinf->isplanar = YES;
	newinf->pixbits = 0;	/* don't care */
	newinf->alpha = NO;	  /* remove Alpha */
	if (cinf->cspace == CS_Black) {
		newinf->cspace = CS_White;
  }
  
	if (allocImage(planes, newinf->width, newinf->height, 8, pn) == NO) {
		ERR_RETURN;
  }
	if (initGetPixel(cinf) == NO) {
		ERR_RETURN;
  }
  
	resetPixel((refmap)map, 0);
	wy = -2;
	for (y = 0; y < newinf->height; y++) {
		double mapy;
		double dif, dif2;
		int yidx, wbufidx;
		unsigned char *pp;
		float *wp1, *wp2;
		mapy = y / (double)yfactor;
		yidx = (int)mapy;
		for (; wy < yidx; wy++) {
			int idx;
			int elm[MAXPLANE];
			float **wp = wbuf[0];
			wbuf[0] = wbuf[1];
			wbuf[1] = wp;
			for (idx = 0; ; ) { // Read new line
				if (getPixelA(elm) < 0) { // EOF
					wbuf[1] = wbuf[0]; // It's tricky
					break;
				}
				for (i = 0; i < pn; i++) {
					wrd[i][idx] = elm[i];
        }
				if (++idx >= cinf->width) {
					for (i = 0; i < pn; i++) {
						wrd[i][idx] = elm[i];	// right edge
          }
					break;
				}
			}
			for (x = 0; x < newinf->width; x++) {
				double mapx = x / (double)xfactor;
				int xidx = (int)mapx;
				dif = mapx - xidx;
				dif2 = (xidx + 1) - mapx;
				for (i = 0; i < pn; i++) {
		      wp[i][x] = wrd[i][xidx] * dif2 + wrd[i][xidx+1] * dif;
        }
			}
		}
		dif = mapy - yidx;
		dif2 = (yidx + 1) - mapy;
		wbufidx = -1;
		if (dif < DELTA) {
      wbufidx = 0;
    } else if (dif2 < DELTA) {
      wbufidx = 1;
    }
		if (wbufidx >= 0) {
			for (i = 0; i < pn; i++) {
				pp = planes[i] + y * newinf->width;
				wp1 = wbuf[wbufidx][i];
				for (x = 0; x < newinf->width; x++) {
          pp[x] = (unsigned char)(wp1[x] + 0.5);
        }
			}
		} else {
			for (i = 0; i < pn; i++) {
				pp = planes[i] + y * newinf->width;
				wp1 = wbuf[0][i];
				wp2 = wbuf[1][i];
				for (x = 0; x < newinf->width; x++) {
				  pp[x] = (unsigned char)(0.5 + wp1[x] * dif2 + wp2[x] * dif);
        }
			}
		}
	}

	for (i = 0; i < pn; i++) {
		newmap[i] = planes[i];
  }
  
  NSZoneFree(NSDefaultMallocZone(), w1[0]);
  NSZoneFree(NSDefaultMallocZone(), w2[0]);
  NSZoneFree(NSDefaultMallocZone(), wrd[0]);
  
	return newinf;
}
