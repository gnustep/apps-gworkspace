/* smbfileop.h
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

#ifndef SMB_FILE_OP_H
#define SMB_FILE_OP_H

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <SMBKit/SMBKit.h>
#include <SMBKit/SMBFileManager.h>
#include <SMBKit/SMBFileHandle.h>

@protocol GWNetdProtocol

- (void)registerFileOperation:(id)anObject;

- (void)fileOperationStarted:(NSData *)opinfo;

- (void)fileOperationUpdated:(NSData *)opinfo;

- (void)fileTransferStarted:(NSData *)opinfo;

- (void)fileTransferUpdated:(NSData *)opinfo;

- (BOOL)fileOperationError:(NSData *)opinfo;

- (oneway void)fileOperationDone:(NSData *)opinfo;

@end 

enum {
  UPLOAD,
  DOWNLOAD,
  DELETE,
  DUPLICATE,
  RENAME,
  NEWFOLDER
};

@interface SMBFileOp: NSObject 
{
  NSString *hosturl;
  NSString *usrname;
  NSString *usrpass;
  NSString *source;
  NSString *destination;
  NSArray *files;
  int ref;
  int type;
  BOOL stopped;
  int fcount;
  unsigned long long fsize;
  NSMutableDictionary *opinfo;
  id <GWNetdProtocol> gwnetd;
  SMBFileManager *manager;
  NSFileManager *fm;
}

- (id)initWithArgc:(int)argc argv:(char **)argv;

- (void)registerWithGwnetd;

- (oneway void)setOperation:(NSData *)d;

- (oneway void)performOperation;

- (void)operationDone;

- (oneway void)stopOperation;

- (BOOL)uploadLocalPath:(NSString *)lpath
            toRemoteUrl:(NSString *)rurl;

- (BOOL)uploadDirectoryContentsAtPath:(NSString *)lpath
                          toRemoteUrl:(NSString *)rurl;

- (BOOL)uploadFileContentsAtPath:(NSString *)lpath
                     toRemoteUrl:(NSString *)rurl;
                     
- (BOOL)downloadRemoteUrl:(NSString *)rurl
              toLocalPath:(NSString *)lpath;
              
- (BOOL)downloadDirectoryContentsAtUrl:(NSString *)rurl
                           toLocalPath:(NSString *)lpath;
                     
- (BOOL)downloadFileContentsAtUrl:(NSString *)rurl
                      toLocalPath:(NSString *)lpath;
                      
- (BOOL)removeRemoteUrl:(NSString *)rurl;
                      
- (void)calculateLocalSizes;

- (void)calculateRemoteSizes;

- (void)flush;

- (void)connectionDidDie:(NSNotification *)notification;


//
// SMBFileManagerHandler delegate methods
//
- (BOOL)smbFileManager:(SMBFileManager *)fileManager
        shouldProceedAfterError:(NSDictionary *)errorDictionary;

- (void)smbFileManager:(SMBFileManager *)fileManager
        willProcessUrl:(NSString *)url;

@end

#endif // SMB_FILE_OP_H
