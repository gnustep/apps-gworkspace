/* FinderController.m
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
#include "GWLib.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWLib.h>
  #endif
#include "FinderController.h"
#include "Shelf/Shelf.h"
#include "GWorkspace.h"
#include "GNUstep.h"
#include <limits.h>
#include <math.h>

#define NAME_NO_VALUE 5         
#define NAME_IS 1               
#define NAME_NOT_CONTAINS 2     
#define NAME_CONTAINS 0         
#define NAME_STARTS 3           
#define NAME_ENDS 4             
       
#define TYPE_NO_VALUE 2         
#define TYPE_IS 0               
#define TYPE_IS_NOT 1         

#define TYPE_PLAIN 0         
#define TYPE_DIR 1         
#define TYPE_EXEC 2       
#define TYPE_LINK 3        
#define TYPE_APP 4        

#define CREATE_NO_VALUE 3       
#define CREATE_EXACTLY 0        
#define CREATE_BEFORE 1         
#define CREATE_AFTER 2          
                                
#define MODIF_NO_VALUE 3        
#define MODIF_EXACTLY 0         
#define MODIF_BEFORE 1          
#define MODIF_AFTER 2           
                                
#define SIZE_NO_VALUE 2         
#define SIZE_LESS 0             
#define SIZE_GREATER 1          
                                
#define OWNER_NO_VALUE 2        
#define OWNER_IS 0              
#define OWNER_IS_NOT 1        

#define SETRECT(o, x, y, w, h) { \
NSRect rct = NSMakeRect(x, y, w, h); \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0; \
[o setFrame: rct]; \
}

#define CHECKRECT(rct) \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0

#define CHECKSIZE(sz) \
if (sz.width < 0) sz.width = 0; \
if (sz.height < 0) sz.height = 0

#define WIN_MIN_W 423
#define WIN_MIN_H_OPT 477
#define WIN_MIN_H_NO_OPT 366

#ifdef GNUSTEP 
  #define MIN_SHELF_HEIGHT 2
  #define MID_SHELF_HEIGHT 77
  #define MAX_SHELF_HEIGHT 150
  #define SHELF_COLLAPSE_LIMIT 35
  #define SHELF_MID_LIMIT 110
#else
  #define MIN_SHELF_HEIGHT 2
  #define MID_SHELF_HEIGHT 55
  #define MAX_SHELF_HEIGHT 110
  #define SHELF_COLLAPSE_LIMIT 25
  #define SHELF_MID_LIMIT 85
#endif

#ifdef GNUSTEP 
  #define MIN_OPTIONS_HEIGHT 2
  #define MAX_OPTIONS_HEIGHT 163
  #define OPTIONS_COLLAPSE_LIMIT 80
#else
  #define MIN_OPTIONS_HEIGHT 2
  #define MAX_OPTIONS_HEIGHT 173
  #define OPTIONS_COLLAPSE_LIMIT 86
#endif

#define CELLS_HEIGHT 16

#ifdef GNUSTEP 
  static NSString *nibName = @"Finder.gorm";
#else
  static NSString *nibName = @"Finder.nib";
#endif

#ifdef GNUSTEP 
  static NSString *findfileName = @"findfile";
#else
  static NSString *findfileName = @"/usr/bin/findfile";
#endif

#ifndef LONG_DELAY
  #define LONG_DELAY 86400.0
#endif

@implementation SelectedFileView

- (void)dealloc
{
  TEST_RELEASE (icon);
  RELEASE (highlightImage);
  RELEASE (nameField);  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  if (self) {
    [self setFrame: NSMakeRect(0, 0, 64, 64)];
	  nameField = [[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 64, 12)];
	  [nameField setBackgroundColor: [NSColor windowBackgroundColor]];
		[nameField setFont: [NSFont systemFontOfSize: 10]];
	  [nameField setAlignment: NSCenterTextAlignment];
	  [nameField setBezeled: NO];
	  [nameField setEditable: NO];
	  [nameField setSelectable: NO];
    [self addSubview: nameField];
    
    ASSIGN (highlightImage, [NSImage imageNamed: @"CellHighlight.tiff"]);
		        
    isactive = NO;
  }
  return self;  
}

- (void)activateForFileAtPath:(NSString *)fpath
{
  NSImage *icn = [[NSWorkspace sharedWorkspace] iconForFile: fpath];
  NSSize size = [icn size];
  
  if ((size.width > ICNMAX) || (size.height > ICNMAX)) {
    NSSize newsize;
  
    if (size.width >= size.height) {
      newsize.width = ICNMAX;
      newsize.height = floor(ICNMAX * size.height / size.width + 0.5);
    } else {
      newsize.height = ICNMAX;
      newsize.width  = floor(ICNMAX * size.width / size.height + 0.5);
    }
    
	  [icn setScalesWhenResized: YES];
	  [icn setSize: newsize];  
  }

  ASSIGN (icon, icn);
  [nameField setStringValue: cutFileLabelText([fpath lastPathComponent], nameField, 64)];
  isactive = YES;
  [self setNeedsDisplay: YES];
}

- (void)deactivate
{
  [nameField setStringValue: @""];
  isactive = NO;
	[self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect
{
	NSPoint p;

  if (isactive == NO) {
    return;
	}

  p = NSMakePoint(0, 12);
  [highlightImage compositeToPoint: p operation: NSCompositeSourceOver];

  p = NSMakePoint((60 - [icon size].width) / 2, (52 - [icon size].height) / 2 + 12);
	[icon compositeToPoint: p operation: NSCompositeSourceOver];    
}

@end

@implementation FinderController

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  if (timer && [timer isValid]) {
    [timer invalidate];
  }
  TEST_RELEASE (timer);
  TEST_RELEASE (connection);
  TEST_RELEASE (task);
  TEST_RELEASE (findfile);
  TEST_RELEASE (criteria);
  TEST_RELEASE (currentSelection);
  TEST_RELEASE (foundPaths);
  RELEASE (selectFileView);
  TEST_RELEASE (foundMatrix);
  TEST_RELEASE (fWin);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      return self;
    } else {    
      criteria = nil;
      foundMatrix = nil;
      currentSelection = nil;
      gw = [GWorkspace gworkspace];
    }
  }
  
  return self;  
}

- (void)awakeFromNib
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
	NSDictionary *myPrefs;
#ifndef GNUSTEP 
  NSNumberFormatter *numFormatter;
  NSDateFormatter *dateFormatter;
#endif
	float shfwidth;   

  if ([[self superclass] instancesRespondToSelector: @selector(awakeFromNib)]){
    [super awakeFromNib];
  }

  [fWin setDelegate: self];  

	shfwidth = [[fWin contentView] frame].size.width;

  myPrefs = [defaults dictionaryForKey: @"finderprefs"];
  if (myPrefs != nil) {     
		NSArray *shelfDicts = [myPrefs objectForKey: @"shelfdicts"];  
		NSString *sheight = [myPrefs objectForKey: @"shelfheight"];
    NSNumber *opClos = [myPrefs objectForKey: @"optclosed"];
    
    if(shelfDicts != nil) {
			shelf = [[FinderShelf alloc] initWithIconsDicts: shelfDicts rootPath: nil]; 
		} else {
			shelf = [[FinderShelf alloc] initWithIconsDicts: [NSArray array] rootPath: nil]; 
		}

    if(sheight != nil) {
      shelfHeight = [sheight intValue];
    } else {
      shelfHeight = MID_SHELF_HEIGHT;
    }

    optionsClosed = (opClos && [opClos intValue]);
    optionsHeight = optionsClosed ? MIN_OPTIONS_HEIGHT : MAX_OPTIONS_HEIGHT;
    
  } else {
		shelf = [[FinderShelf alloc] initWithIconsDicts: [NSArray array] rootPath: nil]; 
    shelfHeight = MID_SHELF_HEIGHT;
    optionsClosed = NO;
    optionsHeight = MAX_OPTIONS_HEIGHT;
  }

  if (optionsClosed) {
    [fWin setMinSize: NSMakeSize(WIN_MIN_W, WIN_MIN_H_NO_OPT)];
  } else {
    [fWin setMinSize: NSMakeSize(WIN_MIN_W, WIN_MIN_H_OPT)];  
  }

  if ([fWin setFrameUsingName: @"Finder"] == NO) {
    [fWin setFrame: NSMakeRect(100, 100, 423, 477) display: NO];
  }            

  SETRECT (shelfBox, 0, 0, shfwidth, shelfHeight); 
  SETRECT (shelf, 0, 0, shfwidth, shelfHeight); 
  
  [shelf setDelegate: self];
  [shelf setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

	[shelfBox addSubview: shelf];

	[findButt setImage: [NSImage imageNamed: @"Magnify_24.tiff"]];
	[stopButt setImage: [NSImage imageNamed: @"stop_24.tiff"]];

  selectFileView = [[SelectedFileView alloc] init];
  [iconBox addSubview: selectFileView];

  [scrollView setBorderType: NSBezelBorder];
  [scrollView setHasVerticalScroller: YES];      
  [scrollView setHasHorizontalScroller: NO];      

  [split setDelegate: self];
  [optionsSplit setDelegate: self];
   
#ifndef GNUSTEP 
  numFormatter = [[NSNumberFormatter alloc] init];
  [numFormatter setFormat:@"###"];
  [[sizeField cell] setFormatter: numFormatter];
  RELEASE (numFormatter);

  dateFormatter = [[NSDateFormatter alloc] initWithDateFormat: @"%m %d %Y"
                                         allowNaturalLanguage: NO];
  [[crDateField cell] setFormatter: dateFormatter];
  [[modDateField cell] setFormatter: dateFormatter];  
  RELEASE (dateFormatter);
#else
  [crDatePopUp setEnabled: NO];
  [crDateField setSelectable: NO];
  [crDateField setEditable: NO];
  [crDateStepper setEnabled: NO];

  [modDatePopUp setEnabled: NO];
  [modDateField setSelectable: NO];
  [modDateField setEditable: NO];
  [modDateStepper setEnabled: NO];  
#endif
  
  /* Internationalization */
  [fWin setTitle: NSLocalizedString(@"Finder", @"")];
  [generallabel setStringValue: NSLocalizedString(@"Search for items whose:", @"")];
  [filenamelabel setStringValue: NSLocalizedString(@"file name", @"")];
  [kindlabel setStringValue: NSLocalizedString(@"kind", @"")];
  [sizelabel setStringValue: NSLocalizedString(@"size (KB)", @"")];
  [ownerlabel setStringValue: NSLocalizedString(@"owner", @"")];
  [datecrlabel setStringValue: NSLocalizedString(@"date created", @"")];
  [datemdlabel setStringValue: NSLocalizedString(@"date modified", @"")];
  [contentslabel setStringValue: NSLocalizedString(@"contents", @"")];
  [includeslabel setStringValue: NSLocalizedString(@"includes", @"")];
  
  [namePopUp removeAllItems];
  [namePopUp insertItemWithTitle: NSLocalizedString(@"contains", @"")  atIndex: 0];
  [namePopUp insertItemWithTitle: NSLocalizedString(@"is", @"")  atIndex: 1];
  [namePopUp insertItemWithTitle: NSLocalizedString(@"doesn't contain", @"")  atIndex: 2];
  [namePopUp insertItemWithTitle: NSLocalizedString(@"starts with", @"")  atIndex: 3];
  [namePopUp insertItemWithTitle: NSLocalizedString(@"ends with", @"")  atIndex: 4];
  [namePopUp insertItemWithTitle: NSLocalizedString(@"no value", @"")  atIndex: 5];
  [namePopUp selectItemAtIndex: 5]; 

  [kindPopUp removeAllItems];
  [kindPopUp insertItemWithTitle: NSLocalizedString(@"is", @"")  atIndex: 0];
  [kindPopUp insertItemWithTitle: NSLocalizedString(@"is not", @"")  atIndex: 1];
  [kindPopUp insertItemWithTitle: NSLocalizedString(@"no value", @"")  atIndex: 2];
  [kindPopUp selectItemAtIndex: 2]; 

  [kindTypePopUp removeAllItems];
  [kindTypePopUp insertItemWithTitle: NSLocalizedString(@"plain file", @"")  atIndex: 0];
  [kindTypePopUp insertItemWithTitle: NSLocalizedString(@"directory", @"")  atIndex: 1];
  [kindTypePopUp insertItemWithTitle: NSLocalizedString(@"shell executable", @"")  atIndex: 2];
  [kindTypePopUp insertItemWithTitle: NSLocalizedString(@"symbolic link", @"")  atIndex: 3];
  [kindTypePopUp insertItemWithTitle: NSLocalizedString(@"application", @"")  atIndex: 4];

  [sizePopUp removeAllItems];
  [sizePopUp insertItemWithTitle: NSLocalizedString(@"is less than", @"")  atIndex: 0];
  [sizePopUp insertItemWithTitle: NSLocalizedString(@"is greater than", @"")  atIndex: 1];
  [sizePopUp insertItemWithTitle: NSLocalizedString(@"no value", @"")  atIndex: 2];
  [sizePopUp selectItemAtIndex: 2]; 

  [ownerPopUp removeAllItems];
  [ownerPopUp insertItemWithTitle: NSLocalizedString(@"is", @"")  atIndex: 0];
  [ownerPopUp insertItemWithTitle: NSLocalizedString(@"is not", @"")  atIndex: 1];
  [ownerPopUp insertItemWithTitle: NSLocalizedString(@"no value", @"")  atIndex: 2];
  [ownerPopUp selectItemAtIndex: 2]; 

  [crDatePopUp removeAllItems];
  [crDatePopUp insertItemWithTitle: NSLocalizedString(@"is exactly", @"")  atIndex: 0];
  [crDatePopUp insertItemWithTitle: NSLocalizedString(@"is before", @"")  atIndex: 1];
  [crDatePopUp insertItemWithTitle: NSLocalizedString(@"is after", @"")  atIndex: 2];
  [crDatePopUp insertItemWithTitle: NSLocalizedString(@"no value", @"")  atIndex: 3];
  [crDatePopUp selectItemAtIndex: 3]; 

  [modDatePopUp removeAllItems];
  [modDatePopUp insertItemWithTitle: NSLocalizedString(@"is exactly", @"")  atIndex: 0];
  [modDatePopUp insertItemWithTitle: NSLocalizedString(@"is before", @"")  atIndex: 1];
  [modDatePopUp insertItemWithTitle: NSLocalizedString(@"is after", @"")  atIndex: 2];
  [modDatePopUp insertItemWithTitle: NSLocalizedString(@"no value", @"")  atIndex: 3];
  [modDatePopUp selectItemAtIndex: 3]; 

  [self initNameControls];
  [self initOptions];
}
       
- (void)activate
{
  [fWin makeKeyAndOrderFront: nil];  
  [self tile];
  [shelf resizeWithOldSuperviewSize: [shelf frame].size];   
  [split setNeedsDisplay: YES];
}

- (IBAction)startFind:(id)sender
{
	NSString *str;    
  int index, typeind;

#define SET_KEY(x) \
[criteria setObject: [NSNumber numberWithInt: 1] forKey: x]

#define CHECK_SET(x, v) if (index == x) SET_KEY (v)

  if (currentSelection == nil) {
		NSRunAlertPanel(nil, NSLocalizedString(@"No selection!", @""), 
                        NSLocalizedString(@"Continue", @""), nil, nil);
    return;
  }

  if (([[nameField stringValue] length] == 0)
                  && ([namePopUp indexOfSelectedItem] != NAME_NO_VALUE)) {
		NSRunAlertPanel(nil, NSLocalizedString(@"No arguments!", @""), 
                          NSLocalizedString(@"Continue", @""), nil, nil);
    return;
  }

  TEST_RELEASE (criteria);
  criteria = [[NSMutableDictionary alloc] initWithCapacity: 1];
  [criteria addEntriesFromDictionary: [self initializeFindCriteria]];

  index = [namePopUp indexOfSelectedItem];
  str = [nameField stringValue];  
  if ((index != NAME_NO_VALUE) && ([str length])) { 
    SET_KEY (@"findName");
    [criteria setObject: str forKey: @"name"];

    CHECK_SET (NAME_IS, @"nameIs");
    CHECK_SET (NAME_CONTAINS, @"nameContains");
    CHECK_SET (NAME_NOT_CONTAINS, @"doesntContain");
    CHECK_SET (NAME_STARTS, @"nameStarts");    
    CHECK_SET (NAME_ENDS, @"nameEnds");
  }
  
  index = [kindPopUp indexOfSelectedItem];
  if (index != TYPE_NO_VALUE) { 
    SET_KEY (@"findType");

    typeind = [kindTypePopUp indexOfSelectedItem];    
    switch(typeind) {
      case TYPE_PLAIN:
        [criteria setObject: @"NSPlainFileType" forKey: @"type"];
        break;
      case TYPE_DIR:
        [criteria setObject: @"NSDirectoryFileType" forKey: @"type"];
        break;
      case TYPE_EXEC:
        [criteria setObject: @"NSShellCommandFileType" forKey: @"type"];
        break;
      case TYPE_LINK:
        [criteria setObject: @"NSFileTypeSymbolicLink" forKey: @"type"];
        break;
      case TYPE_APP:
        [criteria setObject: @"NSApplicationFileType" forKey: @"type"];
        break;          
      default:
        break;
    }

    CHECK_SET (TYPE_IS, @"typeIs"); 
  }
  
  index = [sizePopUp indexOfSelectedItem];
  str = [sizeField stringValue];  
  if ((index != SIZE_NO_VALUE) && ([str length])) { 
    int ksize = [str intValue];

    if ((ksize > 0) && (ksize < INT_MAX)) {
      SET_KEY (@"findSize");       
      [criteria setObject: [NSNumber numberWithLong: ksize] forKey: @"size"];  
      CHECK_SET (SIZE_LESS, @"sizeLess");    
      CHECK_SET (SIZE_GREATER, @"sizeGreater");
    } else {
      [sizeField setStringValue: @"not a valid number!"]; 
      return;
    }
  }
  
  index = [ownerPopUp indexOfSelectedItem];
  str = [ownerField stringValue];  
  if ((index != OWNER_NO_VALUE) && ([str length])) { 
    SET_KEY (@"findOwner");
    [criteria setObject: str forKey: @"owner"];

    CHECK_SET (OWNER_IS, @"ownerIs");
  }

// Questi non funzionano perche' NSCalendarDate ritorna
// "01 00 0000", invece che "nil" se la stringa non e' valida;
// in piu', non si puo' usare nessun Formatter - questo vale anche
// per i numeri interi - perche' non sono implementati.
/*
#ifndef GNUSTEP 
  index = [crDatePopUp indexOfSelectedItem];
  str = [crDateField stringValue];  
  if ((index != CREATE_NO_VALUE) && ([str length])) { 
    NSCalendarDate *date = [NSCalendarDate dateWithString: str
                                           calendarFormat: @"%m %d %Y"];
    if (date) {
      SET_KEY (@"findCreation");
      [criteria setObject: date forKey: @"created"]; 

      CHECK_SET (CREATE_EXACTLY, @"creationExactly");
      CHECK_SET (CREATE_BEFORE, @"creationBefore");
      CHECK_SET (CREATE_AFTER, @"creationAfter");
    } else {
      date = [NSCalendarDate calendarDate];
      [crDateField setStringValue: [date descriptionWithCalendarFormat: @"%m %d %Y"]]; 
    }
  }

  index = [modDatePopUp indexOfSelectedItem];
  str = [modDateField stringValue];  
  if ((index != MODIF_NO_VALUE) && ([str length])) { 
    NSCalendarDate *date = [NSCalendarDate dateWithString: str
                                           calendarFormat: @"%m %d %Y"];
    if (date) {
      SET_KEY (@"findModification");
      [criteria setObject: str forKey: @"modified"]; 

      CHECK_SET (MODIF_EXACTLY, @"modifExactly");
      CHECK_SET (MODIF_BEFORE, @"modifBefore");
      CHECK_SET (MODIF_AFTER, @"modifAfter");
    } else {
      date = [NSCalendarDate calendarDate];
      [crDateField setStringValue: [date descriptionWithCalendarFormat: @"%m %d %Y"]]; 
    }
  }
#endif
*/
  
  str = [contentsField stringValue];  
  if ([str length]) {   
    SET_KEY (@"findContents");
    [criteria setObject: str forKey: @"contents"];   // CONTROLLARE DI PIU' !!!!     
  }  

//
// here we start the find task
//
  [self clearLastFound];
  TEST_RELEASE (foundPaths);
  foundPaths = [NSMutableArray new];
  [findButt setEnabled: NO];
  task = nil;
  findfile = nil;
  donefind = NO;

	if (connection) {
    [[connection receivePort] invalidate];
    [[connection sendPort] invalidate];
    DESTROY (connection);
	}

  if (task) {
    if ([task isRunning]) {
      [task terminate];
    }
    DESTROY (task);
  }
  
  if (timer) {
    if ([timer isValid]) {
      [timer invalidate];
    }
    DESTROY (timer);
  }
    
  connection = [[NSConnection alloc] initWithReceivePort: (NSPort *)[NSPort port]
				                                        sendPort: nil];
  [connection setRootObject: self];
  
  if ([connection registerName: @"Finder"] == NO) {
    NSLog(@"Unable to register the connection");
  }
  [connection setIndependentConversationQueueing: YES];
  [connection setRequestTimeout: LONG_DELAY];
  [connection setReplyTimeout: LONG_DELAY];
	[connection setDelegate: self];

  [[NSNotificationCenter defaultCenter] addObserver: self
                          selector: @selector(connectionDidDie:)
                              name: NSConnectionDidDieNotification
                            object: connection];    

  task = [NSTask launchedTaskWithLaunchPath: findfileName 
                                  arguments: nil];
  RETAIN (task);

  timer = [NSTimer scheduledTimerWithTimeInterval: 5.0 target: self 
          										        selector: @selector(checkFindFile:) 
                                                  userInfo: nil repeats: NO]; 
  RETAIN (timer);   
}

- (void)registerFindFile:(id)anObject
{
  [anObject setProtocolForProxy: @protocol(FindFileProtocol)];
  findfile = (id <FindFileProtocol>)anObject;

  RETAIN (findfile);
    
  [findfile findAtPath: [currentSelection objectAtIndex: 0] 
          withCriteria: [criteria description]];
}

- (void)initNameControls
{
  [namePopUp selectItemAtIndex: NAME_NO_VALUE];
  [nameField setStringValue: @""];
}

- (void)initOptions
{
  [kindPopUp selectItemAtIndex: TYPE_NO_VALUE];
  [kindTypePopUp selectItemAtIndex: TYPE_PLAIN];

  [sizePopUp selectItemAtIndex: SIZE_NO_VALUE];
  [sizeField setStringValue: @""];

  [ownerPopUp selectItemAtIndex: OWNER_NO_VALUE];
  [ownerField setStringValue: @""];

  [crDatePopUp selectItemAtIndex: CREATE_NO_VALUE];
  [crDateField setStringValue: @""];

  [modDatePopUp selectItemAtIndex: MODIF_NO_VALUE];
  [modDateField setStringValue: @""];

  [contentsField setStringValue: @""];
}

- (NSDictionary *)initializeFindCriteria
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  
#define ZERO_VAL [NSNumber numberWithInt: 0]
#define INIT_KEY(x) [dict setObject: ZERO_VAL forKey: x]

  INIT_KEY (@"findName");        
  INIT_KEY (@"nameIs");          
  INIT_KEY (@"doesntContain");   
  INIT_KEY (@"nameContains");    
  INIT_KEY (@"nameStarts");      
  INIT_KEY (@"nameEnds");        
  INIT_KEY (@"findType");        
  INIT_KEY (@"typeIs");          
  INIT_KEY (@"findCreation");    
  INIT_KEY (@"creationExactly"); 
  INIT_KEY (@"creationBefore");  
  INIT_KEY (@"creationAfter");   
  INIT_KEY (@"findModification");
  INIT_KEY (@"modifExactly");    
  INIT_KEY (@"modifBefore");     
  INIT_KEY (@"modifAfter");      
  INIT_KEY (@"findSize");        
  INIT_KEY (@"sizeLess");        
  INIT_KEY (@"sizeGreater");     
  INIT_KEY (@"findOwner");       
  INIT_KEY (@"ownerIs");         
  INIT_KEY (@"findGroup");       
  INIT_KEY (@"groupIs");         
  INIT_KEY (@"findContents");    

  return dict;
}

- (BOOL)getFoundPath:(NSString *)fpath
{
  id cell;
  BOOL fistFound = NO;
  
  if (foundMatrix == nil) {
    cell = [NSBrowserCell new];
    [cell setLeaf: YES];

    foundMatrix = [[NSMatrix alloc] initWithFrame: NSZeroRect 
                          mode: NSRadioModeMatrix prototype: cell 
                                  numberOfRows: 0 numberOfColumns: 0];
    DESTROY (cell);
    [foundMatrix setAutoresizingMask: NSViewWidthSizable];
    [foundMatrix setIntercellSpacing: NSZeroSize];
    [foundMatrix setTarget: self];		
    [foundMatrix setAction: @selector(choseFile:)];	
    [foundMatrix setDoubleAction: @selector(openFile:)];	
    [scrollView setDocumentView: foundMatrix];
    [foundMatrix setCellSize: NSMakeSize([scrollView contentSize].width, CELLS_HEIGHT)];
  
    fistFound = YES;
  }

  [foundPaths addObject: fpath];
	
  if (fistFound) {
    [foundMatrix addColumn];
  } else {
    [foundMatrix addRow];  
  }
  
  cell = [foundMatrix cellAtRow: ([[foundMatrix cells] count] -1) column: 0];    
  [cell setStringValue: fpath];
    
  [foundMatrix sizeToCells];  
  [foundMatrix setNeedsDisplay: YES];      

  return YES;
}

- (void)findDone
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  [[connection receivePort] invalidate];
  [[connection sendPort] invalidate];
  DESTROY (connection);
  
  DESTROY (findfile);  
 
  if (task) {
    if ([task isRunning]) {
      [task terminate];
    }
    DESTROY (task);
  }
  
  if (timer) {
    if ([timer isValid]) {
      [timer invalidate];
    }
    DESTROY (timer);
  }
  
  donefind = YES;  
  [findButt setEnabled: YES];
}

- (void)checkFindFile:(id)sender
{
  if ((findfile == nil) && (donefind == NO)) {  
	  NSString *msg = NSLocalizedString(@"can't contact the findfile tool!", @"");
	  NSString *buttstr = NSLocalizedString(@"Continue", @"");
	
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);

    [[connection receivePort] invalidate];
    [[connection sendPort] invalidate];
    DESTROY (connection);

    if (task) {
      if ([task isRunning]) {
        [task terminate];
      }
      DESTROY (task);
    }

    if (timer) {
      if ([timer isValid]) {
        [timer invalidate];
      }
      DESTROY (timer);
    }

    [self clearLastFound];
  }
}

- (BOOL)connection:(NSConnection*)ancestor 
								shouldMakeNewConnection:(NSConnection*)newConn
{
	if (ancestor == connection) {
  	[[NSNotificationCenter defaultCenter] addObserver: self 
										selector: @selector(connectionDidDie:)
	    									name: NSConnectionDidDieNotification object: newConn];
  	[newConn setDelegate: self];
        
  	return YES;
	}
		
  return NO;
}

- (void)connectionDidDie:(NSNotification *)notification
{
	id conn = [notification object];
  	
  [[NSNotificationCenter defaultCenter] removeObserver: self
	              name: NSConnectionDidDieNotification object: conn];

  if (donefind == NO) {
	  NSString *msg = NSLocalizedString(@"findfile connection died!", @"");
	  NSString *buttstr = NSLocalizedString(@"Continue", @"");
  
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);
    [self clearLastFound];
  }

	DESTROY (findfile);
  
	if (connection) {
    [[connection receivePort] invalidate];
    [[connection sendPort] invalidate];
    DESTROY (connection);
	}

  if (task) {
    if ([task isRunning]) {
      [task terminate];
    }
    DESTROY (task);
  }
  
  if (timer) {
    if ([timer isValid]) {
    [timer invalidate];
    }
    DESTROY (timer);
  }
}

- (void)clearLastFound
{
  if (foundMatrix) {
    [foundMatrix removeFromSuperview];
    [scrollView setDocumentView: nil];
  #ifndef GNUSTEP 
    [scrollView setNeedsDisplay: YES];
  #endif
    DESTROY (foundMatrix);
  }
    
  [selectFileView deactivate];
  [findButt setEnabled: YES];
  donefind = YES;  
}

- (IBAction)stopFind:(id)sender
{
  [self findDone];
}

- (IBAction)namePopUpAction:(id)sender
{
  if ([sender indexOfSelectedItem] == NAME_NO_VALUE) {
    [nameField setStringValue: @""];
  }
}

- (IBAction)kindPopUpAction:(id)sender
{
  if ([sender indexOfSelectedItem] == TYPE_NO_VALUE) {
    [kindTypePopUp selectItemAtIndex: TYPE_PLAIN];
  }
}

- (IBAction)kindTypePopUpAction:(id)sender
{
}
 
- (IBAction)sizePopUpAction:(id)sender
{
  if ([sender indexOfSelectedItem] == SIZE_NO_VALUE) {
    [sizeField setStringValue: @""];
  }
}

- (IBAction)ownerPopUpAction:(id)sender
{
  if ([sender indexOfSelectedItem] == OWNER_NO_VALUE) {
    [ownerField setStringValue: @""];
  }
}

- (IBAction)crDatePopUpAction:(id)sender
{
  if ([sender indexOfSelectedItem] == CREATE_NO_VALUE) {
    [crDateField setStringValue: @""];
  }
}

- (IBAction)crDateStepperAction:(id)sender
{
}

- (IBAction)modDatePopUpAction:(id)sender
{
  if ([sender indexOfSelectedItem] == MODIF_NO_VALUE) {
    [modDateField setStringValue: @""];
  }
}

- (IBAction)modDateStepperAction:(id)sender
{
}

- (IBAction)choseFile:(id)sender
{
  id cell = [foundMatrix selectedCell]; 
  
  if (cell) {
    NSString *path = [cell stringValue];
 
    [selectFileView activateForFileAtPath: path]; 
    [gw setSelectedPaths: [NSArray arrayWithObject: path]]; 
  }
}

- (IBAction)openFile:(id)sender
{
  id cell = [foundMatrix selectedCell]; 
  
  if (cell) {
    NSString *path = [cell stringValue];
 
    [selectFileView activateForFileAtPath: path]; 
    [gw openSelectedPaths: [NSArray arrayWithObject: path] newViewer: NO];
  }
}

- (void)tile
{
  float sph, opsph;
  NSRect shr, clr;
  NSRect lwr, scrr;
  
  sph = [split frame].size.height;
  shr = [shelfBox frame];
  lwr = [lowBox frame];
    
  shr.size.height = shelfHeight;
  shr.origin.y = sph - shelfHeight;
  [shelfBox setFrame: shr];
  [shelf setFrame: [[shelfBox contentView] frame]];

  lwr.size.height = sph - (shelfHeight + [split dividerThickness]);
  lwr.origin.y = 0;
  [lowBox setFrame: lwr];

  [split adjustSubviews];  

  opsph = [optionsSplit frame].size.height;
  clr = [closableBox frame];
  scrr = [scrollBox frame];

  clr.size.height = optionsHeight;
  clr.origin.y = opsph - optionsHeight;
  [closableBox setFrame: clr];

  scrr.size.height = opsph - (optionsHeight + [optionsSplit dividerThickness]);
  scrr.origin.y = 0;
  [scrollBox setFrame: scrr];

  [optionsSplit adjustSubviews];  
  
  [shelf resizeWithOldSuperviewSize: [shelf frame].size];  
}

- (void)updateIcons
{
  [shelf updateIcons];
}

- (void)checkIconsAfterHidingOfPaths:(NSArray *)hpaths
{
  [shelf checkIconsAfterHidingOfPaths: hpaths];
}

- (float)splitView:(NSSplitView *)sender
          constrainSplitPosition:(float)proposedPosition 
                                        ofSubviewAt:(int)offset
{
  if (sender == split) {
    if (proposedPosition < SHELF_COLLAPSE_LIMIT) {
      shelfHeight = MIN_SHELF_HEIGHT;
    } else if (proposedPosition <= SHELF_MID_LIMIT) {  
      shelfHeight = MID_SHELF_HEIGHT;
    } else {
      if (optionsClosed == NO) {
        shelfHeight = MAX_SHELF_HEIGHT;
      } else {
        shelfHeight = MID_SHELF_HEIGHT;
      }
    }

    return shelfHeight;
    
  } else if (sender == optionsSplit) {
    if (proposedPosition < OPTIONS_COLLAPSE_LIMIT) {
      optionsHeight = MIN_OPTIONS_HEIGHT;
      optionsClosed = YES;
      [fWin setMinSize: NSMakeSize(WIN_MIN_W, WIN_MIN_H_NO_OPT)];
      [self initOptions];
    } else {
      optionsHeight = MAX_OPTIONS_HEIGHT;
      optionsClosed = NO;
      [fWin setMinSize: NSMakeSize(WIN_MIN_W, WIN_MIN_H_OPT)];
    }
    
    return optionsHeight;
  }
    
  return proposedPosition;
}

- (float)splitView:(NSSplitView *)sender 
                  constrainMaxCoordinate:(float)proposedMax 
                                        ofSubviewAt:(int)offset
{
  if (sender == split) {
    if (proposedMax >= MAX_SHELF_HEIGHT) {
      if (optionsClosed == NO) {
        return MAX_SHELF_HEIGHT;
      } else {
        return MID_SHELF_HEIGHT;
      }
    }
  } else if (sender == optionsSplit) {
    if (proposedMax >= MAX_OPTIONS_HEIGHT) {
      return MAX_OPTIONS_HEIGHT;
    }
  }
   
  return proposedMax;
}

- (float)splitView:(NSSplitView *)sender 
                  constrainMinCoordinate:(float)proposedMin 
                                          ofSubviewAt:(int)offset
{
  if (sender == split) {
    if (proposedMin <= MIN_SHELF_HEIGHT) {
      return MIN_SHELF_HEIGHT;
    }
  } else if (sender == optionsSplit) {
    if (proposedMin <= MIN_OPTIONS_HEIGHT) {
      return MIN_OPTIONS_HEIGHT;
    }
  }
  
  return proposedMin;
}

- (void)splitView:(NSSplitView *)sender 
                  resizeSubviewsWithOldSize:(NSSize)oldSize
{
  [self tile];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
  [shelf setFrame: [[shelfBox contentView] frame]];
  [shelf resizeWithOldSuperviewSize: [shelf frame].size];  
  [foundMatrix setCellSize: NSMakeSize([scrollView contentSize].width, CELLS_HEIGHT)];
  [foundMatrix sizeToCells];  
  [foundMatrix setNeedsDisplay: YES];           
}

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
  if (foundMatrix) {
    id cell = [foundMatrix selectedCell]; 
    
    if (cell) {
      [gw setSelectedPaths: [NSArray arrayWithObject: [cell stringValue]]]; 
    }
  }  
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	return YES;
}

- (void)updateDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];		
  NSMutableDictionary *myPrefs;
  NSArray *shelfDicts;
  NSString *shHeight;

	if ([fWin isVisible]) {
  	[fWin saveFrameUsingName: @"Finder"];
	}
	
  myPrefs = [NSMutableDictionary dictionaryWithCapacity: 1];
  
  shelfDicts = [shelf iconsDicts];
  [myPrefs setObject: shelfDicts forKey: @"shelfdicts"];

  shHeight = [NSString stringWithFormat: @"%i", (int)[shelf frame].size.height];
  [myPrefs setObject: shHeight forKey: @"shelfheight"];

  [myPrefs setObject: [NSNumber numberWithInt: (int)optionsClosed] 
                                       forKey: @"optclosed"];

	[defaults setObject: myPrefs forKey: @"finderprefs"];
	[defaults synchronize];
}

- (NSWindow *)myWin
{
  return fWin;
}

//
// FinderShelf delegate methods
//
- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths
{
  [self clearLastFound];
  ASSIGN (currentSelection, paths);  
}

- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths
              animateImage:(NSImage *)image startingAtPoint:(NSPoint)startp
{
  [self clearLastFound];
  ASSIGN (currentSelection, paths);
}

- (void)shelf:(Shelf *)sender mouseDown:(NSEvent *)theEvent                                       
{
  DESTROY (currentSelection);
}

@end
