/* ImageViewer.m
 *  
 * Copyright (C) 2004-2026 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale
 *         Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */

#import <AppKit/AppKit.h>
#import "ImageViewer.h"
#include <math.h>

#import "Resizer.h"

@implementation ImageViewer

- (void)dealloc
{
  DESTROY (resizer);
  RELEASE (_pathToDisplay);
  RELEASE (image);
  RELEASE (editPath);
  RELEASE (imageView);
  RELEASE (errLabel);
  RELEASE (progView);
  DESTROY (conn);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          inspector:(id)insp
{
  self = [super initWithFrame: frameRect];
  
  if(self)
    {
      NSRect r = [self bounds];

      r.origin.y += 60;
      r.size.height -= 60;

      imageView = [[NSImageView alloc] initWithFrame: r];
      [imageView setEditable: NO];
      [imageView setImageFrameStyle: NSImageFrameGrayBezel];
      [imageView setImageAlignment: NSImageAlignCenter];
      [imageView setImageScaling: NSScaleNone];
      [self addSubview: imageView];

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

      inspector = insp;
      ws = [NSWorkspace sharedWorkspace];

      valid = YES;
      resizer = nil;
      _pathToDisplay = nil;
      editPath = nil;
      image = nil;

      [self setContextHelp];
    }
	
  return self;
}

- (void)_readImage
{
  NSSize imsize = [imageView bounds].size;

  imsize.width -= 4;
  imsize.height -= 4;
  [self addSubview: progView];
  [progView start];
  [resizer readImageAtPath: _pathToDisplay setSize: imsize];
}

- (void)displayPath:(NSString *)path
{
  DESTROY (editPath);
  [editButt setEnabled: NO];		
  [widthLabel setStringValue: @""];
  [heightLabel setStringValue: @""];

  ASSIGN (_pathToDisplay, path);
  if (conn == nil)
    {
      NSPort *p1;
      NSPort *p2;  

      p1 = [NSPort port];
      p2 = [NSPort port];

      conn = [[NSConnection alloc] initWithReceivePort: p1 
                                              sendPort: p2];
      [conn setRootObject:self];

      [NSThread detachNewThreadSelector: @selector(connectWithPorts:)
                               toTarget: [ImageResizer class]
                             withObject: [NSArray arrayWithObjects: p2, p1, nil]];
      // Resizer will call setResizer when ready
    }
  else // connection existing
    {
      if (resizer != nil)
        {
          NSLog(@"ImageViewer - displayPath - readImage");
          [self _readImage];
        }
      else
        {
          NSLog(@"unexpected: connection started, but resizer not set");
        }
    }
}


- (oneway void)setResizer:(id)anObject
{
  [anObject setProtocolForProxy: @protocol(ImageResizerProtocol)];
  resizer = (ImageResizer *)anObject;
  RETAIN (resizer);
  [resizer setProxy: self];

  [self _readImage];
}



- (oneway void)imageReady:(NSDictionary *)imginfo
{
  BOOL imgok;

  imgok = NO;

  if (nil != imginfo)
    {
      NSData *imgdata = [imginfo objectForKey:@"imgdata"];
      NSString *imgPath = [imginfo objectForKey: @"imgpath"];

      NSLog(@"imageReady for: %@", imgPath);
      // since resizing is async, we check if we still need the generated image
      if (_pathToDisplay)
        { // resizing was in progress
          if ([_pathToDisplay isEqualToString:imgPath] == YES)
	    {
	      // is the inspector still an ImageViewer inspector ?
	      if ([self superview])
		{
		  [inspector contentsReadyAt: _pathToDisplay];
		}
	    }
	  else
            {
              NSLog(@"ImageViewer: trying to display inconsistent image");
              NSLog(@"%@ vs %@", _pathToDisplay, imgPath);
	      imgdata = nil;
	    }
	}
      else if (editPath)
	{ // image displayed completed
	  NSLog(@"we have editPath %@", editPath);
	  if ([editPath isEqualToString:imgPath] == YES)
	    {
	      NSLog(@"ImageViewer: trying to display existing image: %@", editPath);
	    }
	  else
	    {
	      NSLog(@"ImageViewer: image ready of non-current path");
	    }
	  // we remove image data, but we say the image is OK
	  // so current content is not changed
	  imgdata = nil;
	  imgok = YES;
	}

      if (imgdata)
	{
	  [imageView setImage: nil];
	  DESTROY (image);
	  image = [[NSImage alloc] initWithData: imgdata];

	  if (image)
	    {
	      NSImageRep *imgRep;
	      NSString *str;

	      imgRep = [[image representations] objectAtIndex:0];
	      if ([imgRep isKindOfClass:[NSBitmapImageRep class]])
		{
		  // Bitmap Images are scaled inside Resizer
		  [imageView setImageScaling:NSScaleNone];
		}
	      else
		{
		  // others, e.g. PDFs are just returned as-is from the Resizer
		  [imageView setImageScaling:NSScaleProportionally];
		}

	      float width = [[imginfo objectForKey: @"width"] floatValue];
	      float height = [[imginfo objectForKey: @"height"] floatValue];

	      imgok = YES;
	      if (valid == NO)
		{
		  valid = YES;
		  [errLabel removeFromSuperview];
		  [self addSubview: imageView];
		}

	      [imageView setImage: image];

	      str = NSLocalizedString(@"Width:", @"");
	      str = [NSString stringWithFormat: @"%@ %.0f", str, width];
	      [widthLabel setStringValue: str];

	      str = NSLocalizedString(@"Height:", @"");
	      str = [NSString stringWithFormat: @"%@ %.0f", str, height];
	      [heightLabel setStringValue: str];

	      ASSIGN (editPath, _pathToDisplay);
	      [editButt setEnabled: YES];
	      [[self window] makeFirstResponder: editButt];
	      DESTROY (_pathToDisplay);
	    }
	  else
	    {
	      NSLog(@"no image returned");
	    }
	}
    }
  else
    {
      NSLog(@"imageReady without imginfo");

      // whether we have or not read an image, we declare the content is ready
      // at most we won't display it, otherwise other data does not update
      if ([self superview])
	{
	  [inspector contentsReadyAt: _pathToDisplay];
	}
    }

  if (imgok == NO)
    {
      valid = NO;
      [imageView removeFromSuperview];
      [self addSubview: errLabel];
      [widthLabel setStringValue: @""];
      [heightLabel setStringValue: @""];
      [editButt setEnabled: NO];
    }

  [progView stop];
  [progView removeFromSuperview];  
}

- (void)displayData:(NSData *)data 
             ofType:(NSString *)type
{
}

- (NSString *)path
{
  return editPath;
}

- (void)stopTasks
{
  [imageView setImage: nil];
}

- (BOOL)canDisplayPath:(NSString *)path
{
  NSDictionary *attributes;
  NSString *defApp, *fileType, *extension;

  attributes = [[NSFileManager defaultManager] fileAttributesAtPath: path traverseLink: YES];
  if ([attributes objectForKey: NSFileType] == NSFileTypeDirectory)
    {
      return NO;
    }
		
  [ws getInfoForFile: path application: &defApp type: &fileType];
  extension = [path pathExtension];

  if ([[NSImage imageFileTypes] containsObject: [extension lowercaseString]])
    {
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
  NSUInteger i;
     
  for (i = 0; i < [languages count]; i++) {
    NSString *language = [languages objectAtIndex: i];
    NSString *langDir = [NSString stringWithFormat: @"%@.lproj", language];  
    NSString *helpPath = [langDir stringByAppendingPathComponent: @"Help.rtfd"];
  
    helpPath = [resPath stringByAppendingPathComponent: helpPath];
  
    if ([[NSFileManager defaultManager] fileExistsAtPath: helpPath]) {
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
