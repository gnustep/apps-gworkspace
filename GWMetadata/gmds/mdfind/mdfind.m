/* mdfind.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: October 2006
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

#include <Foundation/Foundation.h>
#include "MDKQuery.h"

@interface MDFind : NSObject
{ 
  MDKQuery *query;
  unsigned rescount;
  NSString *searchdir;
  BOOL repscore;
  BOOL onlycount;
}

- (id)initWithArguments:(NSArray *)args;

- (void)queryDidStartGathering:(MDKQuery *)query;

- (void)appendRawResults:(NSArray *)lines;

- (void)queryDidEndGathering:(MDKQuery *)query;

- (void)printAttributesList;

- (void)printAttributeDescription:(NSString *)attribute;

- (void)printHelp;

@end


@implementation MDFind

- (id)initWithArguments:(NSArray *)args
{
  self = [super init];

  if (self) {
    unsigned count = [args count];
    unsigned pos = 1;
    BOOL runquery = YES;
    unsigned i;
    
    if (count <= 1) {
      GSPrintf(stderr, @"mdfind: too few arguments supplied!\n");
      [self printHelp];
      return self;
    }

    searchdir = nil;
    repscore = NO;
    onlycount = NO;
    rescount = 0;
    
    for (i = 1; i < count; i++) {
      NSString *arg = [args objectAtIndex: i];
  
      if ([arg isEqual: @"-h"]) {
        [self printHelp];
        runquery = NO;

      } else if ([arg isEqual: @"-a"]) {
        if ((i + 1) < count) {
          [self printAttributeDescription: [args objectAtIndex: (i + 1)]];
        } else {
          [self printAttributesList];
        }
        runquery = NO;

      } else if ([arg isEqual: @"-s"]) {
        repscore = YES; 
        pos++;

      } else if ([arg isEqual: @"-c"]) {
        onlycount = YES; 
        pos++;

      } else if ([arg isEqual: @"-onlyin"]) {
        BOOL pathok = YES;

        if (i++ < count) {
          arg = [args objectAtIndex: i];

          if ([[NSFileManager defaultManager] fileExistsAtPath: arg]) {
            ASSIGN (searchdir, arg);
            pos += 2;
          } else {
            pathok = NO;
          }
        } else {
          pathok = NO;
        }

        if (pathok == NO) {
          GSPrintf(stderr, @"mdfind: no search path or invalid path supplied!\n");
          runquery = NO;
        }
      }   
    }
  
    if ((pos < count) && runquery) {
      NSArray *queryargs = [args subarrayWithRange: NSMakeRange(pos, count - pos)];
      NSString *qstr = [queryargs componentsJoinedByString: @" "];

	    NS_DURING
	      {
      NSArray *dirs = (searchdir ? [NSArray arrayWithObject: searchdir] : nil);  
      
      ASSIGN (query, [MDKQuery queryFromString: qstr inDirectories: dirs]);            
      [query setDelegate: self];
      [query setReportRawResults: YES];
      [query startGathering];
        }
	    NS_HANDLER
	      {
      GSPrintf(stderr, @"mdfind: %@\n", localException);
      exit(EXIT_FAILURE);
	      }
	    NS_ENDHANDLER
    }  
  }
  
  return self;
}

- (void)queryDidStartGathering:(MDKQuery *)query
{

}

- (void)appendRawResults:(NSArray *)lines
{
  if (onlycount == NO) {
    unsigned i;

    for (i = 0; i < [lines count]; i++) {
      NSArray *line = [lines objectAtIndex: i];
      NSString *path = [line objectAtIndex: 0];

      GSPrintf(stdout, @"%@", path);
      
      if (repscore) {
        GSPrintf(stdout, @" %@", [[line objectAtIndex: 1] description]);
      }
      
      GSPrintf(stdout, @"\n");
    }

  } else {
    rescount += [lines count];
  }
}

- (void)queryDidEndGathering:(MDKQuery *)query
{
  if (onlycount) {
    GSPrintf(stdout, @"%i\n", rescount);
  }
    
  exit(EXIT_SUCCESS);
}

- (void)printAttributesList
{
  NSArray *attributes = [MDKQuery attributesNames];
  unsigned i;
  
  for (i = 0; i < [attributes count]; i++) {
    GSPrintf(stderr, @"%@\n", [attributes objectAtIndex: i]);
  }
}

- (void)printAttributeDescription:(NSString *)attribute
{
  NSString *description = [MDKQuery attributeDescription: attribute];

  if (description) {
    GSPrintf(stderr, @"%@\n", description);
  } else {
    GSPrintf(stderr, @"%@: invalid attribute name!\n", attribute);
  }
}

- (void)printHelp
{
  GSPrintf(stderr,
      @"\n"
      @"The 'mdfind' tool finds files matching a given query\n"
      @"\n"
      @"usage: mdfind [arguments] query\n"
      @"\n"
      @"Arguments:\n"
      @"  -onlyin 'directory'    limits the the search to 'directory'.\n"
      @"  -s                     reports also the score for each found path.\n"
      @"  -c                     reports only the count of the found paths.\n"
      @"  -a [attribute]         if 'attribute' is supplied, prints the attribute\n"
      @"                         description, else prints the attributes list.\n"
      @"  -h                     shows this help and exit.\n"
      @"\n"
      @"The query have the format: attribute  operator  value\n"
      @"where 'attribute' is one of the attributes used by the mdextractor\n"
      @"tool when indexing (type 'mdfind -a' for the attribute list),\n"
      @"and 'operator' is one of the following:\n"
      @"  ==   equal\n"
      @"  !=   not equal\n"
      @"  <    less than (only for numeric values and dates)\n"
      @"  <=   less than or equal (only for numeric values and dates)\n"
      @"  >    greater than (only for numeric values and dates)\n"
      @"  >=   greater than or equal (only for numeric values and dates)\n"
      @"\n"
      @"Value comparison modifiers for string values:\n"
      @"Appending the 'c' character to the search value (ex. \"value\"c),\n"
      @"makes the query case insensitive.\n"      
      @"You can use the '*' wildcard to match substrings anywhere in the\n"
      @"search value.\n"
      @"\n"
      @"Combining queries:\n"
      @"Queries can be combined using '&&' for AND and '||' for OR and\n"
      @"parenthesis to define nesting criteria.\n"
      @"\n"
  );
}

@end


int main(int argc, char **argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo *proc;
  MDFind *mdfind;
  
#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments: argv count: argc environment: env];
#endif

  pool = [NSAutoreleasePool new];
  proc = [NSProcessInfo processInfo];
  
  if (proc == nil) {
    GSPrintf(stderr, @"mdfind: unable to get process information!\n");
    RELEASE (pool);
    exit(EXIT_FAILURE);
  }

  mdfind = [[MDFind alloc] initWithArguments: [proc arguments]];
  
  RELEASE (pool);

  if (mdfind != nil) {
	  CREATE_AUTORELEASE_POOL (pool);
    [[NSRunLoop currentRunLoop] run];
  	RELEASE (pool);
  }
  
  exit(EXIT_SUCCESS);
}


