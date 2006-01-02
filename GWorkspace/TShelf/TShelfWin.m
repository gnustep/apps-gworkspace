/* TShelfWin.m
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "TShelfWin.h"
#include "TShelfView.h"
#include "TShelfViewItem.h"
#include "TShelfIconsView.h"
#include "Dialogs/Dialogs.h"
#include "GNUstep.h"

#define SHELF_HEIGHT 106

@implementation TShelfWin

- (void)dealloc
{
  RELEASE (tView);
  
  [super dealloc];
}

- (id)init
{
  float sizew = [[NSScreen mainScreen] frame].size.width; 

  self = [super initWithContentRect: NSMakeRect(0, 0, sizew, SHELF_HEIGHT)
                          styleMask: NSBorderlessWindowMask 
                            backing: NSBackingStoreBuffered 
                              defer: NO];
  if (self) {
    NSUserDefaults *defaults;
    NSDictionary *tshelfDict;
    id entry;
    NSArray *tabsArr;    
		TShelfViewItem *item;
    TShelfIconsView *view;
    int i;
    
		[self setReleasedWhenClosed: NO];
        
    tView = [[TShelfView alloc] initWithFrame: [[self contentView] frame]];
    [self setContentView: tView];		
    
    defaults = [NSUserDefaults standardUserDefaults];	
        
    tshelfDict = [defaults objectForKey: @"tabshelf"];
    if (tshelfDict == nil) {
      tshelfDict = [NSDictionary dictionary];
    }
    
    entry = [tshelfDict objectForKey: @"auto_hide"];
    autohide = (entry && [entry boolValue]);
        
    tabsArr = [tshelfDict objectForKey: @"tabs"];
    
    if (tabsArr) {
      for (i = 0; i < [tabsArr count]; i++) {
        NSDictionary *dict = [tabsArr objectAtIndex: i];
        NSString *label = [[dict allKeys] objectAtIndex: 0];
        NSDictionary *tabDict = [dict objectForKey: label];
        NSArray *iconsArr = [tabDict objectForKey: @"icons"];
        NSNumber *iconsType = [tabDict objectForKey: @"iconstype"];
        int itype;
    
        if (iconsType) {
          itype = [iconsType intValue];
        } else {
          itype = FILES_TAB;
        }
    
        item = [[TShelfViewItem alloc] initWithTabType: itype];
        [item setLabel: label];
        
        view = [[TShelfIconsView alloc] initWithIconsDescription: iconsArr
                                                       iconsType: itype
                              lastView: ([label isEqual: @"last"] ? YES : NO)];
        [view setFrame: NSMakeRect(0, 0, sizew, 80)];    
        [item setView: view];
        RELEASE (view);
        
        if ([label isEqual: @"last"]) {
          [tView setLastTabItem: item];
        } else {
          [tView addTabItem: item];
        }
        
        RELEASE (item);
      }
      
    } else {
      item = [[TShelfViewItem alloc] initWithTabType: FILES_TAB];
      [item setLabel: @"last"];
      view = [[TShelfIconsView alloc] initWithIconsDescription: nil 
                                                     iconsType: FILES_TAB
                                                      lastView: YES];
      [view setFrame: NSMakeRect(0, 0, sizew, 80)];
      [item setView: view];
      RELEASE (view);
      [tView setLastTabItem: item];
      RELEASE (item);
      
      item = [[TShelfViewItem alloc] initWithTabType: FILES_TAB];
      [item setLabel: @"Tab1"];
      view = [[TShelfIconsView alloc] initWithIconsDescription: nil 
                                                     iconsType: FILES_TAB
                                                      lastView: NO];
      [view setFrame: NSMakeRect(0, 0, sizew, 80)];
      [item setView: view];
      RELEASE (view);
      [tView addTabItem: item];
      RELEASE (item);

      item = [[TShelfViewItem alloc] initWithTabType: DATA_TAB];
      [item setLabel: @"Pasteboard"];
      view = [[TShelfIconsView alloc] initWithIconsDescription: nil 
                                                     iconsType: DATA_TAB
                                                      lastView: NO];
      [view setFrame: NSMakeRect(0, 0, sizew, 80)];
      [item setView: view];
      RELEASE (view);
      [tView addTabItem: item];
      RELEASE (item);
      
      [self saveDefaults];
    }
  }
    
  return self;
}

- (TShelfView *)shelfView
{
  return tView;
}

- (void)activate
{
  [self makeKeyAndOrderFront: nil];
}

- (void)deactivate
{
  [self orderOut: nil];
}

- (void)animateShowing
{
  if (([self isVisible] == NO) || (autohide == NO)) {
    return;
  }

  if (autohidden) {
    int h = -SHELF_HEIGHT;
    int i;
    
    [self setFrameOrigin: NSMakePoint(0, h)];

    for (i = 0; i < 50; i++) {
      h += (int)(SHELF_HEIGHT / 50);
      [self setFrameOrigin: NSMakePoint(0, h)];
    }
    
    [self setFrameOrigin: NSMakePoint(0, 0)];
  }
  
  autohidden = NO;
}

- (void)animateHiding
{
  if (([self isVisible] == NO) || (autohide == NO)) {
    return;
  }

  if (autohidden == NO) {
    int h = 0;
    int i;

    [self setFrameOrigin: NSMakePoint(0, 0)];
    
    for (i = 0; i < 50; i++) {
      h -= (int)(SHELF_HEIGHT / 50);
      [self setFrameOrigin: NSMakePoint(0, h)];
    }
    
    [self setFrameOrigin: NSMakePoint(0, -SHELF_HEIGHT)];
  }
  
  autohidden = YES;
}

- (void)setAutohide:(BOOL)value
{
  autohide = value;
  if (autohide == NO) {
    [self setFrameOrigin: NSMakePoint(0, 0)];
    autohidden = NO;
  }
}

- (BOOL)autohide
{
  return autohide;
}

- (void)addTab
{
  SympleDialog *dialog;
  NSString *tabName;
  int itype;
  NSArray *items;
  TShelfViewItem *item;
  TShelfIconsView *view;
  BOOL duplicate;
  int result;
  int index;
  int i;
    
  if ([self isVisible] == NO) {
    return;
  }

	dialog = [[SympleDialog alloc] initWithTitle: NSLocalizedString(@"Add Tab", @"") 
                                      editText: @""
                                   switchTitle: NSLocalizedString(@"pasteboard tab", @"")];
  AUTORELEASE (dialog);
	[dialog center];
  [dialog makeKeyWindow];
  [dialog orderFrontRegardless];

  result = [dialog runModal];
	if (result != NSAlertDefaultReturn) {
    return;
  }  

  tabName = [dialog getEditFieldText];

  if ([tabName length] == 0) {
		NSString *msg = NSLocalizedString(@"No name supplied!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }

  items = [tView items];

  duplicate = NO;
  for (i = 0; i < [items count]; i++) {
    item = [items objectAtIndex: i];

    if ([[item label] isEqual: tabName]) {
      duplicate = YES;
      break;
    }
  }

  if (duplicate) {
		NSString *msg = NSLocalizedString(@"Duplicate tab name!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }
  
  itype = ([dialog switchButtState] == NSOnState) ? DATA_TAB : FILES_TAB;
  
  item = [tView selectedTabItem];
  index = [tView indexOfItem: item];
  
  item = [[TShelfViewItem alloc] initWithTabType: itype];
  [item setLabel: tabName];
  view = [[TShelfIconsView alloc] initWithIconsDescription: nil 
                                                 iconsType: itype
                                                  lastView: NO];
  [view setFrame: NSMakeRect(0, 0, [[NSScreen mainScreen] frame].size.width, 80)];
  [item setView: view];
  RELEASE (view);
  [tView insertTabItem: item atIndex: (index + 1)];
  [tView selectTabItem: item];  
  RELEASE (item);
  
  [self saveDefaults];
}

- (void)removeTab
{
  NSArray *items;
  TShelfViewItem *item;
	NSString *title, *msg, *buttstr;
  int index;
  int result;
    
  if ([self isVisible] == NO) {
    return;
  }

  items = [tView items];
  item = [tView selectedTabItem];
  index = [tView indexOfItem: item];
  
  if (([items count] == 1) || (item == [tView lastTabItem])) {
		msg = NSLocalizedString(@"You can't remove the last tab!", @"");
		buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }

	title = NSLocalizedString(@"Remove Tab", @"");
	msg = NSLocalizedString(@"Are you sure that you want to remove the selected tab?", @"");
	buttstr = NSLocalizedString(@"Continue", @"");
  result = NSRunAlertPanel(title, msg, 
                  NSLocalizedString(@"OK", @""), buttstr, NULL);
  if(result != NSAlertDefaultReturn) {
    return;
  }

  if ([tView removeTabItem: item] == NO) {
		msg = NSLocalizedString(@"You can't remove this tab!", @"");
		buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }
  
  [tView selectTabItem: [tView lastTabItem]];  
  
  [self saveDefaults];
}

- (void)renameTab
{
  SympleDialog *dialog;
  NSString *oldName;
  NSString *tabName;
  NSArray *items;
  TShelfViewItem *item;
  BOOL duplicate;
  int result;
  int index;
  int i;
    
  if ([self isVisible] == NO) {
    return;
  }

  items = [tView items];
  item = [tView selectedTabItem];
  oldName = [item label];
  index = [tView indexOfItem: item];

  if (item == [tView lastTabItem]) {
		NSString *msg = NSLocalizedString(@"You can't rename this tab!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }

	dialog = [[SympleDialog alloc] initWithTitle: NSLocalizedString(@"Rename Tab", @"") 
                                      editText: oldName
                                   switchTitle: nil];
  AUTORELEASE (dialog);
	[dialog center];
  [dialog makeKeyWindow];
  [dialog orderFrontRegardless];

  result = [dialog runModal];
	if(result != NSAlertDefaultReturn) {
    return;
  }  

  tabName = [dialog getEditFieldText];

  if ([tabName length] == 0) {
		NSString *msg = NSLocalizedString(@"No name supplied!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }

  duplicate = NO;
  for (i = 0; i < [items count]; i++) {
    TShelfViewItem *itm = [items objectAtIndex: i];

    if ([[itm label] isEqual: tabName]) {
      duplicate = YES;
      break;
    }
  }

  if (duplicate) {
		NSString *msg = NSLocalizedString(@"Duplicate tab name!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }
    
  [item setLabel: tabName];
  [tView selectTabItemAtIndex: index];  
  
  [self saveDefaults];
}

- (void)updateIcons
{
  NSArray *items = [tView items];
  int i;
  
  for (i = 0; i < [items count]; i++) {
    [(TShelfIconsView *)[[items objectAtIndex: i] view] updateIcons];
  }  
}

- (void)checkIconsAfterDotsFilesChange
{
  NSArray *items = [tView items];
  int i;
  
  for (i = 0; i < [items count]; i++) {
    TShelfViewItem *item = [items objectAtIndex: i];
    TShelfIconsView *iview = (TShelfIconsView *)[item view];

    [iview checkIconsAfterDotsFilesChange];
  }  
}

- (void)checkIconsAfterHidingOfPaths:(NSArray *)hpaths
{
  NSArray *items = [tView items];
  int i;
  
  for (i = 0; i < [items count]; i++) {
    TShelfViewItem *item = [items objectAtIndex: i];
    TShelfIconsView *iview = (TShelfIconsView *)[item view];

    [iview checkIconsAfterHidingOfPaths: hpaths];
  }  
}

- (void)saveDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  NSMutableDictionary *tshelfDict = [NSMutableDictionary dictionary];
  NSArray *items = [tView items];
  NSMutableArray *tabsArr = [NSMutableArray array];
  int i;

  for (i = 0; i < [items count]; i++) {
    TShelfViewItem *item = [items objectAtIndex: i];
    NSString *label = [item label];
    TShelfIconsView *iview = (TShelfIconsView *)[item view];
    NSArray *iconsArr = [iview iconsDescription];
    NSNumber *iconsType = [NSNumber numberWithInt: [iview iconsType]];
    NSMutableDictionary *tdict = [NSMutableDictionary dictionary];
    
    [tdict setObject: iconsArr forKey: @"icons"];
    [tdict setObject: iconsType forKey: @"iconstype"];
             
    [tabsArr addObject: [NSDictionary dictionaryWithObject: tdict forKey: label]];
  }

  [tshelfDict setObject: tabsArr forKey: @"tabs"];

  [tshelfDict setObject: [NSNumber numberWithBool: autohide]
                 forKey: @"auto_hide"];

  [defaults setObject: tshelfDict forKey: @"tabshelf"];
}

- (BOOL)canBecomeKeyWindow
{
	return YES;
}

- (BOOL)canBecomeMainWindow
{
	return YES;
}

@end
