/* FSNode.m
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
#include "FSNode.h"
#include "FSNodeRep.h"
#include "FSNFunctions.h"
#include "GNUstep.h"

@implementation FSNode

- (void)dealloc
{
  TEST_RELEASE (path);
  TEST_RELEASE (relativePath);  
  TEST_RELEASE (name);  
  TEST_RELEASE (fileType);
  TEST_RELEASE (typeDescription);
  TEST_RELEASE (crDate);
  TEST_RELEASE (crDateDescription);
  TEST_RELEASE (modDate);
  TEST_RELEASE (modDateDescription);
  TEST_RELEASE (owner);
  TEST_RELEASE (ownerId);
  TEST_RELEASE (group);
  TEST_RELEASE (groupId);

  [super dealloc];
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
    NSDictionary *attributes;
        
    fm = [NSFileManager defaultManager];
    ws = [NSWorkspace sharedWorkspace];
    
    parent = aparent;
    ASSIGN (relativePath, rpath);
    ASSIGN (name, [relativePath lastPathComponent]);
    
    if (parent) {
      NSString *parentPath = [parent path];
      
      if ([parentPath isEqual: path_separator()]) {
        parentPath = @"";
      }
      ASSIGN (path, ([NSString stringWithFormat: @"%@%@%@", 
                                      parentPath, path_separator(), name]));
    } else {
      ASSIGN (path, relativePath);
    }
        
    flags.readable = [fm isReadableFileAtPath: path];
    flags.writable = [fm isWritableFileAtPath: path];
    flags.executable = [fm isExecutableFileAtPath: path];
    flags.deletable = [fm isDeletableFileAtPath: path];
    flags.plain = NO;
    flags.directory = NO;
    flags.link = NO;
    flags.socket = NO;
    flags.charspecial = NO;
    flags.blockspecial = NO;
    flags.mountpoint = NO;
    flags.application = NO;
    flags.package = NO;
    flags.unknown = NO;
    
    filesize = 0;
    permissions = 0;
                                      
    attributes = [fm fileAttributesAtPath: path traverseLink: NO];
                                              
    if (attributes) {
      ASSIGN (fileType, [attributes fileType]);
      
      if (fileType == NSFileTypeRegular) {
        flags.plain = YES;

      } else if (fileType == NSFileTypeDirectory) {
	      NSString *defApp, *type;

	      [ws getInfoForFile: path application: &defApp type: &type]; 
        
        flags.directory = YES;

	      if (type == NSApplicationFileType) {
          flags.application = YES;
          flags.package = YES;
	      } else if (type == NSPlainFileType) {
          flags.package = YES;
        } else if (type == NSFilesystemFileType) {
          flags.mountpoint = YES;
        } 

      } else if (fileType == NSFileTypeSymbolicLink) {
        flags.link = YES;
      } else if (fileType == NSFileTypeSocket) {
        flags.socket = YES;
      } else if (fileType == NSFileTypeCharacterSpecial) {
        flags.charspecial = YES;
      } else if (fileType == NSFileTypeBlockSpecial) {
        flags.blockspecial = YES;
      } else {
        flags.unknown = YES;
      } 
      
      typeDescription = nil;
      
      filesize = [attributes fileSize];
      permissions = [attributes filePosixPermissions];
      
      ASSIGN (crDate, [attributes fileCreationDate]);
      ASSIGN (modDate, [attributes fileModificationDate]);
      ASSIGN (owner, [attributes fileOwnerAccountName]);
      ASSIGN (ownerId, [attributes objectForKey: NSFileOwnerAccountID]);
      ASSIGN (group, [attributes fileGroupOwnerAccountName]);
      ASSIGN (groupId, [attributes objectForKey: NSFileGroupOwnerAccountID]);
    }
  }
    
  return self;
}

- (unsigned)hash
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
  NSMutableArray *nodes = [NSMutableArray array];
  NSArray *fnames = [FSNodeRep directoryContentsAtPath: path];
  int i;
  
  for (i = 0; i < [fnames count]; i++) {
    FSNode *node = [FSNode nodeWithRelativePath: [fnames objectAtIndex: i] 
                                         parent: self];
    [nodes addObject: node];
  }
  
  return nodes;
}

+ (NSArray *)nodeComponentsToNode:(FSNode *)anode
{
  NSArray *pcomps = [self pathComponentsToNode: anode];
  NSMutableArray *components = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [pcomps count]; i++) {
    NSString *pcomp = [pcomps objectAtIndex: i];
    FSNode *pnode = (i == 0) ? nil : [components objectAtIndex: (i-1)];
    FSNode *node = [self nodeWithRelativePath: pcomp parent: pnode];
    
    [components insertObject: node atIndex: [components count]];
  }
  
  return [NSArray arrayWithArray: components];
}

+ (NSArray *)pathComponentsToNode:(FSNode *)anode
{
  return [[anode path] pathComponents];
}

+ (NSArray *)nodeComponentsFromNode:(FSNode *)firstNode 
                             toNode:(FSNode *)secondNode
{
  if ([secondNode isSubnodeOfNode: firstNode]) {
    NSString *p1 = [firstNode path];
    NSString *p2 = [secondNode path];
    int index = ([p1 isEqual: path_separator()]) ? [p1 cStringLength] : ([p1 cStringLength] +1);
    NSArray *pcomps = [[p2 substringFromIndex: index] pathComponents];
    NSMutableArray *components = [NSMutableArray array];
    FSNode *node;
    int i;
    
    node = [self nodeWithRelativePath: p1 parent: nil];
    [components addObject: node];
    
    for (i = 0; i < [pcomps count]; i++) {
      FSNode *pnode = [components objectAtIndex: i];
      NSString *rpath = [pcomps objectAtIndex: i];
      
      node = [self nodeWithRelativePath: rpath parent: pnode];
      [components insertObject: node atIndex: [components count]];
    }
    
    return [NSArray arrayWithArray: components];
    
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
    int index = ([p1 isEqual: path_separator()]) ? [p1 cStringLength] : ([p1 cStringLength] +1);
    
    return [[p2 substringFromIndex: index] pathComponents];
    
  } else if ([secondNode isEqual: firstNode]) {
    return [NSArray arrayWithObject: [firstNode path]];
  }
  
  return nil;
}

+ (unsigned int)indexOfNode:(FSNode *)anode 
               inComponents:(NSArray *)nodes
{
  unsigned int i;

  for (i = 0; i < [nodes count]; i++) {
    FSNode *node = [nodes objectAtIndex: i];

    if ([node isEqual: anode]) {
      return i;
    }
  }
  
  return NSNotFound;
}

+ (unsigned int)indexOfNodeWithPath:(NSString *)apath 
                       inComponents:(NSArray *)nodes
{
  unsigned int i;

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
  int i;

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
  int i;

  for (i = 0; i < [subnodes count]; i++) {
    FSNode *node = [subnodes objectAtIndex: i];
    
    if ([node isValid] && [[node path] isEqual: apath]) {
      return node;
    }
  }
  
  return nil;
}

- (FSNode *)parent
{
  return parent;
}

- (NSString *)parentPath
{
  if (parent) {
    return [parent path];
  } 
  return [path stringByDeletingLastPathComponent];
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
  return (fileType ? fileType : [NSString string]);
}

- (NSString *)typeDescription
{
  if (typeDescription == nil) {
    if (flags.plain) {
      ASSIGN (typeDescription, NSLocalizedString(@"plain file", @""));
    } else if (flags.directory) {
      if (flags.application) {
        ASSIGN (typeDescription, NSLocalizedString(@"application", @""));
      } else if (flags.package) {
        ASSIGN (typeDescription, NSLocalizedString(@"plain file", @""));
      } else if (flags.mountpoint) {
        ASSIGN (typeDescription, NSLocalizedString(@"mount point", @""));
      } else {
        ASSIGN (typeDescription, NSLocalizedString(@"directory", @""));
      }
    } else if (flags.link) {
      ASSIGN (typeDescription, NSLocalizedString(@"symbolic link", @""));
    } else if (flags.socket) {
      ASSIGN (typeDescription, NSLocalizedString(@"socket", @""));
    } else if (flags.charspecial) {
      ASSIGN (typeDescription, NSLocalizedString(@"character special", @""));
    } else if (flags.blockspecial) {
      ASSIGN (typeDescription, NSLocalizedString(@"block special", @""));
    } else {
      ASSIGN (typeDescription, NSLocalizedString(@"unknown", @""));
    }
  }

  return typeDescription;
}

- (NSDate *)creationDate
{
  return (crDate ? crDate : [NSDate date]);
}

- (NSString *)crDateDescription
{
  if (crDate) {
    if (crDateDescription == nil) {
      NSString *descr = [crDate descriptionWithCalendarFormat: @"%b %d %Y" 
                            timeZone: [NSTimeZone localTimeZone] locale: nil];

      ASSIGN (crDateDescription, descr);   
    }

    return crDateDescription;
  }

  return [NSString string];
}

- (NSDate *)modificationDate
{
  return (modDate ? modDate : [NSDate date]);
}

- (NSString *)modDateDescription
{
  if (modDate) {
    if (modDateDescription == nil) {
      NSString *descr = [crDate descriptionWithCalendarFormat: @"%b %d %Y" 
                            timeZone: [NSTimeZone localTimeZone] locale: nil];
      ASSIGN (modDateDescription, descr);   
    }
    return modDateDescription;
  }

  return [NSString string];
}

- (unsigned long long)fileSize
{
  return filesize;
}

#define ONE_KB 1024
#define ONE_MB (ONE_KB * ONE_KB)
#define ONE_GB (ONE_KB * ONE_MB)

- (NSString *)sizeDescription
{
	NSString *sizeStr;
	char *sign = "";
    
	if (filesize == 1) {
		sizeStr = @"1 byte";
	} else if (filesize < 0) {
		sign = "-";
		filesize = -filesize;
	} 
  
	if (filesize == 0) {
		sizeStr = @"0 bytes";
	} else if (filesize < (10 * ONE_KB)) {
		sizeStr = [NSString stringWithFormat: @"%s%d bytes", sign, filesize];
	} else if(filesize < (100 * ONE_KB)) {
 		sizeStr = [NSString stringWithFormat: @"%s%3.2f KB", sign,
                          					  ((double)filesize / (double)(ONE_KB))];
	} else if(filesize < (100 * ONE_MB)) {
		sizeStr = [NSString stringWithFormat: @"%s%3.2f MB", sign,
                          					  ((double)filesize / (double)(ONE_MB))];
	} else {
 		sizeStr = [NSString stringWithFormat:@"%s%3.2f GB", sign,
                          					  ((double)filesize / (double)(ONE_GB))];
	}

	return sizeStr;
}

- (NSString *)owner
{
  return (owner ? owner : [NSString string]);
}

- (NSNumber *)ownerId
{
  return (ownerId ? ownerId : [NSNumber numberWithInt: 0]);
}

- (NSString *)group
{
  return (group ? group : [NSString string]);
}

- (NSNumber *)groupId
{
  return (groupId ? groupId : [NSNumber numberWithInt: 0]);
}

- (unsigned long)permissions
{
  return permissions;
}

- (BOOL)isPlain 
{
  return flags.plain;
}

- (BOOL)isDirectory 
{
  return flags.directory;
}

- (BOOL)isLink 
{
  return flags.link;
}

- (BOOL)isMountPoint
{
  return flags.mountpoint;
}

- (void)setMountPoint:(BOOL)value
{
  flags.mountpoint = value;
}

- (BOOL)isApplication 
{
  return flags.application;
}

- (BOOL)isPackage
{
  return flags.package;
}

- (BOOL)isReadable 
{
  return flags.readable;
}

- (BOOL)isWritable 
{
  return flags.writable;
}

- (BOOL)isExecutable
{
  return flags.executable;
}

- (BOOL)isDeletable
{
  return flags.deletable;
}

- (BOOL)isLocked
{
  return [FSNodeRep isNodeLocked: self];
}

- (BOOL)isValid
{
  return [fm fileExistsAtPath: path];
}

- (BOOL)willBeValidAfterFileOperation:(NSDictionary *)opinfo
{
  NSString *operation = [opinfo objectForKey: @"operation"];
  NSString *source = [opinfo objectForKey: @"source"];
  NSString *destination = [opinfo objectForKey: @"destination"];
  NSArray *files = [opinfo objectForKey: @"files"];
  int i;

  if ([self isSubnodeOfPath: source]) {
    if ([operation isEqual: @"NSWorkspaceMoveOperation"]
        || [operation isEqual: @"NSWorkspaceDestroyOperation"]
        || [operation isEqual: @"GWorkspaceRenameOperation"]
			  || [operation isEqual: @"NSWorkspaceRecycleOperation"]
			  || [operation isEqual: @"GWorkspaceRecycleOutOperation"]
			  || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) { 
      if ([operation isEqual: @"GWorkspaceRenameOperation"]) {      
        files = [NSArray arrayWithObject: [source lastPathComponent]]; 
        source = [source stringByDeletingLastPathComponent];            
      } 

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
    if ([operation isEqual: @"NSWorkspaceMoveOperation"]
          || [operation isEqual: @"NSWorkspaceCopyOperation"]
          || [operation isEqual: @"NSWorkspaceLinkOperation"]
				  || [operation isEqual: @"NSWorkspaceRecycleOperation"]
				  || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) { 
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        NSString *fpath = [destination stringByAppendingPathComponent: fname];

        if ([path isEqual: fpath]) {
          NSString *srcpath = [source stringByAppendingPathComponent: fname];
          NSDictionary *attributes = [fm fileAttributesAtPath: srcpath 
                                                 traverseLink: NO];
          if ((attributes == nil) 
                      || ([[attributes fileType] isEqual: fileType] == NO)) {
            return NO;
          }

        } else if ([self isSubnodeOfPath: fpath]) {  
          NSString *ppart = subtractFirstPartFromPath(path, fpath);
          NSString *srcpath = [source stringByAppendingPathComponent: fname];
          
          srcpath = [srcpath stringByAppendingPathComponent: ppart];

          if ([fm fileExistsAtPath: srcpath]) {
            NSDictionary *attributes = [fm fileAttributesAtPath: srcpath  
                                                   traverseLink: NO];
            if ((attributes == nil) 
                        || ([[attributes fileType] isEqual: fileType] == NO)) {
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
  int i;  	 

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
    files = [NSArray arrayWithObject: [destination lastPathComponent]]; 
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

- (int)compareAccordingToName:(FSNode *)aNode
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

- (int)compareAccordingToParent:(FSNode *)aNode
{
  if ([self parent] == nil) {
    return ([aNode parent] ? NSOrderedAscending : NSOrderedSame);
  } else if ([aNode parent] == nil) {
    return NSOrderedDescending;
  }

  return [[[self parent] name] caseInsensitiveCompare: [[aNode parent] name]];
}

- (int)compareAccordingToKind:(FSNode *)aNode
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
    return [[self name] compare: [aNode name]]; 
  }   

  return (i1 > i2 ? NSOrderedAscending : NSOrderedDescending);
}

- (int)compareAccordingToDate:(FSNode *)aNode
{
  return [[self modificationDate] compare: [aNode modificationDate]]; 
}

- (int)compareAccordingToSize:(FSNode *)aNode
{
  return ([self fileSize] <= [aNode fileSize]) ? NSOrderedAscending : NSOrderedDescending;
}

- (int)compareAccordingToOwner:(FSNode *)aNode
{
  return [[self owner] compare: [aNode owner]]; 
}

- (int)compareAccordingToGroup:(FSNode *)aNode
{
  return [[self group] compare: [aNode group]]; 
}

@end




