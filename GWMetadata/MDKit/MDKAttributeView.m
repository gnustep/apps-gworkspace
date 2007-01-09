/* MDKAttributeView.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
 * Date: December 2006
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
#include "MDKAttributeView.h"
#include "MDKAttribute.h"
#include "MDKAttributeEditor.h"
#include "MDKWindow.h"

static NSString *nibName = @"MDKAttributeView";

@implementation MDKAttributeView

- (void)dealloc
{
  RELEASE (mainBox);
  RELEASE (usedAttributesNames);
  RELEASE (otherstr);
  [super dealloc];
}
  
- (id)initInWindow:(MDKWindow *)awindow
{
	self = [super init];

  if (self) {
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSArray *attributes;
    NSString *impath;   
    NSImage *image; 
    int i;
  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }

    RETAIN (mainBox);
    RELEASE (win);

    impath = [bundle pathForResource: @"add" ofType: @"tiff"];
    image = [[NSImage alloc] initWithContentsOfFile: impath];
    [addButt setImage: image];
    RELEASE (image);
    
    impath = [bundle pathForResource: @"remove" ofType: @"tiff"];
    image = [[NSImage alloc] initWithContentsOfFile: impath];    
    [removeButt setImage: image];
    RELEASE (image);

    mdkwindow = awindow;
    attributes = [mdkwindow attributes];
    attribute = nil;

    usedAttributesNames = [NSMutableArray new];

    [popUp removeAllItems];

    for (i = 0; i < [attributes count]; i++) {
      MDKAttribute *attr = [attributes objectAtIndex: i];
      
      if ([attr inUse]) {
        [usedAttributesNames addObject: [attr name]];
      }
      
      [popUp addItemWithTitle: [attr menuName]];
    }
    
    ASSIGN (otherstr, NSLocalizedString(@"Other...", @""));
    [popUp addItemWithTitle: otherstr];
  }  
  
  return self;
}

- (NSBox *)mainBox
{
  return mainBox;
}

- (void)setAttribute:(MDKAttribute *)attr
{
  id editor;
  
  attribute = attr;
  editor = [attribute editor];
    
  if (editor) {
    [editorBox setContentView: [editor editorView]];
    [mdkwindow editorStateDidChange: editor];
  } else {
    NSLog(@"Missing editor for attribute %@", [attribute name]);
  }
    
  [popUp selectItemWithTitle: [attribute menuName]];
}

- (void)updateMenuForAttributes:(NSArray *)attributes
{
  unsigned i;

  [usedAttributesNames removeAllObjects];

  for (i = 0; i < [attributes count]; i++) {
    MDKAttribute *attr = [attributes objectAtIndex: i];

    if ([attr inUse] && (attr != attribute)) {
      [usedAttributesNames addObject: [attr name]];
    }
  }
  
  [[popUp menu] update];
  [popUp selectItemWithTitle: [attribute menuName]];  
}

- (void)attributesDidChange:(NSArray *)attributes
{
  unsigned i;
  
  [popUp removeAllItems];
  [usedAttributesNames removeAllObjects];
  
  for (i = 0; i < [attributes count]; i++) {
    MDKAttribute *attr = [attributes objectAtIndex: i];

    if ([attr inUse] && (attr != attribute)) {
      [usedAttributesNames addObject: [attr name]];
    }

    [popUp addItemWithTitle: [attr menuName]];
  }

  [popUp addItemWithTitle: otherstr];
  [[popUp menu] update];
  [popUp selectItemWithTitle: [attribute menuName]];  
}

- (void)setAddEnabled:(BOOL)value
{
  [addButt setEnabled: value];
}

- (void)setRemoveEnabled:(BOOL)value
{
  [removeButt setEnabled: value];
}

- (MDKAttribute *)attribute
{
  return attribute;
}

- (IBAction)popUpAction:(id)sender
{
  NSString *title = [sender titleOfSelectedItem];
  
  if ([title isEqual: [attribute menuName]] == NO) {
    if ([title isEqual: otherstr] == NO) {
      [mdkwindow attributeView: self changeAttributeTo: title];
    } else {
      [popUp selectItemWithTitle: [attribute menuName]];  
      [mdkwindow showAttributeChooser: self];
    }
  }
}

- (IBAction)buttonsAction:(id)sender
{
  if (sender == addButt) {
    [mdkwindow insertAttributeViewAfterView: self];
  } else {
    [mdkwindow removeAttributeView: self];
  }
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem 
{
  NSString *title = [anItem title];
  
  if ([title isEqual: otherstr]) {
    return YES;
  }
  
  if (attribute) {
    MDKAttribute *attr = [mdkwindow attributeWithMenuName: title];
    
    if ([usedAttributesNames containsObject: [attr name]]) {
      return NO;
    }
    
    return YES;
  }
  
  return NO;
}

@end







