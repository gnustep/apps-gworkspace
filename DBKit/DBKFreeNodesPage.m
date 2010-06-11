/* DBKFreeNodesPage.m
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

#include "DBKFreeNodesPage.h"
#include "DBKBTree.h"
#include "DBKBTreeNode.h"
#include "DBKFixLenRecordsFile.h"

@implementation	DBKFreeNodesPage

- (void)dealloc
{
  RELEASE (pageData);
  RELEASE (file);
  
  [super dealloc];
}

- (id)initInTree:(DBKBTree *)atree
        withFile:(DBKFixLenRecordsFile *)afile
        atOffset:(unsigned long)ofst
          length:(unsigned)len
{
  self = [super init];

  if (self) {
    pageData = [[NSMutableData alloc] initWithCapacity: 1];
    
    tree = atree;
    ASSIGN (file, afile);
    
    firstOffset = ofst;
    currOffset = ofst;
    dlength = len;

    llen = sizeof(unsigned long);
    headlen = llen * 4;
    
    [self gotoLastValidPage];
  }
  
  return self;
}

- (void)gotoLastValidPage
{
  CREATE_AUTORELEASE_POOL (pool);
  NSData *data;
  unsigned long count;
    
  currOffset = firstOffset;
  nextOffset = firstOffset;
  data = nil;

  while (nextOffset != 0) {
    data = [self dataOfPageAtOffset: nextOffset];    
    [self getOffsetsFromData: data];
  }

  if ((nodesCount == 0) && (currOffset != firstOffset)) {
    while (nodesCount == 0) {
      data = [self dataOfPageAtOffset: prevOffset];    
      [self getOffsetsFromData: data];
    
      if (currOffset == firstOffset) {
        break;
      }
    }
  }    
        
  [pageData setLength: 0];
  [pageData appendData: data];
  
  count = (nodesCount > 0) ? (nodesCount - 1) : nodesCount;
  lastNodeRange = NSMakeRange(headlen + (count * llen), llen);

  RELEASE (pool);  
}

- (NSData *)dataOfPageAtOffset:(unsigned long)offset
{
  return [file dataOfLength: dlength
                   atOffset: [NSNumber numberWithUnsignedLong: offset]];
}

- (void)getOffsetsFromData:(NSData *)data
{
  [data getBytes: &currOffset range: NSMakeRange(0, llen)];
  [data getBytes: &prevOffset range: NSMakeRange(llen, llen)];
  [data getBytes: &nextOffset range: NSMakeRange(llen * 2, llen)];
  [data getBytes: &nodesCount range: NSMakeRange(llen * 3, llen)];
}

- (void)writeCurrentPage
{
  CREATE_AUTORELEASE_POOL (pool);
  NSData *data = [pageData copy];

  [file writeData: data
         atOffset: [NSNumber numberWithUnsignedLong: currOffset]];
  
  RELEASE (data);
  RELEASE (pool);
}

- (void)addFreeOffset:(unsigned long)offset
{
  CREATE_AUTORELEASE_POOL (arp);
  unsigned long nodeofs;
  
  [pageData getBytes: &nodeofs range: lastNodeRange];
  
  if (nodeofs != 0) {
    lastNodeRange.location += llen;
  }
  
  if (lastNodeRange.location == dlength) {
    NSData *data; 
  
    if (nextOffset == 0) {
      nextOffset = [tree offsetForFreeNodesPage];
      [pageData replaceBytesInRange: NSMakeRange(llen * 2, llen) 
                          withBytes: &nextOffset];
    }
    
    [self writeCurrentPage];
    
    data = [self dataOfPageAtOffset: nextOffset]; 
    [self getOffsetsFromData: data];
    
    [pageData setLength: 0];
    [pageData appendData: data];
    
    lastNodeRange.location = headlen;
  }
  
  [pageData replaceBytesInRange: lastNodeRange withBytes: &offset];
  nodesCount++;
  [pageData replaceBytesInRange: NSMakeRange(llen * 3, llen) 
                      withBytes: &nodesCount];
                      
  RELEASE (arp);                      
}

- (unsigned long)getFreeOffset
{
  unsigned long offset = 0;
  
  if (nodesCount > 0) {
    CREATE_AUTORELEASE_POOL (arp);
  
    [pageData getBytes: &offset range: lastNodeRange];
    [pageData resetBytesInRange: lastNodeRange];

    nodesCount--;
    [pageData replaceBytesInRange: NSMakeRange(llen * 3, llen) 
                        withBytes: &nodesCount];

    lastNodeRange.location -= llen;

    if (nodesCount == 0) {
      if (currOffset != firstOffset) {
        NSData *data; 
        unsigned long count;

        [self writeCurrentPage];

        data = [self dataOfPageAtOffset: prevOffset]; 
        [self getOffsetsFromData: data];

        count = (nodesCount > 0) ? (nodesCount - 1) : nodesCount;
        lastNodeRange = NSMakeRange(headlen + (count * llen), llen);

        [pageData setLength: 0];
        [pageData appendData: data];

      } else {
        lastNodeRange.location = headlen;
      }
    } 
    
    RELEASE (arp); 
  }
    
  return offset;
}

- (unsigned long)currentPageOffset
{
  return currOffset;
}

- (unsigned long)previousPageOffset
{
  return prevOffset;
}

- (unsigned long)nextPageOffset
{
  return nextOffset;
}

@end




























