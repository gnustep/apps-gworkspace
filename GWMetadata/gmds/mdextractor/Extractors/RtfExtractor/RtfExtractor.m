/* RtfExtractor.m
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <AppKit/AppKit.h>
#include "RtfExtractor.h"

#define MAXFSIZE 600000
#define WORD_MAX 40

@implementation RtfExtractor

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
    ASSIGN (extensions, ([NSArray arrayWithObjects: @"rtf", @"rtfd", nil]));

    skipSet = [NSMutableCharacterSet new];    
    [skipSet formUnionWithCharacterSet: [NSCharacterSet controlCharacterSet]];
    [skipSet formUnionWithCharacterSet: [NSCharacterSet illegalCharacterSet]];
    [skipSet formUnionWithCharacterSet: [NSCharacterSet punctuationCharacterSet]];
    [skipSet formUnionWithCharacterSet: [NSCharacterSet symbolCharacterSet]];
    [skipSet formUnionWithCharacterSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [skipSet formUnionWithCharacterSet: [NSCharacterSet decimalDigitCharacterSet]];
    [skipSet formUnionWithCharacterSet: [NSCharacterSet characterSetWithCharactersInString: @"+-=<>&@$*%#\"\'^`|~_/\\"]];
  
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
    return ([extensions containsObject: ext]);  
  } else if ([attributes fileType] == NSFileTypeDirectory) {
    return ([ext isEqual: @"rtfd"]); 
  }
  
  return NO;
}

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *mddict = [NSMutableDictionary dictionary];  
  NSString *ext = [[path pathExtension] lowercaseString]; 
  NSAttributedString *attrstr = nil;
  NSString *contents = nil;
  BOOL success = NO;
  
  NS_DURING
    {
  if ([ext isEqual: @"rtf"]) {
    NSData *data = [NSData dataWithContentsOfFile: path];

    attrstr = [[NSAttributedString alloc] initWithRTF: data
						                       documentAttributes: NULL];

  } else if ([ext isEqual: @"rtfd"]) {
    if ([attributes fileType] == NSFileTypeRegular) {
      NSData *data = [NSData dataWithContentsOfFile: path];

      attrstr = [[NSAttributedString alloc] initWithRTF: data
						                         documentAttributes: NULL];

    } else if ([attributes fileType] == NSFileTypeDirectory) {
      NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithPath: path];

      attrstr = [[NSAttributedString alloc] initWithRTFDFileWrapper: wrapper
                                                 documentAttributes: NULL];
      RELEASE (wrapper);
    }
  }
    }
  NS_HANDLER
    {
  RELEASE (arp);
  return NO;
    }
  NS_ENDHANDLER
 
  if (attrstr == nil) {
    RELEASE (arp);
    return NO;
  } 
 
  contents = [attrstr string]; 

  if (contents && [contents length]) {
    NSScanner *scanner = [NSScanner scannerWithString: contents];
    SEL scanSel = @selector(scanUpToCharactersFromSet:intoString:);
    IMP scanImp = [scanner methodForSelector: scanSel];
    NSMutableDictionary *wordsDict = [NSMutableDictionary dictionary];
    NSCountedSet *wordset = [[[NSCountedSet alloc] initWithCapacity: 1] autorelease];
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
  }
              
  success = [extractor setMetadata: mddict forPath: path withID: path_id];  
  
  RELEASE (arp);
    
  return success;
}

@end
