/* MDKQuery.h
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: August 2006
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

#ifndef MDK_QUERY_H
#define MDK_QUERY_H

#include <Foundation/Foundation.h>

typedef enum _GMDOperatorType
{
  GMDLessThanOperatorType,
  GMDLessThanOrEqualToOperatorType,
  GMDGreaterThanOperatorType,
  GMDGreaterThanOrEqualToOperatorType,
  GMDEqualToOperatorType,
  GMDNotEqualToOperatorType,
  GMDInRangeOperatorType
} GMDOperatorType;

typedef enum _GMDCompoundOperator
{
  GMDCompoundOperatorNone,  
  GMDAndCompoundOperator,  
  GMDOrCompoundOperator
} GMDCompoundOperator;


@interface MDKQuery : NSObject
{  
  NSString *attribute;
  int attributeType;
  NSString *searchValue;
  BOOL caseSensitive;
  
  GMDOperatorType operatorType;
  NSString *operator;
    
  NSArray *searchPaths;
  NSString *srcTable;  
  NSString *destTable;  
  NSString *joinTable;  

  NSMutableArray *subqueries;
  BOOL subclosed;
  BOOL built;
  MDKQuery *parentQuery;
  GMDCompoundOperator compoundOperator;
  
  NSMutableDictionary *sqlDescription;
  NSMutableDictionary *sqlUpdatesDescription;
  NSArray *attributesList;
  NSDictionary *results;
  NSMutableDictionary *groupedResults;
  
  id qmanager;
  id delegate;
  BOOL started;
  BOOL stopped;
  BOOL updating;
  BOOL reportRawResults;
}

+ (NSArray *)attributesNames;

+ (NSDictionary *)attributesInfo;

+ (NSString *)attributeDescription:(NSString *)attribute;

+ (id)query;

+ (MDKQuery *)queryFromString:(NSString *)qstr
                inDirectories:(NSArray *)searchdirs;

+ (MDKQuery *)queryWithContentsOfFile:(NSString *)path;

- (id)initForAttribute:(NSString *)attr
           searchValue:(NSString *)value
          operatorType:(GMDOperatorType)optype;

- (BOOL)writeToFile:(NSString *)path 
         atomically:(BOOL)flag;

- (void)setCaseSensitive:(BOOL)csens;
- (void)setTextOperatorForCaseSensitive:(BOOL)csens;

- (void)setSearchPaths:(NSArray *)srcpaths;
- (NSArray *)searchPaths;

- (void)setSrcTable:(NSString *)srctab;
- (NSString *)srcTable;

- (void)setDestTable:(NSString *)dsttab;
- (NSString *)destTable;
- (MDKQuery *)queryWithDestTable:(NSString *)tab;

- (void)setJoinTable:(NSString *)jtab;
- (NSString *)joinTable;

- (void)setCompoundOperator:(GMDCompoundOperator)op;
- (GMDCompoundOperator)compoundOperator;

- (void)setParentQuery:(MDKQuery *)query;
- (MDKQuery *)parentQuery;

- (MDKQuery *)leftSibling;

- (BOOL)hasParentWithCompound:(GMDCompoundOperator)op;

- (MDKQuery *)rootQuery;

- (BOOL)isRoot;

- (MDKQuery *)appendSubqueryWithCompoundOperator:(GMDCompoundOperator)op;

- (void)appendSubquery:(id)query
      compoundOperator:(GMDCompoundOperator)op;

- (void)appendSubqueryWithCompoundOperator:(GMDCompoundOperator)op
                                 attribute:(NSString *)attr
                               searchValue:(NSString *)value
                              operatorType:(GMDOperatorType)optype        
                             caseSensitive:(BOOL)csens;

- (void)appendSubqueriesFromString:(NSString *)qstr;

- (void)closeSubqueries;

- (BOOL)isClosed;

- (NSArray *)subqueries;

- (BOOL)buildQuery;

- (BOOL)isBuilt;

- (void)appendSQLToPreStatements:(NSString *)sqlstr
                   checkExisting:(BOOL)check;

- (void)appendSQLToPostStatements:(NSString *)sqlstr
                    checkExisting:(BOOL)check;

- (void)appendToAttributesList:(NSCountedSet *)attributes;

@end


@interface MDKQuery (gathering)

- (void)setDelegate:(id)adelegate;

- (NSDictionary *)sqlDescription;

- (NSDictionary *)sqlUpdatesDescription;

- (void)setQueryNumber:(NSNumber *)qnum;
- (NSNumber *)queryNumber;

- (void)startQuery;
- (void)setStarted;
- (BOOL)isStarted;

- (void)stopQuery;
- (BOOL)isStopped;

- (void)enableUpdates;
- (void)disableUpdates;
- (BOOL)updating;

- (void)setReportRawResults:(BOOL)value;

- (void)endQuery;

- (void)appendResults:(NSArray *)lines;

- (void)insertPath:(NSString *)path
          andScore:(NSNumber *)score
      inDictionary:(NSDictionary *)dict
       needSorting:(BOOL)sort;

- (void)removePaths:(NSArray *)paths;

- (NSArray *)attributesList;

- (NSDictionary *)results;

- (NSDictionary *)groupedResults;

@end


@interface NSObject (MDKQueryDelegate)

- (void)appendRawResults:(NSArray *)lines;

- (void)queryStarted:(MDKQuery *)query;

- (void)queryDidUpdateResults:(MDKQuery *)query;

- (void)endOfQuery:(MDKQuery *)query;

@end

#endif // MDK_QUERY_H









