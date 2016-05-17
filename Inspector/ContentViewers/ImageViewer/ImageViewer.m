/* ImageViewer.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
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
#import "ImageViewer.h"
#include <math.h>

@interface Resizer : NSObject
{
  id viewer;
  NSNotificationCenter *nc; 
}

- (void)readImageAtPath:(NSString *)path
                setSize:(NSSize)imsize;

@end

@implementation ImageViewer

- (void)dealloc
{
  [nc removeObserver: self];  

  if (resizerConn != nil)
    {
      DESTROY (resizer);    
      DESTROY (resizerConn);
    }

  RELEASE (imagePath);	
  RELEASE (image);	
  RELEASE (nextPath);	
  RELEASE (editPath);	
  RELEASE (extsarr);
  RELEASE (imview);
  RELEASE (errLabel);
  RELEASE (progView);
  DESTROY (conn);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          inspector:(id)insp
{
  self = [super initWithFrame: frameRect];
  
  if(self) {
    NSRect r = [self bounds];
    
    r.origin.y += 60;
    r.size.height -= 60;
    
    imview = [[NSImageView alloc] initWithFrame: r];
    [imview setEditable: NO];
    [imview setImageFrameStyle: NSImageFrameGrayBezel];
    [imview setImageAlignment: NSImageAlignCenter];
    [imview setImageScaling: NSScaleNone];
    [self addSubview: imview]; 
    
    r.origin.x = 10;
    r.origin.y -= 20;
    r.size.width = 90;
    r.size.height = 20;
    widthLabel = [[NSTextField alloc] initWithFrame: r];	
    [widthLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [widthLabel setBezeled: NO];
    [widthLabel setEditable: NO];
    [widthLabel setSelectable: NO];
    [widthLabel setStringValue: @""];
    [self addSubview: widthLabel]; 
    RELEASE (widthLabel);

    r.origin.x = 160;
    heightLabel = [[NSTextField alloc] initWithFrame: r];	
    [heightLabel setBackgroundColor: [NSColor windowBackgroundColor]];
    [heightLabel setBezeled: NO];
    [heightLabel setEditable: NO];
    [heightLabel setSelectable: NO];
    [heightLabel setAlignment: NSRightTextAlignment];
    [heightLabel setStringValue: @""];
    [self addSubview: heightLabel]; 
    RELEASE (heightLabel);

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

    r.origin.x = 6;
    r.origin.y = 16;
    r.size.width = 16;
    r.size.height = 16;
    progView = [[ProgressView alloc] initWithFrame: r refreshInterval: 0.05];

    r.origin.x = 141;
    r.origin.y = 10;
    r.size.width = 115;
    r.size.height = 25;
	  editButt = [[NSButton alloc] initWithFrame: r];
	  [editButt setButtonType: NSMomentaryLight];
    [editButt setImage: [NSImage imageNamed: @"common_ret.tiff"]];
    [editButt setImagePosition: NSImageRight];
	  [editButt setTitle: NSLocalizedString(@"Edit", @"")];
	  [editButt setTarget: self];
	  [editButt setAction: @selector(editFile:)];	
    [editButt setEnabled: NO];		
		[self addSubview: editButt]; 
    RELEASE (editButt);

    ASSIGN (extsarr, ([NSArray arrayWithObjects: @"tiff", @"tif", @"png", 
                                            @"jpeg", @"jpg", @"gif", nil]));

    inspector = insp;
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    ws = [NSWorkspace sharedWorkspace];
        
    valid = YES;
    
    resizer = nil;
    waitingResizer = NO;
    imagePath = nil;
    nextPath = nil;
    editPath = nil;
    image = nil;
    
    [self setContextHelp];
  }
	
	return self;
}

- (void)displayPath:(NSString *)path
{
  DESTROY (editPath);
  [editButt setEnabled: NO];		
  
  if (imagePath) {
    ASSIGN (nextPath, path);
    return;
  }
  
  ASSIGN (imagePath, path);
  
  if ((resizer == nil) && (waitingResizer == NO)) {

    waitingResizer = YES;
    resizer = [[Resizer alloc] init];

  } else {
    NSSize imsize = [imview bounds].size;
    
    imsize.width -= 4;
    imsize.height -= 4;
    [self addSubview: progView]; 
    [progView start];
    [resizer readImageAtPath: imagePath setSize: imsize];
  }
}

- (void)displayLastPath:(BOOL)forced
{
  if (editPath) {
    if (forced) {
      [self displayPath: editPath];
    } else {
      [imview setImage: image];
      [inspector contentsReadyAt: editPath];
    }
  }
}


- (void)setResizer:(id)anObject
{
  if (resizer == nil) {
    NSSize imsize = [imview bounds].size;
    
    imsize.width -= 4;
    imsize.height -= 4;
    resizer = [[Resizer alloc] init];
    waitingResizer = NO;
    [self addSubview: progView]; 
    [progView start];    
    [resizer readImageAtPath: imagePath setSize: imsize];
  }
}



- (void)imageReady:(NSDictionary *)imginfo
{
  NSData *imgdata = [imginfo objectForKey: @"imgdata"];
  BOOL imgok = YES;
  NSString *lastPath;
  NSLog(@"ImageViewer - imageReady");
  if ([self superview]) {      
    [inspector contentsReadyAt: imagePath];
  }
        
  if (imgdata) {
    DESTROY (image);
    image = [[NSImage alloc] initWithData: imgdata];
    
    if (image) {
      float width = [[imginfo objectForKey: @"width"] floatValue];
      float height = [[imginfo objectForKey: @"height"] floatValue];
      NSString *str;

      if (valid == NO) {
        valid = YES;
        [errLabel removeFromSuperview];
        [self addSubview: imview]; 
      }

      [imview setImage: image];

      str = NSLocalizedString(@"Width:", @"");
      str = [NSString stringWithFormat: @"%@ %.0f", str, width];
      [widthLabel setStringValue: str];

      str = NSLocalizedString(@"Height:", @"");
      str = [NSString stringWithFormat: @"%@ %.0f", str, height];
      [heightLabel setStringValue: str];

      ASSIGN (editPath, imagePath);
      [editButt setEnabled: YES];		
      [[self window] makeFirstResponder: editButt];
      
    } else {
      imgok = NO;
    }
    
  } else {
    imgok = NO;
  }
  
  if (imgok == NO) {
    if (valid == YES) {
      valid = NO;
      [imview removeFromSuperview];
			[self addSubview: errLabel];
      [widthLabel setStringValue: @""];
      [heightLabel setStringValue: @""];
			[editButt setEnabled: NO];		
    }
  }
  
  [progView stop];
  [progView removeFromSuperview];  
  
  lastPath = [NSString stringWithString: imagePath];
  DESTROY (imagePath);

  if (nextPath && ([nextPath isEqual: lastPath] == NO)) {
    NSString *next = [NSString stringWithString: nextPath];
    DESTROY (nextPath);    
    [self displayPath: next];
  }
}

- (void)displayData:(NSData *)data 
             ofType:(NSString *)type
{
}

- (NSString *)currentPath
{
  return editPath;
}

- (void)stopTasks
{
  [imview setImage: nil];
}

- (BOOL)canDisplayPath:(NSString *)path
{
  NSDictionary *attributes;
	NSString *defApp, *fileType, *extension;

  attributes = [fm fileAttributesAtPath: path traverseLink: YES];
  if ([attributes objectForKey: NSFileType] == NSFileTypeDirectory) {
    return NO;
  }		
		
	[ws getInfoForFile: path application: &defApp type: &fileType];
	extension = [path pathExtension];
	
  if (([fileType isEqual: NSPlainFileType] == NO)
                  && ([fileType isEqual: NSShellCommandFileType] == NO)) {
		return NO;
	}

  if ([extsarr containsObject: [extension lowercaseString]]) {
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
	return NSLocalizedString(@"Image Inspector", @"");	
}

- (NSString *)description
{
	return NSLocalizedString(@"This Inspector allow you view the content of an Image file", @"");	
}

- (void)editFile:(id)sender
{
	NSString *appName;
  NSString *type;

  [ws getInfoForFile: editPath application: &appName type: &type];

	if (appName) {
    NS_DURING
      {
    [ws openFile: editPath withApplication: appName];
      }
    NS_HANDLER
      {
    NSRunAlertPanel(NSLocalizedString(@"error", @""), 
        [NSString stringWithFormat: @"%@ %@!", 
          NSLocalizedString(@"Can't open ", @""), [editPath lastPathComponent]],
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

@implementation ProgressView

#define IMAGES 8

- (void)dealloc
{
  RELEASE (images);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(NSTimeInterval)refresh
{
  self = [super initWithFrame: frameRect];

  if (self) {
    NSUInteger i;
  
    images = [NSMutableArray new];
  
    for (i = 0; i < IMAGES; i++) {
      NSString *imname = [NSString stringWithFormat: @"anim-logo-%lu.tiff", (unsigned long)i];
      [images addObject: [NSImage imageNamed: imname]];    
    }
  
    rfsh = refresh;
    animating = NO;
  }

  return self;
}

- (void)start
{
  index = 0;
  animating = YES;
  progTimer = [NSTimer scheduledTimerWithTimeInterval: rfsh 
                                               target: self selector: @selector(animate:) 
                                             userInfo: nil repeats: YES];
}

- (void)stop
{
  if (animating) {
    animating = NO;
    if (progTimer && [progTimer isValid]) {
      [progTimer invalidate];
    }
    [self setNeedsDisplay: YES];
  }
}

- (void)animate:(id)sender
{
  [self setNeedsDisplay: YES];
  index++;
  if (index == [images count]) {
    index = 0;
  }
}

- (BOOL)animating
{
  return animating;
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  
  if (animating) {
    [[images objectAtIndex: index] compositeToPoint: NSMakePoint(0, 0) 
                                          operation: NSCompositeSourceOver];
  }
}

@end
