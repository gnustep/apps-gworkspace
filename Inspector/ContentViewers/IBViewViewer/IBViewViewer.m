/* IBViewViewer.m
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>
#include "IBViewViewer.h"

@implementation CustomView 

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];

  if (self) {
    [self setBackgroundColor: [NSColor darkGrayColor]];
    [self setTextColor: [NSColor whiteColor]];
    [self setDrawsBackground: YES];
    [self setAlignment: NSCenterTextAlignment];
    [self setFont: [NSFont boldSystemFontOfSize: 12]];
    [self setEditable: NO];
    [self setClassName: @"CustomView"];
  }
  
  return self;
}

- (void)setClassName:(NSString *)aName
{
  [self setStringValue: aName];
}

- (NSString *)className
{
  return [self stringValue];
}

@end

@implementation GormNSBrowser
@end

@implementation GormNSTableView
@end

@implementation GormNSOutlineView
@end

@implementation GormNSMenu
@end

@implementation GormNSPopUpButtonCell 
@end

@implementation GormNSPopUpButton
@end


@implementation IBViewViewer

- (void)dealloc
{
  RELEASE (typeDescriprion);
  RELEASE (icon);
  RELEASE (scrollView);
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
    [scrollView setHasHorizontalScroller: YES];
    [scrollView setHasVerticalScroller: YES]; 
    [scrollView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [[scrollView contentView] setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
    [self addSubview: scrollView]; 

    r.origin.x = 2;
    r.origin.y = 170;
    r.size.width = [self bounds].size.width - 4;
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
    
    ASSIGN (typeDescriprion, NSLocalizedString(@"IBView data", @""));
    ASSIGN (icon, [NSImage imageNamed: @"gormPboard"]);
    
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
  NSArray	*objects = [NSUnarchiver unarchiveObjectWithData: data];

#define MARGIN 10

  if ([self superview]) { 
    [inspector dataContentsReadyForType: typeDescriprion useIcon: icon];
  }
  
  if (objects) {
    NSMutableArray *checkedObjects = [NSMutableArray array];
    NSPoint orp = NSMakePoint(10000, 10000);
    NSPoint szp = NSMakePoint(0, 0);
    id obj;
    int i;
    
    if (valid == NO) {
      valid = YES;
      [errLabel removeFromSuperview];
      [self addSubview: scrollView]; 
    }
    
    for (i = 0; i < [objects count]; i++) {
      obj = [objects objectAtIndex: i];

      if ([obj respondsToSelector: @selector(frame)]) {
        NSRect objr = [obj frame];

        orp.x = (objr.origin.x < orp.x) ? objr.origin.x : orp.x;
        orp.y = (objr.origin.y < orp.y) ? objr.origin.y : orp.y;
        szp.x = ((objr.origin.x + objr.size.width) > szp.x) ? 
                            (objr.origin.x + objr.size.width) : szp.x;
        szp.y = ((objr.origin.y + objr.size.height) > szp.y) ? 
                            (objr.origin.y + objr.size.height) : szp.y;

        [checkedObjects addObject: obj];
      }
    }
  
    if ([checkedObjects count]) {
      NSView *objsView;
      NSRect objsrect;

      objsrect = NSMakeRect(0, 0, szp.x - orp.x + MARGIN * 2, szp.y - orp.y + MARGIN * 2);
      objsView = [[NSView alloc] initWithFrame: objsrect];
      [objsView setAutoresizesSubviews: YES];

      for (i = 0; i < [checkedObjects count]; i++) {
        NSRect objr;

        obj = [checkedObjects objectAtIndex: i];
        objr = [obj frame];

        objr.origin.x = objr.origin.x - orp.x + MARGIN;
        objr.origin.y = objr.origin.y - orp.y + MARGIN;
        [obj setFrame: objr];
        [objsView addSubview: obj];
      }

      [scrollView setDocumentView: objsView];
      RELEASE (objsView);
    }
  
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
  return ([type isEqual: @"IBViewPboardType"]);
}

- (NSString *)winname
{
	return NSLocalizedString(@"IBView Inspector", @"");	
}

- (NSString *)description
{
	return NSLocalizedString(@"This Inspector allow you view IBView pasteboard data", @"");	
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
