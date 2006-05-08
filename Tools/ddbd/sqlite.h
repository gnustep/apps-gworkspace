/* sqlite.h
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

#ifndef SQLITE_H
#define SQLITE_H

#include <Foundation/Foundation.h>
#include <sqlite3.h>

sqlite3 *opendbAtPath(NSString *dbpath);

void closedb(sqlite3 *db);

BOOL createTables(sqlite3 *db, NSString *schema);

NSArray *performQuery(sqlite3 *db, NSString *query);

BOOL performWriteQuery(sqlite3 *db, NSString *query);

char **resultsForQuery(sqlite3 *db, NSString *query, int *rows, int *cols);

NSString *getStringEntry(sqlite3 *db, NSString *query);

int getIntEntry(sqlite3 *db, NSString *query);

float getFloatEntry(sqlite3 *db, NSString *query);

NSData *getBlobEntry(sqlite3 *db, NSString *query);

NSString *blobFromData(NSData *data);

void decodeBlobUnit(unsigned char *unit, const char *src);

NSData *dataFromBlob(const char *blob);

NSString *stringForQuery(NSString *str);


@interface SQLitePreparedStatement: NSObject 
{
  NSString *query;
  sqlite3_stmt *handle;
  sqlite3 *db;
}

+ (id)statementForQuery:(NSString *)querystr
               dbHandle:(sqlite3 *)dbptr;
                     
- (id)initForQuery:(NSString *)querystr
          dbHandle:(sqlite3 *)dbptr;
          
- (BOOL)bindIntValue:(int)value 
             forName:(NSString *)name;

- (BOOL)bindDoubleValue:(double)value 
                forName:(NSString *)name;

- (BOOL)bindTextValue:(NSString *)value 
              forName:(NSString *)name;

- (BOOL)bindBlobValue:(NSData *)value 
              forName:(NSString *)name;

- (BOOL)expired;

- (BOOL)prepare;

- (BOOL)reset;

- (BOOL)finalize;

- (NSString *)query;

- (sqlite3_stmt *)handle;

@end


@interface SQLiteQueryManager: NSObject 
{
  sqlite3 *db;
  NSMutableDictionary *preparedStatements;
}

- (id)initForDb:(sqlite3 *)dbptr;

- (id)statementForQuery:(NSString *)query
         withIdentifier:(id)identifier
               bindings:(int)firstTipe, ...;

- (SQLitePreparedStatement *)statementWithIdentifier:(id)identifier;

- (SQLitePreparedStatement *)statementForQuery:(NSString *)query;

- (void)addPreparedStatement:(SQLitePreparedStatement *)statement
               forIdentifier:(id)identifier;

- (NSArray *)resultsOfQuery:(NSString *)query;

- (NSArray *)resultsOfQueryWithStatement:(SQLitePreparedStatement *)statement;

- (BOOL)executeQuery:(NSString *)query;

- (BOOL)executeQueryWithStatement:(SQLitePreparedStatement *)statement;

- (int)getIntEntry:(NSString *)query;

- (int)getIntEntryWithStatement:(SQLitePreparedStatement *)statement;

- (float)getFloatEntry:(NSString *)query;

- (float)getFloatEntryWithStatement:(SQLitePreparedStatement *)statement;

- (NSString *)getStringEntry:(NSString *)query;

- (NSData *)getBlobEntry:(NSString *)query;

- (NSData *)getBlobEntryWithStatement:(SQLitePreparedStatement *)statement;

@end

#endif // SQLITE_H


