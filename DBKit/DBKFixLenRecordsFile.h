/* DBKFixLenRecordsFile.h
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

#ifndef DBK_FIX_LEN_RECORDS_FILE_H
#define DBK_FIX_LEN_RECORDS_FILE_H

#include <Foundation/Foundation.h>

@interface DBKFixLenRecordsFile: NSObject 
{
  NSString *path;
  NSMutableDictionary *cacheDict;
  NSMutableArray *offsets;
  NSFileHandle *handle;
  unsigned long eof;
  unsigned maxlen;  
  BOOL autoflush;
  NSFileManager *fm;
}

- (id)initWithPath:(NSString *)apath
       cacheLength:(unsigned)len;

- (void)open;

- (void)close;

- (void)setAutoflush:(BOOL)value;

- (BOOL)autoflush;

- (void)flushIfNeeded;

- (void)flush;

- (NSData *)dataOfLength:(unsigned)length
                atOffset:(NSNumber *)offset;

- (void)writeData:(NSData *)data
         atOffset:(NSNumber *)offset;

- (int)insertionIndexForOffset:(NSNumber *)offset;

- (NSNumber *)offsetForNewData;

@end

#endif // DBK_FIX_LEN_RECORDS_FILE_H
