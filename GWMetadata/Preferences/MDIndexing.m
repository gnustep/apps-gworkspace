/* MDIndexing.m
 *  
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2006
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
#import "MDIndexing.h"
#import "CategoriesEditor.h"
#import "StartAppWin.h"

BOOL subPathOfPath(NSString *p1, NSString *p2);

BOOL isDotFile(NSString *path);


@implementation MDIndexing

- (void)dealloc
{
  if (statusTimer && [statusTimer isValid]) {
    [statusTimer invalidate];
  }
  DESTROY (statusTimer);

  TEST_RELEASE (indexedPaths);
  TEST_RELEASE (excludedPaths);
  TEST_RELEASE (excludedSuffixes);
  TEST_RELEASE (startAppWin);  
  TEST_RELEASE (indexedStatusPath);
  TEST_RELEASE (indexedStatusLock);
  TEST_RELEASE (statusWindow);
  TEST_RELEASE (errorLogPath);
  TEST_RELEASE (errorWindow);
  
  [super dealloc];
}

- (void)mainViewDidLoad
{
  if (loaded == NO) {
    id cell;
    CGFloat fonth;
    int index;
    NSString *str;
    NSUInteger i;
    
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    dnc = [NSDistributedNotificationCenter defaultCenter];
    
    indexedPaths = [NSMutableArray new];
    excludedPaths = [NSMutableArray new];
    excludedSuffixes = [NSMutableArray new];

    [self readDefaults];

    index = [tabView indexOfTabViewItemWithIdentifier: @"paths"];
    [[tabView tabViewItemAtIndex: index] setLabel: NSLocalizedString(@"Paths", @"")];

    index = [tabView indexOfTabViewItemWithIdentifier: @"results"];
    [[tabView tabViewItemAtIndex: index] setLabel: NSLocalizedString(@"Search Results", @"")];

    [indexedScroll setBorderType: NSBezelBorder];
    [indexedScroll setHasHorizontalScroller: YES];
    [indexedScroll setHasVerticalScroller: YES]; 

    cell = [NSBrowserCell new];
    fonth = [[cell font] defaultLineHeightForFont];

    indexedMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
                                               mode: NSRadioModeMatrix 
                                          prototype: cell
                                       numberOfRows: 0 
                                    numberOfColumns: 0];
    RELEASE (cell);                     
    [indexedMatrix setIntercellSpacing: NSZeroSize];
    [indexedMatrix setCellSize: NSMakeSize([indexedScroll contentSize].width, fonth)];
    [indexedMatrix setAutoscroll: YES];
    [indexedMatrix setAllowsEmptySelection: YES];
    [indexedScroll setDocumentView: indexedMatrix];	
    RELEASE (indexedMatrix);

    for (i = 0; i < [indexedPaths count]; i++) {
      NSString *name = [indexedPaths objectAtIndex: i];
      NSUInteger count = [[indexedMatrix cells] count];

      [indexedMatrix insertRow: count];
      cell = [indexedMatrix cellAtRow: count column: 0];   
      [cell setStringValue: name];
      [cell setLeaf: YES];  
    }
    
    [self adjustMatrix: indexedMatrix];
    [indexedMatrix sizeToCells]; 
    [indexedMatrix setTarget: self]; 
    [indexedMatrix setAction: @selector(indexedMatrixAction:)]; 

    [indexedRemove setEnabled: ([[excludedMatrix cells] count] > 0)];

    [excludedScroll setBorderType: NSBezelBorder];
    [excludedScroll setHasHorizontalScroller: YES];
    [excludedScroll setHasVerticalScroller: YES]; 

    excludedMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
                                                mode: NSRadioModeMatrix 
                                           prototype: [[NSBrowserCell new] autorelease]
                                        numberOfRows: 0 
                                     numberOfColumns: 0];
    [excludedMatrix setIntercellSpacing: NSZeroSize];
    [excludedMatrix setCellSize: NSMakeSize([excludedScroll contentSize].width, fonth)];
    [excludedMatrix setAutoscroll: YES];
	  [excludedMatrix setAllowsEmptySelection: YES];
	  [excludedScroll setDocumentView: excludedMatrix];	
    RELEASE (excludedMatrix);

    for (i = 0; i < [excludedPaths count]; i++) {
      NSString *path = [excludedPaths objectAtIndex: i];
      NSUInteger count = [[excludedMatrix cells] count];

      [excludedMatrix insertRow: count];
      cell = [excludedMatrix cellAtRow: count column: 0];   
      [cell setStringValue: path];
      [cell setLeaf: YES];  
    }

    [self adjustMatrix: excludedMatrix];    
    [excludedMatrix sizeToCells]; 
    [excludedMatrix setTarget: self]; 
    [excludedMatrix setAction: @selector(excludedMatrixAction:)]; 

    [excludedRemove setEnabled: ([[excludedMatrix cells] count] > 0)];

    [suffixScroll setBorderType: NSBezelBorder];
    [suffixScroll setHasHorizontalScroller: YES];
    [suffixScroll setHasVerticalScroller: YES]; 

    suffixMatrix = [[NSMatrix alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)
                                              mode: NSRadioModeMatrix 
                                         prototype: [[NSBrowserCell new] autorelease]
                                      numberOfRows: 0 
                                   numberOfColumns: 0];
    [suffixMatrix setIntercellSpacing: NSZeroSize];
    [suffixMatrix setCellSize: NSMakeSize([suffixScroll contentSize].width, fonth)];
    [suffixMatrix setAutoscroll: YES];
    [suffixMatrix setAllowsEmptySelection: YES];
    [suffixScroll setDocumentView: suffixMatrix];	
    RELEASE (suffixMatrix);

    for (i = 0; i < [excludedSuffixes count]; i++) {
      NSString *path = [excludedSuffixes objectAtIndex: i];
      NSUInteger count = [[suffixMatrix cells] count];

      [suffixMatrix insertRow: count];
      cell = [suffixMatrix cellAtRow: count column: 0];   
      [cell setStringValue: path];
      [cell setLeaf: YES];  
    }

    [self adjustMatrix: suffixMatrix];    
    [suffixMatrix sizeToCells]; 
    [suffixMatrix setTarget: self]; 
    [suffixMatrix setAction: @selector(suffixMatrixAction:)]; 

    [suffixField setStringValue: @""];
    
    [suffixRemove setEnabled: ([[suffixMatrix cells] count] > 0)];

    pathsUnselReply = NSUnselectNow;
    searchResultsReply = NSUnselectNow;
    loaded = YES;
  
    [revertButton setEnabled: NO];
    [applyButton setEnabled: NO];
        
    startAppWin = [[StartAppWin alloc] init];
    
    [statusWindow setTitle: NSLocalizedString(@"Status", @"")];
    [statusWindow setFrameUsingName: @"mdindexing_status_win"];
    [statusWindow setDelegate: self];

    [statusScroll setBorderType: NSBezelBorder];
    [statusScroll setHasHorizontalScroller: NO];
    [statusScroll setHasVerticalScroller: YES]; 
    statusView = [[NSTextView alloc] initWithFrame: [[statusScroll contentView] bounds]];
    [statusView setEditable: NO];
    [statusView setSelectable: NO];
    [statusView setVerticallyResizable: YES];
    [statusView setHorizontallyResizable: NO];
    [statusView setFont: [NSFont userFixedPitchFontOfSize: 0]];
    [statusScroll setDocumentView: statusView];
    RELEASE (statusView);

    [errorWindow setTitle: NSLocalizedString(@"Error log", @"")];
    [errorWindow setFrameUsingName: @"mdindexing_error_win"];
    [errorWindow setDelegate: self];
    [errorScroll setBorderType: NSBezelBorder];
    [errorScroll setHasHorizontalScroller: NO];
    [errorScroll setHasVerticalScroller: YES]; 

    errorView = [[NSTextView alloc] initWithFrame: [[errorScroll contentView] bounds]];
    [errorView setEditable: NO];
    [errorView setSelectable: NO];
    [errorView setVerticallyResizable: YES];
    [errorView setHorizontallyResizable: YES];
    [errorView setFont: [NSFont userFixedPitchFontOfSize: 0]];
    [errorScroll setDocumentView: errorView];
    RELEASE (errorView);
        
    //
    // Search Results
    //
    str = @"Drag categories to change the order in which results appear.";
    [searchResTitle setStringValue: NSLocalizedString(str, @"")];

    str = @"Only selected categories will appear in search results.";
    [searchResSubtitle setStringValue: NSLocalizedString(str, @"")];
    
    [searchResEditor setMdindexing: self];
    
    [searchResApply setTitle: NSLocalizedString(@"Apply", @"")];
    
    indexedStatusPath = nil;
    errorLogPath = nil;
    statusTimer = nil;    
    [self setupDbPaths];
    
    mdextractor = nil;
    [self connectMDExtractor];
  }
}

- (NSPreferencePaneUnselectReply)shouldUnselect
{
  if ((pathsUnselReply == NSUnselectNow) 
                && (searchResultsReply == NSUnselectNow)) {
    return NSUnselectNow;  
  }
    
  return NSUnselectCancel;
}

- (void)didSelect
{
  if (mdextractor == nil) {
    if (NSRunAlertPanel(nil,
                      NSLocalizedString(@"The mdextractor connection died.\nDo you want to restart it?", @""),
                      NSLocalizedString(@"Yes", @""),
                      NSLocalizedString(@"No", @""),
                      nil)) {
      [self connectMDExtractor];                
    }
  }
}

- (void)willUnselect
{
  if ([statusWindow isVisible]) {
    [statusWindow close];
  }
  if ([errorWindow isVisible]) {
    [errorWindow close];
  }
}

- (void)indexedMatrixAction:(id)sender
{
  [indexedRemove setEnabled: ([[indexedMatrix cells] count] > 0)];  
}

- (IBAction)indexedButtAction:(id)sender
{
  NSPreferencePaneUnselectReply oldReply = pathsUnselReply;
  NSArray *cells = [indexedMatrix cells];
  NSUInteger count = [cells count];
  id cell;
  NSUInteger i;

#define IND_ERR_RETURN(x) \
do { \
NSRunAlertPanel(nil, \
NSLocalizedString(x, @""), \
NSLocalizedString(@"Ok", @""), \
nil, \
nil); \
pathsUnselReply = oldReply; \
return; \
} while (0)

  if (sender == indexedAdd) {
    NSString *path;
    
    pathsUnselReply = NSUnselectCancel; 
    path = [self chooseNewPath];
    
    if (path) {
      if (isDotFile(path)) {
        IND_ERR_RETURN (@"Paths containing \'.\' are not indexable!");
      }

      if ([indexedPaths containsObject: path]) {
        IND_ERR_RETURN (@"The path is already present!");
      }
      
      for (i = 0; i < [indexedPaths count]; i++) {
        if (subPathOfPath([indexedPaths objectAtIndex: i], path)) {
          IND_ERR_RETURN (@"This path is a subpath of an already indexable path!");
        }
      }
    
      for (i = 0; i < [excludedPaths count]; i++) {
        NSString *exclpath = [excludedPaths objectAtIndex: i];
        
        if ([path isEqual: exclpath] || subPathOfPath(exclpath, path)) {
          IND_ERR_RETURN (@"This path is excluded from the indexable paths!");
        }
      }
    
      [indexedPaths addObject: path];
      
      [indexedMatrix insertRow: count];
      cell = [indexedMatrix cellAtRow: count column: 0];   
      [cell setStringValue: path];
      [cell setLeaf: YES];  
      [self adjustMatrix: indexedMatrix];
      [indexedMatrix sizeToCells]; 
      [indexedMatrix selectCellAtRow: count column: 0]; 
      
      [indexedMatrix sendAction];  
          
    } else {
      pathsUnselReply = oldReply;
    }

  } else if (sender == indexedRemove) {
    cell = [indexedMatrix selectedCell];  
    
    if (cell) {  
      NSInteger row, col;
      
      [indexedPaths removeObject: [cell stringValue]];

      [indexedMatrix getRow: &row column: &col ofCell: cell];
      [indexedMatrix removeRow: row];
      [self adjustMatrix: indexedMatrix];
      [indexedMatrix sizeToCells]; 
      
      [indexedMatrix sendAction];
      
      pathsUnselReply = NSUnselectCancel; 
    
    } else {
      pathsUnselReply = oldReply;
    }
  }
  
  [revertButton setEnabled: (pathsUnselReply != NSUnselectNow)];   
  [applyButton setEnabled: (pathsUnselReply != NSUnselectNow)];  
}

- (void)excludedMatrixAction:(id)sender
{
  [excludedRemove setEnabled: ([[excludedMatrix cells] count] > 0)];  
}

- (IBAction)excludedButtAction:(id)sender
{
  NSPreferencePaneUnselectReply oldReply = pathsUnselReply;
  NSArray *cells = [excludedMatrix cells];
  NSUInteger count = [cells count];
  id cell;
  NSUInteger i;

#define EXCL_ERR_RETURN(x) \
do { \
NSRunAlertPanel(nil, \
NSLocalizedString(x, @""), \
NSLocalizedString(@"Ok", @""), \
nil, \
nil); \
pathsUnselReply = oldReply; \
return; \
} while (0)

  if (sender == excludedAdd) {
    NSString *path;
    
    pathsUnselReply = NSUnselectCancel; 
    path = [self chooseNewPath];
    
    if (path) {
      BOOL valid = NO;

      if (isDotFile(path)) {
        IND_ERR_RETURN (@"Paths containing \'.\' are not indexable by default!");
      }
    
      for (i = 0; i < [indexedPaths count]; i++) {
        if (subPathOfPath([indexedPaths objectAtIndex: i], path)) {
          valid = YES;
          break;  
        }
      }
    
      if (valid == NO) {
        EXCL_ERR_RETURN (@"An excluded path must be a subpath of an indexable path!");
      }
    
      if ([excludedPaths containsObject: path]) {
        EXCL_ERR_RETURN (@"The path is already present!");
      }
      
      for (i = 0; i < [excludedPaths count]; i++) {
        if (subPathOfPath([excludedPaths objectAtIndex: i], path)) {
          EXCL_ERR_RETURN (@"This path is a subpath of an already excluded path!");
        }
      }
    
      for (i = 0; i < [indexedPaths count]; i++) {
        NSString *idxpath = [indexedPaths objectAtIndex: i];
        
        if ([path isEqual: idxpath] || subPathOfPath(path, idxpath)) {
          EXCL_ERR_RETURN (@"This path would exclude a path defined as indexable!");
        }
      }
    
      [excludedPaths addObject: path];
      
      [excludedMatrix insertRow: count];
      cell = [excludedMatrix cellAtRow: count column: 0];   
      [cell setStringValue: path];
      [cell setLeaf: YES];  
      [self adjustMatrix: excludedMatrix];
      [excludedMatrix sizeToCells]; 
      [excludedMatrix selectCellAtRow: count column: 0]; 
      
      [excludedMatrix sendAction];  
          
    } else {
      pathsUnselReply = oldReply;
    }

  } else if (sender == excludedRemove) {
    cell = [excludedMatrix selectedCell];  
    
    if (cell) {  
      NSInteger row, col;
      
      [excludedPaths removeObject: [cell stringValue]];

      [excludedMatrix getRow: &row column: &col ofCell: cell];
      [excludedMatrix removeRow: row];
      [self adjustMatrix: excludedMatrix];
      [excludedMatrix sizeToCells]; 
      
      [excludedMatrix sendAction];
      
      pathsUnselReply = NSUnselectCancel; 
    
    } else {
      pathsUnselReply = oldReply;
    }
  }
  
  [revertButton setEnabled: (pathsUnselReply != NSUnselectNow)];   
  [applyButton setEnabled: (pathsUnselReply != NSUnselectNow)];    
}

- (void)suffixMatrixAction:(id)sender
{
  [suffixRemove setEnabled: ([[suffixMatrix cells] count] > 0)];  
}

- (IBAction)suffixButtAction:(id)sender
{
  NSPreferencePaneUnselectReply oldReply = pathsUnselReply;
  NSArray *cells = [suffixMatrix cells];
  NSUInteger count = [cells count];
  id cell;

#define SUFF_ERR_RETURN(x) \
do { \
NSRunAlertPanel(nil, \
NSLocalizedString(x, @""), \
NSLocalizedString(@"Ok", @""), \
nil, \
nil); \
pathsUnselReply = oldReply; \
[suffixField setStringValue: @""]; \
return; \
} while (0)

  if (sender == suffixAdd) {
    NSString *suff = [suffixField stringValue];

    pathsUnselReply = NSUnselectCancel; 

    if ([suff length]) {
      NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString: @". "];

      if ([suff rangeOfCharacterFromSet: set].location != NSNotFound) {
        SUFF_ERR_RETURN (@"Invalid character in suffix!");
      }
      
      if ([excludedSuffixes containsObject: suff]) {
        SUFF_ERR_RETURN (@"The suffix is already present!");
      }
      
      [excludedSuffixes addObject: suff];
      
      [suffixMatrix insertRow: count];
      cell = [suffixMatrix cellAtRow: count column: 0];   
      [cell setStringValue: suff];
      [cell setLeaf: YES];  
      [self adjustMatrix: suffixMatrix];
      [suffixMatrix sizeToCells]; 
      [suffixMatrix selectCellAtRow: count column: 0]; 
      
      [suffixMatrix sendAction];  
                
    } else {        
      pathsUnselReply = oldReply;
    }

  } else if (sender == suffixRemove) {
    cell = [suffixMatrix selectedCell];  
    
    if (cell) {  
      NSInteger row, col;
      
      [excludedSuffixes removeObject: [cell stringValue]];

      [suffixMatrix getRow: &row column: &col ofCell: cell];
      [suffixMatrix removeRow: row];
      [self adjustMatrix: suffixMatrix];
      [suffixMatrix sizeToCells]; 
      
      [suffixMatrix sendAction];
      
      pathsUnselReply = NSUnselectCancel; 
    
    } else {
      pathsUnselReply = oldReply;
    }
  }

  [suffixField setStringValue: @""];
  
  [revertButton setEnabled: (pathsUnselReply != NSUnselectNow)];   
  [applyButton setEnabled: (pathsUnselReply != NSUnselectNow)];  
}

- (IBAction)enableSwitchAction:(id)sender
{
  BOOL oldEnabled = indexingEnabled;

  indexingEnabled = ([enableSwitch state] == NSOnState);

  [revertButton setEnabled: (oldEnabled != indexingEnabled)];   
  [applyButton setEnabled: (oldEnabled != indexingEnabled)];    
}

- (IBAction)revertButtAction:(id)sender
{
  id cell;
  NSUInteger i;

  DESTROY (indexedPaths);
  DESTROY (excludedPaths);
  DESTROY (excludedSuffixes);

  indexedPaths = [NSMutableArray new];
  excludedPaths = [NSMutableArray new];
  excludedSuffixes = [NSMutableArray new];
  
  [self readDefaults];  
  
  if ([indexedMatrix numberOfColumns] > 0) { 
    [indexedMatrix removeColumn: 0];
  }
  
  for (i = 0; i < [indexedPaths count]; i++) {
    NSString *name = [indexedPaths objectAtIndex: i];
    NSUInteger count = [[indexedMatrix cells] count];

    [indexedMatrix insertRow: count];
    cell = [indexedMatrix cellAtRow: count column: 0];   
    [cell setStringValue: name];
    [cell setLeaf: YES];  
  }

  [self adjustMatrix: indexedMatrix];
  [indexedMatrix sizeToCells]; 

  [indexedRemove setEnabled: ([[indexedMatrix cells] count] > 0)];
  
  if ([excludedMatrix numberOfColumns] > 0) {
    [excludedMatrix removeColumn: 0];
  }

  for (i = 0; i < [excludedPaths count]; i++) {
    NSString *path = [excludedPaths objectAtIndex: i];
    NSUInteger count = [[excludedMatrix cells] count];

    [excludedMatrix insertRow: count];
    cell = [excludedMatrix cellAtRow: count column: 0];   
    [cell setStringValue: path];
    [cell setLeaf: YES];  
  }

  [self adjustMatrix: excludedMatrix];    
  [excludedMatrix sizeToCells]; 

  [excludedRemove setEnabled: ([[excludedMatrix cells] count] > 0)];

  if ([suffixMatrix numberOfColumns] > 0) {
    [suffixMatrix removeColumn: 0];
  }

  for (i = 0; i < [excludedSuffixes count]; i++) {
    NSString *suff = [excludedSuffixes objectAtIndex: i];
    NSUInteger count = [[suffixMatrix cells] count];

    [suffixMatrix insertRow: count];
    cell = [suffixMatrix cellAtRow: count column: 0];   
    [cell setStringValue: suff];
    [cell setLeaf: YES];  
  }

  [self adjustMatrix: suffixMatrix];    
  [suffixMatrix sizeToCells]; 

  [suffixRemove setEnabled: ([[suffixMatrix cells] count] > 0)];
  
  pathsUnselReply = NSUnselectNow;
  [revertButton setEnabled: NO];   
  [applyButton setEnabled: NO];
}

- (IBAction)applyButtAction:(id)sender
{
  [self applyChanges];  
  pathsUnselReply = NSUnselectNow; 
  [revertButton setEnabled: NO];   
  [applyButton setEnabled: NO];
}

- (NSString *)chooseNewPath
{
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];
  int result;

  [openPanel setTitle: NSLocalizedString(@"Choose directory", @"")];	
  [openPanel setAllowsMultipleSelection: NO];
  [openPanel setCanChooseFiles: NO];
  [openPanel setCanChooseDirectories: YES];

  result = [openPanel runModalForDirectory: nil file: nil types: nil];
  
  if (result == NSOKButton) {
    return [openPanel filename];
  }
  
  return nil;
}

- (void)adjustMatrix:(NSMatrix *)matrix
{
  NSArray *cells = [matrix cells];
  
  if (cells && [cells count])
    {
      NSSize cellsize = [matrix cellSize];
      CGFloat margin = 10.0;
      CGFloat maxw = margin;
      NSDictionary *fontAttr;
      NSUInteger i;

      fontAttr = [NSDictionary dictionaryWithObject: [[cells objectAtIndex: 0] font] 
                                             forKey: NSFontAttributeName];
                                           
      for (i = 0; i < [cells count]; i++) {
        NSString *str = [[cells objectAtIndex: i] stringValue];
        CGFloat strw = [str sizeWithAttributes: fontAttr].width + margin;
  
        maxw = (strw > maxw) ? strw : maxw;
      }
    
      if (maxw > cellsize.width) {
        [matrix setCellSize: NSMakeSize(maxw, cellsize.height)];
      }
    }
}

- (void)setupDbPaths
{
  NSString *dbdir;
  NSString *lockpath;
  BOOL isdir;
  
  dbdir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  dbdir = [dbdir stringByAppendingPathComponent: @"gmds"];

  if (([fm fileExistsAtPath: dbdir isDirectory: &isdir] &isdir) == NO) {
    if ([fm createDirectoryAtPath: dbdir attributes: nil] == NO) { 
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"unable to create the db directory.", @""), 
                      NSLocalizedString(@"Ok", @""), 
                      nil, 
                      nil); 
      return;
    }
  }

  dbdir = [dbdir stringByAppendingPathComponent: @".db"];

  if (([fm fileExistsAtPath: dbdir isDirectory: &isdir] &isdir) == NO) {
    if ([fm createDirectoryAtPath: dbdir attributes: nil] == NO) { 
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"unable to create the db directory.", @""), 
                      NSLocalizedString(@"Ok", @""), 
                      nil, 
                      nil); 
      return;
    }
  }

  ASSIGN (indexedStatusPath, [dbdir stringByAppendingPathComponent: @"status.plist"]);

  ASSIGN (errorLogPath, [dbdir stringByAppendingPathComponent: @"error.log"]);

  lockpath = [dbdir stringByAppendingPathComponent: @"extractors.lock"];
  indexedStatusLock = [[NSDistributedLock alloc] initWithPath: lockpath];
}

- (void)connectMDExtractor
{
  if (mdextractor == nil) {
    mdextractor = [NSConnection rootProxyForConnectionWithRegisteredName: @"mdextractor" 
                                                                    host: @""];

    if (mdextractor == nil) {
	    NSString *cmd;
      int i;
    
      cmd = [NSTask launchPathForTool: @"mdextractor"];    
                
      [startAppWin showWindowWithTitle: @"MDIndexing"
                               appName: @"mdextractor"
                             operation: NSLocalizedString(@"starting:", @"")
                          maxProgValue: 80.0];
    
      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
   
      for (i = 1; i <= 80; i++) {
        [startAppWin updateProgressBy: 1.0];
	      [[NSRunLoop currentRunLoop] runUntilDate:
		                     [NSDate dateWithTimeIntervalSinceNow: 0.1]];

        mdextractor = [NSConnection rootProxyForConnectionWithRegisteredName: @"mdextractor" 
                                                                        host: @""];                  
        if (mdextractor) {
          [startAppWin updateProgressBy: 80.0 - i];
          break;
        }
      }

      [[startAppWin win] close];
    }
    
    if (mdextractor) {
      [mdextractor setProtocolForProxy: @protocol(MDExtractorProtocol)];
      RETAIN (mdextractor);
    
	    [[NSNotificationCenter defaultCenter] addObserver: self
	                   selector: @selector(mdextractorConnectionDidDie:)
		                     name: NSConnectionDidDieNotification
		                   object: [mdextractor connectionForProxy]];
    } else {
      NSRunAlertPanel(nil,
              NSLocalizedString(@"unable to contact mdextractor!", @""),
              NSLocalizedString(@"Ok", @""),
              nil, 
              nil);  
    }
  }
}

- (void)mdextractorConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  NSAssert(connection == [mdextractor connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (mdextractor);
  mdextractor = nil;

  if ([self isSelected]) {
    if (NSRunAlertPanel(nil,
                      NSLocalizedString(@"The mdextractor connection died.\nDo you want to restart it?", @""),
                      NSLocalizedString(@"Yes", @""),
                      NSLocalizedString(@"No", @""),
                      nil)) {
      [self connectMDExtractor];                
    }
  }
}

- (IBAction)statusButtAction:(id)sender
{
  if ([statusWindow isVisible] == NO) {
    [statusWindow makeKeyAndOrderFront: nil];
    
    [self readIndexedPathsStatus: nil];
    
    if (statusTimer && [statusTimer isValid]) {
      [statusTimer invalidate];
    }
    DESTROY (statusTimer);

    statusTimer = [NSTimer scheduledTimerWithTimeInterval: 5.0 
						                           target: self 
                                     selector: @selector(readIndexedPathsStatus:) 
																     userInfo: nil 
                                      repeats: YES];
    RETAIN (statusTimer);
  }
}

- (IBAction)errorButtAction:(id)sender
{
  NSString *errstr = @"";

  if ([fm fileExistsAtPath: errorLogPath]) {
	  NS_DURING
	    {
	      errstr = [NSString stringWithContentsOfFile: errorLogPath];
	    }
	  NS_HANDLER
	    {
        errstr = @"";
	    }
	  NS_ENDHANDLER
  }
  
  [errorView setString: errstr];
//  [errorView sizeToFit];

  if ([errorWindow isVisible] == NO) {
    [errorWindow makeKeyAndOrderFront: nil];
  }
}

- (void)readIndexedPathsStatus:(id)sender
{
  CREATE_AUTORELEASE_POOL(arp);

  if (indexedStatusPath && [fm isReadableFileAtPath: indexedStatusPath]) {
    NSArray *status = nil;
    
    if ([indexedStatusLock tryLock] == NO) {
      unsigned sleeps = 0;

      if ([[indexedStatusLock lockDate] timeIntervalSinceNow] < -20.0) {
	      NS_DURING
	        {
	      [indexedStatusLock breakLock];
	        }
	      NS_HANDLER
	        {
        NSLog(@"Unable to break lock %@ ... %@", indexedStatusLock, localException);
	        }
	      NS_ENDHANDLER
      }

      for (sleeps = 0; sleeps < 10; sleeps++) {
	      if ([indexedStatusLock tryLock]) {
	        break;
	      }

        sleeps++;
	      [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
	    }

      if (sleeps >= 10) {
        NSLog(@"Unable to obtain lock %@", indexedStatusLock);
        RELEASE (arp);
        return;
	    }
    }

    status = [NSArray arrayWithContentsOfFile: indexedStatusPath];
    [indexedStatusLock unlock];
  
    if (status) {
      NSMutableString *str = [NSMutableString string];
      NSUInteger i;
    
      for (i = 0; i < [status count]; i++) {
        NSDictionary *info = [status objectAtIndex: i];
        NSString *path = [info objectForKey: @"path"];
        BOOL indexed = [[info objectForKey: @"indexed"] boolValue];
        NSNumber *fcount = [info objectForKey: @"count"];
        NSDate *startTime = [info objectForKey: @"start_time"];
        NSDate *endTime = [info objectForKey: @"end_time"];
        NSArray *subPaths = [info objectForKey: @"subpaths"];
                
        [str appendFormat: @"%@\n", path];
        [str appendFormat: @"  indexed: %@\n", (indexed ? @"YES" : @"NO")];
        
        if (startTime) {
          [str appendFormat: @"  start:   %@\n", [startTime description]];
        }
        if (endTime) {
          [str appendFormat: @"  end:     %@\n", [endTime description]];
        }
        if (fcount) {
          [str appendFormat: @"  files:    %lu\n", [fcount unsignedLongValue]];
        }

        if (subPaths && [subPaths count]) {
          unsigned j;
          
          [str appendString: @"  subpaths:\n"];
          
          for (j = 0; j < [subPaths count]; j++) {
            info = [subPaths objectAtIndex: j];
            path = [info objectForKey: @"path"];
            indexed = [[info objectForKey: @"indexed"] boolValue];
            fcount = [info objectForKey: @"count"];
            startTime = [info objectForKey: @"start_time"];
            endTime = [info objectForKey: @"end_time"];
            
            [str appendFormat: @"    %@\n", path];
            [str appendFormat: @"      indexed: %@\n", (indexed ? @"YES" : @"NO")];
            
            if (startTime) {
              [str appendFormat: @"      start:   %@\n", [startTime description]];
            }
            if (endTime) {
              [str appendFormat: @"      end:     %@\n", [endTime description]];
            }
            if (fcount) {
              [str appendFormat: @"      files:    %lu\n", [fcount unsignedLongValue]];
            }          
          }
        }
        
        [str appendString: @"\n"];
      }
  
      [statusView setString: str];
      [statusView sizeToFit];
    }
  }
  
  RELEASE (arp);
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  id win = [aNotification object];
  
  if (win == statusWindow) {
    if (statusTimer && [statusTimer isValid]) {
      [statusTimer invalidate];
    }
    DESTROY (statusTimer);

    [statusWindow saveFrameUsingName: @"mdindexing_status_win"];
  
  } else if (win == errorWindow) {
    [errorWindow saveFrameUsingName: @"mdindexing_error_win"];
  }
}

- (void)readDefaults 
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id entry;
  
  [defaults synchronize];

  entry = [defaults arrayForKey: @"GSMetadataIndexablePaths"];
  if (entry) {
    [indexedPaths addObjectsFromArray: entry];
    
  } else {
    NSArray *dirs;
    NSUInteger i;
    
    [indexedPaths addObject: NSHomeDirectory()];

    dirs = NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory, 
                                                      NSAllDomainsMask, YES);
    [indexedPaths addObjectsFromArray: dirs];

    dirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, 
                                                      NSAllDomainsMask, YES);
    for (i = 0; i < [dirs count]; i++) {
      NSString *dir = [dirs objectAtIndex: i];
      NSString *path = [dir stringByAppendingPathComponent: @"Headers"];

      if ([fm fileExistsAtPath: path]) {
        [indexedPaths addObject: path];
      }
      
      path = [dir stringByAppendingPathComponent: @"Documentation"];
      
      if ([fm fileExistsAtPath: path]) {
        [indexedPaths addObject: path];
      }
    }  
  }

  entry = [defaults arrayForKey: @"GSMetadataExcludedPaths"];
  if (entry) {
    [excludedPaths addObjectsFromArray: entry];
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
  
  indexingEnabled = [defaults boolForKey: @"GSMetadataIndexingEnabled"];
  [enableSwitch setState: (indexingEnabled ? NSOnState : NSOffState)];
}

- (void)applyChanges
{
  CREATE_AUTORELEASE_POOL(arp);
  NSUserDefaults *defaults;
  NSMutableDictionary *domain;
  NSMutableDictionary *info;

  defaults = [NSUserDefaults standardUserDefaults];
  [defaults synchronize];
  domain = [[defaults persistentDomainForName: NSGlobalDomain] mutableCopy];

  [domain setObject: indexedPaths forKey: @"GSMetadataIndexablePaths"];
  [domain setObject: excludedPaths forKey: @"GSMetadataExcludedPaths"];  
  [domain setObject: excludedSuffixes forKey: @"GSMetadataExcludedSuffixes"];  
  [domain setObject: [NSNumber numberWithBool: indexingEnabled] 
             forKey: @"GSMetadataIndexingEnabled"];  

  [defaults setPersistentDomain: domain forName: NSGlobalDomain];
  [defaults synchronize];
  RELEASE (domain);  

  info = [NSMutableDictionary dictionary];

  [info setObject: indexedPaths forKey: @"GSMetadataIndexablePaths"];
  [info setObject: excludedPaths forKey: @"GSMetadataExcludedPaths"];  
  [info setObject: excludedSuffixes forKey: @"GSMetadataExcludedSuffixes"];  
  [info setObject: [NSNumber numberWithBool: indexingEnabled] 
           forKey: @"GSMetadataIndexingEnabled"];  

  [dnc postNotificationName: @"GSMetadataIndexedDirectoriesChanged"
	 								   object: nil 
                   userInfo: info];

  RELEASE (arp);
}

//
// Search Results
//
- (IBAction)searchResButtAction:(id)sender
{
  if (sender == searchResApply) {
    [searchResEditor applyChanges];
  } else {
    [searchResEditor revertChanges];
  } 
}

- (void)searchResultDidStartEditing
{
  [searchResRevert setEnabled: YES];
  [searchResApply setEnabled: YES];
  searchResultsReply = NSUnselectCancel;
}

- (void)searchResultDidEndEditing
{
  [searchResRevert setEnabled: NO];
  [searchResApply setEnabled: NO];
  searchResultsReply = NSUnselectNow;
}

@end


BOOL subPathOfPath(NSString *p1, NSString *p2)
{
  int l1 = [p1 length];
  int l2 = [p2 length];  

  if ((l1 > l2) || ([p1 isEqual: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqual: p1]) {
    if ([[p2 pathComponents] containsObject: [p1 lastPathComponent]]) {
      return YES;
    }
  }

  return NO;
}

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

