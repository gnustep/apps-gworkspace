/* SQLite.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include "SQLite.h"
#include "ddbd.h"

#define MAX_RETRY 100

static char basetable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

NSString *stringForQuery(NSString *str)
{
	NSRange range, subRange;
	NSMutableString *querystr;

  range = NSMakeRange(0, [str length]);
	subRange = [str rangeOfString: @"'" options: NSLiteralSearch range: range];
	
  if (subRange.location == NSNotFound) {
		return str;
	}
  
	querystr = [NSMutableString stringWithString: str];
  
	while ((subRange.location != NSNotFound) && (range.length > 0)) {
		subRange = [querystr rangeOfString: @"'" 
                               options: NSLiteralSearch 
                                 range: range];
		
    if (subRange.location != NSNotFound) {
			[querystr replaceCharactersInRange: subRange withString: @"''"];
		}
    
		range.location = subRange.location + 2;
	  
    if ([querystr length] < range.location) {
      range.length = 0;
    } else {
      range.length = [querystr length] - range.location;
    }
  }
  
	return querystr;
}


@implementation	SQLite

- (void)dealloc
{
  [self closedb];
	RELEASE (dbpath);
  
	[super dealloc];
}

- (id)initWithDatabasePath:(NSString *)path
{
  self = [super init];

  if (self) {
    ASSIGN (dbpath, path);
    sqlite = NULL;
    fm = [NSFileManager defaultManager];
  }
  
  return self;
}

- (BOOL)opendb
{
	if (sqlite == NULL) {
    int dberr = sqlite3_open([dbpath fileSystemRepresentation], &sqlite);
    
    if (dberr != SQLITE_OK) {
      NSLog(@"%s", sqlite3_errmsg(sqlite));
		  return NO;	    
    }
  }

  return YES;  
}

- (void)closedb
{
	if (sqlite) {
	  sqlite3_close(sqlite);
	  sqlite = NULL;
  }
}

- (sqlite3 *)sqlite
{
  return sqlite;
}

- (BOOL)createDatabaseWithTable:(NSDictionary *)table
{
  NSMutableString *query = [NSMutableString stringWithCapacity: 1];
  NSString *tname = [table objectForKey: @"tablename"];
  NSArray *fields = [table objectForKey: @"fields"];
  NSArray *indexes = [table objectForKey: @"indexes"];
  int count;
  int i;

  [query appendFormat: @"CREATE TABLE %@ (", tname];

  count = [fields count];

  for (i = 0; i < count; i++) {
    NSDictionary *fieldict = [fields objectAtIndex: i];
    NSString *fname = [fieldict objectForKey: @"name"];
    NSString *ftype = [fieldict objectForKey: @"type"];

    [query appendFormat: @"%@ %@", fname, ftype];

    if (i < (count - 1)) {
      [query appendString: @", "];
    }
  }    

  [query appendString: @")"];

  if ([self performQuery: query] == nil) {
    return NO;
  }

  if (indexes) {
    count = [indexes count];

    for (i = 0; i < [indexes count]; i++) {
      NSDictionary *indexdict = [indexes objectAtIndex: i];
      NSString *iname = [indexdict objectForKey: @"name"];
      NSString *fields = [indexdict objectForKey: @"fields"];
      BOOL unique = [[indexdict objectForKey: @"unique"] boolValue];

      query = [NSMutableString stringWithCapacity: 1];

      [query appendString: @"CREATE "];

      if (unique) {
        [query appendString: @"UNIQUE "];
      }

      [query appendFormat: @"INDEX %@ ON %@ (%@)", iname, tname, fields];

      if ([self performQuery: query] == nil) {
        return NO;
      }
    }
  }
  
  return YES;
}

- (NSArray *)performQuery:(NSString *)query
{
  CREATE_AUTORELEASE_POOL(pool);
  NSMutableArray *queryResult = [NSMutableArray array];
	char **results;
	int err;
	int cols;
	int rows;
  
	if (sqlite) {
    int retry = 0;

    while (1) {
      err = sqlite3_get_table(sqlite, [query UTF8String], 
                                            &results, &rows, &cols, NULL);
      if (err == SQLITE_OK) {
        break;

      } else if ((err == SQLITE_BUSY) || (err == SQLITE_LOCKED)) {
        CREATE_AUTORELEASE_POOL(arp); 
        NSDate *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

        sqlite3_free_table(results);
        [NSThread sleepUntilDate: when];
        NSLog(@"error %i retry %i", err, retry);
        RELEASE (arp);

        if (retry++ > MAX_RETRY) {
          NSLog(@"error %i", err);
          RELEASE (pool);
		      return nil;
        }

      } else {
		    sqlite3_free_table(results);
        NSLog(@"error %i", err);
        RELEASE (pool);
		    return nil;
      }
    }
  }

  if (rows && cols) {
    NSMutableArray *titles = [NSMutableArray array];
    int index, count;
    char *entry;
    int i, j;
    
    index = 0;
    
    for (i = 0; i < cols; i++) {
      entry = *(results + index);
      [titles addObject: [NSString stringWithUTF8String: entry]];
      index++;
    }
    
    count = [titles count];
    
    for (i = 0; i < (cols * rows); i += count) {
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      
      for (j = 0; j < count; j++) {
        NSString *title = [titles objectAtIndex: j];
      
        entry = *(results + index);
        
        if (entry != NULL) {
          NSData *data = [NSData dataWithBytes: entry 
                                        length: strlen(entry) + 1];
          [dict setObject: data forKey: title];
        } 
      
        index++;
      }
      
      [queryResult addObject: dict];
    }
  }

  sqlite3_free_table(results);
  RETAIN (queryResult);
  RELEASE (pool);

  return queryResult;
}

- (NSString *)blobFromData:(NSData *)data
{
	int length = [data length];
	char *bytes = NSZoneMalloc (NSDefaultMallocZone(), length);	
	unsigned char inBuff[3] = "";
	unsigned char outBuff[4] = "";
	char *blobBuff = NSZoneMalloc (NSDefaultMallocZone(), length * 4/3 + 4);
	char *blobPtr = blobBuff;
  NSString *blobStr;
	int segments;
	int i;
  
  [data getBytes: bytes];

	while (length > 0) {
    segments = 0;
    
		for (i = 0; i < 3; i++) {
			if (length > 0) {
				segments++;
				inBuff[i] = *bytes;
				bytes++;
				length--;
			} else {
				inBuff[i] = 0;
      }
		}

		outBuff[0] = (inBuff[0] & 0xFC) >> 2;
		outBuff[1] = ((inBuff[0] & 0x03) << 4) | ((inBuff[1] & 0xF0) >> 4);
		outBuff[2] = ((inBuff[1] & 0x0F) << 2) | ((inBuff[2] & 0xC0) >> 6);
		outBuff[3] = inBuff[2] & 0x3F;

		switch(segments) {
			case 1:
				sprintf(blobPtr, "%c%c==", 
                      basetable[outBuff[0]], 
                                  basetable[outBuff[1]]);
			  break;
      
			case 2:
				sprintf(blobPtr, "%c%c%c=",
				            basetable[outBuff[0]],
				                    basetable[outBuff[1]],
				                            basetable[outBuff[2]]);
			  break;
      
			default:
				sprintf(blobPtr, "%c%c%c%c",
				              basetable[outBuff[0]],
				                  basetable[outBuff[1]],
				                    basetable[outBuff[2]],
				                        basetable[outBuff[3]]);
			  break;
		}
		
		blobPtr += 4;
	}
	
	*blobPtr = 0;
  blobStr = [NSString stringWithCString: blobBuff];
  NSZoneFree (NSDefaultMallocZone(), blobBuff);

	return blobStr;
}

void decodeBlobUnit(unsigned char *unit, const char *src)
{
	unsigned int x = 0;
	int i;
  
	for (i = 0; i < 4; i++) {
		if (src[i] >= 'A' && src[i] <= 'Z') {
			x = (x << 6) + (unsigned int)(src[i] - 'A' + 0);
		} else if (src[i] >= 'a' && src[i] <= 'z') {
			x = (x << 6) + (unsigned int)(src[i] - 'a' + 26);
		} else if (src[i] >= '0' && src[i] <= '9') {
			x = (x << 6) + (unsigned int)(src[i] - '0' + 52);
		} else if (src[i] == '+') {
			x = (x << 6) + 62;
		} else if (src[i] == '/') {
			x = (x << 6) + 63;
		} else if (src[i] == '=') {
			x = (x << 6);
    }
	}
	
	unit[2] = (unsigned char)(x & 255);
	x >>= 8;
	unit[1] = (unsigned char)(x & 255);
	x >>= 8;
	unit[0] = (unsigned char)(x & 255);
}

- (NSData *)dataFromBlob:(const char *)blob
{
	int blength = 0;
  char *bytes = NSZoneMalloc (NSDefaultMallocZone(), strlen(blob) * 3/4 + 8);
  char *bytesPtr = bytes;
	unsigned long bytesLength = 0;
	unsigned char blobUnit[3] = "";
	int nunits = 0;
	int pos = 0;
  NSData *blobData;
	int i;

	while ((blob[blength] != '=') && blob[blength]) {
		blength++;
  }
	while (blob[blength + pos] == '=') {
		pos++;
  }
  
	nunits = (blength + pos) / 4;

	bytesLength = (nunits * 3) - pos;

	for (i = 0; i < nunits - 1; i++) {
    decodeBlobUnit(bytes, blob);
		bytes += 3;
		blob += 4;
	}

  decodeBlobUnit(blobUnit, blob);

	for (i = 0; i < 3 - pos; i++) {
		bytes[i] = blobUnit[i];
  }
  
  blobData = [NSData dataWithBytes: bytesPtr 
                            length: bytesLength];

  NSZoneFree (NSDefaultMallocZone(), bytesPtr);
  
	return blobData;
}

@end

