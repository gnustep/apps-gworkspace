/* DBKBTree.m
 *  
 * Copyright (C) 2005-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: June 2005
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

#import "DBKBTree.h"
#import "DBKBTreeNode.h"
#import "DBKFreeNodesPage.h"
#import "DBKFixLenRecordsFile.h"

#define MIN_ORDER 3
#define HEADLEN 512
#define FREE_NPAGE_LEN 512

NSRecursiveLock *dbkbtree_lock = nil;

@implementation	DBKBTree

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO)
  {
    if ([self class] == [DBKBTree class]) {
      dbkbtree_lock = [NSRecursiveLock new];
    }
    initialized = YES;
  }
}

- (void)dealloc
{
  if (file) {
    [file close];
    RELEASE (file);
  }

  RELEASE (headData);
  RELEASE (root);
  RELEASE (rootOffset);
  RELEASE (freeNodesPage);
  RELEASE (unsavedNodes);
  
  [super dealloc];
}

- (id)initWithPath:(NSString *)path
             order:(int)ord
          delegate:(id)deleg
{
  self = [super init];

  if (self) {
    if (ord < MIN_ORDER) {
      DESTROY (self);
      [NSException raise: NSInvalidArgumentException
		              format: @"the order must be at least %i", MIN_ORDER];     
      return self;
    }
  
    if (deleg == nil) {
      DESTROY (self);
      [NSException raise: NSInvalidArgumentException
		              format: @"DBKBTree requires a delegate"];     
      return self;
    }

    if ([deleg conformsToProtocol: @protocol(DBKBTreeDelegate)] == NO) {	
      DESTROY (self);
      [NSException raise: NSInvalidArgumentException
		              format: @"the delegate doesn't implement the DBKBTreeDelegate protocol"];     
      return self;
    }
    
    file = [[DBKFixLenRecordsFile alloc] initWithPath: path cacheLength: 10000];
    [file setAutoflush: YES];
    
    order = ord;
    minkeys = order - 1;
    maxkeys = order * 2 - 1;

    ulen = sizeof(unsigned);
    llen = sizeof(unsigned long);
    
    delegate = deleg;
    nodesize = [delegate nodesize];

    unsavedNodes = [[NSMutableSet alloc] initWithCapacity: 1];
            
    ASSIGN (rootOffset, [NSNumber numberWithUnsignedLong: HEADLEN]);
    fnpageOffset = HEADLEN + nodesize;
     
    headData = [[NSMutableData alloc] initWithCapacity: 1];   
    [self readHeader];
        
    [self createRootNode];
    [self createFreeNodesPage];
    
    begin = NO;
  }
  
  return self;
}

- (void)begin
{
  if (begin == YES) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"begin already called"];     
  }

  begin = YES;
}

- (void)end
{
  NSArray *subnodes = [root subnodes];
  int i;

  if (begin == NO) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"end without begin"];     
  }
  
  [self saveNodes];
  [file flush];
  
  for (i = 0; i < [subnodes count]; i++) { 
    [[subnodes objectAtIndex: i] unload];
  }

  begin = NO;  
}

- (void)readHeader
{
  NSData *data = [file dataOfLength: HEADLEN
                           atOffset: [NSNumber numberWithUnsignedLong: 0L]];
  
  [headData setLength: 0];  
  
  /* TODO add the version */
  if ([data length] == HEADLEN) {
    [headData appendData: data];
  } else { // new file
      
  
    [self writeHeader];  
  }
}

- (void)writeHeader
{
  [headData setLength: HEADLEN];
  
  [file writeData: headData
         atOffset: [NSNumber numberWithUnsignedLong: 0L]];
  
  [file flush]; 
}

- (void)createRootNode
{
  NSData *data;

  root = [[DBKBTreeNode alloc] initInTree: self 
                               withParent: nil 
                                 atOffset: rootOffset];
  
  data = [self dataForNode: root];
  
  if (data) {
    [root setNodeData: data];    
  } else {
    [root setLoaded];
  }
  
  [self saveNode: root];
  [file flush]; 
}

- (void)setRoot:(DBKBTreeNode *)newroot
{
  ASSIGN (root, newroot);
  [root setRoot];
  [root setOffset: rootOffset];
  [root setLoaded];
  [self addUnsavedNode: root];
}

- (DBKBTreeNode *)root
{
  return root;
}

- (DBKBTreeNode *)insertKey:(id)key
{
  CREATE_AUTORELEASE_POOL(arp);
  BOOL autoflush = [file autoflush];
  DBKBTreeNode *insnode = nil;
  BOOL exists;

  [self checkBegin];  
  [file setAutoflush: NO];

  [root indexForKey: key existing: &exists];
  
  if (exists == NO) {  
    if ([[root keys] count] == maxkeys) {
      DBKBTreeNode *newroot = [[DBKBTreeNode alloc] initInTree: self 
                                                    withParent: nil 
                                                      atOffset: rootOffset];
      
      [root setOffset: [self offsetForNewNode]];
      [self addUnsavedNode: root];
      
      [newroot addSubnode: root];
      [self setRoot: newroot];
      RELEASE (newroot);
      
      [newroot splitSubnodeAtIndex: 0];

      insnode = [self insertKey: key inNode: newroot];

    } else {
      insnode = [self insertKey: key inNode: root];
    }
  }
  
  [self saveNodes];
  [file setAutoflush: autoflush];
  [file flushIfNeeded];
  
  RETAIN (insnode);
  RELEASE (arp);
  
  return AUTORELEASE (insnode);
}

- (DBKBTreeNode *)insertKey:(id)key
                     inNode:(DBKBTreeNode *)node
{
  if ([node isLoaded] == NO) {
    [node loadNodeData];
  }

  if ([node isLeaf]) {
    if ([node insertKey: key]) {
      [node setLoaded];
      [self addUnsavedNode: node];

      return node;
    } 
    
  } else {
    NSUInteger index;
    BOOL exists;
     
    index = [node indexForKey: key existing: &exists];
    
    if (exists == NO) {  
      DBKBTreeNode *subnode = [[node subnodes] objectAtIndex: index];
      BOOL insert = NO;
          
      if ([subnode isLoaded] == NO) {
        [subnode loadNodeData];
      }
          
      if ([[subnode keys] count] == maxkeys) {
        [subnode indexForKey: key existing: &exists];

        if (exists == NO) {
          [node splitSubnodeAtIndex: index];
          index = [node indexForKey: key existing: &exists];
          subnode = [[node subnodes] objectAtIndex: index];
          
          if ([subnode isLoaded] == NO) {
            [subnode loadNodeData];
          }
          
          insert = YES;
        }
      } else {
        insert = YES;
      }
      
      if (insert) {  
        return [self insertKey: key inNode: subnode];
      }
    }
  }
  
  return nil;
}

- (DBKBTreeNode *)nodeOfKey:(id)key
                   getIndex:(NSUInteger *)index
{
  CREATE_AUTORELEASE_POOL(arp);
  DBKBTreeNode *node = root;
  BOOL exists;
  
  [self checkBegin];
  
  *index = [node indexForKey: key existing: &exists];

  while (exists == NO) {
    NSArray *subnodes = [node subnodes];
    
    if ([subnodes count]) {
      node = [subnodes objectAtIndex: *index];
      
      if ([node isLoaded] == NO) {
        [node loadNodeData];
      }
      
      *index = [node indexForKey: key existing: &exists];
    } else {
      RELEASE (arp);
      return nil;
    }
  }

  RETAIN (node);
  RELEASE (arp);
  
  return [node autorelease];
}

- (DBKBTreeNode *)nodeOfKey:(id)key
                   getIndex:(NSUInteger *)index
                   didExist:(BOOL *)exists
{
  CREATE_AUTORELEASE_POOL(arp);
  DBKBTreeNode *node = root;
  
  [self checkBegin];
  
  *index = [node indexForKey: key existing: exists];

  while (*exists == NO) {
    NSArray *subnodes = [node subnodes];
    
    if ([subnodes count]) {
      node = [subnodes objectAtIndex: *index];
      
      if ([node isLoaded] == NO) {
        [node loadNodeData];
      }
      
      *index = [node indexForKey: key existing: exists];
      
    } else {
      *index = [node indexForKey: key existing: exists];
      break;
    }
  }

  RETAIN (node);
  RELEASE (arp);
  
  return [node autorelease];
}

- (DBKBTreeNode *)nodeOfKey:(id)key
{
  DBKBTreeNode *node;
  BOOL exists;
  NSUInteger index;

  [self checkBegin];
  node = [self nodeOfKey: key getIndex: &index didExist: &exists];
  
  if (exists) {
    return node;
  }
  
  return nil;
}

- (NSArray *)keysGreaterThenKey:(id)akey
               andLesserThenKey:(id)bkey
{
  CREATE_AUTORELEASE_POOL(pool);
  NSMutableArray *keys = [NSMutableArray array];
  DBKBTreeNode *node;
  id key;
  BOOL exists;
  NSUInteger index;
  
  [self checkBegin];
    
  key = akey;
  node = [self nodeOfKey: key getIndex: &index didExist: &exists];
  
  if (exists == NO) {
    key = [node predecessorKeyInNode: &node forKeyAtIndex: index];
    
    if (key == nil) {
      key = [node minKeyInSubnode: &node];
      [keys addObject: key]; 
    } else {
      node = [self nodeOfKey: key getIndex: &index didExist: &exists];
    }
  }

  while (node != nil)
    { 
      CREATE_AUTORELEASE_POOL(arp);
    
      key = [node successorKeyInNode: &node forKeyAtIndex: index];
    
      if (key == nil)
        {
          RELEASE(arp);
          break;
        }
    
      if (bkey && ([delegate compareNodeKey: key withKey: bkey] != NSOrderedAscending))
        {
          RELEASE(arp);
          break;
        }
    
      index = [node indexOfKey: key];
      [keys addObject: key]; 
    
      RELEASE (arp);
  }

  RETAIN (keys);
  RELEASE (pool);
    
  return [keys autorelease];
}

- (BOOL)replaceKey:(id)key
           withKey:(id)newkey
{
  DBKBTreeNode *node;
  BOOL exists;
  NSUInteger index;
  
  [self checkBegin];
  
  node = [self nodeOfKey: key getIndex: &index didExist: &exists];
  
  if (exists == NO) {
    return (([self insertKey: newkey] != nil) ? YES : NO);  
  } else {
    [node replaceKeyAtIndex: index withKey: newkey];
    return YES;
  }
  
  return NO;
}

- (BOOL)deleteKey:(id)key
{
  CREATE_AUTORELEASE_POOL(arp);
  DBKBTreeNode *node;
  NSUInteger index;

  [self checkBegin];

  node = [self nodeOfKey: key getIndex: &index];
    
  if (node) {
    BOOL autoflush = [file autoflush];
    
    [file setAutoflush: NO];
    
    if ([self deleteKey: key atIndex: index ofNode: node]) {
      if ([[root keys] count] == 0) { 
        NSArray *subnodes = [root subnodes];
        
        if ([subnodes count]) {
          DBKBTreeNode *nd = [subnodes objectAtIndex: 0];

          if ([nd isLoaded] == NO) {
            [nd loadNodeData];
          }

          RETAIN (nd);
          [root removeSubnodeAtIndex: 0];
          [self nodeWillFreeOffset: [nd offset]];
          [self setRoot: nd];
          RELEASE (nd);
        }
      }

      [self saveNodes];
      [file setAutoflush: autoflush];
      [file flushIfNeeded];
      
      RELEASE (arp);
      
      return YES;
    }
    
    [file setAutoflush: autoflush];
  }

  RELEASE (arp);
    
  return NO;
}

- (BOOL)deleteKey:(id)key
          atIndex:(NSUInteger)index
           ofNode:(DBKBTreeNode *)node
{
  DBKBTreeNode *chknode = nil;  

  if ([node isLeaf] == NO) {
    DBKBTreeNode *scnode;
    id sckey;

    sckey = [node successorKeyInNode: &scnode forKeyAtIndex: index];
        
    if (sckey) {
      [node replaceKeyAtIndex: index withKey: sckey];
      [self addUnsavedNode: node];
      [scnode removeKey: sckey];
      [self addUnsavedNode: scnode];
      chknode = scnode;
    } else {
      return NO;
    }   
  } else {
    [node removeKeyAtIndex: index];
    [self addUnsavedNode: node];
    chknode = node;
  }

  while ([[chknode keys] count] < minkeys) {
    DBKBTreeNode *chkparent = [chknode parent];
    
    if (chkparent) {
      int chkind = [chkparent indexOfSubnode: chknode];
      DBKBTreeNode *sibling;
      
      if (chkind == 0) { 
        sibling = [chknode rightSibling];
        
        if (sibling && ([sibling isLoaded] == NO)) {
          [sibling loadNodeData];
        }
      
        if (sibling && ([[sibling keys] count] > minkeys)) {
          [chknode borrowFromRightSibling: sibling];
        } else {
          [chknode mergeWithBestSibling];
        }
      } else if (chkind == ([[chkparent subnodes] count] - 1)) {
        sibling = [chknode leftSibling];

        if (sibling && ([sibling isLoaded] == NO)) {
          [sibling loadNodeData];
        }
      
        if (sibling && ([[sibling keys] count] > minkeys)) {
          [chknode borrowFromLeftSibling: sibling];
        } else {
          [chknode mergeWithBestSibling];
        }

      } else {
        BOOL borrowed = NO;
        
        sibling = [chknode leftSibling];

        if (sibling && ([sibling isLoaded] == NO)) {
          [sibling loadNodeData];
        }

        if (sibling && ([[sibling keys] count] > minkeys)) {
          [chknode borrowFromLeftSibling: sibling];
          borrowed = YES;
          
        } else {
          sibling = [chknode rightSibling];

          if (sibling && ([sibling isLoaded] == NO)) {
            [sibling loadNodeData];
          }
          
          if (sibling && ([[sibling keys] count] > minkeys)) {
            [chknode borrowFromRightSibling: sibling];
            borrowed = YES;
          }
        }
        
        if (borrowed == NO) {
          [chknode mergeWithBestSibling];
        }
      }

      chknode = chkparent;
      chkparent = [chknode parent];
      
    } else {
      break;
    }    
  }
  
  return YES;
}

- (NSNumber *)offsetForNewNode
{
  NSMutableData *data = [NSMutableData dataWithLength: nodesize];
  unsigned long ofst = [freeNodesPage getFreeOffset];
  NSNumber *offset;

  if (ofst == 0) {
    offset = [file offsetForNewData];
  } else {
    offset = [NSNumber numberWithUnsignedLong: ofst];
  }

  [file writeData: data atOffset: offset];
  
  return offset;  
}

- (unsigned long)offsetForFreeNodesPage
{
  NSMutableData *data = [NSMutableData dataWithCapacity: 1];
  unsigned long prevOffset = [freeNodesPage currentPageOffset];
  NSNumber *offset = [file offsetForNewData];  
  unsigned long ofs = [offset unsignedLongValue];

  [data appendData: [NSData dataWithBytes: &ofs length: llen]]; 
  [data appendData: [NSData dataWithBytes: &prevOffset length: llen]];   
  [data setLength: FREE_NPAGE_LEN];

  [file writeData: data atOffset: offset];
  
  return ofs;
}

- (void)nodeWillFreeOffset:(NSNumber *)offset
{
  if ([offset isEqual: rootOffset] == NO) {
    [freeNodesPage addFreeOffset: [offset unsignedLongValue]];
  }
}

- (void)createFreeNodesPage
{
  NSMutableData *data = [NSMutableData dataWithCapacity: 1];
  NSData *page = [file dataOfLength: FREE_NPAGE_LEN
                           atOffset: [NSNumber numberWithUnsignedLong: fnpageOffset]];

  [data appendData: page];

  if ([data length] != FREE_NPAGE_LEN) {
    [data setLength: 0];
    [data appendData: [NSData dataWithBytes: &fnpageOffset length: llen]]; 
    [data setLength: FREE_NPAGE_LEN];
    [file writeData: data
           atOffset: [NSNumber numberWithUnsignedLong: fnpageOffset]];
    [file flush];
  }
  
  freeNodesPage = [[DBKFreeNodesPage alloc] initInTree: self
                                              withFile: file
                                              atOffset: fnpageOffset
                                                length: FREE_NPAGE_LEN];
}

- (NSArray *)keysFromData:(NSData *)data
               withLength:(unsigned *)dlen
{
  return [delegate keysFromData: data withLength: dlen];
}

- (NSData *)dataFromKeys:(NSArray *)keys
{
  return [delegate dataFromKeys: keys];
}

- (NSComparisonResult)compareNodeKey:(id)akey 
                             withKey:(id)bkey
{
  return [delegate compareNodeKey: akey withKey: bkey];
}

- (NSData *)dataForNode:(DBKBTreeNode *)node
{
  NSData *data = [file dataOfLength: nodesize atOffset: [node offset]];

  if ([data length] == nodesize) {
    unsigned keyscount;

    [data getBytes: &keyscount range: NSMakeRange(0, ulen)];

    if (keyscount != 0) {
      return data;
    }
  }
  
  return nil;
}

- (void)addUnsavedNode:(DBKBTreeNode *)node
{
  [unsavedNodes addObject: node];
}

- (void)saveNodes
{
  NSEnumerator *enumerator = [unsavedNodes objectEnumerator];
  DBKBTreeNode *node;

  while ((node = [enumerator nextObject])) {
    [self saveNode: node];
  }
  
  [unsavedNodes removeAllObjects];
  [freeNodesPage writeCurrentPage];  
}

- (void)synchronize
{
  [file flush];
}

- (void)saveNode:(DBKBTreeNode *)node
{
  CREATE_AUTORELEASE_POOL (arp);
  NSMutableData *data = [NSMutableData dataWithCapacity: 1];
  
  [data appendData: [node nodeData]];
  [data setLength: nodesize];
  [file writeData: data atOffset: [node offset]];

  RELEASE (arp); 
}

- (unsigned)order
{
  return order;
}

- (void)checkBegin
{
  if (begin == NO) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"begin not called!"];     
  }
}

@end
















