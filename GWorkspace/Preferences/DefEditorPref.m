/* DefEditorPref.m
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
#include "DefEditorPref.h"
#include "GWorkspace.h"
#include "GNUstep.h"
#include <math.h>

#ifdef GNUSTEP 
  #define LABEL_MARGIN 8
#else
  #define LABEL_MARGIN 8
#endif

static NSString *nibName = @"DefEditorPref";

@implementation DefEditorPref

- (void)dealloc
{
  TEST_RELEASE (prefbox);
  TEST_RELEASE (defEditor);
  RELEASE (noEditorStr);
  RELEASE (font);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {  
    ASSIGN (font, [NSFont systemFontOfSize: 12]);
    ASSIGN (noEditorStr, NSLocalizedString(@"No Default Editor", @""));
  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
	    NSUserDefaults *defaults;
      NSString *fullPath;
      NSImage *image;      
      
      RETAIN (prefbox);
      iconBoxWidth = [iconbox frame].size.width;
      labelHeight = [nameLabel frame].size.height;
      labelOrigin = [nameLabel frame].origin;      
      RELEASE (win);
      
		  ws = [NSWorkspace sharedWorkspace];
      gw = [GWorkspace gworkspace];
      defEditor = nil;
      
      [imView setImageScaling: NSScaleProportionally];

      defaults = [NSUserDefaults standardUserDefaults];      
	    defEditor = [defaults stringForKey: @"defaulteditor"];
      if (defEditor != nil) {
		    RETAIN (defEditor);

        fullPath = [ws fullPathForApplication: defEditor];
        image = [ws iconForFile: fullPath];
        [imView setImage: image];

	      [nameLabel setStringValue: defEditor];
        [self tile];
      } else {
	      [nameLabel setStringValue: noEditorStr];
        [self tile];
      }
      
      /* Internationalization */
      [chooseButt setTitle: NSLocalizedString(@"Choose", @"")];
      [iconbox setTitle: NSLocalizedString(@"Default Editor", @"")];
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
  return NSLocalizedString(@"Editor", @"");
}

- (IBAction)chooseEditor:(id)sender
{
	NSOpenPanel *openPanel;
	NSArray *fileTypes;
	NSString *appName;
  NSString *app, *type;
	int result;

	fileTypes = [NSArray arrayWithObjects: @"app", @"debug", nil];
  
	openPanel = [NSOpenPanel openPanel];
	[openPanel setTitle: @"open"];	
  [openPanel setAllowsMultipleSelection: NO];
  [openPanel setCanChooseFiles: YES];
  [openPanel setCanChooseDirectories: NO];

  result = [openPanel runModalForDirectory: NSHomeDirectory() file: nil types: fileTypes];
	if(result != NSOKButton) {
		return;
  }
  
	appName = [NSString stringWithString: [openPanel filename]];
  
  [ws getInfoForFile: appName application: &app type: &type];
  
  if ([type isEqualToString: NSApplicationFileType] == NO) {
    NSRunAlertPanel(nil, 
        [NSString stringWithFormat: @"%@ is not a valid application!", appName], 
                            @"Continue", nil, nil);  
    return;
  }	
      
  [self setEditor: [appName lastPathComponent]];
}

- (void)setEditor:(NSString *)editor
{
  NSUserDefaults *defaults;
  NSImage *image;
  NSString *fullPath;
  
  if ([editor isEqualToString: defEditor] == YES) {
    return;
  }
  
  ASSIGN (defEditor, editor);
  
  fullPath = [ws fullPathForApplication: defEditor];
  image = [ws iconForFile: fullPath];

  [imView setImage: image];
      
  [nameLabel setStringValue: defEditor];
  [self tile];
        
  defaults = [NSUserDefaults standardUserDefaults];      
	[defaults setObject: defEditor forKey: @"defaulteditor"];
	[defaults synchronize];
  
  [gw changeDefaultEditor: defEditor];
}

- (void)tile
{
  NSRect r;
  NSPoint p;

  r = NSMakeRect(0, 0, [font widthOfString: [nameLabel stringValue]] + LABEL_MARGIN, labelHeight);
  [nameLabel setFrame: r];        
  p = NSMakePoint((iconBoxWidth - [nameLabel frame].size.width) / 2, labelOrigin.y);        
  [nameLabel setFrameOrigin: p]; 
}

@end
