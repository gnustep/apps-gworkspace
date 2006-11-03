/* AppExtractor.m
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
#include "AppExtractor.h"

#define MAXFSIZE 600000
#define WORD_MAX 40

@implementation AppExtractor

- (void)dealloc
{
  RELEASE (extensions);

	[super dealloc];
}

- (id)initForExtractor:(id)extr
{
  self = [super init];
  
  if (self) { 
    ASSIGN (extensions, ([NSArray arrayWithObjects: @"app", nil]));
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
  if ([attributes fileType] == NSFileTypeDirectory) {
    return (type == NSApplicationFileType); 
  }
  
  return NO;
}

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *mddict = [NSMutableDictionary dictionary]; 
  NSMutableDictionary *attrsdict = [NSMutableDictionary dictionary]; 
  NSBundle *bundle = [NSBundle bundleWithPath: path];
  NSDictionary *info = [bundle infoDictionary]; 
  BOOL success = NO;
  
  if (info) {
    id entry = [info objectForKey: @"NSTypes"];
    
    if (entry && [entry isKindOfClass: [NSArray class]]) {
      NSMutableArray *unixexts = [NSMutableArray array];
      unsigned i;
    
      for (i = 0; i < [entry count]; i++) {
        id dict = [entry objectAtIndex: i];
        id exts;
        
        if ([dict isKindOfClass: [NSDictionary class]] == NO) {
					continue;
				}
      
        exts = [dict objectForKey: @"NSUnixExtensions"];
        
        if ([exts isKindOfClass: [NSArray class]]) {
          [unixexts addObjectsFromArray: exts];
				}
      }
      
      if ([unixexts count]) {
        [attrsdict setObject: unixexts forKey: @"GSMDItemUnixExtensions"];
      }
    }
    
    entry = [info objectForKey: @"Authors"];
    
    if (entry && [entry isKindOfClass: [NSArray class]]) {
      [attrsdict setObject: entry forKey: @"GSMDItemAuthors"];    
    }

    entry = [info objectForKey: @"Copyright"];

    if (entry && [entry isKindOfClass: [NSString class]]) {
      [attrsdict setObject: entry forKey: @"GSMDItemCopyright"];    
    }

    entry = [info objectForKey: @"CopyrightDescription"];

    if (entry && [entry isKindOfClass: [NSString class]]) {
      [attrsdict setObject: entry forKey: @"GSMDItemCopyrightDescription"];    
    }

    entry = [info objectForKey: @"NSRole"];

    if (entry && [entry isKindOfClass: [NSString class]]) {
      [attrsdict setObject: entry forKey: @"GSMDItemRole"];    
    }

    entry = [info objectForKey: @"NSBuildVersion"];

    if (entry && [entry isKindOfClass: [NSString class]]) {
      [attrsdict setObject: entry forKey: @"GSMDItemBuildVersion"];    
    }

    entry = [info objectForKey: @"ApplicationName"];

    if (entry && [entry isKindOfClass: [NSString class]]) {
      [attrsdict setObject: entry forKey: @"GSMDItemApplicationName"];    
    }

    entry = [info objectForKey: @"ApplicationDescription"];

    if (entry && [entry isKindOfClass: [NSString class]]) {
      [attrsdict setObject: entry forKey: @"GSMDItemApplicationDescription"];    
    }
    
    entry = [info objectForKey: @"ApplicationRelease"];

    if (entry && [entry isKindOfClass: [NSString class]]) {
      [attrsdict setObject: entry forKey: @"GSMDItemApplicationRelease"];    
    }
         
    [mddict setObject: attrsdict forKey: @"attributes"];
    
    {
      /* mdextractor needs this empty "words" dictionary to let 
         a trigger to fire when updating a path. (see dbschema.h) */
      NSMutableDictionary *wordsDict = [NSMutableDictionary dictionary];
      NSCountedSet *wordset = [[[NSCountedSet alloc] initWithCapacity: 1] autorelease];

      [wordsDict setObject: wordset forKey: @"wset"];
      [wordsDict setObject: [NSNumber numberWithUnsignedLong: 0L] 
                    forKey: @"wcount"];
    
      [mddict setObject: wordsDict forKey: @"words"];
    }
  }  
              
  success = [extractor setMetadata: mddict forPath: path withID: path_id];  
  RELEASE (arp);
    
  return success;
}

@end



