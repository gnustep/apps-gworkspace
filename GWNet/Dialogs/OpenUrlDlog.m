/* OpenUrlDlog.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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
#include "OpenUrlDlog.h"
#include "GWNet.h"
#include "GWNetFunctions.h"
#include "GNUstep.h"

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

static NSString *nibName1 = @"OpenUrlDialog";
static NSString *nibName2 = @"LoginWin";

@implementation OpenUrlDlog

- (void)dealloc
{
  RELEASE (win);
  RELEASE (urlsMatrix);

  [super dealloc];
}

- (id)init
{
	self = [super init];
  
  if(self) {
    NSUserDefaults *defaults;		
    NSArray *urls;	
    NSSize ms, cs;
    int i;
    
		if ([NSBundle loadNibNamed: nibName1 owner: self] == NO) {
      NSLog(@"OpenUrlDlog: failed to load %@!", nibName1);
      RELEASE (self);
      return nil;
    } 
		if ([NSBundle loadNibNamed: nibName2 owner: self] == NO) {
      NSLog(@"OpenUrlDlog: failed to load %@!", nibName2);
      RELEASE (self);
      return nil;
    } 

    if ([win setFrameUsingName: @"openurldlog"] == NO) {
      NSRect r = [win frame];
      r.origin.x = 300;
      r.origin.y = 300;
      [win setFrame: r display: NO];
    }
    [win setDelegate: self];  
    [win makeFirstResponder: urlField];
    
    [loginWin setDelegate: self];  

    [addButt setImage: [NSImage imageNamed: @"addurl.tiff"]];

    [scroll setBorderType: NSBezelBorder];
		[scroll setHasHorizontalScroller: NO];
  	[scroll setHasVerticalScroller: YES]; 

    urlsMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				                                    mode: NSRadioModeMatrix 
                                  prototype: [[NSBrowserCell new] autorelease]
			       											       numberOfRows: 0 numberOfColumns: 0];
    [urlsMatrix setAutoresizingMask: NSViewWidthSizable];
    [urlsMatrix setTarget: self];
    [urlsMatrix setAction: @selector(matrixAction:)];
    [urlsMatrix setDoubleAction: @selector(okAction:)];
    [urlsMatrix setIntercellSpacing: NSZeroSize];
    [urlsMatrix setCellSize: NSMakeSize(130, 16)];
    [urlsMatrix setAutoscroll: YES];
	  [urlsMatrix setAllowsEmptySelection: NO];
    cs = [scroll contentSize];
    ms = [urlsMatrix cellSize];
    ms.width = cs.width;
    CHECKSIZE (ms);
    [urlsMatrix setCellSize: ms];
	  [scroll setDocumentView: urlsMatrix];	

    defaults = [NSUserDefaults standardUserDefaults];		
    urls = [defaults objectForKey: @"urls"];
    
    if (urls && [urls count]) {
      [urlsMatrix addColumn];
      
      for (i = 0; i < [urls count]; i++) {
        NSString *url = [urls objectAtIndex: i];
        id cell;

        if (i != 0) {
		      [urlsMatrix insertRow: i];
        }
        cell = [urlsMatrix cellAtRow: i column: 0];   
        [cell setStringValue: url];
        [cell setLeaf: YES];
      }
      
      [urlsMatrix sizeToCells]; 
      [urlsMatrix sendAction]; 
    }
    
    gwnet = [GWNet gwnet];

    /* Internationalization */
    [urlLabel setStringValue: NSLocalizedString(@"address", @"")];
    [buttRemove setTitle: NSLocalizedString(@"Remove", @"")];
    [buttCancel setTitle: NSLocalizedString(@"Cancel", @"")];
    [buttOk setTitle: NSLocalizedString(@"Ok", @"")];
    [userLabel setStringValue: NSLocalizedString(@"user", @"")];
    [passwdLabel setStringValue: NSLocalizedString(@"password", @"")];   
    [buttCancelLogin setTitle: NSLocalizedString(@"Cancel", @"")];
    [buttOkLogin setTitle: NSLocalizedString(@"Login", @"")];
	}

	return self;
}

- (void)chooseUrl
{
  [urlField setStringValue: @""];
  [win makeKeyAndOrderFront: nil];
  if ([urlsMatrix selectedCell]) {
    [urlsMatrix sendAction];
  }
}

- (int)runLoginDialogForHost:(NSString *)hostname
{
  [loginWin setTitle: [NSString stringWithFormat: @"%@ login", hostname]];
  [loginWin makeFirstResponder: buttOkLogin];
  [buttOkLogin setNextKeyView: buttCancelLogin];
  [buttCancelLogin setNextKeyView: userField];
  [userField setNextKeyView: passwdField];
  [passwdField setNextKeyView: buttOkLogin];
  [userField setStringValue: @""];
//  [passwdField setStringValue: @""];
  [NSApp runModalForWindow: loginWin];
  return result;
}

- (NSString *)username
{
  return [userField stringValue];
}

- (NSString *)password
{
  return [passwdField stringValue];
}

- (IBAction)addButtAction:(id)sender
{
  NSString *urlstr = [urlField stringValue];

  if ([urlstr length] > 0) {
    NSArray *cells = [urlsMatrix cells];
    BOOL found = NO;
    int count = 0;
    id cell;
    int i;

    if (cells) {
      count = [cells count];
      
      for (i = 0; i < count; i++) {
        cell = [cells objectAtIndex: i];
        
        if ([[cell stringValue] isEqual: urlstr]) {
          found = YES;
          break;
        }
      }
    }
    
    if (found == NO) {
      if (cells && count) {
        [urlsMatrix insertRow: count];
      } else {
        [urlsMatrix addColumn];
      }
      
      cell = [urlsMatrix cellAtRow: count column: 0];   
      [cell setStringValue: urlstr];
      [cell setLeaf: YES];
      [urlsMatrix sizeToCells]; 
      [urlsMatrix sendAction];
      [self updateDefaults];
    }
  }
}

- (void)matrixAction:(id)sender
{
  id cell = [urlsMatrix selectedCell];
  
  if (cell) {
    [urlField setStringValue: [cell stringValue]];
  }  
}

- (IBAction)removeAction:(id)sender
{
  id cell = [urlsMatrix selectedCell];
    
  if (cell) {
    if ([[urlsMatrix cells] count] == 1) {
      [urlsMatrix removeColumn: 0];
    } else {
      int row, col;
      [urlsMatrix getRow: &row column: &col ofCell: cell];
      [urlsMatrix removeRow: row];
    }
  
    [urlsMatrix sizeToCells]; 
    [urlsMatrix sendAction];
    [self updateDefaults];
  }    
}

- (IBAction)cancelAction:(id)sender
{
  [win performClose: nil];
}

- (IBAction)okAction:(id)sender
{
  NSString *urlstr = [urlField stringValue];

  if ([urlstr length] > 0) {
    NSURL *url = [NSURL URLWithString: urlstr];
    
    if (url && ([url isFileURL] == NO) && [url host] && [url scheme]) {
      [win performClose: nil];
      [gwnet newViewerForUrl: url withSelectedPaths: nil preContents: nil];
    } else {
      NSRunAlertPanel(NULL, NSLocalizedString(@"Invalid URL", @""),
                          NSLocalizedString(@"Ok", @""), NULL, NULL);   
    }
  } else {
    NSRunAlertPanel(NULL, NSLocalizedString(@"Invalid URL", @""),
                        NSLocalizedString(@"Ok", @""), NULL, NULL);   
  }
}

- (IBAction)cancelLoginAction:(id)sender
{
  result = NSAlertAlternateReturn;
  [NSApp stopModal];
  [loginWin close];
}

- (IBAction)okLoginAction:(id)sender
{
  result = NSAlertDefaultReturn;
  [NSApp stopModal];
  [loginWin close];
}

- (id)urlsWin
{
  return win;
}

- (id)loginWin
{
  return loginWin;
}

- (void)updateDefaults
{
  NSArray *cells = [urlsMatrix cells];
  
  if (cells && [cells count]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    NSMutableArray *urls = [NSMutableArray array];
    int i;

    for (i = 0; i < [cells count]; i++) {
      [urls addObject: [[cells objectAtIndex: i] stringValue]];
    }
    [defaults setObject: urls forKey: @"urls"];
    [defaults synchronize];
  }
   	
  [win saveFrameUsingName: @"openurldlog"];
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}

@end
