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

#include <AppKit/NSApplication.h>
  #ifdef GNUSTEP 
#include "GWProtocol.h"
  #else
#include <GWorkspace/GWProtocol.h>
  #endif

#define NOEDIT 0
#define NOXTERM 1

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSNotification;
@class NSTimer;
@class NSFileManager;
@class NSWorkspace;
@class GWViewersManager;
@class ViewersWindow;
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


@protocol	InspectorProtocol

- (oneway void)addViewerWithBundleData:(NSData *)bundleData;

- (oneway void)setPathsData:(NSData *)data;

- (oneway void)showWindow;

- (oneway void)showAttributes;

- (oneway void)showContents;

- (oneway void)showTools;

- (BOOL)canDisplayDataOfType:(NSString *)type;

- (oneway void)showData:(NSData *)data 
                 ofType:(NSString *)type;

@end


@protocol	FinderAppProtocol

- (oneway void)setSelectionData:(NSData *)data;

- (oneway void)showWindow;

@end


@protocol	DesktopAppProtocol

- (NSData *)tabbedShelfBackground;

- (oneway void)checkNewRemovableMedia:(id)sender;

- (oneway void)emptyTrash:(id)sender;

@end


@protocol	RecyclerAppProtocol

- (oneway void)emptyTrash:(id)sender;

@end


@protocol	OperationProtocol

- (oneway void)performOperation:(NSData *)opinfo;

- (oneway void)setFilenamesCutted:(BOOL)value;

- (BOOL)filenamesWasCutted;

@end


@interface GWorkspace : NSObject <GWProtocol, FSWClientProtocol>
{
	NSString *defEditor, *defXterm, *defXtermArgs;
	  
	NSArray *selectedPaths;

  id fswatcher;
  BOOL fswnotifications;
	
  id inspectorApp;
  id operationsApp;
  id finderApp;
  id desktopApp;
  id recyclerApp;
    
  PrefController *prefController;
  Fiend *fiend;
  History *history;
	
  ViewersWindow *rootViewer;	
  NSMutableArray *viewers;
  GWViewersManager *vwrsManager;
  NSMutableArray *viewersSearchPaths;
	NSMutableArray *viewersTemplates;

  BOOL animateChdir;
  BOOL animateSlideBack;

  BOOL contestualMenu;

  BOOL dontWarnOnQuit;
  
  TShelfWin *tshelfWin;
  NSImage *tshelfBackground;
  NSString *tshelfPBDir;
  int tshelfPBFileNum;
      
  OpenWithController *openWithController;
  RunExternalController *runExtController;
  
  StartAppWin *startAppWin;
    
  BOOL usesThumbnails;
	      
  int shelfCellsWidth;
          
  NSFileManager *fm;
  NSWorkspace *ws;
  
  BOOL starting;
}

+ (void)registerForServices;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;

- (BOOL)applicationShouldTerminate:(NSApplication *)app;

- (NSString *)defEditor;

- (NSString *)defXterm;

- (NSString *)defXtermArgs;

- (History *)historyWindow;

- (NSImage *)tshelfBackground;	

- (void)makeTshelfBackground;

- (NSString *)tshelfPBDir;

- (NSString *)tshelfPBFilePath;

- (id)rootViewer;

- (id)viewerRootedAtPath:(NSString *)vpath;

- (void)changeDefaultEditor:(NSString *)editor;

- (void)changeDefaultXTerm:(NSString *)xterm arguments:(NSString *)args;
                             
- (void)updateDefaults;
					 
- (void)startXTermOnDirectory:(NSString *)dirPath;

- (int)defaultSortType;

- (void)setDefaultSortType:(int)type;

- (int)shelfCellsWidth; 

- (int)defaultShelfCellsWidth; 

- (void)setShelfCellsWidth:(int)w; 

- (void)createTabbedShelf;

- (void)makeViewersTemplates;

- (void)addViewer:(id)vwr withBundlePath:(NSString *)bpath;

- (void)removeViewerWithBundlePath:(NSString *)bpath;

- (NSMutableArray *)bundlesWithExtension:(NSString *)extension 
											       inDirectory:(NSString *)dirpath;

- (NSArray *)viewersPaths;

- (void)checkViewersAfterHidingOfPaths:(NSArray *)paths;

- (void)viewerHasClosed:(id)sender;

- (void)iconAnimationChanged:(NSNotification *)notif;

- (void)fileSystemWillChange:(NSNotification *)notif;

- (void)fileSystemDidChange:(NSNotification *)notif;
           
- (void)watcherNotification:(NSNotification *)notification;           
           
- (void)setSelectedPaths:(NSArray *)paths;

- (void)resetSelectedPaths;

- (NSArray *)selectedPaths;

- (void)showPasteboardData:(NSData *)data 
                    ofType:(NSString *)type
                  typeIcon:(NSImage *)icon;

- (void)newObjectAtPath:(NSString *)basePath isDirectory:(BOOL)directory;

- (void)duplicateFiles;

- (void)deleteFiles;

- (BOOL)verifyFileAtPath:(NSString *)path;

- (void)setUsesThumbnails:(BOOL)value;

- (void)thumbnailsDidChange:(NSNotification *)notif;

- (void)applicationForExtensionsDidChange:(NSNotification *)notif;

- (void)connectFSWatcher;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;

- (void)connectInspector;

- (void)inspectorConnectionDidDie:(NSNotification *)notif;

- (void)connectFinder;

- (void)finderConnectionDidDie:(NSNotification *)notif;

- (void)connectDesktop;

- (void)desktopConnectionDidDie:(NSNotification *)notif;

- (void)connectRecycler;

- (void)recyclerConnectionDidDie:(NSNotification *)notif;

- (void)connectOperation;

- (void)operationConnectionDidDie:(NSNotification *)notif;

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

- (void)concludeRemoteFilesDragOperation:(NSData *)opinfo
                             atLocalPath:(NSString *)localdest;

// - (void)addWatcherForPath:(NSString *)path; // already in GWProtocol

// - (void)removeWatcherForPath:(NSString *)path; // already in GWProtocol

// - (NSString *)trashPath; // already in GWProtocol

- (id)workspaceApplication;

@end

#endif // GWORKSPACE_H
