/* GWNet.h
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

#ifndef GWNET_H
#define GWNET_H

#include <Foundation/Foundation.h>

@protocol ViewerProtocol

- (void)stopOperation:(id)op;

- (void)setDispatcher:(id)dsp;

- (void)commandReplyReady:(NSData *)data;

- (oneway void)fileOperationStarted:(NSData *)opinfo;

- (oneway void)fileOperationUpdated:(NSData *)opinfo;

- (oneway void)fileTransferStarted:(NSData *)opinfo;

- (oneway void)fileTransferUpdated:(NSData *)opinfo;

- (BOOL)fileOperationError:(NSData *)opinfo;

- (oneway void)fileOperationDone:(NSData *)opinfo;

@end 


@protocol HandlerProtocol

+ (BOOL)canViewScheme:(NSString *)scheme;

- (oneway void)_nextCommand:(NSData *)cmdinfo;

- (oneway void)_startFileOperation:(NSData *)opinfo;

- (oneway void)_stopFileOperation:(NSData *)opinfo;

- (oneway void)_unregister;

@end 


@protocol DispatcherProtocol

//
// methods for the viewer
//
- (void)setViewer:(id)aViewer 
     handlerClass:(Class)aClass
       connection:(NSConnection *)aConnection;

- (oneway void)nextCommand:(NSData *)cmdinfo;

- (oneway void)startFileOperation:(NSData *)opinfo;

- (oneway void)stopFileOperation:(NSData *)opinfo;

- (oneway void)unregister;

//
// methods for the handler
//
- (void)_setHandler:(id)anObject;

- (oneway void)_replyToViewer:(NSData *)reply;

- (oneway void)_fileOperationStarted:(NSData *)opinfo;

- (oneway void)_fileOperationUpdated:(NSData *)opinfo;

- (oneway void)_fileTransferStarted:(NSData *)opinfo;

- (oneway void)_fileTransferUpdated:(NSData *)opinfo;

- (BOOL)_fileOperationError:(NSData *)opinfo;

- (oneway void)_fileOperationDone:(NSData *)opinfo;

@end 


@protocol FileOpExecutorProtocol

- (oneway void)setOperation:(NSData *)d;

- (oneway void)performOperation;

- (oneway void)stopOperation;

@end 


enum {
  LOGIN,
  NOOP,
  LIST
};

enum {
  CONNECT,
  CONTENTS
};

enum {
  UPLOAD,
  DOWNLOAD,
  DELETE,
  DUPLICATE,
  RENAME,
  NEWFOLDER
};

@class OpenUrlDlog;

@interface GWNet : NSObject 
{
  OpenUrlDlog *openUrlDlog;
  BOOL started;

  NSMutableArray *viewersClasses;
  NSMutableArray *viewers;
  id currentViewer;
  
  NSURL *onStartUrl;
  NSArray *onStartSelection;
  NSDictionary *onStartContents;

  NSMutableArray *handlersClasses;
    
	NSNotificationCenter *nc;
}

+ (GWNet *)gwnet;

- (id)newViewerForUrl:(NSURL *)url 
    withSelectedPaths:(NSArray *)selpaths
          preContents:(NSDictionary *)preconts;

- (void)dispatcherForViewerWithScheme:(NSString *)scheme
                       connectionName:(NSString *)conname;

+ (void)newDispatcherWithInfo:(NSDictionary *)info;

- (void)threadWillExit:(NSNotification *)notification;

- (void)setCurrentViewer:(id)viewer;

- (void)viewerHasClosed:(id)vwr;

- (NSRect)rectForFileOpWindow;

- (BOOL)openBookmarkFile:(NSString *)fpath;

- (void)updateDefaults;


//
// Menu Operations 
//
- (void)openNewUrl:(id)sender;

- (void)closeMainWin:(id)sender;

- (void)showPreferences:(id)sender;

- (void)showInfo:(id)sender;

#ifndef GNUSTEP
- (void)terminate:(id)sender;
#endif

@end

#endif // GWNET_H
