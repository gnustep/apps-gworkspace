/* MYViewer.h
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


#ifndef MYVIEWER_H
#define MYVIEWER_H

#include <AppKit/NSView.h>
  #ifdef GNUSTEP 
#include <ViewersProtocol.h>
  #else
#include <GWorkspace/ViewersProtocol.h>
  #endif

@class NSString;
@class NSArray;
@class NSFileManager;
@class NSDictionary;
@class NSNotification;

@interface MYViewer : NSView <ViewersProtocol, NSCopying>
{
  NSString *rootPath;
	NSArray *selectedPaths;
  int resizeIncrement;
  BOOL autoSynchronize;
  BOOL viewsapps;
	id delegate;
	id gworkspace;
  NSFileManager *fm;
}

@end

//
// Methods Implemented by the Delegate 
//
@interface NSObject (ViewerDelegateMethods)

- (void)setTheSelectedPaths:(id)paths;

- (NSArray *)selectedPaths;

- (void)setTitleAndPath:(id)apath selectedPaths:(id)paths;

- (void)addPathToHistory:(NSArray *)paths;

- (void)updateTheInfoString;

- (int)browserColumnsWidth;

- (int)iconCellsWidth;

- (int)getWindowFrameWidth;

- (int)getWindowFrameHeight;

- (void)startIndicatorForOperation:(NSString *)operation;

- (void)stopIndicatorForOperation:(NSString *)operation;

@end

#endif // MYVIEWER_H

