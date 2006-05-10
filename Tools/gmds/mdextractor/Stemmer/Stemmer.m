/* gmsd.m
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

#include "Stemmer.h"

#define GWDebugLog(format, args...) \
  do { if (GW_DEBUG_LOG) \
    NSLog(format , ## args); } while (0)

@implementation	Stemmer

- (void)dealloc
{  
  if (stemmer != NULL) {
    sb_stemmer_delete(stemmer);
  }
  RELEASE (language);
  RELEASE (stopWords);
    
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {  
    [self setLanguage: @"English"];
  }
  
  return self;    
}

- (NSString *)stemWord:(NSString *)word
{
  const char *buf = [word UTF8String];
  const char *stemmed = sb_stemmer_stem(stemmer, buf, strlen(buf));

  return [NSString stringWithUTF8String: stemmed];
}

- (BOOL)setLanguage:(NSString *)lang
{
  NSBundle *bundle;
  NSString *path;
  
  ASSIGN (language, [lang lowercaseString]);
    
  if (stemmer != NULL) {
    sb_stemmer_delete(stemmer);
  }

  stemmer = sb_stemmer_new([language UTF8String], NULL);

  if (stemmer == NULL) {
    NSLog(@"language \"%@\" not available for stemming", language);     
    return NO;
  }
  
  bundle = [NSBundle bundleForClass: [self class]];
  path = [bundle pathForResource: @"Stopwords" ofType: language];
  ASSIGN (stopWords, [NSArray arrayWithContentsOfFile: path]);

  return YES;
}

- (NSString *)language
{
  return language;
}

- (NSArray *)stopWords
{
  return stopWords;
}

@end


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL (pool);
  Stemmer *stemmer = [[Stemmer alloc] init];
  RELEASE (pool);

  if (stemmer != nil) {
	  CREATE_AUTORELEASE_POOL (pool);
    [[NSRunLoop currentRunLoop] run];
  	RELEASE (pool);
  }
  
  exit(EXIT_SUCCESS);
}

