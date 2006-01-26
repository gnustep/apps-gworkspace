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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef GWORKSPACE_H
#define GWORKSPACE_H

#include <Foundation/Foundation.h>
#include <AppKit/NSApplication.h>

#define NOEDIT 0
#define NOXTERM 1

@class NSWorkspace;
@class FSNodeRep;
@class GWViewersManager;
@class GWDesktopManager;
@class Finder;
@class Inspector;
@class Operation;
@class GWViewer;
@class PrefController;
@class Fiend;
@class History;
@class TShelfWin;
@class OpenWithController;
@class RunExternalController;
@class StartAppWin;
@class NSCursor;

@protocol	FSWClientProtocol

- (void)watchedPathDidChange:(NSData *)dirinfo;

@end


@protocol	FSWatcherProtocol

- (oneway void)setGlobalIncludePaths:(NSArray *)ipaths
                        excludePaths:(NSArray *)epaths;

- (oneway void)addGlobalIncludePath:(NSString *)path;

- (oneway void)removeGlobalIncludePath:(NSString *)path;

- (NSArray *)globalIncludePaths;

- (oneway void)addGlobalExcludePath:(NSString *)path;

- (oneway void)removeGlobalExcludePath:(NSString *)path;

- (NSArray *)globalExcludePaths;

- (oneway void)registerClient:(id <FSWClientProtocol>)client
              isGlobalWatcher:(BOOL)global;

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client;

- (oneway void)client:(id <FSWClientProtocol>)client
                          addWatcherForPath:(NSString *)path;

- (oneway void)client:(id <FSWClientProtocol>)client
                          removeWatcherForPath:(NSString *)path;

@end


@protocol	RecyclerAppProtocol

- (oneway void)emptyTrash:(id)sender;

@end


@protocol	DDBdProtocol

- (BOOL)dbactive;

- (oneway void)insertPath:(NSString *)path;

- (oneway void)removePath:(NSString *)path;

- (NSString *)annotationsForPath:(NSString *)path;

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path;

@end


/* The protocol of the remote dnd source */
@protocol GWRemoteFilesDraggingInfo
- (oneway void)remoteDraggingDestinationReply:(NSData *)reply;
@end 


@interface GWorkspace : NSObject <FSWClientProtocol>
{	
  FSNodeRep *fsnodeRep;
  
	NSArray *selectedPaths;

  id fswatcher;
  BOOL fswnotifications;
	
  id recyclerApp;
  BOOL recyclerCanQuit;
  
  id ddbd;
  
  PrefController *prefController;
  Fiend *fiend;
  
  History *history;
	int maxHistoryCache;
    
  GWViewersManager *vwrsManager;
  GWDesktopManager *dtopManager;  
  Inspector *inspector;
  Finder *finder;
  Operation *fileOpsManager;
  
  BOOL dontWarnOnQuit;
  BOOL terminating;
  
  TShelfWin *tshelfWin;
  NSString *tshelfPBDir;
  int tshelfPBFileNum;
      
  OpenWithController *openWithController;
  RunExternalController *runExtController;
  
  StartAppWin *startAppWin;
    	      
	NSString *defEditor;
  NSString *defXterm;
  NSString *defXtermArgs;
  BOOL teminalService;

  NSCursor *waitCursor;
          
  NSFileManager *fm;
  NSWorkspace *ws;
}

+ (GWorkspace *)gworkspace;

+ (void)registerForServices;

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

- (void)showRootViewer;

- (void)rootViewerSelectFiles:(NSArray *)paths;

- (void)newViewerAtPath:(NSString *)path;

- (void)changeDefaultEditor:(NSNotification *)notif;

- (void)changeDefaultXTerm:(NSString *)xterm 
                 arguments:(NSString *)args;
             
- (void)setUseTerminalService:(BOOL)value;             
                             
- (void)updateDefaults;
					 
- (void)startXTermOnDirectory:(NSString *)dirPath;

- (int)defaultSortType;

- (void)setDefaultSortType:(int)type;

- (void)createTabbedShelf;

- (TShelfWin *)tabbedShelf;

- (void)fileSystemWillChange:(NSNotification *)notif;

- (void)fileSystemDidChange:(NSNotification *)notif;
                      
- (void)setSelectedPaths:(NSArray *)paths;

- (void)resetSelectedPaths;

- (NSArray *)selectedPaths;

- (void)openSelectedPaths:(NSArray *)paths 
                newViewer:(BOOL)newv;

- (void)openSelectedPathsWith;

- (BOOL)openFile:(NSString *)fullPath;

- (BOOL)application:(NSApplication *)theApplication 
           openFile:(NSString *)filename;

- (NSArray *)getSelectedPaths;

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

- (void)removableMediaPathsDidChange:(NSNotification *)notif;

- (void)reservedMountNamesDidChange:(NSNotification *)notif;

- (void)hideDotsFileDidChange:(NSNotification *)notif;

- (void)hiddenFilesDidChange:(NSArray *)paths;

- (void)customDirectoryIconDidChange:(NSNotification *)notif;

- (void)applicationForExtensionsDidChange:(NSNotification *)notif;

- (int)maxHistoryCache;

- (void)setMaxHistoryCache:(int)value;

- (void)connectFSWatcher;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;

- (void)connectRecycler;

- (void)recyclerConnectionDidDie:(NSNotification *)notif;

- (void)connectDDBd;

- (void)ddbdConnectionDidDie:(NSNotification *)notif;

- (BOOL)ddbdactive;

- (void)ddbdInsertPath:(NSString *)path;

- (void)ddbdRemovePath:(NSString *)path;

- (NSString *)ddbdGetAnnotationsForPath:(NSString *)path;

- (void)ddbdSetAnnotations:(NSString *)annotations
                   forPath:(NSString *)path;

- (id)connectApplication:(NSString *)appName;

- (void)performFileOperationWithDictionary:(NSDictionary *)opdict;

- (void)slideImage:(NSImage *)image 
							from:(NSPoint)fromPoint 
								to:(NSPoint)toPoint;


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

- (void)selectSpecialTShelfTab:(id)sender;

- (void)addTShelfTab:(id)sender;

- (void)removeTShelfTab:(id)sender;

- (void)renameTShelfTab:(id)sender;

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

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (NSString *)trashPath;

- (id)workspaceApplication;

- (BOOL)terminating;

@end


@interface GWorkspace (WorkspaceApplication)

- (BOOL)performFileOperation:(NSString *)operation 
                      source:(NSString *)source 
                 destination:(NSString *)destination 
                       files:(NSArray *)files 
                         tag:(int *)tag;

- (BOOL)selectFile:(NSString *)fullPath
							inFileViewerRootedAtPath:(NSString *)rootFullpath;

- (int)extendPowerOffBy:(int)requested;

- (NSArray *)launchedApplications;

@end

#endif // GWORKSPACE_H
