/* DBKBTreeNode.m
 *  
 * Copyright (C) 2005-2012 Free Software Foundation, Inc.
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

#import "DBKBTreeNode.h"
#import "DBKBTree.h"

@implementation	DBKBTreeNode

- (void)dealloc
{
  RELEASE (offset);
  RELEASE (keys);
  RELEASE (subnodes);
  
  [super dealloc];
}

- (id)initInTree:(DBKBTree *)atree
      withParent:(DBKBTreeNode *)pnode
        atOffset:(NSNumber *)ofst
{
  self = [super init];

  if (self) {
    tree = atree;
    parent = pnode;
    ASSIGN (offset, ofst);
    
    order = [tree order];
    minkeys = order - 1;
    maxkeys = order * 2 - 1;
    
    keys = [NSMutableArray new];
    subnodes = [NSMutableArray new];
    
    loaded = NO;
    
    ulen = sizeof(unsigned);
    llen = sizeof(unsigned long);
  }
  
  return self;
}

- (NSUInteger)hash
{
  return [offset hash];
}

- (BOOL)isEqual:(id)other
{
  if (other == self) {
    return YES;
  }
  if ([other isKindOfClass: [DBKBTreeNode class]]) {
    return [offset isEqual: [other offset]];
  }
  return NO;
}

- (BOOL)isLoaded
{
  return loaded;
}

- (void)setLoaded
{
  loaded = YES;
}

- (void)loadNodeData
{
  [self setNodeData: [tree dataForNode: self]];
}

- (BOOL)unload
{
  [keys removeAllObjects];
  [subnodes removeAllObjects];
  loaded = NO;
  return YES;
}

- (void)setNodeData:(NSData *)ndata
{
  CREATE_AUTORELEASE_POOL (pool);
  NSRange range;
  unsigned datalen;
  unsigned offscount;
  NSArray *array;
  NSUInteger i;
      
  array = [tree keysFromData: ndata withLength: &datalen];           
  [keys addObjectsFromArray: array];
      
  range = NSMakeRange(datalen, ulen);
  [ndata getBytes: &offscount range: range];
 
  range.location += ulen;
  range.length = llen;      
      
  for (i = 0; i < offscount; i++) {
    unsigned long offs;      
    NSNumber *offsnum;
    DBKBTreeNode *node;
        
    [ndata getBytes: &offs range: range];
    offsnum = [NSNumber numberWithUnsignedLong: offs];
      
    node = [[DBKBTreeNode alloc] initInTree: tree
                                 withParent: self
                                   atOffset: offsnum];      
      
    [subnodes addObject: node];
    RELEASE (node);
    range.location += llen;
  }      
  
  loaded = YES;
  
  RELEASE (pool);  
}

- (NSData *)nodeData
{
  NSMutableData *nodeData = [NSMutableData dataWithCapacity: 1];
  NSUInteger subcount;
  NSUInteger i;
  
  [nodeData appendData: [tree dataFromKeys: keys]];

  subcount = [subnodes count];
  [nodeData appendData: [NSData dataWithBytes: &subcount length: ulen]];
  
  for (i = 0; i < subcount; i++) {
    NSNumber *offsnum = [[subnodes objectAtIndex: i] offset];
    unsigned long offs = [offsnum unsignedLongValue];
    
    [nodeData appendData: [NSData dataWithBytes: &offs length: llen]];
  }
  
  return nodeData;
}

- (void)save
{
  [tree addUnsavedNode: self];
}

- (NSNumber *)offset
{
  return offset;
}

- (void)setOffset:(NSNumber *)ofst
{
  ASSIGN (offset, ofst);
}

- (DBKBTreeNode *)parent
{
  return parent; 
}

- (void)setParent:(DBKBTreeNode *)anode
{
  parent = anode;
}

- (void)insertKey:(id)key 
          atIndex:(NSUInteger)index
{
  [keys insertObject: key atIndex: index];
  [self save];
}

- (BOOL)insertKey:(id)key 
{
  CREATE_AUTORELEASE_POOL(arp);
  unsigned count = [keys count]; 
  int ins = 0;

  if (count) {
    NSUInteger first = 0;
    NSUInteger last = count;
    NSUInteger pos = 0; 
    id k;
    NSComparisonResult result;

    while (1) {
      if (first == last) {
        ins = first;
        break;
      }

      pos = (first + last) / 2;
      k = [keys objectAtIndex: pos];
      result = [tree compareNodeKey: k withKey: key];

      if (result == NSOrderedSame) {
        /* the key exists */
        RELEASE (arp);
        return NO;
        
      } else if (result == NSOrderedAscending) { 
        first = pos + 1;
      } else {
        last = pos;	
      }
    } 
  } 
  
  [keys insertObject: key atIndex: ins];
  [self save];
  
  RELEASE (arp);
  
  return YES;
}

- (NSUInteger)indexForKey:(id)key
          existing:(BOOL *)exists
{
  CREATE_AUTORELEASE_POOL(arp);
  NSUInteger count = [keys count]; 
  NSUInteger ins = 0;

  if (count) {
    NSUInteger first = 0;
    NSUInteger last = count;
    NSUInteger pos = 0; 
    id k;
    NSComparisonResult result;

    while (1) {
      if (first == last) {
        ins = first;
        break;
      }

      pos = (first + last) / 2;
      k = [keys objectAtIndex: pos];
      result = [tree compareNodeKey: k withKey: key];

      if (result == NSOrderedSame) {
        *exists = YES;
        RELEASE (arp);
        return pos;
        
      } else if (result == NSOrderedAscending) { 
        first = pos + 1;
      } else {
        last = pos;	
      }
    } 
  } 
  
  *exists = NO;  
  RELEASE (arp);
    
  return ins;  
}

- (NSUInteger)indexOfKey:(id)key
{
  return [keys indexOfObject: key];
}

- (id)keyAtIndex:(NSUInteger)index
{
  return [keys objectAtIndex: index];
}

- (void)setKeys:(NSArray *)newkeys
{
  [keys removeAllObjects];
  [keys addObjectsFromArray: newkeys];
  [self save];
}

- (void)addKey:(id)key
{
  [keys addObject: key];
  [self save];
}

- (void)removeKey:(id)key
{
  [keys removeObject: key];
  [self save];
}

- (void)removeKeyAtIndex:(NSUInteger)index
{
  [keys removeObjectAtIndex: index];
  [self save];
}

- (void)replaceKeyAtIndex:(NSUInteger)index
                  withKey:(id)key
{
  [keys replaceObjectAtIndex: index withObject: key];
  [self save];
}

- (void)replaceKey:(id)key
           withKey:(id)newkey
{
  NSUInteger index = [self indexOfKey: key];
  
  if (index != NSNotFound) {
    [keys replaceObjectAtIndex: index withObject: newkey];
    [self save];
  }
}
                  
- (NSArray *)keys
{
  return keys;
}

- (id)minKeyInSubnode:(DBKBTreeNode **)node
{
  if (loaded == NO) {
    [self loadNodeData];
  }

  *node = self;

  while ([*node isLeaf] == NO) {
    *node = [[*node subnodes] objectAtIndex: 0]; 
    if ([*node isLoaded] == NO) {
      [*node loadNodeData];
    }     
  }

  if ([*node isLoaded] == NO) {
    [*node loadNodeData];
  }

  return [[*node keys] objectAtIndex: 0];
}

- (id)maxKeyInSubnode:(DBKBTreeNode **)node
{
  NSArray *nodes;
  NSArray *ndkeys;

  if (loaded == NO) {
    [self loadNodeData];
  }

  *node = self;
  nodes = [*node subnodes];
  
  while ([*node isLeaf] == NO) {
    *node = [nodes objectAtIndex: ([nodes count] -1)];  
    if ([*node isLoaded] == NO) {
      [*node loadNodeData];
    }
    nodes = [*node subnodes];
  }

  if ([*node isLoaded] == NO) {
    [*node loadNodeData];
  }
  
  ndkeys = [*node keys];
  
  return [ndkeys objectAtIndex: ([ndkeys count] -1)];
}

- (id)successorKeyInNode:(DBKBTreeNode **)node
                  forKey:(id)key
{
  NSUInteger index;
  
  if (loaded == NO) {
    [self loadNodeData];
  }
  
  index = [self indexOfKey: key];
  
  if (index != NSNotFound) {
    return [self successorKeyInNode: node forKeyAtIndex: index];
  }
  
  return nil;
}

- (id)successorKeyInNode:(DBKBTreeNode **)node
           forKeyAtIndex:(NSUInteger)index
{
  DBKBTreeNode *nextNode = nil;
  DBKBTreeNode *nextParent = nil;
  id key = nil;
  NSUInteger pos;

  if (loaded == NO) {
    [self loadNodeData];
  }
    
  if ([self isLeaf] == NO) {
    if ([subnodes count] > index) {
      nextNode = [subnodes objectAtIndex: (index + 1)];
  
      if ([nextNode isLoaded] == NO) {
        [nextNode loadNodeData];
      }
  
      key = [nextNode minKeyInSubnode: &nextNode];
    }
    
  } else {
    if (index < ([keys count] - 1)) {
      nextNode = self;
      key = [keys objectAtIndex: (index + 1)];
      
    } else {      
      if ([parent isLastSubnode: self]) {
        nextParent = parent;
        nextNode = self;

        while (nextParent) { 
          if ([nextParent isLastSubnode: nextNode]) {
            nextNode = nextParent;
            nextParent = [nextNode parent];
          } else {
            pos = [nextParent indexOfSubnode: nextNode];
            nextNode = nextParent;
            key = [[nextNode keys] objectAtIndex: pos];
            break;
          }
        }    
        
      } else {
        nextNode = parent;
        pos = [nextNode indexOfSubnode: self];
        key = [[nextNode keys] objectAtIndex: pos];
      }
    }
  }
  
  *node = nextNode;
  
  return key;
}

- (id)predecessorKeyInNode:(DBKBTreeNode **)node
                    forKey:(id)key
{
  NSUInteger index;
  
  if (loaded == NO) {
    [self loadNodeData];
  }
  
  index = [self indexOfKey: key];
  
  if (index != NSNotFound) {
    return [self predecessorKeyInNode: node forKeyAtIndex: index];
  }
  
  return nil;
}

- (id)predecessorKeyInNode:(DBKBTreeNode **)node
             forKeyAtIndex:(NSUInteger)index
{
  DBKBTreeNode *nextNode = nil;
  DBKBTreeNode *nextParent = nil;
  id key = nil;
  NSUInteger pos;

  if (loaded == NO) {
    [self loadNodeData];
  }
    
  if ([self isLeaf] == NO) {
    if (index < [subnodes count]) {
      nextNode = [subnodes objectAtIndex: index];
  
      if ([nextNode isLoaded] == NO) {
        [nextNode loadNodeData];
      }
  
      key = [nextNode maxKeyInSubnode: &nextNode];
    }
    
  } else {  
    if (index > 0) {
      nextNode = self;
      key = [keys objectAtIndex: (index - 1)];
      
    } else { 
      if ([parent isFirstSubnode: self]) {
        nextParent = parent;
        nextNode = self;
        
        while (nextParent) { 
          if ([nextParent isFirstSubnode: nextNode]) {
            nextNode = nextParent;
            nextParent = [nextNode parent];
          } else {
            pos = [nextParent indexOfSubnode: nextNode];
            nextNode = nextParent;
            key = [[nextNode keys] objectAtIndex: (pos - 1)];
            break;
          }
        }    
        
      } else {
        nextNode = parent;
        pos = [nextNode indexOfSubnode: self];
        key = [[nextNode keys] objectAtIndex: (pos - 1)];
      }
    }
  }
  
  *node = nextNode;
  
  return key;
}

- (void)insertSubnode:(DBKBTreeNode *)node 
              atIndex:(NSUInteger)index
{
  [node setParent: self];
  [subnodes insertObject: node atIndex: index];
  [self save];
}

- (void)addSubnode:(DBKBTreeNode *)node
{
  [node setParent: self];
  [subnodes addObject: node];
  [self save];
}

- (void)removeSubnode:(DBKBTreeNode *)node
{
  [subnodes removeObject: node];
  [self save];
}

- (void)removeSubnodeAtIndex:(NSUInteger)index
{
  [subnodes removeObjectAtIndex: index];
  [self save];
}

- (void)replaceSubnodeAtIndex:(NSUInteger)index
                     withNode:(DBKBTreeNode *)node
{
  [node setParent: self];
  [subnodes replaceObjectAtIndex: index withObject: node];
  [self save];
}

- (NSUInteger)indexOfSubnode:(DBKBTreeNode *)node
{
  return [subnodes indexOfObject: node];
}

- (DBKBTreeNode *)subnodeAtIndex:(NSUInteger)index
{
  return [subnodes objectAtIndex: index];
}

- (BOOL)isFirstSubnode:(DBKBTreeNode *)node
{
  NSUInteger index = [self indexOfSubnode: node];
  return ((index != NSNotFound) && (index == 0));
}

- (BOOL)isLastSubnode:(DBKBTreeNode *)node
{
  NSUInteger index = [self indexOfSubnode: node];
  return ((index != NSNotFound) && (index == ([subnodes count] - 1)));
}

- (void)setSubnodes:(NSArray *)nodes
{
  NSUInteger i;
  
  [subnodes removeAllObjects];
  
  for (i = 0; i < [nodes count]; i++) {
    [self addSubnode: [nodes objectAtIndex: i]];
  }
  
  [self save]; 
}

- (NSArray *)subnodes
{
  return subnodes;
}

- (DBKBTreeNode *)leftSibling
{
  if (parent) {
    NSUInteger index = [parent indexOfSubnode: self];

    if (index > 0) {
      return [[parent subnodes] objectAtIndex: (index - 1)];
    }
  }
  
  return nil;
}

- (DBKBTreeNode *)rightSibling
{
  if (parent) {
    NSArray *pnodes = [parent subnodes];
    NSUInteger index = [parent indexOfSubnode: self];

    if (index < ([pnodes count] - 1)) {
      return [pnodes objectAtIndex: (index + 1)];
    }
  }

  return nil;
}

- (void)splitSubnodeAtIndex:(NSUInteger)index
{
  DBKBTreeNode *subnode;
  DBKBTreeNode *newnode;
  NSArray *subkeys;
  NSArray *akeys;
  id key;
  NSArray *bkeys;
  CREATE_AUTORELEASE_POOL(arp);

  subnode = [subnodes objectAtIndex: index];

  if ([subnode isLoaded] == NO) {
    [subnode loadNodeData];
  }

  newnode = [[DBKBTreeNode alloc] initInTree: tree
                                  withParent: self
                                    atOffset: [tree offsetForNewNode]];
  [newnode setLoaded];
  
  subkeys = [subnode keys];
  akeys = [subkeys subarrayWithRange: NSMakeRange(0, order - 1)];
  key = [subkeys objectAtIndex: order - 1];
  bkeys = [subkeys subarrayWithRange: NSMakeRange(order, order - 1)];

  RETAIN (key);
  [subnode setKeys: akeys];
  [newnode setKeys: bkeys];

  if ([subnode isLeaf] == NO) {
    NSArray *nodes = [subnode subnodes];
    NSArray *anodes = [nodes subarrayWithRange: NSMakeRange(0, order)];
    NSArray *bnodes = [nodes subarrayWithRange: NSMakeRange(order, order)];

    [subnode setSubnodes: anodes]; 
    [newnode setSubnodes: bnodes]; 
  }

  [self insertSubnode: newnode atIndex: index + 1];
  [self insertKey: key atIndex: index];
  
  [subnode save];
  [newnode save];
  [self save];
  
  RELEASE (key);  
  RELEASE (newnode);  
  RELEASE (arp);  
}

- (BOOL)mergeWithBestSibling
{
  if (parent) {
    CREATE_AUTORELEASE_POOL(arp);
    DBKBTreeNode *lftnd;
    unsigned lcount = 0;
    DBKBTreeNode *rgtnd;
    unsigned rcount = 0;
    DBKBTreeNode *node;
    NSArray *ndkeys;
    NSUInteger index;
    NSUInteger i;

    lftnd = [self leftSibling];
    
    if (lftnd) {
      if ([lftnd isLoaded] == NO) {
        [lftnd loadNodeData];
      }
      lcount = [[lftnd keys] count];
    }

    rgtnd = [self rightSibling];
    
    if (rgtnd) {
      if ([rgtnd isLoaded] == NO) {
        [rgtnd loadNodeData];
      }
      rcount = [[rgtnd keys] count];
    }

    node = (lcount > rcount) ? lftnd : rgtnd;
    ndkeys = [node keys];

    index = [parent indexOfSubnode: self];

    if (node == rgtnd) {
      [self addKey: [[parent keys] objectAtIndex: index]];
    } else {
      index--;
      [self insertKey: [[parent keys] objectAtIndex: index] atIndex: 0];
    }
    
    if (node == rgtnd)
      {
	for (i = 0; i < [ndkeys count]; i++)
	  [self addKey: [ndkeys objectAtIndex: i]];  
      }
    else
      {
      for (i = [ndkeys count]; i > 0; i--)
        [self insertKey: [ndkeys objectAtIndex: i-1] atIndex: 0];
      }

    if ([self isLeaf] == NO)
      {  
	NSArray *ndnodes = [node subnodes];
	
	if (node == rgtnd)
	  {
	    for (i = 0; i < [ndnodes count]; i++)
	      [self addSubnode: [ndnodes objectAtIndex: i]];  
	  }
	else
	  {
	    for (i = [ndnodes count]; i > 0; i--)
	      [self insertSubnode: [ndnodes objectAtIndex: i-1] atIndex: 0];
	  }
      }

    [parent removeKeyAtIndex: index];
    [tree nodeWillFreeOffset: [node offset]];
    [parent removeSubnode: node];

    [parent save];
    [self save];
    
    RELEASE (arp);
    
    return YES;
  }

  return NO;  
}

- (void)borrowFromRightSibling:(DBKBTreeNode *)sibling  
{
  CREATE_AUTORELEASE_POOL(arp);
  NSUInteger index = [parent indexOfSubnode: self];

  if ([sibling isLoaded] == NO) {
    [sibling loadNodeData];
  }

  [self addKey: [[parent keys] objectAtIndex: index]];

  if ([sibling isLeaf] == NO) {  
    [self addSubnode: [[sibling subnodes] objectAtIndex: 0]]; 
    [sibling removeSubnodeAtIndex: 0];
  }

  [parent replaceKeyAtIndex: index
                    withKey: [[sibling keys] objectAtIndex: 0]];

  [sibling removeKeyAtIndex: 0];

  [self save];
  [sibling save];
  [parent save];

  RELEASE (arp);
}

- (void)borrowFromLeftSibling:(DBKBTreeNode *)sibling 
{  
  CREATE_AUTORELEASE_POOL(arp);
  NSUInteger index;
  NSArray *lftkeys;
  unsigned lftkcount;

  if ([sibling isLoaded] == NO) {
    [sibling loadNodeData];
  }

  index = [parent indexOfSubnode: sibling];
  lftkeys = [sibling keys];
  lftkcount = [lftkeys count];

  [self insertKey: [[parent keys] objectAtIndex: index] atIndex: 0];

  if ([sibling isLeaf] == NO) {  
    NSArray *lftnodes = [sibling subnodes];
    unsigned lftncount = [lftnodes count];

    [self insertSubnode: [lftnodes objectAtIndex: (lftncount - 1)] 
                atIndex: 0];
    [sibling removeSubnodeAtIndex: (lftncount - 1)];
  }

  [parent replaceKeyAtIndex: index
                    withKey: [lftkeys objectAtIndex: (lftkcount - 1)]];

  [sibling removeKeyAtIndex: (lftkcount - 1)];

  [self save];
  [sibling save];
  [parent save];

  RELEASE (arp);
}

- (void)setRoot
{
  parent = nil;
}

- (BOOL)isRoot
{
  return (parent == nil);
}

- (BOOL)isLeaf
{
  return ([subnodes count] == 0);
}

@end

