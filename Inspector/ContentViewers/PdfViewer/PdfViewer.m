/* PdfViewer.m
 *  
 * Copyright (C) 2004-2012 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <math.h>

#import <AppKit/AppKit.h>
#import <PDFKit/PDFDocument.h>
#import <PDFKit/PDFImageRep.h>
#import "PdfViewer.h"

#define MAXPAGES 9999

const double PDFResolution = 72.0;

@implementation PdfViewer

- (void)dealloc
{
  TEST_RELEASE (pdfPath);	
  TEST_RELEASE (pdfDoc);
  TEST_RELEASE (imageRep);
  RELEASE (backButt);
  RELEASE (nextButt);
  RELEASE (scroll);
  RELEASE (matrix);
  RELEASE (imageView);
  RELEASE (errLabel);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          inspector:(id)insp
{
  self = [super initWithFrame: frameRect];
  
  if(self)
    {
      NSRect r = [self bounds];
      NSRect vr;
      id cell;

#define MARGIN 3
		
      vr = NSMakeRect(0, r.size.height - 25 - MARGIN, 25, 25);
      nextButt = [[NSButton alloc] initWithFrame: vr];
      [nextButt setButtonType: NSMomentaryLight];
      [nextButt setImagePosition: NSImageOnly];	
      [nextButt setImage: [NSImage imageNamed: @"common_ArrowUp.tiff"]];
      [nextButt setTarget: self];
      [nextButt setAction: @selector(nextPage:)];
      [self addSubview: nextButt]; 

      vr.origin.y -= 25;
      backButt = [[NSButton alloc] initWithFrame: vr];
      [backButt setButtonType: NSMomentaryLight];
      [backButt setImagePosition: NSImageOnly];	
      [backButt setImage: [NSImage imageNamed: @"common_ArrowDown.tiff"]];
      [backButt setTarget: self];
      [backButt setAction: @selector(previousPage:)];
      [self addSubview: backButt]; 

      vr.origin.x = 25 + MARGIN;
      vr.size.width = r.size.width - vr.origin.x;
      vr.size.height = 50;
      scroll = [[NSScrollView alloc] initWithFrame: vr];
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
    [matrix setCellSize: NSMakeSize(26, [[scroll contentView] bounds].size.height)];
		[matrix setAllowsEmptySelection: YES];
		[matrix setTarget: self];
		[matrix setAction: @selector(goToPage:)];
		[scroll setDocumentView: matrix];	

    vr.size.height = vr.origin.y - 42 - MARGIN;
    vr.origin.x = 0;
    vr.origin.y = 42;
    vr.size.width = r.size.width;
		imageView = [[NSImageView alloc] initWithFrame: vr];
    [imageView setImageFrameStyle: NSImageFrameGrayBezel];
 //   [imageView setImageScaling: NSScaleNone];
		[imageView setImageAlignment: NSImageAlignCenter];
		[imageView setEditable: NO];
  	[self addSubview: imageView]; 

    vr.origin.x = 2;
    vr.origin.y = 170;
    vr.size.width = r.size.width - 4;
    vr.size.height = 25;
		errLabel = [[NSTextField alloc] initWithFrame: vr];	
		[errLabel setFont: [NSFont systemFontOfSize: 18]];
		[errLabel setAlignment: NSCenterTextAlignment];
		[errLabel setBackgroundColor: [NSColor windowBackgroundColor]];
		[errLabel setTextColor: [NSColor grayColor]];	
		[errLabel setBezeled: NO];
		[errLabel setEditable: NO];
		[errLabel setSelectable: NO];
		[errLabel setStringValue: NSLocalizedString(@"Invalid Contents", @"")];

    vr.origin.x = 141;
    vr.origin.y = 10;
    vr.size.width = 115;
    vr.size.height = 25;
	  editButt = [[NSButton alloc] initWithFrame: vr];
	  [editButt setButtonType: NSMomentaryLight];
    [editButt setImage: [NSImage imageNamed: @"common_ret.tiff"]];
    [editButt setImagePosition: NSImageRight];
	  [editButt setTitle: NSLocalizedString(@"Edit", @"")];
	  [editButt setTarget: self];
	  [editButt setAction: @selector(editFile:)];	
    [editButt setEnabled: NO];		
		[self addSubview: editButt]; 
    RELEASE (editButt);

    inspector = insp;    
		fm = [NSFileManager defaultManager];		
		ws = [NSWorkspace sharedWorkspace];

		valid = YES;
		
    pdfPath = nil;
    
    [self setContextHelp];
	}
	
	return self;
}

- (void)displayPath:(NSString *)path
{
  PDFDocument *doc;
  
  ASSIGN (pdfPath, path);

  if ([self superview]) {      
    [inspector contentsReadyAt: pdfPath];
  }
  
  [editButt setEnabled: NO];	
  
  doc = [PDFDocument documentFromFile: pdfPath];

  if ([doc isOk] && ([doc errorCode] == 0)) {
    int npages;
    NSSize imageSize;
	  NSBundle *bundle;
	  NSString *imagePath;
	  NSImage *miniPage;
    id cell;
    int i;

    if (valid == NO) {
      valid = YES;
      [errLabel removeFromSuperview];
      [self addSubview: backButt]; 
      [self addSubview: nextButt]; 
      [self addSubview: scroll]; 
      [self addSubview: imageView]; 
    }
    
    [imageView setImage: nil];
    
    [editButt setEnabled: YES];		
    [[self window] makeFirstResponder: editButt];
    
	  if (matrix) {
		  [matrix removeFromSuperview];	
		  [scroll setDocumentView: nil];		
		  DESTROY (matrix);
	  }
    
  	cell = AUTORELEASE ([NSButtonCell new]);
  	[cell setButtonType: NSPushOnPushOffButton];
  	[cell setImagePosition: NSImageOverlaps]; 

  	matrix = [[NSMatrix alloc] initWithFrame: NSZeroRect
				            				mode: NSRadioModeMatrix prototype: cell
			       												numberOfRows: 0 numberOfColumns: 0];
  	[matrix setIntercellSpacing: NSZeroSize];
  	[matrix setCellSize: NSMakeSize(26, [[scroll contentView] bounds].size.height)];
		[matrix setAllowsEmptySelection: YES];
		[matrix setTarget: self];
		[matrix setAction: @selector(goToPage:)];
		[scroll setDocumentView: matrix];	

		bundle = [NSBundle bundleForClass: [self class]];
		imagePath = [bundle pathForResource: @"page" ofType: @"tiff" inDirectory: nil];		
		miniPage = [[NSImage alloc] initWithContentsOfFile: imagePath];
    
    npages = [doc countPages];
    
		for (i = 0; i < npages; i++) {
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

    DESTROY (imageRep);
    ASSIGN (pdfDoc, doc);

    imageSize = NSMakeSize([pdfDoc pageWidth: 1],
                                    [pdfDoc pageHeight: 1]);
    imageRep = [[PDFImageRep alloc] initWithDocument: pdfDoc];
    [imageRep setSize: imageSize];

  } else {
    if (valid) {
      valid = NO;
      [backButt removeFromSuperview];
      [nextButt removeFromSuperview];
      [scroll removeFromSuperview];
      [imageView removeFromSuperview];
			[self addSubview: errLabel];      
			[editButt setEnabled: NO];		
    }
  }
  
  if (valid) {
    [matrix selectCellAtRow: 0 column: 0];
    [matrix sendAction];
  }
}

- (void)goToPage:(id)sender
{
  NSImage *image = nil;
  int index;
  NSSize imsize;
  NSSize unscaledSize;
                                              

  index = [matrix selectedColumn] + 1;
  if (index <= 0)
    return;

  imsize = [imageView bounds].size;
  unscaledSize = NSMakeSize([pdfDoc pageWidth: index], [pdfDoc pageHeight: index]);

  if ((imsize.width < unscaledSize.width) || (imsize.height < unscaledSize.height))
    {
      float rw, rh;
      NSSize scaledSize;
      float xfactor, yfactor;  

      rw = imsize.width / unscaledSize.width;
      rh = imsize.height / unscaledSize.height;

      if (rw <= rh)
	{
	  scaledSize.width = unscaledSize.width * rw;
	  scaledSize.height = floor(imsize.width * unscaledSize.height / unscaledSize.width + 0.5);
	}
      else
	{
	  scaledSize.height = unscaledSize.height * rh;
	  scaledSize.width  = floor(imsize.height * unscaledSize.width / unscaledSize.height + 0.5);    
	}

      xfactor = scaledSize.width / unscaledSize.width * PDFResolution;
      yfactor = scaledSize.height / unscaledSize.height * PDFResolution;

      [imageRep setResolution: (xfactor < yfactor ? xfactor : yfactor)];
    }

  [imageRep setPageNum: index];
  
  image = [[NSImage alloc] initWithSize: [imageRep size]];
  [image setBackgroundColor: [NSColor whiteColor]];
  [image setScalesWhenResized: YES];
  [image addRepresentation: imageRep];
  [imageView setImage: image];
  RELEASE (image);
}

- (void)displayData:(NSData *)data 
             ofType:(NSString *)type
{
}

- (NSString *)currentPath
{
  return pdfPath;
}

- (void)stopTasks
{

}

- (BOOL)canDisplayPath:(NSString *)path
{
  NSDictionary *attributes;
	NSString *defApp, *fileType;

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
	
	if ([[[path pathExtension] lowercaseString] isEqual: @"pdf"]) {
		return YES;
	}

	return NO;
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return NO;
}

- (NSString *)winname
{
	return NSLocalizedString(@"Pdf Inspector", @"");	
}

- (NSString *)description
{
	return NSLocalizedString(@"This Inspector allow you View the content of a PDF file", @"");	
}

- (void)nextPage:(id)sender
{
  int index;


  index = [matrix selectedColumn] + 1;
  if (index <= 0)
    return;

  if (index < [pdfDoc countPages])
    index++;
  else
    index = [pdfDoc countPages];

  [matrix selectCellAtRow:0 column:index-1];
  [matrix sendAction];
}

- (void)previousPage:(id)sender
{
  int index;

  index = [matrix selectedColumn] + 1;
  if (index <= 0)
    return;

  if (index > 1)
    index--;
  else
    index = 1;

  [matrix selectCellAtRow:0 column:index-1];
  [matrix sendAction];
}



- (void)editFile:(id)sender
{
	NSString *appName;
  NSString *type;

  [ws getInfoForFile: pdfPath application: &appName type: &type];

	if (appName) {
    NS_DURING
      {
    [ws openFile: pdfPath withApplication: appName];
      }
    NS_HANDLER
      {
    NSRunAlertPanel(NSLocalizedString(@"error", @""), 
        [NSString stringWithFormat: @"%@ %@!", 
          NSLocalizedString(@"Can't open ", @""), [pdfPath lastPathComponent]],
                                      NSLocalizedString(@"OK", @""), 
                                      nil, 
                                      nil);                                     
      }
    NS_ENDHANDLER  
	}
}

- (void)setContextHelp
{
  NSString *bpath = [[NSBundle bundleForClass: [self class]] bundlePath];
  NSString *resPath = [bpath stringByAppendingPathComponent: @"Resources"];
  NSArray *languages = [NSUserDefaults userLanguages];
  unsigned i;
     
  for (i = 0; i < [languages count]; i++) {
    NSString *language = [languages objectAtIndex: i];
    NSString *langDir = [NSString stringWithFormat: @"%@.lproj", language];  
    NSString *helpPath = [langDir stringByAppendingPathComponent: @"Help.rtfd"];
  
    helpPath = [resPath stringByAppendingPathComponent: helpPath];
  
    if ([fm fileExistsAtPath: helpPath]) {
      NSAttributedString *help = [[NSAttributedString alloc] initWithPath: helpPath
                                                       documentAttributes: NULL];
      if (help) {
        [[NSHelpManager sharedHelpManager] setContextHelp: help forObject: self];
        RELEASE (help);
      }
    }
  }
}

@end

