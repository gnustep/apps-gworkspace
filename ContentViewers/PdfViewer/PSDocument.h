/* PSDocument.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2002
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


#ifndef PSDOCUMENT_H
#define PSDOCUMENT_H

#include <Foundation/Foundation.h>

@interface PSDocumentMedia : NSObject											
{
	NSString *name;
	int width, height;
}

+ (id)documentMedia;

- (NSString *)mname;
- (int)width;
- (int)height;

- (void)setName:(NSString *)aname;
- (void)setWidth:(int)w;
- (void)setHeight:(int)h;

@end

@interface PSDocumentPage : NSObject
{
	NSString *label;
	NSRect boundingbox;
	PSDocumentMedia *docmedia;
	int orientation;					/* PORTRAIT, LANDSCAPE */
	long begin, end;					/* offsets into file */
	unsigned len;
	NSString *psPath;
	NSString *tiffPath;
	NSString *dscPath;
}

+ (id)page;

- (NSString *)label;
- (NSRect)boundingbox;
- (PSDocumentMedia *)docmedia;
- (int)orientation;
- (long)begin;
- (long)end;
- (unsigned)len;
- (NSString *)psPath;
- (NSString *)tiffPath;
- (NSString *)dscPath;

- (void)setLabel:(NSString *)labstr;
- (void)setBoundingbox:(int *)bboxptr;
- (void)setMedia:(PSDocumentMedia *)amedia;
- (void)setOrientation:(int)or;
- (void)setBegin:(long)bgpos;
- (void)setEnd:(long)endpos;
- (void)setLen:(unsigned)ln;
- (void)setPsPath:(NSString *)path;
- (void)setTiffPath:(NSString *)path;
- (void)setDscPath:(NSString *)path;

@end

@interface PSDocument : NSObject
{
	BOOL epsf;												/* Encapsulated PostScript flag. */
	NSString *title;									/* Title of document. */
	NSString *date;										/* Creation date. */
	int pageorder;										/* ASCEND, DESCEND, SPECIAL */
	long beginheader, endheader;			/* offsets into file */
	unsigned lenheader;
	long beginpreview, endpreview;
	unsigned lenpreview;
	long begindefaults, enddefaults;
	unsigned lendefaults;
	long beginprolog, endprolog;
	unsigned lenprolog;
	long beginsetup, endsetup;
	unsigned lensetup;
	long begintrailer, endtrailer;
	unsigned lentrailer;
	NSRect boundingbox;
	NSRect default_page_boundingbox;
	int orientation;												/* PORTRAIT, LANDSCAPE */
	int default_page_orientation;						/* PORTRAIT, LANDSCAPE */
	NSMutableArray *media;
	PSDocumentMedia *default_page_media;
	NSMutableArray *pages;
}

- (id)initWithPsFileAtPath:(NSString *)path;

- (BOOL)epsf;													
- (NSString *)title;				
- (NSString *)date;
- (int)pageorder;								
- (long)beginheader;
- (long)endheader;
- (unsigned)lenheader;
- (long)beginpreview;
- (long)endpreview;
- (unsigned)lenpreview;								
- (long)begindefaults;
- (long)enddefaults;		
- (unsigned)lendefaults;							
- (long)beginprolog;
- (long)endprolog;			
- (unsigned)lenprolog;						
- (long)beginsetup;
- (long)endsetup;			
- (unsigned)lensetup;							
- (long)begintrailer;
- (long)endtrailer;		
- (unsigned)lentrailer;						
- (NSRect)boundingbox;							
- (NSRect)default_page_boundingbox;
- (int)orientation;											
- (int)default_page_orientation;
- (NSArray *)media;
- (PSDocumentMedia *)default_page_media;
- (NSArray *)pages;

@end

#endif // PSDOCUMENT_H
