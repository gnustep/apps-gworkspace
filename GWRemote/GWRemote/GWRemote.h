/* GWRemote.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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


#ifndef GWREMOTE_H
#define GWREMOTE_H

@class NSString;
@class NSArray;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSNotification;
@class NSFileManager;
@class NSWorkspace;
@class ViewerWindow;
@class PrefController;
@class LoginWindow;
@class RemoteEditor;
@class RemoteTerminal;

@protocol GWSdClientProtocol

- (void)setServerConnection:(NSConnection *)conn;

- (NSString *)userName;

- (NSString *)userPassword;

- (oneway void)connectionRefused;

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (int)showErrorAlertWithMessage:(NSString *)message;

- (oneway void)showProgressForFileOperationWithName:(NSString *)name
                                         sourcePath:(NSString *)source
                                    destinationPath:(NSString *)destination
                                       operationRef:(int)ref
                                           onServer:(id)server;

- (void)endOfFileOperationWithRef:(int)ref onServer:(id)server;

- (oneway void)server:(id)aserver fileSystemDidChange:(NSDictionary *)info;

- (oneway void)exitedShellTaskWithRef:(NSNumber *)ref;

- (oneway void)remoteShellWithRef:(NSNumber *)ref 
                 hasAvailableData:(NSData *)data;

@end

@protocol GWSDProtocol

- (void)registerRemoteClient:(id<GWSdClientProtocol>)remote;

- (NSString *)homeDirectory;

- (BOOL)existsFileAtPath:(NSString *)path;

- (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path;

- (NSString *)typeOfFileAt:(NSString *)path;

- (BOOL)isPakageAtPath:(NSString *)path;

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)path;

- (BOOL)isWritableFileAtPath:(NSString *)path;

- (NSDate *)modificationDateForPath:(NSString *)path;

- (int)sortTypeForDirectoryAtPath:(NSString *)aPath;

- (void)setSortType:(int)type forDirectoryAtPath:(NSString *)aPath;

- (NSDictionary *)directoryContentsAtPath:(NSString *)path;

- (NSString *)contentsOfFileAt:(NSString *)path;

- (BOOL)saveString:(NSString *)str atPath:(NSString *)path;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (oneway void)performLocalFileOperationWithDictionary:(id)opdict;

- (BOOL)pauseFileOpeRationWithRef:(int)ref;

- (BOOL)continueFileOpeRationWithRef:(int)ref;

- (BOOL)stopFileOpeRationWithRef:(int)ref;

- (oneway void)renamePath:(NSString *)oldname toNewName:(NSString *)newname;
				
- (oneway void)newObjectAtPath:(NSString *)basePath isDirectory:(BOOL)directory;       
        
- (oneway void)duplicateFiles:(NSArray *)files inDirectory:(NSString *)basePath;

- (oneway void)deleteFiles:(NSArray *)files inDirectory:(NSString *)basePath;

- (oneway void)openShellOnPath:(NSString *)path refNumber:(NSNumber *)ref;

- (oneway void)remoteShellWithRef:(NSNumber *)ref 
                   newCommandLine:(NSString *)line;

- (oneway void)closedRemoteTerminalWithRefNumber:(NSNumber *)ref;
        
@end 

@interface GWRemote : NSObject <GWSdClientProtocol>
{
  NSMutableDictionary *serversDict;
  NSMutableArray *serversNames;
  NSString *currentServer;
  NSString *loginServer;
  NSString *userName;
  NSString *userPassword;
  NSTimer *connectTimer;
  BOOL haveServersList; 

  PrefController *prefController;  
  LoginWindow *loginWindow;

  BOOL animateChdir;
  BOOL animateLaunck;
  BOOL animateSlideBack;
  
  NSMutableArray *fileOpIndicators;
  BOOL showFileOpStatus;
  
  BOOL starting;

  int shelfCellsWidth;

  NSMutableArray *viewers;
  ViewerWindow *currentViewer;	
  ViewerWindow *rootViewer;	

  NSMutableDictionary *cachedContents;
  int cachedMax;
  
  NSMutableArray *editors;
  
  NSMutableArray *terminals;
  NSNumber *remoteTermRef;

	id nc;
	id dstnc;
  NSFileManager *fm;
  NSWorkspace *ws;
}

+ (GWRemote *)gwremote;

//
// Login methods
//
- (void)serversListChanged;

- (void)tryLoginOnServer:(NSString *)servername 
            withUserName:(NSString *)usrname 
            userPassword:(NSString *)userpass;

- (void)checkConnection:(id)sender;



- (void)performFileOperationWithDictionary:(id)opdict
                            fromSourceHost:(NSString *)fromName 
                         toDestinationHost:(NSString *)toName;

- (BOOL)server:(NSString *)serverName isPakageAtPath:(NSString *)path;

- (BOOL)server:(NSString *)serverName fileExistsAtPath:(NSString *)path;  

- (BOOL)server:(NSString *)serverName isWritableFileAtPath:(NSString *)path;

- (BOOL)server:(NSString *)serverName 
            existsAndIsDirectoryFileAtPath:(NSString *)path;              

- (NSString *)server:(NSString *)serverName typeOfFileAt:(NSString *)path;  

- (int)server:(NSString *)serverName sortTypeForPath:(NSString *)aPath; 

- (void)server:(NSString *)serverName                                   
   setSortType:(int)type 
        atPath:(NSString *)aPath;

- (NSArray *)server:(NSString *)serverName 
   checkHiddenFiles:(NSArray *)files 
             atPath:(NSString *)path;

- (NSArray *)server:(NSString *)serverName 
        sortedDirectoryContentsAtPath:(NSString *)path;

- (void)server:(NSString *)serverName setSelectedPaths:(NSArray *)paths;

- (NSArray *)selectedPathsForServerWithName:(NSString *)serverName;

- (NSString *)homeDirectoryForServerWithName:(NSString *)serverName;

- (BOOL)server:(NSString *)serverName isLockedPath:(NSString *)aPath;

- (void)server:(NSString *)serverName addWatcherForPath:(NSString *)path;

- (void)server:(NSString *)serverName removeWatcherForPath:(NSString *)path;

- (void)server:(NSString *)serverName removeWatcherForPath:(NSString *)path;

- (void)server:(NSString *)serverName 
    renamePath:(NSString *)oldname 
     toNewName:(NSString *)newname;


- (void)readDefaultsForServer:(NSString *)serverName;

- (NSMutableDictionary *)dictionaryForServer:(NSString *)serverName;

- (id <GWSDProtocol>)serverWithName:(NSString *)serverName;

- (id <GWSDProtocol>)serverWithConnection:(NSConnection *)conn;

- (NSString *)nameOfServer:(id)server;

- (NSArray *)viewersOfServer:(NSString *)serverName;

- (NSDictionary *)server:(NSString *)serverName 
            fileSystemAttributesAtPath:(NSString *)path;

- (NSImage *)iconForFile:(NSString *)fullPath ofType:(NSString *)type;

- (NSImage *)getImageWithName:(NSString*)name
		                alternate:(NSString *)alternate;

- (NSImage *)unknownFiletypeImage;

- (NSImage *)folderImage;

- (ViewerWindow *)server:(NSString *)serverName
          newViewerAtPath:(NSString *)path 
              canViewApps:(BOOL)viewapps;

- (void)setCurrentViewer:(ViewerWindow *)viewer;

- (id)rootViewer;

- (void)viewerHasClosed:(id)sender;

- (void)server:(NSString *)serverName 
      openSelectedPaths:(NSArray *)paths 
              newViewer:(BOOL)newv;

- (BOOL)editor:(RemoteEditor *)editor
      didEditContents:(NSString *)contents
               ofFile:(NSString *)filepath
         onRemoteHost:(NSString *)serverName;

- (void)remoteEditorHasClosed:(RemoteEditor *)editor;

- (void)newTerminal;

- (void)remoteTerminalHasClosed:(RemoteTerminal *)terminal;

- (void)_exitedShellTaskWithRef:(NSNumber *)ref;

- (RemoteTerminal *)remoteTerminalWithRef:(NSNumber *)ref;

- (void)_remoteShellWithRef:(NSNumber *)ref hasAvailableData:(NSData *)data;

- (void)terminalWithRef:(NSNumber *)ref newCommandLine:(NSString *)line;

- (NSNumber *)remoteTerminalRef;

- (NSMutableDictionary *)cachedRepresentationForPath:(NSString *)path
                                            onServer:(NSString *)serverName;

- (void)addCachedRepresentation:(NSDictionary *)contentsDict
                    ofDirectory:(NSString *)path
                       onServer:(NSString *)serverName;

- (void)removeCachedRepresentationForPath:(NSString *)path
                                 onServer:(NSString *)serverName;
                                            
- (void)removeOlderCachedForServer:(NSString *)serverName;
                                            
- (int)entriesInCacheOfServer:(NSString *)serverName;


- (BOOL)server:(NSString *)serverName verifyFileAtPath:(NSString *)path;

- (void)fileSystemWillChangeNotification:(NSNotification *)notif;

- (void)fileSystemDidChangeNotification:(NSNotification *)notif;
                      
- (void)server:(NSString *)serverName 
        newObjectAtPath:(NSString *)basePath 
            isDirectory:(BOOL)directory;

- (void)duplicateFilesOnServerName:(NSString *)serverName;

- (void)deleteFilesOnServerName:(NSString *)serverName;

- (BOOL)pauseFileOperationWithRef:(int)ref 
                 onServerWithName:(NSString *)serverName;

- (BOOL)continueFileOperationWithRef:(int)ref
                    onServerWithName:(NSString *)serverName;

- (BOOL)stopFileOperationWithRef:(int)ref
                onServerWithName:(NSString *)serverName;

- (int)shelfCellsWidth; 

- (int)defaultShelfCellsWidth; 

- (void)setShelfCellsWidth:(int)w; 

- (void)updateDefaults;

- (void)connectionDidDie:(NSNotification *)notification;


//
// Menu Operations 
//
- (void)showViewer:(id)sender;

- (void)openRemoteTerminal:(id)sender;

- (void)closeMainWin:(id)sender;

- (void)showPreferences:(id)sender;

- (void)showLoginWindow:(id)sender;

- (void)showInfo:(id)sender;

- (void)logout:(id)sender;

@end

#endif // GWREMOTE_H
