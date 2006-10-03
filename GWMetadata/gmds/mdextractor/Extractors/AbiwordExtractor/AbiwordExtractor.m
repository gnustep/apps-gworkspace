/* AbiwordExtractor.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: July 2006
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
#include "AbiwordExtractor.h"

#define MAXFSIZE 600000
#define WORD_MAX 40

static char *style = "<xsl:stylesheet "
                      "xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\" "
                      "version=\"1.0\"> "
                      "<xsl:output method=\"text\"/> "
                      "</xsl:stylesheet>";


@implementation AbiwordExtractor

- (void)dealloc
{
  RELEASE (extensions);
  RELEASE (skipSet);
  RELEASE (stylesheet);

	[super dealloc];
}

- (id)initForExtractor:(id)extr
{
  self = [super init];
  
  if (self) {    
    NSData *data = [NSData dataWithBytes: style length: strlen(style)];
    GSXMLParser *parser = [GSXMLParser parserWithData: data];

    [parser parse];
    ASSIGN (stylesheet, [parser document]);
    
    fm = [NSFileManager defaultManager];
    
    ASSIGN (extensions, ([NSArray arrayWithObjects: @"abw", nil]));

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
  }
  
  return NO;
}

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *mddict = [NSMutableDictionary dictionary];  
  GSXMLParser *parser = [GSXMLParser parserWithContentsOfFile: path];
  GSXMLDocument *doc = nil;
  NSString *contents = nil;
  NSDictionary *attrsdict = nil;
  BOOL success = NO;
  
  if (parser && [parser parse]) { 
    doc = [parser document];
    
    attrsdict = [self getDocumentAttributes: doc];
  
    if (attrsdict && [attrsdict count]) {
      [mddict setObject: attrsdict forKey: @"attributes"];
    }
    
    doc = [doc xsltTransform: stylesheet];
    
    contents = [doc description];

    if (contents && [contents length]) {
      NSScanner *scanner = [NSScanner scannerWithString: contents];
      SEL scanSel = @selector(scanUpToCharactersFromSet:intoString:);
      IMP scanImp = [scanner methodForSelector: scanSel];
      NSMutableDictionary *wordsDict = [NSMutableDictionary dictionary];
      NSCountedSet *wordset = [[NSCountedSet alloc] initWithCapacity: 1];
      unsigned long wcount = 0;
      NSString *word;

      if ([scanner scanString: @"<?xml" intoString: NULL]) {
        if ([scanner scanUpToString: @"?>" intoString: NULL]) {
          [scanner scanString: @"?>" intoString: NULL];
        }
      }

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
  }
            
  success = [extractor setMetadata: mddict forPath: path withID: path_id];  
  
  RELEASE (arp);
    
  return success;
}

- (NSDictionary *)getDocumentAttributes:(GSXMLDocument *)document
{
  GSXMLNode *node = [document root]; 
  NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

  while (node != nil) {
    NSString *name = [node name];
  
    if (name && [name isEqual: @"metadata"]) {    
      node = [node firstChildElement];

      while (node != nil) {        
        NSString *attrname = [[node attributes] objectForKey: @"key"];
        NSString *ndcont = [node content];
        
        if ([attrname isEqual: @"abiword.generator"]) {
          [attributes setObject: [[NSArray arrayWithObject: ndcont] description] 
                         forKey: @"GSMDItemEncodingApplications"];
        
        } else if ([attrname isEqual: @"dc.description"]) {
          [attributes setObject: ndcont forKey: @"GSMDItemDescription"];

        } else if ([attrname isEqual: @"abiword.keywords"]) {
          NSArray *words = [ndcont componentsSeparatedByString: @" "];
      
          [attributes setObject: [words description]
                          forKey: @"GSMDItemKeywords"];

        } else if ([attrname isEqual: @"dc.contributor"]) {
          NSArray *contrs = [ndcont componentsSeparatedByString: @" "];
      
          [attributes setObject: [contrs description]
                         forKey: @"GSMDItemContributors"];

        } else if ([attrname isEqual: @"dc.subject"]) {


        } else if ([attrname isEqual: @"dc.creator"]) {
          [attributes setObject: ndcont forKey: @"GSMDItemCreator"];

        } else if ([attrname isEqual: @"dc.type"]) {


        } else if ([attrname isEqual: @"dc.language"]) {
          NSArray *langs = [ndcont componentsSeparatedByString: @" "];
      
          [attributes setObject: [langs description]
                         forKey: @"GSMDItemLanguages"];

        } else if ([attrname isEqual: @"dc.format"]) {
       //   [attributes setObject: ndcont forKey: @"GSMDItemContentType"];

        } else if ([attrname isEqual: @"dc.title"]) {
          [attributes setObject: ndcont forKey: @"GSMDItemTitle"];

        } else if ([attrname isEqual: @"dc.publisher"]) {
          [attributes setObject: [[NSArray arrayWithObject: ndcont] description] 
                         forKey: @"GSMDItemPublishers"];
        }        

        node = [node nextElement];
      }
      
      break;
    }
    
    node = [node firstChildElement];
  }
  
  return attributes;
}

@end


