/* PdfViewer.h
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


#ifndef PDFVIEWER_H
#define PDFVIEWER_H

#include <AppKit/NSView.h>
  #ifdef GNUSTEP 
#include "ContentViewersProtocol.h"
  #else
#include <GWorkspace/ContentViewersProtocol.h>
  #endif

@class NSTask;
@class NSPipe;
@class NSFileHandle;
@class NSNotificationCenter;
@class NSScrollView;
@class NSMatrix;
@class NSImageView;
@class NSTextField;
@class NSButton;
@class PSDocument;
@class PSDocumentPage;

@interface PdfViewer : NSView <ContentViewersProtocol>
{
	id panel;
	int index;
  
	NSScrollView *scroll;
	NSMatrix *matrix;
	NSButton *backButt, *nextButt;
	id buttOk;
	NSImageView *imageView;
	NSRect imrect;
	NSTextField *errLabel;
  NSString *bundlePath;
	BOOL valid;
	
	PSDocument *psdoc;
	BOOL structured;	
	NSString *unstructPsPath;
	NSString *unstructTiffPath;	
	int pageIdentifier;
	NSDictionary *paperSizes;
	int pageindex;
	float resolution;
	NSSize papersize;
	BOOL isPdf;
	NSString *gsComm;
	NSString *myPath;
	NSString *editPath;	
	NSString *myName;
	NSTask *task;
	BOOL busy;
		
	NSFileManager *fm;	
	NSNotificationCenter *nc;
	id ws;
}

- (NSDictionary *)uniquePageIdentifier;

- (void)setBusy:(BOOL)value;

- (void)makePage;

- (void)makeUnstructuredPageForPath:(NSString *)path;

- (void)nextPage:(id)sender;

- (void)previousPage:(id)sender;

- (void)goToPage:(id)sender;

- (void)clearTempFiles;

- (void)clearTempFilesOfPage:(PSDocumentPage *)page;

- (void)taskOut:(NSNotification *)notif;

- (void)taskErr:(NSNotification *)notif;

- (void)endOfTask:(NSNotification *)notif;

- (void)editFile:(id)sender;

@end

#endif // PDFVIEWER_H
