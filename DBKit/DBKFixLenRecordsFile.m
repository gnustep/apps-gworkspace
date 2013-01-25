/* DBKFixLenRecordsFile.m
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

#include "DBKFixLenRecordsFile.h"

@implementation	DBKFixLenRecordsFile

- (void)dealloc
{
  if (handle) {
    [handle closeFile];
    RELEASE (handle);
  }

  RELEASE (path);
  RELEASE (cacheDict);
  RELEASE (offsets);
    
  [super dealloc];
}

- (id)initWithPath:(NSString *)apath
       cacheLength:(unsigned)len
{
  self = [super init];

  if (self) {
    BOOL exists, isdir;
    
    ASSIGN (path, apath);

    fm = [NSFileManager defaultManager];

    exists = [fm fileExistsAtPath: path isDirectory: &isdir];

    if (isdir) {
      DESTROY (self);
      [NSException raise: NSInvalidArgumentException
		              format: @"%@ is a directory!", apath];     
      return self;
    } else if (exists == NO) {
      if ([fm createFileAtPath: path contents: nil attributes: nil] == NO) {
        DESTROY (self);
        [NSException raise: NSInvalidArgumentException
		                format: @"cannot create file at: %@", apath];     
        return self;
      }
    }

    [self open];
        
    if (handle == nil) {
      DESTROY (self);
      [NSException raise: NSInvalidArgumentException
		              format: @"cannot open file at: %@", apath];     
      return self;
    }

    cacheDict = [NSMutableDictionary new];
    offsets = [NSMutableArray new];
    maxlen = len;
    autoflush = YES;
  }
  
  return self;  
}

- (void)open
{
  if (handle == nil) {
    handle = [NSFileHandle fileHandleForUpdatingAtPath: path];
    RETAIN (handle);
  }
  
  [handle seekToEndOfFile];
  eof = [handle offsetInFile];
}

- (void)close
{
  if (handle) {
    [handle seekToEndOfFile];
    eof = [handle offsetInFile];
    [handle closeFile];
    DESTROY (handle);
  }
}

- (void)setAutoflush:(BOOL)value
{
  autoflush = value;
}

- (BOOL)autoflush
{
  return autoflush;
}

- (void)flushIfNeeded
{
  if (([cacheDict count] >= maxlen) && autoflush) {
    [self flush];
  }
}

- (void)flush
{
  CREATE_AUTORELEASE_POOL (arp);
  int i;

  for (i = 0; i < [offsets count]; i++) {
    NSNumber *offset = [offsets objectAtIndex: i];
    NSData *data = [cacheDict objectForKey: offset];
    unsigned long ofst;
    
    [handle seekToFileOffset: [offset unsignedLongValue]];
    [handle writeData: data];    
    
    ofst = [handle offsetInFile];
    
    if (ofst > eof) {
      eof = ofst;
    }
  }
  
  [cacheDict removeAllObjects];
  [offsets removeAllObjects];
    
  RELEASE (arp);
}

- (NSData *)dataOfLength:(unsigned)length
                atOffset:(NSNumber *)offset
{
  NSData *data = [cacheDict objectForKey: offset];
  
  if (data == nil) {
    [handle seekToFileOffset: [offset unsignedLongValue]];
    data = [handle readDataOfLength: length];
  } 

  return data;
}

- (void)writeData:(NSData *)data
         atOffset:(NSNumber *)offset
{
  int index = [self insertionIndexForOffset: offset];

  [cacheDict setObject: data forKey: offset];
  
  if (index != -1) {
    [offsets insertObject: offset atIndex: index];
  }

  if (([cacheDict count] >= maxlen) && autoflush) {
    [self flush];
  }
}

- (int)insertionIndexForOffset:(NSNumber *)offset
{
  CREATE_AUTORELEASE_POOL(arp);
  unsigned count = [offsets count]; 
  int ins = 0;
  
  if (count) {
    NSNumber *ofst = nil;
    int first = 0;
    int last = count;
    int pos = 0; 
    NSComparisonResult result;

    while (1) {
      if (first == last) {
        ins = first;
        break;
      }

      pos = (first + last) / 2;
      ofst = [offsets objectAtIndex: pos];
      
      result = [ofst compare: offset];

      if (result == NSOrderedSame) {
        RELEASE (arp);
        return -1;
        
      } else if (result == NSOrderedAscending) { 
        first = pos + 1;
      } else {
        last = pos;	
      }
    } 
  } 
  
  RELEASE (arp);
    
  return ins;  
}

- (NSNumber *)offsetForNewData
{
  unsigned count = [offsets count];
  unsigned long coffs = 0;
  
  if (count > 0) {
    NSNumber *key = [offsets objectAtIndex: (count - 1)];
    NSData *data = [cacheDict objectForKey: key];
  
    coffs = [key unsignedLongValue] + [data length];
  }

  return [NSNumber numberWithUnsignedLong: ((coffs > eof) ? coffs : eof)];
}

@end




























