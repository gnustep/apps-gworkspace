/* ftpfileop.h
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef FTP_FILE_OP_H
#define FTP_FILE_OP_H

#include <Foundation/Foundation.h>

@class FTPDirectoryEnumerator;

@protocol GWNetdProtocol

- (void)registerFileOperation:(id)anObject;

- (void)fileOperationStarted:(NSData *)opinfo;

- (void)fileOperationUpdated:(NSData *)opinfo;

- (void)fileTransferStarted:(NSData *)opinfo;

- (void)fileTransferUpdated:(NSData *)opinfo;

- (BOOL)fileOperationError:(NSData *)opinfo;

- (oneway void)fileOperationDone:(NSData *)opinfo;

@end 

@interface FTPFileOp: NSObject 
{
  NSString *hostname;
  NSString *usrname;
  NSString *usrpass;
  
  NSFileHandle *sockHandle;
  BOOL usePasv;
  
  NSString *source;
  NSString *destination;
  NSArray *files;
  int ref;
  int type;
  NSMutableDictionary *lastContents;
  NSString *lastError;
  BOOL stopped;
  int fcount;
  unsigned long long fsize;
  NSMutableDictionary *opinfo;
  id <GWNetdProtocol> gwnetd;
  NSFileManager *fm;
  
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
}

- (id)initWithArgc:(int)argc argv:(char **)argv;

- (void)registerWithGwnetd;

- (oneway void)setOperation:(NSData *)d;

- (oneway void)performOperation;

- (void)operationDone;

- (oneway void)stopOperation;

- (BOOL)uploadLocalPath:(NSString *)lpath
           toRemotePath:(NSString *)rpath;

- (BOOL)uploadDirectoryContentsAtPath:(NSString *)lpath
                         toRemotePath:(NSString *)rpath;
                         
- (BOOL)uploadFileContentsAtPath:(NSString *)lpath
                    toRemotePath:(NSString *)rpath;
                         
- (BOOL)downloadRemotePath:(NSString *)rpath
               toLocalPath:(NSString *)lpath;
              
- (BOOL)downloadDirectoryContentsAtPath:(NSString *)rpath
                            toLocalPath:(NSString *)lpath;
                     
- (BOOL)downloadFileContentsAtPath:(NSString *)rpath
                       toLocalPath:(NSString *)lpath;
                      
- (BOOL)removeRemotePath:(NSString *)rpath;

- (BOOL)removeRemoteDirectory:(NSString *)rpath;

- (BOOL)removeRemoteFile:(NSString *)rpath;

- (BOOL)createRemoteDirectory:(NSString *)rpath;

- (NSArray *)remoteContentsAtPath:(NSString *)path;

- (NSString *)typeOfFileAtPath:(NSString *)rpath;

- (long)sizeOfFileAtPath:(NSString *)rpath;

- (void)calculateLocalSizes;

- (void)calculateRemoteSizes;

- (FTPDirectoryEnumerator *)enumeratorAtPath:(NSString *)path;

- (void)flush;

- (void)connectionDidDie:(NSNotification *)notification;


//
// ftp commands methods
//
- (int)sendCommand:(NSString *)str 
         withParam:(NSString *)param
          getError:(NSString **)errstr; 

- (int)getReply:(NSString **)errstr;

- (NSString *)readControlLine;

- (void)flushControlLine:(NSString *)codestr;

- (NSFileHandle *)getDataHandle;

- (NSFileHandle *)fileHandleForConnectingAtPort:(unsigned)port;

- (NSFileHandle *)fileHandleForWithLocalPort;

- (NSData *)readDataFrom:(NSFileHandle *)handle;

- (NSString *)readStringFrom:(NSFileHandle *)handle;

@end


@interface FTPDirectoryEnumerator: NSObject
{
  NSMutableArray *stack;
  NSString *topPath;
  NSString *currentFilePath;
  FTPFileOp *fileop;
}

- (id)initWithDirectoryPath:(NSString *)path 
                  ftpFileOp:(FTPFileOp *)op;

- (NSDictionary *)nextObject;

- (void)skipDescendents;

@end

#endif // FTP_FILE_OP_H








