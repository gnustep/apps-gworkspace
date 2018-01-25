/* MDKQuery.m
 *  
 * Copyright (C) 2006-2018 Free Software Foundation, Inc.
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

#import "MDKQuery.h"
#import "MDKQueryManager.h"
#include "SQLite.h"
#import "FSNode.h"

static NSArray *attrNames = nil;
static NSDictionary *attrInfo = nil;

static NSString *path_sep(void);
BOOL subPathOfPath(NSString *p1, NSString *p2);

static NSArray *basesetAttributes(void)
{
  static NSArray *attributes = nil;

  if (attributes == nil) {
    attributes = [[NSArray alloc] initWithObjects: 
	        @"GSMDItemFSName",
	        @"GSMDItemFSExtension",    
	        @"GSMDItemFSType",

	        @"GSMDItemFSSize",              // FSAttribute
	        @"GSMDItemFSModificationDate",  // FSAttribute
	        @"GSMDItemFSOwnerUser",         // FSAttribute
	        @"GSMDItemFSOwnerGroup",        // FSAttribute

	        @"GSMDItemFinderComment",

	        @"GSMDItemApplicationName",
	        @"GSMDItemRole",
          @"GSMDItemUnixExtensions",

	        @"GSMDItemTitle",
	        @"GSMDItemAuthors",
	        @"GSMDItemCopyrightDescription",
          nil];
  }

  return attributes;
}

enum {
  SUBCLOSED = 1,
  BUILT = 2,
  STOPPED = 4,
  GATHERING = 8,
  WAITSTART = 16,
  UPDATE_ENABLE = 32,
  UPDATING = 64
};


#define CHECKDELEGATE(s) \
  ((delegate != nil) \
    && [delegate respondsToSelector: @selector(s)])
    
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
  RELEASE (queryNumber);
  RELEASE (sqlDescription);
  RELEASE (sqlUpdatesDescription);
  TEST_RELEASE (categoryNames);
  TEST_RELEASE (groupedResults);
  TEST_RELEASE (fsfilters);
  
  [super dealloc];
}

+ (void)initialize
{
  static BOOL initialized = NO;

  if (initialized == NO) {
    NSBundle *bundle = [NSBundle bundleForClass: [self class]];
    NSString *dictpath = [bundle pathForResource: @"attributes" ofType: @"plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: dictpath];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
    NSDictionary *domain = [defaults persistentDomainForName: @"MDKQuery"];
    
    if (dict == nil) {
      [NSException raise: NSInternalInconsistencyException
		              format: @"\"%@\" doesn't contain a dictionary!", dictpath];     
    }
    
    ASSIGN (attrInfo, [dict objectForKey: @"attributes"]);
    ASSIGN (attrNames, [attrInfo allKeys]);
               
    if (domain == nil) {
      domain = [NSDictionary dictionaryWithObjectsAndKeys: 
                      basesetAttributes(), @"user-attributes",
                     [dict objectForKey: @"categories"], @"categories", nil];
      [defaults setPersistentDomain: domain forName: @"MDKQuery"];
      [defaults synchronize];
    } else {
      NSArray *entry = nil;
      BOOL modified = NO;
      NSMutableDictionary *mdom = nil;
      
      entry = [domain objectForKey: @"user-attributes"];
      
      if ((entry == nil) || ([entry count] == 0)) {
        mdom = [domain mutableCopy];    
        [mdom setObject: basesetAttributes() forKey: @"user-attributes"];
        modified = YES;
      }
      
      entry = [domain objectForKey: @"categories"];
      
      if ((entry == nil) || ([entry count] == 0)) {      
        if (mdom == nil) {
          mdom = [domain mutableCopy];
        }
        [mdom setObject: [dict objectForKey: @"categories"] 
                 forKey: @"categories"];
        modified = YES;
      }
            
      if (modified) {
        [defaults setPersistentDomain: mdom forName: @"MDKQuery"];
        [defaults synchronize];
        RELEASE (mdom);
      }
    }
    
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

+ (void)updateUserAttributes:(NSArray *)userattrs
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  NSMutableDictionary *domain;
  
  [defaults synchronize];
  domain = [[defaults persistentDomainForName: @"MDKQuery"] mutableCopy];
  [domain setObject: userattrs forKey: @"user-attributes"];
  [defaults setPersistentDomain: domain forName: @"MDKQuery"];
  [defaults synchronize];
  
  RELEASE (domain);
}

+ (NSString *)attributeDescription:(NSString *)attrname
{
  NSDictionary *dict = [attrInfo objectForKey: attrname];
  
  if (dict) {
    return [dict objectForKey: @"description"];
  }
  
  return nil;
}

+ (NSDictionary *)attributeWithName:(NSString *)attrname
{
  return [attrInfo objectForKey: attrname];
}

+ (NSDictionary *)attributesWithMask:(MDKAttributeMask)mask
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  NSDictionary *domain = [defaults persistentDomainForName: @"MDKQuery"];
  NSArray *userSet = [domain objectForKey: @"user-attributes"];
  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
  NSUInteger i;

  for (i = 0; i < [attrNames count]; i++) {
    NSString *attrname = [attrNames objectAtIndex: i];
    NSDictionary *attrdict = [attrInfo objectForKey: attrname];
    BOOL insert = YES;

#define CHECK_MASK(m, condition) \
  if (insert && (mask & m)) insert = condition

    CHECK_MASK(MDKAttributeSearchable, [[attrdict objectForKey: @"searchable"] boolValue]);
    CHECK_MASK(MDKAttributeFSType, [[attrdict objectForKey: @"fsattribute"] boolValue]);
    CHECK_MASK(MDKAttributeUserSet, [userSet containsObject: attrname]);
    CHECK_MASK(MDKAttributeBaseSet, [basesetAttributes() containsObject: attrname]);
  
    if (insert && ([attributes objectForKey: attrname] == nil)) {
      [attributes setObject: attrdict forKey: attrname];
    }
  }
  
  return attributes;
}

+ (NSArray *)categoryNames
{
  NSDictionary *dict = [self categoryInfo];  
  
  if (dict) {
    return [dict keysSortedByValueUsingSelector: @selector(compareAccordingToIndex:)];
  }
  
  return nil;
}

+ (NSDictionary *)categoryInfo
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  NSDictionary *domain;
  
  [defaults synchronize];
  domain = [defaults persistentDomainForName: @"MDKQuery"];
  
  return [domain objectForKey: @"categories"];
}

+ (void)updateCategoryInfo:(NSDictionary *)info
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  NSMutableDictionary *domain;
  
  [defaults synchronize];
  domain = [[defaults persistentDomainForName: @"MDKQuery"] mutableCopy];
  [domain setObject: info forKey: @"categories"];
  [defaults setPersistentDomain: domain forName: @"MDKQuery"];
  [defaults synchronize];
  
  RELEASE (domain);
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

+ (MDKQuery *)queryWithContentsOfFile:(NSString *)path
{
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: path];
  
  if (dict) {
    id descr = [dict objectForKey: @"description"];
    id paths = [dict objectForKey: @"searchpaths"];
    
    if (descr && [descr isKindOfClass: [NSString class]]) {
      return [self queryFromString: descr inDirectories: paths];
    }
  }
  
  return nil;
}

- (id)init
{
  self = [super init];
  
  if (self) {
    unsigned long memaddr = (unsigned long)self;
    unsigned long num;
      
    attribute = nil;
    searchValue = nil;
   
    caseSensitive = NO;
    operatorType = MDKEqualToOperatorType;
    operator = nil;
    searchPaths = nil;     
    
    ASSIGN (srcTable, @"paths");
    qmanager = [MDKQueryManager queryManager];
    num = [qmanager tableNumber] + memaddr;
    ASSIGN (destTable, ([NSString stringWithFormat: @"tab_%lu", num]));
    
    num = [qmanager queryNumber] + memaddr;     
    ASSIGN (queryNumber, [NSNumber numberWithUnsignedLong: num]);
    joinTable = nil;
            
    subqueries = [NSMutableArray new];    
    parentQuery = nil;     
    compoundOperator = MDKCompoundOperatorNone;

    sqlDescription = [NSMutableDictionary new]; 
    [sqlDescription setObject: [NSMutableArray array] forKey: @"pre"];
    [sqlDescription setObject: [NSString string] forKey: @"join"];
    [sqlDescription setObject: [NSMutableArray array] forKey: @"post"];
    [sqlDescription setObject: queryNumber forKey: @"qnumber"];

    sqlUpdatesDescription = [NSMutableDictionary new]; 
    [sqlUpdatesDescription setObject: [NSMutableArray array] forKey: @"pre"];
    [sqlUpdatesDescription setObject: [NSString string] forKey: @"join"];
    [sqlUpdatesDescription setObject: [NSMutableArray array] forKey: @"post"];
    [sqlUpdatesDescription setObject: queryNumber forKey: @"qnumber"];
    
    categoryNames = nil;
    fsfilters = nil;    
    reportRawResults = NO;
    status = 0;    
    delegate = nil;
  }
  
  return self;
}

- (id)initForAttribute:(NSString *)attr
           searchValue:(NSString *)value
          operatorType:(MDKOperatorType)optype           
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL)writeToFile:(NSString *)path 
         atomically:(BOOL)flag
{
  if ([self isRoot] == NO) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not the root query.", [self description]];       
  
  } else if ([self isBuilt] == NO) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not built.", [self description]];       
  
  } else {
    CREATE_AUTORELEASE_POOL(arp);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    BOOL written;
    
    [dict setObject: [self description] forKey: @"description"];
    if (searchPaths && [searchPaths count]) {
      [dict setObject: searchPaths forKey: @"searchpaths"];
    }
    written = [dict writeToFile: path atomically: flag];

    RELEASE (arp);
      
    return written;
  }
  
  return NO;
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
  NSUInteger i;
  
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

- (void)setCompoundOperator:(MDKCompoundOperator)op
{
  compoundOperator = op;
}

- (MDKCompoundOperator)compoundOperator
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

- (MDKQuery *)parentQuery
{
  return parentQuery;
}

- (MDKQuery *)leftSibling
{
  MDKQuery *sibling = nil;

  if (parentQuery) {
    NSArray *subs = [parentQuery subqueries];
    NSUInteger index = [subs indexOfObject: self];
    
    if (index > 0) {
      sibling = [subs objectAtIndex: index - 1];
    }
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"query not in tree"];     
  }
  
  return sibling;
}

- (BOOL)hasParentWithCompound:(MDKCompoundOperator)op
{
  Class c = [MDKQuery class];
  MDKQuery *query = self;
  
  while (query != nil) {
    query = [query parentQuery];
  
    if (query && [query isMemberOfClass: c]) {
      MDKCompoundOperator qop = [query compoundOperator];
      
      if (qop == op) {
        break;
      } else if (qop != MDKCompoundOperatorNone) {
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

- (MDKQuery *)appendSubqueryWithCompoundOperator:(MDKCompoundOperator)op
{
  if ([self isClosed] == NO) {
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
      compoundOperator:(MDKCompoundOperator)op
{
  if ([self isClosed] == NO) {
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

- (void)appendSubqueryWithCompoundOperator:(MDKCompoundOperator)op
                                 attribute:(NSString *)attr
                               searchValue:(NSString *)value
                              operatorType:(MDKOperatorType)optype        
                             caseSensitive:(BOOL)csens
{
  if ([self isClosed] == NO) {
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
  if ([self isClosed] == NO) {
    if (parentQuery) {
      [parentQuery setDestTable: destTable];
    }
    status |= SUBCLOSED;
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"trying to close a closed query."];     
  }
}

- (BOOL)isClosed
{
  return ((status & SUBCLOSED) == SUBCLOSED);
}

- (NSArray *)subqueries
{
  return subqueries;
}

- (BOOL)buildQuery
{
  if ([self isClosed]) {
    NSUInteger i;
    
    status |= BUILT;
    
    for (i = 0; i < [subqueries count]; i++) {
      if ([[subqueries objectAtIndex: i] buildQuery] == NO) {
        status &= ~BUILT;
        break;
      }
    }

    if ([self isBuilt] && [self isRoot]) {
      ASSIGN (groupedResults, [NSMutableDictionary dictionary]);
      ASSIGN (categoryNames, [MDKQuery categoryNames]);
      
      for (i = 0; i < [categoryNames count]; i++) {
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: 
                                      [NSMutableArray array], @"nodes",
                                      [NSMutableArray array], @"scores", nil];
                                      
        [groupedResults setObject: dict
                           forKey: [categoryNames objectAtIndex: i]];
      }
    }

    return [self isBuilt];
  
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"trying to build an unclosed query."];     
  }
  
  return NO;
}

- (BOOL)isBuilt
{
  return ((status & BUILT) == BUILT);
}

- (void)setFSFilters:(NSArray *)filters
{
  ASSIGN (fsfilters, filters);
}

- (NSArray *)fsfilters
{
  return fsfilters;
}

- (void)appendSQLToPreStatements:(NSString *)sqlstr
                   checkExisting:(BOOL)check
{
  if ([self isRoot]) {
    CREATE_AUTORELEASE_POOL(arp);
    NSMutableString *sqlUpdatesStr = [sqlstr mutableCopy];
    NSMutableArray *sqlpre = [sqlDescription objectForKey: @"pre"];  

    if ((check == NO) || ([sqlpre containsObject: sqlstr] == NO)) {
      [sqlpre addObject: sqlstr];
    }

    [sqlUpdatesStr replaceOccurrencesOfString: @"paths" 
                        withString: @"updated_paths" 
                           options: NSLiteralSearch
                             range: NSMakeRange(0, [sqlUpdatesStr length])];
    
    sqlpre = [sqlUpdatesDescription objectForKey: @"pre"];

    if ((check == NO) || ([sqlpre containsObject: sqlUpdatesStr] == NO)) {
      [sqlpre addObject: sqlUpdatesStr];
    }

    RELEASE (sqlUpdatesStr);
    RELEASE (arp);
    
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not the root query.", [self description]];     
  }
}

- (void)appendSQLToPostStatements:(NSString *)sqlstr
                    checkExisting:(BOOL)check
{
  if ([self isRoot]) {
    CREATE_AUTORELEASE_POOL(arp);
    NSMutableString *sqlUpdatesStr = [sqlstr mutableCopy];    
    NSMutableArray *sqlpost = [sqlDescription objectForKey: @"post"];  

    if ((check == NO) || ([sqlpost containsObject: sqlstr] == NO)) {
      [sqlpost addObject: sqlstr];
    }

    [sqlUpdatesStr replaceOccurrencesOfString: @"paths" 
                        withString: @"updated_paths" 
                           options: NSLiteralSearch
                             range: NSMakeRange(0, [sqlUpdatesStr length])];

    sqlpost = [sqlUpdatesDescription objectForKey: @"post"];

    if ((check == NO) || ([sqlpost containsObject: sqlUpdatesStr] == NO)) {
      [sqlpost addObject: sqlUpdatesStr];
    }

    RELEASE (sqlUpdatesStr);
    RELEASE (arp);

  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not the root query.", [self description]];     
  }
}

- (NSString *)description
{
  NSMutableString *descr = [NSMutableString string];
  NSUInteger i;
  
  if ([self isRoot] == NO) {
    [descr appendString: @"("];
  }
  
  for (i = 0; i < [subqueries count]; i++) {
    MDKQuery *query = [subqueries objectAtIndex: i];
    MDKCompoundOperator op = [query compoundOperator];
    
    switch (op) {
      case GMDAndCompoundOperator:
        [descr appendString: @" && "];
        break;
      case GMDOrCompoundOperator:
        [descr appendString: @" || "];
        break;
      case MDKCompoundOperatorNone:
      default:
        [descr appendString: @" "];
        break;
    }
  
    [descr appendString: [[subqueries objectAtIndex: i] description]];
  }
  
  if ([self isRoot] == NO) {
    [descr appendString: @" )"];
  }
  
  return descr;
}

@end


@implementation MDKAttributeQuery

- (void)dealloc
{  
	[super dealloc];
}

- (id)initForAttribute:(NSString *)attr
           searchValue:(NSString *)value
          operatorType:(MDKOperatorType)optype
{
  self = [super init];
  
  if (self) {
    ASSIGN (attribute, attr);
    ASSIGN (searchValue, stringForQuery(value));
    operatorType = optype;
    status |= SUBCLOSED;
    
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
        case DATE_TYPE:
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
    if ((operatorType != MDKEqualToOperatorType) 
              && (operatorType != MDKNotEqualToOperatorType)) {
      return NO;
    }
  
  } else if (attrtype == ARRAY) {
    int elemtype = [[attrinfo objectForKey: @"elements_type"] intValue];
  
    if ((elemtype == STRING) || (elemtype == DATA)) {
      if ((operatorType != MDKEqualToOperatorType) 
              && (operatorType != MDKNotEqualToOperatorType)) {
        return NO;
      }
    } else {
      return NO;
    }
  
  } else if (attrtype == NUMBER) {
    int numtype = [[attrinfo objectForKey: @"number_type"] intValue];

    if (numtype == NUM_BOOL) {
      if ((operatorType != MDKEqualToOperatorType) 
              && (operatorType != MDKNotEqualToOperatorType)) {
        return NO;
      }
    }

  } else if (attrtype == DATE_TYPE) {
    if ([searchValue floatValue] == 0.0) {
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
    case MDKLessThanOperatorType:
      ASSIGN (operator, @"<");
      break;

    case MDKLessThanOrEqualToOperatorType:
      ASSIGN (operator, @"<=");
      break;

    case MDKGreaterThanOperatorType:
      ASSIGN (operator, @">");
      break;

    case MDKGreaterThanOrEqualToOperatorType:
      ASSIGN (operator, @">=");
      break;

    case MDKNotEqualToOperatorType:
      ASSIGN (operator, @"!=");
      break;

    case MDKInRangeOperatorType:
      /* FIXME */
      break;
    
    case MDKEqualToOperatorType:   
    default:
      ASSIGN (operator, @"==");
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

  if (operatorType == MDKEqualToOperatorType) {
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

- (MDKQuery *)appendSubqueryWithCompoundOperator:(MDKCompoundOperator)op
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKAttributeQuery instance."];     
  return nil;
}

- (void)appendSubquery:(id)query
      compoundOperator:(MDKCompoundOperator)op
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKAttributeQuery instance."];     
}

- (void)appendSubqueryWithCompoundOperator:(MDKCompoundOperator)op
                                 attribute:(NSString *)attr
                               searchValue:(NSString *)value
                              operatorType:(MDKOperatorType)optype        
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
                                   @"score REAL); ", destTable];
  
  [root appendSQLToPreStatements: sqlstr checkExisting: YES];

  sqlstr = [NSString stringWithFormat: @"CREATE TEMP TRIGGER %@_trigger "
               @"BEFORE INSERT ON %@ "
               @"BEGIN "
               @"UPDATE %@ "
               @"SET score = (score + new.score) "
               @"WHERE id = new.id; "
               @"END;", destTable, destTable, destTable];

  [root appendSQLToPreStatements: sqlstr checkExisting: YES];

  sqlstr = [NSMutableString string];
          
  [sqlstr appendFormat: @"INSERT INTO %@ (id, path, words_count, score) "
      @"SELECT "
      @"%@.id, "
      @"%@.path, "
      @"%@.words_count, "
      @"attributeScore('%@', '%@', attributes.attribute, %i, %i) "
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
  
  } else if (attributeType == DATE_TYPE) {
    [sqlstr appendFormat: @"(cast (%@ as REAL)) ", searchValue];
  
  } else {
    return NO;
  }
        
  [sqlstr appendFormat: @"AND attributes.path_id = %@.id ", srcTable];      

  if (searchPaths) {
    NSUInteger count = [searchPaths count];
    NSUInteger i;

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

    [joinquery appendFormat: @"INSERT INTO %@ (id, path, words_count, score) "
                             @"SELECT "
                             @"%@.id, "
                             @"%@.path, "
                             @"%@.words_count, "
                             @"%@.score "
                             @"FROM "
                             @"%@, %@ "
                             @"WHERE "
                             @"%@.id = %@.id; ",
                             destTable, srcTable, srcTable, 
                             srcTable, srcTable, srcTable, 
                             destTable, srcTable, destTable];
    
    [root appendSQLToPreStatements: joinquery checkExisting: NO];
  }

  [root appendSQLToPostStatements: [NSString stringWithFormat: @"DROP TABLE %@", destTable] 
                    checkExisting: YES];
  
  [parentQuery setJoinTable: destTable];
  
  status |= BUILT;
  
  return [self isBuilt];
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
    case MDKLessThanOperatorType:
      [descr appendString: @" < "];
      break;
    case MDKLessThanOrEqualToOperatorType:
      [descr appendString: @" <= "];
      break;
    case MDKGreaterThanOperatorType:
      [descr appendString: @" > "];
      break;
    case MDKGreaterThanOrEqualToOperatorType:
      [descr appendString: @" >= "];
      break;
    case MDKEqualToOperatorType:
      [descr appendString: @" == "];
      break;
    case MDKNotEqualToOperatorType:
      [descr appendString: @" != "];
      break;
    case MDKInRangeOperatorType:
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
          operatorType:(MDKOperatorType)optype
{
  self = [super init];
  
  if (self) {
    if ((optype != MDKEqualToOperatorType) 
                        && (optype != MDKNotEqualToOperatorType)) {
      DESTROY (self);
      return self;
    }
        
    ASSIGN (attribute, attr);
    attributeType = STRING;
    ASSIGN (searchValue, stringForQuery(value));
    operatorType = optype;
    
    [self setTextOperatorForCaseSensitive: YES];    
    
    status |= SUBCLOSED;
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

- (MDKQuery *)appendSubqueryWithCompoundOperator:(MDKCompoundOperator)op
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKTextContentQuery instance."];     
  return nil;
}

- (void)appendSubquery:(id)query
      compoundOperator:(MDKCompoundOperator)op
{
  [NSException raise: NSInternalInconsistencyException
		          format: @"Cannot append to a MDKTextContentQuery instance."];     
}

- (void)appendSubqueryWithCompoundOperator:(MDKCompoundOperator)op
                                 attribute:(NSString *)attr
                               searchValue:(NSString *)value
                              operatorType:(MDKOperatorType)optype        
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
                                   @"score REAL); ", destTable];
  
  [root appendSQLToPreStatements: sqlstr checkExisting: YES];
  
  sqlstr = [NSString stringWithFormat: @"CREATE TEMP TRIGGER %@_trigger "
               @"BEFORE INSERT ON %@ "
               @"BEGIN "
               @"UPDATE %@ "
               @"SET score = (score + new.score) "
               @"WHERE id = new.id; "
               @"END;", destTable, destTable, destTable];

  [root appendSQLToPreStatements: sqlstr checkExisting: YES];

  sqlstr = [NSMutableString string];

  if (operatorType == MDKEqualToOperatorType) {
    [sqlstr appendFormat: @"INSERT INTO %@ (id, path, words_count, score) "
        @"SELECT "
        @"%@.id, "
        @"%@.path, "
        @"%@.words_count, "
        @"wordScore('%@', words.word, postings.word_count, %@.words_count) "
        @"FROM words, %@, postings ",        
        destTable, srcTable, srcTable, srcTable, 
        searchValue, srcTable, srcTable];

    [sqlstr appendFormat: @"WHERE words.word %@ '", operator];
    [sqlstr appendString: searchValue];
    [sqlstr appendString: @"' "];

    [sqlstr appendFormat: @"AND postings.word_id = words.id "
                         @"AND %@.id = postings.path_id ", srcTable];

  } else {  /* MDKNotEqualToOperatorType */
    [sqlstr appendFormat: @"INSERT INTO %@ (id, path, words_count, score) "
        @"SELECT "
        @"%@.id AS tid, "
        @"%@.path, "
        @"%@.words_count, "
        @"(1.0 / %@.words_count) "        
        @"FROM %@ ",
        destTable, srcTable, srcTable, srcTable, 
        srcTable, srcTable];

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

    [joinquery appendFormat: @"INSERT INTO %@ (id, path, words_count, score) "
                             @"SELECT "
                             @"%@.id, "
                             @"%@.path, "
                             @"%@.words_count, "
                             @"%@.score "
                             @"FROM "
                             @"%@, %@ "
                             @"WHERE "
                             @"%@.id = %@.id; ",
                             destTable, srcTable, srcTable, 
                             srcTable, srcTable, srcTable, 
                             destTable, srcTable, destTable];

    [root appendSQLToPreStatements: joinquery checkExisting: NO];
  }

  [root appendSQLToPostStatements: [NSString stringWithFormat: @"DROP TABLE %@", destTable] 
                    checkExisting: YES];
  
  [parentQuery setJoinTable: destTable];
  
  status |= BUILT;
  
  return [self isBuilt];
}

- (NSString *)description
{
  NSMutableString *descr = [NSMutableString string];
  NSMutableString *mvalue = [[searchValue mutableCopy] autorelease];
  
  [descr appendString: attribute];
  
  if (operatorType == MDKEqualToOperatorType) {
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


@implementation MDKQuery (gathering)

- (void)setDelegate:(id)adelegate
{
  if ([self isRoot]) {
    delegate = adelegate;
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"only the root query can have a delegate."];     
  }
}

- (NSDictionary *)sqlDescription
{
  if ([self isRoot]) {
    NSString *jtable = [self joinTable];
    NSString *joinquery = [NSString stringWithFormat: @"SELECT %@.path, "
                                          @"%@.score "
                                          @"FROM %@ "
                                          @"ORDER BY "
                                          @"%@.score DESC, "
                                          @"%@.path ASC;",
                                          jtable, jtable, jtable, 
                                          jtable, jtable];
  
    [sqlDescription setObject: joinquery forKey: @"join"];
    
    return sqlDescription;
  
  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not the root query.", [self description]];     
  }
  
  return nil;
}

- (NSDictionary *)sqlUpdatesDescription
{
  if ([self isRoot]) {
    [sqlUpdatesDescription setObject: [[self sqlDescription] objectForKey: @"join"]
                              forKey: @"join"];

    return sqlUpdatesDescription;

  } else {
    [NSException raise: NSInternalInconsistencyException
		            format: @"%@ is not the root query.", [self description]];       
  }
  
  return nil;
}

- (NSNumber *)queryNumber
{
  return queryNumber;  
}

- (void)startGathering
{
  if (([self isGathering] == NO) && ([self waitingStart] == NO)) {
    status &= ~STOPPED;
    status |= WAITSTART;
    [qmanager startQuery: self];
  }
}

- (void)setStarted
{
  status &= ~WAITSTART;
  status |= GATHERING;
  
  if (CHECKDELEGATE (queryDidStartGathering:)) {  
    [delegate queryDidStartGathering: self];
  }    
}

- (BOOL)waitingStart
{
  return ((status & WAITSTART) == WAITSTART);
}

- (BOOL)isGathering
{
  return ((status & GATHERING) == GATHERING);
}

- (void)gatheringDone
{
  if ([self isStopped]) {
    status &= ~(GATHERING | UPDATING);
  } else {
    status &= ~GATHERING;
  }
  
  if (CHECKDELEGATE (queryDidEndGathering:)) {
    [delegate queryDidEndGathering: self];
  }  
  
  if ([self updatesEnabled] && ([self isUpdating] == NO) && ([self isStopped] == NO)) {
    status |= UPDATING;
    [qmanager startUpdateForQuery: self];
  }  
}

- (void)stopQuery
{
  status |= STOPPED;
  status &= ~WAITSTART;
}

- (BOOL)isStopped
{
  return ((status & STOPPED) == STOPPED);
}

- (void)setUpdatesEnabled:(BOOL)enabled
{
  if (enabled) {
    status |= UPDATE_ENABLE;
  } else {
    status &= ~(UPDATE_ENABLE | UPDATING);
  }
}

- (BOOL)updatesEnabled
{
  return ((status & UPDATE_ENABLE) == UPDATE_ENABLE);
}

- (BOOL)isUpdating
{
  return ((status & UPDATING) == UPDATING);
}

- (void)updatingStarted
{
  if (CHECKDELEGATE (queryDidStartUpdating:)) {
    [delegate queryDidStartUpdating: self];
  }  
}

- (void)updatingDone
{
  if (CHECKDELEGATE (queryDidEndUpdating:)) {    
    [delegate queryDidEndUpdating: self];
  }  
}

- (void)appendResults:(NSArray *)lines
{
  if (reportRawResults) {
    if (CHECKDELEGATE (appendRawResults:)) {
      [delegate appendRawResults: lines];
    }
  } else {
    CREATE_AUTORELEASE_POOL(arp);
    NSMutableArray *catnames = [NSMutableArray array];
    BOOL sort = [self isUpdating];
    unsigned i;  
  
    for (i = 0; i < [lines count]; i++) {
      NSArray *line = [lines objectAtIndex: i];
      FSNode *node = [FSNode nodeWithPath: [line objectAtIndex: 0]];
      NSNumber *score = [line objectAtIndex: 1];
      
      if (node && [node isValid]) {
        BOOL caninsert = YES;
        
        if (fsfilters && [fsfilters count]) {
          caninsert = [qmanager filterNode: node withFSFilters: fsfilters];
        }
      
        if (caninsert) {
          NSString *category = [qmanager categoryNameForNode: node];

          [self insertNode: node 
                  andScore: score 
              inDictionary: [groupedResults objectForKey: category] 
               needSorting: sort];

          if ([catnames containsObject: category] == NO) {
            [catnames addObject: category];
          }
        }
      }
    }
  
    if (CHECKDELEGATE (queryDidUpdateResults:forCategories:)) {      
      [delegate queryDidUpdateResults: self forCategories: catnames];
    }
    
    RELEASE (arp);
  }
}

- (void)insertNode:(FSNode *)node
          andScore:(NSNumber *)score
      inDictionary:(NSDictionary *)dict
       needSorting:(BOOL)sort
{
  NSMutableArray *nodes = [dict objectForKey: @"nodes"];
  NSMutableArray *scores = [dict objectForKey: @"scores"];
  
  if ([self isUpdating]) {
    NSUInteger index = [nodes indexOfObject: node];
  
    if (index != NSNotFound) {
      [nodes removeObjectAtIndex: index];
      [scores removeObjectAtIndex: index];
    }
  }
  
  if (sort) {
    NSUInteger count = [nodes count];    
    NSUInteger ins = 0;

    if (count) {
      NSUInteger first = 0;
      NSUInteger last = count;
      NSUInteger pos = 0; 
      NSComparisonResult result;

      while (1) {
        if (first == last) {
          ins = first;
          break;
        }

        pos = (NSUInteger)((first + last) / 2);

        result = [(NSNumber *)[scores objectAtIndex: pos] compare: score];

        if (result == NSOrderedSame) {
          result = [[nodes objectAtIndex: pos] compareAccordingToPath: node];
        }

        if ((result == NSOrderedDescending) || (result == NSOrderedSame)) {
          first = pos + 1;
        } else {
          last = pos;	
        }
      } 
    }

    [nodes insertObject: node atIndex: ins];
    [scores insertObject: score atIndex: ins];
  
  } else {
    [nodes addObject: node];
    [scores addObject: score];
  }
}

- (void)removePaths:(NSArray *)paths
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableArray *catnames = [NSMutableArray array];
  NSUInteger index;    
  NSUInteger i;
  
  index = NSNotFound;
  for (i = 0; i < [paths count]; i++) {
    FSNode *node = [FSNode nodeWithPath: [paths objectAtIndex: i]];
    NSString *catname;
    NSDictionary *catdict;
    NSMutableArray *catnodes;
    NSMutableArray *catscores;

    catname = nil;
    catscores = nil;
    catnodes = nil;
            
    if ([node isValid]) {
      catname = [qmanager categoryNameForNode: node];
      catdict = [groupedResults objectForKey: catname];        
      catnodes = [catdict objectForKey: @"nodes"];
      catscores = [catdict objectForKey: @"scores"];

      index = [catnodes indexOfObject: node];

    } else {
      NSUInteger j;

      for (j = 0; j < [categoryNames count]; j++) {
        catname = [categoryNames objectAtIndex: j];
        catdict = [groupedResults objectForKey: catname];
        catnodes = [catdict objectForKey: @"nodes"];
        catscores = [catdict objectForKey: @"scores"];

        index = [catnodes indexOfObject: node];

        if (index != NSNotFound)
          break;
      }              
    }

    if (index != NSNotFound) {
      [catnodes removeObjectAtIndex: index];
      [catscores removeObjectAtIndex: index]; 
      if (catname && [catnames containsObject: catname] == NO) {
        [catnames addObject: catname];     
      }
    }
  }
  
  if ((index != NSNotFound) && CHECKDELEGATE (queryDidUpdateResults:forCategories:)) {        
    [delegate queryDidUpdateResults: self forCategories: catnames];
  }
  
  RELEASE (arp);
}

- (void)removeNode:(FSNode *)node
{  
  NSString *catname;
  NSDictionary *catdict;
  NSMutableArray *catnodes;
  NSMutableArray *catscores;
  NSUInteger index;

  index = NSNotFound;
  if ([node isValid])
    {
      catname = [qmanager categoryNameForNode: node];
      catdict = [groupedResults objectForKey: catname];        
      catnodes = [catdict objectForKey: @"nodes"];
      catscores = [catdict objectForKey: @"scores"];

      index = [catnodes indexOfObject: node];
    }
  else
    {
      NSUInteger i;

      for (i = 0; i < [categoryNames count]; i++)
        {
          catname = [categoryNames objectAtIndex: i];
          catdict = [groupedResults objectForKey: catname];
          catnodes = [catdict objectForKey: @"nodes"];
          catscores = [catdict objectForKey: @"scores"];

          index = [catnodes indexOfObject: node];

          if (index != NSNotFound)
            break;
        }              
    }

  if (index != NSNotFound)
    {
      [catnodes removeObjectAtIndex: index];
      [catscores removeObjectAtIndex: index];      

      if (CHECKDELEGATE (queryDidUpdateResults:forCategories:))
        {        
          [delegate queryDidUpdateResults: self 
                            forCategories: [NSArray arrayWithObject: catname]];
        }      
    }  
}

- (NSDictionary *)groupedResults
{
  return groupedResults;
}

- (NSArray *)resultNodesForCategory:(NSString *)catname
{
  NSDictionary *catdict = [groupedResults objectForKey: catname];

  if (catdict) {
    return [catdict objectForKey: @"nodes"];
  }
  
  return nil;
}

- (int)resultsCountForCategory:(NSString *)catname
{
  NSArray *catdnodes = [self resultNodesForCategory: catname];
  return (catdnodes ? [catdnodes count] : 0);
}

- (void)setReportRawResults:(BOOL)value
{
  reportRawResults = value;
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
  MDKCompoundOperator op = MDKCompoundOperatorNone;
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
  
  if (op != MDKCompoundOperatorNone) {
    PARSEXCEPT ((parsed & COMPOUND), @"double compound operator");
    PARSEXCEPT ((parsed & SUBOPEN), @"compound operator without arguments");
    parsed &= ~(SUBOPEN | SUBCLOSE | COMPARISION);
    parsed |= COMPOUND;
  }

  if ([self scanString: @"(" intoString: NULL]) {
    PARSEXCEPT ((!(((parsed & SUBOPEN) == SUBOPEN) 
                      || ((parsed & COMPOUND) == COMPOUND)
                  || ((parsed == 0) && (currentQuery == rootQuery)))), 
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
  MDKOperatorType optype;
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
  optype = 0;
  if ([self scanString: @"<" intoString: NULL]) {
    optype = MDKLessThanOperatorType;
    CHK_ATTR_TYPE (@"<");
  } else if ([self scanString: @"<=" intoString: NULL]) {
    optype = MDKLessThanOrEqualToOperatorType;
    CHK_ATTR_TYPE (@"<=");
  } else if ([self scanString: @">" intoString: NULL]) {
    optype = MDKGreaterThanOperatorType;
    CHK_ATTR_TYPE (@">");
  } else if ([self scanString: @">=" intoString: NULL]) {
    optype = MDKGreaterThanOrEqualToOperatorType;
    CHK_ATTR_TYPE (@">=");
  } else if ([self scanString: @"==" intoString: NULL]) {
    optype = MDKEqualToOperatorType;
  } else if ([self scanString: @"!=" intoString: NULL]) {
    optype = MDKNotEqualToOperatorType;
  } else if ([self scanString: @"---------------------" intoString: NULL]) {
    /* TODO TODO TODO TODO TODO TODO TODO */
    optype = MDKInRangeOperatorType;
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
  NSUInteger loc = [self scanLocation];
  
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


@implementation NSDictionary (CategorySort)

- (NSComparisonResult)compareAccordingToIndex:(NSDictionary *)dict
{
  NSNumber *p1 = [self objectForKey: @"index"];
  NSNumber *p2 = [dict objectForKey: @"index"];
  return [p1 compare: p2];
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

BOOL subPathOfPath(NSString *p1, NSString *p2)
{
  NSUInteger l1 = [p1 length];
  NSUInteger l2 = [p2 length];  

  if ((l1 > l2) || ([p1 isEqual: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqual: p1]) {
    if ([[p2 pathComponents] containsObject: [p1 lastPathComponent]]) {
      return YES;
    }
  }

  return NO;
}
