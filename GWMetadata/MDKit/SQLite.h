/* SQLite.h
 *  
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: May 2006
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

#ifndef SQLITE_H
#define SQLITE_H

#import <Foundation/Foundation.h>

#define id sqlite_id
#include <sqlite3.h>
#undef id

@class SQLitePreparedStatement;

@interface SQLite: NSObject 
{
  sqlite3 *db;
  NSMutableDictionary *preparedStatements;  
  NSFileManager *fm;   
}

+ (id)handlerForDbAtPath:(NSString *)path
                   isNew:(BOOL *)isnew;

- (id)initForDbAtPath:(NSString *)path
                isNew:(BOOL *)isnew;

- (BOOL)opendbAtPath:(NSString *)path
               isNew:(BOOL *)isnew;

- (BOOL)attachDbAtPath:(NSString *)path
              withName:(NSString *)name
                 isNew:(BOOL *)isnew;

- (void)closeDb;

- (sqlite3 *)db;

- (BOOL)executeSimpleQuery:(NSString *)query;

- (BOOL)executeQuery:(NSString *)query;

- (NSArray *)resultsOfQuery:(NSString *)query;

- (int)getIntEntry:(NSString *)query;

- (float)getFloatEntry:(NSString *)query;

- (NSString *)getStringEntry:(NSString *)query;

- (NSData *)getBlobEntry:(NSString *)query;

- (BOOL)createFunctionWithName:(NSString *)fname
                argumentsCount:(int)nargs
                  userFunction:(void *)funct;

- (int)lastInsertRowId;

@end


@interface SQLite (PreparedStatements)

- (id)statementForQuery:(NSString *)query
         withIdentifier:(id)identifier
               bindings:(int)firstTipe, ...;

- (BOOL)executeQueryWithStatement:(SQLitePreparedStatement *)statement;

- (NSArray *)resultsOfQueryWithStatement:(SQLitePreparedStatement *)statement;

- (int)getIntEntryWithStatement:(SQLitePreparedStatement *)statement;

- (float)getFloatEntryWithStatement:(SQLitePreparedStatement *)statement;

- (NSString *)getStringEntryWithStatement:(SQLitePreparedStatement *)statement;

- (NSData *)getBlobEntryWithStatement:(SQLitePreparedStatement *)statement;

@end


@interface SQLitePreparedStatement: NSObject 
{
  NSString *query;
  sqlite3_stmt *handle;
  sqlite3 *db;
}

+ (id)statementWithQuery:(NSString *)aquery
                    onDb:(sqlite3 *)dbptr;
                     
- (id)initWithQuery:(NSString *)aquery
               onDb:(sqlite3 *)dbptr;
          
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

- (BOOL)finalizeStatement;

- (NSString *)query;

- (sqlite3_stmt *)handle;

@end


NSString *stringForQuery(NSString *str);

#endif // SQLITE_H


