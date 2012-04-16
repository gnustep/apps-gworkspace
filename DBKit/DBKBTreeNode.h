/* DBKBTreeNode.h
 *  
 * Copyright (C) 2005-2010 Free Software Foundation, Inc.
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

#ifndef DBK_BTREE_NODE_H
#define DBK_BTREE_NODE_H

#include <Foundation/Foundation.h>

@class DBKBTree;
   
@interface DBKBTreeNode: NSObject 
{
  DBKBTree *tree;

  NSNumber *offset;
  
  unsigned order;
  unsigned minkeys;  
  unsigned maxkeys;

  unsigned ulen;  
  unsigned llen;  
    
  NSMutableArray *keys;
  NSMutableArray *subnodes;
  
  BOOL loaded;
  
  DBKBTreeNode *parent;
}

- (id)initInTree:(DBKBTree *)atree
      withParent:(DBKBTreeNode *)pnode
        atOffset:(NSNumber *)ofst;

- (BOOL)isLoaded;

- (void)setLoaded;

- (void)loadNodeData;

/** we use BOOL so not to conflict with the signature of NSBundle's unload */
- (BOOL)unload;

- (void)setNodeData:(NSData *)ndata;

- (NSData *)nodeData;

- (void)save;

- (NSNumber *)offset;

- (void)setOffset:(NSNumber *)ofst;

- (DBKBTreeNode *)parent;

- (void)setParent:(DBKBTreeNode *)anode;

- (void)insertKey:(id)key 
          atIndex:(NSUInteger)index;

- (BOOL)insertKey:(id)key;

- (NSUInteger)indexForKey:(id)key
          existing:(BOOL *)exists;

- (NSUInteger)indexOfKey:(id)key;

- (id)keyAtIndex:(NSUInteger)index; 

- (void)setKeys:(NSArray *)newkeys;

- (void)addKey:(id)key;

- (void)removeKey:(id)key;

- (void)removeKeyAtIndex:(NSUInteger)index;

- (void)replaceKeyAtIndex:(NSUInteger)index
                  withKey:(id)key;

- (void)replaceKey:(id)key
           withKey:(id)newkey;

- (NSArray *)keys;

- (id)minKeyInSubnode:(DBKBTreeNode **)node;

- (id)maxKeyInSubnode:(DBKBTreeNode **)node;

- (id)successorKeyInNode:(DBKBTreeNode **)node
                  forKey:(id)key;

- (id)successorKeyInNode:(DBKBTreeNode **)node
           forKeyAtIndex:(NSUInteger)index;

- (id)predecessorKeyInNode:(DBKBTreeNode **)node
                    forKey:(id)key;
           
- (id)predecessorKeyInNode:(DBKBTreeNode **)node
             forKeyAtIndex:(NSUInteger)index;

- (void)insertSubnode:(DBKBTreeNode *)node 
              atIndex:(NSUInteger)index;
           
- (void)addSubnode:(DBKBTreeNode *)node;
           
- (void)removeSubnode:(DBKBTreeNode *)node;
           
- (void)removeSubnodeAtIndex:(NSUInteger)index;
           
- (void)replaceSubnodeAtIndex:(NSUInteger)index
                     withNode:(DBKBTreeNode *)node;           
           
- (NSUInteger)indexOfSubnode:(DBKBTreeNode *)node;

- (DBKBTreeNode *)subnodeAtIndex:(NSUInteger)index;

- (BOOL)isFirstSubnode:(DBKBTreeNode *)node;
           
- (BOOL)isLastSubnode:(DBKBTreeNode *)node;           
           
- (void)setSubnodes:(NSArray *)nodes;

- (NSArray *)subnodes;

- (DBKBTreeNode *)leftSibling;

- (DBKBTreeNode *)rightSibling;

- (void)splitSubnodeAtIndex:(NSUInteger)index;

- (BOOL)mergeWithBestSibling;

- (void)borrowFromRightSibling:(DBKBTreeNode *)sibling;

- (void)borrowFromLeftSibling:(DBKBTreeNode *)sibling;

- (void)setRoot;

- (BOOL)isRoot;

- (BOOL)isLeaf;

@end

#endif // DBK_BTREE_NODE_H
