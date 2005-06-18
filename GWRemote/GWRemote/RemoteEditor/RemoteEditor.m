/* RemoteEditor.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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
#include "GNUstep.h"
#include "GWRemote.h"
#include "RemoteEditor.h"
#include "RemoteEditorView.h"
#include "Functions.h"
#include "Notifications.h"

static NSString *nibName = @"RemoteEditor";

@implementation RemoteEditor

- (void)dealloc
{
  TEST_RELEASE (win);
  TEST_RELEASE (editorView);
  TEST_RELEASE (serverName);
  TEST_RELEASE (filePath);
  TEST_RELEASE (fileName);
  
  [super dealloc];
}

- (id)initForEditFile:(NSString *)filepath
         withContents:(NSString *)contents
         onRemoteHost:(NSString *)hostname
{
  self = [super init];
  
  if (self) {  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
      NSRect rect;
      
      if ([win setFrameUsingName: @"remoteEditor"] == NO) {
        [win setFrame: NSMakeRect(200, 200, 600, 400) display: NO];
      }

      [win setDelegate: self];  
      [scrollView setBorderType: NSBezelBorder];
      [scrollView setHasVerticalScroller: YES];      
      [scrollView setHasHorizontalScroller: YES];  
  
      rect = [[scrollView contentView] frame];
      editorView = [[RemoteEditorView alloc] initWithFrame: rect inEditor: self];
      [scrollView setDocumentView: editorView];
      
      gwremote = [GWRemote gwremote];
      
      ASSIGN (filePath, filepath);
      ASSIGN (fileName, [filepath lastPathComponent]);
      ASSIGN (serverName, hostname);
      
      [win setTitle: [NSString stringWithFormat: @"%@ - %@", serverName, fileName]];
      [win makeKeyAndOrderFront: nil];
      
      [editorView setStringToEdit: contents];
    }    
  }
  
  return self;    
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
}

- (void)setEdited
{
  [win setTitle: [NSString stringWithFormat: @"%@ - %@ - unsaved", serverName, fileName]];
}

- (BOOL)isEdited
{
  return [editorView isEdited];
}

- (BOOL)trySave
{
  if ([gwremote editor: self didEditContents: [editorView string]
                        ofFile: filePath onRemoteHost: serverName]) {
    [win setTitle: [NSString stringWithFormat: @"%@ - %@", serverName, fileName]];
    return YES;
  }
  
  return NO;
}

- (NSString *)serverName
{
  return serverName;
}

- (NSString *)filePath
{
  return filePath;
}

- (BOOL)windowShouldClose:(id)sender
{
	if ([editorView isEdited]) {
		unsigned result = NSRunAlertPanel(NSLocalizedString(@"Alert", @""),
				        [NSString stringWithFormat: @"%@ %@",
fileName, NSLocalizedString(@"is not saved! Do you want to save it?", @"")], 
								NSLocalizedString(@"Ok", @""), 
                NSLocalizedString(@"No", @""), 
                NSLocalizedString(@"Cancel", @""));
                
		if (result == NSAlertDefaultReturn) {
      [win saveFrameUsingName: @"remoteEditor"];
			return [self trySave];

		} else if(result == NSAlertAlternateReturn) {
      [gwremote remoteEditorHasClosed: self]; 
      [win saveFrameUsingName: @"remoteEditor"];
			return YES;

		} else if(result == NSAlertOtherReturn) {
			return NO;
		}
  } 
  
  [gwremote remoteEditorHasClosed: self]; 

  return YES;
}

@end
