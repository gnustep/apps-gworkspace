 /*  -*-objc-*-
 *  DeskTopPref.m: Implementation of the DeskTopPref Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "DeskTopPref.h"
#include "GWorkspace.h"
#include "GNUstep.h"

static NSString *nibName = @"DeskTopPref";

@implementation ColorView

- (void)dealloc
{
  TEST_RELEASE (color);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  color = nil;
  return self;
}

- (void)setColor:(NSColor *)c
{
  ASSIGN (color, c);
}

- (void)drawRect:(NSRect)rect
{
  NSRect bounds = [self bounds];  
  float x = rect.origin.x + 2;
  float y = rect.origin.y + 2;
  float w = rect.size.width - 4;
  float h = rect.size.height - 4;
  NSRect colorRect = NSMakeRect(x, y, w, h);
  
  [super drawRect: rect];
  
  NSDrawGrayBezel(bounds, rect);
  
  if (color != nil) {
    [color set];
    NSRectFill(colorRect);
  } 
}

@end

@implementation DeskTopPref

- (void)dealloc
{
  TEST_RELEASE (prefbox);
  RELEASE (colorsView);
  TEST_RELEASE (color);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
      NSDictionary *desktopViewPrefs = [defaults dictionaryForKey: @"desktopviewprefs"];
      NSString *imagePath = nil;
    
      RETAIN (prefbox);
      RELEASE (win);

		  gw = [GWorkspace gworkspace];

      deskactive = [defaults boolForKey: @"desktop"];

      if (desktopViewPrefs != nil) { 
    	  id dictEntry = [desktopViewPrefs objectForKey: @"backcolor"];
			  
        imagePath = [desktopViewPrefs objectForKey: @"imagepath"];

    	  if(dictEntry == nil) {
      	  ASSIGN (color, [NSColor windowBackgroundColor]);
    	  } else {
          NSString *cs;
          
          cs = [dictEntry objectForKey: @"red"];
          [redField setStringValue: cs];
      	  r = [cs floatValue];
          [redSlider setFloatValue: r];          
          cs = [dictEntry objectForKey: @"green"];  
          [greenField setStringValue: cs];
      	  g = [cs floatValue];
          [greenSlider setFloatValue: g];          
          cs = [dictEntry objectForKey: @"blue"]; 
          [blueField setStringValue: cs];
      	  b = [cs floatValue]; 
          [blueSlider setFloatValue: b];
				  alpha = [[dictEntry objectForKey: @"alpha"] floatValue];
      	  ASSIGN (color, [NSColor colorWithCalibratedRed: r green: g blue: b alpha: alpha]);
    	  }
      } else {
			  imagePath = nil;
    	  ASSIGN (color, [NSColor windowBackgroundColor]);
		  }

      colorsView = [ColorView new];
      [colorsView setFrame: NSMakeRect(0, 0, 64, 64)];  
      [colorsView setColor: color];      
		  [colorsBox addSubview: colorsView]; 

     if(imagePath != nil) {
        [setImageButt setTitle: NSLocalizedString(@"Unset Image", @"")];	
        [setImageButt setAction: @selector(unsetImage:)];	
      } else {
        [setImageButt setTitle: NSLocalizedString(@"Set Image", @"")];	
        [setImageButt setAction: @selector(chooseImage:)];	
      }

      /* Internationalization */
      [controlsbox setTitle: NSLocalizedString(@"Desktop Color", @"")];
      [setColorButt setTitle: NSLocalizedString(@"Set", @"")];
      [redlabel setStringValue: NSLocalizedString(@"red", @"")];
      [greenlabel setStringValue: NSLocalizedString(@"green", @"")];
      [bluelabel setStringValue: NSLocalizedString(@"blue", @"")];

		  [(NSButton *)chooseDeskButt setState: deskactive];
		  [self setDeskState: chooseDeskButt];
    }
  }
  
  return self;
}

- (NSView *)prefView
{
  return prefbox;
}

- (NSString *)prefName
{
  return NSLocalizedString(@"Desktop", @"");
}

- (IBAction)setDeskState:(id)sender
{
	if ([sender state] == NSOnState) {
		deskactive = YES;
    [chooseDeskButt setTitle: NSLocalizedString(@"Deactivate desktop", @"")];    
		[redSlider setEnabled: YES];
		[greenSlider setEnabled: YES];
		[blueSlider setEnabled: YES];
		[colorsView setColor: color];
  	[colorsView setNeedsDisplay: YES];	
		[setColorButt setEnabled: YES];
		[setImageButt setEnabled: YES];
	} else {
		deskactive = NO;
    [chooseDeskButt setTitle: NSLocalizedString(@"Activate desktop", @"")];    
		[redSlider setEnabled: NO];
		[greenSlider setEnabled: NO];
		[blueSlider setEnabled: NO];
		[colorsView setColor: [NSColor windowBackgroundColor]];
		[colorsView setNeedsDisplay: YES];	
		[setColorButt setEnabled: NO];
		[setImageButt setEnabled: NO];
	}

	[gw showHideDesktop: deskactive];	
}

- (IBAction)makeColor:(id)sender
{
  if (sender == redSlider) {
    r = [sender floatValue];    
    [redField setStringValue: [NSString stringWithFormat: @"%.2f", r]];
  } else if (sender == greenSlider) {
    g = [sender floatValue];
    [greenField setStringValue: [NSString stringWithFormat: @"%.2f", g]];
  } else if (sender == blueSlider) {
    b = [sender floatValue];
    [blueField setStringValue: [NSString stringWithFormat: @"%.2f", b]];
  }

  ASSIGN (color, [NSColor colorWithCalibratedRed: r green: g blue: b alpha: 1]);  
  [colorsView setColor: color];
  [colorsView setNeedsDisplay: YES];
}

- (IBAction)setColor:(id)sender
{
  NSUserDefaults *defaults;	
  NSMutableDictionary *desktopViewPrefs, *colorDict;
  id dictEntry;
   
  defaults = [NSUserDefaults standardUserDefaults];	
  
  dictEntry = [defaults dictionaryForKey: @"desktopviewprefs"];
  if (dictEntry == nil) {      
    desktopViewPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
  } else {
 		desktopViewPrefs = [dictEntry mutableCopy];
  }

  colorDict = [NSMutableDictionary dictionaryWithCapacity: 1];
  [colorDict setObject: [NSString stringWithFormat: @"%f", r] forKey: @"red"];
  [colorDict setObject: [NSString stringWithFormat: @"%f", g] forKey: @"green"];
  [colorDict setObject: [NSString stringWithFormat: @"%f", b] forKey: @"blue"];
  [colorDict setObject: @"1.0" forKey: @"alpha"];
	
  [desktopViewPrefs setObject: colorDict forKey: @"backcolor"];
  [defaults setObject: desktopViewPrefs forKey: @"desktopviewprefs"];
  [defaults synchronize];  
	RELEASE (desktopViewPrefs);
	
	[[NSNotificationCenter defaultCenter]
 				postNotificationName: GWDesktopViewColorChangedNotification
	 								    object: colorDict];	
}

- (IBAction)chooseImage:(id)sender
{
	NSOpenPanel *openPanel;
	NSArray *fileTypes;
	NSString *imagePath;
	int result;
  NSUserDefaults *defaults;	
  NSMutableDictionary *desktopViewPrefs;
  id dictEntry;
   
	fileTypes = [NSArray arrayWithObjects: @"tiff", @"tif", @"TIFF", @"TIFF", @"jpeg", @"jpg", @"JPEG", @"JPG", nil];
  
	openPanel = [NSOpenPanel openPanel];
	[openPanel setTitle: @"open"];	
  [openPanel setAllowsMultipleSelection: NO];
  [openPanel setCanChooseFiles: YES];
  [openPanel setCanChooseDirectories: NO];

  result = [openPanel runModalForDirectory: NSHomeDirectory() file: nil types: fileTypes];
	if(result != NSOKButton) {
		return;
  }
  
	imagePath = [NSString stringWithString: [openPanel filename]];
  [setImageButt setTitle: @"Unset Image"];	
  [setImageButt setAction: @selector(unsetImage:)];	
  [setImageButt setNeedsDisplay: YES];
                       
  defaults = [NSUserDefaults standardUserDefaults];	  
  dictEntry = [defaults dictionaryForKey: @"desktopviewprefs"];
  if (dictEntry == nil) {      
    desktopViewPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
  } else {
 		desktopViewPrefs = [dictEntry mutableCopy];
  }  
  [desktopViewPrefs setObject: imagePath forKey: @"imagepath"];
  [defaults setObject: desktopViewPrefs forKey: @"desktopviewprefs"];
  [defaults synchronize];  
  RELEASE (desktopViewPrefs);      
  	
	[[NSNotificationCenter defaultCenter]
 				postNotificationName: GWDesktopViewImageChangedNotification
	 								    object: imagePath];
}

- (IBAction)unsetImage:(id)sender
{
  NSUserDefaults *defaults;	
  NSMutableDictionary *desktopViewPrefs;
  NSString *imagePath;
  id dictEntry;

  defaults = [NSUserDefaults standardUserDefaults];	
  
  dictEntry = [defaults dictionaryForKey: @"desktopviewprefs"];
  if (dictEntry != nil) {      
 		desktopViewPrefs = [dictEntry mutableCopy];
    imagePath = [desktopViewPrefs objectForKey: @"imagepath"];
    if(imagePath != nil) {
      [desktopViewPrefs removeObjectForKey: @"imagepath"];  
      [defaults setObject: desktopViewPrefs forKey: @"desktopviewprefs"];
      [defaults synchronize];  
    }
    RELEASE (desktopViewPrefs);  
  }    
	
  [setImageButt setTitle: @"Set Image"];	
  [setImageButt setAction: @selector(chooseImage:)];	
  [setImageButt setNeedsDisplay: YES];

	[[NSNotificationCenter defaultCenter]
 				postNotificationName: GWDesktopViewUnsetImageNotification
	 								    object: nil];
}

@end
