/* GWorkspace.h
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

#ifndef GWORKSPACE_H
#define GWORKSPACE_H

#include <Foundation/Foundation.h>
#include <AppKit/NSApplication.h>
#include "GWProtocol.h"

#define NOEDIT 0
#define NOXTERM 1

@class NSWorkspace;
@class FSNodeRep;
@class GWViewersManager;
@class GWDesktopManager;
@class Finder;
@class Inspector;
@class GWViewer;
@class PrefController;
@class Fiend;
@class History;
@class TShelfWin;
@class OpenWithController;
@class RunExternalController;
@class StartAppWin;

@protocol	FSWClientProtocol

- (void)watchedPathDidChange:(NSData *)dirinfo;

@end


@protocol	FSWatcherProtocol

- (oneway void)registerClient:(id <FSWClientProtocol>)client;

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client;

- (oneway void)client:(id <FSWClientProtocol>)client
                          addWatcherForPath:(NSString *)path;

- (oneway void)client:(id <FSWClientProtocol>)client
                          removeWatcherForPath:(NSString *)path;

@end


@protocol	RecyclerAppProtocol

- (oneway void)emptyTrash:(id)sender;

@end


@protocol	OperationProtocol

- (oneway void)performOperation:(NSData *)opinfo;

- (oneway void)setFilenamesCutted:(BOOL)value;

- (BOOL)filenamesWasCutted;

@end


@protocol	DDBdProtocol

- (BOOL)dbactive;

- (oneway void)insertPath:(NSString *)path;

- (oneway void)removePath:(NSString *)path;

- (NSString *)annotationsForPath:(NSString *)path;

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path;

@end


@interface GWorkspace : NSObject <GWProtocol, FSWClientProtocol>
{	
  FSNodeRep *fsnodeRep;
  
	NSArray *selectedPaths;

  id fswatcher;
  BOOL fswnotifications;
	
  id operationsApp;
  id recyclerApp;
  
  id ddbd;
  
  PrefController *prefController;
  Fiend *fiend;
  
  History *history;
	int maxHistoryCache;
    
  GWViewersManager *vwrsManager;
  GWDesktopManager *dtopManager;  
  Inspector *inspector;
  Finder *finder;
  
  BOOL animateChdir;
  BOOL animateSlideBack;

  BOOL contestualMenu;

  BOOL dontWarnOnQuit;
  BOOL terminating;
  
  TShelfWin *tshelfWin;
  NSString *tshelfPBDir;
  int tshelfPBFileNum;
      
  OpenWithController *openWithController;
  RunExternalController *runExtController;
  
  StartAppWin *startAppWin;
    	      
  int shelfCellsWidth;

	NSString *defEditor;
  NSString *defXterm;
  NSString *defXtermArgs;
  BOOL teminalService;
          
  NSFileManager *fm;
  NSWorkspace *ws;
}

+ (void)registerForServices;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;

- (BOOL)applicationShouldTerminate:(NSApplication *)app;

- (NSString *)defEditor;

- (NSString *)defXterm;

- (NSString *)defXtermArgs;

- (GWViewersManager *)viewersManager;

- (GWDesktopManager *)desktopManager;

- (History *)historyWindow;

- (NSImage *)tshelfBackground;	

- (void)tshelfBackgroundDidChange;

- (NSString *)tshelfPBDir;

- (NSString *)tshelfPBFilePath;

- (id)rootViewer;

- (void)newViewerAtPath:(NSString *)path;

- (void)changeDefaultEditor:(NSNotification *)notif;

- (void)changeDefaultXTerm:(NSString *)xterm 
                 arguments:(NSString *)args;
             
- (void)setUseTerminalService:(BOOL)value;             
                             
- (void)updateDefaults;
					 
- (void)startXTermOnDirectory:(NSString *)dirPath;

- (int)defaultSortType;

- (void)setDefaultSortType:(int)type;

- (int)shelfCellsWidth; 

- (int)defaultShelfCellsWidth; 

- (void)setShelfCellsWidth:(int)w; 

- (void)createTabbedShelf;

- (void)checkViewersAfterHidingOfPaths:(NSArray *)paths;

- (void)iconAnimationChanged:(NSNotification *)notif;

- (void)fileSystemWillChange:(NSNotification *)notif;

- (void)fileSystemDidChange:(NSNotification *)notif;
                      
- (void)setSelectedPaths:(NSArray *)paths;

- (void)resetSelectedPaths;

- (NSArray *)selectedPaths;

- (void)showPasteboardData:(NSData *)data 
                    ofType:(NSString *)type
                  typeIcon:(NSImage *)icon;

- (void)newObjectAtPath:(NSString *)basePath 
            isDirectory:(BOOL)directory;

- (void)duplicateFiles;

- (void)deleteFiles;

- (void)moveToTrash;

- (BOOL)verifyFileAtPath:(NSString *)path;

- (void)setUsesThumbnails:(BOOL)value;

- (void)thumbnailsDidChange:(NSNotification *)notif;

- (void)applicationForExtensionsDidChange:(NSNotification *)notif;

- (int)maxHistoryCache;

- (void)setMaxHistoryCache:(int)value;

- (void)connectFSWatcher;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;

- (void)connectRecycler;

- (void)recyclerConnectionDidDie:(NSNotification *)notif;

- (void)connectOperation;

- (void)operationConnectionDidDie:(NSNotification *)notif;

- (void)connectDDBd;

- (void)ddbdConnectionDidDie:(NSNotification *)notif;

- (BOOL)ddbdactive;

- (void)ddbdInsertPath:(NSString *)path;

- (void)ddbdRemovePath:(NSString *)path;

- (NSString *)ddbdGetAnnotationsForPath:(NSString *)path;

- (void)ddbdSetAnnotations:(NSString *)annotations
                   forPath:(NSString *)path;

- (id)connectApplication:(NSString *)appName;


//
// NSServicesRequests protocol
//
- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType;

- (BOOL)readSelectionFromPasteboard:(NSPasteboard *)pboard;


- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types;
                             
										 
//
// Menu Operations
//
- (void)closeMainWin:(id)sender;

- (void)showInfo:(id)sender;

- (void)showPreferences:(id)sender;

- (void)showViewer:(id)sender;

- (void)showHistory:(id)sender;

- (void)showInspector:(id)sender;

- (void)showAttributesInspector:(id)sender;

- (void)showContentsInspector:(id)sender;

- (void)showToolsInspector:(id)sender;

- (void)showAnnotationsInspector:(id)sender;

- (void)showDesktop:(id)sender;

- (void)showRecycler:(id)sender;

- (void)showFinder:(id)sender;

- (void)showFiend:(id)sender;

- (void)hideFiend:(id)sender;

- (void)addFiendLayer:(id)sender;

- (void)removeFiendLayer:(id)sender;

- (void)renameFiendLayer:(id)sender;

- (void)showTShelf:(id)sender;

- (void)hideTShelf:(id)sender;

- (void)maximizeMinimizeTShelf:(id)sender;

- (void)selectSpecialTShelfTab:(id)sender;

- (void)addTShelfTab:(id)sender;

- (void)removeTShelfTab:(id)sender;

- (void)renameTShelfTab:(id)sender;

- (void)openWith:(id)sender;

- (void)runCommand:(id)sender;

- (void)checkRemovableMedia:(id)sender;

- (void)emptyRecycler:(id)sender;


//
// DesktopApplication protocol
//
- (void)selectionChanged:(NSArray *)newsel;

- (void)openSelectionInNewViewer:(BOOL)newv;

- (void)openSelectionWithApp:(id)sender;

- (void)performFileOperation:(NSDictionary *)opinfo;

- (void)lsfolderDragOperation:(NSData *)opinfo
              concludedAtPath:(NSString *)path;
                          
- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localPath;

// - (void)addWatcherForPath:(NSString *)path; // already in GWProtocol

// - (void)removeWatcherForPath:(NSString *)path; // already in GWProtocol

// - (NSString *)trashPath; // already in GWProtocol

- (id)workspaceApplication;

- (BOOL)terminating;

@end

#endif // GWORKSPACE_H
