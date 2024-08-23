/* FindModuleView.m
 *  
 * Copyright (C) 2004-2010 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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
#import "FindModuleView.h"
#import "Finder.h"
#import "LSFEditor.h"
#import "FinderModulesProtocol.h"

static NSString *nibName = @"FindModuleView";

@implementation FindModuleView

- (void)dealloc
{
  RELEASE (mainBox);
  RELEASE (usedModulesNames);
  [super dealloc];
}

- (id)initWithDelegate:(id)anobject 
{
	self = [super init];

  if (self) {
    NSArray *modules;
    int i;
    
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }

    RETAIN (mainBox);
    RELEASE (win);
    
    [removeButt setImage: [NSImage imageNamed: @"remove"]];
    [addButt setImage: [NSImage imageNamed: @"add"]];
    
    delegate = anobject;
    modules = [delegate modules];
    module = nil;
    
    usedModulesNames = [NSMutableArray new];
    
    [popUp removeAllItems];
    for (i = 0; i < [modules count]; i++) {
      id mdl = [modules objectAtIndex: i];
      NSString *mname = [mdl moduleName];
      
      if ([mdl used]) {
        [usedModulesNames addObject: mname];
      }
      
      [popUp insertItemWithTitle: mname atIndex: i];
    }
  }
  
	return self;
}

- (NSBox *)mainBox
{
  return mainBox;
}

- (void)setModule:(id)mdl
{
  module = mdl;
  [moduleBox setContentView: [module controls]];
  [popUp selectItemWithTitle: [mdl moduleName]];  
}

- (void)updateMenuForModules:(NSArray *)modules
{
  int i;

  [usedModulesNames removeAllObjects];
  
  for (i = 0; i < [modules count]; i++) {
    id mdl = [modules objectAtIndex: i];
    NSString *mname = [mdl moduleName];

    if ([mdl used] && (mdl != module)) {
      [usedModulesNames addObject: mname];
    }
  }
  
  [[popUp menu] update];
  [popUp selectItemWithTitle: [module moduleName]];  
}

- (void)setAddEnabled:(BOOL)value
{
  [addButt setEnabled: value];
}

- (void)setRemoveEnabled:(BOOL)value
{
  [removeButt setEnabled: value];
}

- (id)module
{
  return module;
}

- (IBAction)popUpAction:(id)sender
{
  NSString *title = [sender titleOfSelectedItem];
  
  if ([title isEqual: [module moduleName]] == NO) {
    [delegate findModuleView: self changeModuleTo: title];
  }
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem 
{
  if (module == nil) {
    return NO;
  }

  if ([usedModulesNames containsObject: [anItem title]]) {
    return NO;
  }
  
  return YES;
}

- (IBAction)buttonsAction:(id)sender
{
  if (sender == addButt) {
    [delegate addModule: self];
  } else {
    [delegate removeModule: self];
  }
}

@end
