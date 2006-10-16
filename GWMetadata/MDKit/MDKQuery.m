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

#include "MDKQuery.h"
#include "MDKQueryManager.h"
#include "SQLite.h"

static NSArray *attrNames = nil;
static NSDictionary *attrInfo = nil;

static NSString *path_sep(void);

enum {
  STRING,
  ARRAY,
  NUMBER,
  DATE,
  DATA
};

enum {
  NUM_INT,
  NUM_FLOAT,
  NUM_BOOL
};


@interface MDKAttributeQuery : MDKQuery
{
}

- (BOOL)validateOperatorTypeForAttribute:(NSDictionary *)attrinfo;

- (void)setOperatorFromType;

@end


@interface MDKTextContentQuery : MDKQuery
{
}

@end


@interface MDKQueryScanner : NSScanner
{
  MDKQuery *rootQuery;
  MDKQuery *currentQuery;
}

+ (MDKQueryScanner *)scannerWithString:(NSString *)string
                          forRootQuery:(MDKQuery *)query;
- (void)parseQuery;
- (void)parse;
- (MDKQuery *)parseComparison;
- (NSString *)scanAttributeName;
- (NSDictionary *)scanSearchValueForAttributeType:(int)type;
- (BOOL)scanQueryKeyword:(NSString *)key;

@end


@implementation MDKQuery

- (void)dealloc
{  
  RELEASE (subqueries);
  TEST_RELEASE (attribute);
  TEST_RELEASE (searchValue);
  TEST_RELEASE (operator);
  TEST_RELEASE (searchPaths);
  RELEASE (srcTable);
  RELEASE (destTable); 
  TEST_RELEASE (joinTable);
  RELEASE (sqldescription);
  
	[super dealloc];
}

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO) {
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSString *dictpath = [bundle pathForResource: @"attributes" ofType: @"plist"];

    attrInfo = [NSDictionary dictionaryWithContentsOfFile: dictpath];
    RETAIN (attrInfo);
    attrNames = [attrInfo allKeys];
    RETAIN (attrNames);
  
    initialized = YES;
  }
}

+ (NSArray *)attributesNames
{
  return attrNames;
}

+ (NSDictionary *)attributesInfo
{
  return attrInfo;
}

+ (NSString *)attributeDescription:(NSString *)attribute
{
  NSDictionary *dict = [attrInfo objectForKey: attribute];
  
  if (dict) {
    return [dict objectForKey: @"description"];
  }
  
  return nil;
}

+ (id)query
{
  return AUTORELEASE ([MDKQuery new]);
}

+ (MDKQuery *)queryFromString:(NSString *)qstr
                inDirectories:(NSArray *)searchdirs
{
  MDKQuery *query = [self query];  
  NSMutableString *mqstr = [[qstr mutableCopy] autorelease];
  MDKQueryScanner *scanner;

  [query setSearchPaths: searchdirs];
  
  [mqstr replaceOccurrencesOfString: @"(" 
                         withString: @" ( " 
                            options: NSLiteralSearch
                              range: NSMakeRange(0, [mqstr length])];

  [mqstr replaceOccurrencesOfString: @")" 
                         withString: @" ) " 
                            options: NSLiteralSearch
                              range: NSMakeRange(0, [mqstr length])];
  
  scanner = [MDKQueryScanner scannerWithString: mqstr forRootQuery: query];
  [scanner parseQuery];
  
  return query;
}

- (id)init
{
  self = [super init];
  
  if (self) {   
    qmanager = [MDKQueryManager queryManager];

    attribute = nil;
    searchValue = nil;
   
    caseSensitive = NO;
    operatorType = GMDEqualToOperatorType;
    operator = nil;
    searchPaths = nil;     
    
    ASSIGN (srcTable, @"paths");
    ASSIGN (destTable, ([NSString stringWithFormat: @"tab_%i", [qmanager nextTableNumber]]));
    joinTable = nil;
            
    subqueries = [NSMutableArray new];    
    subclosed = NO;
    parentQuery = nil;     
    compoundOperator = GMDCompoundOperatorNone;

    sqldescription = [NSMutableDictionary new]; 
    [sqldescription setObject: [NSMutableArray array] forKey: @"pre"];
    [sqldescription setObject: [NSString string] forKey: @"join"];
    [sqldescription setObject: [NSMutableArray array] forKey: @"post"];
  }
  
  return self;
}

- (id)initForAttribute:(NSString *)attr
           searchValue:(NSString *)value
          operatorType:(GMDOperatorType)optype           
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void)setCaseSensitive:(BOOL)csens
{
  caseSensitive = csens;
}

- (void)setTextOperatorForCaseSensitive:(BOOL)csens
{ 
  [self subclassResponsibility: _cmd];
}

- (void)setSearchPaths:(NSArray *)srcpaths
{
  if (srcpaths) {
    unsigned i;
    
    for (i = 0; i < [subqueries count]; i++) {
      [[subqueries objectAtIndex: i] setSearchPaths: srcpaths];
    }
  
    ASSIGN (searchPaths, srcpaths);
  } else {
    DESTROY (searchPaths);
  }
}

- (NSArray *)searchPaths
{
  return searchPaths;
}

- (void)setSrcTable:(NSString *)srctab
{
  if (srctab) {
    ASSIGN (srcTable, srctab);
  }
}

- (NSString *)srcTable
{
  return srcTable;
}

- (void)setDestTable:(NSString *)dsttab
{
  if (dsttab) {
    ASSIGN (destTable, dsttab);
  }
}

- (NSString *)destTable
{
  return destTable;
}

- (MDKQuery *)queryWithDestTable:(NSString *)tab
{
  unsigned i;
  
  if ([destTable isEqual: tab]) {
    return self;
  }
  
  for (i = 0; i < [subqueries count]; i++) {
    MDKQuery *query = [subqueries objectAtIndex: i];

    if ([query queryWithDestTable: tab] != nil) {
      return query;
    }
  }

  return nil;
}

- (void)setJoinTable:(NSString *)jtab
{
  if (jtab) {
    ASSIGN (joinTable, jtab);
    
    if (parentQuery != nil) {
      [parentQuery setJoinTable: joinTable];
    }
  }
}

- (NSString *)joinTable
{
  return joinTable;
}

- (void)setCompoundOperator:(GMDCompoundOperator)op
{
  compoundOperator = op;
}

- (GMDCompoundOperator)compoundOperator
{
  return compoundOperator;
}

- (void)setParentQuery:(MDKQuery *)query
{
  MDKQuery *leftSibling;

  parentQuery = query;
  leftSibling = [self leftSibling];
  
  if (compoundOperator == GMDAndCompoundOperator) {
    if (leftSibling) {
      [self setSrcTable: [leftSibling destTable]];
      /* destTable is set in -init */
      [parentQuery setDestTable: [self destTable]];
      
    } else {
      [self setSrcTable: [parentQuery srcTable]];
      [self setDestTable: [parentQuery destTable]];
    }
  
  } else if (compoundOperator == GMDOrCompoundOperator) {
    if (leftSibling) {
      [self setSrcTable: [leftSibling srcTable]];
      [self setDestTable: [leftSibling destTable]];    
    } else {
      [self setSrcTable: [parentQuery srcTable]];
      [self setDestTable: [parentQuery destTable]];
    }
  
  } else {
    /* first subquery */
    if (leftSibling == nil) {
      [self setSrcTable: [parentQuery srcTable]];
      [self setDestTable: [parentQuery destTable]];
    } else {
      [NSException raise: NSInternalInconsistencyException
		              format: @"invalid compound operator"];     
    }
  }
}

/*
- (void)closeSubqueries
{
  if (parentQuery) {
    [parentQuery setDestTable: destTable];
  }
}
*/



- (MDKQuery *)parentQuery
{
  return parentQuery;
}

- (MDKQuery *)leftSibling
{
  MDKQuery *sibling = nil;

  if (parentQuery) {
    NSArray *subs = [parentQuery subqueries];
    unsigned index = [subs indexOfObject: self];
    
    if (index > 0) {
      sibling = [subs objectAtIndex: index - 1];
    }
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"query not in tree"];     
  }
  
  return sibling;
}

- (BOOL)hasParentWithCompound:(GMDCompoundOperator)op
{
  Class c = [MDKQuery class];
  MDKQuery *query = self;
  
  while (query != nil) {
    query = [query parentQuery];
  
    if (query && [query isMemberOfClass: c]) {
      GMDCompoundOperator qop = [query compoundOperator];
      
      if (qop == op) {
        break;
      } else if (qop != GMDCompoundOperatorNone) {
        query = nil;
      }
    } else {
      query = nil;
    }
  }

  return (query && (query != self));
}

- (MDKQuery *)rootQuery
{
  MDKQuery *query = self;

  while (1) {
    MDKQuery *pre = [query parentQuery];
  
    if (pre != nil) {
      query = pre;
    } else {
      break;
    }
  }

  return query;
}

- (BOOL)isRoot
{
  return (parentQuery == nil);
}

- (MDKQuery *)appendSubqueryWithCompoundOperator:(GMDCompoundOperator)op
{
  if (subclosed == NO) {
    MDKQuery *query = [MDKQuery query];

    [subqueries addObject: query];
    [query setCompoundOperator: op];
    [query setParentQuery: self];
    [query setSearchPaths: searchPaths];

    return query;
  }
  
  [NSException raise: NSInternalInconsistencyException
		          format: @"trying to append to a closed query."];     
  
  return nil;
}

- (void)appendSubquery:(id)query
      compoundOperator:(GMDCompoundOperator)op
{
  if (subclosed == NO) {
    if ([subqueries containsObject: query] == NO) {
      [subqueries addObject: query];
      [query setCompoundOperator: op];
      [query setParentQuery: self];
      [query setSearchPaths: searchPaths];
    }  
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"trying to append to a closed query."];     
  }
}

- (void)appendSubqueryWithCompoundOperator:(GMDCompoundOperator)op
                                 attribute:(NSString *)attr
                               searchValue:(NSString *)value
                              operatorType:(GMDOperatorType)optype        
                             caseSensitive:(BOOL)csens
{
  if (subclosed == NO) {
    Class queryClass;
    id query = nil;

    if ([attr isEqual: @"GSMDItemTextContent"]) {  
      queryClass = [MDKTextContentQuery class];
    } else {
      queryClass = [MDKAttributeQuery class];
    }

    query = [[queryClass alloc] initForAttribute: attr 
                                     searchValue: value
                                    operatorType: optype];
    if (query) {
      [query setCaseSensitive: csens];    
      [query setSearchPaths: searchPaths];

      [subqueries addObject: query];
      [query setCompoundOperator: op];
      [query setParentQuery: self];

      RELEASE (query);

    } else {
      [NSException raise: NSInvalidArgumentException
		              format: @"invalid arguments for query %@ %@", attr, value];     
    }
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"trying to append to a closed query."];     
  }
}

- (void)appendSubqueriesFromString:(NSString *)qstr
{
  if ([self isRoot]) {
    NSMutableString *mqstr = [[qstr mutableCopy] autorelease];
    MDKQueryScanner *scanner;
  
    [mqstr replaceOccurrencesOfString: @"(" 
                           withString: @" ( " 
                              options: NSLiteralSearch
                                range: NSMakeRange(0, [mqstr length])];

    [mqstr replaceOccurrencesOfString: @")" 
                           withString: @" ) " 
                              options: NSLiteralSearch
                                range: NSMakeRange(0, [mqstr length])];
  
    scanner = [MDKQueryScanner scannerWithString: mqstr forRootQuery: self];
    [scanner parseQuery];    
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not the root query.", [self description]];     
  }
}

- (void)closeSubqueries
{
  if (subclosed == NO) {
    if (parentQuery) {
      [parentQuery setDestTable: destTable];
    }
    subclosed = YES;
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"trying to close a closed query."];     
  }
}

- (NSArray *)subqueries
{
  return subqueries;
}

- (BOOL)buildQuery
{
  if (subclosed) {
    BOOL built = YES;
    unsigned i;

    for (i = 0; i < [subqueries count]; i++) {
      built = [[subqueries objectAtIndex: i] buildQuery];    
      if (built == NO) {
        break;
      }
    }

    return built;
  
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"trying to build an unclosed query."];     
  }
  
  return NO;
}

- (void)appendSQLToPreStatements:(NSString *)sqlstr
                   checkExisting:(BOOL)check
{
  if ([self isRoot]) {
    NSMutableArray *sqlpre = [sqldescription objectForKey: @"pre"];  

    if ((check == NO) || ([sqlpre containsObject: sqlstr] == NO)) {
      [sqlpre addObject: sqlstr];
    }

  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not the root query.", [self description]];     
  }
}

- (void)appendSQLToPostStatements:(NSString *)sqlstr
                    checkExisting:(BOOL)check
{
  if ([self isRoot]) {
    NSMutableArray *sqlpost = [sqldescription objectForKey: @"post"];  

    if ((check == NO) || ([sqlpost containsObject: sqlstr] == NO)) {
      [sqlpost addObject: sqlstr];
    }

  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not the root query.", [self description]];     
  }
}

- (NSString *)description
{
  NSMutableString *descr = [NSMutableString string];
  unsigned i;
  
  [descr appendString: @"("];

  for (i = 0; i < [subqueries count]; i++) {
    MDKQuery *query = [subqueries objectAtIndex: i];
    GMDCompoundOperator op = [query compoundOperator];
    
    switch (op) {
      case GMDAndCompoundOperator:
        [descr appendString: @" && "];
        break;
      case GMDOrCompoundOperator:
        [descr appendString: @" || "];
        break;
      case GMDCompoundOperatorNone:
      default:
        [descr appendString: @" "];
        break;
    }
  
    [descr appendString: [[subqueries objectAtIndex: i] description]];
  }

  [descr appendString: @" )"];
  
  return descr;
}

- (NSDictionary *)sqldescription
{
  if ([self isRoot]) {
    NSString *jtable = [self joinTable];
    NSString *joinquery = [NSString stringWithFormat: @"SELECT %@.path, "
                                          @"%@.score, "
                                          @"%@.attribute "
                                          @"FROM %@ "
                                          @"ORDER BY %@.score DESC; ",
                                          jtable, jtable, jtable, jtable, jtable];
  
    [sqldescription setObject: joinquery forKey: @"join"];
  
    return sqldescription;
  
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not the root query.", [self description]];     
  }
  
  return nil;
}

@end


@implementation MDKAttributeQuery

- (void)dealloc
{  
	[super dealloc];
}

- (id)initForAttribute:(NSString *)attr
           searchValue:(NSString *)value
          operatorType:(GMDOperatorType)optype
{
  self = [super init];
  
  if (self) {
    ASSIGN (attribute, attr);
    ASSIGN (searchValue, stringForQuery(value));
    operatorType = optype;
    subclosed = YES;
    
    if ([attrNames containsObject: attribute]) {
      NSDictionary *info = [attrInfo objectForKey: attribute];
      
      if ([self validateOperatorTypeForAttribute: info] == NO) {
        DESTROY (self);
        return self;
      }
      
      attributeType = [[info objectForKey: @"type"] intValue];
      
      switch (attributeType) {
        case STRING:
        case ARRAY:
        case DATA:        
          [self setTextOperatorForCaseSensitive: NO];
          break;
          
        case NUMBER:
        case DATE:
          [self setOperatorFromType];
          break;

        default:
          DESTROY (self);
          break;
      }
    
    } else {
      DESTROY (self);
    }
  }
  
  return self;
}

- (BOOL)validateOperatorTypeForAttribute:(NSDictionary *)attrinfo
{
  int attrtype = [[attrinfo objectForKey: @"type"] intValue];

  if ((attrtype == STRING) || (attrtype == DATA)) {
    if ((operatorType != GMDEqualToOperatorType) 
              && (operatorType != GMDNotEqualToOperatorType)) {
      return NO;
    }
  
  } else if (attrtype == ARRAY) {
    int elemtype = [[attrinfo objectForKey: @"elements_type"] intValue];
  
    if ((elemtype == STRING) || (elemtype == DATA)) {
      if ((operatorType != GMDEqualToOperatorType) 
              && (operatorType != GMDNotEqualToOperatorType)) {
        return NO;
      }
    } else {
      return NO;
    }
  
  } else if (attrtype == NUMBER) {
    int numtype = [[attrinfo objectForKey: @"number_type"] intValue];

    if (numtype == NUM_BOOL) {
      if ((operatorType != GMDEqualToOperatorType) 
              && (operatorType != GMDNotEqualToOperatorType)) {
        return NO;
      }
    }

  } else if (attrtype == DATE) {
    if ([NSDate dateWithString: searchValue] == nil) {
      return NO;
    }
  
  } else {
    return NO;
  }

  return YES;
}

- (void)setOperatorFromType
{
  switch (operatorType) {
    case GMDLessThanOperatorType:
      ASSIGN (operator, @"<");
      break;

    case GMDLessThanOrEqualToOperatorType:
      ASSIGN (operator, @"<=");
      break;

    case GMDGreaterThanOperatorType:
      ASSIGN (operator, @">");
      break;

    case GMDGreaterThanOrEqualToOperatorType:
      ASSIGN (operator, @">=");
      break;

    case GMDNotEqualToOperatorType:
      ASSIGN (operator, @"!=");
      break;

    case GMDInRangeOperatorType:
      /* FIXME */
      break;

    default:
      break;
  }
}

- (void)setCaseSensitive:(BOOL)csens
{
  if ((attributeType == STRING) 
              || (attributeType == ARRAY) 
                        || (attributeType == DATA)) {
    [self setTextOperatorForCaseSensitive: csens];
  }
  caseSensitive = csens;
}

- (void)setTextOperatorForCaseSensitive:(BOOL)csens
{ 
  NSString *wc = (csens ? @"%" : @"*");
  NSString *wildcard = (csens ? @"*" : @"%");

  if (operatorType == GMDEqualToOperatorType) {
    ASSIGN (operator, (csens ? @"GLOB" : @"LIKE"));
  } else {
    ASSIGN (operator, (csens ? @"NOT GLOB" : @"NOT LIKE"));
  }
 
  if ([searchValue rangeOfString: wc].location != NSNotFound) {
    NSMutableString *mvalue = [searchValue mutableCopy];
  
    [mvalue replaceOccurrencesOfString: wc 
                            withString: wildcard 
                               options: NSLiteralSearch
                                 range: NSMakeRange(0, [mvalue length])];
  
    ASSIGN (searchValue, [mvalue makeImmutableCopyOnFail: NO]);
  
    RELEASE (mvalue);
  }    
  
  caseSensitive = csens;
}

- (MDKQuery *)appendSubqueryWithCompoundOperator:(GMDCompoundOperator)op
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKAttributeQuery instance."];     
  return nil;
}

- (void)appendSubquery:(id)query
      compoundOperator:(GMDCompoundOperator)op
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKAttributeQuery instance."];     
}

- (void)appendSubqueryWithCompoundOperator:(GMDCompoundOperator)op
                                 attribute:(NSString *)attr
                               searchValue:(NSString *)value
                              operatorType:(GMDOperatorType)optype        
                             caseSensitive:(BOOL)csens
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKAttributeQuery instance."];     
}

- (BOOL)buildQuery
{
  MDKQuery *root = [self rootQuery];
  MDKQuery *leftSibling = [self leftSibling];
  NSMutableString *sqlstr;
  
  sqlstr = [NSString stringWithFormat: @"CREATE TEMP TABLE %@ "
                                   @"(id INTEGER UNIQUE ON CONFLICT IGNORE, "
                                   @"path TEXT UNIQUE ON CONFLICT IGNORE, "
                                   @"words_count INTEGER, "
                                   @"score REAL, "
                                   @"attribute TEXT); ", destTable];
  
  [root appendSQLToPreStatements: sqlstr checkExisting: YES];

  sqlstr = [NSString stringWithFormat: @"CREATE TEMP TRIGGER %@_trigger "
               @"BEFORE INSERT ON %@ "
               @"BEGIN "
               @"UPDATE %@ "
               @"SET score = (score + new.score), "
               @"attribute = "
               @"(CASE WHEN (containsSubstr(new.attribute, attribute) == 0) "
               @"THEN (new.attribute || ' ' || attribute) "
               @"ELSE (new.attribute) END) "
               @"WHERE id = new.id; "
               @"END;", destTable, destTable, destTable];

  [root appendSQLToPreStatements: sqlstr checkExisting: YES];

  sqlstr = [NSMutableString string];
          
  [sqlstr appendFormat: @"INSERT INTO %@ (id, path, words_count, score, attribute) "
      @"SELECT "
      @"%@.id, "
      @"%@.path, "
      @"%@.words_count, "
      @"0.0, "
      @"'%@' || ',' || attributeScore('%@', attributes.attribute, %i, %i) "
      @"FROM %@, attributes "
      @"WHERE attributes.key = '%@' ", 
      destTable, srcTable, srcTable, srcTable, 
      attribute, searchValue, attributeType, operatorType, 
      srcTable, attribute];

  [sqlstr appendFormat: @"AND attributes.attribute %@ ", operator];
      
  if ((attributeType == STRING) || (attributeType == DATA)) {
    [sqlstr appendString: @"'"];
    [sqlstr appendString: searchValue];
    [sqlstr appendString: @"' "];
      
  } else if (attributeType == ARRAY) {
    [sqlstr appendString: @"'"];
    [sqlstr appendString: (caseSensitive ? @"*" : @"%")];
    [sqlstr appendString: searchValue];
    [sqlstr appendString: (caseSensitive ? @"*" : @"%")];
    [sqlstr appendString: @"' "];
       
  } else if (attributeType == NUMBER) {
    NSDictionary *info = [attrInfo objectForKey: attribute];
    int numtype = [[info objectForKey: @"number_type"] intValue];

    [sqlstr appendFormat: @"(cast (%@ as ", searchValue];

    if (numtype == NUM_FLOAT) {
      [sqlstr appendString: @"REAL)) "];
    } else {
      [sqlstr appendString: @"INTEGER)) "];
    }
  
  } else if (attributeType == DATE) {
    NSDate *date = [NSDate dateWithString: searchValue];
    NSTimeInterval interval = [date timeIntervalSinceReferenceDate];

    [sqlstr appendFormat: @"(cast (%f as REAL)) ", interval];
  
  } else {
    return NO;
  }
        
  [sqlstr appendFormat: @"AND attributes.path_id = %@.id ", srcTable];      

  if (searchPaths) {
    unsigned count = [searchPaths count];
    unsigned i;

    [sqlstr appendString: @"AND ("];

    for (i = 0; i < count; i++) {
      NSString *path = [searchPaths objectAtIndex: i];
      NSString *minpath = [NSString stringWithFormat: @"%@%@*", path, path_sep()];

      [sqlstr appendFormat: @"(%@.path = '%@' OR %@.path GLOB '%@') ",
                            srcTable, path, srcTable, minpath];    

      if (i != (count - 1)) {
        [sqlstr appendString: @"OR "];
      }
    }

    [sqlstr appendString: @")"];      
  }

  [sqlstr appendString: @";"];    

  [root appendSQLToPreStatements: sqlstr checkExisting: NO];

  if (((leftSibling != nil) && (compoundOperator == GMDAndCompoundOperator))
        || ((leftSibling == nil) && [self hasParentWithCompound: GMDAndCompoundOperator])) {
    NSMutableString *joinquery = [NSMutableString string];

    [joinquery appendFormat: @"INSERT INTO %@ (id, path, words_count, score, attribute) "
                             @"SELECT "
                             @"%@.id, "
                             @"%@.path, "
                             @"%@.words_count, "
                             @"%@.score, "
                             @"%@.attribute "
                             @"FROM "
                             @"%@, %@ "
                             @"WHERE "
                             @"%@.id = %@.id; ",
                             destTable, srcTable, srcTable, 
                             srcTable, srcTable, srcTable,
                             srcTable, destTable, srcTable, destTable];
    
    [root appendSQLToPreStatements: joinquery checkExisting: NO];
  }

  [root appendSQLToPostStatements: [NSString stringWithFormat: @"DROP TABLE %@", destTable] 
                    checkExisting: YES];
  
  [parentQuery setJoinTable: destTable];

  return YES;
}

- (NSString *)description
{
  NSMutableString *descr = [NSMutableString string];
  NSString *svalue = searchValue;
  BOOL txtype = ((attributeType == STRING) 
                          || (attributeType == ARRAY) 
                                    || (attributeType == DATA));
  
  [descr appendString: attribute];

  switch (operatorType) {
    case GMDLessThanOperatorType:
      [descr appendString: @" < "];
      break;
    case GMDLessThanOrEqualToOperatorType:
      [descr appendString: @" <= "];
      break;
    case GMDGreaterThanOperatorType:
      [descr appendString: @" > "];
      break;
    case GMDGreaterThanOrEqualToOperatorType:
      [descr appendString: @" >= "];
      break;
    case GMDEqualToOperatorType:
      [descr appendString: @" == "];
      break;
    case GMDNotEqualToOperatorType:
      [descr appendString: @" != "];
      break;
    case GMDInRangeOperatorType:
      /* TODO */
      break;
    default:
      break;
  }

  if (txtype) {
    NSMutableString *mvalue = [[searchValue mutableCopy] autorelease];
  
    [mvalue replaceOccurrencesOfString: @"%" 
                            withString: @"*" 
                               options: NSLiteralSearch
                                 range: NSMakeRange(0, [mvalue length])];
    svalue = mvalue;
    [descr appendString: @"\""];    
  }
  
  [descr appendString: svalue];
  
  if (txtype) {
    [descr appendString: @"\""];
    
    if (caseSensitive == NO) {
      [descr appendString: @"c"];  
    }      
  }
  
  return descr;
}

@end


@implementation MDKTextContentQuery

- (void)dealloc
{  
	[super dealloc];
}

- (id)initForAttribute:(NSString *)attr
           searchValue:(NSString *)value
          operatorType:(GMDOperatorType)optype
{
  self = [super init];
  
  if (self) {
    if ((optype != GMDEqualToOperatorType) 
                        && (optype != GMDNotEqualToOperatorType)) {
      DESTROY (self);
      return self;
    }
        
    ASSIGN (attribute, attr);
    attributeType = STRING;
    ASSIGN (searchValue, stringForQuery(value));
    operatorType = optype;
    
    [self setTextOperatorForCaseSensitive: YES];    
    
    subclosed = YES;
  }
  
  return self;
}

- (void)setCaseSensitive:(BOOL)csens
{
  [self setTextOperatorForCaseSensitive: csens];
}

- (void)setTextOperatorForCaseSensitive:(BOOL)csens
{ 
  NSString *wc = (csens ? @"%" : @"*");
  NSString *wildcard = (csens ? @"*" : @"%");
  
  ASSIGN (operator, (csens ? @"GLOB" : @"LIKE"));

  if ([searchValue rangeOfString: wc].location != NSNotFound) {
    NSMutableString *mvalue = [searchValue mutableCopy];
  
    [mvalue replaceOccurrencesOfString: wc 
                            withString: wildcard 
                               options: NSLiteralSearch
                                 range: NSMakeRange(0, [mvalue length])];
  
    ASSIGN (searchValue, [mvalue makeImmutableCopyOnFail: NO]);
  
    RELEASE (mvalue);
  }    
  
  caseSensitive = csens;
}

- (MDKQuery *)appendSubqueryWithCompoundOperator:(GMDCompoundOperator)op
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKTextContentQuery instance."];     
  return nil;
}

- (void)appendSubquery:(id)query
      compoundOperator:(GMDCompoundOperator)op
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKTextContentQuery instance."];     
}

- (void)appendSubqueryWithCompoundOperator:(GMDCompoundOperator)op
                                 attribute:(NSString *)attr
                               searchValue:(NSString *)value
                              operatorType:(GMDOperatorType)optype        
                             caseSensitive:(BOOL)csens
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKTextContentQuery instance."];     
}

- (BOOL)buildQuery
{
  MDKQuery *root = [self rootQuery];
  MDKQuery *leftSibling = [self leftSibling];  
  NSMutableString *sqlstr;

  sqlstr = [NSString stringWithFormat: @"CREATE TEMP TABLE %@ "
                                   @"(id INTEGER UNIQUE ON CONFLICT IGNORE, "
                                   @"path TEXT UNIQUE ON CONFLICT IGNORE, "
                                   @"words_count INTEGER, "
                                   @"score REAL, "
                                   @"attribute TEXT); ", destTable];
  
  [root appendSQLToPreStatements: sqlstr checkExisting: YES];
  
  sqlstr = [NSString stringWithFormat: @"CREATE TEMP TRIGGER %@_trigger "
               @"BEFORE INSERT ON %@ "
               @"BEGIN "
               @"UPDATE %@ "
               @"SET score = (score + new.score), "
               @"attribute = "
               @"(CASE WHEN (containsSubstr(new.attribute, attribute) == 0) "
               @"THEN (new.attribute || ' ' || attribute) "
               @"ELSE (new.attribute) END) "
               @"WHERE id = new.id; "
               @"END;", destTable, destTable, destTable];

  [root appendSQLToPreStatements: sqlstr checkExisting: YES];

  sqlstr = [NSMutableString string];

  if (operatorType == GMDEqualToOperatorType) {
    [sqlstr appendFormat: @"INSERT INTO %@ (id, path, words_count, score, attribute) "
        @"SELECT "
        @"%@.id, "
        @"%@.path, "
        @"%@.words_count, "
        @"wordScore('%@', words.word, postings.word_count, %@.words_count), "
        @"'%@' || ',' || 0.0 "    
        @"FROM words, %@, postings ",
        destTable, srcTable, srcTable, srcTable, 
        searchValue, srcTable, attribute, srcTable];

    [sqlstr appendFormat: @"WHERE words.word %@ '", operator];
    [sqlstr appendString: searchValue];
    [sqlstr appendString: @"' "];

    [sqlstr appendFormat: @"AND postings.word_id = words.id "
                         @"AND %@.id = postings.path_id ", srcTable];

  } else {  /* GMDNotEqualToOperatorType */
    [sqlstr appendFormat: @"INSERT INTO %@ (id, path, words_count, score, attribute) "
        @"SELECT "
        @"%@.id AS tid, "
        @"%@.path, "
        @"%@.words_count, "
        @"(1.0 / %@.words_count), "
        @"'%@' || ',' || 0.0 "
        @"FROM %@ ",
        destTable, srcTable, srcTable, srcTable, 
        srcTable, attribute, srcTable];

    [sqlstr appendString: @"WHERE "
                         @"(SELECT words.word "
                         @"FROM words, postings "
                         @"WHERE postings.path_id = tid "
                         @"AND words.id = postings.word_id "];

    [sqlstr appendFormat: @"AND words.word %@ '", operator];

    [sqlstr appendString: searchValue];

    [sqlstr appendString: @"') ISNULL "];
  }

  if (searchPaths) {
    unsigned count = [searchPaths count];
    unsigned i;

    [sqlstr appendString: @"AND ("];

    for (i = 0; i < count; i++) {
      NSString *path = [searchPaths objectAtIndex: i];
      NSString *minpath = [NSString stringWithFormat: @"%@%@*", path, path_sep()];

      [sqlstr appendFormat: @"(%@.path = '%@' OR %@.path GLOB '%@') ",
                            srcTable, path, srcTable, minpath];    

      if (i != (count - 1)) {
        [sqlstr appendString: @"OR "];
      }
    }

    [sqlstr appendString: @") "];      
  }

  [sqlstr appendString: @";"];    

  [root appendSQLToPreStatements: sqlstr checkExisting: NO];

  if (((leftSibling != nil) && (compoundOperator == GMDAndCompoundOperator))
        || ((leftSibling == nil) && [self hasParentWithCompound: GMDAndCompoundOperator])) {
    NSMutableString *joinquery = [NSMutableString string];

    [joinquery appendFormat: @"INSERT INTO %@ (id, path, words_count, score, attribute) "
                             @"SELECT "
                             @"%@.id, "
                             @"%@.path, "
                             @"%@.words_count, "
                             @"%@.score, "
                             @"%@.attribute "
                             @"FROM "
                             @"%@, %@ "
                             @"WHERE "
                             @"%@.id = %@.id; ",
                             destTable, srcTable, srcTable, 
                             srcTable, srcTable, srcTable, 
                             srcTable, destTable, srcTable, destTable];

    [root appendSQLToPreStatements: joinquery checkExisting: NO];
  }

  [root appendSQLToPostStatements: [NSString stringWithFormat: @"DROP TABLE %@", destTable] 
                    checkExisting: YES];
  
  [parentQuery setJoinTable: destTable];
  
  return YES;
}

- (NSString *)description
{
  NSMutableString *descr = [NSMutableString string];
  NSMutableString *mvalue = [[searchValue mutableCopy] autorelease];
  
  [descr appendString: attribute];
  
  if (operatorType == GMDEqualToOperatorType) {
    [descr appendString: @" == "];
  } else {
    [descr appendString: @" != "];
  }
  
  [descr appendString: @"\""];
  [mvalue replaceOccurrencesOfString: @"%" 
                          withString: @"*" 
                             options: NSLiteralSearch
                               range: NSMakeRange(0, [mvalue length])];
  [descr appendString: mvalue];  
  [descr appendString: @"\""];
  
  if (caseSensitive == NO) {
    [descr appendString: @"c"];  
  }  
  
  return descr;
}

@end


@implementation MDKQueryScanner

+ (MDKQueryScanner *)scannerWithString:(NSString *)string
                          forRootQuery:(MDKQuery *)query
{
  MDKQueryScanner *scanner = [[MDKQueryScanner alloc] initWithString: string];
  
  scanner->rootQuery = query;
  scanner->currentQuery = query;
  
  return AUTORELEASE (scanner);
}

- (void)parseQuery
{
  while ([self isAtEnd] == NO) {  
    [self parse];
  }
  [rootQuery closeSubqueries];
  [rootQuery buildQuery];
}

- (void)parse
{
  GMDCompoundOperator op = GMDCompoundOperatorNone;
  static unsigned int parsed = 0;

#define PARSEXCEPT(x, e) \
  if (x > 0) [NSException raise: NSInvalidArgumentException format: e] 
#define COMPOUND 1
#define SUBOPEN 2
#define SUBCLOSE 4
#define COMPARISION 8
  
  if ([self scanQueryKeyword: @"&&"]) {
    op = GMDAndCompoundOperator;            
  } else if ([self scanQueryKeyword: @"||"]) {
    op = GMDOrCompoundOperator;
  }
  
  if (op != GMDCompoundOperatorNone) {
    PARSEXCEPT ((parsed & COMPOUND), @"double compound operator");
    PARSEXCEPT ((parsed & SUBOPEN), @"compound operator without arguments");
    parsed &= ~(SUBOPEN | SUBCLOSE | COMPARISION);
    parsed |= COMPOUND;
  }

  if ([self scanString: @"(" intoString: NULL]) {
    PARSEXCEPT (!(((parsed & SUBOPEN) == SUBOPEN) 
                      || ((parsed & COMPOUND) == COMPOUND)
                      || ((parsed == 0) && (currentQuery == rootQuery))), 
                                      @"subquery without compound operator");
    parsed &= ~(COMPOUND | SUBCLOSE | COMPARISION);  
    parsed |= SUBOPEN;
  
    currentQuery = [currentQuery appendSubqueryWithCompoundOperator: op];

  } else if ([self scanString: @")" intoString: NULL]) {
    PARSEXCEPT ((parsed & COMPOUND), @"compound operator without arguments");
    parsed &= ~(COMPOUND | SUBOPEN | COMPARISION);
    parsed |= SUBCLOSE;
  
    [currentQuery closeSubqueries];
    
    if ((currentQuery == rootQuery) == NO) {
      currentQuery = [currentQuery parentQuery];
    }
    
  } else {
    MDKQuery *query = [self parseComparison];

    PARSEXCEPT ((parsed & COMPARISION), @"subquery without compound operator");
    parsed &= ~(COMPOUND | SUBOPEN | SUBCLOSE);
    parsed |= COMPARISION;
    
    [currentQuery appendSubquery: query compoundOperator: op];
  }
}

- (MDKQuery *)parseComparison
{
  NSString *attribute;
  NSDictionary *attrinfo;
  int attrtype;
  NSDictionary *valueInfo;
  NSString *searchValue;
  GMDOperatorType optype;
  BOOL caseSens;
  Class queryClass;
  id query = nil;

#define CHK_ATTR_TYPE(x) \
  do { if ((attrtype == STRING) || (attrtype == ARRAY) || (attrtype == DATA)) \
    [NSException raise: NSInvalidArgumentException \
		            format: @"Invalid attribute type for operator: %@", x]; \
  } while (0)
  
  attribute = [self scanAttributeName];  
  attrinfo = [[MDKQuery attributesInfo] objectForKey: attribute];
  attrtype = [[attrinfo objectForKey: @"type"] intValue];

  if ([self scanString: @"<" intoString: NULL]) {
    optype = GMDLessThanOperatorType;
    CHK_ATTR_TYPE (@"<");
  } else if ([self scanString: @"<=" intoString: NULL]) {
    optype = GMDLessThanOrEqualToOperatorType;
    CHK_ATTR_TYPE (@"<=");
  } else if ([self scanString: @">" intoString: NULL]) {
    optype = GMDGreaterThanOperatorType;
    CHK_ATTR_TYPE (@">");
  } else if ([self scanString: @">=" intoString: NULL]) {
    optype = GMDGreaterThanOrEqualToOperatorType;
    CHK_ATTR_TYPE (@">=");
  } else if ([self scanString: @"==" intoString: NULL]) {
    optype = GMDEqualToOperatorType;
  } else if ([self scanString: @"!=" intoString: NULL]) {
    optype = GMDNotEqualToOperatorType;
  } else if ([self scanString: @"---------------------" intoString: NULL]) {
    /* TODO TODO TODO TODO TODO TODO TODO */
    optype = GMDInRangeOperatorType;
    CHK_ATTR_TYPE (@"---------------------");
  } else {
    NSString *str = [[self string] substringFromIndex: [self scanLocation]];
    
    [NSException raise: NSInvalidArgumentException 
		            format: @"Invalid query operator: %@", str];
  }
  
  valueInfo = [self scanSearchValueForAttributeType: attrtype];
  searchValue = [valueInfo objectForKey: @"value"];
  caseSens = [[valueInfo objectForKey: @"case_sens"] boolValue];

  if ([attribute isEqual: @"GSMDItemTextContent"]) {  
    queryClass = [MDKTextContentQuery class];
  } else {
    queryClass = [MDKAttributeQuery class];
  }

  query = [[queryClass alloc] initForAttribute: attribute 
                                   searchValue: searchValue
                                  operatorType: optype];
    
  if (query) {
    [query setCaseSensitive: caseSens];    
  }

  return TEST_AUTORELEASE (query);
}

- (NSString *)scanAttributeName
{
  NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSString *attrname;

  if ([self scanUpToCharactersFromSet: set intoString: &attrname] && attrname) {
    if ([[MDKQuery attributesNames] containsObject: attrname]) {
      return attrname;
    }
  }

	[NSException raise: NSInvalidArgumentException 
		          format: @"unable to parse the attribute name"];

  return nil;
}

- (NSDictionary *)scanSearchValueForAttributeType:(int)type
{
  NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  BOOL scanQuote = ((type == STRING) || (type == ARRAY) || (type == DATA));
  BOOL caseSens = YES;
  NSString *value;
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  
  if (scanQuote && ([self scanString: @"\"" intoString: NULL] == NO)) {  
    scanQuote = NO;
  } 

  if (scanQuote) {
    NSString *modifiers;

    if (([self scanUpToString: @"\"" intoString: &value] && value) == NO) {
	    [NSException raise: NSInvalidArgumentException 
		              format: @"Missing \" in query"];
    } else {
      [self scanString: @"\"" intoString: NULL];
    }
  
    if ([self scanUpToCharactersFromSet: set intoString: &modifiers] && modifiers) {
      if ([modifiers rangeOfString: @"c"].location != NSNotFound) {
        caseSens = NO;
      }
    }
  
  } else {
    if (([self scanUpToCharactersFromSet: set intoString: &value] && value) == NO) {
	    [NSException raise: NSInvalidArgumentException 
		              format: @"unable to parse value"];
    }
  }

  [dict setObject: value forKey: @"value"];
  [dict setObject: [NSNumber numberWithBool: caseSens] forKey: @"case_sens"];

  return dict;
}

- (BOOL)scanQueryKeyword:(NSString *)key
{
  unsigned loc = [self scanLocation];
  
  [self setCaseSensitive: NO];
  
  if ([self scanString: key intoString: NULL] == NO) {
    return NO;
  
  } else {
    NSCharacterSet *set = [NSCharacterSet alphanumericCharacterSet];
    unichar c = [[self string] characterAtIndex: [self scanLocation]];
  
    if ([set characterIsMember: c] == NO) {
      return YES;
    }
  }
  
  [self setScanLocation: loc];

  return NO;
}

@end


static NSString *path_sep(void)
{
  static NSString *separator = nil;

  if (separator == nil) {
    #if defined(__MINGW32__)
      separator = @"\\";	
    #else
      separator = @"/";	
    #endif

    RETAIN (separator);
  }

  return separator;
}

