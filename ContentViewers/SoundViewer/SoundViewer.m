/* SoundViewer.m
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
#include "SoundViewer.h"
#include "GNUstep.h"

@implementation SoundViewer

- (void)dealloc
{
  [nc removeObserver: self];
  if (task && [task isRunning]) {
    [task terminate];
	}
  TEST_RELEASE (task);
	
	TEST_RELEASE (soundPath);
	TEST_RELEASE (sound);
	RELEASE (playButt);
	RELEASE (stopButt);
	RELEASE (pauseButt);
	RELEASE (indicator);
	RELEASE (textView);
	TEST_RELEASE (editPath);
	RELEASE (bundlePath);
  
  [super dealloc];
}

- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
	self = [super initWithFrame: frame];

	if(self) {
		NSBox *playBox;
		NSBundle *bundle;
		NSString *imagePath;
		NSImage *image;

		panel = (id<InspectorsProtocol>)apanel;
		index = idx;
		nc = [NSNotificationCenter defaultCenter];
		ws = [NSWorkspace sharedWorkspace];
		
		playBox = [[NSBox alloc] initWithFrame: NSMakeRect(30, 125, 197, 80)];	
    [playBox setBorderType: NSGrooveBorder];
		[playBox setTitle: NSLocalizedString(@"Player", @"")];
    [playBox setTitlePosition: NSAtTop];
		[playBox setContentViewMargins: NSMakeSize(0, 0)]; 
		[self addSubview: playBox]; 
		RELEASE (playBox);

		bundle = [NSBundle bundleForClass: [self class]];
		
		stopButt = [[NSButton alloc] initWithFrame: NSMakeRect(56, 30, 24, 24)];
		[stopButt setButtonType: NSMomentaryLight];
		[stopButt setImagePosition: NSImageOnly];
		imagePath = [bundle pathForResource: @"stop" ofType: @"tiff" inDirectory: nil];		
		image = [[NSImage alloc] initWithContentsOfFile: imagePath];
		[stopButt setImage: image];
		RELEASE (image);
		[stopButt setTarget:self];
		[stopButt setAction:@selector(buttonsAction:)];
		[playBox addSubview: stopButt]; 

		pauseButt = [[NSButton alloc] initWithFrame: NSMakeRect(86, 30, 24, 24)];
		[pauseButt setButtonType: NSMomentaryLight];
		[pauseButt setImagePosition: NSImageOnly];
		imagePath = [bundle pathForResource: @"pause" ofType: @"tiff" inDirectory: nil];		
		image = [[NSImage alloc] initWithContentsOfFile: imagePath];
		[pauseButt setImage: image];
		RELEASE (image);
		[pauseButt setTarget:self];
		[pauseButt setAction:@selector(buttonsAction:)];
		[playBox addSubview: pauseButt]; 

		playButt = [[NSButton alloc] initWithFrame: NSMakeRect(116, 30, 24, 24)];
		[playButt setButtonType: NSMomentaryLight];
		[playButt setImagePosition: NSImageOnly];
		imagePath = [bundle pathForResource: @"play" ofType: @"tiff" inDirectory: nil];		
		image = [[NSImage alloc] initWithContentsOfFile: imagePath];
		[playButt setImage: image];
		RELEASE (image);
		[playButt setTarget:self];
		[playButt setAction:@selector(buttonsAction:)];
		[playBox addSubview: playButt]; 
		
		indicator = [[NSProgressIndicator alloc] 
												initWithFrame: NSMakeRect(10, 6, 172, 16)];
		[indicator setIndeterminate: YES];
		[playBox addSubview: indicator]; 
				
		textView = [[NSTextView alloc] initWithFrame: NSMakeRect(30, 10, 197, 110)];
		[textView setRichText: NO];
		[textView setDrawsBackground: NO];
		[self addSubview: textView]; 
				
		sound = nil;
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

- (void)buttonsAction:(id)sender
{
	if (sender == playButt) {
		if (sound && [sound isPlaying]) {
			return;			
		}

		if (sound == nil) {
			NSSound *snd = [[NSSound alloc] initWithContentsOfFile: soundPath
																								 byReference: NO]; 
			if (snd) {
				ASSIGN (sound, snd);
				RELEASE (snd);
			}
		}

		[indicator startAnimation: self];
		[sound play];
		
	} else if (sender == pauseButt) {
		if (sound && [sound isPlaying]) {
			[indicator stopAnimation: self];
			[sound pause];
		}
		
	} else if (sender == stopButt) {
		if (sound && [sound isPlaying]) {
			[indicator stopAnimation: self];
			[sound stop];
		}
	}
}

- (void)findContentsAtPath:(NSString *)apath
{
  NSArray *args;
	NSFileHandle *fileHandle;

  if (task && [task isRunning]) {
		[task terminate];
		DESTROY (task);		
	}

	ASSIGN (task, [NSTask new]); 
  [task setLaunchPath: @"/bin/sh"];

  args = [NSArray arrayWithObjects: @"-c", [NSString stringWithFormat: @"file -b %@", apath], nil];
  [task setArguments: args];

  ASSIGN (pipe, [NSPipe pipe]);
	AUTORELEASE (pipe);
  [task setStandardOutput: pipe];
    
  fileHandle = [pipe fileHandleForReading];
  [nc addObserver: self
    		 selector: @selector(dataFromTask:)
    				 name: NSFileHandleReadToEndOfFileCompletionNotification
    			 object: (id)fileHandle];

  [fileHandle readToEndOfFileInBackgroundAndNotify];    
  
  [nc addObserver: self 
         selector: @selector(endOfTask:) 
             name: NSTaskDidTerminateNotification 
           object: (id)task];
                     
  [task launch];            
}

- (void)dataFromTask:(NSNotification *)notification
{
  NSDictionary *userInfo = [notification userInfo];
  NSData *readData = [userInfo objectForKey: NSFileHandleNotificationDataItem];
  NSString *descrstr = [[NSString alloc] initWithData: readData encoding: NSNonLossyASCIIStringEncoding];
  NSRange range;
	
	[textView setSelectable: YES];

	if (([textView string]) && ([[textView string] length])) {
		[textView replaceCharactersInRange: NSMakeRange(0, [[textView string] length])
														withString: descrstr];
	} else {
		[textView insertText: descrstr];
	}
  RELEASE (descrstr);
	
	range = NSMakeRange(0, [[textView string] length]);
	
	[textView setAlignment: NSCenterTextAlignment 
							  	 range: range];
	
	[[textView textStorage] addAttribute: NSFontAttributeName 
																 value: [NSFont systemFontOfSize: 12] 
																 range: range];
		
	[[textView textStorage] addAttribute: NSForegroundColorAttributeName 
																 value: [NSColor grayColor] 
																 range: range];			

	[textView setSelectable: NO];	
	[textView setNeedsDisplay: YES];								
}

- (void)endOfTask:(NSNotification *)notification
{
	if ([notification object] == task) {		
		[nc removeObserver: self name: NSTaskDidTerminateNotification object: task];
		DESTROY (task);										
	}
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
	ASSIGN (editPath, path);
	
	buttOk = [panel okButton];
	if (buttOk) {
  	[buttOk setTarget: self];		
		[buttOk setAction: @selector(editFile:)];	
		[buttOk setEnabled: YES];	
	}	
	
	if (sound) {
		if ([sound isPlaying]) {
			[sound stop];
			[indicator stopAnimation: self];
		}
		DESTROY (sound);
	}
	ASSIGN (soundPath, path);
	[self findContentsAtPath: path];
}

- (BOOL)displayData:(NSData *)data ofType:(NSString *)type
{
  return NO;
}

- (BOOL)stopTasks
{
	if (sound) {
		if ([sound isPlaying]) {
			[sound stop];
			[indicator stopAnimation: self];
		}
		DESTROY (sound);
	}

  if (task && [task isRunning]) {
		[nc removeObserver: self name: NSTaskDidTerminateNotification object: task];
		[task terminate];    
		DESTROY (task);		
	}

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
	types = [NSArray arrayWithObjects: @"aiff", @"wav", @"snd", @"au", nil];

	if ([types containsObject: extension]) {
		return YES;
	}
//	if ([[NSSound soundUnfilteredFileTypes] containsObject: extension]) {
//		return YES;
//	}

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
	return NSLocalizedString(@"Sound Inspector", @"");	
}

@end
