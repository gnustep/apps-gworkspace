/* gmsd.h
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

#ifndef STEMMER_H
#define STEMMER_H

#include <Foundation/Foundation.h>
#include "libstemmer.h"

@interface Stemmer: NSObject 
{
  struct sb_stemmer *stemmer;
  NSString *language;
  NSArray *stopWords;  
}

- (NSString *)stemWord:(NSString *)word;

- (BOOL)setLanguage:(NSString *)lang;

- (NSString *)language;

- (NSArray *)stopWords;
      
@end

#endif // STEMMER_H













