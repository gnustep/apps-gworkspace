/* MDKQuery.h
 *  
 * Copyright (C) 2006-2013 Free Software Foundation, Inc.
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

@class FSNode;
@class MDKQueryManager;

/* we cannot use DATE because it clashes on windows with wtypes.h stuff */
enum {
  STRING,
  ARRAY,
  NUMBER,
  DATE_TYPE,
  DATA
};

enum {
  NUM_INT,
  NUM_FLOAT,
  NUM_BOOL
};

typedef enum _MDKAttributeMask
{
  MDKAttributeSearchable = 1,
  MDKAttributeFSType = 2,
  MDKAttributeBaseSet = 4,
  MDKAttributeUserSet = 8
} MDKAttributeMask;

typedef enum _MDKOperatorType
{
  MDKLessThanOperatorType,
  MDKLessThanOrEqualToOperatorType,
  MDKGreaterThanOperatorType,
  MDKGreaterThanOrEqualToOperatorType,
  MDKEqualToOperatorType,
  MDKNotEqualToOperatorType,
  MDKInRangeOperatorType
} MDKOperatorType;

typedef enum _MDKCompoundOperator
{
  MDKCompoundOperatorNone,  
  GMDAndCompoundOperator,  
  GMDOrCompoundOperator
} MDKCompoundOperator;


@interface MDKQuery : NSObject
{  
  NSString *attribute;
  int attributeType;
  NSString *searchValue;
  BOOL caseSensitive;
  
  MDKOperatorType operatorType;
  NSString *operator;
    
  NSArray *searchPaths;
  NSString *srcTable;  
  NSString *destTable;  
  NSString *joinTable;  

  NSMutableArray *subqueries;
  MDKQuery *parentQuery;
  MDKCompoundOperator compoundOperator;
  
  NSNumber *queryNumber;
  NSMutableDictionary *sqlDescription;
  NSMutableDictionary *sqlUpdatesDescription;
  NSArray *categoryNames;  
  NSMutableDictionary *groupedResults;
  NSArray *fsfilters;
    
  BOOL reportRawResults;
  unsigned int status;    
  
  MDKQueryManager *qmanager;
  id delegate;
}

+ (NSArray *)attributesNames;

+ (NSDictionary *)attributesInfo;

+ (void)updateUserAttributes:(NSArray *)userattrs;

+ (NSString *)attributeDescription:(NSString *)attrname;

+ (NSDictionary *)attributeWithName:(NSString *)name;

+ (NSDictionary *)attributesWithMask:(MDKAttributeMask)mask;

+ (NSArray *)categoryNames;

+ (NSDictionary *)categoryInfo;

+ (void)updateCategoryInfo:(NSDictionary *)info;

+ (id)query;

+ (MDKQuery *)queryFromString:(NSString *)qstr
                inDirectories:(NSArray *)searchdirs;

+ (MDKQuery *)queryWithContentsOfFile:(NSString *)path;

- (id)initForAttribute:(NSString *)attr
           searchValue:(NSString *)value
          operatorType:(MDKOperatorType)optype;

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

- (void)setCompoundOperator:(MDKCompoundOperator)op;
- (MDKCompoundOperator)compoundOperator;

- (void)setParentQuery:(MDKQuery *)query;
- (MDKQuery *)parentQuery;

- (MDKQuery *)leftSibling;

- (BOOL)hasParentWithCompound:(MDKCompoundOperator)op;

- (MDKQuery *)rootQuery;

- (BOOL)isRoot;

- (MDKQuery *)appendSubqueryWithCompoundOperator:(MDKCompoundOperator)op;

- (void)appendSubquery:(id)query
      compoundOperator:(MDKCompoundOperator)op;

- (void)appendSubqueryWithCompoundOperator:(MDKCompoundOperator)op
                                 attribute:(NSString *)attr
                               searchValue:(NSString *)value
                              operatorType:(MDKOperatorType)optype        
                             caseSensitive:(BOOL)csens;

- (void)appendSubqueriesFromString:(NSString *)qstr;

- (void)closeSubqueries;

- (BOOL)isClosed;

- (NSArray *)subqueries;

- (BOOL)buildQuery;

- (BOOL)isBuilt;

- (void)setFSFilters:(NSArray *)filters;

- (NSArray *)fsfilters;

- (void)appendSQLToPreStatements:(NSString *)sqlstr
                   checkExisting:(BOOL)check;

- (void)appendSQLToPostStatements:(NSString *)sqlstr
                    checkExisting:(BOOL)check;

@end


@interface MDKQuery (gathering)

- (void)setDelegate:(id)adelegate;

- (NSDictionary *)sqlDescription;
- (NSDictionary *)sqlUpdatesDescription;
- (NSNumber *)queryNumber;

- (void)startGathering;
- (void)setStarted;
- (BOOL)waitingStart;
- (BOOL)isGathering;
- (void)gatheringDone;

- (void)stopQuery;
- (BOOL)isStopped;

- (void)setUpdatesEnabled:(BOOL)enabled;
- (BOOL)updatesEnabled;
- (BOOL)isUpdating;
- (void)updatingStarted;
- (void)updatingDone;

- (void)appendResults:(NSArray *)lines;

- (void)insertNode:(FSNode *)node
          andScore:(NSNumber *)score
      inDictionary:(NSDictionary *)dict
       needSorting:(BOOL)sort;

- (void)removePaths:(NSArray *)paths;

- (void)removeNode:(FSNode *)node;

- (NSDictionary *)groupedResults;

- (NSArray *)resultNodesForCategory:(NSString *)catname;

- (int)resultsCountForCategory:(NSString *)catname;

- (void)setReportRawResults:(BOOL)value;

@end


@interface NSObject (MDKQueryDelegate)

- (void)appendRawResults:(NSArray *)lines;

- (void)queryDidStartGathering:(MDKQuery *)query;

- (void)queryDidUpdateResults:(MDKQuery *)query
                forCategories:(NSArray *)catnames;

- (void)queryDidEndGathering:(MDKQuery *)query;

- (void)queryDidStartUpdating:(MDKQuery *)query;

- (void)queryDidEndUpdating:(MDKQuery *)query;

@end


@interface NSDictionary (CategorySort)

- (NSComparisonResult)compareAccordingToIndex:(NSDictionary *)dict;

@end

#endif // MDK_QUERY_H









