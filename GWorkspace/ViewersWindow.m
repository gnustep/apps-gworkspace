/* ViewersWindow.m
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
#include "GWNotifications.h"
#include "ViewersProtocol.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/ViewersProtocol.h>
  #endif
#include "ViewersWindow.h"
#include "GWSplitView.h"
#include "Shelf/Shelf.h"
#include "IconViewsIcon.h"
#include "History/History.h"
#include "GWorkspace.h"
#include "GNUstep.h"

#define SETRECT(o, x, y, w, h) { \
NSRect rct = NSMakeRect(x, y, w, h); \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0; \
[o setFrame: rct]; \
}

#ifdef GNUSTEP 
  #define MIN_SHELF_HEIGHT 2
  #define MID_SHELF_HEIGHT 77
  #define MAX_SHELF_HEIGHT 150
  #define COLLAPSE_LIMIT 35
  #define MID_LIMIT 110
#else
  #define MIN_SHELF_HEIGHT 2
  #define MID_SHELF_HEIGHT 60
  #define MAX_SHELF_HEIGHT 120
  #define COLLAPSE_LIMIT 23
  #define MID_LIMIT 85
#endif

#define DEFAULT_WIDTH 150
#define DEFAULT_ICONS_WIDTH 120

@implementation ViewersWindow

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE (shelf);
  RELEASE (viewer);
  RELEASE (mainview);
  RELEASE (rootPath);
	RELEASE (selectedPaths);
	RELEASE (viewers);
  RELEASE (viewerTemplates);
  RELEASE (viewType);
	RELEASE (ViewerHistory);
  [super dealloc];
}

- (id)initWithViewerTemplates:(NSArray *)templates 
                      forPath:(NSString *)path 
			            viewPakages:(BOOL)canview
			           isRootViewer:(BOOL)rootviewer
                      onStart:(BOOL)onstart
{
  unsigned int style;

  if (rootviewer == NO) {
    style = NSTitledWindowMask | NSClosableWindowMask 
				         | NSMiniaturizableWindowMask | NSResizableWindowMask;
  } else {
    style = NSTitledWindowMask | NSMiniaturizableWindowMask 
                                          | NSResizableWindowMask;
  }

  self = [super initWithContentRect: NSZeroRect styleMask: style
                               backing: NSBackingStoreBuffered defer: NO];

  if (self) {
    NSUserDefaults *defaults;
    NSMutableDictionary *viewersPrefs = nil;
    NSMutableDictionary *myPrefs = nil;
    NSArray *shelfDicts;
    id dictEntry, defEntry;
    NSString *viewedPath = nil;
    NSMutableArray *selection = nil;
		float shfwidth = 0.0;   
		BOOL isDirDict = NO;
    
		gw = [GWorkspace gworkspace];
  	fm = [NSFileManager defaultManager];
		
		[self setReleasedWhenClosed: NO];
    
    defaults = [NSUserDefaults standardUserDefaults];	
        
    defEntry = [defaults objectForKey: @"browserColsWidth"];
    if (defEntry) {
      resizeIncrement = [defEntry intValue];
    } else {
      resizeIncrement = DEFAULT_WIDTH;
    }

    defEntry = [defaults objectForKey: @"iconsCellsWidth"];
    if (defEntry) {
      iconCellsWidth = [defEntry intValue];
    } else {
      iconCellsWidth = DEFAULT_ICONS_WIDTH;
    }
        
    [self setMinSize: NSMakeSize(resizeIncrement * 2, 250)];    
    [self setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

    isRootViewer = rootviewer;
		
    if (isRootViewer || [path isEqual: fixPath(@"/", 0)]) {
      [self setTitle: NSLocalizedString(@"File Viewer", @"")];
    } else {
			NSString *pth = [path stringByDeletingLastPathComponent];
			NSString *nm = [path lastPathComponent];
			NSString *title = [NSString stringWithFormat: @"%@ - %@", nm, pth];
      [self setTitle: title];   
    }
		    
		ASSIGN (rootPath, path);  
		selectedPaths = [[NSArray alloc] initWithObjects: path, nil];
  	viewsapps = canview;
		ViewerHistory = [[NSMutableArray alloc] init];
		[ViewerHistory addObject: path];
		currHistoryPos = 0;

    if ([fm isWritableFileAtPath: rootPath] 
                       && (isRootViewer == NO) 
                       && ([rootPath isEqual: fixPath(@"/", 0)] == NO)) {
		  NSString *dictPath = [rootPath stringByAppendingPathComponent: @".gwdir"];
    
      if ([fm fileExistsAtPath: dictPath]) {
        NSDictionary *dirDict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
       
        if (dirDict) {
          myPrefs = [dirDict mutableCopy];
          isDirDict = YES; 
        }   
      }
    }

    if (isDirDict == NO) {
      defEntry = [defaults dictionaryForKey: @"viewersprefs"];
      if (defEntry) { 
 		    viewersPrefs = [defEntry mutableCopy];
      } else {
        viewersPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
      }

      if (isRootViewer || [rootPath isEqual: fixPath(@"/", 0)]) {
        defEntry = [viewersPrefs objectForKey: @"rootViewer"];
      } else {
        defEntry = [viewersPrefs objectForKey: rootPath];
      }
      if (defEntry) { 
 		    myPrefs = [defEntry mutableCopy];
      } else {
        myPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
      }
    }
    
    if (isDirDict) {
      NSString *frameStr = [myPrefs objectForKey: @"geometry"];
    
      if (frameStr) {
        [self setFrameFromString: frameStr];
      } else if ([self setFrameUsingName: [NSString stringWithFormat: @"Viewer at %@", path]] == NO) {
        [self setFrame: NSMakeRect(200, 200, resizeIncrement * 3, 500) display: NO];
      }    
      
    } else {
      if (isRootViewer == NO) {
        if ([self setFrameUsingName: [NSString stringWithFormat: @"Viewer at %@", path]] == NO) {
          if ([rootPath isEqual: fixPath(@"/", 0)]) {
            if ([self setFrameUsingName: @"rootViewer"] == NO) {
              [self setFrame: NSMakeRect(200, 200, resizeIncrement * 3, 500) display: NO];
            } else {
              NSPoint fop = [self frame].origin;
              fop.x += 30;
              fop.y -= 30;
              [self setFrameOrigin: fop];
            }
          } else {
            [self setFrame: NSMakeRect(200, 200, resizeIncrement * 3, 500) display: NO];
          }
        }  
      } else {
        if ([self setFrameUsingName: @"rootViewer"] == NO) {
          [self setFrame: NSMakeRect(200, 200, resizeIncrement * 3, 500) display: NO];
        }      
      } 
    }
    
    if ((isRootViewer == NO) && [rootPath isEqual: fixPath(@"/", 0)]) {    
      RELEASE (myPrefs);
    
      defEntry = [viewersPrefs objectForKey: rootPath];
    
      if (defEntry) { 
 		    myPrefs = [defEntry mutableCopy];
      } else {
        myPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
      }
    }

		/* ************* */
		/*     shelf     */
		/* ************* */
		shfwidth = [[self contentView] frame].size.width;
		
    dictEntry = [myPrefs objectForKey: @"shelfdicts"];      
    if(dictEntry) {
      shelfDicts = [NSArray arrayWithArray: dictEntry];      
    } else {
			NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      NSArray *arr;

      if (isRootViewer || [rootPath isEqual: fixPath(@"/", 0)]) {
        arr = [NSArray arrayWithObject: NSHomeDirectory()];
      } else {         
        arr = [NSArray arrayWithObject: rootPath]; 
      }
			
			[dict setObject: arr forKey: @"paths"];
			[dict setObject: @"0" forKey: @"index"];
						       
      shelfDicts = [NSArray arrayWithObject: dict];         		
    }
    [myPrefs setObject: shelfDicts forKey: @"shelfdicts"];      

    shelf = [[Shelf alloc] initWithIconsDicts: shelfDicts rootPath: rootPath];
    dictEntry = [myPrefs objectForKey: @"shelfheight"];

    if(dictEntry) {
      shelfHeight = [dictEntry intValue];
    } else {
      shelfHeight = MID_SHELF_HEIGHT;
    }

    SETRECT (shelf, 0, 0, shfwidth, shelfHeight); 
    		
    [shelf setDelegate: self];
    [shelf setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];

		/* ************* */
		/*    viewer     */
		/* ************* */
    dictEntry = [myPrefs objectForKey: @"viewtype"];
    if(dictEntry) {
			[self makeViewersWithTemplates: templates type: dictEntry];
    } else {
			[self makeViewersWithTemplates: templates type: nil];
    }
    [myPrefs setObject: viewType forKey: @"viewtype"];

    if (onstart) {
      dictEntry = [myPrefs objectForKey: @"viewedpath"];

      if (dictEntry) {
        viewedPath = [NSString stringWithString: dictEntry];
      } else {
        viewedPath = nil;
      }

      dictEntry = [myPrefs objectForKey: @"lastselection"];

      if (dictEntry) {
        int i, count;

        selection = [dictEntry mutableCopy];

        count = [selection count];      
        for (i = 0; i < count; i++) {
          NSString *s = [selection objectAtIndex: i];

          if ([fm fileExistsAtPath: s] == NO){
            [selection removeObject: s];
            count--;
            i--;
          }
        }

        if ([selection count] == 0) {
          RELEASE (selection);
          selection = nil;
        }

      } else {
        selection = nil;
      }
    } else {
      viewedPath = nil;
      selection = nil;
    }
    
		[viewer setRootPath: rootPath 
         viewedPath: viewedPath
          selection: selection 
           delegate: self 
           viewApps: viewsapps];
               
    TEST_RELEASE (selection);
    
    if ([fm isWritableFileAtPath: rootPath] 
                      && (isRootViewer == NO)
                      && ([rootPath isEqual: fixPath(@"/", 0)] == NO)) {
      NSString *dictPath = [rootPath stringByAppendingPathComponent: @".gwdir"];
      [myPrefs writeToFile: dictPath atomically: YES];
    } else {
      if (isRootViewer == NO) {
	      [viewersPrefs setObject: myPrefs forKey: rootPath];
      } else {
        [viewersPrefs setObject: myPrefs forKey: @"rootViewer"];
      }
	    [defaults setObject: viewersPrefs forKey: @"viewersprefs"];
      [defaults synchronize];    
      RELEASE (viewersPrefs);     
    }

    RELEASE (myPrefs);

		/* ************* */
		/*   mainview    */
		/* ************* */
		if ([viewer usesShelf] == YES) {
			usingSplit = YES;
    	mainview = [[GWSplitView alloc] initWithFrame: [[self contentView] frame] viewer: self];
    	[mainview setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
    	[mainview setDelegate: self];
			[mainview addSubview: shelf];
		
		} else {
			usingSplit = NO;
    	mainview = [[NSView alloc] initWithFrame: [[self contentView] frame]];
    	[mainview setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
			[mainview setPostsFrameChangedNotifications: YES];
		}
		
    [mainview addSubview: viewer];
		[[self contentView] addSubview: mainview];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(viewersListDidChange:) 
                					    name: GWViewersListDidChangeNotification
                					  object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(browserCellsIconsDidChange:) 
                					    name: GWBrowserCellsIconsDidChangeNotification
                					  object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(viewersUseShelfDidChange:) 
                					    name: GWViewersUseShelfDidChangeNotification
                					  object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(columnsWidthChanged:) 
                					    name: GWBrowserColumnWidthChangedNotification
                					  object: nil];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(viewFrameDidChange:) 
                					    name: NSViewFrameDidChangeNotification
                					  object: nil];

  	[mainview resizeWithOldSuperviewSize: [mainview frame].size]; 
		
		[self adjustSubviews];	
    
    [self makeFirstResponder: [viewer viewerView]];  
  }
  
  return self;
}

- (void)makeViewersWithTemplates:(NSArray *)templates type:(NSString *)vtype
{
	NSMenu *menu;
	BOOL found;
	int i;

  ASSIGN (viewerTemplates, templates);

	TEST_RELEASE (viewers);
	viewers = [[NSMutableArray alloc] initWithCapacity: 1];

  for (i = 0; i < [templates count]; i++) {
    NSDictionary *dict = [templates objectAtIndex: i];	
		id<ViewersProtocol> vwr = [[dict objectForKey: @"viewer"] copy];
		[viewers addObject: vwr];
		RELEASE ((id)vwr);
  }

	menu = [[[NSApp mainMenu] itemWithTitle: NSLocalizedString(@"View", @"")] submenu];

	while (1) {
  	if ([menu numberOfItems] == 0) {
    	break;
  	}
  	[menu removeItemAtIndex: 0];
	}

	found = NO;
	
	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];
		NSString *menuName = [vwr menuName];
		NSString *shortCut = [vwr shortCut];
		
		addItemToMenu(menu, menuName, @"", @"setViewerType:", shortCut);
		
		if (vtype && [vtype isEqualToString: menuName]) {
			ASSIGN (viewType, menuName);
			ASSIGN (viewer, (id<ViewersProtocol>)vwr);			
			found = YES;
		}
	}
	
	if (found == NO) {
		ASSIGN (viewer, (id<ViewersProtocol>)[viewers objectAtIndex: 0]);
		ASSIGN (viewType, [viewer menuName]);
	}
	
	[self setMiniwindowImage: [viewer miniicon]];
}

- (void)changeViewer:(NSString *)newViewType
{
  NSArray *selPaths;
  NSString *viewedPath = nil;
  NSString *currentViewedPath = nil;  
  NSString *selpath;  
	NSRect r;
      
  if (isRootViewer || [rootPath isEqual: fixPath(@"/", 0)]) {
    [self setTitle: NSLocalizedString(@"File Viewer", @"")];
  } else {
		NSString *pth = [rootPath stringByDeletingLastPathComponent];
		NSString *nm = [rootPath lastPathComponent];
		NSString *title = [NSString stringWithFormat: @"%@ - %@", nm, pth];
    [self setTitle: title];   
  }
  
  currentViewedPath = [viewer currentViewedPath]; 
  if (currentViewedPath) {
    viewedPath = RETAIN (currentViewedPath);
  }
  
  selpath = [selectedPaths objectAtIndex: 0];  
  if ((subPathOfPath(rootPath, selpath)) || ([rootPath isEqual: selpath])) {
    selPaths = [[NSArray alloc] initWithArray: selectedPaths];
  } else {
    selPaths = [[NSArray alloc] initWithObjects: rootPath, nil];   
  }
   
  r = [[self contentView] frame];
  [viewer removeFromSuperview];
	[self makeViewersWithTemplates: viewerTemplates type: newViewType];  
  
  [viewer setRootPath: rootPath 
           viewedPath: viewedPath
            selection: selPaths 
             delegate: self 
             viewApps: viewsapps];
	
  TEST_RELEASE (viewedPath);
  
	if (([viewer usesShelf] == YES) && (usingSplit == NO)) {
		usingSplit = YES;
		[mainview removeFromSuperview];		
		RELEASE (mainview);
		mainview = [[GWSplitView alloc] initWithFrame: r viewer: self];
		[mainview setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
		[mainview setDelegate: self];
		[mainview addSubview: shelf];
    [mainview addSubview: viewer];
		[[self contentView] addSubview: mainview];

	} else if (([viewer usesShelf] == NO) && (usingSplit == YES)) {	
		usingSplit = NO;
		[shelf removeFromSuperview];
		[mainview removeFromSuperview];
		RELEASE (mainview);
		mainview = [[NSView alloc] initWithFrame: r];
    [mainview setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
		[mainview setPostsFrameChangedNotifications: YES];
    [mainview addSubview: viewer];
		[[self contentView] addSubview: mainview];
	
	} else {
  	[mainview addSubview: viewer];                
	}
	
	[self adjustSubviews];
  
  [self makeFirstResponder: [viewer viewerView]]; 
  
	RELEASE (selPaths);
}

- (id)viewer
{
	return viewer;
}

- (void)adjustSubviews
{
  NSRect r = [mainview frame];
  float w = r.size.width;
	float h = r.size.height;   
	
	if (usingSplit == NO) {
		SETRECT (viewer, 8, 0, w - 16, h);
  	[viewer resizeWithOldSuperviewSize: [viewer frame].size]; 
	
	} else {
		float sh = [shelf frame].size.height;
		float d = [mainview dividerThickness];
		
  	if (sh < COLLAPSE_LIMIT) {
    	shelfHeight = MIN_SHELF_HEIGHT;
  	} else if (sh <= MID_LIMIT) {  
    	shelfHeight = MID_SHELF_HEIGHT;
  	} else {
    	shelfHeight = MAX_SHELF_HEIGHT;
  	}

		SETRECT (shelf, 0, 0, r.size.width, shelfHeight);
  	[shelf resizeWithOldSuperviewSize: [shelf frame].size]; 

		SETRECT (viewer, 8, shelfHeight + d, w - 16, h - shelfHeight - d);
  	[viewer resizeWithOldSuperviewSize: [viewer frame].size]; 
	}
}

- (void)viewFrameDidChange:(NSNotification *)notification
{
	if ((NSView *)[notification object] == mainview) {
  	[self adjustSubviews];
	}
}

- (void)setSelectedPaths:(NSArray *)paths
{
	ASSIGN (selectedPaths, paths);
}

- (NSPoint)positionForSlidedImage
{
  return [viewer positionForSlidedImage];
}

- (NSString *)rootPath
{
  return rootPath;
}

- (void)checkRootPathAfterHidingOfPaths:(NSArray *)hpaths
{
  [self tuneHistory];
  
  if (shelf) {
    [shelf checkIconsAfterHidingOfPaths: hpaths];
  }
  
  [viewer checkRootPathAfterHidingOfPaths: hpaths];
}

- (NSString *)currentViewedPath
{  
  return [viewer currentViewedPath];
}

- (void)activate
{
  [self makeKeyAndOrderFront: nil];
}

- (void)viewersListDidChange:(NSNotification *)notification
{
  ASSIGN (viewerTemplates, (NSArray *)[notification object]);
  [self changeViewer: viewType];
}

- (void)browserCellsIconsDidChange:(NSNotification *)notification
{
  [self changeViewer: viewType];
}

- (void)viewersUseShelfDidChange:(NSNotification *)notification
{
  [self changeViewer: viewType];
}

- (void)columnsWidthChanged:(NSNotification *)notification
{
  NSRect r = [self frame];
  float x = r.origin.x;
	float y = r.origin.y;
	float w = r.size.width;
	float h = r.size.height;
  int columnsWidth = [(NSNumber *)[notification object] intValue];
  int columns = (int)(w / resizeIncrement); 

  resizeIncrement = columnsWidth;
     
  [viewer setAutoSynchronize: NO];
     
  [self setFrame: NSMakeRect(x, y, (columns * columnsWidth), h) display: YES];  
  [self setMinSize: NSMakeSize(resizeIncrement * 2, 250)];    
  [self setResizeIncrements: NSMakeSize(resizeIncrement, 1)];

  [viewer setResizeIncrement: columnsWidth];
  [viewer setAutoSynchronize: YES];
  [mainview setNeedsDisplay: YES]; 
}

- (void)thumbnailsDidChangeInPaths:(NSArray *)paths
{
  [viewer thumbnailsDidChangeInPaths: paths];
  [shelf updateIcons];
}

- (NSString *)viewType
{
  return viewType;
}

- (BOOL)viewsApps
{
  return viewsapps;
}

- (void)setViewerSelection:(NSArray *)selPaths
{
  [viewer setCurrentSelection: selPaths];
	
	if ([selPaths count] == 1) {
		[self addToHistory: [selPaths objectAtIndex: 0]];
	}
}

- (void)updateInfoString
{
  NSString *path;
  NSDictionary *attributes;
	NSNumber *freeFs;
  NSString *infoString;
  
	if (usingSplit == NO) {
		return;
	}
	
  path = [[viewer selectedPaths] objectAtIndex: 0];
	attributes = [fm fileSystemAttributesAtPath: path];
	freeFs = [attributes objectForKey: NSFileSystemFreeSize];
  
	if(freeFs == nil) {  
		infoString = [NSString stringWithString: NSLocalizedString(@"unknown volume size", @"")];    
	} else {
		infoString = [NSString stringWithFormat: @"%@ %@", 
                      fileSizeDescription([freeFs unsignedLongLongValue]),
                            NSLocalizedString(@"available on hard disk", @"")];
	}
  
  [mainview updateDiskSpaceInfo: infoString];
}

- (void)selectAll
{
  [viewer selectAll];
}

- (void)updateDefaults
{
	NSUserDefaults *defaults = nil;
  NSMutableDictionary *viewersPrefs = nil;
  NSMutableDictionary *myPrefs = nil;
  NSMutableArray *shelfDicts;
  NSString *shHeight;
  NSString *viewedPath;
  NSArray *selection;

  if ([fm isWritableFileAtPath: rootPath] 
                      && (isRootViewer == NO)
                      && ([rootPath isEqual: fixPath(@"/", 0)] == NO)) {
    myPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
    [myPrefs setObject: [self stringWithSavedFrame] forKey: @"geometry"];
  
  } else {
    id dictEntry;
    
    if (isRootViewer == NO) {
      [self saveFrameUsingName: [NSString stringWithFormat: @"Viewer at %@", rootPath]];
    } else {
      [self saveFrameUsingName: @"rootViewer"];
    }
    
    defaults = [NSUserDefaults standardUserDefaults];	
    viewersPrefs = [[defaults dictionaryForKey: @"viewersprefs"] mutableCopy];
	
    if (isRootViewer == NO) {
      dictEntry = [viewersPrefs objectForKey: rootPath];
    } else {
      dictEntry = [viewersPrefs objectForKey: @"rootViewer"];
    }
    
    if (dictEntry) { 
 		  myPrefs = [dictEntry mutableCopy];
    } else {
      myPrefs = [[NSMutableDictionary alloc] initWithCapacity: 1];
    }
  }
  
  [myPrefs setObject: viewType forKey: @"viewtype"];

  shHeight = [NSString stringWithFormat: @"%i", (int)[shelf frame].size.height];
  [myPrefs setObject: shHeight forKey: @"shelfheight"];

  shelfDicts = [[shelf iconsDicts] mutableCopy];
  if ([shelfDicts count] == 0) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];
		NSArray *arr = [NSArray arrayWithObject: NSHomeDirectory()];
		
		[dict setObject: arr forKey: @"paths"];
		[dict setObject: @"1" forKey: @"index"];
		
    [shelfDicts addObject: dict];
  }      
  [myPrefs setObject: shelfDicts forKey: @"shelfdicts"];
  
  viewedPath = [viewer currentViewedPath];
  if (viewedPath) {
    [myPrefs setObject: viewedPath forKey: @"viewedpath"];
  }
  
  selection = [viewer selectedPaths];
  if (selection) {
    [myPrefs setObject: selection forKey: @"lastselection"];
  }

  if ([fm isWritableFileAtPath: rootPath] 
                      && (isRootViewer == NO)
                      && ([rootPath isEqual: fixPath(@"/", 0)] == NO)) {
    NSString *dictPath = [rootPath stringByAppendingPathComponent: @".gwdir"];

    [myPrefs writeToFile: dictPath atomically: YES];

  } else {
    if (isRootViewer == NO) {
	    [viewersPrefs setObject: myPrefs forKey: rootPath];
    } else {
	    [viewersPrefs setObject: myPrefs forKey: @"rootViewer"];
    }
	  [defaults setObject: viewersPrefs forKey: @"viewersprefs"];
	  [defaults synchronize];
    RELEASE (viewersPrefs);
  }
  
  RELEASE (myPrefs);
  RELEASE (shelfDicts);
}

- (void)keyDown:(NSEvent *)theEvent 
{
	NSString *characters = [theEvent characters];
	unichar character = 0;
		
  if ([characters length] > 0) {
		character = [characters characterAtIndex: 0];
	}
		
	switch (character) {
    case NSLeftArrowFunctionKey:
			if ([theEvent modifierFlags] & NSControlKeyMask) {
				[self goBackwardInHistory: nil];
			}
      return;

    case NSRightArrowFunctionKey:			
			if ([theEvent modifierFlags] & NSControlKeyMask) {
	      [self goForwardInHistory: nil];
	    } 
			return;
	}
	
	[super keyDown: theEvent];
}

- (void)becomeMainWindow
{
  [super becomeMainWindow];
}

- (void)becomeKeyWindow
{
  [super becomeKeyWindow];
  
  if (viewer) {
    NSArray *selPaths = [viewer selectedPaths];
    
    if (selPaths) {
	    ASSIGN (selectedPaths, selPaths);
      [gw setSelectedPaths: selPaths];
	    historyWin = [gw historyWindow];
	    [historyWin setViewer: self];
	    [self tuneHistory];
	    [historyWin setHistoryPaths: ViewerHistory];
	    [self setCurrentHistoryPosition: currHistoryPos];
      [self updateInfoString]; 

      if (viewer && [viewer viewerView]) {
        [self makeFirstResponder: [viewer viewerView]];  
      }
    }
  }
}

- (BOOL)windowShouldClose:(id)sender
{
  if (self != [gw rootViewer]) {
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [viewer unsetWatchers]; 
		[historyWin setHistoryPaths: nil];
		[historyWin setViewer: nil];
  }
    
  [self updateDefaults];
  return YES;
}

- (void)close
{
  [super close];
  [gw viewerHasClosed: self]; 
}

//
// Menu operations
//
- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{	
	if ([[menuItem title] isEqualToString: NSLocalizedString(viewType, @"")]) {
		return NO;
	}
	
	if ([[menuItem title] isEqualToString: NSLocalizedString(@"Go forward", @"")]) {
		if ([ViewerHistory count] <= 1) {
			return NO;
		}
	  if (currHistoryPos < ([ViewerHistory count] - 1)) {
			return YES;
		} else {
			return NO;
		}
	}
	
	if ([[menuItem title] isEqualToString: NSLocalizedString(@"Go backward", @"")]) {
		if ([ViewerHistory count] <= 1) {
			return NO;
		}
	  if (currHistoryPos > 0) {
			return YES;
		}	else {
			return NO;
		}
	}
	
	return YES;
}

- (void)openSelection:(id)sender
{
	[gw openSelectedPaths: selectedPaths newViewer: NO];
}

- (void)openSelectionAsFolder:(id)sender
{
  [gw openSelectedPaths: selectedPaths newViewer: YES];
}

- (void)newFolder:(id)sender
{
  [gw newObjectAtPath: [self currentViewedPath] isDirectory: YES];
}

- (void)newFile:(id)sender
{
  [gw newObjectAtPath: [self currentViewedPath] isDirectory: NO];
}

- (void)duplicateFiles:(id)sender
{
	[gw duplicateFiles];
}

- (void)deleteFiles:(id)sender
{
	[gw deleteFiles];
}

- (void)setViewerType:(id)sender
{
	NSString *title = [sender title];
	int i;

	if ([NSLocalizedString(viewType, @"") isEqualToString: title]) {
    return;
  }

	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];
		NSString *vwrName = [vwr menuName];
	
		if ([title isEqualToString: NSLocalizedString(vwrName, @"")]) {
			[self changeViewer: vwrName];
			break;
		}
	}
}

- (void)selectAllInViewer:(id)sender
{
	[viewer selectAll];
}

- (void)miniaturize:(id)sender
{
  if (selectedPaths && [selectedPaths count]) {
    if ([selectedPaths count] == 1) {
      NSString *path = [selectedPaths objectAtIndex: 0];
      NSString *defApp, *type;
    
	    [[NSWorkspace sharedWorkspace] getInfoForFile: path 
															          application: &defApp 
																		           type: &type]; 
      [self setMiniwindowImage: [GWLib iconForFile: path ofType: type]];
      [self setMiniwindowTitle: [path lastPathComponent]];
    } else {
      NSString *minititle = [NSString stringWithFormat: @"%i %@", 
                    [selectedPaths count], NSLocalizedString(@"elements", @"")];
      
      [self setMiniwindowTitle: minititle];
      [self setMiniwindowImage: [NSImage imageNamed: @"MultipleSelection.tiff"]];
    }
  }
  
  [super miniaturize: sender];
}

- (void)deminiaturize:(id)sender
{
  [super deminiaturize: sender];
  [self setMiniwindowImage: [viewer miniicon]];
}

- (void)showTerminal:(id)sender
{
  NSString *path = [viewer currentViewedPath];
  
  if (path == nil) {
    if ([selectedPaths count] > 1) {
      path = [[selectedPaths objectAtIndex: 0] stringByDeletingLastPathComponent];
    
    } else {
      BOOL isdir;
    
      path = [selectedPaths objectAtIndex: 0];
      [fm fileExistsAtPath: path isDirectory: &isdir]; 
         
      if (isdir == NO) {
        path = [path stringByDeletingLastPathComponent];
      }
    }
	}
  
	[gw startXTermOnDirectory: path];
}

- (void)print:(id)sender
{
	[super print: sender];
}


//
// splitView delegate methods
//
- (float)splitView:(NSSplitView *)sender
          constrainSplitPosition:(float)proposedPosition 
                                        	ofSubviewAt:(int)offset
{
  if (proposedPosition < COLLAPSE_LIMIT) {
    shelfHeight = MIN_SHELF_HEIGHT;
  } else if (proposedPosition <= MID_LIMIT) {  
    shelfHeight = MID_SHELF_HEIGHT;
  } else {
    shelfHeight = MAX_SHELF_HEIGHT;
  }
  
  return shelfHeight;
}

- (float)splitView:(NSSplitView *)sender 
                  constrainMaxCoordinate:(float)proposedMax 
                                        ofSubviewAt:(int)offset
{
  if (proposedMax >= MAX_SHELF_HEIGHT) {
    return MAX_SHELF_HEIGHT;
  }
  
  return proposedMax;
}

- (float)splitView:(NSSplitView *)sender 
                  constrainMinCoordinate:(float)proposedMin 
                                          ofSubviewAt:(int)offset
{
  if (proposedMin <= MIN_SHELF_HEIGHT) {
    return MIN_SHELF_HEIGHT;
  }
  
  return proposedMin;
}

- (void)splitView:(NSSplitView *)sender 
                  resizeSubviewsWithOldSize:(NSSize)oldSize
{
	[self adjustSubviews];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	[self adjustSubviews];
}

@end

//
// history methods
//
@implementation ViewersWindow (historyMethods)

- (void)addToHistory:(NSString *)path
{
  NSString *hpath;
	NSString *defApp, *type;
	NSArray *tempHistory;

#define SETPOSITION(p) \
if ([ViewerHistory isEqual: tempHistory] == NO) { \
[self tuneHistory]; \
if (self == [historyWin viewer]) \
[historyWin setHistoryPaths: ViewerHistory]; \
} \
[self setCurrentHistoryPosition: p]; \
RELEASE (tempHistory); \
return
	
	currHistoryPos = (currHistoryPos < 0) ? 0 : currHistoryPos;
 
	[[NSWorkspace sharedWorkspace] getInfoForFile: path 
															      application: &defApp 
																		       type: &type]; 

	if ((type != NSDirectoryFileType) && (type != NSFilesystemFileType)) {
    hpath = [path stringByDeletingLastPathComponent];
	}	else {
    hpath = path;
  }

	tempHistory = [ViewerHistory copy];
	
	if (([ViewerHistory count] - 1) == currHistoryPos) {
		if ([[ViewerHistory lastObject] isEqual: hpath] == NO) {
			[ViewerHistory addObject: hpath];
		}
		SETPOSITION ([ViewerHistory count] - 1);
  }
	
	if ([ViewerHistory count] > (currHistoryPos + 1)) {
		if (([[ViewerHistory objectAtIndex: currHistoryPos + 1] isEqual: hpath] == NO)
				&& ([[ViewerHistory objectAtIndex: currHistoryPos] isEqual: hpath] == NO)) {
	
			currHistoryPos++;
			[ViewerHistory insertObject: hpath atIndex: currHistoryPos];
			
			while ((currHistoryPos + 1) < [ViewerHistory count]) {
				int last = [ViewerHistory count] - 1;
				[ViewerHistory removeObjectAtIndex: last];
			}
			SETPOSITION (currHistoryPos);
		}	
	}
	
	if ([[ViewerHistory lastObject] isEqual: hpath]) {
		SETPOSITION ([ViewerHistory count] - 1);
	}
	
	RELEASE (tempHistory);
}

- (void)tuneHistory
{
  NSArray *hiddenPaths = [GWLib hiddenPaths];
	int i, count = [ViewerHistory count];
	BOOL changed = NO;
	
#define CHECK_POSITION(n) \
if (currHistoryPos >= i) \
currHistoryPos -= n; \
currHistoryPos = (currHistoryPos < 0) ? 0 : currHistoryPos; \
currHistoryPos = (currHistoryPos >= count) ? (count - 1) : currHistoryPos	

	for (i = 0; i < count; i++) {
		NSString *hpath = [ViewerHistory objectAtIndex: i];
		BOOL isdir;
		
		if ((([fm fileExistsAtPath: hpath isDirectory: &isdir] && isdir) == NO)
                                    || [hiddenPaths containsObject: hpath]) {
			[ViewerHistory removeObjectAtIndex: i];
			changed = YES;
			CHECK_POSITION (1);		
			count--;
			i--;
		}
	}
			
	for (i = 0; i < count; i++) {
		NSString *hpath = [ViewerHistory objectAtIndex: i];

		if (i < ([ViewerHistory count] - 1)) {
			NSString *next = [ViewerHistory objectAtIndex: i + 1];
			
			if ([next isEqual: hpath]) {
				[ViewerHistory removeObjectAtIndex: i + 1];
				changed = YES;
				CHECK_POSITION (1);
				count--;
				i--;
			}
		}
	}
	
	if ([ViewerHistory count] > 4) {
		NSString *sa[2], *sb[2];
	
		count = [ViewerHistory count];
		
		for (i = 0; i < count; i++) {
			if (i < ([ViewerHistory count] - 3)) {
				sa[0] = [ViewerHistory objectAtIndex: i];
				sa[1] = [ViewerHistory objectAtIndex: i + 1];
				sb[0] = [ViewerHistory objectAtIndex: i + 2];
				sb[1] = [ViewerHistory objectAtIndex: i + 3];
		
				if ([sa[0] isEqual: sb[0]] && [sa[1] isEqual: sb[1]]) {
					[ViewerHistory removeObjectAtIndex: i + 3];
					[ViewerHistory removeObjectAtIndex: i + 2];
					changed = YES;
					CHECK_POSITION (2);
					count -= 2;
					i--;
				}
			}
		}
	}
	
	CHECK_POSITION (0);
		
	if (changed) {
		[historyWin setHistoryPaths: ViewerHistory position: currHistoryPos];
	}
}

- (void)setCurrentHistoryPosition:(int)newPosition 
{
	int count = [ViewerHistory count];
	currHistoryPos = (newPosition < 0) ? 0 : newPosition; 			
	currHistoryPos = (newPosition >= count) ? (count - 1) : newPosition;	
	[historyWin setHistoryPosition: currHistoryPos];
}

- (void)goToHistoryPosition:(int)position
{
	[self tuneHistory];
	if ((position >= 0) && (position < [ViewerHistory count])) {
		NSString *newpath = [ViewerHistory objectAtIndex: position];
		[self setCurrentHistoryPosition: position];
		[viewer setCurrentSelection: [NSArray arrayWithObject: newpath]];
	}
}

- (void)goBackwardInHistory:(id)sender
{
	[self tuneHistory];
  if (currHistoryPos > 0) {
    NSString *newpath = [ViewerHistory objectAtIndex: (currHistoryPos - 1)];
		[self setCurrentHistoryPosition: currHistoryPos - 1];
    [viewer setCurrentSelection: [NSArray arrayWithObject: newpath]];
  }
}

- (void)goForwardInHistory:(id)sender
{
	[self tuneHistory];
  if (currHistoryPos < ([ViewerHistory count] - 1)) {
		NSString *newpath = [ViewerHistory objectAtIndex: (currHistoryPos + 1)];
		[self setCurrentHistoryPosition: currHistoryPos + 1];					
    [viewer setCurrentSelection: [NSArray arrayWithObject: newpath]];  
  } 
}

@end

//
// shelf delegate methods
//

@implementation ViewersWindow (ShelfDelegateMethods)

- (NSArray *)getSelectedPaths
{
	return selectedPaths;
}

- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths
{
	[self addPathToHistory: paths];
  [viewer setCurrentSelection: paths];
}

- (void)shelf:(Shelf *)sender setCurrentSelection:(NSArray *)paths
              animateImage:(NSImage *)image startingAtPoint:(NSPoint)startp
{
  NSPoint endp = [viewer positionForSlidedImage];

  if ((NSEqualPoints(endp, NSZeroPoint) == NO) && [gw animateChdir]) {
    [gw slideImage: image from: startp to: endp];
  }
  
	[self addPathToHistory: paths];
  [viewer setCurrentSelection: paths];
}

- (void)shelf:(Shelf *)sender openCurrentSelection:(NSArray *)paths 
    newViewer:(BOOL)newv
{
  [viewer setSelectedPaths: paths];
  [gw openSelectedPaths: paths newViewer: newv];   
}

@end

//
// Viewers Delegate Methods
//

@implementation ViewersWindow (ViewerDelegateMethods)

- (void)setTheSelectedPaths:(id)paths
{
	ASSIGN (selectedPaths, paths);
	[gw setSelectedPaths: paths];
}

- (NSArray *)selectedPaths
{
  return [gw selectedPaths];
}

- (void)setTitleAndPath:(id)apath selectedPaths:(id)paths
{
	ASSIGN (selectedPaths, paths);
	[gw setSelectedPaths: paths];
	
  if ([apath isEqualToString: fixPath(@"/", 0)]) {
    [self setTitle: NSLocalizedString(@"File Viewer", @"")];
  } else {
		NSString *pth = [apath stringByDeletingLastPathComponent];
		NSString *nm = [apath lastPathComponent];
		NSString *title = [NSString stringWithFormat: @"%@ - %@", nm, pth];
    [self setTitle: title];   
  }
}

- (void)addPathToHistory:(NSArray *)paths
{
	if ((paths == nil) || ([paths count] == 0) || ([paths count] > 1)) {
    return; 
	}
	[self addToHistory: [paths objectAtIndex: 0]];
}

- (void)updateTheInfoString
{
	[self updateInfoString];
}

- (int)browserColumnsWidth
{
  return resizeIncrement;
}

- (int)iconCellsWidth
{
  return iconCellsWidth;
}

- (int)getWindowFrameWidth
{
	return (int)[self frame].size.width;
}

- (int)getWindowFrameHeight
{
	return (int)[self frame].size.height;
}

@end
