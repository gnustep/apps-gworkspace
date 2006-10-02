/* PdfExtractor.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: June 2006
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
#include <PDFKit/PDFDocument.h>
#include "PdfExtractor.h"

#define MAXFSIZE 600000
#define DLENGTH 256
#define WORD_MAX 40

@implementation PdfExtractor

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
  
    ASSIGN (extensions, ([NSArray arrayWithObject: @"pdf"]));  
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
  }
  
  return NO;
}

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *mddict = [NSMutableDictionary dictionary];  
  PDFDocument *doc = [PDFDocument documentFromFile: path];  
  BOOL success = NO;
  
  if (doc && [doc isOk] && ([doc errorCode] == 0)) {
    NSString *contents = [doc getAllText];
    NSDictionary *info = [doc getDocumentInfo];

    if (contents && [contents length]) {
      NSScanner *scanner = [NSScanner scannerWithString: contents];
      SEL scanSel = @selector(scanUpToCharactersFromSet:intoString:);
      IMP scanImp = [scanner methodForSelector: scanSel];
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
      RELEASE (wordset);
      [wordsDict setObject: [NSNumber numberWithUnsignedLong: wcount] 
                    forKey: @"wcount"];

      [mddict setObject: wordsDict forKey: @"words"];
    }
    
    if (info) {
      NSMutableDictionary *attrsdict = [NSMutableDictionary dictionary];
      id entry;
    
      entry = [info objectForKey: @"Title"];    
      if (entry) {
        [attrsdict setObject: entry forKey: @"GSMDItemTitle"];
      }

  //    entry = [info objectForKey: @"Subject"];    
  //    if (entry) {
  //      [attrsdict setObject: entry forKey: @"GSMDItemTitle"];
  //    }
    
      entry = [info objectForKey: @"Keywords"];    
      if (entry) {
        NSArray *words = [entry componentsSeparatedByString: @", "];
      
        [attrsdict setObject: [words description]
                      forKey: @"GSMDItemKeywords"];
      }
    
      entry = [info objectForKey: @"Author"];    
      if (entry) {
        [attrsdict setObject: [[NSArray arrayWithObject: entry] description] 
                      forKey: @"GSMDItemAuthors"];
      }
    
      entry = [info objectForKey: @"Creator"];    
      if (entry) {
        [attrsdict setObject: entry forKey: @"GSMDItemCreator"];
      }

      entry = [info objectForKey: @"Producer"];    
      if (entry) {
        [attrsdict setObject: [[NSArray arrayWithObject: entry] description] 
                      forKey: @"GSMDItemEncodingApplications"];
      }
    
      [mddict setObject: attrsdict forKey: @"attributes"];
    }
  }
  
  success = [extractor setMetadata: mddict forPath: path withID: path_id];  
  
  RELEASE (arp);
    
  return success;
}

@end


