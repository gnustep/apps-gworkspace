/* MDIndexing.h
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
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

#ifndef MD_INDEXING_H
#define MD_INDEXING_H

#include <Foundation/Foundation.h>
#ifdef __APPLE__
  #include <GSPreferencePanes/PreferencePanes.h>
#else
  #include <PreferencePanes/PreferencePanes.h>
#endif

@class NSMatrix;
@class StartAppWin;

@protocol	MDExtractorProtocol


@end


@interface MDIndexing : NSPreferencePane 
{
  IBOutlet id indexedTitle;
  IBOutlet id indexedScroll;
  NSMatrix *indexedMatrix;  
  IBOutlet id indexedAdd;
  IBOutlet id indexedRemove;
  NSMutableArray *indexedPaths;
  
  IBOutlet id excludedTitle;
  IBOutlet id excludedScroll;
  NSMatrix *excludedMatrix;
  IBOutlet id excludedAdd;
  IBOutlet id excludedRemove;  
  NSMutableArray *excludedPaths;
  
  BOOL indexingEnabled;
  
  IBOutlet id enableSwitch;
  IBOutlet id revertButton;
  IBOutlet id applyButton;
      
  BOOL loaded;
  NSPreferencePaneUnselectReply unselectReply;

  id mdextractor;
  StartAppWin *startAppWin;  
  NSString *indexedStatusPath;
  NSDistributedLock *indexedStatusLock;
  
  NSFileManager *fm;
  NSNotificationCenter *nc;
  NSNotificationCenter *dnc;
}

- (void)indexedMatrixAction:(id)sender;

- (IBAction)indexedButtAction:(id)sender;

- (void)excludedMatrixAction:(id)sender;

- (IBAction)excludedButtAction:(id)sender;

- (IBAction)enableSwitchAction:(id)sender;

- (IBAction)revertButtAction:(id)sender;

- (IBAction)applyButtAction:(id)sender;

- (void)adjustMatrix:(NSMatrix *)matrix;

- (void)setupDbPaths;

- (NSArray *)readIndexedPathsStatus;

- (void)connectMDExtractor;

- (void)mdextractorConnectionDidDie:(NSNotification *)notif;

- (NSString *)chooseNewPath;

- (void)readDefaults;

- (void)applyChanges;

@end

#endif // MD_INDEXING_H

