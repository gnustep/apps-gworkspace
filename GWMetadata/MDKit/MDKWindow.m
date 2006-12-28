/* MDKWindow.m
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
 
#include <AppKit/AppKit.h>
#include "MDKWindow.h"
#include "MDKTableView.h"
#include "MDKAttribute.h"
#include "MDKAttributeView.h"
#include "MDKAttributeEditor.h"
#include "MDKAttributeChooser.h"
#include "MDKQuery.h"
#include "MDKResultsCategory.h"
#include "DBKPathsTree.h"
#include "FSNodeRep.h"
#include "MDKResultCell.h"

#define WORD_MAX 40
#define WORD_MIN 3
#define CELLS_HEIGHT (28.0)

BOOL isDotFile(NSString *path);
NSString *pathSeparator(void);

typedef BOOL (*boolIMP)(id, SEL, Class);
static SEL memberSel = NULL;
static boolIMP isMember = NULL;

static Class FSNodeClass = Nil;

static NSString *nibName = @"MDKWindow";

@implementation MDKWindow

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO) {
    FSNodeClass = [FSNode class];
    memberSel = @selector(isMemberOfClass:);
    isMember = (boolIMP)[FSNodeClass instanceMethodForSelector: memberSel];    

    initialized = YES;
  }
}

- (void)dealloc
{
  RELEASE (win);
  RELEASE (attributes);
  RELEASE (attrViews);
  TEST_RELEASE (chooser);
  RELEASE (onImage);
  freeTree(includePathsTree);
  freeTree(excludedPathsTree);
  RELEASE (excludedSuffixes);
  RELEASE (textContentWords);
  RELEASE (queryEditors);
  RELEASE (currentQuery);
  RELEASE (skipSet);
  RELEASE (categoryNames);
  RELEASE (resultCategories);
  
	[super dealloc];
}

- (id)init
{
  self = [super init];

  if (self) {
    NSArray *usedAttributes;
    unsigned i;
    
    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }  
    
    loadingAttributes = YES;
    
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    dnc = [NSDistributedNotificationCenter defaultCenter];
    fsnodeRep = [FSNodeRep sharedInstance];
    
    [self setupQueries];
    [self setupResults];
    [self setupInterface];

    attrViews = [NSMutableArray new];  
    [self loadAttributes];
    usedAttributes = [self usedAttributes];

    for (i = 0; i < [usedAttributes count]; i++) {
      MDKAttribute *attr = [usedAttributes objectAtIndex: i];
      MDKAttributeView *attrview = [[MDKAttributeView alloc] initInWindow: self];

      [attrview setAttribute: attr];

      if ([usedAttributes count] == [attributes count]) {
        [attrview setAddEnabled: NO];    
      }

      [[attrBox contentView] addSubview: [attrview mainBox]];
      [attrViews addObject: attrview];
      RELEASE (attrview);
    }

    for (i = 0; i < [attrViews count]; i++) {
      [[attrViews objectAtIndex: i] updateMenuForAttributes: attributes];
    }
    
    chooser = nil;
        
    includePathsTree = newTreeWithIdentifier(@"included");
    excludedPathsTree = newTreeWithIdentifier(@"excluded");
    excludedSuffixes = [[NSMutableSet alloc] initWithCapacity: 1];
    
    [self setSearcheablePaths];
  
    [dnc addObserver: self
            selector: @selector(searcheablePathsDidChange:)
	              name: @"GSMetadataIndexedDirectoriesChanged"
	            object: nil];
  
    loadingAttributes = NO;
  }
  
  return self;
}

- (void)setupInterface
{
  NSString *ttstr;
  NSRect r;
  
  onImage = [NSImage imageNamed: @"common_2DCheckMark"];
  RETAIN (onImage);

  while ([[placesPopUp itemArray] count] > 1) {
    [placesPopUp removeItemAtIndex: 1];
  }      
  [self insertSavedSearchPlaces];
  [placesPopUp addItemWithTitle: NSLocalizedString(@"Add...", @"")];
  ttstr = NSLocalizedString(@"Restrict the search to choosen places.", @"");
  [placesPopUp setTitle: NSLocalizedString(@"Search in...", @"")];
  [placesPopUp setToolTip: ttstr]; 
  
  ttstr = NSLocalizedString(@"Saves the query as a Live Search Folder.", @"");
  [saveButt setTitle: NSLocalizedString(@"Save", @"")];
  [saveButt setToolTip: ttstr]; 

  ttstr = NSLocalizedString(@"Type terms to search into the text contents.", @"");
  [searchField setToolTip: ttstr]; 

  ttstr = NSLocalizedString(@"Starts a search if no term has been\nentered into the search field.", @"");
  [startSearchButt setToolTip: ttstr]; 

  ttstr = NSLocalizedString(@"Stops a running query.", @"");
  [stopSearchButt setToolTip: ttstr]; 

  ttstr = NSLocalizedString(@"Show a list of attributes to search.", @"");
  [attributesButt setToolTip: ttstr]; 

  [elementsLabel setStringValue: NSLocalizedString(@"0 elements", @"")];

  [resultsScroll setBorderType: NSBezelBorder];
  [resultsScroll setHasHorizontalScroller: NO];
  [resultsScroll setHasVerticalScroller: YES]; 

  r = [[resultsScroll contentView] bounds];
  resultsView = [[MDKTableView alloc] initWithFrame: r];
  [resultsView setDrawsGrid: NO];
  [resultsView setHeaderView: nil];
  [resultsView setCornerView: nil];
  [resultsView setAllowsColumnSelection: NO];
  [resultsView setAllowsColumnReordering: NO];
  [resultsView setAllowsColumnResizing: NO];
  [resultsView setAllowsEmptySelection: YES];
  [resultsView setAllowsMultipleSelection: NO];
  [resultsView setRowHeight: CELLS_HEIGHT];
  [resultsView setIntercellSpacing: NSZeroSize];
  [resultsView setAutoresizesAllColumnsToFit: YES];

  nameColumn = [[NSTableColumn alloc] initWithIdentifier: @"name"];
  [nameColumn setDataCell: AUTORELEASE ([[MDKResultCell alloc] init])];
  [nameColumn setEditable: NO];
  [nameColumn setResizable: YES];
  [resultsView addTableColumn: nameColumn];
  RELEASE (nameColumn);

  attrColumn = [[NSTableColumn alloc] initWithIdentifier: @"attribute"];
  [attrColumn setDataCell: AUTORELEASE ([[MDKResultCell alloc] init])];
  [attrColumn setEditable: NO];
  [attrColumn setResizable: NO];
  [attrColumn setWidth: 120];
  [resultsView addTableColumn: attrColumn];
  RELEASE (attrColumn);
 
  [resultsScroll setDocumentView: resultsView];
  RELEASE (resultsView);

  [resultsView setDataSource: self]; 
  [resultsView setDelegate: self];
  [resultsView setTarget: self];
  [resultsView setDoubleAction: @selector(doubleClickOnResultsView:)];
  
  [self setContextHelp];
}

- (void)insertSavedSearchPlaces
{
  [placesPopUp addItemWithTitle: NSLocalizedString(@"Computer", @"")];
  [[placesPopUp lastItem] setRepresentedObject: pathSeparator()];

  [placesPopUp addItemWithTitle: NSLocalizedString(@"Home", @"")];
  [[placesPopUp lastItem] setRepresentedObject: NSHomeDirectory()];


  /* This will be useful only for the saved live queries */
  /* For the moment we insert only the default places */
}

- (NSArray *)searchPlaces
{
  NSMutableArray *places = [NSMutableArray array];
  NSArray *items = [placesPopUp itemArray];
  unsigned i;

  for (i = 3; i < [items count] -1; i++) {
    [places addObject: [[items objectAtIndex: i] representedObject]];
  }
  
  return places;
}

- (void)setSearcheablePaths
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id entry;
  unsigned i;
  
  [defaults synchronize];
  
  entry = [defaults arrayForKey: @"GSMetadataIndexablePaths"];
  if (entry) {
    for (i = 0; i < [entry count]; i++) {  
      insertComponentsOfPath([entry objectAtIndex: i], includePathsTree);
    }
  }
  
  entry = [defaults arrayForKey: @"GSMetadataExcludedPaths"];
  if (entry) {
    for (i = 0; i < [entry count]; i++) {
      insertComponentsOfPath([entry objectAtIndex: i], excludedPathsTree);
    }
  }
  
  entry = [defaults arrayForKey: @"GSMetadataExcludedSuffixes"];
  if (entry == nil) {
    entry = [NSArray arrayWithObjects: @"a", @"d", @"dylib", @"er1", 
                                       @"err", @"extinfo", @"frag", @"la", 
                                       @"log", @"o", @"out", @"part", 
                                       @"sed", @"so", @"status", @"temp",
                                       @"tmp",  
                                       nil];
  } 

  [excludedSuffixes addObjectsFromArray: entry];
}

- (void)searcheablePathsDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSArray *included = [info objectForKey: @"GSMetadataIndexablePaths"];
  NSArray *excluded = [info objectForKey: @"GSMetadataExcludedPaths"];
  NSArray *suffixes = [info objectForKey: @"GSMetadataExcludedSuffixes"];
  NSArray *items = [placesPopUp itemArray];
  int count = [items count];
  unsigned i;

  emptyTreeWithBase(includePathsTree);

  for (i = 0; i < [included count]; i++) {
    insertComponentsOfPath([included objectAtIndex: i], includePathsTree);
  }

  emptyTreeWithBase(excludedPathsTree);

  for (i = 0; i < [excluded count]; i++) {
    insertComponentsOfPath([excluded objectAtIndex: i], excludedPathsTree);
  }

  [excludedSuffixes removeAllObjects];
  [excludedSuffixes addObjectsFromArray: suffixes];

  for (i = 3; i < count -1; i++) {
    NSString *path = [[items objectAtIndex: i] representedObject];
    NSString *ext = [[path pathExtension] lowercaseString];
  
    if ([excludedSuffixes containsObject: ext]
                || isDotFile(path)
                || (inTreeFirstPartOfPath(path, includePathsTree) == NO)
                || inTreeFirstPartOfPath(path, excludedPathsTree)) {
      [placesPopUp removeItemAtIndex: i];
      items = [placesPopUp itemArray];
      count--;
      i--;
    }
  }
  
  [[placesPopUp menu] update];
}

- (void)loadAttributes
{
  unsigned mask = MDKAttributeSearchable | MDKAttributeUserSet;
  NSDictionary *attrdict = [MDKQuery attributesWithMask: mask];
  NSArray *names = [attrdict allKeys];
  NSMutableArray *unsortedAttributes;
  NSDictionary *lastUsedAttributes;
  NSArray *usedNames;  
  unsigned index;
  unsigned i;

  unsortedAttributes = [NSMutableArray array];
  
  for (i = 0; i < [names count]; i++) {
    NSDictionary *info = [attrdict objectForKey: [names objectAtIndex: i]];
    MDKAttribute *attribute = [[MDKAttribute alloc] initWithAttributeInfo: info];
    
    [unsortedAttributes addObject: attribute];
    RELEASE (attribute);
  }
  
  lastUsedAttributes = [self lastUsedAttributes];  
  
  if (lastUsedAttributes && [lastUsedAttributes count]) {
    usedNames = [lastUsedAttributes allKeys]; // C'ERA SOLO QUESTA LINEA !!
  
    for (i = 0; i < [usedNames count]; i++) {
      NSString *usedName = [usedNames objectAtIndex: i];
      
      if ([self attributeWithName: usedName inArray: unsortedAttributes] == nil) {
        NSDictionary *info = [MDKQuery attributeWithName: usedName];
        MDKAttribute *attribute = [[MDKAttribute alloc] initWithAttributeInfo: info];
      
        [unsortedAttributes addObject: attribute];
        RELEASE (attribute);
      }
    }
  
  } else {
    lastUsedAttributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 0]
                                                     forKey: @"GSMDItemFSName"];
    usedNames = [NSArray arrayWithObject: @"GSMDItemFSName"];
  }
  
  index = [usedNames count];
  
  for (i = 0; i < [unsortedAttributes count]; i++) {
    MDKAttribute *attribute = [unsortedAttributes objectAtIndex: i];  
    NSString *name = [attribute name];
    NSNumber *num = [lastUsedAttributes objectForKey: name];
  
    if (num) {
      [attribute setIndex: [num intValue]];    
      [attribute setInUse: [usedNames containsObject: name]];
    } else {
      [attribute setIndex: index];
      [attribute setInUse: NO];
      index++;
    }  
  }
  
  [unsortedAttributes sortUsingSelector: @selector(compareByIndex:)];
  attributes = [unsortedAttributes mutableCopy];
}

- (NSDictionary *)lastUsedAttributes
{
  /* this will be useful only for the saved live queries */

  return nil;
}

- (NSDictionary *)orderedAttributeNames
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  unsigned i;

  for (i = 0; i < [attrViews count]; i++) {
    [dict setObject: [NSNumber numberWithInt: i]
             forKey: [[[attrViews objectAtIndex: i] attribute] name]];    
  }
  
  return dict;
}

- (NSArray *)attributes
{
  return attributes;
}

- (NSArray *)usedAttributes
{
  NSMutableArray *used = [NSMutableArray array];
  int i;

  for (i = 0; i < [attributes count]; i++) {
    MDKAttribute *attribute = [attributes objectAtIndex: i];
    
    if ([attribute inUse]) {
      [used addObject: attribute];
    }
  }
 
  return used;
}

- (MDKAttribute *)firstUnusedAttribute
{
  int i;
  
  for (i = 0; i < [attributes count]; i++) {
    MDKAttribute *attribute = [attributes objectAtIndex: i];
    
    if ([attribute inUse] == NO) {
      return attribute;
    }
  }
 
  return nil;
}

- (BOOL)isUsedAttributeWithName:(NSString *)name
{
  MDKAttribute *attribute = [self attributeWithName: name];
  
  if (attribute) {
    return [attribute inUse];
  }

  return NO;
}

- (MDKAttribute *)attributeWithName:(NSString *)name
{
  int i;
  
  for (i = 0; i < [attributes count]; i++) {
    MDKAttribute *attribute = [attributes objectAtIndex: i];
    
    if ([[attribute name] isEqual: name]) {
      return attribute;
    }
  }
 
  return nil;
}

- (MDKAttribute *)attributeWithName:(NSString *)name
                            inArray:(NSArray *)attrarray
{
  int i;
  
  for (i = 0; i < [attrarray count]; i++) {
    MDKAttribute *attribute = [attrarray objectAtIndex: i];
    
    if ([[attribute name] isEqual: name]) {
      return attribute;
    }
  }
 
  return nil;
}

- (MDKAttribute *)attributeWithMenuName:(NSString *)mname
{
  int i;
  
  for (i = 0; i < [attributes count]; i++) {
    MDKAttribute *attribute = [attributes objectAtIndex: i];
    
    if ([[attribute menuName] isEqual: mname]) {
      return attribute;
    }
  }
 
  return nil;
}

- (void)insertAttributeViewAfterView:(MDKAttributeView *)view
{
  NSArray *usedAttributes = [self usedAttributes];

  if ([usedAttributes count] < [attributes count]) {
    int index = [attrViews indexOfObjectIdenticalTo: view];  
    MDKAttribute *attr = [self firstUnusedAttribute];
    MDKAttributeView *attrview = [[MDKAttributeView alloc] initInWindow: self];
    int count;
    int attrcount;
    int i;

    [attr setInUse: YES];
    [attrview setAttribute: attr];

    [[attrBox contentView] addSubview: [attrview mainBox]];
    [attrViews insertObject: attrview atIndex: index + 1];
    RELEASE (attrview);

    count = [attrViews count];
    attrcount = [attributes count];
    
    for (i = 0; i < count; i++) {
      attrview = [attrViews objectAtIndex: i];

      [attrview updateMenuForAttributes: attributes];
      
      if (count == attrcount) {
        [attrview setAddEnabled: NO]; 
      }
      
      if (count > 1) {
        [attrview setRemoveEnabled: YES]; 
      }
    }

    [self tile];    
  }
}

- (void)removeAttributeView:(MDKAttributeView *)view
{
  if ([attrViews count] > 1) {
    MDKAttribute *attribute = [view attribute];
    int count;
    int i;

    [attribute setInUse: NO];
    [[view mainBox] removeFromSuperview];
    [attrViews removeObject: view];
    
    count = [attrViews count];

    for (i = 0; i < count; i++) {
      MDKAttributeView *attrview = [attrViews objectAtIndex: i];
      
      [attrview updateMenuForAttributes: attributes];
      [attrview setAddEnabled: YES]; 
      
      if (count == 1) {
        [attrview setRemoveEnabled: NO]; 
      }
    }
    
    [self tile];
    
    [nc postNotificationName: @"MDKAttributeEditorStateDidChange" 
                      object: [attribute editor]];
  }
}

- (void)attributeView:(MDKAttributeView *)view 
    changeAttributeTo:(NSString *)menuname
{
  MDKAttribute *attribute = [self attributeWithMenuName: menuname];
  MDKAttribute *oldattribute = [view attribute];

  if (attribute && (oldattribute != attribute)) {
    unsigned i;

    [oldattribute setInUse: NO];    
    [nc postNotificationName: @"MDKAttributeEditorStateDidChange" 
                      object: [oldattribute editor]];    
    [attribute setInUse: YES];
    [view setAttribute: attribute];
    /* notification sent by MDKAttributeView */
    
    for (i = 0; i < [attrViews count]; i++) {
      [[attrViews objectAtIndex: i] updateMenuForAttributes: attributes];
    }    
  }
}

- (unsigned)indexOfAttributeView:(MDKAttributeView *)view
{
  return [attrViews indexOfObjectIdenticalTo: view];
}






- (void)activate
{
  [win makeKeyAndOrderFront: nil];
  [self tile];  
}

#define ATBOXH (30.0)
#define ATVIEWH (26.0)
#define RESLIMH (70.0)

- (void)tile
{
  NSView *view = [win contentView];
  NSRect abr = [attributesButt frame];
  float ylim = abr.origin.y + abr.size.height;
  NSRect atr = [attrBox frame];
  NSRect elr = [elementsLabel frame];
  NSRect rsr = [resultsScroll frame];

  if ([attributesButt state] == NSOffState) {
    atr.origin.y = ylim;
    atr.size.height = 0;
    [attrBox setFrame: atr];
    
  } else {
    unsigned count = [attrViews count];
    float hspace = ATBOXH + ((count - 1) * ATVIEWH);
    float posy;
    unsigned i;
  
    atr.origin.y = ylim - hspace;
    atr.size.height = hspace;
    [attrBox setFrame: atr];
    
    posy = [[attrBox contentView] bounds].size.height;
    
    for (i = 0; i < count; i++) {  
      MDKAttributeView *attrview = [attrViews objectAtIndex: i];
      NSBox *atbox = [attrview mainBox];
      NSRect attbr = [atbox frame];
      
      posy -= ATVIEWH;
      attbr.origin.y = posy;
      [atbox setFrame: attbr];
    }
  }
  
  atr = [attrBox frame];  
  ylim = (atr.size.height == 0) ? (atr.origin.y - abr.size.height) : atr.origin.y;
  
  elr.origin.y = ylim - elr.size.height;
  [elementsLabel setFrame: elr];

  rsr.size.height = elr.origin.y - rsr.origin.y;
  
  if (rsr.size.height <= RESLIMH) {
    NSRect wrect = [win frame];
    float inc = RESLIMH - rsr.size.height + ATVIEWH;
    
    wrect.size.height += inc;
    wrect.origin.y -= inc;   
    
    [win setFrame: wrect display: NO];
    
    /* setting the window frame will cause 
      a NSWindowDidResizeNotification 
      so we must return to avoid recursion */

    return;
  }
  
  [resultsScroll setFrame: rsr];

  [view setNeedsDisplay: YES];  
}

- (IBAction)placesPopUpdAction:(id)sender
{
  NSArray *items = [sender itemArray];
  int count = [items count];
  int index = [sender indexOfSelectedItem];
  int i;
  
  if ((index != 0) && (index != count-1)) {
    NSString *title = [sender titleOfSelectedItem];
    
    for (i = 1; i < [items count] -1; i++) {
      NSMenuItem *item = [items objectAtIndex: i];
    
      if (i == index) {
        [item setImage: onImage];
        title = [item title];
      } else {
        [item setImage: nil];
      }
    }
    
    // DO SOMETHING WITH "title"
    
  } else if (index == count-1) {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	  int result;

	  [openPanel setTitle: NSLocalizedString(@"Choose search place", @"")];	
    [openPanel setAllowsMultipleSelection: NO];
    [openPanel setCanChooseFiles: NO];
    [openPanel setCanChooseDirectories: YES];

    result = [openPanel runModalForDirectory: nil file: nil types: nil];
  
    if (result == NSOKButton) {
      NSString *path = [openPanel filename];
      NSString *name = [path lastPathComponent];
      NSString *ext = [[path pathExtension] lowercaseString];
      
      if (([excludedSuffixes containsObject: ext] == NO)
              && (isDotFile(path) == NO)
              && inTreeFirstPartOfPath(path, includePathsTree)
              && (inTreeFirstPartOfPath(path, excludedPathsTree) == NO)) {      
        BOOL duplicate = NO;
        
        for (i = 1; i < [items count] -1; i++) {   
          if ([[[items objectAtIndex: i] representedObject] isEqual: path]) {
            duplicate = YES;
            break;
          }
        } 
        
        if (duplicate == NO) {
          [placesPopUp insertItemWithTitle: name atIndex: count-1];
          [[placesPopUp itemAtIndex: count-1] setRepresentedObject: path];
          [[placesPopUp menu] update];
        
        } else {
          NSRunAlertPanel(nil, 
                NSLocalizedString(@"This path is already in the menu!", @""),
					      NSLocalizedString(@"Ok", @""), 
                nil, 
                nil);  
        }
        
      } else {
        NSRunAlertPanel(nil, 
              NSLocalizedString(@"This path is not searchable!", @""),
					    NSLocalizedString(@"Ok", @""), 
              nil, 
              nil);  
      }      
    }
  }
  
  
  
}

- (IBAction)startSearchButtAction:(id)sender
{
  NSLog(@"startSearchButtAction");
}

- (IBAction)attributesButtAction:(id)sender
{
  if ([sender state] == NSOnState) {
    [attributesButt setImage: [NSImage imageNamed: @"common_ArrowDown"]];
  } else {
    [attributesButt setImage: [NSImage imageNamed: @"common_ArrowRight"]];
  }

  [self tile];  
}

- (IBAction)saveButtAction:(id)sender
{
  
//  NSLog(@"saveButtAction");
}

- (void)showAttributeChooser:(MDKAttributeView *)sender
{
  MDKAttribute *attr;
  
  if (chooser == nil) {
    chooser = [[MDKAttributeChooser alloc] initForWindow: self];
  }

  attr = [chooser chooseNewAttributeForView: sender];
  
  if (attr) {
    MDKAttribute *oldattribute = [sender attribute];
    unsigned i;

    [oldattribute setInUse: NO];    
    [nc postNotificationName: @"MDKAttributeEditorStateDidChange" 
                      object: [oldattribute editor]];        
    [attr setInUse: YES];
    [attributes addObject: attr];
    
    for (i = 0; i < [attrViews count]; i++) {  
      [[attrViews objectAtIndex: i] attributesDidChange: attributes];
    }
        
    [sender setAttribute: attr];
    /* notification sent by MDKAttributeView */
    
    for (i = 0; i < [attrViews count]; i++) {
      MDKAttributeView *attrview = [attrViews objectAtIndex: i];
    
      [attrview updateMenuForAttributes: attributes];
      [attrview setAddEnabled: YES]; 
    }    
  }
}

- (void)setContextHelp
{
  NSString *bpath = [[NSBundle bundleForClass: [self class]] bundlePath];
  NSString *resPath = [bpath stringByAppendingPathComponent: @"Resources"];
  NSArray *languages = [NSUserDefaults userLanguages];
  unsigned i;
     
  for (i = 0; i < [languages count]; i++) {
    NSString *language = [languages objectAtIndex: i];
    NSString *langDir = [NSString stringWithFormat: @"%@.lproj", language];  
    NSString *helpPath = [langDir stringByAppendingPathComponent: @"Help.rtfd"];
  
    helpPath = [resPath stringByAppendingPathComponent: helpPath];
  
    if ([fm fileExistsAtPath: helpPath]) {
      NSAttributedString *help = [[NSAttributedString alloc] initWithPath: helpPath
                                                       documentAttributes: NULL];
      if (help) {
        [[NSHelpManager sharedHelpManager] setContextHelp: help 
                                                forObject: [win contentView]];
        RELEASE (help);
      }
    }
  }
}


//
// NSWindow delegate methods
//

- (void)windowDidResize:(NSNotification *)notif
{
  if ([notif object] == win) {  
    [self tile]; 
  }
}

@end


@implementation MDKWindow (queries)

- (void)setupQueries
{
  NSCharacterSet *set;

  ASSIGN (currentQuery, [MDKQuery query]);
  ASSIGN (textContentWords, [NSArray array]);
  queryEditors = [NSMutableArray new];
  rowsCount = 0;
  globalCount = 0;
  
  skipSet = [NSMutableCharacterSet new];

  set = [NSCharacterSet controlCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet illegalCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet symbolCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  [skipSet formUnionWithCharacterSet: set];

  set = [NSCharacterSet characterSetWithCharactersInString: 
                                      @"~`@#$%^_-+\\{}:;\"\',/?"];
  [skipSet formUnionWithCharacterSet: set];  

  [nc addObserver: self
         selector: @selector(editorStateDidChange:)
	           name: @"MDKAttributeEditorStateDidChange"
	         object: nil];
    
  [dnc addObserver: self
          selector: @selector(queryCategoriesDidChange:)
	            name: @"MDKQueryCategoriesDidChange"
	          object: nil];
}

- (void)setupResults
{
  NSDictionary *categoryInfo = [MDKQuery categoryInfo];
  int i;
 
  ASSIGN (categoryNames, [MDKQuery categoryNames]);
  DESTROY (resultCategories);
  resultCategories = [NSMutableDictionary new];
  
  for (i = 0; i < [categoryNames count]; i++) {
    NSString *catname = [categoryNames objectAtIndex: i];
    NSDictionary *catinfo = [categoryInfo objectForKey: catname];
    NSString *catmenu = [catinfo objectForKey: @"menu_name"];
    MDKResultsCategory *rescat;
              
    rescat = [[MDKResultsCategory alloc] initWithCategoryName: catname
                                                     menuName: catmenu
                                                     inWindow: self];
    [resultCategories setObject: rescat forKey: catname];
    RELEASE (rescat);
    
    if (i > 0) {
      NSString *prevname = [categoryNames objectAtIndex: i-1];  
      MDKResultsCategory *prevcat = [resultCategories objectForKey: prevname];

      [rescat setPrev: prevcat];              
      [prevcat setNext: rescat];
    }
  }
  
  catlist = [resultCategories objectForKey: [categoryNames objectAtIndex: 0]];
}

- (void)controlTextDidChange:(NSNotification *)notif
{
  NSString *str = [searchField stringValue];
  BOOL newquery = NO;
    
  if ([str length]) {
    CREATE_AUTORELEASE_POOL(arp);
    NSScanner *scanner = [NSScanner scannerWithString: str];
    NSMutableArray *words = [NSMutableArray array];
        
    while ([scanner isAtEnd] == NO) {
      NSString *word;
            
      if ([scanner scanUpToCharactersFromSet: skipSet intoString: &word]) {            
        if (word) {
          unsigned wl = [word length];

          if ((wl >= WORD_MIN) && (wl < WORD_MAX)) { 
            [words addObject: word];
          }
        }
      } else {
        break;
      }
    }

    if ([words count] && ([words isEqual: textContentWords] == NO)) {
      ASSIGN (textContentWords, words);
      newquery = YES;
    }      
    
    RELEASE (arp);
    
  } else {
    ASSIGN (textContentWords, [NSArray array]);
    
    if ([queryEditors count]) {
      newquery = YES;
    } else {
      [self stopSearchButtAction: nil];
    }
  }

  if (newquery) {
    [self newQuery];
  }
}

- (void)editorStateDidChange:(NSNotification *)notif
{
  MDKAttributeEditor *editor = [notif object];  
  MDKAttribute *attribute = [editor attribute];
  BOOL newquery = NO;
  
  if (loadingAttributes) {
    return;
  }
  
  if ([attribute inUse]) {  
    if ([editor hasValidValues]) {    
      if ([queryEditors containsObject: editor] == NO) {
        [queryEditors addObject: editor];
      }
      newquery = YES;
      
    } else {       
      if ([queryEditors containsObject: editor]) {
        [queryEditors removeObject: editor];
        newquery = YES;
      }
    }
  
  } else {
    if ([queryEditors containsObject: editor]) {
      [queryEditors removeObject: editor];
      newquery = YES;
    }    
  }
  
  if ([queryEditors count] && newquery) {
    [self newQuery];
  } else {
    [self stopSearchButtAction: nil];
  }
}

- (void)newQuery
{
  CREATE_AUTORELEASE_POOL(arp);
  MDKCompoundOperator operator;
  int i;

  [currentQuery setUpdatesEnabled: NO];
  [currentQuery stopQuery];

  [progView stop];  
  [self updateElementsLabel: 0];
  rowsCount = 0; 
  globalCount = 0;
  [self updateCategoryControls: NO removeSubviews: YES];
  [resultsView noteNumberOfRowsChanged];
  [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
  
  ASSIGN (currentQuery, [MDKQuery query]);
  [currentQuery setUpdatesEnabled: YES];
  [currentQuery setDelegate: self];
    
  operator = MDKCompoundOperatorNone;
  
  for (i = 0; i < [textContentWords count]; i++) {
    [currentQuery appendSubqueryWithCompoundOperator: operator
                                           attribute: @"GSMDItemTextContent"
                                         searchValue: [textContentWords objectAtIndex: i]
                                        operatorType: MDKEqualToOperatorType    
                                       caseSensitive: YES];    
    operator = GMDAndCompoundOperator;
  }
  
  for (i = 0; i < [queryEditors count]; i++) {
    MDKAttributeEditor *editor = [queryEditors objectAtIndex: i];  
    NSDictionary *edinfo = [editor editorInfo];
    NSString *name = [edinfo objectForKey: @"attrname"];
    MDKOperatorType type = [[edinfo objectForKey: @"optype"] intValue];
    NSArray *values = [edinfo objectForKey: @"values"];
    BOOL csens = [[edinfo objectForKey: @"casesens"] boolValue];
  
    [currentQuery appendSubqueryWithCompoundOperator: operator
                                           attribute: name
                                         searchValue: [values objectAtIndex: 0]
                                        operatorType: type    
                                       caseSensitive: csens];  
    operator = GMDAndCompoundOperator;
    
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // DIVIDERLI TRA FILTRI E ALTRE COSE !!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  }

  [currentQuery closeSubqueries];
  
  if ([currentQuery buildQuery] == NO) {
    NSLog(@"unable to build \"%@\"", [currentQuery description]); 
    [NSApp terminate: self];
  } 
  
  [self prepareResultCategories];
  
  
  
  NSLog([currentQuery description]);
  
  
  
  
  [currentQuery startGathering];

  RELEASE (arp);
}

- (void)prepareResultCategories
{
  int i;

  for (i = 0; i < [categoryNames count]; i++) {
    NSString *catname = [categoryNames objectAtIndex: i];
    MDKResultsCategory *rescat = [resultCategories objectForKey: catname];
    NSArray *nodes = [currentQuery resultNodesForCategory: catname];
    
    [rescat setResults: nodes];  
  }
}

- (void)queryDidStartGathering:(MDKQuery *)query
{
  [progView start];   
}

- (void)appendRawResults:(NSArray *)lines
{
}

- (void)queryDidUpdateResults:(MDKQuery *)query
                forCategories:(NSArray *)catnames
{
  [self updateCategoryControls: YES removeSubviews: NO];
  [self updateElementsLabel: globalCount]; 
}

- (void)queryDidEndGathering:(MDKQuery *)query
{
  if (query == currentQuery) {
    [progView stop];
    [self updateElementsLabel: globalCount];
  } 
}

- (void)queryDidStartUpdating:(MDKQuery *)query
{
  if (query == currentQuery) {
    [progView start];
  }
}

- (void)queryDidEndUpdating:(MDKQuery *)query
{
  if (query == currentQuery) {
    [progView stop];
    [self updateElementsLabel: globalCount];
  }
}

- (IBAction)stopSearchButtAction:(id)sender
{
  [currentQuery setUpdatesEnabled: NO];
  [currentQuery stopQuery];
  rowsCount = 0;
  globalCount = 0;
  [self updateCategoryControls: NO removeSubviews: YES];
  [progView stop];  
  [resultsView noteNumberOfRowsChanged];
  [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
  [self updateElementsLabel: 0];
}

- (void)updateElementsLabel:(int)n
{
  NSString *elemstr = NSLocalizedString(@"elements", @"");
  NSString *str = [NSString stringWithFormat: @"%i %@", n, elemstr];
    
  [elementsLabel setStringValue: str];
}

- (void)queryCategoriesDidChange:(NSNotification *)notif
{
  [self setupResults];
}

@end


@implementation MDKWindow (TableView)

//
// NSTableDataSource protocol
//
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return rowsCount;
}

- (id)tableView:(NSTableView *)aTableView
          objectValueForTableColumn:(NSTableColumn *)aTableColumn
                                row:(int)rowIndex
{
  id nd = [catlist resultAtIndex: rowIndex];
    
  if ((*isMember)(nd, memberSel, FSNodeClass)) {    
    if (aTableColumn == nameColumn) {
      return [nd name];
    } else if (aTableColumn == attrColumn) {
      return [nd modDateDescription];
    }     
  }
        
  return [NSString string];
}

- (BOOL)tableView:(NSTableView *)aTableView
	      writeRows:(NSArray *)rows
     toPasteboard:(NSPasteboard *)pboard
{
  return NO;
}

//
// NSTableView delegate methods
//
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
              row:(int)rowIndex
{
  id nd = [catlist resultAtIndex: rowIndex];
  
  if ((*isMember)(nd, memberSel, FSNodeClass)) {
    [aCell setHeadCell: NO];
      
    if (aTableColumn == nameColumn) {    
      [aCell setIcon: [fsnodeRep iconOfSize: 24 forNode: nd]];    
    } else if (aTableColumn == attrColumn) {
   
    }
  } else {
    MDKResultsCategory *rescat = [nd objectForKey: @"category"];
    BOOL ishead = [[nd objectForKey: @"head"] boolValue];
    NSView *controls = (ishead ? [rescat headControls] : [rescat footControls]);
        
    [aCell setHeadCell: YES];
    [controls setFrame: [resultsView rectOfRow: rowIndex]];
  }
}

//
// other methods
//
- (void)updateCategoryControls:(BOOL)newranges
                removeSubviews:(BOOL)remove
{
  NSArray *rviews = [resultsView subviews];
  int i;
  
  if (newranges) {
    [catlist calculateRanges];
  }
  
  for (i = 0; i < [categoryNames count]; i++) {
    NSString *catname = [categoryNames objectAtIndex: i];
    MDKResultsCategory *rescat = [resultCategories objectForKey: catname];
    NSView *headControls = [rescat headControls];
    NSView *footControls = [rescat footControls];
    
    if (remove == NO) {
      if ([rescat hasResults]) {
        if ([rviews containsObject: headControls] == NO) {
          [resultsView addControlView: headControls];
        }
        
        if ([rescat showFooter]) {
          if ([rviews containsObject: footControls] == NO) {
            [resultsView addControlView: footControls];
          }        
        } else {
          if ([rviews containsObject: footControls]) {
            [resultsView removeControlView: footControls];
          }        
        } 
                          
      } else {
        if ([rviews containsObject: headControls]) {
          [resultsView removeControlView: headControls];
        }
        if ([rviews containsObject: footControls]) {
          [resultsView removeControlView: footControls];
        }
      } 
      
    } else {
      if ([rviews containsObject: headControls]) {
        [resultsView removeControlView: headControls];
      }
      if ([rviews containsObject: footControls]) {
        [resultsView removeControlView: footControls];
      }
    }
  }      

  if (newranges) {
    MDKResultsCategory *last = [catlist last];
    NSRange range = [last range];
    
    rowsCount = range.location + range.length;  
    globalCount = [last globalCount];
    [resultsView noteNumberOfRowsChanged];
    [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
  }  
}

- (void)doubleClickOnResultsView:(id)sender
{
  NSLog(@"doubleClickOnResultsView");
  // sempliciter@hotmail.com
}

- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows
{
  return nil;
}

@end


@implementation ProgrView

#define IMAGES 8

- (void)dealloc
{
  RELEASE (images);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
{
  self = [super initWithFrame: frameRect];

  if (self) {
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    int i;

    images = [NSMutableArray new];
    
    for (i = 0; i < IMAGES; i++) {
      NSString *imname = [NSString stringWithFormat: @"anim-logo-%d", i];
      NSString *impath = [bundle pathForResource: imname ofType: @"tiff"];
      NSImage *image = [[NSImage alloc] initWithContentsOfFile: impath];
      
      if (image) {
        [images addObject: image];    
        RELEASE (image);
      }
    }
  
    animating = NO;
  }

  return self;
}

- (void)start
{
  if (animating == NO) {
    index = 0;
    animating = YES;
    progTimer = [NSTimer scheduledTimerWithTimeInterval: 0.1 
						              target: self selector: @selector(animate:) 
																					  userInfo: nil repeats: YES];
  }
}

- (void)stop
{
  if (animating) {
    animating = NO;
    if (progTimer && [progTimer isValid]) {
      [progTimer invalidate];
    }
    [self setNeedsDisplay: YES];
  }
}

- (void)animate:(id)sender
{
  [self setNeedsDisplay: YES];
  index++;
  if (index == [images count]) {
    index = 0;
  }
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  
  if (animating) {
    [[images objectAtIndex: index] compositeToPoint: NSMakePoint(0, 0) 
                                          operation: NSCompositeSourceOver];
  }
}

@end


BOOL isDotFile(NSString *path)
{
  int len = ([path length] - 1);
  unichar c;
  int i;
  
  for (i = len; i >= 0; i--) {
    c = [path characterAtIndex: i];
    
    if (c == '.') {
      if ((i > 0) && ([path characterAtIndex: (i - 1)] == '/')) {
        return YES;
      }
    }
  }
  
  return NO;  
}

NSString *pathSeparator(void)
{
  static NSString *separator = nil;

  if (separator == nil) {
    #if defined(__MINGW32__)
      separator = @"\\";	
    #else
      separator = @"/";	
    #endif

    RETAIN (separator);
  }

  return separator;
}
