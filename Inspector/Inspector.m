/* Inspector.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
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
#include "Inspector.h"
#include "ContentViewersProtocol.h"
#include "Preferences/InspectorPref.h"
#include "Dialogs/StartAppWin.h"
#include "Functions.h"
#include "GNUstep.h"

static Inspector *inspector = nil;
static NSString *nibName = @"Inspector";

@implementation Inspector

+ (Inspector *)inspector
{
	if (inspector == nil) {
		inspector = [[Inspector alloc] init];
	}	
  return inspector;
}

+ (void)initialize
{
	static BOOL initialized = NO;
	
	if (initialized == YES) {
		return;
  }
	
	initialized = YES;
}

- (void)dealloc
{
  if (fswatcher && [[(NSDistantObject *)fswatcher connectionForProxy] isValid]) {
    [fswatcher unregisterClient: (id <FSWClientProtocol>)self];
    DESTROY (fswatcher);
  }

  RELEASE (searchPaths);
  RELEASE (userDir);
  RELEASE (disabledDir);
  RELEASE (viewers);
  
  TEST_RELEASE (currentPath);
  
  TEST_RELEASE (genericView);
  TEST_RELEASE (noContsView);
  
  TEST_RELEASE (win);
  RELEASE (preferences);
  RELEASE (startAppWin);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    searchPaths = [NSMutableArray new];
    viewers = [NSMutableArray new];
    currentPath = nil;
    viewerTmpRef = (unsigned long)self;
    fm = [NSFileManager defaultManager];	
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
  }
  
  return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSMutableArray *bundlesPaths;
  NSString *home;
  BOOL isdir;
  id label;
  unsigned i;
  NSRect r;
     
  if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
    NSLog(@"failed to load %@!", nibName);
    [NSApp terminate: self];
  } 

  [win setFrameUsingName: @"inspector"];
  [win setTitle: NSLocalizedString(@"inspector", @"")];
  [win setDelegate: self];
  
  r = [[(NSBox *)viewersBox contentView] frame];
  preferences = [[InspectorPref alloc] initForInspector: self];
      
  home = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  ASSIGN (userDir, [home stringByAppendingPathComponent: @"Inspector"]);  
    
  if (([fm fileExistsAtPath: userDir isDirectory: &isdir] && isdir) == NO) {
    if ([fm createDirectoryAtPath: userDir attributes: nil] == NO) {
      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
             NSLocalizedString(@"Can't create the user viewers directory! Quiting now.", @""), 
                                    NSLocalizedString(@"OK", @""), nil, nil);                                     
      [NSApp terminate: self];
    }
  }

  ASSIGN (disabledDir, [userDir stringByAppendingPathComponent: @"Disabled"]);

  if (([fm fileExistsAtPath: disabledDir isDirectory: &isdir] && isdir) == NO) {
    if ([fm createDirectoryAtPath: disabledDir attributes: nil] == NO) {
      NSRunAlertPanel(NSLocalizedString(@"error", @""), 
             NSLocalizedString(@"Can't create the directory for the disabled viewers! Quiting now.", @""), 
                                    NSLocalizedString(@"OK", @""), nil, nil);                                     
      [NSApp terminate: self];
    }
  }

  [searchPaths addObject: userDir];
  [searchPaths addObject: [[NSBundle mainBundle] resourcePath]];

  bundlesPaths = [self bundlesWithExtension: @"inspector" inPath: userDir];
  [self addViewersFromBundlePaths: bundlesPaths userViewers: YES];
    
  bundlesPaths = [self bundlesWithExtension: @"inspector" 
                                     inPath: [[NSBundle mainBundle] resourcePath]];
  [self addViewersFromBundlePaths: bundlesPaths userViewers: NO];
                                     
  genericView = [[NSView alloc] initWithFrame: r];		
  MAKE_LABEL (genericField, NSMakeRect(2, 125, 254, 65), nil, 'c', YES, genericView);		  
  [genericField setFont: [NSFont systemFontOfSize: 18]];
  [genericField setTextColor: [NSColor grayColor]];				

  noContsView = [[NSView alloc] initWithFrame: r];
  MAKE_LOCALIZED_LABEL (label, NSMakeRect(2, 125, 254, 65), @"No Contents Inspector", @"", 'c', YES, noContsView);		  
  [label setFont: [NSFont systemFontOfSize: 18]];
  [label setTextColor: [NSColor grayColor]];				

  startAppWin = [[StartAppWin alloc] init];
  fswatcher = nil;
  fswnotifications = YES;
  [self connectFSWatcher];
  
  if (fswatcher) {
    for (i = 0; i < [searchPaths count]; i++) {
      [self addWatcherForPath: [searchPaths objectAtIndex: i]];
    }
  }  
  
  [win makeKeyAndOrderFront: nil];
  currentViewer = nil;
  [self showContentsAt: nil];
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
  NSMutableArray *externalVwrs = [NSMutableArray array];
  int i;

#define TEST_CLOSE(o, w) if ((o) && ([w isVisible])) [w close]
  
	for (i = 0; i < [viewers count]; i++) {
		id viewer = [viewers objectAtIndex: i];
    
    if ([viewer isExternal]) {
      [externalVwrs addObject: viewer];
    }
  }  
  
  if ([externalVwrs count]) {
    if (NSRunAlertPanel(nil,
            NSLocalizedString(@"Do you want to save the external viewers?", @""),
            NSLocalizedString(@"Yes", @""),
            NSLocalizedString(@"No", @""),
            nil)) {
      TEST_CLOSE (preferences, [preferences win]);
      [preferences removeAllViewers];
  
      for (i = 0; i < [externalVwrs count]; i++) {
        [preferences addViewer: [externalVwrs objectAtIndex: i]];
      }
    
      [preferences setSaveMode: YES];
      [NSApp runModalForWindow: [preferences win]];
    }
  }

  [self updateDefaults];

  TEST_CLOSE (startAppWin, [startAppWin win]);
  TEST_CLOSE (preferences, [preferences win]);

  if (fswatcher) {
    NSConnection *fswconn = [(NSDistantObject *)fswatcher connectionForProxy];
  
    if ([fswconn isValid]) {
      [nc removeObserver: self
	                  name: NSConnectionDidDieNotification
	                object: fswconn];
      [fswatcher unregisterClient: (id <FSWClientProtocol>)self];  
      DESTROY (fswatcher);
    }
  }
    		
	return YES;
}

- (void)addViewersFromBundlePaths:(NSArray *)bundlesPaths 
                      userViewers:(BOOL)isuservwr
{
  NSRect r = [[(NSBox *)viewersBox contentView] frame];
  int i;

  for (i = 0; i < [bundlesPaths count]; i++) {
    NSString *bpath = [bundlesPaths objectAtIndex: i];
    NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 

    if (bundle) {
			Class principalClass = [bundle principalClass];
			if ([principalClass conformsToProtocol: @protocol(ContentViewersProtocol)]) {	
	      CREATE_AUTORELEASE_POOL (pool);
        id vwr = [[principalClass alloc] initWithFrame: r inspector: self];
	  		NSString *name = [vwr winname];
        BOOL exists = NO;	
        int j;
        			
				for (j = 0; j < [viewers count]; j++) {
					if ([name isEqual: [[viewers objectAtIndex: j] winname]]) {
            NSLog(@"duplicate viewer \"%@\" at %@", name, bpath);
						exists = YES;
						break;
					}
				}

				if (exists == NO) {
          [vwr setBundlePath: bpath];     
          [vwr setIsExternal: NO];   
          [vwr setIsRemovable: isuservwr];   
          [self addViewer: vwr];            
        }

	  		RELEASE ((id)vwr);			
        RELEASE (pool);		
			}
    }
  }
}

- (NSMutableArray *)bundlesWithExtension:(NSString *)extension 
																	inPath:(NSString *)path
{
  NSMutableArray *bundleList = [NSMutableArray array];
  NSEnumerator *enumerator;
  NSString *dir;
  BOOL isDir;
  
  if ((([fm fileExistsAtPath: path isDirectory: &isDir]) && isDir) == NO) {
		return nil;
  }
	  
  enumerator = [[fm directoryContentsAtPath: path] objectEnumerator];
  while ((dir = [enumerator nextObject])) {
    if ([[dir pathExtension] isEqualToString: extension]) {
			[bundleList addObject: [path stringByAppendingPathComponent: dir]];
		}
  }
  
  return bundleList;
}

- (void)addViewer:(id)vwr
{
	[viewers addObject: vwr];
  [preferences addViewer: vwr];
}

- (void)removeViewer:(id)vwr
{
  [viewers removeObject: vwr];
  [preferences removeViewer: vwr];
  if (currentPath) {  
    [self showContentsAt: currentPath];
  }
}

- (void)disableViewer:(id)vwr
{
  NSString *vpath = [vwr bundlePath];

  if (vpath) {
    NSString *vname = [vpath lastPathComponent];
    NSString *dispath = [disabledDir stringByAppendingPathComponent: vname];
    
    if ([fm fileExistsAtPath: dispath] == NO) {
      [self removeWatcherForPath: userDir];
      
      if ([fm movePath: vpath toPath: dispath handler: nil]) {
        [self removeViewer: vwr];
      }
      
      [self addWatcherForPath: userDir];
      
    } else {
      NSRunAlertPanel(nil,
              NSLocalizedString(@"A disabled viewer with this name already exists.", @""),
              NSLocalizedString(@"Ok", @""),
              nil, 
              nil);  
    }
  } else if ([vwr isExternal]) {
    [self removeViewer: vwr];
  }
}

- (BOOL)saveExternalViewer:(id)vwr 
                  withName:(NSString *)vwrname
{
  NSString *vname = [vwrname stringByDeletingPathExtension];
  NSString *vwrpath = [userDir stringByAppendingPathComponent: vname];
  
  vwrpath = [vwrpath stringByAppendingPathExtension: @"inspector"];

  if ([fm fileExistsAtPath: vwrpath]) {
    NSRunAlertPanel(nil,
            NSLocalizedString(@"A disabled viewer with this name already exists.", @""),
            NSLocalizedString(@"Ok", @""),
            nil, 
            nil); 
  } else {
    NSData *data = [vwr dataRepresentation];

    if (data && [self writeDataRepresentation: data toPath: vwrpath]) {
      return YES;
    }
  }
  
  NSRunAlertPanel(nil,
          NSLocalizedString(@"Error saving the viewer!", @""),
          NSLocalizedString(@"Ok", @""),
          nil, 
          nil); 
   
  return NO;  
}

- (id)viewerWithBundlePath:(NSString *)path
{
	int i;
			
	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];
    NSString *bpath = [vwr bundlePath];
    		
		if(bpath && [bpath isEqual: path]) {
			return vwr;	
    }	
	}

	return nil;
}

- (id)viewerWithWindowName:(NSString *)wname
{
	int i;
			
	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];
    NSString *winname = [vwr winname];
    		
		if([winname isEqual: wname]) {
			return vwr;	
    }	
	}

	return nil;
}

- (id)viewerForPath:(NSString *)path
{
	int i;
  
  if (path == nil) {
    return nil;
  }
  
  if ([fm fileExistsAtPath: path] == NO) {
    return nil;
  }
  
	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];		
		if([vwr canDisplayPath: path]) {
			return vwr;
    }				
	}

	return nil;
}

- (id)viewerForDataOfType:(NSString *)type
{
  int i;
  
	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];		
    
    if ([vwr respondsToSelector: @selector(canDisplayDataOfType:)]) {
      if ([vwr canDisplayDataOfType: type]) {
			  return vwr;
      }
    } 				
	}
  
  return nil;
}

- (void)updateDefaults
{
  [preferences updateDefaults];
  [win saveFrameUsingName: @"inspector"];
}

- (void)connectFSWatcher
{
  if (fswatcher == nil) {
    id fsw = [NSConnection rootProxyForConnectionWithRegisteredName: @"fswatcher" 
                                                               host: @""];

    if (fsw) {
      NSConnection *c = [fsw connectionForProxy];
      
	    [nc addObserver: self
	           selector: @selector(fswatcherConnectionDidDie:)
		             name: NSConnectionDidDieNotification
		           object: c];
      
      fswatcher = fsw;
	    [fswatcher setProtocolForProxy: @protocol(FSWatcherProtocol)];
      RETAIN (fswatcher);
                                   
	    [fswatcher registerClient: (id <FSWClientProtocol>)self];
      
	  } else {
	    static BOOL recursion = NO;
	    static NSString	*cmd = nil;

	    if (recursion == NO) {
        if (cmd == nil) {
          #ifdef GNUSTEP	
            cmd = RETAIN ([[NSSearchPathForDirectoriesInDomains(
                      GSToolsDirectory, NSSystemDomainMask, YES) objectAtIndex: 0]
                            stringByAppendingPathComponent: @"fswatcher"]);
          #else
            cmd = @"/usr/local/bin/fswatcher";
            RETAIN (cmd);
          #endif
		    }
      }
	  
      if (recursion == NO && cmd != nil) {
        int i;
        
        [startAppWin showWindowWithTitle: @"Inspector"
                                 appName: @"fswatcher"
                            maxProgValue: 40.0];

	      [NSTask launchedTaskWithLaunchPath: cmd arguments: nil];
        RELEASE (cmd);
        
        for (i = 1; i <= 40; i++) {
          [startAppWin updateProgressBy: 1 * 1.0];
	        [[NSRunLoop currentRunLoop] runUntilDate:
		                       [NSDate dateWithTimeIntervalSinceNow: 0.1]];
        }
        
        [[startAppWin win] close];
        
	      recursion = YES;
	      [self connectFSWatcher];
	      recursion = NO;
        
	    } else { 
	      recursion = NO;
        fswnotifications = NO;
        NSRunAlertPanel(nil,
                NSLocalizedString(@"unable to contact fswatcher\nfswatcher notifications disabled!", @""),
                NSLocalizedString(@"Ok", @""),
                nil, 
                nil);  
      }
	  }
  }
}

- (void)fswatcherConnectionDidDie:(NSNotification *)notif
{
  id connection = [notif object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  NSAssert(connection == [fswatcher connectionForProxy],
		                                  NSInternalInconsistencyException);
  RELEASE (fswatcher);
  fswatcher = nil;

  if (NSRunAlertPanel(nil,
                    NSLocalizedString(@"The fswatcher connection died.\nDo you want to restart it?", @""),
                    NSLocalizedString(@"Yes", @""),
                    NSLocalizedString(@"No", @""),
                    nil)) {
    [self connectFSWatcher];                
  } else {
    fswnotifications = NO;
    NSRunAlertPanel(nil,
                    NSLocalizedString(@"fswatcher notifications disabled!", @""),
                    NSLocalizedString(@"Ok", @""),
                    nil, 
                    nil);  
  }
}

- (void)addWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    [fswatcher client: self addWatcherForPath: path];
  }
}

- (void)removeWatcherForPath:(NSString *)path
{
  if (fswnotifications) {
    [self connectFSWatcher];
    [fswatcher client: self removeWatcherForPath: path];
  }
}

- (void)addExternalViewerWithBundleData:(NSData *)bundleData
{
  id viewer;

  if (NSRunAlertPanel(nil,
        NSLocalizedString(@"An other process is asking me to add a viever\nMust I accept it?", @""),
        NSLocalizedString(@"Yes", @""),
        NSLocalizedString(@"No", @""),
        nil) != NSAlertDefaultReturn) {
    return;                
  }

  viewer = [self viewerFromPackedBundle: bundleData];

  if (viewer) {
    NSString *name = [viewer winname];
    BOOL exists = NO;	
    int i;
        			
		for (i = 0; i < [viewers count]; i++) {
			if ([name isEqual: [[viewers objectAtIndex: i] winname]]) {
				exists = YES;
				break;
			}
		}

		if (exists == NO) {
      [viewer setIsExternal: YES]; 
      [viewer setDataRepresentation: bundleData];
      [viewer setIsRemovable: YES];
      [self addViewer: viewer];            
    } else {
      NSRunAlertPanel(nil, 
            NSLocalizedString(@"A viewer for this type already exists!", @""), 
              NSLocalizedString(@"OK", @""), nil, nil);                                     
    }
  } else {
    NSRunAlertPanel(nil, 
          NSLocalizedString(@"invalid bundle data!", @""), 
            NSLocalizedString(@"OK", @""), nil, nil);                                     
  }
}                           

- (void)addExternalViewerWithBundlePath:(NSString *)path
{
  if (NSRunAlertPanel(nil,
        NSLocalizedString(@"An other process is asking me to add a viever\nMust I accept it?", @""),
        NSLocalizedString(@"Yes", @""),
        NSLocalizedString(@"No", @""),
        nil) != NSAlertDefaultReturn) {
    return;                
  } else {
    NSBundle *bundle = [NSBundle bundleWithPath: path]; 

    if (bundle) {
			Class principalClass = [bundle principalClass];
			if ([principalClass conformsToProtocol: @protocol(ContentViewersProtocol)]) {	
        NSRect r = [[(NSBox *)viewersBox contentView] frame];
        CREATE_AUTORELEASE_POOL (pool);
        id viewer = [[principalClass alloc] initWithFrame: r inspector: self];
	  		NSString *name = [viewer winname];
        BOOL exists = NO;		
        int i;
        
				for (i = 0; i < [viewers count]; i++) {
					if ([name isEqual: [[viewers objectAtIndex: i] winname]]) {
						exists = YES;
						break;
					}
				}

				if (exists == NO) {
          NSData *bundleData = [self dataRepresentationAtPath: path];
          
          if (bundleData) {
            [viewer setIsExternal: YES]; 
            [viewer setIsRemovable: YES];
            [viewer setDataRepresentation: bundleData];
            [self addViewer: viewer]; 
            
          } else {
            NSRunAlertPanel(nil, 
                NSLocalizedString(@"Cannot create the viewer data representation!", @""), 
                  NSLocalizedString(@"OK", @""), nil, nil);                                     
          }   
          
        } else {
          NSRunAlertPanel(nil, 
              NSLocalizedString(@"A viewer for this type already exists!", @""), 
                NSLocalizedString(@"OK", @""), nil, nil);                                     
        }

	  		RELEASE ((id)viewer);
        RELEASE (pool);
        
			} else {
        NSRunAlertPanel(nil, 
            NSLocalizedString(@"This object doesn't conforms to the ContentViewersProtocol!", @""), 
                NSLocalizedString(@"OK", @""), nil, nil);                                     
      }
    } else {
      NSRunAlertPanel(nil, 
            NSLocalizedString(@"invalid bundle data!", @""), 
                        NSLocalizedString(@"OK", @""), nil, nil);                                     
    }
  }
}

- (void)showContentsAt:(NSString *)path
{
	NSString *winName;

  if (currentViewer) {
    if ([currentViewer conformsToProtocol: @protocol(ContentViewersProtocol)]) {
      [currentViewer stopTasks];  
    }
  }   
    	      
	if (path) {
		id viewer = [self viewerForPath: path];

    if (currentPath && ([currentPath isEqual: path] == NO)) {
      [self removeWatcherForPath: currentPath];
      DESTROY (currentPath);
    }
        
		if (viewer) {
      currentViewer = viewer;
      winName = [viewer winname];
      [(NSBox *)viewersBox setContentView: viewer];
    
      if ([path isEqual: [viewer currentPath]]) {
        [viewer displayLastPath: NO];
      } else {
			  [viewer displayPath: path];
      }
		} else {
      NSString *appName, *type;
            
      [ws getInfoForFile: path application: &appName type: &type];
      
      if (type == NSPlainFileType) {
        NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
        NSString *fmtype = [attributes fileType];                                       
        
        if (fmtype != NSFileTypeRegular) {
          type = fmtype;
        }
      }
      
      [genericField setStringValue: type];
      [(NSBox *)viewersBox setContentView: genericView];
      currentViewer = genericView;
			winName = NSLocalizedString(@"Contents Inspector", @"");
      [iconView setImage: [ws iconForFile: path]];
      [titleField setStringValue: [path lastPathComponent]];
		}
		
	} else {  
    [iconView setImage: nil];
    [titleField setStringValue: @""];
    [(NSBox *)viewersBox setContentView: noContsView];
    currentViewer = noContsView;
		winName = NSLocalizedString(@"Contents Inspector", @"");
    
    if (currentPath) {
      [self removeWatcherForPath: currentPath];
      DESTROY (currentPath);
    }    
	}
	
	[win setTitle: winName];
  [viewersBox setNeedsDisplay: YES];
}

- (void)contentsReadyAt:(NSString *)path
{
  NSImage *icon = [ws iconForFile: path];
        
  if (icon) {
    [iconView setImage: icon];
  }
    
  [titleField setStringValue: [path lastPathComponent]];

  if (currentPath == nil) {
    ASSIGN (currentPath, path); 
    [self addWatcherForPath: currentPath];
  }
}

- (BOOL)canDisplayDataOfType:(NSString *)type
{
  return ([self viewerForDataOfType: type] != nil);
}

- (void)showData:(NSData *)data 
          ofType:(NSString *)type
{
	NSString *winName;
	id viewer;

  if (currentViewer) {
    if ([currentViewer conformsToProtocol: @protocol(ContentViewersProtocol)]) {
      [currentViewer stopTasks]; 
    }
  }   

  if (currentPath) {
    [self removeWatcherForPath: currentPath];
    DESTROY (currentPath);
  }
  
  viewer = [self viewerForDataOfType: type];
  
	if (viewer) {   
    currentViewer = viewer;
    winName = [viewer winname];
    [(NSBox *)viewersBox setContentView: viewer];
    [viewer displayData: data ofType: type];

	} else {	   
    [iconView setImage: [NSImage imageNamed: @"Pboard"]];
    [titleField setStringValue: @""];  
    [(NSBox *)viewersBox setContentView: noContsView];
    currentViewer = noContsView;
	  winName = NSLocalizedString(@"Data Inspector", @"");
  }
	
	[win setTitle: winName];
	[viewersBox setNeedsDisplay: YES];
}

- (void)dataContentsReadyForType:(NSString *)typeDescr
                         useIcon:(NSImage *)icon
{
  [iconView setImage: icon];
  [titleField setStringValue: typeDescr];
}


//
// FSWClientProtocol
//
- (void)watchedPathDidChange:(NSData *)dirinfo
{
  NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: dirinfo];
  NSString *path = [info objectForKey: @"path"];
  NSString *event = [info objectForKey: @"event"];
  unsigned i, j, count;

  if ([searchPaths containsObject: path]) {
    if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
      NSArray *files = [info objectForKey: @"files"];
      BOOL removed = NO;

      count = [files count];
      for (i = 0; i < count; i++) { 
        NSString *fname = [files objectAtIndex: i];
        NSString *dpath = [path stringByAppendingPathComponent: fname];
        id vwr = [self viewerWithBundlePath: dpath];

        if (vwr) { 
          [self removeViewer: vwr];  
          removed = YES;  
          i--;
          count--;
          
          NSRunAlertPanel(nil, 
                  NSLocalizedString(@"Viewer removed!", @""), 
                              NSLocalizedString(@"OK", @""), nil, nil);                                     
        }
      }

      if (removed && currentPath) {  
        [self showContentsAt: currentPath];
      }

    } else if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
      NSArray *files = [info objectForKey: @"files"];
      BOOL added = NO;

      for (i = 0; i < [files count]; i++) { 
        NSString *fname = [files objectAtIndex: i];
        NSString *bpath = [path stringByAppendingPathComponent: fname];
        NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 
        BOOL exists = NO;
        
        if (bundle) {
				  Class principalClass = [bundle principalClass];
				  if ([principalClass conformsToProtocol: @protocol(ContentViewersProtocol)]) {	
	  			  NSRect r = [[(NSBox *)viewersBox contentView] frame];
            CREATE_AUTORELEASE_POOL (pool);
            id vwr = [[principalClass alloc] initWithFrame: r inspector: self];
	  			  NSString *name = [vwr winname];
					
					  for (j = 0; j < [viewers count]; j++) {
						  if ([name isEqual: [[viewers objectAtIndex: j] winname]]) {
							  exists = YES;
							  break;
						  }
					  }
					
					  if (exists == NO) {
              [vwr setBundlePath: bpath];   
              [vwr setIsExternal: NO];  
              [vwr setIsRemovable: [userDir isEqual: path]];
              [self addViewer: vwr];
              added = YES;
              
              NSRunAlertPanel(nil, 
                  NSLocalizedString(@"Viewer added!", @""), 
                              NSLocalizedString(@"OK", @""), nil, nil);                                     
            }
					
	  			  RELEASE ((id)vwr);	
            RELEASE (pool);				
				  }
        }
      }
      
      if (added && currentPath) {  
        [self showContentsAt: currentPath];
      }
    }
    
  } else {   // viewed file watcher
    if (currentPath && [currentPath isEqual: path]) {
      if ([event isEqual: @"GWWatchedFileDeleted"]) {
        [self showContentsAt: nil];
        
      } else if ([event isEqual: @"GWWatchedFileModified"]) {
        if (currentViewer 
                && [currentViewer conformsToProtocol: @protocol(ContentViewersProtocol)]) {
          if ([currentPath isEqual: [currentViewer currentPath]]) {
            [currentViewer displayLastPath: YES];
          }
        }
      }
    }
  }
}


- (BOOL)windowShouldClose:(id)sender
{
  [win saveFrameUsingName: @"inspector"];
	return YES;
}

//
// Menu Operations
//
- (void)closeMainWin:(id)sender
{
  [[[NSApplication sharedApplication] keyWindow] performClose: sender];
}

- (void)showPreferences:(id)sender
{
  [preferences activate];
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"Inspector" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"-----------------------", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"Inspector 0.3" forKey: @"ApplicationRelease"];
  [d setObject: @"01 2004" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: @"Enrico Sersale <enrico@imago.ro>.", nil]
        forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gworkspace", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2004 Free Software Foundation, Inc."
        forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
        forKey: @"CopyrightDescription"];
  
#ifdef GNUSTEP	
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
#else
	[NSApp orderFrontStandardAboutPanel: d];
#endif
}

#ifndef GNUSTEP
- (void)terminate:(id)sender
{
  [NSApp terminate: self];
}
#endif

@end


@implementation Inspector (PackedBundles)
//
// Part of these methods taken from Zillion
// by Stefan Boehringer <stefan.boehringer@uni-essen.de>.
// Zillion is a Server application for scheduling tasks on slave machines.
//

- (NSData *)dataRepresentationAtPath:(NSString *)path
{
	NSArray *files = [fm directoryContentsAtPath: path];
	NSMutableDictionary	*contsDict = [NSMutableDictionary dictionary];
	int	i;

	for (i = 0; i < [files count]; i++) {
		NSString *file = [files objectAtIndex: i];
		NSString *filePath = [path stringByAppendingPathComponent: file];
		NSDictionary *attributes = [fm fileAttributesAtPath: filePath traverseLink: YES];
    NSMutableDictionary *fileDict = [NSMutableDictionary dictionary];
    NSData *contsData;
    
		if ([attributes fileType] == NSFileTypeDirectory) {	
			contsData = [self dataRepresentationAtPath: filePath];
		} else {
			contsData = [fm contentsAtPath: filePath];
		}

    [fileDict setObject: attributes forKey: @"attributes"];
    [fileDict setObject: contsData forKey: @"contents"];
    
		[contsDict setObject: fileDict forKey: file];
	}
  
	return [NSArchiver archivedDataWithRootObject: contsDict];
}

- (BOOL)writeDataRepresentation:(NSData *)data 
                         toPath:(NSString *)path
{
  NSDictionary *dirDict = [NSUnarchiver unarchiveObjectWithData: data];

  if (dirDict) {
	  NSEnumerator *files = [dirDict keyEnumerator];
    NSString *fname;

    while ((fname = [files nextObject])) {
		  NSString *filePath = [path stringByAppendingPathComponent: fname];
      NSDictionary *fileDict = [dirDict objectForKey: fname];
      NSDictionary *attributes = [fileDict objectForKey: @"attributes"];
      NSData *contents = [fileDict objectForKey: @"contents"];
 
      if ([[attributes fileType] isEqual: NSFileTypeDirectory]) {
        if ([fm createDirectoryAtPath: filePath attributes: attributes] == NO) {
          return NO;
        } 
			  if ([self writeDataRepresentation: contents toPath: filePath] == NO) {
          return NO;
        }
      } else {
			  if ([fm createFileAtPath: filePath 
                        contents: contents attributes: attributes] == NO) {
          return NO;
        }
      }
    }
    
    return YES;
  }
  
  return NO;
}

- (NSString *)tempBundleName
{
  viewerTmpRef++;
  return [NSString stringWithFormat: @"%i", viewerTmpRef];
}

- (id)viewerFromPackedBundle:(NSData *)packedBundle
{
	NSString *tempPath = NSTemporaryDirectory();

  tempPath = [tempPath stringByAppendingPathComponent: [self tempBundleName]];
  
  if ([fm createDirectoryAtPath: tempPath attributes: nil]) {
    if ([self writeDataRepresentation: packedBundle toPath: tempPath]) {
  	  NSBundle *bundle = [NSBundle bundleWithPath: tempPath];

      if (bundle) {
	      Class bundleClass = [bundle principalClass];

        if ([bundleClass conformsToProtocol: @protocol(ContentViewersProtocol)]) {
          NSRect r = [[(NSBox *)viewersBox contentView] frame];
          id viewer = [[bundleClass alloc] initWithFrame: r inspector: self];

          [fm removeFileAtPath: tempPath handler: nil];

          return AUTORELEASE (viewer);
        }
      }
    }
	}
  
	return nil;
}

@end 








