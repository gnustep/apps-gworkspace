/* MDIndexing.h
 *  
 * Copyright (C) 2006-2010 Free Software Foundation, Inc.
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



#import <Foundation/Foundation.h>
#ifdef __APPLE__
  #import <GSPreferencePanes/PreferencePanes.h>
#else
  #import <PreferencePanes/PreferencePanes.h>
#endif

@class NSMatrix;
@class NSScrollView;
@class NSTextView;
@class NSButton;
@class StartAppWin;

@protocol	MDExtractorProtocol

@end


@interface MDIndexing : NSPreferencePane 
{
  IBOutlet id tabView;

  //
  // Paths & Status
  //
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

  IBOutlet id suffixTitle;
  IBOutlet id suffixScroll;
  NSMatrix *suffixMatrix;
  IBOutlet id suffixField;
  IBOutlet id suffixAdd;
  IBOutlet id suffixRemove;  
  NSMutableArray *excludedSuffixes;
  
  BOOL indexingEnabled;
  
  IBOutlet id enableSwitch;
  IBOutlet id statusButton;  
  IBOutlet id errorButton;  
  IBOutlet id revertButton;
  IBOutlet id applyButton;
      
  BOOL loaded;
  NSPreferencePaneUnselectReply pathsUnselReply;

  id mdextractor;
  
  StartAppWin *startAppWin;  
  NSString *indexedStatusPath;
  NSDistributedLock *indexedStatusLock;
  
  IBOutlet id statusWindow;
  IBOutlet NSScrollView *statusScroll;
  NSTextView *statusView;
  NSTimer *statusTimer;

  NSString *errorLogPath;

  IBOutlet id errorWindow;
  IBOutlet NSScrollView *errorScroll;
  NSTextView *errorView;
  
  //
  // Search Results
  //
  IBOutlet id searchResTitle;
  IBOutlet id searchResSubtitle;
  IBOutlet id searchResScroll;
  IBOutlet id searchResEditor;
  IBOutlet id searchResRevert;
  IBOutlet id searchResApply;
  
  NSPreferencePaneUnselectReply searchResultsReply;

  NSFileManager *fm;
  NSNotificationCenter *nc;
  NSNotificationCenter *dnc;
}

- (void)indexedMatrixAction:(id)sender;

- (IBAction)indexedButtAction:(id)sender;

- (void)excludedMatrixAction:(id)sender;

- (IBAction)excludedButtAction:(id)sender;

- (void)suffixMatrixAction:(id)sender;

- (IBAction)suffixButtAction:(id)sender;

- (IBAction)enableSwitchAction:(id)sender;

- (IBAction)revertButtAction:(id)sender;

- (IBAction)applyButtAction:(id)sender;

- (NSString *)chooseNewPath;

- (void)adjustMatrix:(NSMatrix *)matrix;

- (void)setupDbPaths;

- (void)connectMDExtractor;

- (void)mdextractorConnectionDidDie:(NSNotification *)notif;

- (IBAction)statusButtAction:(id)sender;

- (IBAction)errorButtAction:(id)sender;

- (void)readIndexedPathsStatus:(id)sender;

- (void)readDefaults;

- (void)applyChanges;

//
// Search Results
//
- (IBAction)searchResButtAction:(id)sender;

- (void)searchResultDidStartEditing;

- (void)searchResultDidEndEditing;

@end
