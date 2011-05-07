/* OpenOfficeExtractor.m
 *  
 * Copyright (C) 2006-2011 Free Software Foundation, Inc.
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

#import <AppKit/AppKit.h>
#import "OpenOfficeExtractor.h"
#import "extractors.h"

#define MAXFSIZE 600000
#define WORD_MAX 40

static char *style = "<xsl:stylesheet "
                      "xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\" "
                      "version=\"1.0\"> "
                      "<xsl:output method=\"text\"/> "
                      "</xsl:stylesheet>";


@implementation OpenOfficeExtractor

- (void)dealloc
{
  RELEASE (extensions);
  RELEASE (skipSet);
  RELEASE (tempdir);
  RELEASE (unzcomm);
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

    tempdir = NSTemporaryDirectory();
    tempdir = [tempdir stringByAppendingPathComponent: @"ooextractor"];
    RETAIN (tempdir);
    
    if ([fm fileExistsAtPath: tempdir]) {
      [fm removeFileAtPath: tempdir handler: nil];
    }
    
    ASSIGN (unzcomm, [NSString stringWithUTF8String: UNZIP_PATH]);
    
    ASSIGN (extensions, ([NSArray arrayWithObjects: @"sxw", @"odt", @"odp", 
                                                    @"sxi", @"ods", @"sxc", 
                                                    @"odg", @"sxd", nil]));

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
  NSDictionary *unzpaths = nil;
  NSString *unzpath = nil;
  GSXMLParser *parser = nil;
  BOOL success = NO;
  
  unzpaths = [self unzippedPathsForPath: path];
  
  if (unzpaths == nil) {
    RELEASE (arp);
    return NO;
  }

  unzpath = [unzpaths objectForKey: @"content"];

  if (unzpath) {
    parser = [GSXMLParser parserWithContentsOfFile: unzpath];
  }

  if (parser && [parser parse]) { 
    GSXMLDocument *doc = [[parser document] xsltTransform: stylesheet]; 
    NSString *contents;

    if (doc == nil) {
      RELEASE (arp);
      return NO;
    }
    
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

  unzpath = [unzpaths objectForKey: @"meta"];
      
  if (unzpath) {
    parser = [GSXMLParser parserWithContentsOfFile: unzpath];
  } else {
    parser = nil;
  }
      
  if (parser && [parser parse]) {
    GSXMLDocument *doc = [parser document];
    
    if (doc) {
      GSXMLNode *node = [doc root]; 
      NSDictionary *dict = [self getAttributes: nil fromNode: node];
      NSMutableDictionary *attrsdict = [NSMutableDictionary dictionary];
      id entry;
    
      entry = [dict objectForKey: @"title"];    
      if (entry) {
        [attrsdict setObject: entry forKey: @"GSMDItemTitle"];
      }
    
      entry = [dict objectForKey: @"keyword"];    
      if (entry) {
        NSArray *words = [entry componentsSeparatedByString: @", "];
      
        [attrsdict setObject: [words description]
                      forKey: @"GSMDItemKeywords"];
      }
  
      entry = [dict objectForKey: @"creator"];    
      if (entry) {
        [attrsdict setObject: entry forKey: @"GSMDItemCreator"];
      }
        
      entry = [dict objectForKey: @"generator"];    
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

- (NSDictionary *)unzippedPathsForPath:(NSString *)path
{
  NSMutableDictionary *paths = nil;
  NSTask *task = nil;
  NSFileHandle *nullHandle;

  [fm removeFileAtPath: tempdir handler: nil]; 
 
  if ([fm createDirectoryAtPath: tempdir attributes: nil] == NO) {
    return nil;
  }
  
  NS_DURING
    {
      task = [NSTask new];
      
      [task setCurrentDirectoryPath: tempdir];
      [task setLaunchPath: unzcomm]; 
      [task setArguments: [NSArray arrayWithObject: path]];
      nullHandle = [NSFileHandle fileHandleWithNullDevice];
      [task setStandardOutput: nullHandle];
      [task setStandardError: nullHandle];

      [task launch];
    }
  NS_HANDLER
    {
      DESTROY (task);
    }
  NS_ENDHANDLER  
   
  if (task) {
    [task waitUntilExit];
    
    if ([task terminationStatus] == 0) { 
      NSString *contspath = [tempdir stringByAppendingPathComponent: @"content.xml"];
      NSString *metapath = [tempdir stringByAppendingPathComponent: @"meta.xml"];
        
      paths = [NSMutableDictionary dictionary];  
      
      if ([fm fileExistsAtPath: contspath]) {
        [paths setObject: contspath forKey: @"content"];
      }
      if ([fm fileExistsAtPath: metapath]) {
        [paths setObject: metapath forKey: @"meta"];
      }
    }
    
    RELEASE (task);
  } 
  
  if (paths && [paths count]) {
    return paths;
  }
  
  return nil;
}

- (NSDictionary *)getAttributes:(NSMutableDictionary *)attributes
                       fromNode:(GSXMLNode *)node
{
  if (attributes == nil) {
    attributes = [NSMutableDictionary dictionary];
  }  

  while (node != nil) {
    NSDictionary *ndattrs = [node attributes];
    GSXMLNode *child;

    if (ndattrs && [ndattrs count]) {
      [attributes addEntriesFromDictionary: ndattrs];
    } else {
      NSString *name = [node name];
      NSString *content = [node content];
      
      if (name && [name length] && content && [content length]) {
        [attributes setObject: content forKey: name];
      }
    }
    
    child = [node firstChildElement];
    
    if (child != nil) {
      [attributes addEntriesFromDictionary: [self getAttributes: attributes fromNode: child]];
    }
  
    node = [node nextElement];
  }
  
  return attributes;
}

@end


