/* DDBPathsManager.m
 *  
 * Copyright (C) 2005-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: July 2005
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

#import "DBKBTreeNode.h"
#import "DBKVarLenRecordsFile.h"
#import "DDBPathsManager.h"
#import "DDBMDStorage.h"
#import "MDModulesProtocol.h"
#import "ddbd.h"

@implementation	DDBPathsManager

- (void)dealloc
{
  RELEASE (mdstorage);
  RELEASE (vlfile);
  RELEASE (tree);
  RELEASE (dummyPaths[0]);
  RELEASE (dummyPaths[1]);
  RELEASE (dummyOffsets[0]);
  RELEASE (dummyOffsets[1]);
  RELEASE (mdmodules);
      
  [super dealloc];
}

- (id)initWithBasePath:(NSString *)bpath
{
  self = [super init];

  if (self) {
    NSEnumerator *enumerator;
    NSString *path;
    NSBundle *bundle;
    NSString *bundlesDir;
    NSArray *bnames;
    NSUInteger i;

    ulen = sizeof(unsigned);
    llen = sizeof(unsigned long);

    path = [bpath stringByAppendingPathComponent: @"paths"];
    vlfile = [[DBKVarLenRecordsFile alloc] initWithPath: path cacheLength: 10];

    path = [bpath stringByAppendingPathComponent: @"paths.index"];
    tree = [[DBKBTree alloc] initWithPath: path order: 16 delegate: self];

    path = [bpath stringByAppendingPathComponent: @"docs"];
    mdstorage = [[DDBMDStorage alloc] initWithPath: path 
                                        levelCount: 100 
                                         dirsDepth: 3];

    ASSIGN (dummyOffsets[0], [NSNumber numberWithUnsignedLong: 1L]);
    ASSIGN (dummyOffsets[1], [NSNumber numberWithUnsignedLong: 2L]);
  
    fm = [NSFileManager defaultManager];
    
    mdmodules = [NSMutableDictionary new];
    
    enumerator = [NSSearchPathForDirectoriesInDomains
      (NSLibraryDirectory, NSAllDomainsMask, YES) objectEnumerator];
    while ((bundlesDir = [enumerator nextObject]) != nil)
      {
	bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];
	bnames = [fm directoryContentsAtPath: bundlesDir];

	for (i = 0; i < [bnames count]; i++) {
	  NSString *bname = [bnames objectAtIndex: i];
	
	  if ([[bname pathExtension] isEqual: @"mdm"]) {
	    NSString *bpath;
	    
	    bpath = [bundlesDir stringByAppendingPathComponent: bname];
	    bundle = [NSBundle bundleWithPath: bpath]; 
	  
	    if (bundle) {
	      Class principalClass = [bundle principalClass];
	    
	      if ([principalClass conformsToProtocol:
		@protocol(MDModulesProtocol)]) {	
		CREATE_AUTORELEASE_POOL (pool);
		id module = [[principalClass alloc] init];
	    
		[mdmodules setObject: module forKey: [module mdtype]];
	    
		RELEASE ((id)module);	
		RELEASE (pool);		
	      }
	    }
	  }
	}
      }
    
    [self addPath: pathsep()];
    [self synchronize];
  }

  return self;
}

- (void)synchronize
{
  [vlfile flush];
  [tree synchronize];
}

- (DDBPath *)ddbpathForPath:(NSString *)path
{
  CREATE_AUTORELEASE_POOL(arp);
  DDBPath *ddbpath = nil;
  DBKBTreeNode *node;
  BOOL exists;
  NSUInteger index;

  DESTROY (dummyPaths[1]);  
  DESTROY (dummyPaths[0]);  
  dummyPaths[0] = [[DDBPath alloc] initForPath: path];

  [tree begin];
  node = [tree nodeOfKey: dummyOffsets[0] getIndex: &index didExist: &exists];
  
  if (exists) {
    NSNumber *offset = [node keyAtIndex: index];
    NSData *data = [vlfile dataAtOffset: offset];
  
    ddbpath = [NSUnarchiver unarchiveObjectWithData: data];
  }
  
  [tree end];  
  DESTROY (dummyPaths[0]);
  RETAIN (ddbpath);
  RELEASE (arp);
  
  return AUTORELEASE (ddbpath);  
}

- (DDBPath *)addPath:(NSString *)path
{
  CREATE_AUTORELEASE_POOL(arp);
  DDBPath *ddbpath = nil;
  DBKBTreeNode *node;
  
  DESTROY (dummyPaths[1]);  
  DESTROY (dummyPaths[0]);  
  dummyPaths[0] = [[DDBPath alloc] initForPath: path];
  
  [tree begin];

  node = [tree insertKey: dummyOffsets[0]];

  if (node) {
    NSString *mdpath = [mdstorage nextEntry];
    NSTimeInterval stamp = [[NSDate date] timeIntervalSinceReferenceDate];
    NSData *data;
    NSNumber *offset;

    [dummyPaths[0] setMDPath: mdpath];
    [dummyPaths[0] setTimestamp: stamp];

    data = [NSArchiver archivedDataWithRootObject: dummyPaths[0]];
    offset = [vlfile writeData: data];

    [node replaceKey: dummyOffsets[0] withKey: offset];
    [self synchronize];
    
    ddbpath = dummyPaths[0];
    RETAIN (ddbpath);
  } 
  
  [tree end];
  
  DESTROY (dummyPaths[0]);  
  RELEASE (arp);
  
  return AUTORELEASE (ddbpath);
}

- (void)removePath:(NSString *)path
{
  CREATE_AUTORELEASE_POOL(arp);
  DBKBTreeNode *node; 
  NSUInteger index;
  BOOL exists;

  DESTROY (dummyPaths[1]);
  DESTROY (dummyPaths[0]);  
  dummyPaths[0] = [[DDBPath alloc] initForPath: path];
  
  [tree begin];
  node = [tree nodeOfKey: dummyOffsets[0] getIndex: &index didExist: &exists];

  if (exists) {
    NSNumber *offset = [node keyAtIndex: index];
    NSData *data = [vlfile dataAtOffset: offset];
    DDBPath *ddbpath = [NSUnarchiver unarchiveObjectWithData: data];
    NSString *mdpath = [ddbpath mdpath];
      
    RETAIN (offset);
    [tree deleteKey: offset];
    [vlfile deleteDataAtOffset: offset]; 
    [mdstorage removeEntry: mdpath]; 
    RELEASE (offset);
  }
  
  [tree end];
  
  DESTROY (dummyPaths[0]);  
  
  RELEASE (arp);  
  
  [self synchronize];
}

- (void)setMetadata:(id)mdata
             ofType:(NSString *)mdtype
            forPath:(NSString *)apath
{
  CREATE_AUTORELEASE_POOL(arp);
  DDBPath *ddbpath = [self ddbpathForPath: apath];
  NSString *path = [mdstorage basePath];
  id module = [self mdmoduleForMDType: mdtype];
  
  if (ddbpath == nil) {
    ddbpath = [self addPath: apath];
  } 

  path = [path stringByAppendingPathComponent: [ddbpath mdpath]];
  
  [module saveData: mdata withBasePath: path];
  
  [self metadataDidChangeForPath: ddbpath];

  if ([apath isEqual: pathsep()] == NO) {
    NSString *parent = [apath stringByDeletingLastPathComponent];
    DDBPath *ppath = [self ddbpathForPath: parent];
    
    if (ppath == nil) {
      [self addPath: parent];
    } else {
      [self metadataDidChangeForPath: ppath];
    }
  }

	[[NSDistributedNotificationCenter defaultCenter] 
        postNotificationName: @"GSMetadataUserAttributeModifiedNotification"
	 								    object: apath 
                    userInfo: nil];

  RELEASE (arp);
}

- (id)metadataOfType:(NSString *)mdtype
             forPath:(NSString *)apath
{
  DDBPath *ddbpath = [self ddbpathForPath: apath];
  id mddata = nil;
  
  if (ddbpath) {
    id module = [self mdmoduleForMDType: mdtype];
    NSString *path = [mdstorage basePath];
    
    path = [path stringByAppendingPathComponent: [ddbpath mdpath]];
    mddata = [module dataWithBasePath: path];
  }
  
  return mddata;
}

- (NSArray *)metadataForPath:(NSString *)apath
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableArray *alldata = [NSMutableArray array];
  NSArray *types = [mdmodules allKeys];
  NSUInteger i;

  for (i = 0; i < [types count]; i++) {
    NSString *type = [types objectAtIndex: i];
    id data = [self metadataOfType: type forPath: apath];

    if (data) {
      NSDictionary *dict;
      
      dict = [NSDictionary dictionaryWithObjectsAndKeys: type, @"key", 
                                                         data, @"attribute",
                                                         nil]; 
      [alldata addObject: dict];
    }
  }
  [alldata retain];
  RELEASE (arp);
  return [alldata autorelease];
}

- (NSTimeInterval)timestampOfPath:(NSString *)path
{
  DDBPath *ddbpath = [self ddbpathForPath: path];
  
  if (ddbpath) {
    return [ddbpath timestamp];
  }
  
  return 0.0;
}

- (void)metadataDidChangeForPath:(DDBPath *)ddbpath
{
  CREATE_AUTORELEASE_POOL(arp);
  DBKBTreeNode *node; 
  NSUInteger index;
  BOOL exists;  
  DESTROY (dummyPaths[1]);
  ASSIGN (dummyPaths[0], ddbpath);  

  [tree begin];
  node = [tree nodeOfKey: dummyOffsets[0] getIndex: &index didExist: &exists];

  if (exists) {
    NSNumber *offset = [node keyAtIndex: index];
    NSTimeInterval stamp = [[NSDate date] timeIntervalSinceReferenceDate];
    NSData *data;

    [ddbpath setTimestamp: stamp];
    data = [NSArchiver archivedDataWithRootObject: ddbpath];
    [vlfile writeData: data atOffset: offset];
    [self synchronize];
  }
  
  [tree end];
  
  RELEASE (arp);  
}

- (void)duplicateDataOfPath:(NSString *)srcpath
                    forPath:(NSString *)dstpath
{
  NSArray *types = [mdmodules allKeys];
  NSUInteger i;

  for (i = 0; i < [types count]; i++) {
    NSString *type = [types objectAtIndex: i];
    id module = [mdmodules objectForKey: type];

    if ([module duplicable]) {
      id mddata = [self metadataOfType: type forPath: srcpath];

      if (mddata) {
        [self setMetadata: mddata ofType: type forPath: dstpath];
      }
    }
  }
}

- (void)duplicateDataOfPaths:(NSArray *)srcpaths
                    forPaths:(NSArray *)dstpaths
{
  NSUInteger i, j;

  for (i = 0; i < [srcpaths count]; i++) {
    CREATE_AUTORELEASE_POOL(arp);
    NSString *srcpath = [srcpaths objectAtIndex: i];
    NSString *dstpath = [dstpaths objectAtIndex: i];
    NSDictionary *attrs = [fm fileAttributesAtPath: dstpath traverseLink: NO];
    DDBPath *ddbpath = [self ddbpathForPath: srcpath];
    
    if (ddbpath) {
      [self duplicateDataOfPath: srcpath forPath: dstpath];
    }
        
    if ([attrs fileType] == NSFileTypeDirectory) {
      NSArray *subpaths = [self subpathsFromPath: srcpath];
      
      for (j = 0; j < [subpaths count]; j++) {
        NSString *subpath = [[subpaths objectAtIndex: j] path];
        NSString *newpath = removePrefix(subpath, srcpath);

        newpath = [dstpath stringByAppendingPathComponent: newpath];
          
        if ([fm fileExistsAtPath: newpath]) {
          [self duplicateDataOfPath: subpath forPath: newpath];
        }
      }
    }
    
    RELEASE (arp);
  }
}

- (NSArray *)subpathsFromPath:(NSString *)path
{
  CREATE_AUTORELEASE_POOL(pool);
  NSMutableArray *paths = [NSMutableArray array];
  NSMutableArray *toremove = [NSMutableArray array];
  NSArray *keys = nil;
  NSString *dmstr[2];
  NSUInteger i;

  [tree begin];
    
  if ([path isEqual: pathsep()] == NO) {
    dmstr[0] = [path stringByAppendingString: pathsep()];
    dmstr[1] = [path stringByAppendingString: @"0"];
  } else {
    dmstr[0] = path;
    dmstr[1] = @"0";
  }

  dummyPaths[0] = [[DDBPath alloc] initForPath: dmstr[0]];
  dummyPaths[1] = [[DDBPath alloc] initForPath: dmstr[1]];

  keys = [tree keysGreaterThenKey: dummyOffsets[0] 
                 andLesserThenKey: dummyOffsets[1]];

  [tree end];
  
  if (keys) {
    for (i = 0; i < [keys count]; i++) {
      CREATE_AUTORELEASE_POOL(arp);
      NSData *data = [vlfile dataAtOffset: [keys objectAtIndex: i]];
      DDBPath *ddbpath = [NSUnarchiver unarchiveObjectWithData: data];

      if ([fm fileExistsAtPath: [ddbpath path]]) {
        [paths addObject: ddbpath];
      } else {
        [toremove addObject: [ddbpath path]];
      }

      RELEASE(arp);
    }  
  }
  
  for (i = 0; i < [toremove count]; i++) {
    [self removePath: [toremove objectAtIndex: i]];
  }
  
  RETAIN (paths);
  RELEASE(pool);
  
  return [paths autorelease];
}
                                        
- (id)mdmoduleForMDType:(NSString *)type
{
  return [mdmodules objectForKey: type];
}


//
// DBKBTreeDelegate methods
//

- (unsigned long)nodesize
{
  return 512;
} 

- (NSArray *)keysFromData:(NSData *)data
               withLength:(unsigned *)dlen
{
  NSMutableArray *keys = [NSMutableArray array];
  NSRange range;
  unsigned kcount;
  unsigned long key;
  NSUInteger i;
  
  range = NSMakeRange(0, sizeof(unsigned));
  [data getBytes: &kcount range: range];
  range.location += sizeof(unsigned);
  
  range.length = sizeof(unsigned long);

  for (i = 0; i < kcount; i++) {
    [data getBytes: &key range: range];
    [keys addObject: [NSNumber numberWithUnsignedLong: key]];
    range.location += sizeof(unsigned long);
  }
  
  *dlen = range.location;
  
  return keys;
}

- (NSData *)dataFromKeys:(NSArray *)keys
{
  NSMutableData *data = [NSMutableData dataWithCapacity: 1];
  unsigned kcount = [keys count];
  NSUInteger i;
  
  [data appendData: [NSData dataWithBytes: &kcount length: sizeof(unsigned)]];
    
  for (i = 0; i < kcount; i++) {
    unsigned long kl = [[keys objectAtIndex: i] unsignedLongValue];
    [data appendData: [NSData dataWithBytes: &kl length: sizeof(unsigned long)]];
  }
  
  return data;  
}

- (NSComparisonResult)compareNodeKey:(id)akey 
                             withKey:(id)bkey
{
  CREATE_AUTORELEASE_POOL(arp);
  DDBPath *apath;
  DDBPath *bpath;
  NSComparisonResult result;
  
  if ([akey isEqual: dummyOffsets[0]]) {
    apath = RETAIN (dummyPaths[0]);
  } else {
    NSData *data = [vlfile dataAtOffset: (NSNumber *)akey];
    apath = [NSUnarchiver unarchiveObjectWithData: data];
  }
  
  if ([bkey isEqual: dummyOffsets[0]]) {
    bpath = dummyPaths[0];
  } else if ([bkey isEqual: dummyOffsets[1]]) {
    bpath = dummyPaths[1];
  } else {
    NSData *data = [vlfile dataAtOffset: (NSNumber *)bkey];
    bpath = [NSUnarchiver unarchiveObjectWithData: data];
  }

  result = [apath compare: bpath];
  
  RELEASE (arp);
  
  return result;  
}

@end


@implementation	DDBPath

- (void)dealloc
{
  RELEASE (path);
  RELEASE (mdpath);
      
  [super dealloc];
}

- (id)initForPath:(NSString *)apath
{
  self = [super init];

  if (self) {
    ASSIGN (path, apath);
    mdpath = nil;
    timestamp = 0.0;
  }
  
  return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
  self = [super init];
  
  if (self) {
    if ([decoder allowsKeyedCoding]) {
      ASSIGN (path, [decoder decodeObjectForKey: @"path"]);
      ASSIGN (mdpath, [decoder decodeObjectForKey: @"mdpath"]);
      timestamp = [decoder decodeDoubleForKey: @"timestamp"];
    } else {
      ASSIGN (path, [decoder decodeObject]);
      ASSIGN (mdpath, [decoder decodeObject]);    
      [decoder decodeValueOfObjCType: @encode(double) at: &timestamp];
    }
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
  if ([encoder allowsKeyedCoding]) {
    [encoder encodeObject: path forKey: @"path"];
    [encoder encodeObject: mdpath forKey: @"mdpath"];
    [encoder encodeDouble: timestamp forKey: @"timestamp"];
  } else {
    [encoder encodeObject: path];
    [encoder encodeObject: mdpath];  
    [encoder encodeValueOfObjCType: @encode(double) at: &timestamp]; 
  }
}

- (NSUInteger)hash
{
  return [path hash];
}

- (BOOL)isEqual:(id)other
{
  if (other == self) {
    return YES;
  }
  
  if ([other isKindOfClass: [DDBPath class]]) {
    return [path isEqual: [other path]];
  }
  
  return NO;
}

- (void)setPath:(NSString *)apath
{
  ASSIGN (path, apath);
}

- (NSString *)path
{
  return path;
}

- (void)setMDPath:(NSString *)apath
{
  ASSIGN (mdpath, apath);
}

- (NSString *)mdpath
{
  return mdpath;
}

- (void)setTimestamp:(NSTimeInterval)stamp
{
  timestamp = stamp;
}

- (NSTimeInterval)timestamp
{
  return timestamp;
}

- (NSComparisonResult)compare:(DDBPath *)apath
{
  return [path compare: [apath path]];
}

@end













