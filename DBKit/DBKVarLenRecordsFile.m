/* DBKVarLenRecordsFile.m
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

#import "DBKVarLenRecordsFile.h"
#import "DBKBTreeNode.h"

#define FIRST_OFFSET 512

@implementation	DBKVarLenRecordsFile

- (void)dealloc
{
  if (handle) {
    [handle closeFile];
    RELEASE (handle);
  }
  RELEASE (freeOffsetsTree);

  RELEASE (cacheDict);
  RELEASE (offsets);
            
  [super dealloc];
}

- (id)initWithPath:(NSString *)path
       cacheLength:(unsigned)len
{
  self = [super init];
  
  if (self) {
    NSMutableData *data = [NSMutableData dataWithCapacity: 1];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL exists, isdir;  
    
    exists = [fm fileExistsAtPath: path isDirectory: &isdir];

    if (exists == NO) {
      if ([fm createDirectoryAtPath: path attributes: nil] == NO) {
        DESTROY (self);
        [NSException raise: NSInvalidArgumentException
		                format: @"cannot create directory at: %@", path];     
        return self;
      }    
    
      isdir = YES;
    }
    
    if (isdir == NO) {
      DESTROY (self);
      [NSException raise: NSInvalidArgumentException
		              format: @"%@ is not a directory!", path];     
      return self;
    } else {
      NSString *recordsPath = [path stringByAppendingPathComponent: @"records"];
      NSString *freePath = [path stringByAppendingPathComponent: @"free"];

      exists = [fm fileExistsAtPath: recordsPath isDirectory: &isdir];

      if (isdir) {
        DESTROY (self);
        [NSException raise: NSInvalidArgumentException
		                format: @"%@ is a directory!", recordsPath];     
        return self;
      } else if (exists == NO) {
        if ([fm createFileAtPath: recordsPath contents: nil attributes: nil] == NO) {
          DESTROY (self);
          [NSException raise: NSInvalidArgumentException
		                  format: @"cannot create file at: %@", recordsPath];     
          return self;
        }
      }

      cacheDict = [NSMutableDictionary new];
      offsets = [NSMutableArray new];
      maxlen = len;
      autoflush = YES;

      ulen = sizeof(unsigned);
      llen = sizeof(unsigned long);

      handle = [NSFileHandle fileHandleForUpdatingAtPath: recordsPath];
      RETAIN (handle);
      
      [data setLength: FIRST_OFFSET];
      [handle writeData: data];
      
      [handle seekToEndOfFile];
      eof = [handle offsetInFile];

      freeOffsetsTree = [[DBKBTree alloc] initWithPath: freePath 
                                                 order: 16 
                                              delegate: self];
    }
  }
  
  return self;
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
  int i;

  for (i = 0; i < [offsets count]; i++) {
    CREATE_AUTORELEASE_POOL (arp);
    NSNumber *offset = [offsets objectAtIndex: i];
    NSData *dictdata = [cacheDict objectForKey: offset];
    unsigned datalen = [dictdata length];  
    NSMutableData *data = [NSMutableData dataWithCapacity: 1];
    unsigned long ofst;
    
    [data appendBytes: &datalen length: ulen];
    [data appendData: dictdata];
    
    [handle seekToFileOffset: [offset unsignedLongValue]];
    [handle writeData: data];    
    
    ofst = [handle offsetInFile];
    
    if (ofst > eof) {
      eof = ofst;
    }
    
    RELEASE (arp);
  }
  
  [cacheDict removeAllObjects];
  [offsets removeAllObjects];
}

- (NSData *)dataAtOffset:(NSNumber *)offset
{
  NSData *data = [cacheDict objectForKey: offset];
  
  if (data == nil) {
    unsigned long ofst = [offset unsignedLongValue];
    unsigned datalen;
  
    [handle seekToFileOffset: ofst];
    data = [handle readDataOfLength: ulen];
    [data getBytes: &datalen range: NSMakeRange(0, ulen)];
    data = [handle readDataOfLength: datalen];
  } 

  return data;
}

- (NSNumber *)writeData:(NSData *)data
{
  NSNumber *offset = [self offsetForNewData: data];

  [self writeData: data atOffset: offset];
    
  return offset;
}

- (void)writeData:(NSData *)data
         atOffset:(NSNumber *)offset
{
  int index = [self insertionIndexForOffset: offset];
  
  if (index != -1) {
    [offsets insertObject: offset atIndex: index];
  }

  [cacheDict setObject: data forKey: offset];

  if (([cacheDict count] > maxlen) && autoflush) {
    [self flush];
  }
}

- (void)deleteDataAtOffset:(NSNumber *)offset
{
  NSData *data = [cacheDict objectForKey: offset];
  
  if (data) {  
    [cacheDict removeObjectForKey: offset];
    [offsets removeObject: offset];

  } else {
    CREATE_AUTORELEASE_POOL(arp);
    unsigned long ofst = [offset unsignedLongValue];
    NSData *lndata;
    unsigned datalen;
    DBKBFreeNodeEntry *entry;    
    
    [handle seekToFileOffset: ofst];
    lndata = [handle readDataOfLength: ulen];
    [lndata getBytes: &datalen range: NSMakeRange(0, ulen)];
            
    entry = [DBKBFreeNodeEntry entryWithLength: datalen atOffset: ofst];
  
    [freeOffsetsTree begin];
    [freeOffsetsTree insertKey: entry];  
    [freeOffsetsTree end];  
        
    RELEASE (arp);
  }
}

- (NSNumber *)offsetForNewData:(NSData *)data
{
  NSNumber *offset = [self freeOffsetForData: data];
  
  if (offset == nil) {  
    unsigned count = [offsets count];
    unsigned long coffs = 0;
  
    if (count > 0) {
      NSNumber *key = [offsets objectAtIndex: (count - 1)];
      NSData *dictData = [cacheDict objectForKey: key];

      coffs = [key unsignedLongValue] + ulen + [dictData length];
    }
    
    offset = [NSNumber numberWithUnsignedLong: ((coffs > eof) ? coffs : eof)];
  }
  
  return offset;
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

- (NSNumber *)freeOffsetForData:(NSData *)data
{
  CREATE_AUTORELEASE_POOL(arp);
  DBKBFreeNodeEntry *entry = [DBKBFreeNodeEntry entryWithLength: [data length] atOffset: 0];
  DBKBFreeNodeEntry *freeEntry = nil;
  NSNumber *offset = nil;
  DBKBTreeNode *node;
  BOOL exists;
  NSUInteger index;
  
  [freeOffsetsTree begin];
    
  node = [freeOffsetsTree nodeOfKey: entry getIndex: &index didExist: &exists];
  
  if (node && [[node keys] count]) {
    freeEntry = [node successorKeyInNode: &node forKeyAtIndex: index];
  } 

  if (freeEntry) {
    offset = RETAIN ([freeEntry offsetNum]);
    [freeOffsetsTree deleteKey: freeEntry];
  }

  [freeOffsetsTree end];
  
  RELEASE (arp);
  
  return AUTORELEASE (offset);
}


//
// DBKBTreeDelegate methods
//
- (unsigned long)nodesize
{
  return 512;
} 

- (NSArray *)keysFromData:(NSData *)data
               withLength:(unsigned *)dlen
{
  NSMutableArray *keys = [NSMutableArray array];
  NSRange range;
  unsigned kcount;
  unsigned i;
  
  range = NSMakeRange(0, ulen);
  [data getBytes: &kcount range: range];
  range.location += ulen;
  
  range.length = llen;

  for (i = 0; i < kcount; i++) {
    CREATE_AUTORELEASE_POOL(arp);
    DBKBFreeNodeEntry *entry;
    unsigned long length;
    unsigned long offset;
  
    [data getBytes: &length range: range];
    range.location += llen;
    [data getBytes: &offset range: range];
    range.location += llen;
    
    entry = [[DBKBFreeNodeEntry alloc] initWithLength: length atOffset: offset];
    [keys addObject: entry];
    RELEASE (entry);
    
    RELEASE (arp);
  }
  
  *dlen = range.location;
  
  return keys;
}

- (NSData *)dataFromKeys:(NSArray *)keys
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableData *data = [NSMutableData dataWithCapacity: 1];
  unsigned kcount = [keys count];
  unsigned i;
  
  [data appendData: [NSData dataWithBytes: &kcount length: ulen]];
    
  for (i = 0; i < kcount; i++) {
    DBKBFreeNodeEntry *entry = [keys objectAtIndex: i];
    unsigned long length = [entry length];
    unsigned long offset = [entry offset];
  
    [data appendData: [NSData dataWithBytes: &length length: llen]];
    [data appendData: [NSData dataWithBytes: &offset length: llen]];
  }
  
  RETAIN (data);
  RELEASE (arp);
    
  return [data autorelease];  
}

- (NSComparisonResult)compareNodeKey:(id)akey 
                             withKey:(id)bkey
{
  NSComparisonResult result = [[akey lengthNum] compare: [bkey lengthNum]];

  if (result == NSOrderedSame) {
    result = [[akey offsetNum] compare: [bkey offsetNum]];
  }
  
  return result;
}

@end


@implementation	DBKBFreeNodeEntry

- (void)dealloc
{
  RELEASE (lengthNum);
  RELEASE (offsetNum);      
  [super dealloc];
}

+ (id)entryWithLength:(unsigned long)len
             atOffset:(unsigned long)ofst
{
  return AUTORELEASE ([[DBKBFreeNodeEntry alloc] initWithLength: len 
                                                       atOffset: ofst]);
}

- (id)initWithLength:(unsigned long)len
            atOffset:(unsigned long)ofst
{
  self = [super init];

  if (self) {
    ASSIGN (lengthNum, [NSNumber numberWithUnsignedLong: len]);
    ASSIGN (offsetNum, [NSNumber numberWithUnsignedLong: ofst]);
  }
  
  return self;
}

- (NSNumber *)lengthNum 
{
  return lengthNum;
}

- (unsigned long)length
{
  return [lengthNum unsignedLongValue];
}

- (NSNumber *)offsetNum 
{
  return offsetNum;
}

- (unsigned long)offset
{
  return [offsetNum unsignedLongValue];
}

- (NSUInteger)hash
{
  return ([lengthNum hash] + [offsetNum hash]);
}

- (BOOL)isEqual:(id)other
{
  if (other == self) {
    return YES;
  }
  if ([other isKindOfClass: [DBKBFreeNodeEntry class]]) {
    return ([lengthNum isEqual: [other lengthNum]] 
                      && [offsetNum isEqual: [other offsetNum]]);
  }
  return NO;
}

@end

























