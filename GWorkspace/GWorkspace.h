/* GWorkspace.h
 *  
 * Copyright (C) 2003-2016 Free Software Foundation, Inc.
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

#import <Foundation/Foundation.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSWorkspace.h>

#define NOEDIT 0
#define NOXTERM 1

/* defines the maximum number of files to open before issuing a dialog */
#define MAX_FILES_TO_OPEN_DIALOG 8


@class NSWorkspace;
@class FSNode;
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
@class GWLaunchedApp;

@protocol	FSWClientProtocol

- (oneway void)watchedPathDidChange:(NSData *)dirinfo;

- (oneway void)globalWatchedPathDidChange:(NSDictionary *)dirinfo;

@end


@protocol	FSWatcherProtocol

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

- (oneway void)insertPath:(NSString *)path;

- (oneway void)removePath:(NSString *)path;

- (NSString *)annotationsForPath:(NSString *)path;

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path;

- (oneway void)fileSystemDidChange:(NSData *)info;

@end


@protocol	MDExtractorProtocol

@end

/* The protocol of the remote dnd source */
@protocol GWRemoteFilesDraggingInfo
- (oneway void)remoteDraggingDestinationReply:(NSData *)reply;
@end 


@interface GWorkspace : NSObject <FSWClientProtocol>
{	
  FSNodeRep *fsnodeRep;
  
  NSArray *selectedPaths;
  NSMutableArray *trashContents;
  NSString *trashPath;
  
  id fswatcher;
  BOOL fswnotifications;
  NSCountedSet *watchedPaths;
  
  id recyclerApp;
  BOOL recyclerCanQuit;
  
  id ddbd;
  id mdextractor;
  
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
  
  NSString *gwProcessName;  	      
  NSString *gwBundlePath;  	      
  NSString *defEditor;
  NSString *defXterm;
  NSString *defXtermArgs;
  BOOL teminalService;
          
  NSFileManager *fm;

  //
  // WorkspaceApplication
  //
  NSWorkspace *ws;  
  NSNotificationCenter *wsnc; 
  
  NSMutableArray *launchedApps;
  GWLaunchedApp *activeApplication;
  
  NSString *storedAppinfoPath;
  NSDistributedLock *storedAppinfoLock;
  
  NSTimer *logoutTimer;
  BOOL loggingout;
  int autoLogoutDelay;
  int maxLogoutDelay;  
  int logoutDelay;
}

+ (GWorkspace *)gworkspace;

+ (void)registerForServices;

- (void)createMenu;

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

- (NSString *)gworkspaceProcessName;

- (void)updateDefaults;

- (void)setContextHelp;

- (NSAttributedString *)contextHelpFromName:(NSString *)fileName;
					 
- (void)startXTermOnDirectory:(NSString *)dirPath;

- (int)defaultSortType;

- (void)setDefaultSortType:(int)type;

- (void)createTabbedShelf;

- (TShelfWin *)tabbedShelf;

- (StartAppWin *)startAppWin;

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

- (void)connectMDExtractor;

- (void)mdextractorConnectionDidDie:(NSNotification *)notif;

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
#if 0
- (void)closeMainWin:(id)sender;
#endif

- (void)logout:(id)sender;

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

- (BOOL)filenamesWasCut;

- (void)setFilenamesCut:(BOOL)value;

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


@interface GWorkspace (SharedInspector)

- (oneway void)showExternalSelection:(NSArray *)selection;

@end


@interface GWorkspace (WorkspaceApplication)

- (BOOL)performFileOperation:(NSString *)operation 
                      source:(NSString *)source 
                 destination:(NSString *)destination 
                       files:(NSArray *)files 
                         tag:(NSInteger *)tag;

- (BOOL)selectFile:(NSString *)fullPath
							inFileViewerRootedAtPath:(NSString *)rootFullpath;

- (int)extendPowerOffBy:(int)requested;

- (NSArray *)launchedApplications;

- (NSDictionary *)activeApplication;

- (BOOL)openFile:(NSString *)fullPath
          withApplication:(NSString *)appname
            andDeactivate:(BOOL)flag;

- (BOOL)launchApplication:(NSString *)appname
		             showIcon:(BOOL)showIcon
	             autolaunch:(BOOL)autolaunch;

- (BOOL)openTempFile:(NSString *)fullPath;

@end


@interface GWorkspace (Applications)

- (void)initializeWorkspace;

- (void)applicationName:(NSString **)appName
                andPath:(NSString **)appPath
                forName:(NSString *)name;

- (BOOL)launchApplication:(NSString *)appname
		            arguments:(NSArray *)args;

- (void)appWillLaunch:(NSNotification *)notif;

- (void)appDidLaunch:(NSNotification *)notif;

- (void)appDidTerminate:(NSNotification *)notif;

- (void)appDidBecomeActive:(NSNotification *)notif;

- (void)appDidResignActive:(NSNotification *)notif;

- (void)activateAppWithPath:(NSString *)path
                    andName:(NSString *)name;

- (void)appDidHide:(NSNotification *)notif;

- (void)appDidUnhide:(NSNotification *)notif;

- (void)unhideAppWithPath:(NSString *)path
                  andName:(NSString *)name;

- (void)applicationTerminated:(GWLaunchedApp *)app;

- (GWLaunchedApp *)launchedAppWithPath:(NSString *)path
                               andName:(NSString *)name;

- (NSArray *)storedAppInfo;

- (void)updateStoredAppInfoWithLaunchedApps:(NSArray *)apps;

- (void)checkLastRunningApps;

- (void)startLogout;

- (void)doLogout:(id)sender;

- (void)terminateTasks:(id)sender;

@end


@interface GWLaunchedApp : NSObject
{
  NSTask *task;
  NSString *name;
  NSString *path;
  NSNumber *identifier;
  NSConnection *conn;
  id application;
  BOOL active;
  BOOL hidden;
  
  GWorkspace *gw;   
  NSNotificationCenter *nc;
}

+ (id)appWithApplicationPath:(NSString *)apath
             applicationName:(NSString *)aname
                launchedTask:(NSTask *)atask;

+ (id)appWithApplicationPath:(NSString *)apath
             applicationName:(NSString *)aname
           processIdentifier:(NSNumber *)ident
                checkRunning:(BOOL)check;
            
- (NSDictionary *)appInfo;

- (void)setTask:(NSTask *)atask;

- (NSTask *)task;

- (void)setPath:(NSString *)apath;

- (NSString *)path;

- (void)setName:(NSString *)aname;

- (NSString *)name;

- (void)setIdentifier:(NSNumber *)ident;

- (NSNumber *)identifier;

- (id)application;

- (void)setActive:(BOOL)value;

- (BOOL)isActive;

- (void)activateApplication;

- (void)setHidden:(BOOL)value;

- (BOOL)isHidden;

- (void)hideApplication;

- (void)unhideApplication;

- (BOOL)isApplicationHidden;

- (BOOL)gwlaunched;

- (BOOL)isRunning;

- (void)terminateApplication;

- (void)terminateTask;

- (void)connectApplication:(BOOL)showProgress;

- (void)connectionDidDie:(NSNotification *)notif;

@end


@interface NSWorkspace (WorkspaceApplication)

- (id)_workspaceApplication;

@end

#endif // GWORKSPACE_H
