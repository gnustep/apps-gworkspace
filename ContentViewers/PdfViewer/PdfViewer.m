/* PdfViewer.m
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
  #ifdef GNUSTEP 
#include "InspectorsProtocol.h"
#include "GWLib.h"
  #else
#include <GWorkspace/InspectorsProtocol.h>
#include <GWorkspace/GWLib.h>
  #endif
#include "PdfViewer.h"
#include "PSDocument.h"
#include "GNUstep.h"
#include "config.h"

#define MAXPAGES 9999

@implementation PdfViewer

- (void)dealloc
{
  [nc removeObserver: self];
  if (task && [task isRunning]) {
    [task terminate];
	} 
	TEST_RELEASE (task);
	[self clearTempFiles];
	RELEASE (myPath);
	TEST_RELEASE (editPath);
  RELEASE (bundlePath);
	RELEASE (myName);
	TEST_RELEASE (psdoc);
	TEST_RELEASE (unstructPsPath);
	TEST_RELEASE (unstructTiffPath);
	RELEASE (imageView);
	RELEASE (errLabel);
	RELEASE (scroll);
	RELEASE (matrix);
	RELEASE (backButt);
	RELEASE (nextButt);
		
  [super dealloc];
}

- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
	self = [super initWithFrame: frame];

	if(self) {
		id cell;
		
		panel = (id<InspectorsProtocol>)apanel;		
		index = idx;
    
		nc = [NSNotificationCenter defaultCenter];
		fm = [NSFileManager defaultManager];		
		ws = [NSWorkspace sharedWorkspace];

		pageIdentifier = 0;		

		myPath = nil;
		myName = nil;
		psdoc = nil;
    task = nil;
		valid = YES;
		
		unstructPsPath = nil;
		unstructTiffPath = nil;
		
		ASSIGN (gsComm, [NSString stringWithCString: GSPATH]);
		pageindex = 0;

		backButt = [[NSButton alloc] initWithFrame: NSMakeRect(3, 218, 24, 24)];
		[backButt setButtonType: NSMomentaryLight];
		[backButt setImagePosition: NSImageOnly];	
		[backButt setImage: [NSImage imageNamed: @"common_ArrowUpH.tiff"]];
		[backButt setTarget: self];
		[backButt setAction: @selector(previousPage:)];
		[self addSubview: backButt]; 

		nextButt = [[NSButton alloc] initWithFrame: NSMakeRect(3, 194, 24, 24)];
		[nextButt setButtonType: NSMomentaryLight];
		[nextButt setImagePosition: NSImageOnly];	
		[nextButt setImage: [NSImage imageNamed: @"common_ArrowDownH.tiff"]];
		[nextButt setTarget: self];
		[nextButt setAction: @selector(nextPage:)];
		[self addSubview: nextButt]; 

		scroll = [[NSScrollView alloc] initWithFrame: NSMakeRect(28, 194, 228, 50)];
    [scroll setBorderType: NSBezelBorder];
		[scroll setHasHorizontalScroller: YES];
  	[scroll setHasVerticalScroller: NO]; 
		[scroll setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
  	[self addSubview: scroll]; 

    cell = AUTORELEASE ([NSButtonCell new]);
    [cell setButtonType: NSPushOnPushOffButton];
    [cell setImagePosition: NSImageOverlaps]; 
						
    matrix = [[NSMatrix alloc] initWithFrame: NSZeroRect
				            				mode: NSRadioModeMatrix prototype: cell
			       												numberOfRows: 0 numberOfColumns: 0];
    [matrix setIntercellSpacing: NSZeroSize];
    [matrix setCellSize: NSMakeSize(26, 24)];
		[matrix setAllowsEmptySelection: YES];
		[matrix setTarget: self];
		[matrix setAction: @selector(goToPage:)];
		[scroll setDocumentView: matrix];	

		imrect = NSMakeRect(0, 0, 257, 190);
		imageView = [[NSImageView alloc] initWithFrame: imrect];
		[imageView setImageAlignment: NSImageAlignCenter];
  	[self addSubview: imageView]; 

		errLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(2, 90, 252, 25)];	
		[errLabel setFont: [NSFont systemFontOfSize: 18]];
		[errLabel setAlignment: NSCenterTextAlignment];
		[errLabel setBackgroundColor: [NSColor windowBackgroundColor]];
		[errLabel setTextColor: [NSColor grayColor]];	
		[errLabel setBezeled: NO];
		[errLabel setEditable: NO];
		[errLabel setSelectable: NO];
		[errLabel setStringValue: @"Invalid Contents"];

		[self setBusy: NO];
	}
	
	return self;
}

- (void)setBundlePath:(NSString *)path
{
  ASSIGN (bundlePath, path);
}

- (NSString *)bundlePath
{
  return bundlePath;
}

- (void)setIndex:(int)idx
{
  index = idx;
}

- (void)setBusy:(BOOL)value
{
	busy = value;
	[backButt setEnabled: !busy];
	[nextButt setEnabled: !busy];
}

- (NSDictionary *)uniquePageIdentifier
{
	NSString *tempName = [NSString stringWithFormat: @"pdfviewer_%i", pageIdentifier];	
	NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent: tempName];
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];

	[dict setObject: [tempPath stringByAppendingPathExtension: @"ps"] forKey: @"pspath"];
	[dict setObject: [tempPath stringByAppendingPathExtension: @"tiff"] forKey: @"tiffpath"];
	[dict setObject: [tempPath stringByAppendingPathExtension: @"dsc"] forKey: @"dscpath"];

	pageIdentifier++;
	if (pageIdentifier >= MAXPAGES) {
		pageIdentifier = 0;
	}
	
	return dict;
}

- (void)makePage
{
	PSDocumentPage *pspage;
	NSString *psPath, *tiffPath;
	NSFileHandle *fileHandle, *readHandle, *writeHandle;
	NSData *data;
	NSMutableArray *args;
	NSPipe *pipe[2];

  if (task && [task isRunning]) {
		[nc removeObserver: self];
    [task terminate];
	} 
	DESTROY (task);

	[self setBusy: YES];

	[matrix selectCellAtRow: 0 column: pageindex];
	[matrix scrollCellToVisibleAtRow: 0 column: pageindex];
	
	pspage = [[psdoc pages] objectAtIndex: pageindex];
	psPath = [pspage psPath];
	tiffPath = [pspage tiffPath];

	if ([fm fileExistsAtPath: psPath]) {
		[fm removeFileAtPath: psPath handler: nil];
	}
	
	if ([fm fileExistsAtPath: tiffPath]) {
		NSImage *image = [[NSImage alloc] initWithContentsOfFile: tiffPath];
		
		if (image != nil) {
			NSSize is = [image size];
			NSSize rs = imrect.size;

			if (valid == NO) {
				valid = YES;
				[errLabel removeFromSuperview];
				[self addSubview: imageView]; 
				[buttOk setEnabled: YES];	
			}
		
			if ((is.width <= rs.width) || (is.height <= rs.height)) {
				[imageView setImageScaling: NSScaleNone];
			} else {
				[imageView setImageScaling: NSScaleProportionally];
			}		
			
			[image setBackgroundColor: [NSColor windowBackgroundColor]];
			[imageView setImage: image];
			RELEASE (image);
			[self setBusy: NO];
			return;
		}
	}

	[fm createFileAtPath: psPath contents: nil attributes: nil];

	readHandle = [NSFileHandle fileHandleForReadingAtPath: myPath];
	writeHandle = [NSFileHandle fileHandleForWritingAtPath: psPath];

	[readHandle seekToFileOffset: [psdoc beginprolog]];
	data = [readHandle readDataOfLength: [psdoc lenprolog]];
	[writeHandle writeData: data];

	[readHandle seekToFileOffset: [psdoc beginsetup]];
	data = [readHandle readDataOfLength: [psdoc lensetup]];
	[writeHandle writeData: data];

	[readHandle seekToFileOffset: [pspage begin] - 1];		// WHY -1 ??????
	data = [readHandle readDataOfLength: [pspage len]];
	[writeHandle writeData: data];

	[readHandle seekToFileOffset: [psdoc begintrailer]];
	data = [readHandle readDataOfLength: [psdoc lentrailer]];
	[writeHandle writeData: data];

	[readHandle closeFile];
	[writeHandle closeFile];

	args = [NSMutableArray arrayWithCapacity: 1];		
	[args addObject: @"-dQUIET"];
	[args addObject: @"-dSAFER"];
	[args addObject: @"-dSHORTERRORS"];
	[args addObject: @"-dDOINTERPOLATE"];	
	[args addObject: [NSString stringWithFormat: @"-dDEVICEXRESOLUTION=%i", (int)resolution]];	
	[args addObject: [NSString stringWithFormat: @"-dDEVICEYRESOLUTION=%i", (int)resolution]];	
	[args addObject: @"-sDEVICE=tiff24nc"]; 
	[args addObject: [NSString stringWithFormat: @"-sOutputFile=%@", tiffPath]];	
	[args addObject: psPath];	

  ASSIGN (task, [NSTask new]);
  [task setLaunchPath: gsComm];
	[task setArguments: args];

	pipe[0] = [NSPipe pipe];
	[task setStandardOutput: pipe[0]];
  fileHandle = [pipe[0] fileHandleForReading];

	[nc addObserver: self 
      	 selector: @selector(taskOut:) 
      			 name: NSFileHandleReadCompletionNotification
      		 object: (id)fileHandle];

	[fileHandle readInBackgroundAndNotify];

  pipe[1] = [NSPipe pipe];
	[task setStandardError: pipe[1]];		
  fileHandle = [pipe[1] fileHandleForReading];

  [nc addObserver: self 
      	 selector: @selector(taskErr:) 
      			 name: NSFileHandleReadCompletionNotification
      		 object: (id)fileHandle];

	[fileHandle readInBackgroundAndNotify];

  [nc addObserver: self 
      	 selector: @selector(endOfTask:) 
      			 name: NSTaskDidTerminateNotification
      		 object: (id)task];

	[task launch]; 
}

- (void)makeUnstructuredPageForPath:(NSString *)path
{
	NSDictionary *pageIdent;
	NSFileHandle *fileHandle, *writeHandle;
	NSData *data;
	NSMutableArray *args;
	NSPipe *pipe[2];

  if (task && [task isRunning]) {
		[nc removeObserver: self];
    [task terminate];
	} 
	DESTROY (task);

	[self setBusy: YES];

	pageIdent = [self uniquePageIdentifier];
		
	ASSIGN (unstructPsPath, [pageIdent objectForKey: @"pspath"]);
	ASSIGN (unstructTiffPath, [pageIdent objectForKey: @"tiffpath"]);
		
	if ([fm fileExistsAtPath: unstructPsPath]) {
		[fm removeFileAtPath: unstructPsPath handler: nil];
	}
	
	[fm createFileAtPath: unstructPsPath contents: nil attributes: nil];

	data = [NSData dataWithContentsOfFile: myPath];	
	writeHandle = [NSFileHandle fileHandleForWritingAtPath: unstructPsPath];
	[writeHandle writeData: data];
	[writeHandle closeFile];

	args = [NSMutableArray arrayWithCapacity: 1];		
	[args addObject: @"-dQUIET"];
	[args addObject: @"-dSAFER"];
	[args addObject: @"-dSHORTERRORS"];
	[args addObject: @"-dDOINTERPOLATE"];	
	[args addObject: [NSString stringWithFormat: @"-dDEVICEXRESOLUTION=%i", (int)resolution]];	
	[args addObject: [NSString stringWithFormat: @"-dDEVICEYRESOLUTION=%i", (int)resolution]];	
	[args addObject: @"-sDEVICE=tiff24nc"]; 
	[args addObject: [NSString stringWithFormat: @"-sOutputFile=%@", unstructTiffPath]];	
	[args addObject: unstructPsPath];	

  ASSIGN (task, [NSTask new]);
  [task setLaunchPath: gsComm];
	[task setArguments: args];

	pipe[0] = [NSPipe pipe];
	[task setStandardOutput: pipe[0]];
  fileHandle = [pipe[0] fileHandleForReading];

	[nc addObserver: self 
      	 selector: @selector(taskOut:) 
      			 name: NSFileHandleReadCompletionNotification
      		 object: (id)fileHandle];

	[fileHandle readInBackgroundAndNotify];

  pipe[1] = [NSPipe pipe];
	[task setStandardError: pipe[1]];		
  fileHandle = [pipe[1] fileHandleForReading];

  [nc addObserver: self 
      	 selector: @selector(taskErr:) 
      			 name: NSFileHandleReadCompletionNotification
      		 object: (id)fileHandle];

	[fileHandle readInBackgroundAndNotify];

  [nc addObserver: self 
      	 selector: @selector(endOfTask:) 
      			 name: NSTaskDidTerminateNotification
      		 object: (id)task];

	[task launch]; 
}

- (void)nextPage:(id)sender
{
	if (structured == YES) {
		pageindex++;
		if (pageindex == [[psdoc pages] count]) {
			pageindex--;
			return;
		}
		[self makePage];	
	}
}

- (void)previousPage:(id)sender
{
	if (structured == YES) {
		pageindex--;
		if (pageindex < 0) {
			pageindex = 0;
			return;
		} 
		[self makePage];	
	}
}

- (void)goToPage:(id)sender
{
	pageindex = [sender selectedColumn];
	[self makePage];
}

- (void)taskOut:(NSNotification *)notif
{
	NSFileHandle *fileHandle = [notif object];
  NSDictionary *userInfo = [notif userInfo];
  NSData *data = [userInfo objectForKey: NSFileHandleNotificationDataItem];

  if ([data length]) {
  	NSString *buff = [[NSString alloc] initWithData: data 
																					 encoding: NSUTF8StringEncoding];
		NSRange range = [buff rangeOfString: @">>showpage, press <return> to continue<<"];
		
		if (range.length != 0) {
			NSImage *image;
			
			if (structured == YES) {
				PSDocumentPage *pspage = [[psdoc pages] objectAtIndex: pageindex];
				NSString *tiffPath = [pspage tiffPath];
				image = [[NSImage alloc] initWithContentsOfFile: tiffPath];
			} else {
				image = [[NSImage alloc] initWithContentsOfFile: unstructTiffPath];
			}
			
			if (image != nil) {
				NSSize is = [image size];
				NSSize rs = imrect.size;

				if (valid == NO) {
					valid = YES;
					[errLabel removeFromSuperview];
					[self addSubview: imageView]; 
					[buttOk setEnabled: YES];	
				}
				
				if ((is.width <= rs.width) || (is.height <= rs.height)) {
					[imageView setImageScaling: NSScaleNone];
				} else {
					[imageView setImageScaling: NSScaleProportionally];
				}		
				
				[image setBackgroundColor: [NSColor windowBackgroundColor]];
				[imageView setImage: image];
				RELEASE (image);
			} else {
				if (valid == YES) {
					valid = NO;
					[imageView removeFromSuperview];
					[self addSubview: errLabel];
					[buttOk setEnabled: NO];	
				}
			}
									
  		if (task && [task isRunning]) {
    		[task terminate];
			}
			
			[self setBusy: NO];
  		RELEASE (buff);
			return;
		}
			
		if (valid == YES) {
			valid = NO;
			[imageView removeFromSuperview];
			[self addSubview: errLabel];
			[buttOk setEnabled: NO];	
		}
		[self setBusy: NO];
	}
	
  if (task && [task isRunning]) {
		[fileHandle readInBackgroundAndNotify];
  }
} 

- (void)taskErr:(NSNotification *)notif
{
	NSFileHandle *fileHandle = [notif object];
  NSDictionary *userInfo = [notif userInfo];
  NSData *data = [userInfo objectForKey: NSFileHandleNotificationDataItem];

  if ([data length]) {
		if (valid == YES) {
			valid = NO;
			[imageView removeFromSuperview];
			[self addSubview: errLabel];
			[buttOk setEnabled: NO];	
		}
		[self setBusy: NO];
	}
	
  if (task && [task isRunning]) {
		[fileHandle readInBackgroundAndNotify];
  }
}

- (void)endOfTask:(NSNotification *)notif
{
	if ([notif object] == task) {
		[nc removeObserver: self];
  	RELEASE (task);
	}
}

- (void)clearTempFiles
{
	int i;

	if (psdoc == nil) {
		return;
	}
	
	[imageView setImage: nil];

	if (structured == YES) {
		for (i = 0; i < [[psdoc pages] count]; i++) {
			PSDocumentPage *pspage = [[psdoc pages] objectAtIndex: i];	
			[self clearTempFilesOfPage: pspage];
		}
	} else {
		[fm removeFileAtPath: unstructPsPath handler: nil];
		[fm removeFileAtPath: unstructTiffPath handler: nil];
	}
}

- (void)clearTempFilesOfPage:(PSDocumentPage *)page
{
	[fm removeFileAtPath: [page psPath] handler: nil];
	[fm removeFileAtPath: [page tiffPath] handler: nil];
	[fm removeFileAtPath: [page dscPath] handler: nil];
}

- (void)editFile:(id)sender
{
	NSString *appName;
  NSString *type;

  [ws getInfoForFile: editPath application: &appName type: &type];

	if (appName != nil) {
		[ws openFile: editPath withApplication: appName];
	}
}

- (void)activateForPath:(NSString *)path
{
	NSArray *docPages;
	NSString *ext;
	NSBundle *bundle;
	NSString *imagePath;
	NSImage *miniPage;
	id cell;
	int i, count;

#define RETURNERR { \
NSString *msg = NSLocalizedString(@"Can't load ", @""); \
NSRunAlertPanel(@"error", \
[msg stringByAppendingString: myName], \
@"Continue", nil, nil); \
return; \
}

  if (task && [task isRunning]) {
		[nc removeObserver: self];
    [task terminate];
	} 
	DESTROY (task);
	
	[self clearTempFiles];
	
	DESTROY (unstructPsPath);
	DESTROY (unstructTiffPath);

	if (valid == NO) {
		valid = YES;
		[errLabel removeFromSuperview];
		[self addSubview: imageView]; 
	}

	ASSIGN (myPath, path);
	ASSIGN (editPath, path);
	ext = [myPath pathExtension];
	isPdf = (([ext isEqual: @"pdf"]) || ([ext isEqual: @"PDF"]));
	ASSIGN (myName, [myPath lastPathComponent]);		
	pageindex = 0;	
	resolution = 14;
	
	[self setBusy: NO];
	
	buttOk = [panel okButton];
	if (buttOk) {
  	[buttOk setTarget: self];		
		[buttOk setAction: @selector(editFile:)];	
		[buttOk setEnabled: YES];	
	}
	
	pageIdentifier = 0;		

	if (isPdf) {
		NSDictionary *pageIdent = [self uniquePageIdentifier];
		NSString *dscPath = [pageIdent objectForKey: @"dscpath"];
		NSMutableArray *args = [NSMutableArray arrayWithCapacity: 1];		

		[args addObject: @"-dNODISPLAY"];
		[args addObject: [NSString stringWithFormat: @"-sPDFname=%@", myPath]];
		[args addObject: [NSString stringWithFormat: @"-sDSCname=%@", dscPath]];
		[args addObject: @"pdf2dsc.ps"];

  	ASSIGN (task, [NSTask new]);
  	[task setLaunchPath: gsComm];
		[task setArguments: args];		
		[task launch];
    [task waitUntilExit];

    if ([task terminationStatus] == 0) {
			ASSIGN (myPath, dscPath);
			DESTROY (psdoc);
			psdoc = [[PSDocument alloc] initWithPsFileAtPath: myPath];
			if (psdoc == nil) {
				RETURNERR;
			}
    } else {
			RETURNERR;
		}		 			 

	} else {
		DESTROY (psdoc);
		psdoc = [[PSDocument alloc] initWithPsFileAtPath: myPath];
		if (psdoc == nil) {
			RETURNERR;
		}
	}

	docPages = [psdoc pages];
	count = [docPages count];
	structured = ((([psdoc epsf] == NO) && (count > 0)) 
															|| (([psdoc epsf] == YES) && (count > 1)));

	if (matrix) {
		[matrix removeFromSuperview];	
		[scroll setDocumentView: nil];		
		DESTROY (matrix);
	}
	
	if (structured == NO) {
		[self makeUnstructuredPageForPath: path];
	
	} else {
  	cell = AUTORELEASE ([NSButtonCell new]);
  	[cell setButtonType: NSPushOnPushOffButton];
  	[cell setImagePosition: NSImageOverlaps]; 

  	matrix = [[NSMatrix alloc] initWithFrame: NSZeroRect
				            				mode: NSRadioModeMatrix prototype: cell
			       												numberOfRows: 0 numberOfColumns: 0];
  	[matrix setIntercellSpacing: NSZeroSize];
  	[matrix setCellSize: NSMakeSize(26, 24)];
		[matrix setAllowsEmptySelection: YES];
		[matrix setTarget: self];
		[matrix setAction: @selector(goToPage:)];
		[scroll setDocumentView: matrix];	

		bundle = [NSBundle bundleForClass: [self class]];
		imagePath = [bundle pathForResource: @"page" ofType: @"tiff" inDirectory: nil];		
		miniPage = [[NSImage alloc] initWithContentsOfFile: imagePath];

		for (i = 0; i < count; i++) {
			NSDictionary *pageIdent = [self uniquePageIdentifier];
			NSString *psPath = [pageIdent objectForKey: @"pspath"];
			NSString *tiffPath = [pageIdent objectForKey: @"tiffpath"];
			NSString *dscPath = [pageIdent objectForKey: @"dscpath"];		
			PSDocumentPage *pspage = [docPages objectAtIndex: i];

			[pspage setPsPath: psPath];
			[pspage setTiffPath: tiffPath];
			[pspage setDscPath: dscPath];

			[matrix addColumn];

			cell = [matrix cellAtRow: 0 column: i];
			if (i < 100) {
				[cell setFont: [NSFont systemFontOfSize: 10]];
			} else {
				[cell setFont: [NSFont systemFontOfSize: 8]];
			}
			[cell setImage: miniPage];     
			[cell setTitle: [NSString stringWithFormat: @"%i", i+1]];     
		}
		[matrix sizeToCells];
		RELEASE (miniPage);	

		[self makePage];
	}
}

- (BOOL)displayData:(NSData *)data ofType:(NSString *)type
{
  return NO;
}

- (BOOL)stopTasks
{
  if (task && [task isRunning]) {
		[nc removeObserver: self];
    [task terminate];
	} 
	DESTROY (task);
	[self clearTempFiles];
  return YES;
}

- (void)deactivate
{
  if (task && [task isRunning]) {
		[nc removeObserver: self];
    [task terminate];
	} 
	TEST_RELEASE (task);
	[self clearTempFiles];
	[self removeFromSuperview];
}

- (BOOL)canDisplayFileAtPath:(NSString *)path
{
  NSDictionary *attributes;
	NSString *defApp, *fileType, *extension;
	NSArray *types;

  attributes = [[NSFileManager defaultManager] fileAttributesAtPath: path
                                                       traverseLink: YES];
  if ([attributes objectForKey: NSFileType] == NSFileTypeDirectory) {
    return NO;
  }		
		
	[ws getInfoForFile: path application: &defApp type: &fileType];

  if(([fileType isEqual: NSPlainFileType] == NO)
                  && ([fileType isEqual: NSShellCommandFileType] == NO)) {
    return NO;
  }
	
	extension = [path pathExtension];
	types = [NSArray arrayWithObjects: @"pdf", @"PDF", @"ps", @"PS", @"eps", @"EPS", nil];

	if ([types containsObject: extension]) {
		return YES;
	}

	return NO;
}

- (BOOL)canDisplayData:(NSData *)data ofType:(NSString *)type
{
  return NO;
}

- (int)index
{
	return index;
}

- (NSString *)winname
{
	return NSLocalizedString(@"Ps-Pdf Inspector", @"");	
}

- (void)drawRect:(NSRect)rect
{  
  [super drawRect: rect];		
  NSDrawGrayBezel(rect, [self bounds]);	
}

@end
