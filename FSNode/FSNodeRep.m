/* FSNodeRep.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep FSNode framework
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
#include "FSNodeRep.h"
#include "FSNFunctions.h"
#include "ExtendedInfo.h"
#include "GNUstep.h"

static FSNodeRep *shared = nil;

@interface FSNodeRep (PrivateMethods)

+ (void)initialize;

+ (FSNodeRep *)sharedInstance;

- (id)initSharedInstance;

- (NSArray *)directoryContentsAtPath:(NSString *)path;

- (NSImage *)iconOfSize:(float)size 
                forNode:(FSNode *)node;

- (NSImage *)multipleSelectionIconOfSize:(float)size;

- (NSImage *)openFolderIconOfSize:(float)size 
                          forNode:(FSNode *)node;

- (NSImage *)workspaceIconOfSize:(float)size;

- (NSImage *)trashIconOfSize:(float)size;

- (NSImage *)trashFullIconOfSize:(float)size;

- (NSImage *)resizedIcon:(NSImage *)icon 
                  ofSize:(float)size;

- (NSBezierPath *)highlightPathOfSize:(NSSize)size;

- (void)setDefaultSortOrder:(int)order;

- (unsigned int)defaultSortOrder;

- (SEL)defaultCompareSelector;

- (unsigned int)sortOrderForDirectory:(NSString *)dirpath;

- (SEL)compareSelectorForDirectory:(NSString *)dirpath;

- (void)setSortOrder:(int)order forDirectory:(NSString *)dirpath;

- (void)lockNode:(FSNode *)node;

- (void)lockPath:(NSString *)path;

- (void)lockNodes:(NSArray *)nodes;

- (void)lockPaths:(NSArray *)paths;

- (void)unlockNode:(FSNode *)node;

- (void)unlockPath:(NSString *)path;

- (void)unlockNodes:(NSArray *)nodes;

- (void)unlockPaths:(NSArray *)paths;

- (BOOL)isNodeLocked:(FSNode *)node;

- (BOOL)isPathLocked:(NSString *)path;

- (void)setUseThumbnails:(BOOL)value;

- (void)prepareThumbnailsCache;

- (void)thumbnailsDidChange:(NSNotification *)notif;

- (NSImage *)thumbnailForPath:(NSString *)apath;

- (void)loadExtendedInfoModules;

- (NSArray *)bundlesWithExtension:(NSString *)extension 
												   inPath:(NSString *)path;

- (NSArray *)availableExtendedInfoNames;

- (NSDictionary *)extendedInfoOfType:(NSString *)type
                             forNode:(FSNode *)anode;

@end


@implementation FSNodeRep (PrivateMethods)

+ (void)initialize
{
  if ([self class] == [FSNodeRep class]) {
    [FSNodeRep sharedInstance];              
  }
}

+ (FSNodeRep *)sharedInstance
{
	if (shared == nil) {
		shared = [[FSNodeRep alloc] initSharedInstance];
	}	
  return shared;
}

- (id)initSharedInstance
{    
  self = [super init];
    
  if (self) {
  	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSBundle *bundle = [NSBundle bundleForClass: [FSNodeRep class]];
    id defentry;
    NSString *imagepath;
    BOOL isdir;
    
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
    
    defSortOrder = FSNInfoNameType;
    defentry = [defaults objectForKey: @"default_sortorder"];	
    [self setDefaultSortOrder: (defentry ? [defentry intValue] : FSNInfoNameType)];
    
    hideSysFiles = [defaults boolForKey: @"GSFileBrowserHideDotFiles"];
  
    if (hideSysFiles == NO) {
      NSDictionary *domain = [defaults persistentDomainForName: NSGlobalDomain];
      
      defentry = [domain objectForKey: @"GSFileBrowserHideDotFiles"];
    
      if (defentry) {
        hideSysFiles = [defentry boolValue];
      } else {  
        hideSysFiles = NO;
      }
    }
    
    imagepath = [bundle pathForResource: @"MultipleSelection" ofType: @"tiff"];
    multipleSelIcon = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    imagepath = [bundle pathForResource: @"FolderOpen" ofType: @"tiff"];
    openFolderIcon = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    imagepath = [bundle pathForResource: @"HardDisk" ofType: @"tiff"];
    hardDiskIcon = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    imagepath = [bundle pathForResource: @"HardDiskOpen" ofType: @"tiff"];
    openHardDiskIcon = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    imagepath = [bundle pathForResource: @"Workspace" ofType: @"tiff"];
    workspaceIcon = [[NSImage alloc] initWithContentsOfFile: imagepath];
    imagepath = [bundle pathForResource: @"Recycler" ofType: @"tiff"];
    trashIcon = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    imagepath = [bundle pathForResource: @"RecyclerFull" ofType: @"tiff"];
    trashFullIcon = [[NSImage alloc] initWithContentsOfFile: imagepath];

    thumbnailDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    thumbnailDir = [thumbnailDir stringByAppendingPathComponent: @"Thumbnails"];
    RETAIN (thumbnailDir);
    
    if (([fm fileExistsAtPath: thumbnailDir isDirectory: &isdir] && isdir) == NO) {
      if ([fm createDirectoryAtPath: thumbnailDir attributes: nil] == NO) {
        NSLog(@"unable to create the thumbnails directory. Quiting now");
        [NSApp terminate: self];
      }
    }
    
    usesThumbnails = [defaults boolForKey: @"use_thumbnails"];
    [self setUseThumbnails: usesThumbnails];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                        selector: @selector(thumbnailsDidChange:) 
                					  name: @"GWThumbnailsDidChangeNotification"
                          object: nil];
  
    lockedPaths = [NSMutableArray new];	
    
    [self loadExtendedInfoModules];
  }
    
  return self;
}

- (NSArray *)directoryContentsAtPath:(NSString *)path
{
  NSArray *fnames = [fm directoryContentsAtPath: path];
  NSString *hdnFilePath = [path stringByAppendingPathComponent: @".hidden"];
  NSArray *hiddenNames = nil;  

  if ([fm fileExistsAtPath: hdnFilePath]) {
    NSString *str = [NSString stringWithContentsOfFile: hdnFilePath];
	  hiddenNames = [str componentsSeparatedByString: @"\n"];
	}

  if (hiddenNames || hideSysFiles) {
    NSMutableArray *filteredNames = [NSMutableArray array];
	  int i;

    for (i = 0; i < [fnames count]; i++) {
      NSString *fname = [fnames objectAtIndex: i];
      BOOL hidden = NO;
    
      if ([fname hasPrefix: @"."] && hideSysFiles) {
        hidden = YES;  
      }
    
      if (hiddenNames && [hiddenNames containsObject: fname]) {
        hidden = YES;  
      }
      
      if (hidden == NO) {
        [filteredNames addObject: fname];
      }
    }
  
    return filteredNames;
  }
  
  return fnames;
}

- (NSImage *)iconOfSize:(float)size 
                forNode:(FSNode *)node
{
  NSString *nodepath = [node path];
  NSImage *icon = nil;
	NSSize icnsize;

  if (usesThumbnails) {
    icon = [self thumbnailForPath: nodepath];
  }

  if (icon == nil) {
    if ([node isMountPoint]) {
      icon = hardDiskIcon;
    } else {
      icon = [ws iconForFile: nodepath];
    }
  }

  if (icon == nil) {
    icon = [NSImage imageNamed: @"Unknown"];
  }
  
  icnsize = [icon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: icon ofSize: size];
  }  

  return icon;
}

- (NSImage *)multipleSelectionIconOfSize:(float)size
{
  NSSize icnsize = [multipleSelIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: multipleSelIcon ofSize: size];
  }  
  
  return multipleSelIcon;
}

- (NSImage *)openFolderIconOfSize:(float)size 
                          forNode:(FSNode *)node
{
  NSString *ipath = [[node path] stringByAppendingPathComponent: @".opendir.tiff"];
  NSImage *icon = nil;

  if ([fm isReadableFileAtPath: ipath]) {
    NSImage *img = [[NSImage alloc] initWithContentsOfFile: ipath];

    if (img) {
      icon = AUTORELEASE (img);
    } else {
      icon = openFolderIcon;
    }      
  } else {
    if ([node isMountPoint]) {
      icon = openHardDiskIcon;
    } else {
      icon = openFolderIcon;
    }
  }

  if (icon) {
    NSSize icnsize = [icon size];

    if ((icnsize.width > size) || (icnsize.height > size)) {
      return [self resizedIcon: icon ofSize: size];
    }  
  }
  
  return icon;
}

- (NSImage *)workspaceIconOfSize:(float)size
{
  NSSize icnsize = [workspaceIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: workspaceIcon ofSize: size];
  }  
  
  return workspaceIcon;
}

- (NSImage *)trashIconOfSize:(float)size
{
  NSSize icnsize = [trashIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: trashIcon ofSize: size];
  }  
  
  return trashIcon;
}

- (NSImage *)trashFullIconOfSize:(float)size
{
  NSSize icnsize = [trashFullIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: trashFullIcon ofSize: size];
  }  
  
  return trashFullIcon;
}

- (NSImage *)resizedIcon:(NSImage *)icon 
                  ofSize:(float)size
{
  NSImage *newIcon = [icon copy];
  NSSize icnsize = [icon size];
  float fact;
  NSSize newsize;

  if (icnsize.width >= icnsize.height) {
    fact = icnsize.width / size;
  } else {
    fact = icnsize.height / size;
  }

  newsize = NSMakeSize(icnsize.width / fact, icnsize.height / fact);

	[newIcon setScalesWhenResized: YES];
	[newIcon setSize: newsize];  

  return AUTORELEASE (newIcon);
}

- (NSBezierPath *)highlightPathOfSize:(NSSize)size
{
  NSSize intsize = NSMakeSize(ceil(size.width), ceil(size.height));
  NSBezierPath *bpath = [NSBezierPath bezierPath];
  float clenght = intsize.height / 4;
  NSPoint p, cp1, cp2;
  
  p = NSMakePoint(clenght, 0);
  [bpath moveToPoint: p];

  p = NSMakePoint(0, clenght);
  cp1 = NSMakePoint(0, 0);
  cp2 = NSMakePoint(0, 0);
  [bpath curveToPoint: p controlPoint1: cp1 controlPoint2: cp2];

  p = NSMakePoint(0, intsize.height - clenght);
  [bpath lineToPoint: p];

  p = NSMakePoint(clenght, intsize.height);
  cp1 = NSMakePoint(0, intsize.height);
  cp2 = NSMakePoint(0, intsize.height);
  [bpath curveToPoint: p controlPoint1: cp1 controlPoint2: cp2];

  p = NSMakePoint(intsize.width - clenght, intsize.height);
  [bpath lineToPoint: p];

  p = NSMakePoint(intsize.width, intsize.height - clenght);
  cp1 = NSMakePoint(intsize.width, intsize.height);
  cp2 = NSMakePoint(intsize.width, intsize.height);
  [bpath curveToPoint: p controlPoint1: cp1 controlPoint2: cp2];

  p = NSMakePoint(intsize.width, clenght);
  [bpath lineToPoint: p];

  p = NSMakePoint(intsize.width - clenght, 0);
  cp1 = NSMakePoint(intsize.width, 0);
  cp2 = NSMakePoint(intsize.width, 0);
  [bpath curveToPoint: p controlPoint1: cp1 controlPoint2: cp2];

  [bpath closePath];
  
  return bpath;
}

- (void)setDefaultSortOrder:(int)order
{
	if (defSortOrder != order) {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
    defSortOrder = order;
		[defaults setObject: [NSNumber numberWithInt: defSortOrder] 
							   forKey: @"default_sortorder"];
		[defaults synchronize];
	  
    [[NSDistributedNotificationCenter defaultCenter]
          postNotificationName: @"GWSortTypeDidChangeNotification"
                        object: nil
                      userInfo: nil];
	}
}

- (unsigned int)defaultSortOrder
{
  return defSortOrder;
}

- (SEL)defaultCompareSelector
{
  SEL compareSel;

  switch(defSortOrder) {
    case FSNInfoNameType:
      compareSel = @selector(compareAccordingToName:);
      break;
    case FSNInfoKindType:
      compareSel = @selector(compareAccordingToKind:);
      break;
    case FSNInfoDateType:
      compareSel = @selector(compareAccordingToDate:);
      break;
    case FSNInfoSizeType:
      compareSel = @selector(compareAccordingToSize:);
      break;
    case FSNInfoOwnerType:
      compareSel = @selector(compareAccordingToOwner:);
      break;
    default:
      compareSel = @selector(compareAccordingToName:);
      break;
  }

  return compareSel;
}

- (unsigned int)sortOrderForDirectory:(NSString *)dirpath
{
  if ([fm isWritableFileAtPath: dirpath]) {
    NSString *dictPath = [dirpath stringByAppendingPathComponent: @".gwsort"];
    
    if ([fm fileExistsAtPath: dictPath]) {
      NSDictionary *sortDict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
       
      if (sortDict) {
        return [[sortDict objectForKey: @"sort"] intValue];
      }   
    }
  } 
  
	return defSortOrder;
}

- (SEL)compareSelectorForDirectory:(NSString *)dirpath
{
  int order = [self sortOrderForDirectory: dirpath];
  SEL compareSel;

  switch(order) {
    case FSNInfoNameType:
      compareSel = @selector(compareAccordingToName:);
      break;
    case FSNInfoKindType:
      compareSel = @selector(compareAccordingToKind:);
      break;
    case FSNInfoDateType:
      compareSel = @selector(compareAccordingToDate:);
      break;
    case FSNInfoSizeType:
      compareSel = @selector(compareAccordingToSize:);
      break;
    case FSNInfoOwnerType:
      compareSel = @selector(compareAccordingToOwner:);
      break;
    default:
      compareSel = @selector(compareAccordingToName:);
      break;
  }

  return compareSel;
}

- (void)setSortOrder:(int)order forDirectory:(NSString *)dirpath
{
  NSDictionary *userInfo = [NSDictionary dictionaryWithObject: dirpath 
                                                       forKey: @"path"];

  if ([fm isWritableFileAtPath: dirpath]) {
    NSNumber *sortnum = [NSNumber numberWithInt: order];
    NSDictionary *dict = [NSDictionary dictionaryWithObject: sortnum 
                                                     forKey: @"sort"];
    [dict writeToFile: [dirpath stringByAppendingPathComponent: @".gwsort"] 
           atomically: YES];
  }
 
  [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName: @"GWSortTypeDidChangeNotification"
                      object: nil
                    userInfo: userInfo];
}

- (void)lockNode:(FSNode *)node
{
  NSString *path = [node path];
    
	if ([lockedPaths containsObject: path] == NO) {
		[lockedPaths addObject: path];
	} 
}

- (void)lockPath:(NSString *)path
{
	if ([lockedPaths containsObject: path] == NO) {
		[lockedPaths addObject: path];
	} 
}

- (void)lockNodes:(NSArray *)nodes
{
	int i;
	  
	for (i = 0; i < [nodes count]; i++) {
    NSString *path = [[nodes objectAtIndex: i] path];
    
		if ([lockedPaths containsObject: path] == NO) {
			[lockedPaths addObject: path];
		} 
	}
}

- (void)lockPaths:(NSArray *)paths
{
	int i;
	  
	for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];
    
		if ([lockedPaths containsObject: path] == NO) {
			[lockedPaths addObject: path];
		} 
	}
}

- (void)unlockNode:(FSNode *)node
{
  NSString *path = [node path];

	if ([lockedPaths containsObject: path]) {
		[lockedPaths removeObject: path];
	} 
}

- (void)unlockPath:(NSString *)path
{
	if ([lockedPaths containsObject: path]) {
		[lockedPaths removeObject: path];
	} 
}

- (void)unlockNodes:(NSArray *)nodes
{
	int i;
	  
	for (i = 0; i < [nodes count]; i++) {
    NSString *path = [[nodes objectAtIndex: i] path];
	
		if ([lockedPaths containsObject: path]) {
			[lockedPaths removeObject: path];
		} 
	}
}

- (void)unlockPaths:(NSArray *)paths
{
	int i;
	  
	for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];
	
		if ([lockedPaths containsObject: path]) {
			[lockedPaths removeObject: path];
		} 
	}
}

- (BOOL)isNodeLocked:(FSNode *)node
{
  NSString *path = [node path];
	int i;  
  
	if ([lockedPaths containsObject: path]) {
		return YES;
	}
	
	for (i = 0; i < [lockedPaths count]; i++) {
		NSString *lpath = [lockedPaths objectAtIndex: i];
	
    if (isSubpathOfPath(lpath, path)) {
			return YES;
		}
	}
	
	return NO;
}

- (BOOL)isPathLocked:(NSString *)path
{
	int i;  
  
	if ([lockedPaths containsObject: path]) {
		return YES;
	}
	
	for (i = 0; i < [lockedPaths count]; i++) {
		NSString *lpath = [lockedPaths objectAtIndex: i];
	
    if (isSubpathOfPath(lpath, path)) {
			return YES;
		}
	}
	
	return NO;
}

- (void)setUseThumbnails:(BOOL)value
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
    
  usesThumbnails = value;
  
  if (usesThumbnails) {
    [self prepareThumbnailsCache];
  }
  
  [defaults setBool: usesThumbnails forKey: @"use_thumbnails"];
  [defaults synchronize];
}

- (void)prepareThumbnailsCache
{
  NSString *dictName = @"thumbnails.plist";
  NSString *dictPath = [thumbnailDir stringByAppendingPathComponent: dictName];
  NSDictionary *tdict;
  
  TEST_RELEASE (tumbsCache);
  tumbsCache = [NSMutableDictionary new];
  
  tdict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
    
  if (tdict) {
    NSArray *keys = [tdict allKeys];
    int i;

    for (i = 0; i < [keys count]; i++) {
      NSString *key = [keys objectAtIndex: i];
      NSString *tumbname = [tdict objectForKey: key];
      NSString *tumbpath = [thumbnailDir stringByAppendingPathComponent: tumbname]; 

      if ([fm fileExistsAtPath: tumbpath]) {
        NSImage *tumb = [[NSImage alloc] initWithContentsOfFile: tumbpath];
        
        if (tumb) {
          [tumbsCache setObject: tumb forKey: key];
          RELEASE (tumb);
        }
      }
    }
  } 
}

- (void)thumbnailsDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSArray *deleted = [info objectForKey: @"deleted"];	
  NSArray *created = [info objectForKey: @"created"];	
  int i;

  if (usesThumbnails == NO) {
    return;
  }
  
  if ([deleted count]) {
    for (i = 0; i < [deleted count]; i++) {
      [tumbsCache removeObjectForKey: [deleted objectAtIndex: i]];
    }
  }
  
  if ([created count]) {
    NSString *dictName = @"thumbnails.plist";
    NSString *dictPath = [thumbnailDir stringByAppendingPathComponent: dictName];
    NSDictionary *tdict = [NSDictionary dictionaryWithContentsOfFile: dictPath];
  
    for (i = 0; i < [created count]; i++) {
      NSString *key = [created objectAtIndex: i];
      NSString *tumbname = [tdict objectForKey: key];
      NSString *tumbpath = [thumbnailDir stringByAppendingPathComponent: tumbname]; 

      if ([fm fileExistsAtPath: tumbpath]) {
        NSImage *tumb = [[NSImage alloc] initWithContentsOfFile: tumbpath];
        
        if (tumb) {
          [tumbsCache setObject: tumb forKey: key];
          RELEASE (tumb);
        }
      }
    }
  }
}

- (NSImage *)thumbnailForPath:(NSString *)apath
{
  if (usesThumbnails) {
    return [tumbsCache objectForKey: apath];
  }
  return nil;
}

- (void)loadExtendedInfoModules
{
  NSString *bundlesDir;
  NSArray *bundlesPaths;
  NSMutableArray *loaded;
  int i;
  
  bundlesPaths = [NSMutableArray array];

  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
  bundlesPaths = [self bundlesWithExtension: @"extinfo" inPath: bundlesDir];

  loaded = [NSMutableArray array];
  
  for (i = 0; i < [bundlesPaths count]; i++) {
    NSString *bpath = [bundlesPaths objectAtIndex: i];
    NSBundle *bundle = [NSBundle bundleWithPath: bpath];
     
    if (bundle) {
			Class principalClass = [bundle principalClass];

			if ([principalClass conformsToProtocol: @protocol(ExtendedInfo)]) {	
	      CREATE_AUTORELEASE_POOL (pool);
        id module = [[principalClass alloc] init];
	  		NSString *name = [module menuName];
        BOOL exists = NO;	
        int j;
        			
				for (j = 0; j < [loaded count]; j++) {
					if ([name isEqual: [[loaded objectAtIndex: j] menuName]]) {
            NSLog(@"duplicate module \"%@\" at %@", name, bpath);
						exists = YES;
						break;
					}
				}

				if (exists == NO) {
          [loaded addObject: module];
        }

	  		RELEASE ((id)module);			
        RELEASE (pool);		
			}
    }
  }
  
  ASSIGN (extInfoModules, loaded);
}

- (NSArray *)bundlesWithExtension:(NSString *)extension 
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

- (NSArray *)availableExtendedInfoNames
{
  NSMutableArray *names = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [extInfoModules count]; i++) {
    id module = [extInfoModules objectAtIndex: i];
    [names addObject: NSLocalizedString([module menuName], @"")];
  }
  
  return names;
}

- (NSDictionary *)extendedInfoOfType:(NSString *)type
                             forNode:(FSNode *)anode
{
  int i;

  for (i = 0; i < [extInfoModules count]; i++) {
    id module = [extInfoModules objectAtIndex: i];
    NSString *mname = NSLocalizedString([module menuName], @"");
  
    if ([mname isEqual: type]) {
      return [module extendedInfoForNode: anode];
    }
  }
  
  return nil;
}

@end


@implementation FSNodeRep 

- (void)dealloc
{
  if (self == [FSNodeRep sharedInstance]) {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];
  }
  TEST_RELEASE (extInfoModules);
	TEST_RELEASE (lockedPaths);
  TEST_RELEASE (tumbsCache);
  TEST_RELEASE (thumbnailDir);
  TEST_RELEASE (multipleSelIcon);
  TEST_RELEASE (openFolderIcon);
  TEST_RELEASE (hardDiskIcon);
  TEST_RELEASE (openHardDiskIcon);
  TEST_RELEASE (workspaceIcon);
  TEST_RELEASE (trashIcon);
  TEST_RELEASE (trashFullIcon);
        
  [super dealloc];
}

+ (NSArray *)directoryContentsAtPath:(NSString *)path
{
  return [[self sharedInstance] directoryContentsAtPath: path];
}

+ (NSImage *)iconOfSize:(float)size 
                forNode:(FSNode *)node
{
  return [[self sharedInstance] iconOfSize: size forNode: node];
}

+ (NSImage *)multipleSelectionIconOfSize:(float)size
{
  return [[self sharedInstance] multipleSelectionIconOfSize: size];
}

+ (NSImage *)openFolderIconOfSize:(float)size 
                          forNode:(FSNode *)node
{
  return [[self sharedInstance] openFolderIconOfSize: size forNode: node];
}

+ (NSImage *)workspaceIconOfSize:(float)size
{
  return [[self sharedInstance] workspaceIconOfSize: size];
}

+ (NSImage *)trashIconOfSize:(float)size
{
  return [[self sharedInstance] trashIconOfSize: size];
}

+ (NSImage *)trashFullIconOfSize:(float)size
{
  return [[self sharedInstance] trashFullIconOfSize: size];
}

+ (NSBezierPath *)highlightPathOfSize:(NSSize)size
{
  return [[self sharedInstance] highlightPathOfSize: size];
}

+ (float)highlightHeightFactor
{
  return 0.8125;
}

+ (int)labelMargin
{
  return 4;
}

+ (int)defaultIconBaseShift
{
  return 12;
}

+ (void)setDefaultSortOrder:(int)order
{
  [[self sharedInstance] setDefaultSortOrder: order];
}

+ (unsigned int)defaultSortOrder
{
  return [[self sharedInstance] defaultSortOrder];
}

+ (SEL)defaultCompareSelector
{
  return [[self sharedInstance] defaultCompareSelector];
}

+ (unsigned int)sortOrderForDirectory:(NSString *)dirpath
{
  return [[self sharedInstance] sortOrderForDirectory: dirpath];
}

+ (SEL)compareSelectorForDirectory:(NSString *)dirpath
{
  return [[self sharedInstance] compareSelectorForDirectory: dirpath];
}

+ (void)setSortOrder:(int)order forDirectory:(NSString *)dirpath
{
  [[self sharedInstance] setSortOrder: order forDirectory: dirpath];
}

+ (void)lockNode:(FSNode *)node
{
  [[self sharedInstance] lockNode: node];
}

+ (void)lockPath:(NSString *)path
{
  [[self sharedInstance] lockPath: path];
}

+ (void)lockNodes:(NSArray *)nodes
{
  [[self sharedInstance] lockNodes: nodes];
}

+ (void)lockPaths:(NSArray *)paths
{
  [[self sharedInstance] lockPaths: paths];
}

+ (void)unlockNode:(FSNode *)node
{
  [[self sharedInstance] unlockNode: node];
}

+ (void)unlockPath:(NSString *)path
{
  [[self sharedInstance] unlockPath: path];
}

+ (void)unlockNodes:(NSArray *)nodes
{
  [[self sharedInstance] unlockNodes: nodes];
}

+ (void)unlockPaths:(NSArray *)paths
{
  [[self sharedInstance] unlockPaths: paths];
}

+ (BOOL)isNodeLocked:(FSNode *)node
{
  return [[self sharedInstance] isNodeLocked: node];
}

+ (BOOL)isPathLocked:(NSString *)path
{
  return [[self sharedInstance] isPathLocked: path];
}

+ (void)setUseThumbnails:(BOOL)value
{
  [[self sharedInstance] setUseThumbnails: value];
}

+ (NSArray *)availableExtendedInfoNames
{
  return [[self sharedInstance] availableExtendedInfoNames];
}

+ (NSDictionary *)extendedInfoOfType:(NSString *)type
                             forNode:(FSNode *)anode
{
  return [[self sharedInstance] extendedInfoOfType: type forNode: anode];
}

@end










