/* RemoteEditorView.m
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "GNUstep.h"
#include "GWRemote.h"
#include <GWorkspace/GWNotifications.h>
#include "RemoteEditorView.h"
#include "RemoteEditor.h"
#include "Functions.h"

static NSString *nibName = @"FindWindow";

@implementation RemoteEditorView

- (void) dealloc
{
  TEST_RELEASE (findWin);
  RELEASE (fontDict);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frame inEditor:(RemoteEditor *)anEditor
{
  self = [super initWithFrame: frame];
  
  if (self) {
    NSFont *font;
    NSSize size;

		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      return nil;
    } 

    if ([findWin setFrameUsingName: @"findWindow"] == NO) {
      [findWin setFrame: NSMakeRect(200, 200, 209, 99) display: NO];
    }
    [findWin setDelegate: self];  
    
    [self setString: @""];
    [self setSelectedRange: NSMakeRange(0, 0)];
    
    [self setRichText: NO];
    [self setImportsGraphics: NO];
    [self setUsesFontPanel: NO];
    [self setUsesRuler: NO];
    [self setEditable: YES];
    [self setAllowsUndo: YES];
    [self setMinSize: NSMakeSize(0,0)];
    [self setMaxSize: NSMakeSize(1e7, 1e7)];
    [self setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
    [self setVerticallyResizable: YES];
    [self setHorizontallyResizable: NO];
  
    size = NSMakeSize([self frame].size.width, 1e7);
    [[self textContainer] setContainerSize: size];
    [[self textContainer] setWidthTracksTextView: YES];
        
    font = [NSFont userFixedPitchFontOfSize: 12];
    fontDict = [[NSDictionary alloc] initWithObjects: 
                          [NSArray arrayWithObject: font] 
                     forKeys: [NSArray arrayWithObject: NSFontAttributeName]];
    
    editor = anEditor;
    edited = NO;
  }
    
  return self;
}

- (void)setStringToEdit:(NSString *)string
{
  [self setString: string];
  
  if ([string length]) {
    [[self textStorage] setAttributes: fontDict
                                range: NSMakeRange(0, [string length])];
    [self setSelectedRange: NSMakeRange(0, 0)];
  }
  [[self textStorage] setDelegate: self]; 
  edited = NO;      
}

- (NSString *)editedString
{
  return nil;
}

- (BOOL)isEdited
{
  return edited;
}

- (void)saveRemoteFile:(id)sender
{
  if ([editor trySave]) {
    edited = NO;
  } 
}

- (void)textStorageDidProcessEditing:(NSNotification *)not
{
  if (edited == NO) {
    edited = YES;
    [editor setEdited];
  }
}

- (void)showFindWin:(id)sender
{
  [findWin makeKeyAndOrderFront: nil];
}

- (IBAction)Find:(id)sender
{
  NSString *toFind = [findField stringValue];
  
  if (toFind && [toFind length]) {
    NSRange cursor, range;
    cursor = [self selectedRange];

    if (cursor.location == NSNotFound) {
      cursor = NSMakeRange(0, [[self textStorage] length]);
    } else {
      cursor = NSMakeRange(cursor.location + cursor.length, 
         [[self textStorage] length] - (cursor.location + cursor.length));
    }

    range = [[self string] rangeOfString: toFind 
                                 options: NSCaseInsensitiveSearch
                                   range: cursor];
                                
    if (range.location == NSNotFound) {
      NSBeep();
      return;  
    }
  
    [self setSelectedRange: range];
    [self scrollRangeToVisible: range];
    
  } else {
    NSBeep();
  }
}

- (BOOL)windowShouldClose:(id)sender
{
  [findWin saveFrameUsingName: @"findWindow"];
  return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem 
{	
  NSString *title = [anItem title];
	
  if ([title isEqual: NSLocalizedString(@"Save Remote File", @"")]) {
    return edited;
  }

  if ([title isEqual: NSLocalizedString(@"Find...", @"")]) {
    return YES;
  }
  
	return NO;
}

@end
