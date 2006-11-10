/* sqlite.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: February 2006
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

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include "sqlite.h"

#define MAX_RETRY 1000

static char basetable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

sqlite3 *opendbAtPath(NSString *path)
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *components = [path pathComponents];
  unsigned count = [components count];
  NSString *dbname = [components objectAtIndex: count - 1];
  NSString *dbpath = [NSString string];
  sqlite3 *db = NULL;
  int dberr;
  unsigned i;

  for (i = 0; i < (count - 1); i++) {
    NSString *dir = [components objectAtIndex: i];
    BOOL isdir;    

    dbpath = [dbpath stringByAppendingPathComponent: dir];

    if (([fm fileExistsAtPath: dbpath isDirectory: &isdir] &isdir) == NO) {
      if ([fm createDirectoryAtPath: dbpath attributes: nil] == NO) { 
        NSLog(@"unable to create: %@", dbpath);
        return NULL;
      }
    }
  }

  dbpath = [dbpath stringByAppendingPathComponent: dbname];
  dberr = sqlite3_open([dbpath fileSystemRepresentation], &db);
    
  if (dberr != SQLITE_OK) {
    NSLog(@"%s", sqlite3_errmsg(db));
		return NULL;	    
  }
      
  return db;  
}

void closedb(sqlite3 *db)
{
  sqlite3_close(db);
}

BOOL createTables(sqlite3 *db, NSString *schema)
{
  if (performQuery(db, schema) == nil) {
    return NO;
  }
  return YES;
}

NSArray *performQuery(sqlite3 *db, NSString *query)
{
  CREATE_AUTORELEASE_POOL(pool);
  NSMutableArray *queryResult = [NSMutableArray array];
	char **results;
	int cols;
	int rows;
  
  results = resultsForQuery(db, query, &rows, &cols);

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
  
  if (results != NULL) {
    sqlite3_free_table(results);
  }
  
  RETAIN (queryResult);
  RELEASE (pool);
  
  return AUTORELEASE (queryResult);
}

BOOL performWriteQuery(sqlite3 *db, NSString *query)
{
  const char *qbuff = [query UTF8String];
  struct sqlite3_stmt *stmt;
  int retry = 0;
  int err;
  
  err = sqlite3_prepare(db, qbuff, strlen(qbuff), &stmt, NULL);
  
  if (err != SQLITE_OK) {
    NSLog(@"%s", sqlite3_errmsg(db));
    return NO;
  }
  
  while (1) {
    err = sqlite3_step(stmt);

    if (err == SQLITE_DONE) {
      break;
      
    } else if (err == SQLITE_BUSY) {
      CREATE_AUTORELEASE_POOL(arp); 
      NSDate *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

      [NSThread sleepUntilDate: when];
      NSLog(@"retry %i", retry);
      RELEASE (arp);

      if (retry++ > MAX_RETRY) {
        NSLog(@"%s", sqlite3_errmsg(db));
        sqlite3_finalize(stmt);
		    return NO;
      }

    } else {
      NSLog(@"%s", sqlite3_errmsg(db));
      sqlite3_finalize(stmt);
      return NO;
    }
  }

  sqlite3_finalize(stmt);
  
  return YES;
}

char **resultsForQuery(sqlite3 *db, NSString *query, int *rows, int *cols)
{
  int retry = 0;
	char **results;
	int err;
  
  *rows = 0;
  *cols = 0;
  
  while (1) {
    err = sqlite3_get_table(db, [query UTF8String], 
                                          &results, rows, cols, NULL);
    if (err == SQLITE_OK) {
      break;

    } else if ((err == SQLITE_BUSY) || (err == SQLITE_LOCKED)) {
      CREATE_AUTORELEASE_POOL(arp); 
      NSDate *when = [NSDate dateWithTimeIntervalSinceNow: 0.1];

      sqlite3_free_table(results);
      results = NULL;
      [NSThread sleepUntilDate: when];
      NSLog(@"retry %i", retry);
      RELEASE (arp);

      if (retry++ > MAX_RETRY) {
        NSLog(@"error %i", err);
		    return NULL;
      }

    } else {
		  sqlite3_free_table(results);
      NSLog(@"error %i", err);
		  return NULL;
    }
  }
  
  return results;
}

NSString *getStringEntry(sqlite3 *db, NSString *query)
{
	char **results;
	int cols;
	int rows;

  results = resultsForQuery(db, query, &rows, &cols);

  if (rows && cols) {
    char *entry = *(results + 1);
    NSString *str = [NSString stringWithUTF8String: entry];
    
    sqlite3_free_table(results);

    return str;
  }

  if (results != NULL) {
    sqlite3_free_table(results);
  }

  return nil;
}

int getIntEntry(sqlite3 *db, NSString *query)
{
	char **results;
	int cols;
	int rows;

  results = resultsForQuery(db, query, &rows, &cols);

  if (rows && cols) {
    char *entry = *(results + 1);
    int n = atoi(entry);
    
    sqlite3_free_table(results);

    return n;
  }

  if (results != NULL) {
    sqlite3_free_table(results);
  }

  return -1;
}

float getFloatEntry(sqlite3 *db, NSString *query)
{
	char **results;
	int cols;
	int rows;

  results = resultsForQuery(db, query, &rows, &cols);

  if (rows && cols) {
    char *entry = *(results + 1);
    float f = atof(entry);
    
    sqlite3_free_table(results);

    return f;
  }

  if (results != NULL) {
    sqlite3_free_table(results);
  }

  return -1.0;
}

NSData *getBlobEntry(sqlite3 *db, NSString *query)
{
	char **results;
	int cols;
	int rows;

  results = resultsForQuery(db, query, &rows, &cols);

  if (rows && cols) {
    char *entry = *(results + 1);
    NSData *data = dataFromBlob(entry);
    
    sqlite3_free_table(results);

    return data;
  }

  if (results != NULL) {
    sqlite3_free_table(results);
  }

  return nil;
}

NSString *blobFromData(NSData *data)
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

NSData *dataFromBlob(const char *blob)
{
	int blength = 0;
  unsigned char *bytes = NSZoneMalloc (NSDefaultMallocZone(), strlen(blob) * 3/4 + 8);
  unsigned char *bytesPtr = bytes;
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

