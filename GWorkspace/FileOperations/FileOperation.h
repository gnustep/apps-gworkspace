/* FileOperation.h
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

#ifndef FILEOPERATION_H
#define FILEOPERATION_H

#include <Foundation/NSObject.h>

@class NSString;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSFileManager;
@class NSTimer;
@class NSLock;
@class GWorkspace;
@class FileOpExecutor;

@protocol FileOpProtocol

- (void)registerExecutor:(id)anObject;
                            
- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (int)showErrorAlertWithMessage:(NSString *)message;

- (void)setNumFiles:(int)n;

- (void)updateProgressIndicator;

- (int)sendDidChangeNotification;

- (oneway void)endOperation;

@end

@protocol FileOpExecutorProtocol

+ (void)setPorts:(NSArray *)thePorts;

- (void)setFileop:(NSArray *)thePorts;

- (BOOL)setOperation:(NSDictionary *)opDict;

- (BOOL)checkSameName;

- (oneway void)calculateNumFiles;

- (oneway void)performOperation;

- (NSString *)processedFiles;

- (void)Pause;

- (void)Stop;

- (BOOL)isPaused;

- (void)done;

@end

@interface FileOperation: NSObject <FileOpProtocol>
{
	NSString *operation;
	NSString *source;
	NSString *destination;
	NSMutableArray *files;
  NSMutableDictionary *operationDict;
  NSMutableArray *notifNames;
  int fileOperationRef;
  int filescount;
  BOOL confirm;
  BOOL showwin;
  BOOL opdone;
  NSConnection *execconn;
  id <FileOpExecutorProtocol> executor;
  NSTimer *timer;
  NSNotificationCenter *dnc;
  NSFileManager *fm;
  GWorkspace *gw;

  IBOutlet id win;
  IBOutlet id fromLabel;
  IBOutlet id fromField;
  IBOutlet id toLabel;
  IBOutlet id toField;
  IBOutlet id progInd;
  IBOutlet id pauseButt;
  IBOutlet id stopButt;  
}

- (id)initWithOperation:(NSString *)opr
                 source:(NSString *)src
		 	      destination:(NSString *)dest
                  files:(NSArray *)fls
        useConfirmation:(BOOL)conf
             showWindow:(BOOL)showw
             windowRect:(NSRect)wrect;

- (void)checkExecutor:(id)sender;

- (BOOL)showFileOperationAlert;

- (void)showProgressWin;

- (void)sendWillChangeNotification;

- (IBAction)pause:(id)sender;

- (IBAction)stop:(id)sender;

- (int)fileOperationRef;

- (NSRect)winRect;

- (BOOL)showsWindow;
                 
@end


@interface FileOpExecutor: NSObject <FileOpExecutorProtocol>
{
	NSString *operation;
	NSString *source;
	NSString *destination;
	NSMutableArray *files;
	NSMutableArray *procfiles;
	NSString *filename;
	int fcount;
	BOOL stopped;
	BOOL paused;
	BOOL canupdate;
  BOOL samename;
  NSFileManager *fm;
  NSConnection *fopConn;
  id <FileOpProtocol> fileOp;
}

- (void)doMove;

- (void)doCopy;

- (void)doLink;

- (void)doRemove;

- (void)doDuplicate;

- (void)removeExisting:(NSString *)fname;

@end 

#endif // FILEOPERATION_H
