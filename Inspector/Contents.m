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
#include <math.h>
#include "Contents.h"
#include "ContentViewersProtocol.h"
#include "Inspector.h"
#include "Preferences/InspectorPref.h"
#include "Functions.h"
#include "GNUstep.h"

#ifndef ICNMAX
  #define ICNMAX 48
  
  #define CHECK_ICON_SIZE(i) \
  { \
  NSSize size = [i size]; \
  if ((size.width > ICNMAX) || (size.height > ICNMAX)) { \
  NSSize newsize; \
  if (size.width >= size.height) { \
  newsize.width = ICNMAX; \
  newsize.height = floor(ICNMAX * size.height / size.width + 0.5); \
  } else { \
  newsize.height = ICNMAX; \
  newsize.width  = floor(ICNMAX * size.width / size.height + 0.5); \
  } \
  [i setScalesWhenResized: YES]; \
  [i setSize: newsize]; \
  } \
  }
#endif

static NSString *nibName = @"Contents";

@implementation Contents

- (void)dealloc
{
  RELEASE (searchPaths);
  RELEASE (userDir);
  RELEASE (disabledDir);
  RELEASE (viewers);
  
  TEST_RELEASE (currentPath);
  
  TEST_RELEASE (genericView);
  TEST_RELEASE (noContsView);
  
  TEST_RELEASE (mainBox);
    
	[super dealloc];
}

- (id)initForInspector:(id)insp
{
  self = [super init];
  
  if (self) {
    NSMutableArray *bundlesPaths;
    NSString *bundlesDir;
    BOOL isdir;
    id label;
    unsigned i;
    NSRect r;

    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      [NSApp terminate: self];
    } 

    RETAIN (mainBox);
    RELEASE (win);
    
    inspector = insp;
    searchPaths = [NSMutableArray new];
    viewers = [NSMutableArray new];
    currentPath = nil;
    viewerTmpRef = (unsigned long)self;
    fm = [NSFileManager defaultManager];	
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
        
    r = [[(NSBox *)viewersBox contentView] frame];

    bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    ASSIGN (userDir, [bundlesDir stringByAppendingPathComponent: @"Inspector"]);  

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

    bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
    bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];

    bundlesPaths = [self bundlesWithExtension: @"inspector" inPath: bundlesDir];
    [self addViewersFromBundlePaths: bundlesPaths userViewers: NO];

    genericView = [[NSView alloc] initWithFrame: r];		
    MAKE_LABEL (genericField, NSMakeRect(2, 125, 254, 65), nil, 'c', YES, genericView);		  
    [genericField setFont: [NSFont systemFontOfSize: 18]];
    [genericField setTextColor: [NSColor grayColor]];				

    noContsView = [[NSView alloc] initWithFrame: r];
    MAKE_LOCALIZED_LABEL (label, NSMakeRect(2, 125, 254, 65), @"No Contents Inspector", @"", 'c', YES, noContsView);		  
    [label setFont: [NSFont systemFontOfSize: 18]];
    [label setTextColor: [NSColor grayColor]];				

    for (i = 0; i < [searchPaths count]; i++) {
      [inspector addWatcherForPath: [searchPaths objectAtIndex: i]];
    }

    currentViewer = nil;
  }
  
  return self;
}

- (NSView *)inspView
{
  return mainBox;
}

- (NSString *)winname
{
  return NSLocalizedString(@"Contents Inspector", @"");
}

- (void)activateForPaths:(NSArray *)paths
{
  if ([paths count] == 1) {
    [self showContentsAt: [paths objectAtIndex: 0]];
    
  } else {
    NSString *items = NSLocalizedString(@"items", @"");
    
    items = [NSString stringWithFormat: @"%i %@", [paths count], items];
		[titleField setStringValue: items];  
    [iconView setImage: [NSImage imageNamed: @"MultipleSelection.tiff"]];
    
    [(NSBox *)viewersBox setContentView: noContsView];
    currentViewer = noContsView;
    
    if (currentPath) {
      [inspector removeWatcherForPath: currentPath];
      DESTROY (currentPath);
    }    
	
	  [[inspector inspWin] setTitle: [self winname]];    
  }
}

- (BOOL)prepareToTerminate
{
  NSMutableArray *externalVwrs = [NSMutableArray array];
  int i;

	for (i = 0; i < [viewers count]; i++) {
		id viewer = [viewers objectAtIndex: i];
    
    if ([viewer isExternal]) {
      [externalVwrs addObject: viewer];
    }
  }  
  
  if ([externalVwrs count]) {
    InspectorPref *preferences = [inspector preferences];
  
    if (NSRunAlertPanel(nil,
            NSLocalizedString(@"Do you want to save the external viewers?", @""),
            NSLocalizedString(@"Yes", @""),
            NSLocalizedString(@"No", @""),
            nil)) {
      if ([[preferences win] isVisible]) {
        [[preferences win] close];
      }    
      [preferences removeAllViewers];
  
      for (i = 0; i < [externalVwrs count]; i++) {
        [preferences addViewer: [externalVwrs objectAtIndex: i]];
      }
    
      [preferences setSaveMode: YES];
      [NSApp runModalForWindow: [preferences win]];
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
  [[inspector preferences] addViewer: vwr];
}

- (void)removeViewer:(id)vwr
{
  [viewers removeObject: vwr];
  [[inspector preferences] removeViewer: vwr];
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
      [inspector removeWatcherForPath: userDir];
      
      if ([fm movePath: vpath toPath: dispath handler: nil]) {
        [self removeViewer: vwr];
      }
      
      [inspector addWatcherForPath: userDir];
      
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
      [inspector removeWatcherForPath: currentPath];
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
      NSImage *icon;
            
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
      
      icon = [ws iconForFile: path];
      CHECK_ICON_SIZE (icon);
      [iconView setImage: icon];
      
      [titleField setStringValue: [path lastPathComponent]];
		}
		
	} else {  
    [iconView setImage: nil];
    [titleField setStringValue: @""];
    [(NSBox *)viewersBox setContentView: noContsView];
    currentViewer = noContsView;
		winName = NSLocalizedString(@"Contents Inspector", @"");
    
    if (currentPath) {
      [inspector removeWatcherForPath: currentPath];
      DESTROY (currentPath);
    }    
	}
	
	[[inspector inspWin] setTitle: winName];
}

- (void)contentsReadyAt:(NSString *)path
{
  NSImage *icon = [ws iconForFile: path];
        
  if (icon) {
    CHECK_ICON_SIZE (icon);
    [iconView setImage: icon];
  }
    
  [titleField setStringValue: [path lastPathComponent]];

  if (currentPath == nil) {
    ASSIGN (currentPath, path); 
    [inspector addWatcherForPath: currentPath];
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
    [inspector removeWatcherForPath: currentPath];
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
	
	[[inspector inspWin] setTitle: winName];
	[viewersBox setNeedsDisplay: YES];
}

- (void)dataContentsReadyForType:(NSString *)typeDescr
                         useIcon:(NSImage *)icon
{
  [iconView setImage: icon];
  [titleField setStringValue: typeDescr];
}


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

@end


@implementation Contents (PackedBundles)
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








