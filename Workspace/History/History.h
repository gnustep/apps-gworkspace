/* History.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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

#ifndef HISTORY_H
#define HISTORY_H

#include <Foundation/Foundation.h>

@class NSWindow;
@class NSScrollView;
@class NSMatrix;

@interface History : NSObject 
{
  NSWindow *win;
	NSScrollView *scrollView;
  NSMatrix *matrix;
	id viewer;
}

- (void)activate;

- (void)setViewer:(id)aviewer;

- (id)viewer;

- (void)setHistoryNodes:(NSArray *)nodes;

- (void)setHistoryPosition:(int)position;

- (void)setHistoryNodes:(NSArray *)nodes 
               position:(int)position;

- (void)matrixAction:(id)sender;

- (void)setMatrixWidth;

- (void)updateDefaults;

- (NSWindow *)myWin;

@end

#endif // HISTORY_H

