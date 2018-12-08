/* FSNode.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>
#import "FSNode.h"
#import "FSNodeRep.h"
#import "FSNFunctions.h"


@implementation FSNode

- (void)dealloc
{
  RELEASE (path);
  RELEASE (relativePath);
  RELEASE (name);  
  RELEASE (attributes);  
  RELEASE (fileType);
  RELEASE (typeDescription);
  RELEASE (crDate);
  RELEASE (crDateDescription);
  RELEASE (modDate);
  RELEASE (modDateDescription);
  RELEASE (owner);
  RELEASE (ownerId);
  RELEASE (group);
  RELEASE (groupId);

  [super dealloc];
}

+ (FSNode *)nodeWithPath:(NSString *)apath
{
  return AUTORELEASE ([[FSNode alloc] initWithRelativePath: apath parent: nil]);
}

+ (FSNode *)nodeWithRelativePath:(NSString *)rpath
                          parent:(FSNode *)aparent
{
  return AUTORELEASE ([[FSNode alloc] initWithRelativePath: rpath 
                                                    parent: aparent]);
}

- (id)initWithRelativePath:(NSString *)rpath
                    parent:(FSNode *)aparent
{    
  self = [super init];
    
  if (self) {
    NSString *lastPathComponent;
    
    fsnodeRep = [FSNodeRep sharedInstance];
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    
    parent = aparent;
    ASSIGN (relativePath, rpath);
    lastPathComponent = [[relativePath lastPathComponent] retain];
    name = nil;
    
    if (parent) {
      NSString *parentPath = [parent path];
      
      if ([parentPath isEqual: path_separator()]) {
        parentPath = @"";
      }
      ASSIGN (path, ([NSString stringWithFormat: @"%@%@%@", 
                                      parentPath, path_separator(), lastPathComponent]));
    } else {
      ASSIGN (path, relativePath);
    }
        
    flags.readable = -1;
    flags.writable = -1;
    flags.executable = -1;
    flags.deletable = -1;
    flags.plain = -1;
    flags.directory = -1;
    flags.link = -1;
    flags.socket = -1;
    flags.charspecial = -1;
    flags.blockspecial = -1;
    flags.mountpoint = -1;
    flags.application = -1;
    flags.package = -1;
    flags.unknown = -1;

    crDate = nil;
    modDate = nil;
    owner = nil;
    ownerId = nil;
    group = nil;
    groupId = nil;

    filesize = 0;
    permissions = 0;
    
    fileType = nil;    
    typeDescription = nil;
    
    application = nil;
                                      
    attributes = [fm fileAttributesAtPath: path traverseLink: NO];
    RETAIN (attributes);

    /* we localize only directories which could be special */
    if ([self isDirectory])
      ASSIGN (name, NSLocalizedStringFromTableInBundle(lastPathComponent, nil, [NSBundle bundleForClass:[self class]], @""));
    else
      ASSIGN (name, lastPathComponent);
    
    [lastPathComponent release];
  }
    
  return self;
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
  if ([other isKindOfClass: [FSNode class]]) {
    return [self isEqualToNode: (FSNode *)other];
  }
  return NO;
}

- (BOOL)isEqualToNode:(FSNode *)anode
{
  if (anode == self) {
    return YES;
  }
  return [path isEqualToString: [anode path]];
}

- (NSArray *)subNodes 
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableArray *nodes = [NSMutableArray array];
  NSArray *fnames = [fsnodeRep directoryContentsAtPath: path];
  NSUInteger i;
  
  for (i = 0; i < [fnames count]; i++) {
    NSString *fname = [fnames objectAtIndex: i];
    FSNode *node = [[FSNode alloc] initWithRelativePath: fname parent: self];

    [nodes addObject: node];
    RELEASE (node);
  }
  
  RETAIN (nodes);
  RELEASE (arp);
    
  return [[nodes autorelease] makeImmutableCopyOnFail: NO];
}

- (NSArray *)subNodeNames 
{
  return [fsnodeRep directoryContentsAtPath: path];
}

- (NSArray *)subNodesOfParent
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableArray *nodes = [NSMutableArray array];
  NSArray *fnames = [fsnodeRep directoryContentsAtPath: [self parentPath]];
  FSNode *pnd = nil;
  NSUInteger i;
  
  if (parent != nil) {
    pnd = [parent parent];
  }
  
  for (i = 0; i < [fnames count]; i++) {
    NSString *fname = [fnames objectAtIndex: i];
    FSNode *node = [[FSNode alloc] initWithRelativePath: fname parent: pnd];

    [nodes addObject: node];
    RELEASE (node);
  }
  
  RETAIN (nodes);
  RELEASE (arp);
    
  return [[nodes autorelease] makeImmutableCopyOnFail: NO];
}

- (NSArray *)subNodeNamesOfParent
{
  return [fsnodeRep directoryContentsAtPath: [self parentPath]];
}

+ (NSArray *)nodeComponentsToNode:(FSNode *)anode
{
  CREATE_AUTORELEASE_POOL(arp);
  NSArray *pcomps = [self pathComponentsToNode: anode];
  NSMutableArray *components = [NSMutableArray array];
  NSUInteger i;
  
  for (i = 0; i < [pcomps count]; i++) {
    NSString *pcomp = [pcomps objectAtIndex: i];
    FSNode *pnode = (i == 0) ? nil : [components objectAtIndex: (i-1)];
    FSNode *node = [self nodeWithRelativePath: pcomp parent: pnode];
    
    [components insertObject: node atIndex: [components count]];
  }
  
  RETAIN (components);
  RELEASE (arp);
  
  return [[components autorelease] makeImmutableCopyOnFail: NO];
}

+ (NSArray *)pathComponentsToNode:(FSNode *)anode
{
  return [[anode path] pathComponents];
}

+ (NSArray *)nodeComponentsFromNode:(FSNode *)firstNode 
                             toNode:(FSNode *)secondNode
{
  if ([secondNode isSubnodeOfNode: firstNode]) {
    CREATE_AUTORELEASE_POOL(arp);
    NSString *p1 = [firstNode path];
    NSString *p2 = [secondNode path];
    NSUInteger index = ([p1 isEqual: path_separator()]) ? [p1 length] : ([p1 length] +1);
    NSArray *pcomps = [[p2 substringFromIndex: index] pathComponents];
    NSMutableArray *components = [NSMutableArray array];
    FSNode *node;
    NSUInteger i;
    
    node = [self nodeWithPath: p1];
    [components addObject: node];
    
    for (i = 0; i < [pcomps count]; i++) {
      FSNode *pnode = [components objectAtIndex: i];
      NSString *rpath = [pcomps objectAtIndex: i];
      
      node = [self nodeWithRelativePath: rpath parent: pnode];
      [components insertObject: node atIndex: [components count]];
    }
    
    RETAIN (components);
    RELEASE (arp);
    
    return [[components autorelease] makeImmutableCopyOnFail: NO];
    
  } else if ([secondNode isEqual: firstNode]) {
    return [NSArray arrayWithObject: firstNode];
  }
  
  return nil;
}

+ (NSArray *)pathComponentsFromNode:(FSNode *)firstNode 
                             toNode:(FSNode *)secondNode
{
  if ([secondNode isSubnodeOfNode: firstNode]) {
    NSString *p1 = [firstNode path];
    NSString *p2 = [secondNode path];
    int index = ([p1 isEqual: path_separator()]) ? [p1 length] : ([p1 length] +1);
    
    return [[p2 substringFromIndex: index] pathComponents];
    
  } else if ([secondNode isEqual: firstNode]) {
    return [NSArray arrayWithObject: [firstNode name]];
  }
  
  return nil;
}

+ (NSArray *)pathsOfNodes:(NSArray *)nodes
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableArray *paths = [NSMutableArray array];
  NSUInteger i;
  
  for (i = 0; i < [nodes count]; i++) {
    [paths addObject: [[nodes objectAtIndex: i] path]];
  }
  
  RETAIN (paths);
  RELEASE (arp);
  
  return [[paths autorelease] makeImmutableCopyOnFail: NO];
}

+ (NSUInteger)indexOfNode:(FSNode *)anode 
               inComponents:(NSArray *)nodes
{
  return [nodes indexOfObject: anode];
}

+ (NSUInteger)indexOfNodeWithPath:(NSString *)apath 
                       inComponents:(NSArray *)nodes
{
  NSUInteger i;

  for (i = 0; i < [nodes count]; i++) {
    FSNode *node = [nodes objectAtIndex: i];

    if ([[node path] isEqual: apath]) {
      return i;
    }
  }
  
  return NSNotFound;
}

+ (FSNode *)subnodeWithName:(NSString *)aname 
                 inSubnodes:(NSArray *)subnodes
{
  NSUInteger i;

  for (i = 0; i < [subnodes count]; i++) {
    FSNode *node = [subnodes objectAtIndex: i];
    
    if ([node isValid] && [[node name] isEqual: aname]) {
      return node;
    }
  }
  
  return nil;
}

+ (FSNode *)subnodeWithPath:(NSString *)apath 
                 inSubnodes:(NSArray *)subnodes
{
  NSUInteger i;

  for (i = 0; i < [subnodes count]; i++) {
    FSNode *node = [subnodes objectAtIndex: i];
    
    if ([node isValid] && [[node path] isEqual: apath]) {
      return node;
    }
  }
  
  return nil;
}

+ (BOOL)pathOfNode:(FSNode *)anode
        isEqualOrDescendentOfPath:(NSString *)apath
                  containingFiles:(NSArray *)files
{
  NSString *nodepath = [anode path];
  
  if ([nodepath isEqual: apath]) {
    return YES;
  
  } else if (isSubpathOfPath(apath, nodepath)) {
    NSUInteger i;
    
    if (files == nil) {
      return YES;
      
    } else {
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        NSString *fpath = [apath stringByAppendingPathComponent: fname];				
				
        if (([fpath isEqual: nodepath]) || (isSubpathOfPath(fpath, nodepath))) {
          return YES;
        }
      }
    }
  }

  return NO;
}

- (FSNode *)parent
{
  return parent;
}

- (NSString *)parentPath
{
  return [path stringByDeletingLastPathComponent];
}

- (NSString *)parentName
{
  return [[self parentPath] lastPathComponent];
}

- (BOOL)isSubnodeOfNode:(FSNode *)anode
{
  return isSubpathOfPath([anode path], path);
}

- (BOOL)isSubnodeOfPath:(NSString *)apath
{
  return isSubpathOfPath(apath, path);
}

- (BOOL)isParentOfNode:(FSNode *)anode
{
  return isSubpathOfPath(path, [anode path]);
}

- (BOOL)isParentOfPath:(NSString *)apath
{
  return isSubpathOfPath(path, apath);
}

- (NSString *)path
{
  return path;
}

- (NSString *)relativePath
{
  return relativePath;
}

- (NSString *)name
{
  return name;
}

- (NSString *)fileType
{
  if (attributes && (fileType == nil)) {
    ASSIGN (fileType, [attributes fileType]);
  }
  return (fileType ? fileType : (NSString *)[NSString string]);
}

- (NSString *)application
{
  if ([self isApplication] == NO) {
    return application;
  }
  return nil;
}

- (void)setTypeFlags
{  
  flags.plain = 0;
  flags.directory = 0;
  flags.link = 0;
  flags.socket = 0;
  flags.charspecial = 0;
  flags.blockspecial = 0;
  flags.mountpoint = 0;
  flags.application = 0;
  flags.package = 0;
  flags.unknown = 0;

  if (fileType == nil) {
    [self fileType];
  }
  
  if (fileType) {
    if (fileType == NSFileTypeRegular) {
      flags.plain = 1;

    } else if (fileType == NSFileTypeDirectory) {
	    NSString *defApp = nil, *type = nil;

	    [ws getInfoForFile: path application: &defApp type: &type]; 
      
      if (defApp) {
        ASSIGN (application, defApp);
      }
      
      flags.directory = 1;

	    if (type == NSApplicationFileType) {
        flags.application = 1;
        flags.package = 1;
	    } else if (type == NSPlainFileType) {
        flags.package = 1;
      }

    } else if (fileType == NSFileTypeSymbolicLink) {
      NSDictionary *attrs = [fm fileAttributesAtPath: path traverseLink: YES];

      if (attrs) {
        [self setFlagsForSymLink: attrs];
      }

      flags.link = 1;
    } else if (fileType == NSFileTypeSocket) {
      flags.socket = 1;
    } else if (fileType == NSFileTypeCharacterSpecial) {
      flags.charspecial = 1;
    } else if (fileType == NSFileTypeBlockSpecial) {
      flags.blockspecial = 1;
    } else {
      flags.unknown = 1;
    } 
  } else {
    flags.unknown = 1;
  }
}

- (void)setFlagsForSymLink:(NSDictionary *)attrs
{  
  NSString *ftype = [attrs fileType];

  if (ftype == NSFileTypeRegular) {
    flags.plain = 1;

  } else if (ftype == NSFileTypeDirectory) {
	  NSString *defApp = nil, *type = nil;

	  [ws getInfoForFile: path application: &defApp type: &type]; 
      
    if (defApp) {
      ASSIGN (application, defApp);
    }
    
    flags.directory = 1;

	  if (type == NSApplicationFileType) {
      flags.application = 1;
      flags.package = 1;
	  } else if (type == NSPlainFileType) {
      flags.package = 1;
    } else if (type == NSFilesystemFileType) {
      flags.mountpoint = 1;
    } 

  } else if (ftype == NSFileTypeSymbolicLink) {
    attrs = [fm fileAttributesAtPath: path traverseLink: YES];
    if (attrs) {
      [self setFlagsForSymLink: attrs];
    }
  } else if (ftype == NSFileTypeSocket) {
    flags.socket = 1;
  } else if (ftype == NSFileTypeCharacterSpecial) {
    flags.charspecial = 1;
  } else if (ftype == NSFileTypeBlockSpecial) {
    flags.blockspecial = 1;
  } else {
    flags.unknown = 1;
  } 

  ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"symbolic link", nil, [NSBundle bundleForClass:[self class]], @""));
}

- (NSString *)typeDescription
{
  if (typeDescription == nil) {
    if ([self isPlain]) {
      ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"plain file", nil, [NSBundle bundleForClass:[self class]], @""));
    } else if ([self isDirectory]) {
      if ([self isApplication]) {
        ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"application", nil, [NSBundle bundleForClass:[self class]], @""));
      } else if ([self isPackage]) {
        ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"package", nil, [NSBundle bundleForClass:[self class]], @""));
      } else if ([self isMountPoint]) {
        ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"mount point", nil, [NSBundle bundleForClass:[self class]], @""));
      } else {
        ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"directory", nil, [NSBundle bundleForClass:[self class]], @""));
      }
    } else if ([self isLink]) {
      ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"symbolic link", nil, [NSBundle bundleForClass:[self class]], @""));
    } else if ([self isSocket]) {
      ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"socket", nil, [NSBundle bundleForClass:[self class]], @""));
    } else if ([self isCharspecial]) {
      ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"character special", nil, [NSBundle bundleForClass:[self class]], @""));
    } else if ([self isBlockspecial]) {
      ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"block special", nil, [NSBundle bundleForClass:[self class]], @""));
    } else {
      ASSIGN (typeDescription, NSLocalizedStringFromTableInBundle(@"unknown", nil, [NSBundle bundleForClass:[self class]], @""));
    }
  }

  return typeDescription;
}

- (NSDate *)creationDate
{
  if (attributes && (crDate == nil)) {
    ASSIGN (crDate, [attributes fileCreationDate]);
  }
  return (crDate ? crDate : (NSDate *)[NSDate date]);
}

- (NSString *)crDateDescription
{
  NSDate *date = [self creationDate];
  
  if (date) {
    if (crDateDescription == nil) {
      NSString *descr = [date descriptionWithCalendarFormat: @"%b %d %Y" 
                            timeZone: [NSTimeZone localTimeZone] locale: nil];

      ASSIGN (crDateDescription, descr);   
    }

    return crDateDescription;
  }

  return [NSString string];
}

- (NSDate *)modificationDate
{
  if (attributes && (modDate == nil)) {
    ASSIGN (modDate, [attributes fileModificationDate]);
  }
  return (modDate ? modDate : (NSDate *)[NSDate date]);
}

- (NSString *)modDateDescription
{
  NSDate *date = [self modificationDate];

  if (date) {
    if (modDateDescription == nil) {
      NSString *descr = [date descriptionWithCalendarFormat: @"%b %d %Y" 
                            timeZone: [NSTimeZone localTimeZone] locale: nil];
      ASSIGN (modDateDescription, descr);   
    }
    return modDateDescription;
  }

  return [NSString string];
}

- (unsigned long long)fileSize
{
  if ((filesize == 0) && attributes) {
    filesize = [attributes fileSize];
  }
  return filesize;
}


- (NSString *)sizeDescription
{
  unsigned long long fsize = [self fileSize];
  NSString *sizeStr;

  sizeStr = sizeDescription(fsize);
    
  return sizeStr;
}

- (NSString *)owner
{
  if (attributes && (owner == nil)) {
    ASSIGN (owner, [attributes fileOwnerAccountName]);
  }
  return (owner ? owner : (NSString *)[NSString string]);
}

- (NSNumber *)ownerId
{
  if (attributes && (ownerId == nil)) {
    ASSIGN (ownerId, [attributes objectForKey: NSFileOwnerAccountID]);
  }
  return (ownerId ? ownerId : [NSNumber numberWithInt: 0]);
}

- (NSString *)group
{
  if (attributes && (group == nil)) {
    ASSIGN (group, [attributes fileGroupOwnerAccountName]);
  }
  return (group ? group : (NSString *)[NSString string]);
}

- (NSNumber *)groupId
{
  if (attributes && (groupId == nil)) {
    ASSIGN (groupId, [attributes objectForKey: NSFileGroupOwnerAccountID]);
  }
  return (groupId ? groupId : [NSNumber numberWithInt: 0]);
}

- (unsigned long)permissions
{
  if ((permissions == 0) && attributes) {
    permissions = [attributes filePosixPermissions];
  }
  return permissions;
}

- (BOOL)isPlain 
{
  if (flags.plain == -1) {
    [self setTypeFlags];
  }
  return (flags.plain ? YES : NO);  
}

- (BOOL)isDirectory 
{
  if (flags.directory == -1) {
    [self setTypeFlags];
  }
  return (flags.directory ? YES : NO);
}

- (BOOL)isLink 
{
  if (flags.link == -1) {
    [self setTypeFlags];
  }
  return (flags.link ? YES : NO);
}

- (BOOL)isSocket
{
  if (flags.socket == -1) {
    [self setTypeFlags];
  }
  return (flags.socket ? YES : NO);
}

- (BOOL)isCharspecial
{
  if (flags.charspecial == -1) {
    [self setTypeFlags];
  }
  return (flags.charspecial ? YES : NO);
}

- (BOOL)isBlockspecial
{
  if (flags.blockspecial == -1) {
    [self setTypeFlags];
  }
  return (flags.blockspecial ? YES : NO);
}

- (BOOL)isMountPoint
{
  if (flags.mountpoint == -1) {
    [self setTypeFlags];
  }
  return (flags.mountpoint ? YES : NO);
}

- (void)setMountPoint:(BOOL)value
{
  flags.mountpoint = value;
}

- (BOOL)isApplication 
{
  if (flags.application == -1) {
    [self setTypeFlags];
  }
  return (flags.application ? YES : NO);
}

- (BOOL)isPackage
{
  if (flags.package == -1) {
    [self setTypeFlags];
  }
  return (flags.package ? YES : NO);
}

- (BOOL)isReadable 
{
  if (flags.readable == -1) {
    flags.readable = [fm isReadableFileAtPath: path];
  }
  return (flags.readable ? YES : NO);
}

- (BOOL)isWritable 
{
  if (flags.writable == -1) {
    flags.writable = [fm isWritableFileAtPath: path];
  }
  return (flags.writable ? YES : NO);
}

- (void)checkWritable
{
  flags.writable = [fm isWritableFileAtPath: path];
}

- (BOOL)isParentWritable
{
  return [fm isWritableFileAtPath: [self parentPath]];
}

- (BOOL)isExecutable
{
  if (flags.executable == -1) {
    flags.executable = [fm isExecutableFileAtPath: path];
  }
  return (flags.executable ? YES : NO);
}

- (BOOL)isDeletable
{
  if (flags.deletable == -1) {
    flags.deletable = [fm isDeletableFileAtPath: path];
  }
  return (flags.deletable ? YES : NO);
}

- (BOOL)isLocked
{
  return [fsnodeRep isNodeLocked: self];
}

- (BOOL)isValid
{
  BOOL valid = (attributes != nil);

  if (valid) {
    valid = [fm fileExistsAtPath: path];

    if ((valid == NO) && flags.link) {
      valid = ([fm fileAttributesAtPath: path traverseLink: NO] != nil);
    }
  }
  
  return valid;
}

- (BOOL)hasValidPath
{
  return [fm fileExistsAtPath: path];
}

- (BOOL)isReserved
{
  return [fsnodeRep isReservedName: name];
}

- (BOOL)willBeValidAfterFileOperation:(NSDictionary *)opinfo
{
  NSString *operation = [opinfo objectForKey: @"operation"];
  NSString *source = [opinfo objectForKey: @"source"];
  NSString *destination = [opinfo objectForKey: @"destination"];
  NSArray *files = [opinfo objectForKey: @"files"];
  NSUInteger i;

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {      
    files = [NSArray arrayWithObject: [source lastPathComponent]]; 
    source = [source stringByDeletingLastPathComponent];            
  } 

  if ([self isSubnodeOfPath: source]) {
    if ([operation isEqual: NSWorkspaceMoveOperation]
        || [operation isEqual: NSWorkspaceDestroyOperation]
        || [operation isEqual: @"GWorkspaceRenameOperation"]
			  || [operation isEqual: NSWorkspaceRecycleOperation]
			  || [operation isEqual: @"GWorkspaceRecycleOutOperation"]
			  || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) { 
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        NSString *fpath = [source stringByAppendingPathComponent: fname];

        if ([path isEqual: fpath] || [self isSubnodeOfPath: fpath]) {  
          return NO;      
        }
      }
    } 
  }

  if ([self isSubnodeOfPath: destination]) {
    if ([operation isEqual: NSWorkspaceMoveOperation]
          || [operation isEqual: NSWorkspaceCopyOperation]
          || [operation isEqual: NSWorkspaceLinkOperation]
	|| [operation isEqual: NSWorkspaceRecycleOperation]
	|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]) { 
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        NSString *fpath = [destination stringByAppendingPathComponent: fname];

        if ([path isEqual: fpath]) {
          NSString *srcpath = [source stringByAppendingPathComponent: fname];
          NSDictionary *attrs = [fm fileAttributesAtPath: srcpath 
                                            traverseLink: NO];
          if ((attrs == nil) 
                      || ([[attrs fileType] isEqual: [self fileType]] == NO)) {
            return NO;
          }

        } else if ([self isSubnodeOfPath: fpath]) {  
          NSString *ppart = subtractFirstPartFromPath(path, fpath);
          NSString *srcpath = [source stringByAppendingPathComponent: fname];
          
          srcpath = [srcpath stringByAppendingPathComponent: ppart];

          if ([fm fileExistsAtPath: srcpath]) {
            NSDictionary *attrs = [fm fileAttributesAtPath: srcpath  
                                              traverseLink: NO];
            if ((attrs == nil) 
                        || ([[attrs fileType] isEqual: [self fileType]] == NO)) {
              return NO;
            }
          } else {
            return NO;
          }
        }
      }
    }
  }
  
  return YES;
}

- (BOOL)involvedByFileOperation:(NSDictionary *)opinfo
{
  NSString *operation = [opinfo objectForKey: @"operation"];
  NSString *source = [opinfo objectForKey: @"source"];
  NSString *destination = [opinfo objectForKey: @"destination"];	 
  NSArray *files = [opinfo objectForKey: @"files"];    
  NSUInteger i;  	 

  if ([operation isEqual: @"GWorkspaceRenameOperation"]) { 
    files = [NSArray arrayWithObject: [source lastPathComponent]]; 
    source = [source stringByDeletingLastPathComponent];            
    destination = [destination stringByDeletingLastPathComponent];            
  } 

  if ([path isEqual: source] || [path isEqual: destination]) {
    return YES;
  }

  if (isSubpathOfPath(source, path)) {
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fpath = [source stringByAppendingPathComponent: fname];				

      if (([fpath isEqual: path]) || (isSubpathOfPath(fpath, path))) {
        return YES;
      }
    }
  }
    
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    destination = [opinfo objectForKey: @"destination"];	 
    files = [NSArray arrayWithObject: [destination lastPathComponent]]; 
    destination = [destination stringByDeletingLastPathComponent];  
  } 
  
  if (isSubpathOfPath(destination, path)) {
    for (i = 0; i < [files count]; i++) {
      NSString *fname = [files objectAtIndex: i];
      NSString *fpath = [destination stringByAppendingPathComponent: fname];				

      if (([fpath isEqual: path]) || (isSubpathOfPath(fpath, path))) {
        return YES;
      }
    }
  }
    
  return NO;
}

@end


@implementation FSNode (Comparing)

- (NSComparisonResult)compareAccordingToPath:(FSNode *)aNode
{
  return [path compare: [aNode path]];
}

- (NSComparisonResult)compareAccordingToName:(FSNode *)aNode
{
  NSString *n1 = [self name];
  NSString *n2 = [aNode name];

  if ([n2 hasPrefix: @"."] || [n1 hasPrefix: @"."]) {
    if ([n2 hasPrefix: @"."] && [n1 hasPrefix: @"."]) {
      return [n1 caseInsensitiveCompare: n2];
    } else {
      return [n2 caseInsensitiveCompare: n1];
    }
  }
  
  return [n1 caseInsensitiveCompare: n2];
}

- (NSComparisonResult)compareAccordingToParent:(FSNode *)aNode
{
  CREATE_AUTORELEASE_POOL(pool);
  NSString *p1 = [self parentPath];
  NSString *p2 = [aNode parentPath];
  NSComparisonResult result = [p1 compare: p2];
  RELEASE (pool);
  return result;
}

- (NSComparisonResult)compareAccordingToKind:(FSNode *)aNode
{
  unsigned i1, i2;

  if ([self isDirectory]) { 
    i1 = 2; 
  } else if ([self isExecutable]) { 
    i1 = 1; 
  } else { 
    i1 = 0; 
  } 

  if ([aNode isDirectory]) { 
    i2 = 2; 
  } else if ([aNode isExecutable]) { 
    i2 = 1; 
  } else { 
    i2 = 0; 
  } 

  if (i1 == i2) {	
    return [self compareAccordingToExtension: aNode];
  }   

  return ((i1 > i2) ? NSOrderedAscending : NSOrderedDescending);
}

- (NSComparisonResult)compareAccordingToExtension:(FSNode *)aNode
{
  NSString *e1 = [[self path] pathExtension];
  NSString *e2 = [[aNode path] pathExtension];
  
  if ([e1 isEqual: e2]) {
    return [self compareAccordingToName: aNode];
  }
  
  return [e1 caseInsensitiveCompare: e2];
}

- (NSComparisonResult)compareAccordingToDate:(FSNode *)aNode
{
  return [[self modificationDate] compare: [aNode modificationDate]]; 
}

- (NSComparisonResult)compareAccordingToSize:(FSNode *)aNode
{
  unsigned long long fs1 = [self fileSize];  
  unsigned long long fs2 = [aNode fileSize];  
  return (fs1 > fs2) ? NSOrderedAscending : NSOrderedDescending;
}

- (NSComparisonResult)compareAccordingToOwner:(FSNode *)aNode
{
  return [[self owner] compare: [aNode owner]]; 
}

- (NSComparisonResult)compareAccordingToGroup:(FSNode *)aNode
{
  return [[self group] compare: [aNode group]]; 
}

@end




