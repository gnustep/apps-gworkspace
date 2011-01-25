/* FSNodeRep.m
 *  
 * Copyright (C) 2004-2011 Free Software Foundation, Inc.
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

#include <math.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "FSNodeRep.h"
#import "FSNFunctions.h"
#import "ExtendedInfo.h"
#import "config.h"

#ifndef __APPLE__
  #if	defined(HAVE_GETMNTENT) && defined (MNT_DIR)
    #if	defined(HAVE_MNTENT_H)
      #include <mntent.h>
    #elif defined(HAVE_SYS_MNTENT_H)
      #include <sys/mntent.h>
    #else
      #undef HAVE_GETMNTENT
    #endif
  #endif
#else
  #ifdef HAVE_GETMNTINFO
    #include <sys/param.h>
    #include <sys/ucred.h>
    #include <sys/mount.h>
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
    reservedNames = [[NSMutableSet alloc] initWithCapacity: 1];
    
    [self loadExtendedInfoModules];
    
    systype = [[NSProcessInfo processInfo] operatingSystem];
  }
    
  return self;
}

- (void)loadExtendedInfoModules
{
  NSString *bundlesDir;
  NSMutableArray *bundlesPaths;
  NSEnumerator *enumerator;
  NSMutableArray *loaded;
  int i;
  
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
  RELEASE (workspaceIcon);
  RELEASE (trashIcon);
  RELEASE (trashFullIcon);
        
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

  if ([fm fileExistsAtPath: hdnFilePath])
    hiddenNames = [[NSString stringWithContentsOfFile: hdnFilePath] componentsSeparatedByString: @"\n"];
 

  if (hiddenNames || hideSysFiles || [hiddenPaths count])
    {
      NSMutableArray *filteredNames = [NSMutableArray array];
      int i;

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

- (float)heighOfFont:(NSFont *)font
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

#if !defined(HAVE_GETMNTENT) || !defined(MNT_DIR)
  #ifndef __APPLE__
    static char mtabuf[1024] = "";
  #endif
#endif

- (NSArray *)mountedVolumes
{
  NSMutableArray *volumes = [NSMutableArray array];
  
#ifndef __APPLE__
#if defined(HAVE_GETMNTENT) && defined(MNT_DIR)
  if ([[NSFileManager defaultManager] fileExistsAtPath: @"/etc/mtab"])
    {

      FILE *fp = fopen("/etc/mtab", "r");
      struct mntent	*mnt;

      while ((mnt = getmntent(fp)) != NULL )
	{ 
	  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

	  [dict setObject: [NSString stringWithUTF8String: mnt->MNT_FSNAME]
		   forKey: @"name"]; 
	  [dict setObject: [NSString stringWithUTF8String: mnt->MNT_DIR]
		   forKey: @"dir"];  
	  [dict setObject: [NSString stringWithUTF8String: mnt->MNT_FSTYPE]
		   forKey: @"type"];  

	  [volumes addObject: dict];
	}

      fclose(fp);
    
    }
  else
    {
      /* FIXME add something for Hurd */
      
    }       
        
#else   // NO GETMNTENT
  unsigned int systype = [[NSProcessInfo processInfo] operatingSystem];
  NSString *mtab = nil;

  if (systype == NSGNULinuxOperatingSystem)
    {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      NSString *mtabpath = [defaults stringForKey: @"GSMtabPath"];
      NSLog(@"Linux");
      if (mtabpath == nil)
	mtabpath = @"/etc/mtab";

      if ([[NSFileManager defaultManager] fileExistsAtPath: mtabpath])
	{
	  mtab = [NSString stringWithContentsOfFile: mtabpath];
	}
      if (mtab)
	{
	  NSArray *lines = [mtab componentsSeparatedByString: @"\n"];
	  int i;
      
	  for (i = 0; i < [lines count]; i++)
	    {
	      NSString *line = [lines objectAtIndex: i];
        
	      if ([line length])
		{
		  NSArray	*parts = [line componentsSeparatedByString: @" "];

		  if ([parts count] == 6)
		    {  
		      NSMutableDictionary *dict = [NSMutableDictionary dictionary];

		      [dict setObject: [parts objectAtIndex: 0] forKey: @"name"]; 
		      [dict setObject: [parts objectAtIndex: 1] forKey: @"dir"]; 
		      [dict setObject: [parts objectAtIndex: 2] forKey: @"type"]; 
                        
		      [volumes addObject: dict];
		    }
		}
	    }
	}
    }
  else if (systype == NSBSDOperatingSystem)
    {
      /* FIXME: this code appears to be FreeBSD only */
      NSTask *task = [NSTask new]; 
      NSPipe *pipe = [NSPipe pipe];
      NSFileHandle *handle = [pipe fileHandleForReading];
      NSString *mountStr = nil;

      [task setLaunchPath: @"mount"];
      [task setStandardOutput: pipe];    

      [task launch];
      [task waitUntilExit];

      if ([task terminationStatus] == 0)
	{
	  NSData *data = [handle readDataToEndOfFile];	      
	  unsigned len = [data length];

	  mountStr = [[NSString alloc] initWithData: data encoding:NSUTF8StringEncoding];
	}

      RELEASE (task);     
      NSLog(@"mountStr: %@", mountStr);
      if (mountStr)
	{
	  NSArray *lines = [mountStr componentsSeparatedByString: @"\n"];
	  int i;
      
	  for (i = 0; i < [lines count]; i++)
	    {
	      NSString *line = [lines objectAtIndex: i];
        
	      if ([line length])
		{
		  NSArray	*parts1 = [line componentsSeparatedByString: @" on "];
		  if ([parts1 count] == 2)
		    {  
		      NSMutableDictionary *dict = [NSMutableDictionary dictionary];

		      [dict setObject: [parts1 objectAtIndex: 0] forKey: @"name"];
		      if ([[parts1 objectAtIndex: 1] rangeOfString: @" type "].location == NSNotFound)
			{
			  /* FreeBSD
			     /dev/ad0s1a on / (ufs, local)
			  */
			  NSArray *parts2 = [[parts1 objectAtIndex: 1] componentsSeparatedByString: @" "];
			  NSString *typeStr;
			  NSRange endRange;

			  typeStr = [parts2 objectAtIndex: 1];
			  [dict setObject: [parts2 objectAtIndex: 0] forKey: @"dir"]; 
			  if ([typeStr length] > 2)
			    {

			      NSString *cleanTypeStr;
			      cleanTypeStr = [typeStr substringWithRange: NSMakeRange(1, [typeStr length]-1)];
			      [dict setObject: cleanTypeStr forKey: @"type"];
			    }
			}
		      else
			{
			  /* OpenBSD, NetBSD
			     /dev/wd0a on / type ffs (local)
			     /dev/wd0f on /usr type ffs (local, nodev)
			  */
			  NSArray *parts2 = [[parts1 objectAtIndex: 1] componentsSeparatedByString: @" "];
			  if ([parts2 count] >= 4)
			    {
			      [dict setObject: [parts2 objectAtIndex: 0] forKey: @"dir"]; 
			      [dict setObject: [parts2 objectAtIndex: 2] forKey: @"type"];
			    };
			}                     
		      [volumes addObject: dict];
		    }
		}
	    }
	}
    }
  else
    {
      NSLog(@"Unknown operating system: %u", systype);
    }
    
#endif
#else   // __APPLE__
  struct statfs *buf;
  int i, count;
  
  count = getmntinfo(&buf, 0);
  
  for (i = 0; i < count; i++)
    {
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];  
  
      [dict setObject: [NSString stringWithUTF8String: buf[i].f_mntfromname]
	       forKey: @"name"]; 
      [dict setObject: [NSString stringWithUTF8String: buf[i].f_mntonname]
	       forKey: @"dir"]; 
      [dict setObject: [NSString stringWithUTF8String: buf[i].f_fstypename]
	       forKey: @"type"]; 

      [volumes addObject: dict];
    }
#endif
  NSLog(@"Volumes %@", volumes);   
  return volumes;
}

- (NSArray *)removableMediaPaths
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *domain;
  NSArray *removables;
    
  domain = [defaults persistentDomainForName: NSGlobalDomain];
  removables = [domain objectForKey: @"GSRemovableMediaPaths"];

  if (removables == nil) {
    CREATE_AUTORELEASE_POOL(arp);
    NSMutableDictionary *mdomain = [domain mutableCopy];  
    unsigned int systype = [[NSProcessInfo processInfo] operatingSystem];
  
    switch (systype) {
      case NSGNULinuxOperatingSystem:
        removables = [NSArray arrayWithObjects: @"/mnt/floppy", @"/mnt/cdrom", nil];
        break;

      case NSBSDOperatingSystem:
        removables = [NSArray arrayWithObjects: @"/cdrom", nil];
        break;
    
      default:
        break;
    }
    
    if (removables) {
      [mdomain setObject: removables forKey: @"GSRemovableMediaPaths"];
      [defaults setPersistentDomain: mdomain forName: NSGlobalDomain];
      [defaults synchronize];
    }
    
    RELEASE (mdomain);
    RELEASE (arp);
  }
    
  return removables;
}

- (NSArray *)reservedMountNames
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *domain;
  NSArray *reserved;

  [defaults synchronize];
  domain = [defaults persistentDomainForName: NSGlobalDomain];
  reserved = [domain objectForKey: @"GSReservedMountNames"];
  
  if (reserved == nil) {
    CREATE_AUTORELEASE_POOL(arp);
    NSMutableDictionary *mdomain = [domain mutableCopy];  
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

      case NSMACHOperatingSystem:
        reserved = [NSArray arrayWithObjects: @"devfs", @"fdesc", 
                                                    @"<volfs>", nil];
        break;
    
      default:
        break;
    }
    
    if (reserved) {
      [mdomain setObject: reserved forKey: @"GSReservedMountNames"];
      [defaults setPersistentDomain: mdomain forName: NSGlobalDomain];
      [defaults synchronize];
    }
    
    RELEASE (mdomain);
    RELEASE (arp);
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
  return [self getFileSystemInfoForPath: fullPath
		                 isRemovable: removableFlag
		                  isWritable: writableFlag
		               isUnmountable: unmountableFlag
		                 description: description
			                      type: fileSystemType
                usingVolumesInfo: nil];
}

- (BOOL)getFileSystemInfoForPath:(NSString *)fullPath
		                 isRemovable:(BOOL *)removableFlag
		                  isWritable:(BOOL *)writableFlag
		               isUnmountable:(BOOL *)unmountableFlag
		                 description:(NSString **)description
			                      type:(NSString **)fileSystemType
                usingVolumesInfo:(NSArray *)info
{
  NSArray *mounted = ((info == nil) ? [self mountedVolumes] : info);
  NSArray *removables = [self removableMediaPaths];
  int i;

  for (i = 0; i < [mounted count]; i++) {
    NSDictionary *dict = [mounted objectAtIndex: i];
    NSString *mountPoint = [dict objectForKey: @"dir"];
    NSString *fsType = [dict objectForKey: @"type"];
  
    if ([mountPoint isEqual: fullPath]) {  
      *removableFlag = [removables containsObject: mountPoint];
      *writableFlag = [[NSFileManager defaultManager] isWritableFileAtPath: fullPath];
      *unmountableFlag = YES;
      *description = fsType;
      *fileSystemType = fsType;

      return YES;
    }
  }
  
  return NO;
}

- (NSArray *)mountedLocalVolumePaths
{
  NSMutableArray *mpoints = [NSMutableArray array];
  NSArray *mounted = [self mountedVolumes];
  NSArray *reserved = [self reservedMountNames];
  unsigned i;

  for (i = 0; i < [mounted count]; i++)
    {
      NSDictionary *dict = [mounted objectAtIndex: i];

      if ([reserved containsObject: [dict objectForKey: @"name"]] == NO) {
	[mpoints addObject: [dict objectForKey: @"dir"]];
      }
    }
  
  return mpoints;
}

- (NSArray *)mountedRemovableMedia
{
  NSMutableArray *mpoints = [NSMutableArray array];
  NSArray *mounted = [self mountedVolumes];
  NSArray *removables = [self removableMediaPaths];
  NSArray *reserved = [self reservedMountNames];
  NSMutableArray *names = [NSMutableArray array];  
  unsigned i;

  for (i = 0; i < [mounted count]; i++) {
    NSDictionary *dict = [mounted objectAtIndex: i];
    NSString *name = [dict objectForKey: @"name"];
    NSString *dir = [dict objectForKey: @"dir"];

    if (([reserved containsObject: name] == NO) 
                        && [removables containsObject: dir]) {
      [mpoints addObject: dir];
    }
  }

  for (i = 0; i < [mpoints count]; i++) {
    BOOL removableFlag;
    BOOL writableFlag;
    BOOL unmountableFlag;
    NSString *description;
    NSString *fileSystemType;
    NSString *name = [mpoints objectAtIndex: i];

    if ([self getFileSystemInfoForPath: name
		              isRemovable: &removableFlag
		              isWritable: &writableFlag
		              isUnmountable: &unmountableFlag
		              description: &description
		              type: &fileSystemType
      usingVolumesInfo: mounted] && removableFlag) {
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









