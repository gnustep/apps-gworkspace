/* PBViewer.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2003
 *
 * This file is part of the GNUstep ClipBook application
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "PBViewer.h"
#include "ClipBook.h"
#include <math.h>

#define BORDERW 2

static NSRect vrect = { { 0, 0 }, { 260, 300 } };

@implementation PBViewer

- (void)dealloc
{
  RELEASE (RTFViewer);
  RELEASE (TIFFViewer);
  RELEASE (ColorViewer);
  RELEASE (IBViewViewer);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if(self) {
    RTFViewer = [[NSRTFPboardViewer alloc] initWithFrame: vrect];
    TIFFViewer = [[NSTIFFPboardViewer alloc] initWithFrame: vrect];
    ColorViewer = [[NSColorboardViewer alloc] initWithFrame: vrect];
    IBViewViewer = [[IBViewPboardViewer alloc] initWithFrame: vrect];
  }
	
	return self;
}

- (id)viewerForData:(NSData *)data ofType:(NSString *)type
{
  id viewer = nil;

  if ([type isEqual: NSStringPboardType] ||
                [type isEqual: NSRTFPboardType] ||
                [type isEqual: NSRTFDPboardType]) {
    viewer = RTFViewer;
  } else if ([type isEqual: NSTIFFPboardType]) {
    viewer = TIFFViewer;
  } else if ([type isEqual: NSColorPboardType]) {
    viewer = ColorViewer;
  } else if ([type isEqual: @"IBViewPboardType"]) {
    viewer = IBViewViewer;
  }
  
  if (viewer && [viewer displayData: data ofType: type]) {
    return viewer;
  }
    
  return nil;
}

@end

@implementation NSRTFPboardViewer

- (void)dealloc
{
  RELEASE (scrollView);
  RELEASE (textView);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame: frame];
  
  if(self) {
    NSRect rect;
    
    [self setFrame: frame];
        
    scrollView = [[NSScrollView alloc] initWithFrame: vrect];
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
  }
	
	return self;
}

- (BOOL)displayData:(NSData *)data ofType:(NSString *)type
{
  NSAttributedString *attrstr = nil;
  NSFont *font = nil;  

  if ([type isEqual: NSRTFPboardType]) {    
    attrstr = [[NSAttributedString alloc] initWithRTF: data
						                       documentAttributes: NULL];
    AUTORELEASE (attrstr);
  } else if ([type isEqual: NSRTFDPboardType]) { 
    attrstr = [[NSAttributedString alloc] initWithRTFD: data
						                        documentAttributes: NULL];
    AUTORELEASE (attrstr);
  } else if ([type isEqual: NSStringPboardType]) { 
    NSString *str = [[NSString alloc] initWithData: data
                           encoding: [NSString defaultCStringEncoding]];
    
    if (str) {
      attrstr = [[NSAttributedString alloc] initWithString: str];
      RELEASE (str);
      AUTORELEASE (attrstr);
    }
  }

  if (attrstr) {
    [[textView textStorage] setAttributedString: attrstr];
    font = [NSFont systemFontOfSize: 8.0];
		[[textView textStorage] addAttribute: NSFontAttributeName 
                                   value: font 
                                   range: NSMakeRange(0, [attrstr length])];
    return YES;
  } 

  return NO;
}

@end


@implementation NSTIFFPboardViewer

- (void)dealloc
{
  TEST_RELEASE (imview);
  TEST_RELEASE (widthResult);
  TEST_RELEASE (heightResult);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame: frame];
  
  if(self) {
    NSView *view;
    NSTextField *widthLabel, *heightLabel;

    [self setFrame: frame];
    [self setBorderType: NSBezelBorder];
    [self setTitlePosition: NSNoTitle];
    [self setContentViewMargins: NSMakeSize(0, 0)]; 
    
    view = [[NSView alloc] initWithFrame: [[self contentView] frame]];
    
    imrect = NSMakeRect(0, 30, vrect.size.width, vrect.size.height - 30);
    imview = [[NSImageView alloc] initWithFrame: imrect];
    [imview setEditable: NO];
    [imview setImageFrameStyle: NSImageFrameNone];
    [imview setImageAlignment: NSImageAlignCenter];
    [view addSubview: imview]; 
    
    widthLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(5, 2, 40, 20)];	
    [widthLabel setAlignment: NSRightTextAlignment];
    [widthLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [widthLabel setBezeled: NO];
    [widthLabel setEditable: NO];
    [widthLabel setSelectable: NO];
    [widthLabel setStringValue: @"Width :"];
    [view addSubview: widthLabel]; 
    RELEASE (widthLabel);

    widthResult = [[NSTextField alloc] initWithFrame: NSMakeRect(45, 2, 40, 20)];	
    [widthResult setAlignment: NSRightTextAlignment];
    [widthResult setBackgroundColor: [NSColor windowBackgroundColor]];
    [widthResult setBezeled: NO];
    [widthResult setEditable: NO];
    [widthResult setSelectable: NO];
    [widthResult setStringValue: @""];
    [view addSubview: widthResult]; 

    heightLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(160, 2, 40, 20)];	
    [heightLabel setAlignment: NSRightTextAlignment];
    [heightLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [heightLabel setBezeled: NO];
    [heightLabel setEditable: NO];
    [heightLabel setSelectable: NO];
    [heightLabel setStringValue: @"Height :"];
    [view addSubview: heightLabel]; 
    RELEASE (heightLabel);

    heightResult = [[NSTextField alloc] initWithFrame: NSMakeRect(200, 2, 40, 20)];	
    [heightResult setAlignment: NSRightTextAlignment];
    [heightResult setBackgroundColor: [NSColor windowBackgroundColor]];
    [heightResult setBezeled: NO];
    [heightResult setEditable: NO];
    [heightResult setSelectable: NO];
    [heightResult setStringValue: @""];
    [view addSubview: heightResult];
    
    [self addSubview: view];
    RELEASE (view);
  }
	
	return self;
}

- (BOOL)displayData:(NSData *)data ofType:(NSString *)type
{
  NSImage *image = [[NSImage alloc] initWithData: data];

  if (image != nil) {
    NSSize is = [image size];
    NSSize rs = imrect.size;
    NSSize size;

    if ((is.width <= rs.width) && (is.height <= rs.height)) {
      [imview setImageScaling: NSScaleNone];
    } 
    else {
      [imview setImageScaling: NSScaleProportionally];
    }

    [imview setImage: image];
    size = [image size];
    [widthResult setStringValue: [[NSNumber numberWithInt: size.width] stringValue]];
    [heightResult setStringValue: [[NSNumber numberWithInt: size.height] stringValue]];

    RELEASE (image);
    return YES;    	
  }
  
  return NO;
}

@end


@implementation NSColorboardViewer

- (void)dealloc
{
  TEST_RELEASE (color);
  TEST_RELEASE (redField);
  TEST_RELEASE (greenField);
  TEST_RELEASE (blueField);
  TEST_RELEASE (alphaField);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame: frame];
  
  if(self) {
    NSView *view;
    NSRect r;
    
    [self setFrame: frame];
    
    color = nil;
    colorRect = [self bounds];
    colorRect.size.height -= 30 + BORDERW;
    colorRect.origin.y += 30;
    colorRect.origin.x += BORDERW;
    colorRect.size.width -= BORDERW * 2;
    
    r = [self frame];
    r.size.height = 20;

    view = [[NSView alloc] initWithFrame: r];
        
    redField = [[NSTextField alloc] initWithFrame: NSMakeRect(5, 2, 55, 20)];	
    [redField setBackgroundColor: [NSColor windowBackgroundColor]];
    [redField setBezeled: NO];
    [redField setEditable: NO];
    [redField setSelectable: NO];
    [redField setStringValue: @""];
    [view addSubview: redField]; 

    greenField = [[NSTextField alloc] initWithFrame: NSMakeRect(63, 2, 60, 20)];	
    [greenField setBackgroundColor: [NSColor windowBackgroundColor]];
    [greenField setBezeled: NO];
    [greenField setEditable: NO];
    [greenField setSelectable: NO];
    [greenField setStringValue: @""];
    [view addSubview: greenField]; 

    blueField = [[NSTextField alloc] initWithFrame: NSMakeRect(130, 2, 55, 20)];	
    [blueField setBackgroundColor: [NSColor windowBackgroundColor]];
    [blueField setBezeled: NO];
    [blueField setEditable: NO];
    [blueField setSelectable: NO];
    [blueField setStringValue: @""];
    [view addSubview: blueField]; 

    alphaField = [[NSTextField alloc] initWithFrame: NSMakeRect(195, 2, 60, 20)];	
    [alphaField setBackgroundColor: [NSColor windowBackgroundColor]];
    [alphaField setBezeled: NO];
    [alphaField setEditable: NO];
    [alphaField setSelectable: NO];
    [alphaField setStringValue: @""];
    [view addSubview: alphaField]; 
    
    [self addSubview: view];
    RELEASE (view);
  }
	
	return self;
}

- (BOOL)displayData:(NSData *)data ofType:(NSString *)type
{
  id c = [NSUnarchiver unarchiveObjectWithData: data];
    
  if (c && [c isKindOfClass: [NSColor class]]) {
    float red, green, blue, alpha;
    
    ASSIGN (color, [c colorUsingColorSpaceName: NSDeviceRGBColorSpace]);
    [color getRed: &red green: &green blue: &blue alpha: &alpha];
    
    [redField setStringValue: [NSString stringWithFormat: @"red: %.2f", red]];
    [greenField setStringValue: [NSString stringWithFormat: @"green: %.2f", green]];
    [blueField setStringValue: [NSString stringWithFormat: @"blue: %.2f", blue]];
    [alphaField setStringValue: [NSString stringWithFormat: @"alpha: %.2f", alpha]];
    
    [self setNeedsDisplay: YES];    

    return YES;    	
  } 
  
  return NO;
}

- (void)drawRect:(NSRect)rect
{
  NSRect borderRect = [self bounds];
  NSRect r = NSIntersectionRect(borderRect, rect);
  
  [[[self window] backgroundColor] set];
  NSRectFill(r);
  NSDrawGrayBezel(borderRect, rect);
  
  if (color) {
    [color set];
    NSRectFill(colorRect);
  }
}

@end


@implementation CustomView 

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];

  [self setBackgroundColor: [NSColor darkGrayColor]];
  [self setTextColor: [NSColor whiteColor]];
  [self setDrawsBackground: YES];
  [self setAlignment: NSCenterTextAlignment];
  [self setFont: [NSFont boldSystemFontOfSize: 12]];
  [self setEditable: NO];
  [self setClassName: @"CustomView"];
  
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

@implementation GormObjectsView

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
  return [[[self window] delegate] draggingEntered: sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  return [[[self window] delegate] draggingUpdated: sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
  return [[[self window] delegate] draggingExited: sender];
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
  return [[[self window] delegate] prepareForDragOperation: sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
  return [[[self window] delegate] performDragOperation: sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  return [[[self window] delegate] concludeDragOperation: sender];
}

@end

@implementation IBViewPboardViewer

- (void)dealloc
{
  RELEASE (scroll);
  
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame: frame];
  
  if(self) {
		scroll = [[NSScrollView alloc] initWithFrame: [self bounds]];
    [scroll setBorderType: NSBezelBorder];
		[scroll setHasHorizontalScroller: YES];
  	[scroll setHasVerticalScroller: YES]; 
		[scroll setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
  	[self addSubview: scroll]; 
  }
	
	return self;
}

- (BOOL)displayData:(NSData *)data ofType:(NSString *)type
{
  NSUnarchiver *u;
  NSArray	*objects;
  NSMutableArray *checkedObjects;
  id obj;
  NSPoint orp, szp;
  int i;

#define MARGIN 10

  orp = NSMakePoint(10000, 10000);
  szp = NSMakePoint(0, 0);
  
  u = [[NSUnarchiver alloc] initForReadingWithData: data];
  objects = [u decodeObject];
  RELEASE (u);

  checkedObjects = [NSMutableArray array];

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
    GormObjectsView *objsView;
    NSRect objsrect;
    
    objsrect = NSMakeRect(0, 0, szp.x - orp.x + MARGIN * 2, szp.y - orp.y + MARGIN * 2);
    objsView = [[GormObjectsView alloc] initWithFrame: objsrect];
    [objsView setAutoresizesSubviews: YES];
    
    for (i = 0; i < [checkedObjects count]; i++) {
      obj = [checkedObjects objectAtIndex: i];
      NSRect objr = [obj frame];
    
      objr.origin.x = objr.origin.x - orp.x + MARGIN;
      objr.origin.y = objr.origin.y - orp.y + MARGIN;
      [obj setFrame: objr];      
      [objsView addSubview: obj];
    }
    
    [scroll setDocumentView: objsView];

    RELEASE (objsView);
    
    return YES;
  }

  return NO;
}

@end
