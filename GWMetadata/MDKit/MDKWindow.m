/* MDKWindow.m
 *  
 * Copyright (C) 2006-2018 Free Software Foundation, Inc.
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
 
#import <AppKit/AppKit.h>
#import "MDKWindow.h"
#import "MDKTableView.h"
#import "MDKAttribute.h"
#import "MDKAttributeView.h"
#import "MDKAttributeEditor.h"
#import "MDKFSFilter.h"
#import "MDKAttributeChooser.h"
#import "MDKQuery.h"
#import "MDKResultsCategory.h"
#import "DBKPathsTree.h"
#import "FSNodeRep.h"
#import "FSNPathComponentsViewer.h"
#import "MDKResultCell.h"

#define CHECKDELEGATE(s) \
  (delegate && [delegate respondsToSelector: @selector(s)])

#define WORD_MAX 40
#define WORD_MIN 3
#define CELLS_HEIGHT (28.0)
#define ICNSIZE 24

/* defines the maximum number of files to open before issuing a dialog */
#define MAX_FILES_TO_OPEN_DIALOG 8


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
  [dnc removeObserver: self];
  
  DESTROY (win);
  DESTROY (attributes);
  DESTROY (attrViews);
  DESTROY (chooser);
  DESTROY (onImage);
  if (includePathsTree != NULL) {
    freeTree(includePathsTree);
    freeTree(excludedPathsTree);
  }
  DESTROY (excludedSuffixes);
  DESTROY (queryEditors);
  DESTROY (searchPaths);
  DESTROY (textContentEditor);
  DESTROY (currentQuery);
  DESTROY (categoryNames);
  DESTROY (resultCategories);
  DESTROY (savepath);
  
	[super dealloc];
}

- (id)initWithContentsOfFile:(NSString *)path
                  windowRect:(NSRect)wrect
                    delegate:(id)adelegate
{
  self = [super init];

  if (self) {
    NSDictionary *info = nil;
        
    if (path) {    
      info = [self savedInfoAtPath: path];
    
      if (info == nil) {
        DESTROY (self);
        return self;
      }            
    } 
    
    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    }  
    
    delegate = adelegate;    
    
    if (info) {
      NSString *str = [info objectForKey: @"window_frame"];
      
      if (str) {
        [win setFrame: NSRectFromString([info objectForKey: @"window_frame"]) 
              display: NO];
      } else {
        [win setFrameUsingName: @"mdkwindow"];
      }      
    } else {
      if (NSEqualRects(wrect, NSZeroRect) == NO) {
        [win setFrame: wrect display: NO];
      } else {
        [win setFrameUsingName: @"mdkwindow"];
      }
    }
    
    if (path) {
      [self setSavePath: path];
    } else {
      [win setTitle: NSLocalizedString(@"Untitled", @"")];
    }
    
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    dnc = [NSDistributedNotificationCenter defaultCenter];
    fsnodeRep = [FSNodeRep sharedInstance];

    loadingAttributes = YES; 
    [self prepareInterface];       
    [self prepareQueries: info];
    [self prepareResults];
    [self loadAttributes: info];
    loadingAttributes = NO;
            
    includePathsTree = newTreeWithIdentifier(@"included");
    excludedPathsTree = newTreeWithIdentifier(@"excluded");
    excludedSuffixes = [[NSMutableSet alloc] initWithCapacity: 1];
    
    [self setSearcheablePaths];
      
    [dnc addObserver: self
            selector: @selector(searcheablePathsDidChange:)
	              name: @"GSMetadataIndexedDirectoriesChanged"
	            object: nil];
    
    chooser = nil;
    closing = NO;
    [self setSaved: YES];
    
    if (info) {
      NSNumber *num = [info objectForKey: @"attributes_visible"];
      
      if (num) {
        [attributesButt setState: [num intValue]];
        [self attributesButtAction: attributesButt];
      }
    }
    
    [self startSearchButtAction: startSearchButt];
  }
  
  return self;
}

- (NSDictionary *)savedInfoAtPath:(NSString *)path
{
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: path];
  id entry;
  
#define CHECK_ENTRY(e, c) do { \
  if (dict) { \
    entry = [dict objectForKey: e]; \
    if ((entry == nil) || ([entry isKindOfClass: c] == NO)) dict = nil; \
  } \
} while (0)
  
  if (dict) {
    CHECK_ENTRY (@"editors", [NSArray class]);
    CHECK_ENTRY (@"text_content_words", [NSArray class]);
    CHECK_ENTRY (@"window_frame", [NSString class]);
    CHECK_ENTRY (@"search_places", [NSArray class]);
  }
  
  return dict;
}

- (void)loadAttributes:(NSDictionary *)info
{
  unsigned mask = MDKAttributeSearchable | MDKAttributeUserSet;
  NSDictionary *attrdict = [MDKQuery attributesWithMask: mask];
  NSArray *attrnames = [attrdict allKeys];
  MDKAttribute *attribute;
  MDKAttributeView *attrview;
  BOOL addenabled;
  int i;
  
  attributes = [NSMutableArray new];
  attrViews = [NSMutableArray new];
  attribute = nil;  
  attrnames = [attrnames sortedArrayUsingSelector: @selector(compare:)];
  
  for (i = 0; i < [attrnames count]; i++) {
    NSDictionary *attrinfo = [attrdict objectForKey: [attrnames objectAtIndex: i]];
    
    attribute = [[MDKAttribute alloc] initWithAttributeInfo: attrinfo
                                                  forWindow: self];
    [attributes addObject: attribute];
    RELEASE (attribute);
  }

  if (info) {
    NSArray *editorsInfo = [info objectForKey: @"editors"];
    NSArray *words = [info objectForKey: @"text_content_words"];

    if (words && [words count]) {
      [textContentEditor setTextContentWords: words];
    }
    
    if (editorsInfo && [editorsInfo count]) {
      for (i = 0; i < [editorsInfo count]; i++) {
        NSDictionary *edinfo = [editorsInfo objectAtIndex: i];
        NSString *attrname = [edinfo objectForKey: @"attrname"];
        MDKAttributeEditor *editor;

        attribute = [self attributeWithName: attrname];        
        [attribute setInUse: YES];

        attrview = [[MDKAttributeView alloc] initInWindow: self];
        [attrview setAttribute: attribute];
        [[attrBox contentView] addSubview: [attrview mainBox]];
        [attrViews addObject: attrview];
        RELEASE (attrview);     

        editor = [attribute editor];
        [editor restoreSavedState: edinfo];           
        [queryEditors addObject: editor];      
      }
    } else {
      attribute = nil;     
    }
                
  } else {
    attribute = nil;  
  }
  
  if (attribute == nil) {
    attribute = [self attributeWithName: @"GSMDItemFSName"];  
    [attribute setInUse: YES];
    
    attrview = [[MDKAttributeView alloc] initInWindow: self];
    [attrview setAttribute: attribute];
    
    [[attrBox contentView] addSubview: [attrview mainBox]];
    [attrViews addObject: attrview];
    RELEASE (attrview);    
  }
  
  if ([[self usedAttributes] count] == [attributes count]) {
    for (i = 0; i < [attrViews count]; i++) {
      [[attrViews objectAtIndex: i] setAddEnabled: NO];     
    }      
  }
  
  addenabled = ([[self usedAttributes] count] < [attributes count]);
  
  for (i = 0; i < [attrViews count]; i++) {
    attrview = [attrViews objectAtIndex: i];
    [attrview setAddEnabled: addenabled];     
    [attrview updateMenuForAttributes: attributes];
  }
}

- (void)prepareInterface
{
  NSBundle *bundle = [NSBundle bundleForClass: [self class]];
  NSString *impath;
  NSImage *image;
  NSString *ttstr;
  NSRect r;
  
  onImage = [NSImage imageNamed: @"common_2DCheckMark"];
  RETAIN (onImage);

  ttstr = NSLocalizedString(@"Restrict the search to chosen places.", @"");
  [placesPopUp setTitle: NSLocalizedString(@"Search in...", @"")];
  [placesPopUp setToolTip: ttstr]; 
  
  impath = [bundle pathForResource: @"switchOff" ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: impath];
  [caseSensButt setImage: image];    
  RELEASE (image);

  impath = [bundle pathForResource: @"switchOn" ofType: @"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile: impath];
  [caseSensButt setAlternateImage: image];    
  RELEASE (image);

  [caseSensButt setState: NSOnState];    
  [caseSensButt setToolTip: NSLocalizedString(@"Case sensitive switch", @"")];     
  
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
  [resultsView setAllowsMultipleSelection: YES];
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
  
  r = [[pathBox contentView] bounds];
  pathViewer = [[FSNPathComponentsViewer alloc] initWithFrame: r];
  [pathBox setContentView: pathViewer];
  RELEASE (pathViewer);

  [self setContextHelp];
}

- (void)setSearcheablePaths
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id entry;
  NSUInteger i;
  
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
  NSUInteger count = [items count];
  NSUInteger i;

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

- (NSArray *)attributes
{
  return attributes;
}

- (NSArray *)usedAttributes
{
  NSMutableArray *used = [NSMutableArray array];
  NSUInteger i;

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
  NSUInteger i;
  
  for (i = 0; i < [attributes count]; i++) {
    MDKAttribute *attribute = [attributes objectAtIndex: i];
    
    if ([attribute inUse] == NO) {
      return attribute;
    }
  }
 
  return nil;
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
    NSUInteger index = [attrViews indexOfObjectIdenticalTo: view];  
    MDKAttribute *attr = [self firstUnusedAttribute];
    MDKAttributeView *attrview = [[MDKAttributeView alloc] initInWindow: self];
    NSUInteger count;
    NSUInteger attrcount;
    NSUInteger i;

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
    
    [self editorStateDidChange: [attribute editor]];
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
    [self editorStateDidChange: [oldattribute editor]];                     
    [attribute setInUse: YES];
    [view setAttribute: attribute];
    /* notification sent by MDKAttributeView */
    
    for (i = 0; i < [attrViews count]; i++) {
      [[attrViews objectAtIndex: i] updateMenuForAttributes: attributes];
    }    
  }
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
  [self tile];  
}

- (NSDictionary *)statusInfo
{
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  NSMutableArray *editorsInfo = [NSMutableArray array];
  NSArray *items = [placesPopUp itemArray];
  NSMutableArray *paths = [NSMutableArray array];
  NSInteger index;
  NSUInteger i;
  
  for (i = 0; i < [attrViews count]; i++) {
    MDKAttributeView *attrview = [attrViews objectAtIndex: i];
    MDKAttribute *attr = [attrview attribute];
    MDKAttributeEditor *editor = [attr editor];
        
    if ([editor hasValidValues]) { 
      [editorsInfo addObject: [editor editorInfo]];
    }  
  }
  
  [info setObject: editorsInfo forKey: @"editors"];
  
  [info setObject: [textContentEditor textContentWords]
           forKey: @"text_content_words"];
    
  [info setObject: NSStringFromRect([win frame])
           forKey: @"window_frame"];
    
  [info setObject: [NSNumber numberWithInt: [attributesButt state]]
           forKey: @"attributes_visible"];
  
  /* We must start at 2 because [items objectAtIndex: 0] is the title */
  /* of the popup, [items objectAtIndex: 1] is "Computer"             */
  /* and [items objectAtIndex: 2] is "Home".                          */
  /* The upper limit is [items count] -1 because the last item        */
  /* is the "Add..." item                                             */
  for (i = 3; i < [items count] -1; i++) {
    [paths addObject: [[items objectAtIndex: i] representedObject]];
  }  
  
  [info setObject: paths forKey: @"search_places"];
  
  index = [placesPopUp indexOfSelectedItem];
  
  if ((index > 0) && (index < [items count] -1)) {
    [info setObject: [NSNumber numberWithInt: index]
             forKey: @"selected_search_place"];
  }
  
  return info;
}

- (void)setSaved:(BOOL)value
{
  saved = value;  
  [saveButt setEnabled: (saved == NO)];
}

- (BOOL)isSaved
{
  return saved;
}

- (void)setSavePath:(NSString *)path
{
  ASSIGN (savepath, path);
  [win setTitle: [savepath lastPathComponent]];
}

- (NSString *)savePath
{
  return savepath;
}

#define ATBOXH (30.0)
#define ATVIEWH (26.0)
#define RESLIMH (70.0)

- (void)tile
{
  NSView *view = [win contentView];
  NSRect abr = [attributesButt frame];
  CGFloat ylim = abr.origin.y + abr.size.height;
  NSRect atr = [attrBox frame];
  NSRect elr = [elementsLabel frame];
  NSRect rsr = [resultsScroll frame];

  if ([attributesButt state] == NSOffState) {
    atr.origin.y = ylim;
    atr.size.height = 0;
    [attrBox setFrame: atr];
    
  } else {
    NSUInteger count = [attrViews count];
    CGFloat hspace = ATBOXH + ((count - 1) * ATVIEWH);
    CGFloat posy;
    NSUInteger i;
  
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
    CGFloat inc = RESLIMH - rsr.size.height + ATVIEWH;
    
    wrect.size.height += inc;
    wrect.origin.y -= inc;   
    
    [win setFrame: wrect display: NO];
    
    /* setting the window frame will cause   */
    /* a NSWindowDidResizeNotification       */
    /* so we must return to avoid recursion  */
    return;
  }
  
  [resultsScroll setFrame: rsr];

  [view setNeedsDisplay: YES];  
}

- (NSWindow *)window
{
  return win;
}

- (IBAction)placesPopUpdAction:(id)sender
{
  NSArray *items = [sender itemArray];
  NSUInteger count = [items count];    
  NSInteger index = [sender indexOfSelectedItem];
  NSUInteger i;
  
  [searchPaths removeAllObjects];
  
  if ((index != 0) && (index != count-1)) {
    id<NSMenuItem> item = [sender selectedItem];
    NSString *path = [item representedObject];
        
    for (i = 1; i < count -1; i++) {
      item = [items objectAtIndex: i];
    
      if (i == index) {
        [item setImage: onImage];
      } else {
        [item setImage: nil];
      }
    }
    
    if ([path isEqual: pathSeparator()] == NO) {
      [searchPaths addObject: path];      
    }    

    if (loadingAttributes == NO) {
      [self setSaved: NO];
      [self startSearchButtAction: startSearchButt];
    }
        
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
  [self stopSearchButtAction: nil];
      
  if ([[textContentEditor textContentWords] count] || [queryEditors count]) {
    [self newQuery];
  }    
}

- (IBAction)caseSensButtAction:(id)sender
{
  [self editorStateDidChange: caseSensButt];
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
  if (saved == NO) {
    if (CHECKDELEGATE (saveQuery:)) {
      [delegate saveQuery: nil];
    }
  }
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
    [self editorStateDidChange: [oldattribute editor]];                         
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
  NSUInteger i;
     
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
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
  if (CHECKDELEGATE (setActiveWindow:)) {
    [delegate setActiveWindow: self];
  }
}

- (void)windowDidResize:(NSNotification *)notif
{
  if ([notif object] == win) {  
    [self tile]; 
  }
}

- (BOOL)windowShouldClose:(id)sender
{
  BOOL canclose = YES;
  
  if ([currentQuery isGathering] || [currentQuery waitingStart]) {
    closing = YES;
    [self stopCurrentQuery];        
    canclose = NO;
  }

  if ((savepath != nil) && (saved == NO)) {
    canclose = !(NSRunAlertPanel(nil,
                          NSLocalizedString(@"The query is unsaved", @""),
                          NSLocalizedString(@"Cancel", @""),
                          NSLocalizedString(@"Close Anyway", @""),
                          nil));        
  }
    
	return canclose;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  if (currentQuery) {
    [self stopCurrentQuery];  
    [win saveFrameUsingName: @"mdkwindow"];
    
    if (CHECKDELEGATE (mdkwindowWillClose:)) {
      [delegate mdkwindowWillClose: self];
    }
  }
}

@end


@implementation MDKWindow (queries)

- (void)prepareQueries:(NSDictionary *)info
{
  ASSIGN (currentQuery, [MDKQuery query]);
  queryEditors = [NSMutableArray new];
  textContentEditor = [[MDKTextContentEditor alloc] initWithSearchField: searchField
                                                               inWindow: self];
  rowsCount = 0;
  globalCount = 0;
      
  [dnc addObserver: self
          selector: @selector(queryCategoriesDidChange:)
	            name: @"MDKQueryCategoriesDidChange"
	          object: nil];

  searchPaths = [NSMutableArray new];

  while ([[placesPopUp itemArray] count] > 1) {
    [placesPopUp removeItemAtIndex: 1];
  }   
     
  [placesPopUp addItemWithTitle: NSLocalizedString(@"Computer", @"")];
  [[placesPopUp lastItem] setRepresentedObject: pathSeparator()];

  [placesPopUp addItemWithTitle: NSLocalizedString(@"Home", @"")];
  [[placesPopUp lastItem] setRepresentedObject: NSHomeDirectory()];

  if (info) {
    NSArray *places = [info objectForKey: @"search_places"];
    int index = [[info objectForKey: @"selected_search_place"] intValue];
    BOOL canselect = YES;
    NSUInteger i;
    
    for (i = 0; i < [places count]; i++) {
      NSString *place = [places objectAtIndex: i];
      
      if ([fm fileExistsAtPath: place]
              && inTreeFirstPartOfPath(place, includePathsTree)
              && (inTreeFirstPartOfPath(place, excludedPathsTree) == NO)) {      
        NSString *name = [place lastPathComponent];
    
        [placesPopUp addItemWithTitle: name];
        [[placesPopUp lastItem] setRepresentedObject: place];
      
      } else {
        canselect = NO;
      }
    }
    
    if (canselect) {
      [placesPopUp selectItemAtIndex: index];
    }
    
  } else {
    [placesPopUp selectItemAtIndex: 1];
  }

  [placesPopUp addItemWithTitle: NSLocalizedString(@"Add...", @"")];
  
  [self placesPopUpdAction: placesPopUp];
}

- (void)prepareResults
{
  NSDictionary *categoryInfo = [MDKQuery categoryInfo];
  NSUInteger i;
 
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

- (void)editorStateDidChange:(id)sender
{
  if (loadingAttributes == NO) {
    BOOL newquery = NO;
      
    if (sender == caseSensButt) {
      if ([[textContentEditor textContentWords] count]) {
        newquery = YES;
      }    

    } else if (sender == textContentEditor) {      
      newquery = YES;
    
    } else {
      MDKAttribute *attribute = (MDKAttribute *)[sender attribute];

      if ([attribute inUse]) {  
        if ([sender hasValidValues]) {    
          if ([queryEditors containsObject: sender] == NO) {
            [queryEditors addObject: sender];
          }
          newquery = YES;

        } else {       
          if ([queryEditors containsObject: sender]) {
            [queryEditors removeObject: sender];
            newquery = YES;
          }
        }

      } else {
        if ([queryEditors containsObject: sender]) {
          [queryEditors removeObject: sender];
          newquery = YES;
        }    
      }      
    }
        
    if (newquery) { 
      [self setSaved: NO];
      [self newQuery];
    }    
  }
}

- (void)newQuery
{
  CREATE_AUTORELEASE_POOL(arp);
  NSArray *words;
  MDKCompoundOperator operator;
  BOOL casesens;
  NSMutableArray *fsfilters;
  BOOL onlyfilters;
  NSUInteger i, j;

  [currentQuery setUpdatesEnabled: NO];
  [currentQuery stopQuery];

  [progView stop];  
  [self updateElementsLabel: 0];
  [pathViewer showComponentsOfSelection: nil];
  rowsCount = 0; 
  globalCount = 0;
  [self updateCategoryControls: NO removeSubviews: YES];
  [resultsView noteNumberOfRowsChanged];
  [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
  
  ASSIGN (currentQuery, [MDKQuery query]);
  [currentQuery setUpdatesEnabled: YES];
  [currentQuery setDelegate: self];
  
  casesens = ([caseSensButt state] == NSOnState);
  operator = MDKCompoundOperatorNone;
  
  onlyfilters = YES;  
  words = [textContentEditor textContentWords];
  
  for (i = 0; i < [words count]; i++) {
    [currentQuery appendSubqueryWithCompoundOperator: operator
                                           attribute: @"GSMDItemTextContent"
                                         searchValue: [words objectAtIndex: i]
                                        operatorType: MDKEqualToOperatorType    
                                       caseSensitive: casesens];    
    operator = GMDAndCompoundOperator;
    onlyfilters = NO;
  }
  
  fsfilters = [NSMutableArray array];
  
  for (i = 0; i < [queryEditors count]; i++) {
    MDKAttributeEditor *editor = [queryEditors objectAtIndex: i]; 
    MDKAttribute *attribute = [editor attribute];
    NSDictionary *edinfo = [editor editorInfo];
    NSString *name = [edinfo objectForKey: @"attrname"];
    MDKOperatorType type = [[edinfo objectForKey: @"optype"] intValue];
    NSArray *values = [edinfo objectForKey: @"values"];
    BOOL fsfilter = [attribute isFsattribute];
    
    if (fsfilter == NO) {
      BOOL csens = [[edinfo objectForKey: @"casesens"] boolValue];
      
      if ([attribute type] != ARRAY) {
        [currentQuery appendSubqueryWithCompoundOperator: operator
                                               attribute: name
                                             searchValue: [values objectAtIndex: 0]
                                            operatorType: type    
                                           caseSensitive: csens]; 
        operator = GMDAndCompoundOperator;                                    
      } else {
        for (j = 0; j < [values count]; j++) {
          [currentQuery appendSubqueryWithCompoundOperator: operator
                                                 attribute: name
                                               searchValue: [values objectAtIndex: j]
                                              operatorType: type    
                                             caseSensitive: csens];  
          operator = GMDAndCompoundOperator;                                     
        }
      }
      
      onlyfilters = NO;

    } else {
      MDKFSFilter *filter = [MDKFSFilter filterForAttribute: attribute
                                               operatorType: type
                                                searchValue: [values objectAtIndex: 0]];
      if (filter) {
        [fsfilters addObject: filter];
      }
    }
  }

  [currentQuery closeSubqueries];

  if ([searchPaths count]) {  
    [currentQuery setSearchPaths: searchPaths];
  }    
  
  if ([currentQuery buildQuery] == NO) {
    NSLog(@"unable to build \"%@\"", [currentQuery description]); 
    [NSApp terminate: self];
  } 

  [currentQuery setFSFilters: fsfilters];    
    
  [self prepareResultCategories];
    
  if (onlyfilters == NO) {
    closing = NO;
    [currentQuery startGathering];
  } else {
    // 
  }
  
  RELEASE (arp);
}

- (void)prepareResultCategories
{
  NSUInteger i;

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
    
    if (closing) {
      [win close: nil];
    }
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
  [self stopCurrentQuery];
  
  rowsCount = 0;
  globalCount = 0;
  [self updateCategoryControls: NO removeSubviews: YES];    
  [resultsView noteNumberOfRowsChanged];
  [resultsView setNeedsDisplayInRect: [resultsView visibleRect]];
  [pathViewer showComponentsOfSelection: nil];
  [self updateElementsLabel: 0];
}

- (void)stopCurrentQuery
{
  if (currentQuery) {
    [currentQuery setUpdatesEnabled: NO];
    [currentQuery stopQuery];
    [progView stop];
  }
}

- (void)updateElementsLabel:(int)n
{
  NSString *elemstr = NSLocalizedString(@"elements", @"");
  NSString *str = [NSString stringWithFormat: @"%i %@", n, elemstr];
    
  [elementsLabel setStringValue: str];
}

- (void)queryCategoriesDidChange:(NSNotification *)notif
{
  [self prepareResults];
}

- (MDKQuery *)currentQuery
{
  return currentQuery;
}

@end


@implementation MDKWindow (TableView)

//
// NSTableDataSource protocol
//
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return rowsCount;
}

- (id)tableView:(NSTableView *)aTableView
          objectValueForTableColumn:(NSTableColumn *)aTableColumn
                                row:(NSInteger)rowIndex
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
  NSMutableArray *paths = [NSMutableArray array];
  NSMutableArray *parentPaths = [NSMutableArray array];
  int i;

  for (i = 0; i < [rows count]; i++) {
    NSInteger index = [[rows objectAtIndex: i] intValue];
    id nd = [catlist resultAtIndex: index];
    
    if ((*isMember)(nd, memberSel, FSNodeClass) && [nd isValid]) {
      NSString *parentPath = [nd parentPath];
      
      if (([parentPaths containsObject: parentPath] == NO) && (i != 0)) {
        NSString *msg = NSLocalizedString(@"You can't move objects with multiple parent paths!", @"");
        NSRunAlertPanel(nil, msg, NSLocalizedString(@"Continue", @""), nil, nil);
        return NO;
      }

      [paths addObject: [nd path]];
      [parentPaths addObject: parentPath];    
    }
  }
  
  if ([paths count]) {
    [pboard declareTypes: [NSArray arrayWithObject: NSFilenamesPboardType] 
                                             owner: nil];
    [pboard setPropertyList: paths forType: NSFilenamesPboardType];

    return YES;  
  }
  
  return NO;
}

//
// NSTableView delegate methods
//
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
  NSArray *selected = [self selectedObjects];

  [pathViewer showComponentsOfSelection: selected];

  if (CHECKDELEGATE (window:didChangeSelection:)) {
    [delegate window: self didChangeSelection: selected];
  }
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
              row:(NSInteger)rowIndex
{
  id nd = [catlist resultAtIndex: rowIndex];
  
  if ((*isMember)(nd, memberSel, FSNodeClass)) {
    [aCell setHeadCell: NO];
      
    if (aTableColumn == nameColumn) {    
      [aCell setIcon: [fsnodeRep iconOfSize: ICNSIZE forNode: nd]];    
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
  NSUInteger i;
  
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
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSArray *selected = [self selectedObjects];
  NSUInteger count = [selected count];
  NSUInteger i;

  if (count > MAX_FILES_TO_OPEN_DIALOG) {
    NSString *msg1 = NSLocalizedString(@"Are you sure you want to open", @"");
    NSString *msg2 = NSLocalizedString(@"items?", @"");
  
    if (NSRunAlertPanel(nil,
                [NSString stringWithFormat: @"%@ %lu %@",
                          msg1, (unsigned long) count, msg2],
                NSLocalizedString(@"Cancel", @""),
                NSLocalizedString(@"Yes", @""),
                nil)) {
      return;
    }
  }
  
  for (i = 0; i < count; i++) {
    FSNode *nd = [selected objectAtIndex: i];
    
    if ([nd hasValidPath]) {   
      NSString *path = [nd path];
               
      NS_DURING
        {
      if ([nd isDirectory]) {
        if ([nd isPackage]) {    
          if ([nd isApplication] == NO) {
            [ws openFile: path];
          } else {
            [ws launchApplication: path];
          }
        } else {
          [ws selectFile: path inFileViewerRootedAtPath: path]; 
        } 
      } else if ([nd isPlain]) {        
        [ws openFile: path];
      }
        }
      NS_HANDLER
        {
          NSRunAlertPanel(NSLocalizedString(@"error", @""), 
              [NSString stringWithFormat: @"%@ %@!", 
                        NSLocalizedString(@"Can't open ", @""), [nd name]],
                                            NSLocalizedString(@"OK", @""), 
                                            nil, 
                                            nil);                                     
        }
      NS_ENDHANDLER      
    }
  }
}

- (NSArray *)selectedObjects
{
  NSMutableArray *selected = [NSMutableArray array];
  NSEnumerator *enumerator = [resultsView selectedRowEnumerator];
  NSNumber *row;

  while ((row = [enumerator nextObject])) {
    id nd = [catlist resultAtIndex: [row intValue]];

    if ((*isMember)(nd, memberSel, FSNodeClass) && [nd isValid]) {
      [selected addObject: nd];
    }
  }

  return selected; 
}

- (NSArray *)selectedPaths
{
  NSArray *selnodes = [self selectedObjects];
  NSMutableArray *selpaths = [NSMutableArray array];
  NSUInteger i;
  
  for (i = 0; i < [selnodes count]; i++) {
    [selpaths addObject: [[selnodes objectAtIndex: i] path]];
  }

  return [selpaths makeImmutableCopyOnFail: NO];
}

- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows
{
  if ([dragRows count] > 1) {
    return [fsnodeRep multipleSelectionIconOfSize: ICNSIZE];
  } else {
    int index = [[dragRows objectAtIndex: 0] intValue];
    FSNode *nd = [catlist resultAtIndex: index];
    
    if ((*isMember)(nd, memberSel, FSNodeClass) && [nd isValid]) {
      return [fsnodeRep iconOfSize: ICNSIZE forNode: nd];    
    }        
  }

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
    NSUInteger i;

    images = [NSMutableArray new];
    
    for (i = 0; i < IMAGES; i++) {
      NSString *imname = [NSString stringWithFormat: @"anim-logo-%lu", i];
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
  NSArray *components;
  NSEnumerator *e;
  NSString *c;
  BOOL found;

  if (path == nil)
    return NO;

  found = NO;
  components = [path pathComponents];
  e = [components objectEnumerator];
  while ((c = [e nextObject]) && !found)
    {
      if (([c length] > 0) && ([c characterAtIndex:0] == '.'))
	found = YES;
    }

  return found;  
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
