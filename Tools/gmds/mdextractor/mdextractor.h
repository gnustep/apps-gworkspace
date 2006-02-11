/* mdextractor.h
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef MDEXTRACTOR_H
#define MDEXTRACTOR_H

#include <Foundation/Foundation.h>
#include "sqlite.h"

@protocol	ExtractorsProtocol

- (id)initForExtractor:(id)extr;

- (NSString *)fileType;

- (NSArray *)pathExtensions;

- (BOOL)canExtractFromFileType:(NSString *)type
                 withExtension:(NSString *)ext
                    attributes:(NSDictionary *)attributes
                      testData:(NSData *)testdata;

- (void)extractMetadataAtPath:(NSString *)path
               withAttributes:(NSDictionary *)attributes
                 usingStemmer:(id)stemmer
                    stopWords:(NSSet *)stopwords;

@end


@protocol	StemmerProtocol

- (BOOL)setLanguage:(NSString *)lang;

- (NSString *)language;

- (NSArray *)stopWords;

- (NSString *)stemWord:(NSString *)word;

@end


@protocol	GMDSProtocol

- (oneway void)registerExtractor:(id)extractor;

- (oneway void)extractorDidEndTask:(id)extractor;

@end


@interface GMDSExtractor: NSObject 
{
  NSString *extractPath;
  BOOL recursive;
  NSString *dbpath;
  sqlite3 *db;

	NSMutableArray *extractors;
  id textExtractor;
	id stemmer;
  NSSet *stopWords;
  
  id gmds;
  NSFileManager *fm;
  id ws;
  NSNotificationCenter *nc; 
}

- (id)initForPath:(NSString *)apath
        recursive:(BOOL)rec
           dbPath:(NSString *)dbp
     gmdsConnName:(NSString *)cname;

- (void)terminate;

- (NSString *)extractPath;

- (void)connectionDidDie:(NSNotification *)notification;

- (void)startExtracting;

- (void)setMetadata:(NSDictionary *)mddict
            forPath:(NSString *)path
     withAttributes:(NSDictionary *)attributes;

- (void)setFileSystemMetadataForPath:(NSString *)path
                      withAttributes:(NSDictionary *)attributes;

- (id)extractorForPath:(NSString *)path
        withAttributes:(NSDictionary *)attributes;

- (void)loadExtractors;

- (void)setStemmingLanguage:(NSString *)language;

- (void)loadStemmer;

@end

#endif // MDEXTRACTOR_H
