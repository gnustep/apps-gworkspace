/* ClipBook.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2003
 *
 * This file is part of the GNUstep ClipBook application
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

#ifndef CLIP_BOOK_H
#define CLIP_BOOK_H

#include <Foundation/Foundation.h>

@class ClipBookWindow;

@interface ClipBook : NSObject
{
  ClipBookWindow *cbwin;

  NSString *pdDir;
  int pbFileNum;

  NSFileManager *fm;
}

+ (ClipBook *)clipbook;

+ (void)registerForServices;

- (NSString *)pdDir;

- (NSString *)pbFilePath;

- (NSArray *)pbTypes;

- (void)updateDefaults;

- (void)cut:(id)sender;

- (void)copy:(id)sender;

- (void)paste:(id)sender;

- (void)showInfo:(id)sender;

@end

#endif // CLIP_BOOK_H




