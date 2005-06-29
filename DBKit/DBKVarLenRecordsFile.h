/* DBKVarLenRecordsFile.h
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

#ifndef DBK_VAR_LEN_RECORDS_FILE_H
#define DBK_VAR_LEN_RECORDS_FILE_H

#include <Foundation/Foundation.h>
#include "DBKBTree.h"

@class DBKBFreeNodeEntry;

@interface DBKVarLenRecordsFile: NSObject <DBKBTreeDelegate>
{  
  NSMutableDictionary *cacheDict;
  NSMutableArray *offsets;
  NSFileHandle *handle;
  unsigned long eof;
  unsigned maxlen;  
  BOOL autoflush;  

  DBKBTree *freeOffsetsTree;
  
  unsigned ulen;
  unsigned llen;
}

- (id)initWithPath:(NSString *)path
       cacheLength:(unsigned)len;

- (void)setAutoflush:(BOOL)value;

- (BOOL)autoflush;

- (void)flushIfNeeded;

- (void)flush;

- (NSData *)dataAtOffset:(NSNumber *)offset;

- (NSNumber *)writeData:(NSData *)data;

- (void)writeData:(NSData *)data
         atOffset:(NSNumber *)offset;

- (void)deleteDataAtOffset:(NSNumber *)offset;

- (NSNumber *)offsetForNewData:(NSData *)data;

- (int)insertionIndexForOffset:(NSNumber *)offset;

- (NSNumber *)freeOffsetForData:(NSData *)data;

@end


@interface DBKBFreeNodeEntry: NSObject 
{
  NSNumber *lengthNum;
  NSNumber *offsetNum;
}

+ (id)entryWithLength:(unsigned long)len
             atOffset:(unsigned long)ofst;

- (id)initWithLength:(unsigned long)len
            atOffset:(unsigned long)ofst;

- (NSNumber *)lengthNum;

- (unsigned long)length;

- (NSNumber *)offsetNum;

- (unsigned long)offset;

@end

#endif // DBK_VAR_LEN_RECORDS_FILE_H
