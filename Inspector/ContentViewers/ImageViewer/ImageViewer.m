/* ImageViewer.m
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <AppKit/AppKit.h>
#include "ImageViewer.h"
#include "ImgReader.h"
#include <math.h>

@implementation ImageViewer

- (void)dealloc
{
  [nc removeObserver: self];  
  DESTROY (readerConn);
  DESTROY (reader);
  TEST_RELEASE (bundlePath);
  TEST_RELEASE (dataRep);
  TEST_RELEASE (imagePath);	
  TEST_RELEASE (nextPath);	
  TEST_RELEASE (editPath);	
  RELEASE (extsarr);
  RELEASE (imview);
  RELEASE (errLabel);
  RELEASE (progView);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
          inspector:(id)insp
{
  self = [super initWithFrame: frameRect];
  
  if(self) {
    NSRect r = [self frame];
    
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
    r.size.width = [self frame].size.width - 4;
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
                                      @"jpeg", @"jpg", @"gif", @"xpm", nil]));

    inspector = insp;
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    ws = [NSWorkspace sharedWorkspace];
        
    valid = YES;
    
    reader = nil;
    bundlePath = nil;
    dataRep = nil;
    imagePath = nil;
    nextPath = nil;
    editPath = nil;
    
    [nc addObserver: self
           selector: @selector(threadWillExit:)
               name: NSThreadWillExitNotification
             object: nil];
  }
	
	return self;
}

- (void)threadWillExit:(NSNotification *)notification
{
  NSLog(@"thread will exit");
}

- (void)setBundlePath:(NSString *)path
{
  ASSIGN (bundlePath, path);
}

- (NSString *)bundlePath
{
  return bundlePath;
}

- (void)setDataRepresentation:(NSData *)rep
{
  ASSIGN (dataRep, rep);
}

- (NSData *)dataRepresentation
{
  return dataRep;
}

- (void)setIsRemovable:(BOOL)value
{
  removable = value;
}

- (BOOL)isRemovable
{
  return removable;
}

- (void)setIsExternal:(BOOL)value
{
  external = value;
}

- (BOOL)isExternal
{
  return external;
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

  if (reader == nil) {
    NSPort *port[2];  
    NSArray *portArray;
  
    port[0] = (NSPort *)[NSPort port];
    port[1] = (NSPort *)[NSPort port];
    portArray = [NSArray arrayWithObjects: port[1], port[0], nil];

    readerConn = [[NSConnection alloc] initWithReceivePort: (NSPort *)port[0]
                                                  sendPort: (NSPort *)port[1]];
    [readerConn setRootObject: self];
    [readerConn setDelegate: self];
    [readerConn enableMultipleThreads];

    [nc addObserver: self 
				   selector: @selector(readerConnDidDie:)
	    			   name: NSConnectionDidDieNotification 
             object: readerConn];

    NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(createReaderWithPorts:)
                               toTarget: [ImgReader class]
                             withObject: portArray];
    }
    NS_HANDLER
    {
      NSLog(@"Error! A fatal error occured while detaching the thread.");
    }
    NS_ENDHANDLER
    
  } else {
    [self addSubview: progView]; 
    [progView start];
    [reader readImageAtPath: imagePath setSize: [imview frame].size];
  }
}

- (void)displayLastPath:(BOOL)forced
{
  if (editPath) {
    if (forced) {
      [self displayPath: editPath];
    } else {
      [inspector contentsReadyAt: editPath];
    }
  }
}

- (void)setReader:(id)anObject
{
  if (reader == nil) {
    [anObject setProtocolForProxy: @protocol(ImageReaderProtocol)];
    reader = (id <ImageReaderProtocol>)anObject;
    RETAIN (reader);
    [self addSubview: progView]; 
    [progView start];    
    [reader readImageAtPath: imagePath setSize: [imview frame].size];
  }
}

- (void)readerConnDidDie:(NSNotification *)notification
{
	id diedconn = [notification object];

  if (diedconn == readerConn) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: readerConn];
    DESTROY (reader);
    DESTROY (readerConn);
    NSLog(@"reader connection died", @"");
  }
}

- (void)imageReady:(NSData *)data
{
  NSDictionary *imginfo = [NSUnarchiver unarchiveObjectWithData: data];
  NSData *imgdata = [imginfo objectForKey: @"imgdata"];
  BOOL imgok = YES;
  NSString *lastPath;
  
  if ([self superview]) {      
    [inspector contentsReadyAt: imagePath];
  }
        
  if (imgdata) {
    NSImage *image = [[NSImage alloc] initWithData: imgdata];
    
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
      RELEASE (image);

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
	
  if(([fileType isEqual: NSPlainFileType] == NO)
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
		[ws openFile: editPath withApplication: appName];
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
    refreshInterval:(float)refresh
{
  self = [super initWithFrame: frameRect];

  if (self) {
    int i;
  
    images = [NSMutableArray new];
  
    for (i = 0; i < IMAGES; i++) {
      NSString *imname = [NSString stringWithFormat: @"anim-logo-%d.tiff", i];
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
  animating = NO;
  if (progTimer && [progTimer isValid]) {
    [progTimer invalidate];
  }
  [self setNeedsDisplay: YES];
}

- (void)animate:(id)sender
{
  [self setNeedsDisplay: YES];
  index++;
  if (index == [images count]) {
    index = 0;
  }
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
