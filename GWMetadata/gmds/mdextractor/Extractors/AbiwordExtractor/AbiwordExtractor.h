/* AbiwordExtractor.h
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

#ifndef ABIWORD_EXTRACTOR_H
#define ABIWORD_EXTRACTOR_H

#include <Foundation/Foundation.h>
#include <GNUstepBase/GSXML.h>

@protocol	GMDSExtractorProtocol

- (BOOL)setMetadata:(NSDictionary *)mddict
            forPath:(NSString *)path
             withID:(int)path_id;

@end


@protocol	ExtractorsProtocol

- (id)initForExtractor:(id)extr;

- (NSArray *)pathExtensions;

- (BOOL)canExtractFromFileType:(NSString *)type
                 withExtension:(NSString *)ext
                    attributes:(NSDictionary *)attributes
                      testData:(NSData *)testdata;

- (BOOL)extractMetadataAtPath:(NSString *)path
                       withID:(int)path_id
                   attributes:(NSDictionary *)attributes;

@end


@interface AbiwordExtractor: NSObject <ExtractorsProtocol>
{
  NSArray *extensions;
  GSXMLDocument *stylesheet;  
  NSMutableCharacterSet *skipSet;  
  id extractor;
  
  NSFileManager *fm;
}

- (NSDictionary *)getDocumentAttributes:(GSXMLDocument *)document;

@end

#endif // ABIWORD_EXTRACTOR_H
