/* NSRTFViewer.m
 *  
 * Copyright (C) 2004-2010 Free Software Foundation, Inc.
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

#import <AppKit/AppKit.h>
#import "NSRTFViewer.h"

#define STR  0
#define RTF  1
#define RTFD 2

@implementation NSRTFViewer

- (void)dealloc
{
  RELEASE (typesDescriprion);
  RELEASE (typeIcons);
  RELEASE (scrollView);
  RELEASE (textView);
  RELEASE (errLabel);
  
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          inspector:(id)insp
{
  self = [super initWithFrame: frameRect];
  
  if(self) {
    NSRect r = [self bounds];

    r.origin.y += 10;
    r.size.height -= 10;
    
    scrollView = [[NSScrollView alloc] initWithFrame: r];
    [scrollView setBorderType: NSBezelBorder];
    [scrollView setHasHorizontalScroller: NO];
    [scrollView setHasVerticalScroller: YES]; 
    [scrollView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[scrollView contentView] setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[scrollView contentView] setAutoresizesSubviews:YES];
    [self addSubview: scrollView]; 

    r = [[scrollView contentView] bounds];
    textView = [[NSTextView alloc] initWithFrame: r];
    [textView setBackgroundColor: [NSColor whiteColor]];
    [textView setRichText: YES];
    [textView setEditable: NO];
    [textView setSelectable: NO];
    [textView setHorizontallyResizable: NO];
    [textView setVerticallyResizable: YES];
    [textView setMinSize: NSMakeSize (0, 0)];
    [textView setMaxSize: NSMakeSize (1E7, 1E7)];
    [textView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[textView textContainer] setContainerSize: NSMakeSize (r.size.width, 1e7)];
    [[textView textContainer] setWidthTracksTextView: YES];
    [textView setUsesRuler: NO];
    [scrollView setDocumentView: textView];

    r.origin.x = 2;
    r.origin.y = 170;
    r.size.width -= 4;
    r.size.height = 25;
    errLabel = [[NSTextField alloc] initWithFrame: r];	
    [errLabel setFont: [NSFont systemFontOfSize: 18]];
    [errLabel setAlignment: NSCenterTextAlignment];
    [errLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [errLabel setTextColor: [NSColor darkGrayColor]];	
    [errLabel setBezeled: NO];
    [errLabel setEditable: NO];
    [errLabel setSelectable: NO];
    [errLabel setStringValue: NSLocalizedString(@"Invalid Contents", @"")];

    inspector = insp;
    valid = YES;
    
    ASSIGN (typesDescriprion, ([NSArray arrayWithObjects:
                               NSLocalizedString(@"NSString data", @""),
                               NSLocalizedString(@"NSRTF data", @""),
                               NSLocalizedString(@"NSRTFD data", @""), nil]));
                                  
    ASSIGN (typeIcons, ([NSArray arrayWithObjects:
                              [NSImage imageNamed: @"stringPboard"],
                              [NSImage imageNamed: @"rtfPboard"],
                              [NSImage imageNamed: @"rtfPboard"], nil]));
  
    [self setContextHelp];
  }
	
	return self;
}

- (void)displayPath:(NSString *)path
{
}

- (void)displayData:(NSData *)data 
             ofType:(NSString *)type
{
  NSAttributedString *attrstr = nil;
  int index = 0;

  index = -1;
  if ([type isEqual: NSStringPboardType]) {
    NSString *str = [[NSString alloc] initWithData: data
                           encoding: [NSString defaultCStringEncoding]];
    if (str) {
      attrstr = [[NSAttributedString alloc] initWithString: str];
      RELEASE (str);
    }
    index = STR;
  } else if ([type isEqual: NSRTFPboardType]) {
    attrstr = [[NSAttributedString alloc] initWithRTF: data
						                       documentAttributes: NULL];
    index = RTF;
  } else if ([type isEqual: NSRTFDPboardType]) {
    attrstr = [[NSAttributedString alloc] initWithRTFD: data
						                        documentAttributes: NULL];
    index = RTFD;
  }

  if ([self superview]) {
    [inspector dataContentsReadyForType: [typesDescriprion objectAtIndex: index]
                                useIcon: [typeIcons objectAtIndex: index]];
  }
  
  if (attrstr) {
    if (valid == NO) {
      valid = YES;
      [errLabel removeFromSuperview];
      [self addSubview: scrollView]; 
    }
    
    [[textView textStorage] setAttributedString: attrstr];

    if ([type isEqual: NSStringPboardType]) {
		  [[textView textStorage] addAttribute: NSFontAttributeName 
                                     value: [NSFont systemFontOfSize: 8.0] 
                                     range: NSMakeRange(0, [attrstr length])];
    }
    
    RELEASE (attrstr);                                
  } else {
    if (valid == YES) {
      valid = NO;
      [scrollView removeFromSuperview];
			[self addSubview: errLabel];
    }
  }
}

- (NSString *)currentPath
{
  return nil;
}

- (void)stopTasks
{
}

- (BOOL)canDisplayPath:(NSString *)path
{
	return NO;
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return ([type isEqual: NSStringPboardType] ||
                    [type isEqual: NSRTFPboardType] ||
                            [type isEqual: NSRTFDPboardType]);
}

- (NSString *)winname
{
	return NSLocalizedString(@"Rtf Inspector", @"");	
}

- (NSString *)description
{
	return NSLocalizedString(@"This Inspector allow you view NSRTF pasteboard data", @"");	
}

- (void)setContextHelp
{
  NSFileManager *fm = [NSFileManager defaultManager];
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
