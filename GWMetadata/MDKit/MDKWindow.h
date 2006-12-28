/* MDKWindow.h
 *  
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
 * Date: December 2006
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

#ifndef MDK_WINDOW_H
#define MDK_WINDOW_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>

@class MDKQuery;
@class MDKResultsCategory;
@class MDKAttribute;
@class MDKAttributeView;
@class MDKAttributeChooser;
@class NSBox;
@class NSPopUpButton;
@class ProgrView;
@class NSTextField;
@class NSButton;
@class NSScrollView;
@class NSTableView;
@class MDKTableView;
@class NSImage;
@class FSNodeRep;

@interface MDKWindow: NSObject 
{
  NSMutableArray *attributes;
  NSMutableArray *attrViews;
  MDKAttributeChooser *chooser;

  void *includePathsTree;  
  void *excludedPathsTree;  
  NSMutableSet *excludedSuffixes;  
  
  IBOutlet id win;
  IBOutlet NSBox *controlsBox;
  IBOutlet NSPopUpButton *placesPopUp;
  NSImage *onImage;
  IBOutlet ProgrView *progView;
  IBOutlet NSTextField *searchField;
  IBOutlet NSButton *startSearchButt;
  IBOutlet NSButton *stopSearchButt;
  IBOutlet NSButton *saveButt;
  IBOutlet NSButton *attributesButt;
  IBOutlet NSBox *attrBox;
  IBOutlet NSTextField *elementsLabel;
  IBOutlet NSScrollView *resultsScroll;
  MDKTableView *resultsView;
  NSTableColumn *nameColumn;
  NSTableColumn *attrColumn;  
  IBOutlet NSBox *pathBox;
  
  FSNodeRep *fsnodeRep;
  NSFileManager *fm;
  NSNotificationCenter *nc;
  NSNotificationCenter *dnc;

  //
  // queries
  //
  BOOL loadingAttributes;  
  NSMutableCharacterSet *skipSet;  
  NSArray *textContentWords;
  NSMutableArray *queryEditors;
  MDKQuery *currentQuery;
  NSArray *categoryNames;
  NSMutableDictionary *resultCategories;
  MDKResultsCategory *catlist;
  int rowsCount;
  int globalCount;
}

- (void)loadAttributes;

- (void)setupInterface;

- (void)insertSavedSearchPlaces;

- (NSArray *)searchPlaces;

- (void)setSearcheablePaths;

- (void)searcheablePathsDidChange:(NSNotification *)notif;

- (NSDictionary *)lastUsedAttributes;

- (NSDictionary *)orderedAttributeNames;

- (NSArray *)attributes;

- (NSArray *)usedAttributes;

- (MDKAttribute *)firstUnusedAttribute;

- (BOOL)isUsedAttributeWithName:(NSString *)name;

- (MDKAttribute *)attributeWithName:(NSString *)name;

- (MDKAttribute *)attributeWithName:(NSString *)name
                            inArray:(NSArray *)attrarray;

- (MDKAttribute *)attributeWithMenuName:(NSString *)mname;

- (void)insertAttributeViewAfterView:(MDKAttributeView *)view;

- (void)removeAttributeView:(MDKAttributeView *)view;

- (void)attributeView:(MDKAttributeView *)view 
    changeAttributeTo:(NSString *)menuname;

- (unsigned)indexOfAttributeView:(MDKAttributeView *)view;










- (void)activate;

- (void)tile;

- (IBAction)placesPopUpdAction:(id)sender;

- (IBAction)startSearchButtAction:(id)sender;

- (IBAction)attributesButtAction:(id)sender;

- (IBAction)saveButtAction:(id)sender;

- (void)showAttributeChooser:(MDKAttributeView *)sender;

- (void)setContextHelp;

@end


@interface MDKWindow (queries)

- (void)setupQueries;

- (void)setupResults;

- (void)controlTextDidChange:(NSNotification *)notif;

- (void)editorStateDidChange:(NSNotification *)notif;

- (void)newQuery;

- (void)prepareResultCategories;

- (void)queryDidStartGathering:(MDKQuery *)query;

- (void)appendRawResults:(NSArray *)lines;

- (void)queryDidUpdateResults:(MDKQuery *)query
                forCategories:(NSArray *)catnames;

- (void)queryDidEndGathering:(MDKQuery *)query;

- (void)queryDidStartUpdating:(MDKQuery *)query;

- (void)queryDidEndUpdating:(MDKQuery *)query;

- (IBAction)stopSearchButtAction:(id)sender;

- (void)updateElementsLabel:(int)n;

- (void)queryCategoriesDidChange:(NSNotification *)notif;

@end


@interface MDKWindow (TableView)

- (void)updateCategoryControls:(BOOL)newranges
                removeSubviews:(BOOL)remove;

- (void)doubleClickOnResultsView:(id)sender;

- (NSImage *)tableView:(NSTableView *)tableView 
      dragImageForRows:(NSArray *)dragRows;

@end


@interface ProgrView : NSView 
{
  NSMutableArray *images;
  int index;
  NSTimer *progTimer;
  BOOL animating;
}

- (void)start;

- (void)stop;

- (void)animate:(id)sender;

@end

#endif // MDK_WINDOW_H
