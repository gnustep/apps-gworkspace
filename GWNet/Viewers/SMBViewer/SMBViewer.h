/* SMBViewer.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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

#ifndef SMB_VIEWER_H
#define SMB_VIEWER_H

#include <Foundation/Foundation.h>
#include <AppKit/NSWindow.h>

@class Browser;
@class NSImage;
@class FileOpInfo;

@interface SMBViewer : NSWindow 
{
  Browser *browser;

  int resizeIncrement;
  int iconCellsWidth;
  int columns;
  float columnsWidth;  

  NSMutableDictionary *cachedContents;
  NSMutableDictionary *preContents;
  NSString *pathSeparator;
  NSArray *selectedPaths;
  NSMutableArray *nextPathComponents;
  NSString *progrPath;
  NSArray *nextSelection[2];
  BOOL loadingSelection;
  NSMutableArray *lockedPaths;

  NSImage *hostIcon;
  NSImage *folderIcon;
  NSImage *toolIcon;
  NSImage *unknownIcon;
  
  NSMutableArray *commandsQueue;
  int commref;
  NSMutableArray *tmoutTimers;

  NSMutableArray *fileOperations;
  int fopRef;
        
  NSString *hostname;
  NSString *user;
  NSString *password;
  BOOL connected;
  
  id gwnetapp;
  id dispatcher;
  NSConnection *dispatcherConn;
  
  NSString *dndConnName;
  NSConnection *dndConn;

  NSNotificationCenter *nc;
}

+ (BOOL)canViewScheme:(NSString *)scheme;

- (id)initForUrl:(NSURL *)url 
            user:(NSString *)usr
        password:(NSString *)passwd;

- (void)setPathAndSelection:(NSArray *)selection;

- (void)createInterface;

- (void)createIcons;

- (void)activate;

- (void)adjustSubviews;

- (void)viewFrameDidChange:(NSNotification *)notification;

- (void)selectAll;

- (void)setNextSelectionComponent;

- (NSString *)hostname;

- (NSString *)scheme;

- (NSArray *)fileOperations;

- (void)updateDefaults;


//
// gwnetd connection methods
//
- (void)setDispatcher:(id)dsp;

- (void)checkConnection:(id)sender;

- (void)connectionDidDie:(NSNotification *)notification;


//
// smb commands methods
//
- (void)newCommand:(int)cmd 
     withArguments:(NSArray *)args;

- (void)nextCommand;

- (void)timeoutCommand:(id)sender;

- (void)removeTimerForCommand:(NSDictionary *)cmdInfo;

- (NSDictionary *)commandWithRef:(NSNumber *)ref;

- (NSNumber *)commandRef;

- (BOOL)isQueuedCommand:(NSDictionary *)cmdInfo;

- (void)commandReplyReady:(NSData *)data;


//
// remote file operation methods
//
- (int)fileOpRef;

- (BOOL)confirmOperation:(FileOpInfo *)op;

- (void)startOperation:(FileOpInfo *)op;

- (void)stopOperation:(FileOpInfo *)op;

- (FileOpInfo *)infoForOperationWithRef:(int)ref;

- (oneway void)fileOperationStarted:(NSData *)opinfo;

- (oneway void)fileOperationUpdated:(NSData *)opinfo;

- (oneway void)fileTransferStarted:(NSData *)opinfo;

- (oneway void)fileTransferUpdated:(NSData *)opinfo;

- (oneway void)fileOperationDone:(NSData *)opinfo;

- (BOOL)fileOperationError:(NSData *)opinfo;

- (oneway void)remoteDraggingDestinationReply:(NSData *)reply;


//
// directory contents methods
//
- (NSDictionary *)createPathCache:(NSDictionary *)pathInfo;

- (void)addCachedContents:(NSDictionary *)conts 
                  forPath:(NSString *)path;

- (void)removeCachedContentsForPath:(NSString *)path;

- (void)removeCachedContentsStartingAt:(NSString *)apath;

- (void)setPreContents:(NSDictionary *)conts;

- (void)removePreContents;

- (NSDictionary *)infoForPath:(NSString *)path;

- (void)lockFiles:(NSArray *)files 
      inDirectory:(NSString *)path;

- (void)unlockFiles:(NSArray *)files 
        inDirectory:(NSString *)path;


//
// browser delegate methods
//
- (BOOL)fileExistsAtPath:(NSString *)path;

- (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path;

- (BOOL)isWritableFileAtPath:(NSString *)path;

- (NSString *)typeOfFileAt:(NSString *)path;

- (BOOL)isPakageAtPath:(NSString *)path;

- (BOOL)isLockedPath:(NSString *)path;

- (void)prepareContentsForPath:(NSString *)path;

- (NSDictionary *)contentsForPath:(NSString *)path;

- (NSDictionary *)preContentsForPath:(NSString *)path;

- (void)invalidateContentsRequestForPath:(NSString *)path;

- (BOOL)isLoadingSelection;

- (void)stopLoadSelection;

- (void)setSelectedPaths:(NSArray *)paths;

- (void)openSelectedPaths:(NSArray *)paths 
                newViewer:(BOOL)isnew;

- (void)renamePath:(NSString *)oldPath 
            toPath:(NSString *)newPath;

- (void)uploadFiles:(NSDictionary *)info;

- (NSImage *)iconForFile:(NSString *)fullPath 
                  ofType:(NSString *)type;

- (NSString *)dndConnName;


//
// Menu operations
//
- (void)newFolder:(id)sender;

- (void)duplicateFiles:(id)sender;

- (void)deleteFiles:(id)sender;

- (void)selectAllInViewer:(id)sender;

- (void)reloadLastColumn:(id)sender;

- (void)reloadAll:(id)sender;

- (void)print:(id)sender;

@end

#endif // SMB_VIEWER_H
