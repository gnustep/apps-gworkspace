/* RtfViewer.m
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
#include "RtfViewer.h"
#include "GNUstep.h"

#define MAXDATA 1000

@implementation RtfViewer

- (void)dealloc
{
  RELEASE (extsarr);
  RELEASE (txtTypesExtsArr);
  RELEASE (scrollView);
  RELEASE (textView);
  RELEASE (label);
  TEST_RELEASE (editPath);	
  RELEASE (bundlePath);
  [super dealloc];
}

- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
  self = [super init];
  
  if(self) {
    NSString *suffs = @"rtf, RTF, rtfd, RTFD";
    NSString *txtSuffs = @"txt, TXT, text, TEXT, c, cc, C, cpp, m, h, java, class";
    NSRect rect;
    
    [self setFrame: frame];
    panel = (id<InspectorsProtocol>)apanel;
    ws = [NSWorkspace sharedWorkspace];
    index = idx;
    
    extsarr = [[NSArray alloc] initWithArray: [suffs componentsSeparatedByString:@", "]];
    txtTypesExtsArr = [[NSArray alloc] initWithArray: [txtSuffs componentsSeparatedByString:@", "]];
    
    rect = NSMakeRect(0, 10, 257, 215);
    scrollView = [[NSScrollView alloc] initWithFrame: rect];
    [scrollView setBorderType: NSBezelBorder];
    [scrollView setHasHorizontalScroller: NO];
    [scrollView setHasVerticalScroller: YES]; 
    [scrollView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[scrollView contentView] setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[scrollView contentView] setAutoresizesSubviews:YES];
    [self addSubview: scrollView]; 

    rect = [[scrollView contentView] frame];
    textView = [[NSTextView alloc] initWithFrame: rect];
    [textView setBackgroundColor: [NSColor whiteColor]];
    [textView setRichText: YES];
    [textView setEditable: NO];
    [textView setSelectable: NO];
    [textView setHorizontallyResizable: NO];
    [textView setVerticallyResizable: YES];
    [textView setMinSize: NSMakeSize (0, 0)];
    [textView setMaxSize: NSMakeSize (1E7, 1E7)];
    [textView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[textView textContainer] setContainerSize: NSMakeSize (rect.size.width, 1e7)];
    [[textView textContainer] setWidthTracksTextView: YES];
    [textView setUsesRuler: NO];
    [scrollView setDocumentView: textView];

    //label if error
    label = [[NSTextField alloc] initWithFrame: NSMakeRect(2, 133, 255, 25)];	
    [label setFont: [NSFont systemFontOfSize: 18]];
    [label setAlignment: NSCenterTextAlignment];
    [label setBackgroundColor: [NSColor windowBackgroundColor]];
    [label setTextColor: [NSColor grayColor]];	
    [label setBezeled: NO];
    [label setEditable: NO];
    [label setSelectable: NO];
    [label setStringValue: @"Invalid Contents"];
    
    valid = YES;
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

- (void)activateForPath:(NSString *)path
{
  NSString *ext = [path pathExtension];
  NSData *data = nil;
  NSString *s = nil;
  NSAttributedString *attrstr = nil;
  NSFont *font = nil;  
  
  buttOk = [panel okButton];
  if (buttOk) {
    [buttOk setTarget: self];		
    [buttOk setAction: @selector(editFile:)];	
  }

  if ([txtTypesExtsArr containsObject: ext]) {
    NSDictionary *dict = [[NSFileManager defaultManager] 
                              fileAttributesAtPath: path traverseLink: YES];
    int nbytes = nbytes = [[dict objectForKey: NSFileSize] intValue];
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath: path];
    int maxbytes = 0;
    
    data = [NSMutableData new];
  
    do {
      maxbytes += MAXDATA;

      [(NSMutableData *)data appendData: 
          [handle readDataOfLength: ((nbytes >= MAXDATA) ? MAXDATA : nbytes)]];

      s = [[NSString alloc] initWithData: data
                                encoding: [NSString defaultCStringEncoding]];
     } while ((s == nil) && (maxbytes < nbytes));
     
    [handle closeFile];
    RELEASE(data);

    attrstr = [[NSAttributedString alloc] initWithString: s];
    RELEASE (s);
    AUTORELEASE (attrstr);

    font = [NSFont systemFontOfSize: 8.0];

  } else if ([ext isEqual: @"rtf"] || [ext isEqual: @"RTF"]) {
    data = [NSData dataWithContentsOfFile: path];

    if (data) {    
      attrstr = [[NSAttributedString alloc] initWithRTF: data
						                         documentAttributes: NULL];
      AUTORELEASE (attrstr);
    }

  } else if ([ext isEqual: @"rtfd"] || [ext isEqual: @"RTFD"]) {
    data = [NSData dataWithContentsOfFile: path];

    if (data) {
      attrstr = [[NSAttributedString alloc] initWithRTFD: data
						                          documentAttributes: NULL];
      AUTORELEASE (attrstr);
    }
  }
  
  if (attrstr != nil) {
    ASSIGN (editPath, path);
  
    if (valid == NO) {
      valid = YES;
      [label removeFromSuperview];
      [self addSubview: scrollView]; 
    }
  
    [[textView textStorage] setAttributedString: attrstr];
    
    if (font) {
		  [[textView textStorage] addAttribute: NSFontAttributeName 
                                     value: font 
                                     range: NSMakeRange(0, [attrstr length])];
    }
    
    [buttOk setEnabled: YES];			

  } else {
    if (valid == YES) {
      valid = NO;
      [scrollView removeFromSuperview];
			[self addSubview: label];
			[buttOk setEnabled: NO];			
    }
  }
}

- (BOOL)displayData:(NSData *)data ofType:(NSString *)type
{
  return NO;
}

- (BOOL)stopTasks
{
  return YES;
}

- (void)deactivate
{
  [self removeFromSuperview];
}

- (BOOL)canDisplayFileAtPath:(NSString *)path
{
  NSDictionary *attributes;
	NSString *defApp, *fileType, *extension;

  attributes = [[NSFileManager defaultManager] fileAttributesAtPath: path
                                                       traverseLink: YES];
  if ([attributes objectForKey: NSFileType] == NSFileTypeDirectory) {
    return NO;
  }		

	[ws getInfoForFile: path application: &defApp type: &fileType];
	extension = [path pathExtension];
	
  if(([fileType isEqual: NSPlainFileType] == NO)
                  && ([fileType isEqual: NSShellCommandFileType] == NO)) {
    return NO;
  }

  if ([extsarr containsObject: extension]
          || [txtTypesExtsArr containsObject: extension]) {
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
	return NSLocalizedString(@"Rtf-Txt Inspector", @"");	
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

@end
