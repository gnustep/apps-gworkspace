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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

 
#ifndef HISTORY_H
#define HISTORY_H

#include <Foundation/NSObject.h>

@class NSWindow;
@class NSScrollView;
@class NSMatrix;
@class NSMutableArray;

@interface History : NSObject 
{
  NSWindow *win;
	NSScrollView *scrollView;
  NSMatrix *matrix; 
	id viewer;
}

- (void)activate;

- (void)setViewer:(id)aviewer;

- (void)setHistoryPaths:(NSArray *)paths;

- (void)setHistoryPosition:(int)position;

- (void)setHistoryPaths:(NSArray *)paths position:(int)position;

- (void)setViewerPath:(id)sender;

- (void)setMatrixWidth;

- (void)updateDefaults;

- (NSWindow *)myWin;

- (id)viewer;

@end

#endif // HISTORY_H

