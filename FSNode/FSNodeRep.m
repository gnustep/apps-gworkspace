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

#define LABEL_W_FACT (8.0)

static FSNodeRep *shared = nil;

@interface FSNodeRep (PrivateMethods)

- (id)initSharedInstance;

- (NSImage *)resizedIcon:(NSImage *)icon 
                  ofSize:(int)size;

- (NSImage *)icon:(NSImage *)icon 
      dissolvedBy:(float)delta;

- (void)prepareThumbnailsCache;

- (NSImage *)thumbnailForPath:(NSString *)apath;

- (void)loadExtendedInfoModules;

- (NSArray *)bundlesWithExtension:(NSString *)extension 
												   inPath:(NSString *)path;

@end


@implementation FSNodeRep (PrivateMethods)

+ (void)initialize
{
  if ([self class] == [FSNodeRep class]) {
    [FSNodeRep sharedInstance];              
  }
}

- (id)initSharedInstance
{    
  self = [super init];
    
  if (self) {
    NSBundle *bundle = [NSBundle bundleForClass: [FSNodeRep class]];
    NSString *imagepath;
    BOOL isdir;
    
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
          
    labelWFactor = LABEL_W_FACT;
    
    oldresize = [[NSUserDefaults standardUserDefaults] boolForKey: @"old_resize"];
    
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
    
    defSortOrder = FSNInfoNameType;
    hideSysFiles = NO;
    usesThumbnails = NO;
      
    lockedPaths = [NSMutableArray new];	
    hiddenPaths = [NSArray new];
    volumes = [[NSMutableSet alloc] initWithCapacity: 1];
    
    [self loadExtendedInfoModules];
  }
    
  return self;
}

- (NSImage *)resizedIcon:(NSImage *)icon 
                  ofSize:(int)size
{
  if (oldresize == NO) {
    CREATE_AUTORELEASE_POOL(arp);
    NSSize icnsize = [icon size];
	  NSRect srcr = NSZeroRect;
	  NSRect dstr = NSZeroRect;  
    float fact;
    NSSize newsize;	
    NSImage *newIcon;
    NSBitmapImageRep *rep;

    if (icnsize.width >= icnsize.height) {
      fact = icnsize.width / size;
    } else {
      fact = icnsize.height / size;
    }

    newsize = NSMakeSize(icnsize.width / fact, icnsize.height / fact);
	  srcr.size = icnsize;
	  dstr.size = newsize;

    newIcon = [[NSImage alloc] initWithSize: newsize];

    NS_DURING
      {
		    [newIcon lockFocus];

        [icon drawInRect: dstr 
                fromRect: srcr 
               operation: NSCompositeSourceOver 
                fraction: 1.0];

        rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: dstr];

        if (rep) {
          [newIcon addRepresentation: rep];
          RELEASE (rep); 
        }

		    [newIcon unlockFocus];
      }
    NS_HANDLER
      {
        newIcon = [icon copy];
	      [newIcon setScalesWhenResized: YES];
	      [newIcon setSize: newsize];  
      }
    NS_ENDHANDLER

    RELEASE (arp);

    return [newIcon autorelease];  
  
  } else {
    CREATE_AUTORELEASE_POOL(arp);
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
    RELEASE (arp);

    return [newIcon autorelease];  
  }

  return nil;
}

- (NSImage *)icon:(NSImage *)icon 
      dissolvedBy:(float)delta
{
  if (oldresize == NO) {
    CREATE_AUTORELEASE_POOL(arp);
    NSSize sz = [icon size];
    NSImage *newIcon = [[NSImage alloc] initWithSize: sz];
    NSBitmapImageRep *rep;
    NSRect r = NSZeroRect;
    
    NS_DURING
      {
		    [newIcon lockFocus];
        
        [icon dissolveToPoint: NSZeroPoint fraction: delta];
        r.size = sz;
        rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect: r];

        if (rep) {
          [newIcon addRepresentation: rep];
          RELEASE (rep); 
        }

		    [newIcon unlockFocus];
      }
    NS_HANDLER
      {
        newIcon = [icon copy];
      }
    NS_ENDHANDLER

    RELEASE (arp);

    return [newIcon autorelease];  
    
  } else {
    return icon;
  }
}

- (void)prepareThumbnailsCache
{
  NSString *dictName = @"thumbnails.plist";
  NSString *dictPath = [thumbnailDir stringByAppendingPathComponent: dictName];
  NSDictionary *tdict;
  
  DESTROY (tumbsCache);
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

- (NSImage *)thumbnailForPath:(NSString *)apath
{
  if (usesThumbnails && tumbsCache) {
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

@end


@implementation FSNodeRep 

- (void)dealloc
{
  TEST_RELEASE (extInfoModules);
	TEST_RELEASE (lockedPaths);
  TEST_RELEASE (volumes);
  TEST_RELEASE (hiddenPaths);
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

+ (FSNodeRep *)sharedInstance
{
	if (shared == nil) {
		shared = [[FSNodeRep alloc] initSharedInstance];
	}	
  return shared;
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

  if (hiddenNames || hideSysFiles || [hiddenPaths count]) {
    NSMutableArray *filteredNames = [NSMutableArray array];
	  int i;

    for (i = 0; i < [fnames count]; i++) {
      NSString *fname = [fnames objectAtIndex: i];
      NSString *fpath = [path stringByAppendingPathComponent: fname];
      BOOL hidden = NO;
    
      if ([fname hasPrefix: @"."] && hideSysFiles) {
        hidden = YES;  
      }
    
      if (hiddenNames && [hiddenNames containsObject: fname]) {
        hidden = YES;  
      }

      if ([hiddenPaths containsObject: fpath]) {
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

- (NSImage *)iconOfSize:(int)size 
                forNode:(FSNode *)node
{
  NSString *nodepath = [node path];
  NSImage *icon = nil;
	NSSize icnsize;

  if (usesThumbnails) {
    icon = [self thumbnailForPath: nodepath];
  }

  if (icon == nil) {
    if (([node isMountPoint] && [volumes containsObject: nodepath])
                                  || [volumes containsObject: nodepath]) {
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

- (NSImage *)multipleSelectionIconOfSize:(int)size
{
  NSSize icnsize = [multipleSelIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: multipleSelIcon ofSize: size];
  }  
  
  return multipleSelIcon;
}

- (NSImage *)openFolderIconOfSize:(int)size 
                          forNode:(FSNode *)node
{
  NSString *ipath = [[node path] stringByAppendingPathComponent: @".opendir.tiff"];
  NSImage *icon = nil;

  if ([fm isReadableFileAtPath: ipath]) {
    NSImage *img = [[NSImage alloc] initWithContentsOfFile: ipath];

    if (img) {
      icon = AUTORELEASE (img);
    } else {
      if ([node isApplication]) {
        icon = [self icon: [self iconOfSize: size forNode: node] dissolvedBy: 0.7];
      } else {
        icon = openFolderIcon;
      }
    }      
  } else {
    if ([node isMountPoint]) {
      icon = openHardDiskIcon;
    } else if ([node isApplication]) {    
      icon = [self icon: [self iconOfSize: size forNode: node] dissolvedBy: 0.7];
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

- (NSImage *)workspaceIconOfSize:(int)size
{
  NSSize icnsize = [workspaceIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: workspaceIcon ofSize: size];
  }  
  
  return workspaceIcon;
}

- (NSImage *)trashIconOfSize:(int)size
{
  NSSize icnsize = [trashIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: trashIcon ofSize: size];
  }  
  
  return trashIcon;
}

- (NSImage *)trashFullIconOfSize:(int)size
{
  NSSize icnsize = [trashFullIcon size];

  if ((icnsize.width > size) || (icnsize.height > size)) {
    return [self resizedIcon: trashFullIcon ofSize: size];
  }  
  
  return trashFullIcon;
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

- (float)highlightHeightFactor
{
  return 0.8125;
}

- (int)labelMargin
{
  return 4;
}

- (float)labelWFactor
{
  return labelWFactor;  
}

- (void)setLabelWFactor:(float)f
{
  labelWFactor = f;
}

- (int)defaultIconBaseShift
{
  return 12;
}

- (void)setDefaultSortOrder:(int)order
{
  defSortOrder = order;
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

- (void)setHideSysFiles:(BOOL)value
{
  hideSysFiles = value;
}

- (BOOL)hideSysFiles
{
  return hideSysFiles;
}

- (void)setHiddenPaths:(NSArray *)paths
{
  ASSIGN (hiddenPaths, paths);
}

- (NSArray *)hiddenPaths
{
  return hiddenPaths;
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

- (void)setVolumes:(NSArray *)vls
{
  [volumes removeAllObjects];
  [volumes addObjectsFromArray: vls];
}

- (void)addVolumeAt:(NSString *)path
{
  [volumes addObject: path];
}

- (void)removeVolumeAt:(NSString *)path
{
  [volumes removeObject: path];
}

- (void)setUseThumbnails:(BOOL)value
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
    
  usesThumbnails = value;
  
  if (usesThumbnails) {
    [self prepareThumbnailsCache];
  }
  
  [defaults setBool: usesThumbnails forKey: @"use_thumbnails"];
}

- (BOOL)usesThumbnails
{
  return usesThumbnails;
}

- (void)thumbnailsDidChange:(NSDictionary *)info
{
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










