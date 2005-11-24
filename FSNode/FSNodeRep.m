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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <math.h>
#include "FSNodeRep.h"
#include "FSNFunctions.h"
#include "ExtendedInfo.h"

#define LABEL_W_FACT (8.0)

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
    
    iconsCache = [NSMutableDictionary new];
    rootPath = path_separator();
    RETAIN (rootPath);
    
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
  TEST_RELEASE (rootPath);
  TEST_RELEASE (hiddenPaths);
  TEST_RELEASE (iconsCache);
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

- (NSSet *)volumes
{
  return volumes;
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


@implementation NSWorkspace (mounting)

static char mtabuf[1024] = "";

- (NSString *)mtabContents
{
  unsigned int systype = [[NSProcessInfo processInfo] operatingSystem];
  NSString *mtab = nil;

  if (systype == NSGNULinuxOperatingSystem) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *mtabpath = [defaults stringForKey: @"GSMtabPath"];

    if (mtabpath == nil) {
      mtabpath = @"/etc/mtab";
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath: mtabpath]) {
      mtab = [NSString stringWithContentsOfFile: mtabpath];
    }
    
  } else if (systype == NSBSDOperatingSystem) {
    NSTask *task = [NSTask new]; 
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *handle = [pipe fileHandleForReading];
    
    [task setLaunchPath: @"mount"];
    [task setArguments: [NSArray arrayWithObject: @"-p"]];
    [task setStandardOutput: pipe];    
    
    [task launch];
    [task waitUntilExit];
    
    if ([task terminationStatus] == 0) {
      NSData *data = [handle readDataToEndOfFile];
      unsigned len = [data length];
      
      if (len) {
        const char *bytes = [data bytes];
        int i;
          
        bzero(mtabuf, 1024);
        
        for (i = 0; i < len; i++) {
          if (bytes[i] == '\t') {
            mtabuf[i] = ' ';
          } else {
            mtabuf[i] = bytes[i]; 
          } 
        }
            
        mtab = [NSString stringWithUTF8String: mtabuf];
      }
    }
    
    RELEASE (task);     
  }

  return mtab;
}

- (NSArray *)removableMediaPaths
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *removables = [defaults arrayForKey: @"GSRemovableMediaPaths"];

  if (removables == nil) {
    unsigned int systype = [[NSProcessInfo processInfo] operatingSystem];
  
    switch(systype) {
      case NSGNULinuxOperatingSystem:
        removables = [NSArray arrayWithObjects: @"/mnt/floppy", @"/mnt/cdrom", nil];
        break;

      case NSBSDOperatingSystem:
        removables = [NSArray arrayWithObjects: @"/cdrom", nil];
        break;
    
      default:
        break;
    }
  }

  return removables;
}

- (NSArray *)reservedMountPoints
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *reserved = [defaults arrayForKey: @"GSReservedMountPoints"];

  if (reserved == nil) {
    unsigned int systype = [[NSProcessInfo processInfo] operatingSystem];
  
    switch(systype) {
      case NSGNULinuxOperatingSystem:
        reserved = [NSArray arrayWithObjects: @"proc", @"devpts", @"shm", 
                                                    @"usbdevfs", @"devpts", 
                                                    @"sysfs", @"tmpfs", nil];
        break;

      case NSBSDOperatingSystem:
        reserved = [NSArray arrayWithObjects: @"devfs", nil];
        break;
    
      default:
        break;
    }
  }

  return reserved;
}

- (BOOL)getFileSystemInfoForPath:(NSString *)fullPath
		                 isRemovable:(BOOL *)removableFlag
		                  isWritable:(BOOL *)writableFlag
		               isUnmountable:(BOOL *)unmountableFlag
		                 description:(NSString **)description
			                      type:(NSString **)fileSystemType
{
  NSString *mtab = [self mtabContents];
       
  if (mtab) {
    NSArray *mounts = [mtab componentsSeparatedByString: @"\n"];
    NSArray *removables = [self removableMediaPaths];
    int i;

    for (i = 0; i < [mounts count]; i++) {
      NSString *mount = [mounts objectAtIndex: i];

      if ([mount length]) {
        NSArray	*parts = [mount componentsSeparatedByString: @" "];

        if ([parts count] == 6) {
          NSString *mountPoint = [parts objectAtIndex: 1];
          NSString *fsType = [parts objectAtIndex: 2];
          NSString *fsOptions = [parts objectAtIndex: 3];

          if ([mountPoint isEqual: fullPath]) {
            NSScanner *scanner = [NSScanner scannerWithString: fsOptions];

            *removableFlag = [removables containsObject: mountPoint];
            *writableFlag = [scanner scanString: @"rw" intoString: NULL];
            *unmountableFlag = YES;
            *description = fsType;
            *fileSystemType = fsType;

            return YES;
          }
        }
      }
    }
  }
  
  return NO;
}

- (NSArray *)mountedLocalVolumePaths
{
  NSString *mtab = [self mtabContents];
  NSMutableArray *names = [NSMutableArray array];
   
  if (mtab) {
    NSArray *mounts = [mtab componentsSeparatedByString: @"\n"];
    NSArray *reserved = [self reservedMountPoints];
    int i;

    for (i = 0; i < [mounts count]; i++) {
      NSString *mount = [mounts objectAtIndex: i];

      if ([mount length]) {
        NSArray	*parts = [mount componentsSeparatedByString: @" "];

        if ([parts count] >= 2) {
          NSString *type = [parts objectAtIndex: 2];

          if ([reserved containsObject: type] == NO) {
	          [names addObject: [parts objectAtIndex: 1]];
	        }
        }
      } 
    }
  }
  
  return names;
}

- (NSArray *)mountedRemovableMedia
{
  NSArray	*volumes = [self mountedLocalVolumePaths];
  NSMutableArray *names = [NSMutableArray array];
  unsigned	i;

  for (i = 0; i < [volumes count]; i++) {
    BOOL removableFlag;
    BOOL writableFlag;
    BOOL unmountableFlag;
    NSString *description;
    NSString *fileSystemType;
    NSString *name = [volumes objectAtIndex: i];

    if ([self getFileSystemInfoForPath: name
		              isRemovable: &removableFlag
		              isWritable: &writableFlag
		              isUnmountable: &unmountableFlag
		              description: &description
		              type: &fileSystemType] && removableFlag) {
	    [names addObject: name];
	  }
  }

  return names;
}

- (NSArray *)mountNewRemovableMedia
{
  NSArray *removables = [self removableMediaPaths];
  NSArray *mountedMedia = [self mountedRemovableMedia]; 
  NSMutableArray *willMountMedia = [NSMutableArray array];
  NSMutableArray *newlyMountedMedia = [NSMutableArray array];
  int i;

  for (i = 0; i < [removables count]; i++) {
    NSString *removable = [removables objectAtIndex: i];
    
    if ([mountedMedia containsObject: removable] == NO) {
      [willMountMedia addObject: removable];
    }
  }  
  
  for (i = 0; i < [willMountMedia count]; i++) {
    NSString *media = [willMountMedia objectAtIndex: i];
    NSTask *task = [NSTask launchedTaskWithLaunchPath: @"mount"
                                arguments: [NSArray arrayWithObject: media]];
      
    if (task) {
      [task waitUntilExit];
      
      if ([task terminationStatus] == 0) {
        NSDictionary *userinfo = [NSDictionary dictionaryWithObject: media 
                                                      forKey: @"NSDevicePath"];

        [[self notificationCenter] postNotificationName: NSWorkspaceDidMountNotification
                                  object: self
                                userInfo: userinfo];

        [newlyMountedMedia addObject: media];
      }
    }
  }

  return newlyMountedMedia;
}

- (BOOL)unmountAndEjectDeviceAtPath:(NSString *)path
{
  unsigned int systype = [[NSProcessInfo processInfo] operatingSystem];
  NSArray	*volumes = [self mountedLocalVolumePaths];

  if ([volumes containsObject: path]) {
    NSDictionary *userinfo;
    NSTask *task;

    userinfo = [NSDictionary dictionaryWithObject: path forKey: @"NSDevicePath"];

    [[self notificationCenter] postNotificationName: NSWorkspaceWillUnmountNotification
				                object: self
				              userInfo: userinfo];

    task = [NSTask launchedTaskWithLaunchPath: @"umount"
				                            arguments: [NSArray arrayWithObject: path]];

    if (task) {
      [task waitUntilExit];
      if ([task terminationStatus] != 0) {
	      return NO;
	    } 
    } else {
      return NO;
    }

    [[self notificationCenter] postNotificationName: NSWorkspaceDidUnmountNotification
				                object: self
				              userInfo: userinfo];

    if (systype == NSGNULinuxOperatingSystem) {
      task = [NSTask launchedTaskWithLaunchPath: @"eject"
				                              arguments: [NSArray arrayWithObject: path]];
    }
    
    return YES;
  }
  
  return NO;
}

@end









