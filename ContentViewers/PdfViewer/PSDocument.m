/* PSDocument.m
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


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "PSDocument.h"
#include "ps.h"
#include "GNUstep.h"

#define MAKESTRING(c) [NSString stringWithCString: c]
			
@implementation PSDocumentMedia

+ (id)documentMedia
{
	PSDocumentMedia *media = [PSDocumentMedia new];
	media->name = nil;
	media->width = 0;
	media->height = 0;
	return AUTORELEASE (media);
}

- (void)dealloc
{
  TEST_RELEASE (name);
	[super dealloc];
}

- (NSString *)mname
{
	return name;
}

- (int)width
{
	return width;
}

- (int)height
{
	return height;
}

- (void)setName:(NSString *)aname
{
	ASSIGN (name, aname);
}

- (void)setWidth:(int)w
{
	width = w;
}

- (void)setHeight:(int)h
{
	height = h;
}

@end

@implementation PSDocumentPage

+ (id)page
{
	PSDocumentPage *page = [PSDocumentPage new];
	page->label = nil;
	page->boundingbox = NSZeroRect;
	page->docmedia = nil;
	page->orientation = -1;
	page->begin = 0;
	page->end = 0;
	page->len = 0;	
	page->psPath = nil;
	page->tiffPath = nil;
	page->dscPath = nil;	
	return AUTORELEASE (page);
}

- (void)dealloc
{
  TEST_RELEASE (label);
  TEST_RELEASE (docmedia);
  TEST_RELEASE (psPath);
  TEST_RELEASE (tiffPath);
  TEST_RELEASE (dscPath);
	[super dealloc];
}

- (NSString *)label
{
	return label;
}

- (NSRect)boundingbox
{
	return boundingbox;
}

- (PSDocumentMedia *)docmedia
{
	return docmedia;
}

- (int)orientation
{
	return orientation;
}

- (long)begin
{
	return begin;
}

- (long)end
{
	return end;
}

- (unsigned)len
{
	return len;
}

- (NSString *)psPath
{
	return psPath;
}

- (NSString *)tiffPath
{
	return tiffPath;
}

- (NSString *)dscPath
{
	return dscPath;
}

- (void)setLabel:(NSString *)labstr
{
	ASSIGN (label, labstr);
}

- (void)setBoundingbox:(int *)bboxptr
{
	boundingbox = NSMakeRect(bboxptr[0], bboxptr[1], bboxptr[2], bboxptr[3]);
}

- (void)setMedia:(PSDocumentMedia *)amedia
{
	ASSIGN (docmedia, amedia);
}

- (void)setOrientation:(int)or
{
	orientation = or;
}

- (void)setBegin:(long)bgpos
{
	begin = bgpos;
}

- (void)setEnd:(long)endpos
{
	end = endpos;
}

- (void)setLen:(unsigned)ln
{
	len = ln;
}

- (void)setPsPath:(NSString *)path
{
	ASSIGN (psPath, path);
}

- (void)setTiffPath:(NSString *)path
{
	ASSIGN (tiffPath, path);
}

- (void)setDscPath:(NSString *)path
{
	ASSIGN (dscPath, path);
}

@end

@implementation PSDocument

- (void)dealloc
{
	RELEASE (pages);
	RELEASE (media);
  TEST_RELEASE (title);
  TEST_RELEASE (date);
	TEST_RELEASE (default_page_media);
	[super dealloc];
}

- (id)initWithPsFileAtPath:(NSString *)path
{
	self = [super init];

	if (self) {
		struct document *doc;
		FILE *file;
		int i, count;
		
		if ((file = fopen([path cString], "r")) == NULL) {
			NSLog(@"failed to open: %@", [path lastPathComponent]);
			return nil;
		}
		
		doc = NULL;
		doc = psscan(file);
		
		if (doc == NULL) {
			NSLog(@"failed to parse: %@", [path lastPathComponent]);
			fclose(file);
			return nil;
		}
		
		fclose(file);
		
		if (doc->title != NULL) {
			ASSIGN (title, MAKESTRING (doc->title));
		}
		if (doc->date != NULL) {
			ASSIGN (date, MAKESTRING (doc->date));
		}		

#define GET(x) if (doc->x) x = (doc->x); else x = 0

		GET (epsf);
		GET (beginheader);
		GET (endheader);
		GET (lenheader);
		GET (beginpreview);
		GET (endpreview);
		GET (lenpreview);
		GET (begindefaults);
		GET (enddefaults);
		GET (lendefaults);
		GET (beginprolog);
		GET (endprolog);
		GET (lenprolog);
		GET (beginsetup);
		GET (endsetup);
		GET (lensetup);
		GET (begintrailer);
		GET (endtrailer);
		GET (lentrailer);
		
		boundingbox = NSMakeRect(doc->boundingbox[0], doc->boundingbox[1],
																doc->boundingbox[2], doc->boundingbox[3]);
		
		default_page_boundingbox = NSMakeRect(doc->default_page_boundingbox[0], 
																					doc->default_page_boundingbox[1],
																					doc->default_page_boundingbox[2], 
																					doc->default_page_boundingbox[3]);
		
		GET (orientation);
		GET (default_page_orientation);
		
		count = doc->nummedia;
		media = [[NSMutableArray alloc] initWithCapacity: 1];
		
		for (i = 0; i < count; i++) {
			PSDocumentMedia *psdmedia = [PSDocumentMedia documentMedia];
			[psdmedia setName: MAKESTRING (doc->media[i].name)];
			[psdmedia setWidth: doc->media[i].width];
			[psdmedia setHeight: doc->media[i].height];
			[media addObject: psdmedia];
		}
		
		default_page_media = [PSDocumentMedia new];
		if (doc->default_page_media != NULL) {
			[default_page_media setName: MAKESTRING (doc->default_page_media->name)];
			[default_page_media setWidth: doc->default_page_media->width];
			[default_page_media setHeight: doc->default_page_media->height];
		}
			
		count = doc->numpages;
		pages = [[NSMutableArray alloc] initWithCapacity: 1];
	
		for (i = 0; i < count; i++) {
			PSDocumentPage *psdpage;
			PSDocumentMedia *psdmedia;
			
			psdpage = [PSDocumentPage page];
			
			[psdpage setLabel: MAKESTRING (doc->pages[i].label)];
			[psdpage setBoundingbox: doc->pages[i].boundingbox];
			
			psdmedia = [PSDocumentMedia documentMedia];
			
			if (doc->pages[i].media != NULL) {
				[psdmedia setName: MAKESTRING (doc->pages[i].media->name)];
				[psdmedia setWidth: doc->media[i].width];
				[psdmedia setHeight: doc->media[i].height];			
			}
			
			[psdpage setMedia: psdmedia];

			[psdpage setOrientation: doc->pages[i].orientation];
			[psdpage setBegin: doc->pages[i].begin];
			[psdpage setEnd: doc->pages[i].end];
			[psdpage setLen: doc->pages[i].len];
			
			[pages addObject: psdpage];
		}

		psfree(doc);
	}
	
	return self;
}

- (BOOL)epsf
{
	return epsf; 
}
													
- (NSString *)title
{
	return title; 
}
				
- (NSString *)date
{
	return date; 
}

- (int)pageorder
{
	return pageorder; 
}
								
- (long)beginheader
{
	return beginheader; 
}

- (long)endheader
{
	return endheader; 
}

- (unsigned)lenheader
{
	return lenheader; 
}

- (long)beginpreview
{
	return beginpreview; 
}

- (long)endpreview
{
	return endpreview; 
}

- (unsigned)lenpreview
{
	return lenpreview; 
}
								
- (long)begindefaults
{
	return begindefaults; 
}

- (long)enddefaults
{
	return enddefaults; 
}
		
- (unsigned)lendefaults
{
	return lendefaults; 
}
							
- (long)beginprolog
{
	return beginprolog; 
}

- (long)endprolog
{
	return endprolog; 
}
			
- (unsigned)lenprolog
{
	return lenprolog; 
}
						
- (long)beginsetup
{
	return beginsetup; 
}

- (long)endsetup
{
	return endsetup; 
}
			
- (unsigned)lensetup
{
	return lensetup; 
}
							
- (long)begintrailer
{
	return begintrailer; 
}

- (long)endtrailer
{
	return endtrailer; 
}
		
- (unsigned)lentrailer
{
	return lentrailer; 
}
						
- (NSRect)boundingbox
{
	return boundingbox; 
}
							
- (NSRect)default_page_boundingbox
{
	return default_page_boundingbox; 
}

- (int)orientation
{
	return orientation; 
}
											
- (int)default_page_orientation
{
	return default_page_orientation; 
}

- (NSArray *)media
{
	return media; 
}

- (PSDocumentMedia *)default_page_media
{
	return default_page_media; 
}

- (NSArray *)pages
{
	return pages; 
}

@end
