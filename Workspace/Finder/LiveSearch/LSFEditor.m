/* LSFEditor.m
 *  
 * Copyright (C) 2005-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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

#import <AppKit/AppKit.h>
#import "LSFEditor.h"
#import "LSFolder.h"
#import "FindModuleView.h"
#import "FinderModulesProtocol.h"
#import "Finder.h"
#import "SearchPlacesCell.h"
#import "GWFunctions.h"

#define WINH (186.0)
#define FMVIEWH (34.0)
#define BORDER (4.0)
#define HMARGIN (12.0)

#define CELLS_HEIGHT (28.0)
#define ICON_SIZE NSMakeSize(24.0, 24.0)

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

static NSString *nibName = @"LSFEditor";

@implementation LSFEditor

- (void)dealloc
{
  RELEASE (modules);
  RELEASE (fmviews);

	[super dealloc];
}

- (id)initForFolder:(id)fldr
{
	self = [super init];

  if (self) {
    NSDictionary *sizesDict;
    NSArray *searchPaths;
    SEL compareSel;
    NSSize cs, ms;
    NSUInteger i;
    
    folder = fldr;
    finder = [Finder finder];
    
    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }

    [win setTitle: [[folder node] name]];    
    [win setDelegate: self];
           
    sizesDict = [folder getSizes];      
           
    if (sizesDict) {
      id entry = [sizesDict objectForKey: @"editor_win"];
      
      if (entry) {
        [win setFrameFromString: entry];
      }
    }        

    [placesScroll setBorderType: NSBezelBorder];
    [placesScroll setHasHorizontalScroller: NO];
    [placesScroll setHasVerticalScroller: YES]; 

    placesMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
				            	              mode: NSListModeMatrix 
                               prototype: [[SearchPlacesCell new] autorelease]
			       							  numberOfRows: 0 
                         numberOfColumns: 0];
    [placesMatrix setIntercellSpacing: NSZeroSize];
    [placesMatrix setCellSize: NSMakeSize(1, CELLS_HEIGHT)];
    [placesMatrix setAutoscroll: YES];
	  [placesMatrix setAllowsEmptySelection: YES];
    cs = [placesScroll contentSize];
    ms = [placesMatrix cellSize];
    ms.width = cs.width;
    CHECKSIZE (ms);
    [placesMatrix setCellSize: ms];
	  [placesScroll setDocumentView: placesMatrix];	
    RELEASE (placesMatrix);

    searchPaths = [folder searchPaths];

    for (i = 0; i < [searchPaths count]; i++) {
      int count = [[placesMatrix cells] count];
      FSNode *node = [FSNode nodeWithPath: [searchPaths objectAtIndex: i]];
      SearchPlacesCell *cell;

      [placesMatrix insertRow: count];
      cell = [placesMatrix cellAtRow: count column: 0];   
      [cell setNode: node];
      [cell setLeaf: YES]; 
      [cell setIcon];
    }

    compareSel = [[FSNodeRep sharedInstance] defaultCompareSelector];
    [placesMatrix sortUsingSelector: compareSel];
    [placesMatrix setCellSize: NSMakeSize([placesScroll contentSize].width, CELLS_HEIGHT)];  
    [placesMatrix sizeToCells];

    [recursiveSwitch setState: ([folder recursive] ? NSOnState : NSOffState)];

    [searchLabel setStringValue: NSLocalizedString(@"Searching in:", @"")];
    [modulesLabel setStringValue: NSLocalizedString(@"Modules:", @"")];
    [recursiveSwitch setStringValue: NSLocalizedString(@"recursive", @"")];

    fmviews = [NSMutableArray new];

    [self setModules];
  }
  
	return self;
}

- (void)setModules
{
  CREATE_AUTORELEASE_POOL(arp);
  NSArray *fmods = [finder modules];
  NSDictionary *searchCriteria = [folder searchCriteria];
  NSArray *names = [searchCriteria allKeys];
  NSArray *usedModules;
  NSUInteger i;

  while ([fmviews count] > 0) {
    FindModuleView *view = [fmviews objectAtIndex: 0];

    [[view mainBox] removeFromSuperview];
    [fmviews removeObject: view];
  }
  
  DESTROY (modules);
  modules = [NSMutableArray new];
  
  for (i = 0; i < [fmods count]; i++) {
    Class mclass = [[fmods objectAtIndex: i] class];
    NSString *cname = NSStringFromClass(mclass);
    id module = [[mclass alloc] initInterface];
    
    if ([names containsObject: cname]) {
      [module setControlsState: [searchCriteria objectForKey: cname]];
      [module setInUse: YES];
    } else {
      [module setInUse: NO];  
    }
    
    [modules addObject: module];
    RELEASE (module);
  }
  
  usedModules = [self usedModules];
 
  for (i = 0; i < [usedModules count]; i++) {
    id module = [usedModules objectAtIndex: i];
    id fmview = [[FindModuleView alloc] initWithDelegate: self];

    [fmview setModule: module];

    if ([usedModules count] == [modules count]) {
      [fmview setAddEnabled: NO];    
    }

    [[modulesBox contentView] addSubview: [fmview mainBox]];
    [fmviews insertObject: fmview atIndex: [fmviews count]];
    RELEASE (fmview);
  }

  RELEASE (arp);
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
  [self tile];
}

- (NSArray *)modules
{
  return modules;
}

- (NSArray *)usedModules
{
  NSMutableArray *used = [NSMutableArray array];
  NSUInteger i;

  for (i = 0; i < [modules count]; i++) {
    id module = [modules objectAtIndex: i];
    
    if ([module used]) {
      [used addObject: module];
    }
  }
 
  return used;
}

- (id)firstUnusedModule
{
  NSUInteger i;
  
  for (i = 0; i < [modules count]; i++) {
    id module = [modules objectAtIndex: i];
    
    if ([module used] == NO) {
      return module;
    }
  }
 
  return nil;
}

- (id)moduleWithName:(NSString *)mname
{
  int i;
  
  for (i = 0; i < [modules count]; i++) {
    id module = [modules objectAtIndex: i];
    
    if ([[module moduleName] isEqual: mname]) {
      return module;
    }
  }
 
  return nil;
}

- (void)addModule:(FindModuleView *)aview
{
  NSArray *usedModules = [self usedModules];

  if ([usedModules count] < [modules count]) {
    NSUInteger index = [fmviews indexOfObjectIdenticalTo: aview];  
    id module = [self firstUnusedModule];
    id fmview = [[FindModuleView alloc] initWithDelegate: self];
    NSUInteger count;
    NSUInteger i;
    
    [module setInUse: YES];
    [fmview setModule: module];

    [[modulesBox contentView] addSubview: [fmview mainBox]];
    [fmviews insertObject: fmview atIndex: index + 1];
    RELEASE (fmview);
    
    count = [fmviews count];
    
    for (i = 0; i < count; i++) {
      fmview = [fmviews objectAtIndex: i];

      [fmview updateMenuForModules: modules];
      
      if (count == [modules count]) {
        [fmview setAddEnabled: NO]; 
      }
      
      if (count > 1) {
        [fmview setRemoveEnabled: YES]; 
      }
    }

    [self tile];
  }
}

- (void)removeModule:(FindModuleView *)aview
{
  if ([fmviews count] > 1) {
    int count;
    int i;

    [[aview module] setInUse: NO];
    [[aview mainBox] removeFromSuperview];
    [fmviews removeObject: aview];
    
    count = [fmviews count];
    
    for (i = 0; i < count; i++) {
      id fmview = [fmviews objectAtIndex: i];
      
      [fmview updateMenuForModules: modules];
      [fmview setAddEnabled: YES]; 
      
      if (count == 1) {
        [fmview setRemoveEnabled: NO]; 
      }
    }
    
    [self tile];
  }
}

- (void)findModuleView:(FindModuleView *)aview 
        changeModuleTo:(NSString *)mname
{
  id module = [self moduleWithName: mname];

  if (module && ([aview module] != module)) {
    int i;

    [[aview module] setInUse: NO];
    [module setInUse: YES];
    [aview setModule: module];
    
    for (i = 0; i < [fmviews count]; i++) {
      [[fmviews objectAtIndex: i] updateMenuForModules: modules];
    }    
  }
}

- (IBAction)buttonsAction:(id)sender
{
  if (sender == cancelButt) {
    [self setModules];
    [self tile];
    
  } else {
    NSMutableDictionary *criteria = [NSMutableDictionary dictionary];
    int i;  
  
    for (i = 0; i < [fmviews count]; i++) {
      id module = [[fmviews objectAtIndex: i] module]; 
      NSDictionary *dict = [module searchCriteria];
      
      if (dict) {
        [criteria setObject: dict forKey: NSStringFromClass([module class])];
      }
    }
    
    if ([criteria count]) {
      [folder setSearchCriteria: criteria 
                      recursive: ([recursiveSwitch state] == NSOnState)];
    }
  }
}

- (void)tile
{
  NSRect wrect = [win frame];
  NSRect mbrect = [modulesBox bounds];
  int count = [fmviews count];
  float hspace = (count * FMVIEWH) + HMARGIN + BORDER;
  int i;
    
  if (mbrect.size.height != hspace) {  
    if (wrect.size.height != WINH) {
      wrect.origin.y -= (hspace - mbrect.size.height);
    } 
    wrect.size.height += (hspace - mbrect.size.height);
    [win setFrame: wrect display: NO];
  }

  mbrect = [modulesBox bounds];
  
  for (i = 0; i < count; i++) {  
    FindModuleView *fmview = [fmviews objectAtIndex: i];
    NSBox *fmbox = [fmview mainBox];
    NSRect mbr = [fmbox frame];
    float posy = mbrect.size.height - (FMVIEWH * (i + 1)) - BORDER;
    
    if (mbr.origin.y != posy) {
      mbr.origin.y = posy;
      [fmbox setFrame: mbr];
    }
  }
}

- (NSWindow *)win
{
  return win;
}

//
// NSWindow delegate
//
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
}

- (BOOL)windowShouldClose:(id)sender
{
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  [folder saveSizes];
}

@end
