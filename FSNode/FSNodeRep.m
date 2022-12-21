/* FSNodeRep.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>

#import "FSNodeRep.h"
#import "FSNFunctions.h"
#import "ExtendedInfo.h"
#import "config.h"


#ifdef HAVE_GETMNTINFO
  #include <sys/param.h>
  #include <sys/ucred.h>
  #include <sys/mount.h>
#ifdef HAVE_SYS_TYPES_H
  #include <sys/types.h>
#ifdef HAVE_SYS_STATVFS_H
  #include <sys/statvfs.h>
  #ifdef __NetBSD__
    #define statfs statvfs
  #endif
#endif
#endif /* HAVE_SYSTYPES */
#else 
  #if	defined(HAVE_GETMNTENT) && defined (MNT_DIR)
    #if	defined(HAVE_MNTENT_H)
      #include <mntent.h>
    #elif defined(HAVE_SYS_MNTENT_H)
      #include <sys/mntent.h>
    #else
      #undef HAVE_GETMNTENT
    #endif
  #endif
#endif

#define LABEL_W_FACT (8.0)
#define FONT_H_FACT (1.5)

static FSNodeRep *shared = nil;

@interface FSNodeRep (PrivateMethods)

- (id)initSharedInstance;

- (void)loadExtendedInfoModules;

- (NSArray *)bundlesWithExtension:(NSString *)extension 
			   inPath:(NSString *)path;

@end


@implementation FSNodeRep (PrivateMethods)

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO) {
    if ([self class] == [FSNodeRep class]) {
      [FSNodeRep sharedInstance];     
    }
    initialized = YES;
  }
}

/*
 * Loads and caches named images
 * Images coming from GSTheme need to be recached on a theme change
 */
- (void)cacheIcons
{
  [multipleSelIcon release];
  multipleSelIcon = [[NSImage imageNamed:NSImageNameMultipleDocuments] retain];
  [trashIcon release];
  trashIcon = [[NSImage imageNamed:NSImageNameTrashEmpty] retain];
  [trashFullIcon retain];
  trashFullIcon = [[NSImage imageNamed:NSImageNameTrashFull] retain];
}

- (id)initSharedInstance
{    
  self = [super init];
    
  if (self) {
    NSBundle *bundle = [NSBundle bundleForClass: [FSNodeRep class]];
    NSString *imagepath;
    BOOL isdir;
    NSString *libraryDir;
    NSNotificationCenter *nc;
    
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    nc = [NSNotificationCenter defaultCenter];
          
    labelWFactor = LABEL_W_FACT;
    
    oldresize = [[NSUserDefaults standardUserDefaults] boolForKey: @"old_resize"];

    /* images coming form GSTheme */
    [self cacheIcons];

    /* images for which we provide our own resources */
    imagepath = [bundle pathForImageResource: @"FolderOpen"];
    openFolderIcon = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    imagepath = [bundle pathForImageResource: @"HardDisk"];
    hardDiskIcon = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    imagepath = [bundle pathForImageResource: @"HardDiskOpen"];
    openHardDiskIcon = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    
    iconsCache = [NSMutableDictionary new];
    rootPath = path_separator();
    RETAIN (rootPath);
    
    libraryDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
    if (([fm fileExistsAtPath: libraryDir isDirectory: &isdir] && isdir) == NO)
      {
        if ([fm createDirectoryAtPath: libraryDir attributes: nil] == NO)
          {
            NSLog(@"Unable to create the Library directory. Quitting now");
            [NSApp terminate: self];
          }
      }
    thumbnailDir = [libraryDir stringByAppendingPathComponent: @"Thumbnails"];
    RETAIN (thumbnailDir);
    
    if (([fm fileExistsAtPath: thumbnailDir isDirectory: &isdir] && isdir) == NO) {
      if ([fm createDirectoryAtPath: thumbnailDir attributes: nil] == NO) {
        NSLog(@"Unable to create the thumbnails directory. Quitting now");
        [NSApp terminate: self];
      }
    }
    
    defSortOrder = FSNInfoNameType;
    hideSysFiles = NO;
    usesThumbnails = NO;
      
    lockedPaths = [NSMutableArray new];	
    hiddenPaths = [NSArray new];
    volumes = [[NSMutableSet alloc] initWithCapacity: 1];
    [self setVolumes:[ws mountedRemovableMedia]];
    reservedNames = [[NSMutableSet alloc] initWithCapacity: 1];
    
    [self loadExtendedInfoModules];
    
    systype = [[NSProcessInfo processInfo] operatingSystem];

    /* we observe a theme change to re-cache icons */
    [nc addObserver:self selector:@selector(themeDidActivate:) name:GSThemeDidActivateNotification object:nil];
  }
    
  return self;
}

- (void)loadExtendedInfoModules
{
  NSString *bundlesDir;
  NSMutableArray *bundlesPaths;
  NSEnumerator *enumerator;
  NSMutableArray *loaded;
  NSUInteger i;
  
  bundlesPaths = [NSMutableArray array];

  enumerator = [NSSearchPathForDirectoriesInDomains
    (NSLibraryDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((bundlesDir = [enumerator nextObject]) != nil)
    {
      bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
      [bundlesPaths addObjectsFromArray:
	[self bundlesWithExtension: @"extinfo" inPath: bundlesDir]];
    }

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

- (void)themeDidActivate:(id)sender
{
  /* we clean the cache of theme-derived images */
  [iconsCache removeAllObjects];
  [self cacheIcons];
}

@end


@implementation FSNodeRep 

- (void)dealloc
{
  RELEASE (extInfoModules);
  RELEASE (lockedPaths);
  RELEASE (volumes);
  RELEASE (reservedNames);
  RELEASE (rootPath);
  RELEASE (hiddenPaths);
  RELEASE (iconsCache);
  RELEASE (tumbsCache);
  RELEASE (thumbnailDir);
  RELEASE (multipleSelIcon);
  RELEASE (openFolderIcon);
  RELEASE (hardDiskIcon);
  RELEASE (openHardDiskIcon);
  RELEASE (trashIcon);
  RELEASE (trashFullIcon);
        
  [super dealloc];
}

+ (FSNodeRep *)sharedInstance
{
  if (shared == nil)
    {
      shared = [[FSNodeRep alloc] initSharedInstance];
    }
  return shared;
}

- (NSArray *)directoryContentsAtPath:(NSString *)path
{
  NSArray *fnames = [fm directoryContentsAtPath: path];
  NSString *hdnFilePath = [path stringByAppendingPathComponent: @".hidden"];
  NSArray *hiddenNames = nil;  

  if ([fm fileExistsAtPath: hdnFilePath])
    hiddenNames = [[NSString stringWithContentsOfFile: hdnFilePath] componentsSeparatedByString: @"\n"];
 

  if (hiddenNames || hideSysFiles || [hiddenPaths count])
    {
      NSMutableArray *filteredNames = [NSMutableArray array];
      NSUInteger i;

      for (i = 0; i < [fnames count]; i++)
	{
	  NSString *fname = [fnames objectAtIndex: i];
	  NSString *fpath = [path stringByAppendingPathComponent: fname];
	  BOOL hidden = NO;
    
	  if ([fname hasPrefix: @"."] && hideSysFiles)
	    hidden = YES;  
    
	  if (hiddenNames && [hiddenNames containsObject: fname])
	    hidden = YES;  

	  if ([hiddenPaths containsObject: fpath])
	    hidden = YES;  
      
	  if (hidden == NO)
	    {
	      [filteredNames addObject: fname];
	    }
	}
  
      return filteredNames;
    }
  
  return fnames;
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

- (float)heightOfFont:(NSFont *)font
{
//  return [font defaultLineHeightForFont];
  return ([font pointSize] * FONT_H_FACT);
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
    
  if ([lockedPaths containsObject: path] == NO)
    {
      [lockedPaths addObject: path];
    }
}

- (void)lockPath:(NSString *)path
{
  if ([lockedPaths containsObject: path] == NO)
    {
      [lockedPaths addObject: path];
    }
}

- (void)lockNodes:(NSArray *)nodes
{
  NSUInteger i;
	  
  for (i = 0; i < [nodes count]; i++)
    {
      NSString *path = [[nodes objectAtIndex: i] path];
    
      if ([lockedPaths containsObject: path] == NO)
	{
	  [lockedPaths addObject: path];
	}
    }
}

- (void)lockPaths:(NSArray *)paths
{
  NSUInteger i;
	  
  for (i = 0; i < [paths count]; i++)
    {
      NSString *path = [paths objectAtIndex: i];
    
      if ([lockedPaths containsObject: path] == NO)
	{
	  [lockedPaths addObject: path];
	}
    }
}

- (void)unlockNode:(FSNode *)node
{
  NSString *path = [node path];

  if ([lockedPaths containsObject: path])
    {
      [lockedPaths removeObject: path];
    }
}

- (void)unlockPath:(NSString *)path
{
  if ([lockedPaths containsObject: path])
    {
      [lockedPaths removeObject: path];
    }
}

- (void)unlockNodes:(NSArray *)nodes
{
  NSUInteger i;
	  
  for (i = 0; i < [nodes count]; i++)
    {
      NSString *path = [[nodes objectAtIndex: i] path];
	
      if ([lockedPaths containsObject: path])
	{
	  [lockedPaths removeObject: path];
	}
    }
}

- (void)unlockPaths:(NSArray *)paths
{
  NSUInteger i;
	  
  for (i = 0; i < [paths count]; i++)
    {
      NSString *path = [paths objectAtIndex: i];
      
      if ([lockedPaths containsObject: path])
        {
          [lockedPaths removeObject: path];
        } 
    }
}

- (BOOL)isNodeLocked:(FSNode *)node
{
  NSString *path = [node path];
  NSUInteger i;  
  
  if ([lockedPaths containsObject: path])
    return YES;
	
  for (i = 0; i < [lockedPaths count]; i++)
    {
      NSString *lpath = [lockedPaths objectAtIndex: i];
      
      if (isSubpathOfPath(lpath, path)) {
        return YES;
      }
    }
  
  return NO;
}

- (BOOL)isPathLocked:(NSString *)path
{
  NSUInteger i;  
  
  if ([lockedPaths containsObject: path])
    return YES;
  
  for (i = 0; i < [lockedPaths count]; i++)
    {
      NSString *lpath = [lockedPaths objectAtIndex: i];
      
      if (isSubpathOfPath(lpath, path))
        return YES;
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

- (NSSet *)volumes
{
  return volumes;
}

- (void)setReservedNames:(NSArray *)names
{
  [reservedNames removeAllObjects];
  [reservedNames addObjectsFromArray: names];
}

- (NSSet *)reservedNames
{
  return reservedNames;
}

- (BOOL)isReservedName:(NSString *)name
{
  return [reservedNames containsObject: name];
}

- (unsigned)systemType
{
  return systype;
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
  NSUInteger i;

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
    
    if ([fm fileExistsAtPath: dictPath]) {
      NSDictionary *tdict = [NSDictionary dictionaryWithContentsOfFile: dictPath];

      for (i = 0; i < [created count]; i++) {
        NSString *key = [created objectAtIndex: i];
        NSString *tumbname = [tdict objectForKey: key];
        NSString *tumbpath = [thumbnailDir stringByAppendingPathComponent: tumbname]; 

        if ([fm fileExistsAtPath: tumbpath]) {
          NSImage *tumb = nil;
        
          NS_DURING
            {
          tumb = [[NSImage alloc] initWithContentsOfFile: tumbpath];
          
          if (tumb) {
            [tumbsCache setObject: tumb forKey: key];
            RELEASE (tumb);
          }
            }
          NS_HANDLER
            {
          NSLog(@"BAD IMAGE '%@'", tumbpath);
            }
          NS_ENDHANDLER
        }
      }    
    }  
  }
}

- (NSArray *)availableExtendedInfoNames
{
  NSMutableArray *names = [NSMutableArray array];
  NSUInteger i;
  
  for (i = 0; i < [extInfoModules count]; i++)
    {
      id module = [extInfoModules objectAtIndex: i];
      [names addObject: [module menuName]];
    }
  
  return names;
}

- (NSDictionary *)extendedInfoOfType:(NSString *)type
                             forNode:(FSNode *)anode
{
  NSUInteger i;

  for (i = 0; i < [extInfoModules count]; i++)
    {
      id module = [extInfoModules objectAtIndex: i];
      NSString *mname = [module menuName];
      
      if ([mname isEqual: type])
        {
          return [module extendedInfoForNode: anode];
        }
    }
  
  return nil;
}

@end

