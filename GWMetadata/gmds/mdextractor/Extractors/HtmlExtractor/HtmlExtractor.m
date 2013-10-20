/* HtmlExtractor.m
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@dtedu.net>
 * Date: May 2006
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
#include "HtmlExtractor.h"

#define MAXFSIZE 600000
#define DLENGTH 256
#define WORD_MAX 40

void strip(const char *inbuf, NSMutableString *outstr, NSMutableDictionary *metadict);
int escapeChar(char *buf, NSMutableString *str);


@implementation HtmlExtractor

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
  
    ASSIGN (extensions, ([NSArray arrayWithObjects: @"html", @"htm", nil]));  
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
    const char *bytes = (const char *)[testdata bytes];
    int i;

    for (i = 0; i < [testdata length]; i++) {
      if (bytes[i] == 0x00) {
        return NO; 
        break;
      } 
    }

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
  NSString *contents = [NSString stringWithContentsOfFile: path];
  BOOL success = NO;
  
  if (contents && [contents length]) {
    const char *inbuf = [contents UTF8String];
    NSMutableString	*stripped = [NSMutableString stringWithCapacity: [contents length]];
    NSMutableDictionary *attrsdict = [NSMutableDictionary dictionary];
    
    strip(inbuf, stripped, attrsdict);
    
    if (stripped && [stripped length]) {
      NSScanner *scanner = [NSScanner scannerWithString: stripped];
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
      [wordsDict setObject: [NSNumber numberWithUnsignedLong: wcount] 
                    forKey: @"wcount"];

      [mddict setObject: wordsDict forKey: @"words"];
      [mddict setObject: attrsdict forKey: @"attributes"];

      RELEASE (wordset); 
    }    
  }

  success = [extractor setMetadata: mddict forPath: path withID: path_id];
  
  RELEASE (arp);
  
  return success;
}

@end


void strip(const char *inbuf, NSMutableString *outstr, NSMutableDictionary *metadict) 
{
  int len = strlen(inbuf);
  BOOL isScript = NO;
  BOOL isMarkup = NO;
  BOOL isMeta = NO;  
  BOOL isTitle = NO;  
  BOOL spaceAdded = NO;  
  int offset;
  int i;

#define CHK_POS(x, l) \
do { \
  if (x >= (l - 1)) return; \
} while (0)

  for (i = 0; i < len; i++) {
    /* end of buffer are possible points of failure
      if a markup or a token is cut, it will not be parsed. */        
    if ((i > len - 9) 
            && ((strncmp(inbuf + i, "\x3c", 1) == 0) 
                          || (strncmp(inbuf + i, "\x26", 1) == 0))) {
      break;
    }

    /* detecting end of script */
    if (isScript && ((strncmp(inbuf + i, "</script>", 9) == 0))) {
      isScript = NO;
      i += 9;
    }

    /* detecting new paragraph */
    if ((isScript == NO) && (strncmp(inbuf + i, "<p", 2) == 0)) {
	    i += 2;

      while (strncmp(inbuf + i, ">", 1) != 0) {
	      i++;
        CHK_POS (i, len);
	    }
    }

    /* detecting beginning of markup */
    if ((isScript == NO) && (isMarkup == NO) 
                                && (strncmp(inbuf + i, "\x3c", 1) == 0)) {
      /* detecting begining of script */
      if ((strncmp(inbuf + i, "<script", 7) == 0)
                        || (strncmp(inbuf + i, "<SCRIPT", 7) == 0)) {
        isScript = YES;
        i += 7;
        
      } else if ((strncmp(inbuf + i, "<title>", 7) == 0)
		                             || (strncmp(inbuf + i, "<TITLE>", 7) == 0)) {
        isMeta = YES;
        isTitle = YES;
        i += 7;
        
      } else if ((strncmp(inbuf + i, "<meta", 5) == 0) 
                                  || (strncmp(inbuf + i, "<META", 5) == 0)) {
        isMeta = YES;
        i += 5;

      } else {
        isMarkup = YES;
      }
    }
    
    CHK_POS (i, len);
        
    /* get metadata value */
    if ((isScript == NO) && isMeta) {
      NSMutableString	*mdbuff = [NSMutableString stringWithCapacity: 128];
      char endstr[16];
   //   NSString *key;
   //   NSString *value;
      
      while (strncmp(inbuf + i, "\x20", 1) == 0) {
        i++;
        CHK_POS (i, len);
      }

      memset(endstr, '\0', 16);
      
      if (isTitle) {
        strncpy(endstr, "</title>", 8);
      } else {
        strncpy(endstr, "/>", 2);
      }
            
      while (strncmp(inbuf + i, endstr, strlen(endstr)) != 0) {
        if (strncmp(inbuf + i, "\x26", 1) == 0) {
          offset = escapeChar((char *)(inbuf + i), mdbuff);
          i += offset;
        } else {
          [mdbuff appendFormat: @"%c", inbuf[i]];
          i++;
        }

        CHK_POS (i, len);
      }

      if (isTitle) {
        [metadict setObject: [mdbuff makeImmutableCopyOnFail: NO]
                     forKey: @"GSMDItemTitle"];
        i += 8;
      } else {
        /* TODO - extract metadata from <meta> */
              
        i += 2;
      }

      isTitle = NO;
      isMeta = NO;
      CHK_POS (i, len);
      continue;
    }
    
    /* detecting end of markup */    
    if ((isScript == NO) && isMarkup && (strncmp(inbuf + i, "\x3e", 1) == 0)) {
	    if (spaceAdded == NO) {
              [outstr appendFormat: @"%C", 0x20]; 
	      spaceAdded = YES;
	    }
      
	    isMarkup = NO;
    }
    
    CHK_POS (i, len);
    
    /* handling text */
    if ((isScript == NO) && (isMarkup == NO) 
                              && (strncmp(inbuf + i, "\x3e", 1) != 0)) {
      if ((strncmp(inbuf + i, "\n", 1) != 0) 
                                && (strncmp(inbuf + i, "\t", 1) != 0)) { 
        if (strncmp(inbuf + i, "\x26", 1) == 0) {
          offset = escapeChar((char *)(inbuf + i), outstr);
          i += (offset - 1);
          CHK_POS (i, len);
          spaceAdded = NO;
          
        } else {
          [outstr appendFormat: @"%c", inbuf[i]];
        }
        
        spaceAdded = NO;
        
      } else {
        /* replace tabs and eol by spaces */
        [outstr appendFormat: @"%C", 0x20]; 
      }
    }
  }
}

int escapeChar(char *buf, NSMutableString *str) 
{
  char token[9];
  unichar c = 0x26;
  int len = 0;
  int i = 0;

  /* copying token into local buffer */
  while (i <= 8 && (strncmp(buf + i, ";", 1) != 0)) {
    strncpy(token + i, buf + i, 1);
    i++;
  }
  
  if (strncmp(buf + i, ";\0", 2) == 0) {
    strncpy(token + i, buf + i, 1);   
  
  } else { /* if it does not seem to be a token, result is '&' */
    [str appendFormat: @"%C", c];
    return 1;
  }

  /* identifying token */
  if (strncmp(token, "&amp;", 5) == 0) {
    c = 0x26;
    len = 5;
  } else if (strncmp(token, "&lt;", 4) == 0) {
    c = 0x3C;
    len = 4;
  } else if (strncmp(token, "&gt;", 4) == 0) {
    c = 0x3E;
    len = 4;
  } else if (strncmp(token, "&quot;", 6) == 0) {
    c = 0x22;
    len = 6;
  } else if (strncmp(token, "&eacute;", 8) == 0) {
    c = 0xE9;
    len = 8;
  } else if (strncmp(token, "&Eacute;", 8) == 0) {
    c = 0xC9;
    len = 8;
  } else if (strncmp(token, "&egrave;", 8) == 0) {
    c = 0xE8;
    len = 8;
  } else if (strncmp(token, "&Egrave;", 8) == 0) {
    c = 0xC8;
    len = 8;
  } else if (strncmp(token, "&ecirc;", 7) == 0) {
    c = 0xEA;
    len = 7;
  } else if (strncmp(token, "&agrave;", 8) == 0) {
    c = 0xE0;
    len = 8;
  } else if (strncmp(token, "&iuml;", 6) == 0) {
    c = 0xEF;
    len = 6;
  } else if (strncmp(token, "&ccedil;", 8) == 0) {
    c = 0xE7;
    len = 8;
  } else if (strncmp(token, "&ntilde;", 8) == 0) {
    c = 0xF1;
    len = 8;
  } else if (strncmp(token, "&copy;", 6) == 0) {
    c = 0xA9;
    len = 6;
  } else if (strncmp(token, "&reg;", 5) == 0) {
    c = 0xAE;
    len = 5;
  } else if (strncmp(token, "&deg;", 5) == 0) {
    c = 0xB0;
    len = 5;
  } else if (strncmp(token, "&ordm;", 6) == 0) {
    c = 0xBA;
    len = 6;
  } else if (strncmp(token, "&laquo;", 7) == 0) {
    c = 0xAB;
    len = 7;
  } else if (strncmp(token, "&raquo;", 7) == 0) {
    c = 0xBB;
    len = 7;
  } else if (strncmp(token, "&micro;", 7) == 0) {
    c = 0xB5;
    len = 7;
  } else if (strncmp(token, "&para;", 6) == 0) {
    c = 0xB6;
    len = 6;
  } else if (strncmp(token, "&frac14;", 8) == 0) {
    c = 0xBC;
    len = 8;
  } else if (strncmp(token, "&frac12;", 8) == 0) {
    c = 0xBD;
    len = 8;
  } else if (strncmp(token, "&frac34;", 8) == 0) {
    c = 0xBE;
    len = 8;
  } else if (strncmp(token, "&#", 2) == 0) {
    [str appendFormat: @"%i", atoi(token + 2)];
    return 6;
  } else {
    c = 0x20;
    len = i+1;
  }
  
  if (len != 0) {
    [str appendFormat: @"%C", c]; 
  }
  
  return len;  
}






