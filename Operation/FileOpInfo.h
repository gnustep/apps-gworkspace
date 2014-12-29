/* FileOpInfo.h
 *  
 * Copyright (C) 2004-2014 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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


#import <Foundation/Foundation.h>

@class FileOpExecutor;

@class NSWindow;
@class NSTextField;
@class NSButton;
@class NSProgressIndicator;

@protocol FileOpInfoProtocol

- (void)registerExecutor:(id)anObject;
                            
- (NSInteger)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (NSInteger)showErrorAlertWithMessage:(NSString *)message;

- (void)setNumFiles:(int)n;

- (void)setProgIndicatorValue:(int)n;

- (void)sendDidChangeNotification;

- (void)removeProcessedFiles;

- (void)cleanUpExecutor;

- (void)endOperation;

@end


@protocol FileOpExecutorProtocol

+ (void)setPorts:(NSArray *)thePorts;

- (void)setFileop:(NSArray *)thePorts;

- (BOOL)setOperation:(NSData *)opinfo;

- (BOOL)checkSameName;

- (void)setOnlyOlder:(BOOL)flag;

- (oneway void)calculateNumFiles:(NSUInteger)continueFrom;

- (oneway void)performOperation;

- (NSData *)processedFiles;

- (oneway void)Pause;

- (oneway void)Stop;

- (BOOL)isPaused;

@end


@interface FileOpInfo: NSObject
{
  NSString *type;
  NSString *source;
  NSString *destination;
  NSMutableArray *files;
  NSMutableArray *dupfiles;
  NSMutableArray *procFiles;
  int ref;
  
  NSMutableDictionary *operationDict;
  NSMutableArray *notifNames;

  BOOL confirm;
  BOOL showwin;
  BOOL opdone;
  BOOL onlyOlder;
  NSConnection *execconn;
  id <FileOpExecutorProtocol> executor;
  NSNotificationCenter *nc;
  NSNotificationCenter *dnc;
  NSFileManager *fm;
    
  id controller;  

  IBOutlet NSWindow *win;
  IBOutlet NSTextField *fromLabel;
  IBOutlet NSTextField *fromField;
  IBOutlet NSTextField *toLabel;
  IBOutlet NSTextField *toField;
  IBOutlet NSProgressIndicator *progInd;
  IBOutlet NSButton *pauseButt;
  IBOutlet NSButton *stopButt;  
}

+ (id)operationOfType:(NSString *)tp
                  ref:(int)rf
               source:(NSString *)src
          destination:(NSString *)dst
                files:(NSArray *)fls
         confirmation:(BOOL)conf
            usewindow:(BOOL)uwnd
              winrect:(NSRect)wrect
           controller:(id)cntrl;

- (id)initWithOperationType:(NSString *)tp
                        ref:(int)rf
                     source:(NSString *)src
                destination:(NSString *)dst
                      files:(NSArray *)fls
               confirmation:(BOOL)conf
                  usewindow:(BOOL)uwnd
                    winrect:(NSRect)wrect
                 controller:(id)cntrl;

- (void)startOperation;

- (void)detachOperationThread;

- (NSInteger)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (NSInteger)showErrorAlertWithMessage:(NSString *)message;

- (IBAction)pause:(id)sender;

- (IBAction)stop:(id)sender;

- (void)showProgressWin;

- (void)setNumFiles:(int)n;

- (void)setProgIndicatorValue:(int)n;

- (void)removeProcessedFiles;

- (void)cleanUpExecutor;

- (void)endOperation;

- (void)sendWillChangeNotification;

- (void)sendDidChangeNotification;

- (void)registerExecutor:(id)anObject;

- (void)connectionDidDie:(NSNotification *)notification;

- (NSString *)type;

- (NSString *)source;

- (NSString *)destination;

- (NSArray *)files;

- (NSArray *)dupfiles;

- (int)ref;

- (BOOL)showsWindow;

- (NSWindow *)win;

- (void)getWinRect: (NSRect*)rptr;

@end 


@interface FileOpExecutor: NSObject
{
  NSString *operation;
  NSString *source;
  NSString *destination;
  NSMutableArray *files;
  NSMutableArray *procfiles;
  NSDictionary *fileinfo;
  NSString *filename;
  int fcount;
  float progstep;
  int stepcount;
  BOOL canupdate;
  BOOL samename;
  BOOL onlyolder;
  NSFileManager *fm;
  id <FileOpInfoProtocol> fileOp;
}

+ (void)setPorts:(NSArray *)thePorts;

- (void)setFileop:(NSArray *)thePorts;

- (BOOL)setOperation:(NSData *)opinfo;

- (BOOL)checkSameName;

- (oneway void)calculateNumFiles:(NSUInteger)continueFrom;

- (oneway void)performOperation;

- (NSData *)processedFiles;

- (void)doMove;

- (void)doCopy;

- (void)doLink;

- (void)doRemove;

- (void)doDuplicate;

- (void)doRename;

- (void)doNewFolder;

- (void)doNewFile;

- (void)doTrash;

- (BOOL)removeExisting:(NSDictionary *)info;

- (NSDictionary *)infoForFilename:(NSString *)name;

@end 


@protocol FMProtocol

- (BOOL)_copyPath:(NSString *)source
	         toPath:(NSString *)destination
	        handler:(id)handler;

- (BOOL)_copyFile:(NSString *)source
	         toFile:(NSString *)destination
	        handler:(id)handler;

- (void)_sendToHandler:(id)handler
       willProcessPath:(NSString *)path;

- (BOOL)_proceedAccordingToHandler:(id)handler
                          forError:(NSString *)error
                            inPath:(NSString *)path;

- (BOOL)_proceedAccordingToHandler:(id)handler
                          forError:(NSString *)error
                            inPath:(NSString *)path
                          fromPath:(NSString *)fromPath
                            toPath:(NSString *)toPath;

@end

