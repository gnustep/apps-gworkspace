/* Finder.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Finder application
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

#ifndef FINDER_H
#define FINDER_H

#include <Foundation/Foundation.h>

@class FindView;
@class SearchResults;
@class NSMatrix;
@class SearchPlacesScroll;
@class SearchPlacesMatrix;

@protocol workspaceAppProtocol

- (void)showRootViewer;

- (BOOL)openFile:(NSString *)fullPath;

- (BOOL)selectFile:(NSString *)fullPath
				  inFileViewerRootedAtPath:(NSString *)rootFullpath;

@end


@interface Finder : NSObject 
{
  IBOutlet id win;
  IBOutlet id searchLabel;
  IBOutlet id wherePopUp;
  IBOutlet id placesBox;
  SearchPlacesScroll *placesScroll;
  SearchPlacesMatrix *placesMatrix;
  IBOutlet id addPlaceButt;
  IBOutlet id removePlaceButt;
  IBOutlet id itemsLabel;
  IBOutlet id findViewsBox;
  IBOutlet id findButt;

  NSMutableArray *modules;
  NSMutableArray *fviews;

  NSArray *currentSelection;
  BOOL searchPlaces;
  
  NSMutableArray *searchResults;
  int searchResh;
  
  NSFileManager *fm;
  id ws;
  NSNotificationCenter *nc; 
  
  id workspaceApplication;
}

+ (Finder *)finder;

- (NSArray *)loadModules;

- (NSArray *)usedModules;

- (id)firstUnusedModule;

- (id)moduleWithName:(NSString *)mname;

- (void)addModule:(FindView *)aview;

- (void)removeModule:(FindView *)aview;

- (void)findView:(FindView *)aview changeModuleTo:(NSString *)mname;

- (NSArray *)bundlesWithExtension:(NSString *)extension 
													 inPath:(NSString *)path;

- (void)tile;

- (void)showWindow;

- (void)setSelectionData:(NSData *)data;

- (IBAction)chooseSearchPlacesType:(id)sender;

- (IBAction)addSearchPlaceFromDialog:(id)sender;

- (void)addSearchPlaceFromPasteboard:(NSPasteboard *)pb;

- (void)addSearchPlaceWithPath:(NSString *)spath;

- (IBAction)removeSearchPlaceButtAction:(id)sender;

- (void)removeSearchPlaceWithPath:(NSString *)spath;

- (NSArray *)searchPlacesPaths;

- (NSArray *)selectedSearchPlacesPaths;

- (void)placesMatrixAction:(id)sender;

- (void)checkSearchPlaceRemoved:(NSNotification *)notif;

- (IBAction)startFind:(id)sender;

- (void)resultsWindowWillClose:(SearchResults *)results;

- (void)setSearchResultsHeight:(int)srh;

- (int)searchResultsHeight;

- (void)openFoundSelection:(NSArray *)selection;

- (void)updateDefaults;

- (void)contactWorkspaceApp;

- (void)workspaceAppConnectionDidDie:(NSNotification *)notif;


//
// Menu Operations 
//
- (void)showFindWindow:(id)sender;

- (void)showPreferences:(id)sender;

- (void)showInfo:(id)sender;

- (void)closeMainWin:(id)sender;

#ifndef GNUSTEP
- (void)terminate:(id)sender;
#endif


//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)performFileOperation:(NSDictionary *)opinfo;

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (NSString *)trashPath;

- (id)workspaceApplication;

@end

#endif // FINDER_H
