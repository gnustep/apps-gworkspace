/* mdextractor.m
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "mdextractor.h"
#include "config.h"

#define DLENGTH 256

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

#define PERFORM_OR_EXIT(d, q) \
do { \
  if (performWriteQuery(d, q) == NO) { \
    NSLog(@"error at: %@", q); \
    exit(EXIT_FAILURE); \
  } \
} while (0)


@implementation	GMDSExtractor

- (void)dealloc
{
  [nc removeObserver: self];
  DESTROY (gmds);
  RELEASE (extractPath);
  RELEASE (dbpath);
  RELEASE (extractors);  
  RELEASE (textExtractor);
  RELEASE (stemmer);  
  TEST_RELEASE (stopWords);
  
  [super dealloc];
}

- (id)initForPath:(NSString *)apath
        recursive:(BOOL)rec
           dbPath:(NSString *)dbp
     gmdsConnName:(NSString *)cname
{
  self = [super init];
  
  if (self) {
    NSConnection *conn;
    id anObject;
    
    ASSIGN (extractPath, apath);
    recursive = rec;
    ASSIGN (dbpath, dbp);
    
    fm = [NSFileManager defaultManager]; 
    ws = [NSWorkspace sharedWorkspace];   
    nc = [NSNotificationCenter defaultCenter];

    textExtractor = nil;        
    [self loadExtractors];
    
    [self loadStemmer];
    [self setStemmingLanguage: nil];
    
    db = opendbAtPath(dbpath);

    if (db != NULL) {
      performWriteQuery(db, @"PRAGMA cache_size = 20000");
      performWriteQuery(db, @"PRAGMA count_changes = 0");
      performWriteQuery(db, @"PRAGMA synchronous = OFF");
      performWriteQuery(db, @"PRAGMA temp_store = MEMORY");
    } else {
      NSLog(@"unable to open the database at %@", dbpath);
      exit(0);
    }

    conn = [NSConnection connectionWithRegisteredName: cname host: @""];
    
    if (conn == nil) {
      NSLog(@"failed to contact gmds - bye.");
	    exit(1);           
    } 

    [nc addObserver: self
           selector: @selector(connectionDidDie:)
               name: NSConnectionDidDieNotification
             object: conn];    
    
    anObject = [conn rootProxy];
    [anObject setProtocolForProxy: @protocol(GMDSProtocol)];
    gmds = (id <GMDSProtocol>)anObject;
    RETAIN (gmds);

    [gmds registerExtractor: self];
  }
  
  return self;
}

- (void)terminate
{
  [nc removeObserver: self];
  DESTROY (gmds);
  GWDebugLog(@"exiting");
  exit(0);
}

- (NSString *)extractPath
{
  return extractPath;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  id conn = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: conn];

  NSLog(@"gmds connection has been destroyed. Exiting.");
  
  exit(0);
}

- (void)startExtracting
{
  NSDictionary *attributes = [fm fileAttributesAtPath: extractPath traverseLink: NO];
  id extractor = nil;
  NSDate *start = [NSDate date];
  unsigned long fcount = 0;  

  if (attributes) {
    [self setFileSystemMetadataForPath: extractPath 
                        withAttributes: attributes];

    extractor = [self extractorForPath: extractPath 
                        withAttributes: attributes];

    if (extractor) {
      [extractor extractMetadataAtPath: extractPath
                        withAttributes: attributes
                          usingStemmer: stemmer
                             stopWords: stopWords];
    }
        
    fcount++;    

    if (([attributes fileType] == NSFileTypeDirectory) && recursive) {
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: extractPath];

      while (1) {
        CREATE_AUTORELEASE_POOL(arp);  
        NSString *entry = [enumerator nextObject];

        if (entry) {
          NSString *subpath = [extractPath stringByAppendingPathComponent: entry];

          attributes = [fm fileAttributesAtPath: subpath traverseLink: NO];

          if (attributes) {
            [self setFileSystemMetadataForPath: subpath 
                                withAttributes: attributes];
          
            extractor = [self extractorForPath: subpath 
                                withAttributes: attributes];

            if (extractor) {
              [extractor extractMetadataAtPath: subpath
                                withAttributes: attributes
                                  usingStemmer: stemmer
                                     stopWords: stopWords];
            }
                      
            fcount++;    
          }

        } else {
          RELEASE (arp);
          break;
        } 

        RELEASE (arp);       
      }
    }
  }
  
  NSLog(@"%f seconds", [[NSDate date] timeIntervalSinceDate: start]);
  NSLog(@"%d files", fcount);

  [gmds extractorDidEndTask: self];
}

- (void)setMetadata:(NSDictionary *)mddict
            forPath:(NSString *)path
     withAttributes:(NSDictionary *)attributes
{
  NSDictionary *wordsdict;
  NSDictionary *attrsdict;
  NSString *query;
  int path_id;
  
  NSLog(path);
  
  PERFORM_OR_EXIT (db, @"BEGIN");
  
  query = [NSString stringWithFormat: 
             @"SELECT id FROM paths WHERE path = '%@'", stringForQuery(path)];
  path_id = getIntEntry(db, query);

  query = [NSString stringWithFormat:
                      @"DELETE FROM postings WHERE path_id = %i", path_id];
  PERFORM_OR_EXIT (db, query);
  
  wordsdict = [mddict objectForKey: @"words"];

  if (wordsdict) {
    NSCountedSet *wordset = [wordsdict objectForKey: @"wset"];
    NSEnumerator *enumerator = [wordset objectEnumerator];  
    unsigned wcount = [[wordsdict objectForKey: @"wcount"] unsignedLongValue];
    NSString *word;

    query = [NSString stringWithFormat:
                  @"UPDATE paths SET words_count = %i WHERE id = %i", 
                                                              wcount, path_id];
    PERFORM_OR_EXIT (db, query);

    while ((word = [enumerator nextObject])) {
      unsigned count = [wordset countForObject: word];
      int word_id;

      query = [NSString stringWithFormat: 
                      @"SELECT id FROM words WHERE word = '%@'",
                                                  stringForQuery(word)];
      word_id = getIntEntry(db, query);

      if (word_id == -1) {
        query = [NSString stringWithFormat:
             @"INSERT INTO words (word) VALUES('%@')", stringForQuery(word)];
        PERFORM_OR_EXIT (db, query);

        word_id = sqlite3_last_insert_rowid(db);
      }
            
      query = [NSString stringWithFormat:
          @"INSERT INTO postings (word_id, path_id, score) VALUES(%i, %i, %f)", 
                    word_id, path_id, (1.0 * count / wcount)];
      PERFORM_OR_EXIT (db, query);
    }
  }

  attrsdict = [mddict objectForKey: @"attributes"];

  if (attrsdict) {
    NSArray *keys = [attrsdict allKeys];
    unsigned i;

    for (i = 0; i < [keys count]; i++) {
      NSString *key = [keys objectAtIndex: i];
      id mdvalue = [attrsdict objectForKey: key];
      NSString *attributeStr;

      if ([mdvalue isKindOfClass: [NSString class]]) {
        attributeStr = [NSString stringWithFormat: @"'%@'", mdvalue];

      } else if ([mdvalue isKindOfClass: [NSArray class]]) {
        attributeStr = [NSString stringWithFormat: @"'%@'", [mdvalue description]];      
      
      } else if ([mdvalue isKindOfClass: [NSNumber class]]) {
        attributeStr = [NSString stringWithFormat: @"%@", [mdvalue description]];      
      
      } else if ([mdvalue isKindOfClass: [NSData class]]) {
        attributeStr = [NSString stringWithFormat: @"%@", blobFromData(mdvalue)];      
      }
     
      query = [NSString stringWithFormat:
        @"INSERT INTO attributes (path_id, key, attribute) VALUES(%i, '%@', %@)", 
                                                  path_id, key, attributeStr];
      PERFORM_OR_EXIT (db, query);
    }
  }

  PERFORM_OR_EXIT (db, @"COMMIT");
}

- (void)setFileSystemMetadataForPath:(NSString *)path
                      withAttributes:(NSDictionary *)attributes
{
  NSDate *moddate = [attributes fileModificationDate];
  NSTimeInterval interval = [moddate timeIntervalSinceReferenceDate];
  NSString *query;
  int path_id;
    
  PERFORM_OR_EXIT (db, @"BEGIN");

  query = [NSString stringWithFormat: 
                    @"SELECT id FROM paths WHERE path = '%@'",
                                              stringForQuery(path)];
  path_id = getIntEntry(db, query);
    
  if (path_id == -1) { 
    query = [NSString stringWithFormat:
        @"INSERT INTO paths (path, words_count, moddate) VALUES('%@', 0, %f)", 
                                                 stringForQuery(path), interval];
    PERFORM_OR_EXIT (db, query);
  
    path_id = sqlite3_last_insert_rowid(db);
  
  } else {
    query = [NSString stringWithFormat:
        @"UPDATE paths SET words_count = 0, moddate = %f WHERE id = %i",
                                                          interval, path_id];
    PERFORM_OR_EXIT (db, query);
  }


  query = [NSString stringWithFormat:
                      @"DELETE FROM attributes WHERE path_id = %i", path_id];
  PERFORM_OR_EXIT (db, query);



  query = [NSString stringWithFormat:
    @"INSERT INTO attributes (path_id, key, attribute) VALUES(%i, '%@', %f)", 
                            path_id, @"kMDItemFSContentChangeDate", interval];
  PERFORM_OR_EXIT (db, query);

  interval = [[attributes fileCreationDate] timeIntervalSinceReferenceDate];

  query = [NSString stringWithFormat:
    @"INSERT INTO attributes (path_id, key, attribute) VALUES(%i, '%@', %f)", 
                                path_id, @"kMDItemFSCreationDate", interval];
  PERFORM_OR_EXIT (db, query);

  // kMDItemFSInvisible
  // kMDItemFSIsExtensionHidden
  // kMDItemFSLabel
  // kMDItemFSName  

  if ([attributes fileType] == NSFileTypeDirectory) {  
    NSArray *contents = [fm directoryContentsAtPath: path];
    
    if (contents) {
      query = [NSString stringWithFormat:
        @"INSERT INTO attributes (path_id, key, attribute) VALUES(%i, '%@', %i)", 
                              path_id, @"kMDItemFSNodeCount", [contents count]];
      PERFORM_OR_EXIT (db, query);
    }
  }
  
  {
    unsigned long account;
    
    account = [[attributes objectForKey: NSFileGroupOwnerAccountID] unsignedLongValue];

    query = [NSString stringWithFormat:
      @"INSERT INTO attributes (path_id, key, attribute) VALUES(%i, '%@', %i)", 
                                  path_id, @"kMDItemFSOwnerGroupID", account];
    PERFORM_OR_EXIT (db, query);
    
    account = [[attributes objectForKey: NSFileOwnerAccountID] unsignedLongValue];

    query = [NSString stringWithFormat:
      @"INSERT INTO attributes (path_id, key, attribute) VALUES(%i, '%@', %i)", 
                                    path_id, @"kMDItemFSOwnerUserID", account];
    PERFORM_OR_EXIT (db, query);
  }

  query = [NSString stringWithFormat:
    @"INSERT INTO attributes (path_id, key, attribute) VALUES(%i, '%@', %i)", 
                            path_id, @"kMDItemFSSize", [attributes fileSize]];
  PERFORM_OR_EXIT (db, query);
  
  // kMDItemPath
  
  PERFORM_OR_EXIT (db, @"COMMIT");
}

- (id)extractorForPath:(NSString *)path
        withAttributes:(NSDictionary *)attributes
{
  NSString *ext = [[path pathExtension] lowercaseString];
  NSString *app, *type;
  NSData *data = nil;
  int i;
  
  [ws getInfoForFile: path application: &app type: &type]; 
  
  if ([attributes fileType] == NSFileTypeRegular) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath: path];

    if (handle) {
      NS_DURING
        {
          data = [handle readDataOfLength: DLENGTH];
        }
      NS_HANDLER
        {
          data = nil;
        }
      NS_ENDHANDLER

      [handle closeFile];
    }
  }
  
  for (i = 0; i < [extractors count]; i++) {
    id extractor = [extractors objectAtIndex: i];

    if ([extractor canExtractFromFileType: type
                            withExtension: ext 
                               attributes: attributes
                                 testData: data]) {
      return extractor;
    }
  }
  
  if ([textExtractor canExtractFromFileType: type 
                              withExtension: ext
                                 attributes: attributes
                                   testData: data]) {
    return textExtractor;
  }
  
  return nil;
}

- (void)loadExtractors
{
  NSString *bundlesDir;
  NSMutableArray *bundlesPaths;
  NSEnumerator *enumerator;
  NSString *dir;
  int i;
   
  bundlesDir = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlesDir = [bundlesDir stringByAppendingPathComponent: @"Bundles"];

  bundlesPaths = [NSMutableArray array];

  enumerator = [[fm directoryContentsAtPath: bundlesDir] objectEnumerator];

  while ((dir = [enumerator nextObject])) {
    if ([[dir pathExtension] isEqual: @"extr"]) {
			[bundlesPaths addObject: [bundlesDir stringByAppendingPathComponent: dir]];
		}
  }

  extractors = [NSMutableArray new];
  
  for (i = 0; i < [bundlesPaths count]; i++) {
    NSString *bpath = [bundlesPaths objectAtIndex: i];
    NSBundle *bundle = [NSBundle bundleWithPath: bpath]; 

    if (bundle) {
			Class principalClass = [bundle principalClass];  
  
			if ([principalClass conformsToProtocol: @protocol(ExtractorsProtocol)]) {	
        id extractor = [[principalClass alloc] initForExtractor: self];
        
        if ([[extractor pathExtensions] containsObject: @"txt"]) {
          ASSIGN (textExtractor, extractor);
        } else {
          [extractors addObject: extractor];
          RELEASE ((id)extractor);
        }
      }
    }
  }
}

- (void)setStemmingLanguage:(NSString *)language
{
  NSString *lang = (language == nil) ? @"English" : language;

  if ([stemmer setLanguage: lang] == NO) {
    [stemmer setLanguage: @"English"];
  }
  
  ASSIGN (stopWords, [NSSet setWithArray: [stemmer stopWords]]);
}

- (void)loadStemmer
{
  NSString *bundlePath;

  bundlePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  bundlePath = [bundlePath stringByAppendingPathComponent: @"Bundles"];
  bundlePath = [bundlePath stringByAppendingPathComponent: @"Stemmer.bundle"];

  if ([fm fileExistsAtPath: bundlePath]) {
    NSBundle *bundle = [NSBundle bundleWithPath: bundlePath];

    if (bundle) {
      stemmer = [[bundle principalClass] new];
    } 
  }
  
  if (stemmer == nil) {
    [NSException raise: NSInternalInconsistencyException
		            format: @"unable to load stemmer"];   
    exit(EXIT_FAILURE);
  }
}

@end


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL (pool);
  
  if (argc > 1) {
    NSString *path = [NSString stringWithCString: argv[1]];
    int rec = atoi(argv[2]);
    NSString *dbpath = [NSString stringWithCString: argv[3]];
    NSString *cname = [NSString stringWithCString: argv[4]];
    GMDSExtractor *extractor = [[GMDSExtractor alloc] initForPath: path 
                                                        recursive: rec
                                                           dbPath: dbpath
                                                     gmdsConnName: cname];
    if (extractor) {
      [[NSRunLoop currentRunLoop] run];
    }
  } else {
    NSLog(@"no arguments.");
  }
  
  RELEASE (pool);  
  exit(EXIT_SUCCESS);
}




