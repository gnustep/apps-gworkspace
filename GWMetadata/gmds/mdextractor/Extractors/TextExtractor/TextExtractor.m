/* TextExtractor.m
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

#include <AppKit/AppKit.h>
#include "TextExtractor.h"

#define MAXFSIZE 600000
#define DLENGTH 256
#define WORD_MAX 40

@implementation TextExtractor

- (void)dealloc
{
  RELEASE (extensions);
  RELEASE (skipSet);
	[super dealloc];
}

- (id)initForExtractor:(id)extr
{
  self = [super init];
  
  if (self) {
    NSCharacterSet *set;

    skipSet = [NSMutableCharacterSet new];
    
    set = [NSCharacterSet controlCharacterSet];
    [skipSet formUnionWithCharacterSet: set];
    
    set = [NSCharacterSet illegalCharacterSet];
    [skipSet formUnionWithCharacterSet: set];
    
    set = [NSCharacterSet punctuationCharacterSet];
    [skipSet formUnionWithCharacterSet: set];

    set = [NSCharacterSet symbolCharacterSet];
    [skipSet formUnionWithCharacterSet: set];

    set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    [skipSet formUnionWithCharacterSet: set];
    
    set = [NSCharacterSet decimalDigitCharacterSet];
    [skipSet formUnionWithCharacterSet: set];

    set = [NSCharacterSet characterSetWithCharactersInString: @"+-=<>&@$*%#\"\'^`|~_/\\"];
    [skipSet formUnionWithCharacterSet: set];  
  
    ASSIGN (extensions, [NSArray arrayWithObject: @"txt"]);  
  
    extractor = extr;
  }

  return self;
}

- (NSArray *)pathExtensions
{
  return extensions;
}

- (BOOL)canExtractFromFileType:(NSString *)type
                 withExtension:(NSString *)ext
                    attributes:(NSDictionary *)attributes
                      testData:(NSData *)testdata
{
  if (testdata && ([attributes fileSize] < MAXFSIZE)) {
    const char *bytes = (const char *)[testdata bytes];
    int i;

    for (i = 0; i < [testdata length]; i++) {
      if (bytes[i] == 0x00) {
        return NO; 
        break;
      } 
    }

    return YES;  
  }
  
  return NO;
}

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *contents = [NSString stringWithContentsOfFile: path];
  BOOL success = YES;
  
  if (contents && [contents length]) {
    NSScanner *scanner = [NSScanner scannerWithString: contents];
    SEL scanSel = @selector(scanUpToCharactersFromSet:intoString:);
    IMP scanImp = [scanner methodForSelector: scanSel];
    NSMutableDictionary *mddict = [NSMutableDictionary dictionary];
    NSMutableDictionary *wordsDict = [NSMutableDictionary dictionary];
    NSCountedSet *wordset = [[NSCountedSet alloc] initWithCapacity: 1];
    unsigned long wcount = 0;
    NSString *word;
    
    [scanner setCharactersToBeSkipped: skipSet];
        
    while ([scanner isAtEnd] == NO) {        
      (*scanImp)(scanner, scanSel, skipSet, &word);

      if (word) {
        unsigned wl = [word length];

        if ((wl > 3) && (wl < WORD_MAX)) { 
          [wordset addObject: word];
        }

        wcount++;
      }
    }
    
    [wordsDict setObject: wordset forKey: @"wset"];
    [wordsDict setObject: [NSNumber numberWithUnsignedLong: wcount] 
                  forKey: @"wcount"];

    [mddict setObject: wordsDict forKey: @"words"];
    
    success = [extractor setMetadata: mddict forPath: path withID: path_id];
    
    RELEASE (wordset);   
  }

  RELEASE (arp);
  
  return success;
}

@end








