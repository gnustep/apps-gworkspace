/* Tools.m
 *  
 * Copyright (C) 2004-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          RIccardo Mottola
 * Date: January 2004
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <math.h>
#import "Tools.h"
#import "Inspector.h"
#import "IconView.h"
#import "Functions.h"
#import "FSNodeRep.h"

#define ICNSIZE 48

static NSString *nibName = @"Tools";

@implementation Tools

- (void)dealloc
{
  RELEASE (toolsBox); 
  RELEASE (errLabel); 
  RELEASE (mainBox);   
  RELEASE (insppaths);
  RELEASE (extensions);
  RELEASE (currentApp);
  
  [super dealloc];
}

- (id)initForInspector:(id)insp
{
  self = [super init];
  
  if (self) {
    NSRect r;
    id cell;
  
    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    } 
    
    RETAIN (mainBox);
    RETAIN (toolsBox);
    RELEASE (win); 

    inspector = insp;
    [iconView setInspector: inspector];
    ws = [NSWorkspace sharedWorkspace];

    [scrollView setBorderType: NSBezelBorder];
    [scrollView setHasHorizontalScroller: YES];
    [scrollView setHasVerticalScroller: NO]; 

  	cell = [NSButtonCell new];
  	[cell setButtonType: NSPushOnPushOffButton];
  	[cell setImagePosition: NSImageOnly]; 

  	matrix = [[NSMatrix alloc] initWithFrame: NSZeroRect
			      	  					mode: NSRadioModeMatrix prototype: cell
		       							    			numberOfRows: 0 numberOfColumns: 0];
    RELEASE (cell);
		[matrix setIntercellSpacing: NSZeroSize];
    [matrix setCellSize: NSMakeSize(64, [[scrollView contentView] bounds].size.height)];
		[matrix setAllowsEmptySelection: YES];
  	[matrix setTarget: self];		
  	[matrix setAction: @selector(setCurrentApplication:)];		
  	[matrix setDoubleAction: @selector(openFile:)];		    
		[scrollView setDocumentView: matrix];	
    RELEASE (matrix);

    r = [toolsBox bounds];
    r.origin.y = 165;
    r.size.height = 25;
  	errLabel = [[NSTextField alloc] initWithFrame: r];	
  	[errLabel setAlignment: NSCenterTextAlignment];
		[errLabel setFont: [NSFont systemFontOfSize: 18]];
  	[errLabel setBackgroundColor: [NSColor windowBackgroundColor]];
  	[errLabel setTextColor: [NSColor darkGrayColor]];	
  	[errLabel setBezeled: NO];
  	[errLabel setEditable: NO];
  	[errLabel setSelectable: NO];
		[errLabel setStringValue: NSLocalizedString(@"No Tools Inspector", @"")];

    insppaths = nil;
		currentApp = nil;
    extensions = nil;
    [okButt setEnabled: NO]; 
	}
  
	return self;
}

- (NSView *)inspView
{
  return mainBox;
}

- (NSString *)winname
{
  return NSLocalizedString(@"Tools Inspector", @"");
}

- (void)activateForPaths:(NSArray *)paths
{
  BOOL toolsOK = YES;
  NSInteger i;

  if (paths == nil) {
    DESTROY (insppaths);
    return;
  }

  [okButt setEnabled: NO];		  

  if ([paths count] == 1)
    { 
      FSNode *node = [FSNode nodeWithPath: [paths objectAtIndex: 0]];
      NSImage *icon = [[FSNodeRep sharedInstance] iconOfSize: ICNSIZE forNode: node];
      
      [iconView setImage: icon];
      [titleField setStringValue: [node name]];
    }
  else
    {
      NSImage *icon = [[FSNodeRep sharedInstance] multipleSelectionIconOfSize: ICNSIZE];
      NSString *items = NSLocalizedString(@"items", @"");
      items = [NSString stringWithFormat: @"%lu %@", (long unsigned)[paths count], items];
      [titleField setStringValue: items];  
      [iconView setImage: icon];
    }
   
  for (i = 0; i < [paths count]; i++)
    {
      FSNode *node = [FSNode nodeWithPath: [paths objectAtIndex: i]];
  
      if (![node isValid])
        {  
          toolsOK = NO;
          break;
        }
  }

  // We have a valid node and found applications to open it
  if (toolsOK && [self findApplicationsForPaths: paths])
    {
      [errLabel removeFromSuperview];
      [mainBox addSubview: toolsBox];
    }
  else
    {
      [toolsBox removeFromSuperview];
      [mainBox addSubview: errLabel];
    }
}

- (BOOL)findApplicationsForPaths:(NSArray *)paths
{
  NSMutableDictionary *extensionsAndApps;
  NSMutableArray *commonApps;   
  NSString *s;
  id cell;
  BOOL appsforext;
  NSInteger i, count;

  ASSIGN (insppaths, paths);

  RELEASE (extensions);
  extensions = [NSMutableArray new];
  extensionsAndApps = [NSMutableDictionary dictionary];

  DESTROY (currentApp);
  [defAppField setStringValue: @""];
  [defPathField setStringValue: @""];
  
  appsforext = YES;
	
  for (i = 0; i < [insppaths count]; i++)
    {
      NSString *ext = [[insppaths objectAtIndex: i] pathExtension];		
      
      if ([extensions containsObject: ext] == NO)
        { 
          NSDictionary *extinfo = [ws infoForExtension: ext];
          
          if (extinfo)
            {
              NSMutableArray *appsnames = [NSMutableArray arrayWithCapacity: 1];
              [appsnames addObjectsFromArray: [extinfo allKeys]];
              [extensionsAndApps setObject: appsnames forKey: ext];
              [extensions addObject: ext];				
            }
          else
            {
              appsforext = NO;
            }
        }            
    }

  if (!appsforext)
    return NO;

  if ([extensions count] == 1) {
    NSString *ext = [extensions objectAtIndex: 0];
    commonApps = [NSMutableArray arrayWithArray: [extensionsAndApps objectForKey: ext]];    
    currentApp = [ws getBestAppInRole: nil forExtension: ext];
    RETAIN (currentApp);			
		
  }
  else
    {
      NSInteger j, n;
		
      for (i = 0; i < [extensions count]; i++)
        {
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

    commonApps = [NSMutableArray array];

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

  if (currentApp == nil)
    return NO;

  if ([commonApps count] == 0)
    return NO;

  [okButt setEnabled: YES];

  count = [commonApps count];

  [matrix renewRows: 1 columns: count];
  [matrix sizeToCells];

  if (appsforext)
    {
      for (i = 0; i < count; i++)
	{
	  NSString *appName = [commonApps objectAtIndex: i];
	  FSNode *node = [FSNode nodeWithPath: [ws fullPathForApplication: appName]];
	  NSImage *icon = [[FSNodeRep sharedInstance] iconOfSize: ICNSIZE forNode: node];

	  cell = [matrix cellAtRow: 0 column: i];
	  [cell setImage: icon];
	  [cell setTitle: appName];
	}

      [matrix sizeToCells];
    }
	
  if (currentApp != nil)
    {
      NSArray *cells = [matrix cells];
		
      for(i = 0; i < [cells count]; i++)
	{
	  cell = [cells objectAtIndex: i];
	  if(cell && ([[cell title] isEqualToString: currentApp]))
	    {
	      [matrix selectCellAtRow: 0 column: i];
	      [matrix scrollCellToVisibleAtRow: 0 column: i];
	      break;
	    }
	}

      [defAppField setStringValue: [currentApp stringByDeletingPathExtension]];
      s = [ws fullPathForApplication: currentApp];
      if (s != nil)
	s = relativePathFit(defPathField, s);
      else
	s = @"";
      [defPathField setStringValue: s];
    }

  return YES;
}

- (void)setCurrentApplication:(id)sender
{
  NSString *s;
	
  ASSIGN (currentApp, [[sender selectedCell] title]);	
  s = [ws fullPathForApplication: currentApp];
  s = relativePathFit(defPathField, s);
  [defPathField setStringValue: s];
  [defAppField setStringValue: [currentApp stringByDeletingPathExtension]];  
}

- (IBAction)setDefaultApplication:(id)sender
{
  NSString *ext, *app;
  NSDictionary *changedInfo;
  NSArray *cells;
  NSMutableArray *newApps;
  id cell;
  FSNode *node;
  NSImage *icon;
  NSInteger i, count;
  
  for (i = 0; i < [extensions count]; i++)
    {
      ext = [extensions objectAtIndex: i];  		
      [ws setBestApp: currentApp inRole: nil forExtension: ext];  
    }

  changedInfo = [NSDictionary dictionaryWithObjectsAndKeys: 
                                                  currentApp, @"app", 
                                                  extensions, @"exts", nil];
  
	[[NSDistributedNotificationCenter defaultCenter]
 				   postNotificationName: @"GWAppForExtensionDidChangeNotification"
	 								       object: nil
                       userInfo: changedInfo];  
  
  newApps = [NSMutableArray arrayWithCapacity: 1];
  [newApps addObject: currentApp];
  
  cells = [matrix cells];
  for(i = 0; i < [cells count]; i++)
    {
      app = [[cells objectAtIndex: i] title];
      if ([app isEqual: currentApp] == NO)
        {
          [newApps insertObject: app atIndex: [newApps count]];
        }
    }
  
  count = [newApps count];
  [matrix renewRows: 1 columns: count];
  
  for (i = 0; i < count; i++)
    {
      cell = [matrix cellAtRow: 0 column: i];
      app = [newApps objectAtIndex: i];
      [cell setTitle: app];
      node = [FSNode nodeWithPath: [ws fullPathForApplication: app]];
      icon = [[FSNodeRep sharedInstance] iconOfSize: ICNSIZE forNode: node];
      [cell setImage: icon];
    }

  [matrix scrollCellToVisibleAtRow: 0 column: 0];
  [matrix selectCellAtRow: 0 column: 0];
}

- (void)openFile:(id)sender
{
  NSInteger i;
  
  for (i = 0; i < [insppaths count]; i++)
    {
      NSString *fpath = [insppaths objectAtIndex: i];
        
      NS_DURING
        {
          [ws openFile: fpath withApplication: [[sender selectedCell] title]];
        }
      NS_HANDLER
        {
          NSRunAlertPanel(NSLocalizedString(@"error", @""), 
                          [NSString stringWithFormat: @"%@ %@!", 
                                    NSLocalizedString(@"Can't open ", @""), [fpath lastPathComponent]],
                          NSLocalizedString(@"OK", @""), 
                          nil, 
                          nil);                                     
        }
      NS_ENDHANDLER  
        }
}

- (void)watchedPathDidChange:(NSDictionary *)info
{
}

@end
