/* DBKBTree.h
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

#ifndef DBK_BTREE_H
#define DBK_BTREE_H

#import <Foundation/Foundation.h>

@class DBKBTreeNode;
@class DBKFreeNodesPage;
@class DBKFixLenRecordsFile;

extern NSRecursiveLock *dbkbtree_lock;

@interface DBKBTree: NSObject 
{
  NSMutableData *headData;
  
  DBKBTreeNode *root;
  NSNumber *rootOffset;  
  
  NSMutableSet *unsavedNodes;
  
  DBKFreeNodesPage *freeNodesPage;
  unsigned long fnpageOffset;  
    
  unsigned order;
  unsigned minkeys;  
  unsigned maxkeys;  
  
  DBKFixLenRecordsFile *file;
  unsigned long nodesize;  
  
  BOOL begin;
  
  unsigned ulen;  
  unsigned llen;  
    
  id delegate;
}

- (id)initWithPath:(NSString *)path
             order:(int)ord
          delegate:(id)deleg;

- (void)begin;

- (void)end;

- (void)readHeader;

- (void)writeHeader;

- (void)createRootNode;

- (void)setRoot:(DBKBTreeNode *)newroot;

- (DBKBTreeNode *)root;

- (DBKBTreeNode *)insertKey:(id)key;

- (DBKBTreeNode *)insertKey:(id)key
                     inNode:(DBKBTreeNode *)node;

- (DBKBTreeNode *)nodeOfKey:(id)key
                   getIndex:(NSUInteger *)index;

- (DBKBTreeNode *)nodeOfKey:(id)key
                   getIndex:(NSUInteger *)index
                   didExist:(BOOL *)exists;

- (DBKBTreeNode *)nodeOfKey:(id)key;

- (NSArray *)keysGreaterThenKey:(id)akey
               andLesserThenKey:(id)bkey;

- (BOOL)replaceKey:(id)key
           withKey:(id)newkey;
               
- (BOOL)deleteKey:(id)key;

- (BOOL)deleteKey:(id)key
          atIndex:(NSUInteger)index
           ofNode:(DBKBTreeNode *)node;

- (NSNumber *)offsetForNewNode;

- (unsigned long)offsetForFreeNodesPage;

- (void)nodeWillFreeOffset:(NSNumber *)offset;

- (void)createFreeNodesPage;

- (NSArray *)keysFromData:(NSData *)data
               withLength:(unsigned *)dlen;

- (NSData *)dataFromKeys:(NSArray *)keys;

- (NSComparisonResult)compareNodeKey:(id)akey 
                             withKey:(id)bkey;

- (NSData *)dataForNode:(DBKBTreeNode *)node;
                         
- (void)addUnsavedNode:(DBKBTreeNode *)node;
                         
- (void)saveNodes;

- (void)synchronize;
                         
- (void)saveNode:(DBKBTreeNode *)node;

- (unsigned)order;

- (void)checkBegin;

@end

@protocol DBKBTreeDelegate

- (unsigned long)nodesize;  

- (NSArray *)keysFromData:(NSData *)data
               withLength:(unsigned *)dlen;

- (NSData *)dataFromKeys:(NSArray *)keys;

- (NSComparisonResult)compareNodeKey:(id)akey 
                             withKey:(id)bkey;

@end

#endif // DBK_BTREE_H
