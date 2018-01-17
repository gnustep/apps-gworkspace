/* Finder.m
 *  
 * Copyright (C) 2005-2018 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Finder.h"
#import "FinderModulesProtocol.h"
#import "FindModuleView.h"
#import "SearchPlacesBox.h"
#import "SearchPlacesCell.h"
#import "SearchResults.h"
#import "LSFolder.h"
#import "FSNodeRep.h"
#import "GWorkspace.h"
#import "GWFunctions.h"

#define WINH (262.0)
#define FMVIEWH (34.0)
#define BORDER (4.0)
#define HMARGIN (12.0)

#define SELECTION 0
#define PLACES 1

#define CELLS_HEIGHT (28.0)

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

static NSString *nibName = @"Finder";

static Finder *finder = nil;

@implementation Finder

+ (Finder *)finder
{
	if (finder == nil) {
		finder = [[Finder alloc] init];
	}	
  return finder;
}

- (void)dealloc
{
  [nc removeObserver: self];
  RELEASE (modules);
  RELEASE (fmviews);
  RELEASE (currentSelection);
  RELEASE (win);
  RELEASE (searchResults);
  RELEASE (lsFolders);
    
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id defentry;
    NSArray *usedModules;
    NSRect rect;
    NSSize cs, ms;
    NSUInteger i;
    
    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    } 
   
    fmviews = [NSMutableArray new];
    modules = nil;
    currentSelection = nil;
    searchResults = [NSMutableArray new];
    lsFolders = [NSMutableArray new];
        
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    ws = [NSWorkspace sharedWorkspace];
    gworkspace = [GWorkspace gworkspace];

    [win setTitle: NSLocalizedString(@"Finder", @"")];
    [win setDelegate: self];
  
    [win setFrameUsingName: @"finder" force: YES];

    [placesBox setFinder: self];

    rect = [[(NSBox *)placesBox contentView] bounds];
    placesScroll = [[NSScrollView alloc] initWithFrame: rect];
    [placesScroll setBorderType: NSBezelBorder];
    [placesScroll setHasHorizontalScroller: NO];
    [placesScroll setHasVerticalScroller: YES]; 
    [(NSBox *)placesBox setContentView: placesScroll];
    RELEASE (placesScroll);  
  
    placesMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
                                              mode: NSListModeMatrix 
                                         prototype: [[SearchPlacesCell new] autorelease]
                                      numberOfRows: 0 
                                   numberOfColumns: 0];
    [placesMatrix setTarget: self];
    [placesMatrix setAction: @selector(placesMatrixAction:)];
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
  
    defentry = [defaults objectForKey: @"saved_places"];

    if (defentry && [defentry isKindOfClass: [NSArray class]]) {
      for (i = 0; i < [defentry count]; i++) {
        NSString *path = [defentry objectAtIndex: i];

        if ([fm fileExistsAtPath: path]) {
          [self addSearchPlaceWithPath: path];
        }
      }
    }

    [removePlaceButt setEnabled: ([[placesMatrix cells] count] != 0)];

    [self loadModules];

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

    for (i = 0; i < [fmviews count]; i++) {
      [[fmviews objectAtIndex: i] updateMenuForModules: modules];
    }

    [recursiveSwitch setState: NSOnState];

    defentry = [defaults objectForKey: @"search_res_h"];

    if (defentry) {
      searchResh = [defentry intValue];
    } else {
      searchResh = 0;
    } 

    defentry = [defaults objectForKey: @"lsfolders_paths"];

    if (defentry) {
      for (i = 0; i < [defentry count]; i++) {
        NSString *lsfpath = [defentry objectAtIndex: i];

        if ([fm fileExistsAtPath: lsfpath]) {
          if ([self addLiveSearchFolderWithPath: lsfpath createIndex: NO] != nil) {
            GWDebugLog(@"added lsf with path %@", lsfpath);
          }
        }
      }
    }

    [nc addObserver: self 
           selector: @selector(fileSystemWillChange:) 
               name: @"GWFileSystemWillChangeNotification"
             object: nil];

    [nc addObserver: self 
           selector: @selector(fileSystemDidChange:) 
               name: @"GWFileSystemDidChangeNotification"
             object: nil];

    [nc addObserver: self 
           selector: @selector(watcherNotification:) 
               name: @"GWFileWatcherFileDidChangeNotification"
             object: nil];    

    /* Internationalization */ 
    [searchLabel setStringValue: NSLocalizedString(@"Search in:", @"")];
    [wherePopUp removeAllItems];
    [wherePopUp insertItemWithTitle: NSLocalizedString(@"Current selection", @"")
                            atIndex: SELECTION];
    [wherePopUp insertItemWithTitle: NSLocalizedString(@"Specific places", @"")
                            atIndex: PLACES];
    [addPlaceButt setTitle: NSLocalizedString(@"Add", @"")];
    [removePlaceButt setTitle: NSLocalizedString(@"Remove", @"")];
    [itemsLabel setStringValue: NSLocalizedString(@"Search for items whose:", @"")];
    [recursiveSwitch setTitle: NSLocalizedString(@"Recursive", @"")];
    [findButt setTitle: NSLocalizedString(@"Search", @"")];
        
    usesSearchPlaces = [defaults boolForKey: @"uses_search_places"];
    if (usesSearchPlaces) {
      [wherePopUp selectItemAtIndex: PLACES];
    } else {
      [wherePopUp selectItemAtIndex: SELECTION];
    }
    
    [self chooseSearchPlacesType: wherePopUp];
  }

  return self;
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
  [self tile];
}

- (void)loadModules
{
  NSString *bundlesDir;
  NSEnumerator *enumerator;
  NSString *path;
  NSMutableArray *bundlesPaths;
  NSMutableArray *unsortedModules;
  NSDictionary *lastUsedModules;
  NSArray *usedNames;
  NSUInteger index;
  NSUInteger i;

  bundlesPaths = [NSMutableArray array];
  enumerator = [NSSearchPathForDirectoriesInDomains
    (NSLibraryDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((bundlesDir = [enumerator nextObject]) != nil)
    {
      NSEnumerator *enumerator;

      bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
      enumerator = [[fm directoryContentsAtPath: bundlesDir] objectEnumerator];

      while ((path = [enumerator nextObject])) {
	if ([[path pathExtension] isEqual: @"finder"]) {
	  [bundlesPaths addObject:
	    [bundlesDir stringByAppendingPathComponent: path]];
	}
      }
  }

  unsortedModules = [NSMutableArray array];

  for (i = 0; i < [bundlesPaths count]; i++)
    {
      CREATE_AUTORELEASE_POOL(arp);
      NSString *bpath = [bundlesPaths objectAtIndex: i];
      NSBundle *bundle = [NSBundle bundleWithPath: bpath];
     
      if (bundle)
        {
          Class principalClass = [bundle principalClass];

          if ([principalClass conformsToProtocol: @protocol(FinderModulesProtocol)]) {	
            id module = [[principalClass alloc] initInterface];
        
            [unsortedModules addObject: module];
            RELEASE ((id)module);			
          }
        }
    
      RELEASE (arp);
    }

  if ([unsortedModules count] == 0) {  
    NSRunAlertPanel(NSLocalizedString(@"error", @""), 
                    NSLocalizedString(@"No Finder modules! Quitting now.", @""),
                    NSLocalizedString(@"OK", @""), nil, nil);                                     
    [NSApp terminate: self];
  }

  lastUsedModules = [[NSUserDefaults standardUserDefaults] objectForKey: @"last_used_modules"];

  if ((lastUsedModules == nil) || ([lastUsedModules count] == 0)) {
    lastUsedModules = [NSDictionary dictionaryWithObjectsAndKeys:
         [NSNumber numberWithInt: 0], NSLocalizedString(@"name", @""),
         [NSNumber numberWithInt: 1], NSLocalizedString(@"kind", @""), 
         [NSNumber numberWithInt: 2], NSLocalizedString(@"size", @""), 
         [NSNumber numberWithInt: 3], NSLocalizedString(@"owner", @""), 
         [NSNumber numberWithInt: 4], NSLocalizedString(@"date created", @""), 
         [NSNumber numberWithInt: 5], NSLocalizedString(@"date modified", @""), 
         [NSNumber numberWithInt: 6], NSLocalizedString(@"contents", @""), 
         nil];
    usedNames = [NSArray arrayWithObject: NSLocalizedString(@"name", @"")];
  } else {
    usedNames = [lastUsedModules allKeys];
  }

  index = [usedNames count];

  for (i = 0; i < [unsortedModules count]; i++) {  
    id module = [unsortedModules objectAtIndex: i];  
    NSString *mname = [module moduleName];
    NSNumber *num = [lastUsedModules objectForKey: mname];
    
    if (num) {
      [module setIndex: [num intValue]];    
      [module setInUse: [usedNames containsObject: mname]];
    } else {
      [module setIndex: index];
      [module setInUse: NO];
      index++;
    }
  }

  modules = [[unsortedModules sortedArrayUsingSelector: @selector(compareModule:)] mutableCopy];
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
  NSUInteger i;
  
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
    NSUInteger count;
    NSUInteger i;

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
    NSUInteger i;

    [[aview module] setInUse: NO];
    [module setInUse: YES];
    [aview setModule: module];
    
    for (i = 0; i < [fmviews count]; i++) {
      [[fmviews objectAtIndex: i] updateMenuForModules: modules];
    }    
  }
}

- (IBAction)chooseSearchPlacesType:(id)sender
{
  NSArray *cells = [placesMatrix cells];
  NSUInteger i;
  
  usesSearchPlaces = ([sender indexOfSelectedItem] == PLACES);
  
  for (i = 0; i < [cells count]; i++) {
    [[cells objectAtIndex: i] setEnabled: usesSearchPlaces];
  }
  
  [placesMatrix deselectAllCells];
  [placesMatrix setNeedsDisplay: YES];
  
  [addPlaceButt setEnabled: usesSearchPlaces];
  [removePlaceButt setEnabled: NO];
}

- (NSDragOperation)draggingEnteredInSearchPlaces:(id <NSDraggingInfo>)sender
{
  if (usesSearchPlaces)
    {
      NSPasteboard *pb = [sender draggingPasteboard];

      splacesDndTarget = NO;

      if ([[pb types] containsObject: NSFilenamesPboardType])
        {
          NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
          NSArray *cells = [placesMatrix cells];
          NSUInteger count = [sourcePaths count];
          NSUInteger i;

          if (count == 0)
            return NSDragOperationNone;

          for (i = 0; i < [cells count]; i++)
            {
              SearchPlacesCell *cell = [cells objectAtIndex: i];

              if ([sourcePaths containsObject: [cell path]])
                return NSDragOperationNone;
            }

          splacesDndTarget = YES;    

          return [sender draggingSourceOperationMask];
        }
    }
    
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdatedInSearchPlaces:(id <NSDraggingInfo>)sender
{
  if (splacesDndTarget && usesSearchPlaces) {
    return [sender draggingSourceOperationMask];
  }
  return NSDragOperationNone;
}

- (void)concludeDragOperationInSearchPlaces:(id <NSDraggingInfo>)sender
{
  if (usesSearchPlaces) {
	  NSPasteboard *pb = [sender draggingPasteboard];

    if ([[pb types] containsObject: NSFilenamesPboardType]) {
      NSArray *sourcePaths = [pb propertyListForType: NSFilenamesPboardType]; 
      NSUInteger i;  

      for (i = 0; i < [sourcePaths count]; i++) {
        [self addSearchPlaceWithPath: [sourcePaths objectAtIndex: i]];
      }
    }
  }
    
  splacesDndTarget = NO;
}

- (IBAction)addSearchPlaceFromDialog:(id)sender
{
  NSOpenPanel *openPanel;
  NSArray *filenames;
  NSInteger result;
  NSUInteger i;
  
  openPanel = [NSOpenPanel openPanel];
  [openPanel setTitle: NSLocalizedString(@"open", @"")];	
  [openPanel setAllowsMultipleSelection: YES];
  [openPanel setCanChooseFiles: YES];
  [openPanel setCanChooseDirectories: YES];

  result = [openPanel runModalForDirectory: systemRoot() 
                                      file: nil 
                                     types: nil];
  if (result != NSOKButton)
    return;
	
  filenames = [openPanel filenames];

  for (i = 0; i < [filenames count]; i++)
    {
      [self addSearchPlaceWithPath: [filenames objectAtIndex: i]];
    }
}

- (void)addSearchPlaceWithPath:(NSString *)spath
{
  NSArray *cells = [placesMatrix cells];  
  NSUInteger count = [cells count];
  BOOL found = NO;
  NSUInteger i;

  for (i = 0; i < [cells count]; i++) {
    NSString *srchpath = [[cells objectAtIndex: i] path];
    
    if ([srchpath isEqual: spath]) {
      found = YES;
      break;
    }
  }
  
  if (found == NO) {
    FSNode *node = [FSNode nodeWithPath: spath];
    SEL compareSel = [[FSNodeRep sharedInstance] defaultCompareSelector];
    SearchPlacesCell *cell;
      
    [placesMatrix insertRow: count];
    cell = [placesMatrix cellAtRow: count column: 0];   
    [cell setNode: node];
    [cell setLeaf: YES]; 
    [cell setIcon];
    [placesMatrix sortUsingSelector: compareSel];
    [self adjustMatrix]; 
  }
}

- (void)placesMatrixAction:(id)sender
{
  if ([[placesMatrix cells] count] && usesSearchPlaces) {
    [removePlaceButt setEnabled: YES];
  }
}

- (IBAction)removeSearchPlaceButtAction:(id)sender
{
  NSArray *cells = [placesMatrix selectedCells];
  NSUInteger i;

  for (i = 0; i < [cells count]; i++) {
    [self removeSearchPlaceWithPath: [[cells objectAtIndex: i] path]];
  } 
}

- (void)removeSearchPlaceWithPath:(NSString *)spath
{
  NSArray *cells = [placesMatrix cells];
  NSUInteger i;

  for (i = 0; i < [cells count]; i++) {
    SearchPlacesCell *cell = [cells objectAtIndex: i];
  
    if ([[cell path] isEqual: spath]) {
      NSInteger row, col;
      
      [placesMatrix getRow: &row column: &col ofCell: cell];
      [placesMatrix removeRow: row];
      [self adjustMatrix]; 

      // TODO - STOP SEARCHING IN THIS PATH !
      
      break;
    }
  }
  
  if ([[placesMatrix cells] count] == 0) {
    [removePlaceButt setEnabled: NO];
  }
}

- (NSArray *)searchPlacesPaths
{
  NSArray *cells = [placesMatrix cells];
  
  if (cells && [cells count]) {
    NSMutableArray *paths = [NSMutableArray array];  
    NSUInteger i;
  
    for (i = 0; i < [cells count]; i++) {
      [paths addObject: [[cells objectAtIndex: i] path]];
    }
    
    return paths;
  }  

  return [NSArray array];
}

- (NSArray *)selectedSearchPlacesPaths
{
  NSArray *cells = [placesMatrix selectedCells];
  
  if (cells && [cells count]) {
    NSMutableArray *paths = [NSMutableArray array];  
    NSUInteger i;
    
    RETAIN (cells);
    for (i = 0; i < [cells count]; i++) {
      NSString *path = [[cells objectAtIndex: i] path];
    
      if ([fm fileExistsAtPath: path]) {
        [paths addObject: path];
      } else {
        [self removeSearchPlaceWithPath: path];
      }
    }
    RELEASE (cells);
    
    return paths;
  }  

  return nil;
}

- (void)setCurrentSelection:(NSArray *)paths
{
  NSString *elmstr = NSLocalizedString(@"elements", @"");
  NSString *title;

  ASSIGN (currentSelection, paths);

  if ([currentSelection count] == 1) {
    title = [[currentSelection objectAtIndex: 0] lastPathComponent];
  } else {
    title = [NSString stringWithFormat: @"%lu %@", (unsigned long)[currentSelection count], elmstr];
  }

  [[wherePopUp itemAtIndex: SELECTION] setTitle: title];
  [wherePopUp setNeedsDisplay: YES];
}

- (IBAction)startFind:(id)sender
{
  NSMutableDictionary *criteria = [NSMutableDictionary dictionary];
  NSArray *selection;
  NSUInteger i;

  if (usesSearchPlaces == NO) {
    if (currentSelection == nil) {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"No selection!", @""), 
                      NSLocalizedString(@"OK", @""), 
                      nil, 
                      nil);  
      return;                                   
    } else {
      selection = currentSelection;
    }
    
  } else {
    selection = [self selectedSearchPlacesPaths];
  
    if (selection == nil) {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"No selection!", @""), 
                      NSLocalizedString(@"OK", @""), 
                      nil, 
                      nil);  
      return;                              
    }
  }
  
  for (i = 0; i < [fmviews count]; i++) {
    id module = [[fmviews objectAtIndex: i] module]; 
    NSDictionary *dict = [module searchCriteria];

    if (dict) {
      [criteria setObject: dict 
                   forKey: NSStringFromClass([module class])];
    }
  }

  if ([criteria count]) {
    SearchResults *results = [SearchResults new];
    
    [searchResults addObject: results];
    RELEASE (results);
    
    [results activateForSelection: selection
               withSearchCriteria: criteria
                        recursive: ([recursiveSwitch state] == NSOnState)];  
  } else {
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"No search criteria!", @""), 
                    NSLocalizedString(@"OK", @""), 
                    nil, 
                    nil);                                     
  }
}

- (void)stopAllSearchs
{
  NSUInteger i;

  for (i = 0; i < [searchResults count]; i++) {
    SearchResults *results = [searchResults objectAtIndex: i];
  
    [results stopSearch: nil];
    if ([[results win] isVisible]) {
      [[results win] close];
    }
  }
}

- (id)resultWithAddress:(unsigned long)address
{
  NSUInteger i;

  for (i = 0; i < [searchResults count]; i++) {
    SearchResults *results = [searchResults objectAtIndex: i];
  
    if ([results memAddress] == address) {
      return results;
    }
  }

  return nil;
}

- (void)resultsWindowWillClose:(id)results
{
  [searchResults removeObject: results];
}

- (void)setSearchResultsHeight:(int)srh
{
  searchResh = srh;
}

- (int)searchResultsHeight
{
  return searchResh;
}

- (void)foundSelectionChanged:(NSArray *)selected
{
  [gworkspace selectionChanged: selected];
}

- (void)openFoundSelection:(NSArray *)selection
{
  NSUInteger i;

  for (i = 0; i < [selection count]; i++) {
    FSNode *node = [selection objectAtIndex: i];

    if ([node isDirectory] || [node isMountPoint]) {
      if ([node isApplication]) {
        [ws launchApplication: [node path]];
      } else if ([node isPackage]) {
        [gworkspace openFile: [node path]];
      } else {
        [gworkspace newViewerAtPath: [node path]];
      }        
    } else if ([node isPlain] || [node isExecutable]) {
      [gworkspace openFile: [node path]];    
    } else if ([node isApplication]) {
      [ws launchApplication: [node path]];    
    }
  }
}

- (void)fileSystemWillChange:(NSNotification *)notif
{
  NSDictionary *info = [notif object];
  NSUInteger i;

  for (i = 0; i < [lsFolders count]; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    FSNode *node = [folder node];
    
    if ([node involvedByFileOperation: info]) {
      [gworkspace removeWatcherForPath: [node path]];
      [folder setWatcherSuspended: YES];
    }
  }
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *info = [notif object];
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSArray *origfiles = [info objectForKey: @"origfiles"];
  NSMutableArray *srcpaths = [NSMutableArray array];
  NSMutableArray *dstpaths = [NSMutableArray array];
  BOOL copy, move, remove; 
  NSUInteger i, j, count;

  if ([operation isEqual: @"GWorkspaceRenameOperation"])
    {
      srcpaths = [NSMutableArray arrayWithObject: source];
      dstpaths = [NSMutableArray arrayWithObject: destination];
    }
  else
    {
      if ([operation isEqual: NSWorkspaceDuplicateOperation]
	  || [operation isEqual: NSWorkspaceRecycleOperation])
	{ 
	  for (i = 0; i < [files count]; i++) {
	    NSString *fname = [origfiles objectAtIndex: i];
	    [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
	    fname = [files objectAtIndex: i];
	    [dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
	  }
	}
      else
	{
	  for (i = 0; i < [files count]; i++)
	    {
	      NSString *fname = [files objectAtIndex: i];
	      [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
	      if (destination != nil)
		[dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
	    }
	}
    }

  copy = ([operation isEqual: NSWorkspaceCopyOperation]
                || [operation isEqual: NSWorkspaceDuplicateOperation]); 

  move = ([operation isEqual: NSWorkspaceMoveOperation] 
                || [operation isEqual: @"GWorkspaceRenameOperation"]); 

  remove = ([operation isEqual: NSWorkspaceDestroyOperation]
				        || [operation isEqual: NSWorkspaceRecycleOperation]);

  // Search Places
  if (move || remove) {
    NSArray *placesPaths = [self searchPlacesPaths];
    NSMutableArray *deletedPlaces = [NSMutableArray array];

    for (i = 0; i < [srcpaths count]; i++) {
      NSString *srcpath = [srcpaths objectAtIndex: i];
      
      for (j = 0; j < [placesPaths count]; j++) {
        NSString *path = [placesPaths objectAtIndex: j];

        if ([path isEqual: srcpath] || subPathOfPath(srcpath, path)) {
          [deletedPlaces addObject: path];
        }
      }
    }

    if ([deletedPlaces count]) {
      for (i = 0; i < [deletedPlaces count]; i++) {
        [self removeSearchPlaceWithPath: [deletedPlaces objectAtIndex: i]];
      }
    }
  }

  // LSFolders
  count = [lsFolders count];

  for (i = 0; i < count; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    FSNode *node = [folder node];
    FSNode *newnode = nil;
    BOOL found = NO;
        
    for (j = 0; j < [srcpaths count]; j++) {
      NSString *srcpath = [srcpaths objectAtIndex: j];
      NSString *dstpath = [dstpaths objectAtIndex: j];
      
      if (move || copy) {
        if ([[node path] isEqual: srcpath]) {
          if ([fm fileExistsAtPath: dstpath]) {
            newnode = [FSNode nodeWithPath: dstpath];
            found = YES;
          }
          break;
                  
        } else if ([node isSubnodeOfPath: srcpath]) {
          NSString *newpath = pathRemovingPrefix([node path], srcpath);

          newpath = [dstpath stringByAppendingPathComponent: newpath];
          
          if ([fm fileExistsAtPath: newpath]) {
            newnode = [FSNode nodeWithPath: newpath];
            found = YES;
          }
          break;
        }
        
      } else if (remove) {
        if ([[node path] isEqual: srcpath] || [node isSubnodeOfPath: srcpath]) {
          found = YES;
          break;
        }
      }
    }
    
    [folder setWatcherSuspended: NO];
    
    if (found) {
      if (move) {
        GWDebugLog(@"moved lsf with path %@ to path %@", [node path], [newnode path]);
        [folder setNode: newnode];
        
      } else if (copy) {
        [self addLiveSearchFolderWithPath: [newnode path] createIndex: NO];
        GWDebugLog(@"added lsf with path %@", [newnode path]);
        
      } else if (remove) {
        GWDebugLog(@"removed lsf with path %@", [node path]);
        [self removeLiveSearchFolder: folder];
        count--;
        i--;
      }
    }
  }

  RELEASE (arp);
}

- (void)watcherNotification:(NSNotification *)notif
{
  NSDictionary *info = [notif object];
  NSString *event = [info objectForKey: @"event"];

  if ([event isEqual: @"GWWatchedPathDeleted"]) {
    LSFolder *folder = [self lsfolderWithPath: [info objectForKey: @"path"]];
    
    if (folder) {
      GWDebugLog(@"removed (watcher) lsf with path %@", [[folder node] path]);
      [self removeLiveSearchFolder: folder];
    }
  }
}

- (void)tile
{
  NSRect wrect = [win frame];
  NSRect mbrect = [modulesBox bounds];
  NSUInteger count = [fmviews count];
  CGFloat hspace = (count * FMVIEWH) + HMARGIN + BORDER;
  NSUInteger i;
    
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
    CGFloat posy = mbrect.size.height - (FMVIEWH * (i + 1)) - BORDER;
    
    if (mbr.origin.y != posy) {
      mbr.origin.y = posy;
      [fmbox setFrame: mbr];
    }
  }
}

- (void)adjustMatrix
{
  [placesMatrix setCellSize: NSMakeSize([placesScroll contentSize].width, CELLS_HEIGHT)];  
  [placesMatrix sizeToCells];
  [placesMatrix setNeedsDisplay: YES];
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSArray *cells = [placesMatrix cells];
  NSMutableArray *savedPlaces = [NSMutableArray array];
  NSMutableArray *lsfpaths = [NSMutableArray array];
  NSUInteger i;

  if (cells && [cells count]) {
    for (i = 0; i < [cells count]; i++) {
      NSString *srchpath = [[cells objectAtIndex: i] path];
    
      if ([fm fileExistsAtPath: srchpath]) {
        [savedPlaces addObject: srchpath];
      }
    }
  }

  [defaults setObject: savedPlaces forKey: @"saved_places"];
  [defaults setBool: usesSearchPlaces forKey: @"uses_search_places"];
  
  for (i = 0; i < [fmviews count]; i++) {
    FindModuleView *fmview = [fmviews objectAtIndex: i];
    id module = [fmview module]; 
    [dict setObject: [NSNumber numberWithInt: i]
             forKey: [module moduleName]];    
  }

  [defaults setObject: dict forKey: @"last_used_modules"];  

  [defaults setObject: [NSNumber numberWithInt: searchResh] 
               forKey: @"search_res_h"];    
  
  for (i = 0; i < [lsFolders count]; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    FSNode *node = [folder node];
    
    if ([node isValid]) {
      [lsfpaths addObject: [node path]];
    }  
  }
  
  [defaults setObject: lsfpaths forKey: @"lsfolders_paths"];

  [win saveFrameUsingName: @"finder"];
}

- (BOOL)windowShouldClose:(id)sender
{
  [win saveFrameUsingName: @"finder"];
	return YES;
}

@end


@implementation Finder (LSFolders)

- (void)lsfolderDragOperation:(NSData *)opinfo
              concludedAtPath:(NSString *)path
{
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  unsigned long address = [[dict objectForKey: @"sender"] unsignedLongValue];
  SearchResults *results = [self resultWithAddress: address];

  if (results) {
    [results createLiveSearchFolderAtPath: path];
  }
}

- (BOOL)openLiveSearchFolderAtPath:(NSString *)path
{
  LSFolder *folder = [self lsfolderWithPath: path];

  if (folder == nil) {
    folder = [self addLiveSearchFolderWithPath: path createIndex: NO];
  }

  if (folder) {                                 
    [folder updateIfNeeded: nil];
  }

  return YES;
}

- (LSFolder *)addLiveSearchFolderWithPath:(NSString *)path
                              createIndex:(BOOL)index
{
  LSFolder *folder = [self lsfolderWithPath: path];

  if (folder == nil) {
    FSNode *node = [FSNode nodeWithPath: path];
  
    folder = [[LSFolder alloc] initForFinder: self 
                                    withNode: node 
                               needsIndexing: index];      
    if (folder) {
      [lsFolders addObject: folder];
      RELEASE (folder);
    }
  }
  
  if (index) {
    GWDebugLog(@"creating trees for lsf at %@", path);
  }
  
  return folder;
}

- (void)removeLiveSearchFolder:(LSFolder *)folder
{
  [folder endUpdate];
  [folder closeWindow];
  [lsFolders removeObject: folder];
}

- (LSFolder *)lsfolderWithNode:(FSNode *)node
{
  NSUInteger i;
  
  for (i = 0; i < [lsFolders count]; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    
    if ([[folder node] isEqual: node]) {
      return folder;
    }
  }
  
  return nil;
}

- (LSFolder *)lsfolderWithPath:(NSString *)path
{
  NSUInteger i;
  
  for (i = 0; i < [lsFolders count]; i++) {
    LSFolder *folder = [lsFolders objectAtIndex: i];
    
    if ([[[folder node] path] isEqual: path]) {
      return folder;
    }
  }
  
  return nil;
}

@end


@implementation NSDictionary (ColumnsSort)

- (int)compareColInfo:(NSDictionary *)dict
{
  NSNumber *p1 = [self objectForKey: @"position"];
  NSNumber *p2 = [dict objectForKey: @"position"];
  return [p1 compare: p2];
}

@end
