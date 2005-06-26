/* DBKFreeNodesPage.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
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

#ifndef DBK_FREE_NODES_PAGE_H
#define DBK_FREE_NODES_PAGE_H

#include <Foundation/Foundation.h>

@class DBKBTree;
@class DBKFixLenRecordsFile;

@interface DBKFreeNodesPage: NSObject 
{
  DBKBTree *tree;
  DBKFixLenRecordsFile *file;

  NSMutableData *pageData;
  unsigned dlength;
  unsigned headlen;
  
  unsigned long firstOffset;
  
  unsigned long currOffset;
  unsigned long prevOffset;
  unsigned long nextOffset;
  unsigned long nodesCount;
  
  NSRange lastNodeRange;
  
  unsigned llen;  
}

- (id)initInTree:(DBKBTree *)atree
        withFile:(DBKFixLenRecordsFile *)afile
        atOffset:(unsigned long)ofst
          length:(unsigned)len;

- (void)gotoLastValidPage;

- (NSData *)dataOfPageAtOffset:(unsigned long)offset;

- (void)getOffsetsFromData:(NSData *)data;

- (void)writeCurrentPage;

- (void)addFreeOffset:(unsigned long)offset;

- (unsigned long)getFreeOffset;

- (unsigned long)currentPageOffset;

- (unsigned long)previousPageOffset;

- (unsigned long)nextPageOffset;

@end

#endif // DBK_FREE_NODES_PAGE_H
