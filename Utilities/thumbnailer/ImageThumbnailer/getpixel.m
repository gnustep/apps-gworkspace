 /*
 *  getpixel.m: 
 *
 *  Copyright (c) 2003 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: June 2003
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <stdlib.h>
#include <objc/objc.h>
#include <stdlib.h>
#include "common.h"
#include "getpixel.h"

static const commonInfo *comInfo;
static const unsigned char *rr, *gg, *bb, *kk, *aa;

static int cs0, cs1;
static int elems;	
static int alpx, kkx, palp;
static BOOL ismono;
static int bufp, yline;
static unsigned char *buffer[MAXPLANE];
static int had_alpha;

static int _cc;
static short _pp[] = { 0, 0x55, 0xaa, 0xff };
#define pigment(c)	(((_cc = ((c) & 0xf0)) == 0xf0) ? 0xff : _cc)
#define pigment2(c)	(_pp[((c) & 0xc0) >> 6])

void convCMYKtoRGB(int width, int kkx, unsigned char **planes)
{
	int	x, i;
	float	k;
	id	clr, newclr;
	float	cs[3];
	NSAutoreleasePool *subpool;

	subpool = [[NSAutoreleasePool alloc] init];
  
	for (x = 0; x < width; x++) {
		k = kkx ? (planes[kkx][x] / 255.0) : 0.0;
		clr = [NSColor colorWithDeviceCyan: planes[0][x]/255.0
			                         magenta: planes[1][x]/255.0
			                          yellow: planes[2][x]/255.0
			                           black: k
			                           alpha: 1.0];
		newclr = [clr colorUsingColorSpaceName: NSDeviceRGBColorSpace];
		[newclr getRed:&cs[0] green:&cs[1] blue:&cs[2] alpha:NULL];
		for (i = 0; i < 3; i++) {
			planes[i][x] = (int)(cs[i] * 255.0);
    }
	}
  
	[subpool release];
}


BOOL initGetPixel(const commonInfo *cinf)
{
	int i, wid, elnum;
	unsigned char *p;
	static int buffer_size = 0;

	comInfo = cinf;
	if (comInfo->cspace == CS_Black) {
		cs0 = 0xff, cs1 = 0;
	} else {
		cs0 = 0, cs1 = 0xff;
  }
	ismono = (comInfo->numcolors == 1);
	palp = 0;
	if (comInfo->alpha) {
		elems = 4;
		alpx = 3;	// even if mono images
	} else {
		elems = 3;
		alpx = 0;
	}
	if (comInfo->cspace == CS_CMYK) {
		elems++;
		elnum = 5;
		kkx = 3;
		if (comInfo->alpha) {
			alpx = 4;
    }
	} else {
		elnum = 4;
		kkx = 0;
	}
	wid = (comInfo->width + 7) & 0xfff8;
	if (wid > MAXWidth) {
		return NO;
  }
	if (wid * elnum > buffer_size) {
		if (buffer_size > 0) {
      NSZoneFree(NSDefaultMallocZone(), buffer[0]);  
    }
		buffer_size = wid * elnum;
		p = NSZoneMalloc(NSDefaultMallocZone(), buffer_size);
    
		if (p == NULL) {
			buffer_size = 0;
			return NO;
		}
		for (i = 0; i < elnum; i++) {
			buffer[i] = p;
			p += wid;
		}
	}
  
	return YES;
}

void resetPixel(refmap planes, int y)
{
	had_alpha = 0;
	rr = planes[0];
  
	if (!comInfo->isplanar) {
		aa = gg = bb = kk = rr;
  } else if (ismono) {
		gg = bb = kk = rr;
		aa = planes[alpx ? 1 : 0];
	} else {
		gg = planes[1];
		bb = planes[2];
		kk = planes[kkx];
		aa = planes[alpx];
	}
	if (y > 0) {
		int w = comInfo->xbytes * y;
		rr += w;
		gg += w;
		bb += w;
		kk += w;
		aa += w;
	}
	yline = y;
	bufp = MAXWidth;
}

static int alphaToWhite(int c, int a)
{
	int n;
	if (a == AlphaOpaque) {
    return c;
  }
	n = 255 - a + ((c * a) >> 8);	/* (256-c)*((256-a)/256)+c */
	return (n >= 255) ? 255 : n;
}

static int getNextLine(void)
{
	int i, x, mask, xbytes;

	if (++yline > comInfo->height) {
    return -1;	/* End of Image */
  }
	bufp = 0;
	xbytes = comInfo->xbytes;

	if (comInfo->isplanar) { /* -------- Planar Color -------- */
    if (comInfo->bits == 1) {
		  for (x = 0; x < xbytes; x++) {
		    for (mask = 0x80; mask; mask >>= 1) {
			    buffer[RED][bufp]   = (*rr & mask)? cs1 : cs0;
			    buffer[GREEN][bufp] = (*gg & mask)? cs1 : cs0;
			    buffer[BLUE][bufp]  = (*bb & mask)? cs1 : cs0;
			    bufp++;
	      }
        rr++, gg++, bb++;
		  }
		  if (alpx) {
		    bufp = 0;
		    for (x = 0; x < xbytes; x++) {
			    for (mask = 0x80; mask; mask >>= 1) {
			      buffer[alpx][bufp++]  = (*aa & mask)? 0xff : 0;
          }
			    aa++;
		    }
		  }
		  if (kkx) { /* CS_CMYK */
		    bufp = 0;
		    for (x = 0; x < xbytes; x++) {
			    for (mask = 0x80; mask; mask >>= 1) {
			      buffer[kkx][bufp++]  = (*kk & mask)? 0xff : 0;
          }
			    kk++;
		    }
		  }
    } else if (comInfo->bits == 2) {
		  for (x = 0; x < xbytes; x++) {
		    for (i = 0; i < 8; i += 2) {
			    buffer[RED][bufp]   = pigment2(*rr << i);
			    buffer[GREEN][bufp] = pigment2(*gg << i);
			    buffer[BLUE][bufp]  = pigment2(*bb << i);
			    bufp++;
		    }
		    rr++, gg++, bb++;
		  }
		  if (alpx) {
		    bufp = 0;
		    for (x = 0; x < xbytes; x++) {
			    for (i = 0; i < 8; i += 2) {
			      buffer[alpx][bufp++] = pigment2(*aa << i);
          }
			    aa++;
		    }
		  }
		  if (kkx) { /* CS_CMYK */
		    bufp = 0;
		    for (x = 0; x < xbytes; x++) {
			    for (i = 0; i < 8; i += 2) {
			      buffer[kkx][bufp++] = pigment2(*kk << i);
          }
			    kk++;
		    }
		  }
    } else if (comInfo->bits == 4) {
		  for (x = 0; x < xbytes; x++) {
		    buffer[RED][bufp]   = pigment(*rr);
		    buffer[GREEN][bufp] = pigment(*gg);
		    buffer[BLUE][bufp]  = pigment(*bb);
		    bufp++;
		    buffer[RED][bufp]   = pigment(*rr++ << 4);
		    buffer[GREEN][bufp] = pigment(*gg++ << 4);
		    buffer[BLUE][bufp]  = pigment(*bb++ << 4);
		    bufp++;
		  }
		  if (alpx) {
		    bufp = 0;
		    for (x = 0; x < xbytes; x++) {
			    buffer[alpx][bufp++]  = pigment(*aa);
			    buffer[alpx][bufp++]  = pigment(*aa++ << 4);
		    }
		  }
		  if (kkx) { /* CS_CMYK */
		    bufp = 0;
		    for (x = 0; x < xbytes; x++) {
			    buffer[kkx][bufp++]  = pigment(*kk);
			    buffer[kkx][bufp++]  = pigment(*kk++ << 4);
		    }
		  }
    } else /* 8 */ {
		  for (x = 0; x < xbytes; x++) {
		    buffer[RED][x]   = *rr++;
		    buffer[GREEN][x] = *gg++;
		    buffer[BLUE][x]  = *bb++;
		  }
		  if (alpx) {
		    for (x = 0; x < xbytes; x++) {
			    buffer[alpx][x]  = *aa++;
        }
		  }
		  if (kkx) { /* CS_CMYK */
		    for (x = 0; x < xbytes; x++) {
			    buffer[kkx][x]  = *kk++;
        }
		  }
    }
	} else if (ismono) { /* -------- Meshed Mono -------- */
    if (comInfo->bits == 1) {
		  for (x = 0; x < xbytes; x++) {
		    for (mask = 0x80; mask; mask >>= 1) {
			    buffer[0][bufp] = buffer[1][bufp] = buffer[2][bufp] = (*rr & mask)? cs1 : cs0;
			    if (alpx) {
			      mask >>= 1;
			      buffer[alpx][bufp] = (*rr & mask)? cs1 : cs0;
			    }
			    bufp++;
        }
		    rr++;
		  }
    } else if (comInfo->bits == 2) {
		  for (x = 0; x < xbytes; x++) {
		    for (i = 0; i < 8; i += 2) {
			    buffer[0][bufp] = buffer[1][bufp] = buffer[2][bufp] = pigment2(*rr << i);
			    if (alpx) {
			      i += 2;
			      buffer[alpx][bufp] = pigment2(*rr << i);
			    }
			    bufp++;
        }
		    rr++;
		  }
    } else if (comInfo->bits == 4) {
		  if (alpx) {
		    for (bufp = 0; bufp < xbytes; bufp++) {
			    buffer[0][bufp] = buffer[1][bufp] = buffer[2][bufp] = pigment(*rr);
			    buffer[alpx][bufp] = pigment(*rr++ << 4);
		    }
		  } else {
		    int sft = 0;
		    x = 0;
		    for (bufp = 0;  ; bufp++) {
			    buffer[0][bufp] = buffer[1][bufp] = buffer[2][bufp] = pigment(sft ? (*rr << 4) : *rr);
			    if (sft) {
			      sft = 0, rr++;
			      if (++x >= xbytes) break;
			    } else {
			      sft = 1;
          }
        }
		  }
    } else /* 8 */ {
		  for (bufp = 0, x = 0; x < xbytes; bufp++) {
		    buffer[0][bufp] = buffer[1][bufp] = buffer[2][bufp] = *rr++;
		    x++;
		    if (alpx) {
		    	buffer[alpx][bufp] = *rr++;
			    x++;
        }
		  }
    }
  } else { /* -------- Meshed Color -------- */
    int elnum;	/* num. of elements including dummy bits */
    
    elnum = (comInfo->pixbits == 0) ? elems : (comInfo->pixbits / comInfo->bits);
		/* elnum may be >= elems */
    if (comInfo->bits == 1) {
		  i = x = 0;
		  mask = 0x80;
		  for ( ; ; ) {
		    if (i < elems) {
			    buffer[i][bufp] = (*rr & mask)? cs1 : cs0;
        }
		    if (++i >= elnum) {
			    i = 0, bufp++;
        }
		    if ((mask >>= 1) == 0) {
			    mask = 0x80, rr++;
			    if (++x >= xbytes) {
            break;
          }
		    }
		  }
    } else if (comInfo->bits == 2) {
		  i = x = 0;
		  mask = 0;
		  for ( ; ; ) {
		    if (i < elems) {
			    buffer[i][bufp] = pigment2(*rr << mask);
        }
		    if (++i >= elnum) {
			    i = 0, bufp++;
        }
		    if ((mask += 2) == 8) {
			    mask = 0, rr++;
			    if (++x >= xbytes) {
            break;
          }
		    }
		  }
    } else if (comInfo->bits == 4) {
		  int sft = 0;
		  i = x = 0;
		  for ( ; ; ) {
		    if (i < elems) {
			    buffer[i][bufp] = pigment(sft ? (*rr << 4) : *rr);
        }
		    if (++i >= elnum) {
			    i = 0, bufp++;
        }
		    if (sft) {
		    	sft = 0, rr++;
			    if (++x >= xbytes) {
            break;
          }
		    } else {
		    	sft = 1;
        }
		  }
    } else /* 8 */ {
		  /* perhaps, elnum == elems */
		  for (x = 0; x < xbytes; x += elems) {
		    for (i = 0; i < elems; i++) {
			    buffer[i][bufp] = *rr++;
        }
		    bufp++;
		  }
    }
	}

	bufp = 0;
  
	return 0;
}

int getPixel(int *r, int *g, int *b, int *a)
{
	int av;

	if (bufp >= comInfo->width) {
		if (getNextLine() != 0) {
			return -1;
    }
		if (kkx) { /* CS_CMYK */
			convCMYKtoRGB(comInfo->width, kkx, buffer);
    }
	}
	if (alpx && (av = buffer[alpx][bufp]) < AlphaOpaque) {
		had_alpha = 1;
		if (av == AlphaTransp) {
			*r = *g = *b = 255;	/* white */
		} else {
			*r = alphaToWhite(buffer[RED][bufp], av);
			*g = alphaToWhite(buffer[GREEN][bufp], av);
			*b = alphaToWhite(buffer[BLUE][bufp], av);
		}
		*a = av;
	} else {
		*r = buffer[RED][bufp];
		*g = buffer[GREEN][bufp];
		*b = buffer[BLUE][bufp];
		*a = AlphaOpaque;
	}
	if (++bufp >= comInfo->width) {
		return 1;
  }
  
	return 0;
}

int getPixelA(int *elm)
{
	if (bufp >= comInfo->width) {
		if (getNextLine() != 0) {
			return -1;
    }
		if (kkx) { /* CS_CMYK */
			convCMYKtoRGB(comInfo->width, kkx, buffer);
    }
	}
	elm[RED] = buffer[RED][bufp];
	elm[GREEN] = buffer[GREEN][bufp];
	elm[BLUE] = buffer[BLUE][bufp];
	if (alpx) {
		if ((elm[ALPHA] = buffer[alpx][bufp]) < AlphaOpaque) {
			had_alpha = 1;
    }
	} else {
		elm[ALPHA] = AlphaOpaque;
  }
	if (++bufp >= comInfo->width) {
		return 1;
  }
  
	return 0;
}
