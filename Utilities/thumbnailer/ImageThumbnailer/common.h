/* common.h
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


#ifndef COMMON_H
#define COMMON_H

#define  isAlphaOpaque(x)	((x) >= 255)
#define  isAlphaTransp(x)	((x) < 255)
#define  AlphaOpaque		255
#define  AlphaTransp		0
#define  Bright255(r, g, b)	(((r)*30 + (g)*59 + (b)*11 + 50) / 100)

#define  RED		  0
#define  GREEN		1
#define  BLUE		  2
#define  ALPHA		3
#define  MAXPLANE	5

enum ns_colorspace {
	CS_White, 
  CS_Black, 
  CS_RGB, 
  CS_CMYK, 
  CS_Other
};

/* Operations */

#define  MAXWidth	4096	/* MAX width that ToyViewer can display */
#define  MAX_COMMENT	256
#define	 MAXFILENAMELEN	512

typedef unsigned char	paltype[3];
typedef const unsigned char *const *refmap;

typedef struct {
	int	width, height;
	short	xbytes;		/* (number of bytes)/line */
	short	palsteps;	/* colors of palette */
	unsigned char	bits;
	unsigned char	pixbits;	/* bits/pixel (mesh) */
	unsigned char	numcolors;	/* color elements without alpha */
	BOOL	isplanar, alpha;
  enum ns_colorspace cspace;
	paltype	*palette;
	unsigned char	memo[MAX_COMMENT];
} commonInfo;

#endif // COMMON_H
