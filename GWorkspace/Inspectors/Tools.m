/* Tools.m
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
#include "GWLib.h"
#include "GWFunctions.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
  #endif
#include "Tools.h"
#include "GNUstep.h"

#define TOOLS_INDEX 1
#define NO_TOOLS_INDEX 0

static NSString *nibName = @"ToolsPanel";

@implementation Tools

- (void)dealloc
{
	TEST_RELEASE (inspBox);  
	TEST_RELEASE (matrix);
	TEST_RELEASE (insppaths);
  TEST_RELEASE (extensions);
	TEST_RELEASE (currentApp);
  [super dealloc];
}

- (id)init
{
	self = [super init];
  
	if(self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"Attribute Inspector: failed to load %@!", nibName);
    } else { 
      id cell;
       
 		  ws = [NSWorkspace sharedWorkspace];

      [scrollView setBorderType: NSBezelBorder];
      [scrollView setHasHorizontalScroller: YES];
      [scrollView setHasVerticalScroller: NO]; 

  	  cell = AUTORELEASE ([NSButtonCell new]);
  	  [cell setButtonType: NSPushOnPushOffButton];
  	  [cell setImagePosition: NSImageOnly]; 

  	  matrix = [[NSMatrix alloc] initWithFrame: NSZeroRect
			      	  					  mode: NSRadioModeMatrix prototype: cell
		       							    			  numberOfRows: 0 numberOfColumns: 0];
		  [matrix setIntercellSpacing: NSZeroSize];
		  [matrix setCellSize: NSMakeSize(64, 64)];
  	  [matrix setTarget: self];		
  	  [matrix setAction: @selector(setCurrentApplication:)];		
  	  [matrix setDoubleAction: @selector(openFile:)];		    
		  [scrollView setDocumentView: matrix];	

      [tabView selectTabViewItemAtIndex: NO_TOOLS_INDEX];

		  currentApp = nil;

      [cancelButt setEnabled: NO];         
      [okButt setEnabled: NO]; 

		  valid = NO;
    }
	}
  
	return self;
}

- (id)inspView
{
  return inspBox;
}

- (void)activateForPaths:(NSArray *)paths
{
	int pathscount;
  NSString *currentPath;  
  BOOL toolsok;
	int i;

	[okButt setEnabled: NO];		
	[cancelButt setEnabled: NO];

	pathscount = [paths count];
  currentPath = [paths objectAtIndex: 0];

  toolsok = YES; 
  for (i = 0; i < [paths count]; i++) {
		NSString *defApp = nil;
		NSString *fType = nil;

	  currentPath = [paths objectAtIndex: i];
		[ws getInfoForFile: currentPath application: &defApp type: &fType];		
		if (([fType isEqual: NSPlainFileType] == NO)
                       && ([fType isEqual: NSShellCommandFileType] == NO)) {
			toolsok = NO;		
			break;
    }
  }
    
	if (toolsok == YES) {		  	
		if (valid == NO) {
      [tabView selectTabViewItemAtIndex: TOOLS_INDEX];
			valid = YES;
		}
    [self findApplicationsForPaths: paths];
		
	} else {
		if (valid == YES) {
      [tabView selectTabViewItemAtIndex: NO_TOOLS_INDEX];
			valid = NO;
		}
	}
	
	[inspBox setNeedsDisplay: YES];	
}

- (void)deactivate
{
  [inspBox removeFromSuperview];
}

- (NSString *)inspname
{
	return NSLocalizedString(@"Tools", @"");
}

- (NSString *)winname
{
	return NSLocalizedString(@"Tools Inspector", @"");
}

- (NSButton *)revertButton
{
	return cancelButt;
}

- (NSButton *)okButton
{
	return okButt;
}

- (void)findApplicationsForPaths:(NSArray *)paths
{
	NSMutableDictionary *extensionsAndApps;
  NSMutableArray *commonApps;   
  NSString *s;
	id cell;
	BOOL appsforext;
  int i, count;
		
  ASSIGN (insppaths, paths);

	TEST_RELEASE (extensions);
  extensions = [[NSMutableArray alloc] initWithCapacity: 1];
  extensionsAndApps = [NSMutableDictionary dictionaryWithCapacity: 1];

	DESTROY (currentApp);
	[defAppField setStringValue: @""];
	[defPathField setStringValue: @""];

	appsforext = YES;
	
  for (i = 0; i < [insppaths count]; i++) {
    NSString *ext = [[insppaths objectAtIndex: i] pathExtension];		

    if ([extensions containsObject: ext] == NO) { 
		  NSDictionary *extinfo = [ws infoForExtension: ext];
			
      if (extinfo != nil) {
		    NSMutableArray *appsnames = [NSMutableArray arrayWithCapacity: 1];
				[appsnames addObjectsFromArray: [extinfo allKeys]];
        [extensionsAndApps setObject: appsnames forKey: ext];
				[extensions addObject: ext];				
      } else {
				appsforext = NO;
			}
    }            
  }   
				
  if ([extensions count] == 1) {
    NSString *ext = [extensions objectAtIndex: 0];
    commonApps = [NSArray arrayWithArray: [extensionsAndApps objectForKey: ext]];    
    currentApp = [ws getBestAppInRole: nil forExtension: ext];
    TEST_RETAIN (currentApp);			
		
  } else {
    int j, n;
		
		for (i = 0; i < [extensions count]; i++) {
			NSString *ext1 = [extensions objectAtIndex: i];
			NSMutableArray *a1 = [extensionsAndApps objectForKey: ext1];			
			
			for (j = 0; j < [extensions count]; j++) {
				NSString *ext2 = [extensions objectAtIndex: j];
				NSMutableArray *a2 = [extensionsAndApps objectForKey: ext2];
				
				count = [a1 count];			
				for (n = 0; n < count; n++) {
					NSString *s = [a1 objectAtIndex: n];
					if ([a2 containsObject: s] == NO) {
						[a1 removeObject: s];
						count--;
						n--;
					}
				}
				[extensionsAndApps setObject: a1 forKey: ext1];
			}
		}

    commonApps = [NSMutableArray arrayWithCapacity: 1];

    for (i = 0; i < [extensions count]; i++) {
      NSString *ext = [extensions objectAtIndex: i];
			NSArray *apps = [extensionsAndApps objectForKey: ext];
			
			for (j = 0; j < [apps count]; j++) {
				NSString *app = [apps objectAtIndex: j];
				if ([commonApps containsObject: app] == NO) {
					[commonApps addObject: app];
				}
			}
    }
		
		if ([commonApps count] != 0) {
			BOOL iscommapp = YES;		
			NSString *ext1 = [extensions objectAtIndex: 0];

			currentApp = [ws getBestAppInRole: nil forExtension: ext1];
			
			if ([commonApps containsObject: currentApp]) {
    		for (i = 1; i < [extensions count]; i++) {
					NSString *ext2 = [extensions objectAtIndex: i];
					NSString *app = [ws getBestAppInRole: nil forExtension: ext2];

					if ([currentApp isEqual: app] == NO) {
						iscommapp = NO;
					}
    		}
			} else {
				currentApp = nil;
			}

			if ((iscommapp == YES) && (currentApp != nil) && appsforext) {
				RETAIN (currentApp);		
			} else {
				currentApp = nil;
			}
		}
  }

  if (([commonApps count] != 0) && (currentApp != nil) && (appsforext == YES)) {
 	  [okButt setEnabled: YES];
  }	else {
 	  [okButt setEnabled: NO];
  }
	
	count = [commonApps count];
	
	[matrix renewRows: 1 columns: count];
	[matrix sizeToCells];
	
	if (appsforext == YES) {
		for(i = 0; i < count; i++) {
			NSString *appName = [commonApps objectAtIndex: i];
			NSString *appPath = [ws fullPathForApplication: appName];
			cell = [matrix cellAtRow: 0 column: i];
			[cell setImage: [ws iconForFile: appPath]];
			[cell setTitle: appName];
		}
		[matrix sizeToCells];
	}
	
	if(currentApp != nil) {
		NSArray *cells = [matrix cells];
		
		for(i = 0; i < [cells count]; i++) {
			cell = [cells objectAtIndex: i];
			if(cell && ([[cell title] isEqualToString: currentApp])) {
				[matrix selectCellAtRow: 0 column: i];
				[matrix scrollCellToVisibleAtRow: 0 column: i];
				break;
			}
		}

	  [defAppField setStringValue: [currentApp stringByDeletingPathExtension]];
    s = [ws fullPathForApplication: currentApp];
		if (s != nil) {
    	s = relativePathFittingInContainer(defPathField, s);
		} else {
			s = @"";
		}
	  [defPathField setStringValue: s];
	}
}

- (IBAction)setCurrentApplication:(id)sender
{
  NSString *s;
	
	ASSIGN (currentApp, [[sender selectedCell] title]);	
  s = [ws fullPathForApplication: currentApp];
  s = relativePathFittingInContainer(defPathField, s);
	[defPathField setStringValue: s];
  [defAppField setStringValue: [currentApp stringByDeletingPathExtension]];  
}

- (IBAction)setDefaultApplication:(id)sender
{
  NSString *ext, *app;
  NSArray *cells;
  NSMutableArray *newApps;
  id cell;
  int i, count;
  
  for (i = 0; i < [extensions count]; i++) {
    ext = [extensions objectAtIndex: i];  		
    [ws setBestApp: currentApp inRole: nil forExtension: ext];    
  }
  
  newApps = [NSMutableArray arrayWithCapacity: 1];
  [newApps addObject: currentApp];
  
  cells = [matrix cells];
	for(i = 0; i < [cells count]; i++) {
    app = [[cells objectAtIndex: i] title];
		if([app isEqualToString: currentApp] == NO) {
      [newApps addObject: app];
		}
  }
  
	count = [newApps count];
	[matrix renewRows: 1 columns: count];
  
  for(i = 0; i < count; i++) {
		app = [newApps objectAtIndex: i];
		cell = [matrix cellAtRow: 0 column: i];
		[cell setTitle: app];
		app = [ws fullPathForApplication: app];
		[cell setImage: [ws iconForFile: app]];
	}

  [matrix selectCellAtRow: 0 column: 0];
}

- (IBAction)openFile:(id)sender
{
  int i;
  
  for (i = 0; i < [insppaths count]; i++) {
    NSString *fpath = [insppaths objectAtIndex: i];
	  [ws openFile: fpath withApplication: [[sender selectedCell] title]];
  }
}

//
// NSTabView delegate Methods
//
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
  return YES;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
}

- (void)tabViewDidChangeNumberOfTabViewItems:(NSTabView *)TabView
{
}

@end
