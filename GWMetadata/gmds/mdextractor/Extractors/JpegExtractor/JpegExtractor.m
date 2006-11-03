/* JpegExtractor.m
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
#include "JpegExtractor.h"
#include "jhead.h"

@implementation JpegExtractor

- (void)dealloc
{
  RELEASE (extensions);
	[super dealloc];
}

- (id)initForExtractor:(id)extr
{
  self = [super init];
  
  if (self) {
    ASSIGN (extensions, ([NSArray arrayWithObjects: @"jpeg", @"jpg", nil]));  
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
  return (testdata && [testdata length] && [extensions containsObject: ext]);
}

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary *mddict = [NSMutableDictionary dictionary];
  NSMutableDictionary *imageInfo = [NSMutableDictionary dictionary];
  BOOL success = YES;
  
  ResetJpgfile();

  if (ReadJpegFile([path UTF8String], imageInfo)) {
 //   [imageInfo setObject: @"public.jpeg" forKey: @"GSMDItemContentType"];
    [mddict setObject: imageInfo forKey: @"attributes"];
    DiscardData();

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

    success = [extractor setMetadata: mddict forPath: path withID: path_id];
  }
  
  RELEASE (arp);
  
  return success;
}

@end








