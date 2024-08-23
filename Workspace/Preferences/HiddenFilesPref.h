/* HiddenFilesPref.h
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

#ifndef HIDDEN_FILES_PREF_H
#define HIDDEN_FILES_PREF_H

#include <Foundation/Foundation.h>
#include "PrefProtocol.h"

@class NSFileManager;
@class NSWorkspace;
@class GWorkspace;
@class FSNode;

@interface HiddenFilesPref : NSObject <PrefProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;

  IBOutlet id tabView;

  IBOutlet id iconView;
  IBOutlet id pathField;

  IBOutlet id hiddenlabel;
  IBOutlet id leftScroll;
  IBOutlet id shownlabel;
  IBOutlet id rightScroll;
  
  IBOutlet id addButt;
  IBOutlet id removeButt;
  IBOutlet id loadButt;
  
  IBOutlet id labelinfo;
  
  IBOutlet id setButt;

  NSMatrix *leftMatrix, *rightMatrix;
  id cellPrototipe;
  
  FSNode *currentNode;

  IBOutlet id hiddenDirslabel;
  IBOutlet id hiddenDirsScroll;
  NSMatrix *dirsMatrix;
  IBOutlet id addDirButt;
  IBOutlet id removeDirButt;
  IBOutlet id setDirButt;

  NSMutableArray *hiddenPaths;

	NSFileManager *fm;
  NSWorkspace *ws;
  GWorkspace *gw;
}

- (IBAction)loadContents:(id)sender;

- (IBAction)moveToHidden:(id)sender;

- (IBAction)moveToShown:(id)sender;

- (IBAction)activateChanges:(id)sender;

- (IBAction)addDir:(id)sender;

- (IBAction)removeDir:(id)sender;

- (IBAction)activateDirChanges:(id)sender;

- (void)selectionChanged:(NSNotification *)n;

- (void)clearAll;

- (void)addCellsWithNames:(NSArray *)names inMatrix:(NSMatrix *)matrix;

- (void)removeCellsWithNames:(NSArray *)names inMatrix:(NSMatrix *)matrix;

- (void)selectCellsWithNames:(NSArray *)names inMatrix:(NSMatrix *)matrix;

- (id)cellWithTitle:(NSString *)title inMatrix:(NSMatrix *)matrix;

@end

#endif // HIDDEN_FILES_PREF_H
