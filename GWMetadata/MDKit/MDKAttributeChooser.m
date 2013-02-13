/* MDKAttributeChooser.m
 *  
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

#import "MDKAttributeChooser.h"
#import "MDKWindow.h"
#import "MDKAttribute.h"
#import "MDKAttributeView.h"
#import "MDKQuery.h"

static NSString *nibName = @"MDKAttributeChooser";

@implementation MDKAttributeChooser

- (void)dealloc
{
  RELEASE (win);
  RELEASE (mdkattributes);    
  [super dealloc];
}

- (id)initForWindow:(MDKWindow *)awindow
{
  self = [super init];
  
  if (self) {
    NSDictionary *attrdict;
    NSArray *names;
    id cell;
    float fonth;
    unsigned i;
    
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }

    mdkwindow = awindow;
    mdkattributes = [NSMutableArray new];
    attrdict = [MDKQuery attributesWithMask: MDKAttributeSearchable];
    names = [[attrdict allKeys] sortedArrayUsingSelector: @selector(compare:)];
    
    cell = [NSBrowserCell new];
    fonth = [[cell font] defaultLineHeightForFont];

    menuNamesMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            	              mode: NSRadioModeMatrix 
                               prototype: cell
			       							  numberOfRows: 0 
                         numberOfColumns: 0];
    RELEASE (cell);                     

    [menuNamesMatrix setIntercellSpacing: NSZeroSize];
    [menuNamesMatrix setCellSize: NSMakeSize([menuNamesScroll contentSize].width, fonth)];
    [menuNamesMatrix setAutoscroll: YES];
	  [menuNamesMatrix setAllowsEmptySelection: YES];
    [menuNamesMatrix setTarget: self]; 
    [menuNamesMatrix setAction: @selector(menuNamesMatrixAction:)]; 
    [menuNamesScroll setBorderType: NSBezelBorder];
    [menuNamesScroll setHasHorizontalScroller: NO];
    [menuNamesScroll setHasVerticalScroller: YES]; 
    [menuNamesScroll setDocumentView: menuNamesMatrix];	
    RELEASE (menuNamesMatrix);
    
    for (i = 0; i < [names count]; i++) {
      NSDictionary *info = [attrdict objectForKey: [names objectAtIndex: i]];
      MDKAttribute *attribute = [[MDKAttribute alloc] initWithAttributeInfo: info
                                                                  forWindow: mdkwindow];
      NSString *menuname = [attribute menuName];
      unsigned count = [[menuNamesMatrix cells] count];
      
      [menuNamesMatrix insertRow: count];
      cell = [menuNamesMatrix cellAtRow: count column: 0];
      [cell setStringValue: menuname];
      [cell setLeaf: YES];        

      [mdkattributes addObject: attribute]; 
      RELEASE (attribute);
    }
    
    [menuNamesMatrix sizeToCells]; 
    
    [nameLabel setStringValue: NSLocalizedString(@"name", @"")];
    [typeLabel setStringValue: NSLocalizedString(@"type", @"")];
    [typeDescrLabel setStringValue: NSLocalizedString(@"type description", @"")];
    [descriptionLabel setStringValue: NSLocalizedString(@"description", @"")];    
    [descriptionView setDrawsBackground: NO];
    [cancelButt setTitle: NSLocalizedString(@"Cancel", @"")];
    [okButt setTitle: NSLocalizedString(@"OK", @"")];
  
    [okButt setEnabled: NO];
    
    choosenAttr = nil;
    attrView = nil;
  }

  return self;
}

- (MDKAttribute *)chooseNewAttributeForView:(MDKAttributeView *)aview
{
  attrView = aview;
  [NSApp runModalForWindow: win];
  return choosenAttr;
}

- (MDKAttribute *)attributeWithMenuName:(NSString *)mname
{
  int i;
  
  for (i = 0; i < [mdkattributes count]; i++) {
    MDKAttribute *attribute = [mdkattributes objectAtIndex: i];
    
    if ([[attribute menuName] isEqual: mname]) {
      return attribute;
    }
  }
 
  return nil;
}

- (void)menuNamesMatrixAction:(id)sender
{
  id cell = [menuNamesMatrix selectedCell];  

  if (cell) {
    NSArray *winattrs = [mdkwindow attributes];
    MDKAttribute *attr = [self attributeWithMenuName: [cell stringValue]];
    int type = [attr type];
    NSString *typestr;
    
    [nameField setStringValue: [attr name]];
    
    switch (type) {
      case STRING:
        typestr = @"NSString";
        break;
      case ARRAY:
        typestr = @"NSArray";
        break;
      case NUMBER:
        typestr = @"NSNumber";
        break;
      case DATE_TYPE:
        typestr = @"NSDate";
        break;
      case DATA:
        typestr = @"NSData";
        break;        
      default:
        typestr = @"";
        break;
    }
    
    [typeField setStringValue: typestr];  
    [typeDescrField setStringValue: [attr typeDescription]];        
    [descriptionView setString: [attr description]];
    
    [okButt setEnabled: ([winattrs containsObject: attr] == NO)];
  }
}

- (IBAction)buttonsAction:(id)sender
{
  if (sender == okButt) {
    id cell = [menuNamesMatrix selectedCell];
    
    if (cell) {
      choosenAttr = [self attributeWithMenuName: [cell stringValue]];
    } else {
      choosenAttr = nil;
    }
  } else {
    choosenAttr = nil;
  }
  
  [menuNamesMatrix deselectAllCells];
  [okButt setEnabled: NO];
  [NSApp stopModal];
  [win close];
}

@end

