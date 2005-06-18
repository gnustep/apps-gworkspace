/* ftpfileop.m
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

#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include "ftpfileop.h"

#define	NETBUF_SIZE	1024

#ifndef WILL
  #define	WILL 251
  #define	WONT 252
  #define	DO 253
  #define	DONT 254
  #define	IAC 255
#endif

#define MAKEDATA(d) [NSArchiver archivedDataWithRootObject: d]

#define ERROR(s) \
[opinfo setObject: s forKey: @"errorstr"]; \
[opinfo setObject: [NSNumber numberWithBool: NO] forKey: @"cancontinue"]; \
[gwnetd fileOperationError: MAKEDATA (opinfo)]; \
[self operationDone]


@implementation FTPFileOp

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];

  TEST_RELEASE (hostname);
  TEST_RELEASE (usrname);
  TEST_RELEASE (usrpass);
  TEST_RELEASE (sockHandle);
    
  TEST_RELEASE (source);
  TEST_RELEASE (destination);
  TEST_RELEASE (files);
  TEST_RELEASE (opinfo);
  
  TEST_RELEASE (lastContents);
    
	[super dealloc];
}

- (id)initWithArgc:(int)argc argv:(char **)argv
{  
	self = [super init];
  
  if(self) {
    NSString *refStr;
    NSString *connName;
    NSConnection *connection;
    id anObject;
    
    fm = [NSFileManager defaultManager];
    
    ref = [[NSString stringWithCString: argv[1]] intValue];   
    refStr = [NSString stringWithCString: argv[2]];   
    
    connName = [NSString stringWithFormat: @"ftp_fileop_ref_%@_%i", refStr, ref];

    connection = [NSConnection connectionWithRegisteredName: connName host: @""];
    if (connection == nil) {
      NSLog(@"ftpfileop - failed to get the connection - bye.");
	    exit(1);               
    }

    anObject = [connection rootProxy];
    
    if (anObject == nil) {
      NSLog(@"ftpfileop - failed to contact gwnetd - bye.");
	    exit(1);           
    } 

    [anObject setProtocolForProxy: @protocol(GWNetdProtocol)];
    gwnetd = (id <GWNetdProtocol>)anObject;
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                            selector: @selector(connectionDidDie:)
                                name: NSConnectionDidDieNotification
                              object: connection];    
    fcount = 0;
		stopped = NO;
  }
    
	return self;
}

- (void)registerWithGwnetd
{
  [gwnetd registerFileOperation: self];  
}

- (oneway void)setOperation:(NSData *)d
{
  NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: d];
  id entry;
  NSString *errStr;
  int rep = 0;
      
  ASSIGN (hostname, [info objectForKey: @"hostname"]);
  
  entry = [info objectForKey: @"usrname"];
  if (entry) {
    ASSIGN (usrname, entry);
  } else {
    ASSIGN (usrname, [NSString stringWithString: @"anonymous"]);
  }

  entry = [info objectForKey: @"usrpass"];
  if (entry) {
    ASSIGN (usrpass, entry);
  } else {
    ASSIGN (usrpass, [NSString stringWithString: @"anonymous"]);
  }

  usePasv = [[info objectForKey: @"usepasv"] boolValue];
  
  ASSIGN (source, [info objectForKey: @"source"]);
  ASSIGN (destination, [info objectForKey: @"destination"]);
  ASSIGN (files, [info objectForKey: @"files"]);    

  type = [[info objectForKey: @"type"] intValue];
    
  opinfo = [NSMutableDictionary new];
  [opinfo setObject: [NSNumber numberWithInt: ref] forKey: @"ref"];    
  [opinfo setObject: [NSNumber numberWithInt: type] forKey: @"type"];        
  
  sockHandle = [self fileHandleForConnectingAtPort: 21];
  if (sockHandle == nil) {
    ERROR (@"no socket!");
    exit(0);    
  }
  
  RETAIN (sockHandle);

  rep = [self getReply: &errStr];
  if (rep != 220) {
    ERROR (errStr);
  }

  rep = [self sendCommand: @"USER" withParam: usrname getError: &errStr];
  if (rep != 331) {
    ERROR (errStr);
  }
          
  rep = [self sendCommand: @"PASS" withParam: usrpass getError: &errStr];
  if (rep != 230) {
    ERROR (errStr);
  }
}

- (oneway void)performOperation
{
  int i;

  switch (type) {
    case UPLOAD:
      {
        [self calculateLocalSizes];
        [opinfo setObject: [NSNumber numberWithInt: fcount] forKey: @"fcount"];
  
        [gwnetd fileOperationStarted: MAKEDATA (opinfo)];

        for (i = 0; i < [files count]; i++) {
          NSString *fname, *srcPath, *destPath;
          
          fname = [files objectAtIndex: i];
          srcPath = [source stringByAppendingPathComponent: fname];
          destPath = [destination stringByAppendingPathComponent: fname];

          if ([self uploadLocalPath: srcPath toRemotePath: destPath] == NO) {
            [opinfo setObject: [NSString stringWithFormat: @"uploading %@", fname] 
                       forKey: @"errorstr"];
            [opinfo setObject: [NSNumber numberWithBool: NO] 
                       forKey: @"cancontinue"];            
            if ([gwnetd fileOperationError: MAKEDATA (opinfo)] == NO) {
              break;
            }
          }

          [self flush];
          
          if (stopped) {
            break;
          } 
        }
        
        [self operationDone];
      }
      break;

    case DOWNLOAD:
      {
        [self calculateRemoteSizes];
        [opinfo setObject: [NSNumber numberWithInt: fcount] forKey: @"fcount"];
        [gwnetd fileOperationStarted: MAKEDATA (opinfo)];
        
        for (i = 0; i < [files count]; i++) {
          NSString *fname, *srcPath, *dstPath;
          
          fname = [files objectAtIndex: i];
          srcPath = [source stringByAppendingPathComponent: fname];
          dstPath = [destination stringByAppendingPathComponent: fname];
          
          if ([self downloadRemotePath: srcPath toLocalPath: dstPath] == NO) {
            [opinfo setObject: [NSString stringWithFormat: @"downloading %@", fname] 
                       forKey: @"errorstr"];
            [opinfo setObject: [NSNumber numberWithBool: YES] 
                       forKey: @"cancontinue"];
            if ([gwnetd fileOperationError: MAKEDATA (opinfo)] == NO) {
              break;
            }
          }
      
          [self flush];
          
          if (stopped) {
            break;
          } 
        }
        
        [self operationDone];
      }
      break;

    case DELETE:
      {
        [self calculateRemoteSizes];
        [opinfo setObject: [NSNumber numberWithInt: fcount] forKey: @"fcount"];
        [gwnetd fileOperationStarted: MAKEDATA (opinfo)];
        
        for (i = 0; i < [files count]; i++) {
          NSString *fname, *fpath;
          
          fname = [files objectAtIndex: i];
          fpath = [destination stringByAppendingPathComponent: fname];
          
          if ([self removeRemotePath: fpath] == NO) {
            [opinfo setObject: [NSString stringWithFormat: @"deleting %@", fname] 
                       forKey: @"errorstr"];
            [opinfo setObject: [NSNumber numberWithBool: NO] 
                       forKey: @"cancontinue"];
            if ([gwnetd fileOperationError: MAKEDATA (opinfo)] == NO) {
              break;
            }
          }
          
          [self flush];
          
          if (stopped) {
            break;
          } 
        }
      
        [self operationDone];
      }
      break;

    case RENAME:
      {
        NSString *fname;
        NSString *errStr;
        int rep;
        
        [opinfo setObject: [NSNumber numberWithInt: 1] forKey: @"fcount"];
        [gwnetd fileOperationStarted: MAKEDATA (opinfo)];
        
        fname = [source lastPathComponent];
        
        rep = [self sendCommand: @"RNFR" withParam: source getError: &errStr];
        
        if (rep == 350) {
          rep = [self sendCommand: @"RNTO" withParam: destination getError: &errStr];
          
          if (rep != 250) {
            [opinfo setObject: [NSString stringWithFormat: @"renaming %@", fname] 
                       forKey: @"errorstr"];
            [opinfo setObject: [NSNumber numberWithBool: NO] 
                       forKey: @"cancontinue"];
            [gwnetd fileOperationError: MAKEDATA (opinfo)];
          }
          
        } else {
          [opinfo setObject: [NSString stringWithFormat: @"renaming %@", fname] 
                     forKey: @"errorstr"];
          [opinfo setObject: [NSNumber numberWithBool: NO] 
                     forKey: @"cancontinue"];
          [gwnetd fileOperationError: MAKEDATA (opinfo)];
        }
        
        [self operationDone];
      }
      break;

    case NEWFOLDER:
      {
        NSString *fname, *fpath;
        
        fname = [files objectAtIndex: 0];
        fpath = [destination stringByAppendingPathComponent: fname];
              
        [opinfo setObject: [NSNumber numberWithInt: 1] forKey: @"fcount"];
        [gwnetd fileOperationStarted: MAKEDATA (opinfo)];
        
        if ([self createRemoteDirectory: fpath] == NO) {
          [opinfo setObject: [NSString stringWithFormat: @"creating %@", fname] 
                     forKey: @"errorstr"];
          [opinfo setObject: [NSNumber numberWithBool: NO] 
                     forKey: @"cancontinue"];
          [gwnetd fileOperationError: MAKEDATA (opinfo)];
        }
              
        [self operationDone];
      }
      break;

    default:
      [self operationDone];
  }
}

- (void)operationDone
{
  NSString *errStr;
  [self sendCommand: @"QUIT" withParam: nil getError: &errStr];
  [gwnetd fileOperationDone: MAKEDATA (opinfo)];
  exit(0);
}

- (oneway void)stopOperation
{
  stopped = YES;
}

- (BOOL)uploadLocalPath:(NSString *)lpath
           toRemotePath:(NSString *)rpath
{
  NSDictionary *attrs = [fm fileAttributesAtPath: lpath traverseLink: NO];
  NSString *fname = [lpath lastPathComponent];
  NSString *fileType;
  
  if (attrs == nil) {
    return NO;
  }

  [opinfo setObject: lpath forKey: @"source"];
  [opinfo setObject: rpath forKey: @"destination"];
  [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];
  
  fileType = [attrs fileType];

  if ([fileType isEqual: NSFileTypeDirectory]) {
    if ([self createRemoteDirectory: rpath] == NO) {
      [opinfo setObject: [NSString stringWithFormat: @"uploading %@", fname] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];
      return [gwnetd fileOperationError: MAKEDATA (opinfo)];
	  }

    if ([self uploadDirectoryContentsAtPath: lpath 
                               toRemotePath: rpath] == NO) {
	    return NO;
	  }
    
  } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
    [opinfo setObject: [NSString stringWithFormat: 
                      @"'%@' symbolik links not supported by ftp protocol", fname] 
               forKey: @"errorstr"];
    [opinfo setObject: [NSNumber numberWithBool: YES] 
               forKey: @"cancontinue"];
    return [gwnetd fileOperationError: MAKEDATA (opinfo)];

  } else {
	  if ([self uploadFileContentsAtPath: lpath
			                    toRemotePath: rpath] == NO) {
	    return NO;
    }
  }

  return YES;
}

- (BOOL)uploadDirectoryContentsAtPath:(NSString *)lpath
                         toRemotePath:(NSString *)rpath
{
  NSDirectoryEnumerator *enumerator;
  NSString *dirEntry;
  CREATE_AUTORELEASE_POOL (pool);

  enumerator = [fm enumeratorAtPath: lpath];

  while ((dirEntry = [enumerator nextObject])) {
    NSString *sourceFile = [lpath stringByAppendingPathComponent: dirEntry];
    NSString *destinationFile = [rpath stringByAppendingPathComponent: dirEntry];
    NSString *fname = [sourceFile lastPathComponent];
    NSDictionary *attributes = [fm fileAttributesAtPath: sourceFile traverseLink: NO];
    NSString *fileType = [attributes fileType];

    [opinfo setObject: sourceFile forKey: @"source"];
    [opinfo setObject: destinationFile forKey: @"destination"];
    [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];
    
    if ([fileType isEqual: NSFileTypeDirectory]) {
      if ([self createRemoteDirectory: destinationFile] == NO) {
        [opinfo setObject: [NSString stringWithFormat: @"uploading %@", fname] 
                   forKey: @"errorstr"];
        [opinfo setObject: [NSNumber numberWithBool: YES] 
                   forKey: @"cancontinue"];
        if ([gwnetd fileOperationError: MAKEDATA (opinfo)] == NO) {
          RELEASE (pool);
          return NO;
        }
	    } else {
        [enumerator skipDescendents];

        if ([self uploadDirectoryContentsAtPath: sourceFile 
                                   toRemotePath: destinationFile] == NO) {
          RELEASE (pool);                          
	        return NO;
	      }
      }

    } else if ([fileType isEqual: NSFileTypeRegular]) {
	    if ([self uploadFileContentsAtPath: sourceFile
			                      toRemotePath: destinationFile] == NO) {
        RELEASE (pool);                           
	      return NO;
      }
  
    } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
      [opinfo setObject: [NSString stringWithFormat: 
                      @"'%@' symbolik links not supported by ftp protocol", fname] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];                 
      if ([gwnetd fileOperationError: MAKEDATA (opinfo)] == NO) {
        RELEASE (pool);
        return NO;
      }
      
    } else {
      [opinfo setObject: [NSString stringWithFormat: @"cannot copy %@", fname] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];                 
      if ([gwnetd fileOperationError: MAKEDATA (opinfo)] == NO) {
        RELEASE (pool);
        return NO;
      }
    }
    
    if (stopped) {
      RELEASE (pool);
      return YES;
    } 
    
    [self flush];
  }
  
  RELEASE (pool);
  
  return YES;
}

- (BOOL)uploadFileContentsAtPath:(NSString *)lpath
                    toRemotePath:(NSString *)rpath
{
  NSDictionary *attributes;
  NSFileHandle *srcHandle;
  NSFileHandle *dstHandle;
  NSData *data;
  int fileSize;
  int rbytes;
  int rep;
  
#define UPLOAD_ERR(s) \
[opinfo setObject: s forKey: @"errorstr"]; \
[opinfo setObject: [NSNumber numberWithBool: YES] forKey: @"cancontinue"]; \
return [gwnetd fileOperationError: MAKEDATA (opinfo)]

  attributes = [fm fileAttributesAtPath: lpath traverseLink: NO];
  fileSize = [attributes fileSize];
  [opinfo setObject: [NSNumber numberWithInt: fileSize] forKey: @"fsize"];
  [gwnetd fileTransferStarted: MAKEDATA (opinfo)];

  srcHandle = [NSFileHandle fileHandleForReadingAtPath: lpath];
  if (srcHandle == nil) {
    UPLOAD_ERR (([NSString stringWithFormat: @"cannot open file for reading %@", lpath]));
  }

  rep = [self sendCommand: @"TYPE" withParam: @"I" getError: &lastError];
  if (rep >= 500) {
    UPLOAD_ERR (lastError);
  }

  dstHandle = [self getDataHandle];
  if (dstHandle == nil) {
    [srcHandle closeFile];
    UPLOAD_ERR (([NSString stringWithFormat: @"cannot open file for writing %@", rpath]));
  }

  rep = [self sendCommand: @"STOR" withParam: rpath getError: &lastError];
  if (rep >= 500) {
    [srcHandle closeFile];
    [dstHandle closeFile];
    UPLOAD_ERR (lastError);
  } else {
    if (usePasv == NO) {
      NSFileHandle *newhandle;
      struct sockaddr_in cli_addr;
      int clilen = sizeof(cli_addr);
      int sockfd;

      sockfd = accept([dstHandle fileDescriptor], (struct sockaddr *) &cli_addr, &clilen);

      if (sockfd < 0) {
	      ERROR (@"no socket!");
      }

      newhandle = [[NSFileHandle alloc] initWithFileDescriptor: sockfd
                                                closeOnDealloc: YES];
      [dstHandle closeFile];
      dstHandle = AUTORELEASE (newhandle);
    }
  }

  data = [srcHandle readDataOfLength: NETBUF_SIZE];
  rbytes = [data length];

  if (rbytes < 0) {
    [srcHandle closeFile];
    [dstHandle closeFile];
    UPLOAD_ERR (([NSString stringWithFormat: @"cannot read from file %@", rpath]));
	}

  [opinfo setObject: [NSNumber numberWithInt: rbytes] forKey: @"increment"];
  [gwnetd fileTransferUpdated: MAKEDATA (opinfo)];

	while ([data length] > 0) {
    NS_DURING
      [dstHandle writeData: data];   
	  NS_HANDLER
      [srcHandle closeFile];
      [dstHandle closeFile];
      UPLOAD_ERR (([NSString stringWithFormat: @"cannot write to file %@", lpath]));
	  NS_ENDHANDLER  
     
    data = [srcHandle readDataOfLength: NETBUF_SIZE];
    rbytes = [data length];
            
    if (rbytes < 0) {
      [srcHandle closeFile];
      [dstHandle closeFile];
      UPLOAD_ERR (([NSString stringWithFormat: @"cannot read from file %@", rpath]));
	  }

    [opinfo setObject: [NSNumber numberWithInt: rbytes] forKey: @"increment"];
    [gwnetd fileTransferUpdated: MAKEDATA (opinfo)];
    
    if (stopped) {
      break;
    } 
    
    [self flush];
	}
  
  [srcHandle closeFile];
  [dstHandle closeFile];

  return YES;
}

- (BOOL)downloadRemotePath:(NSString *)rpath
               toLocalPath:(NSString *)lpath
{
  NSString *fname = [rpath lastPathComponent];
  NSString *fileType = [self typeOfFileAtPath: rpath];

  if (fileType == nil) {
    return NO;
  }
  
  [opinfo setObject: rpath forKey: @"source"];
  [opinfo setObject: rpath forKey: @"destination"];
  [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];

  if ([fileType isEqual: NSFileTypeDirectory]) {
    if ([fm createDirectoryAtPath: lpath attributes: nil] == NO) {
      [opinfo setObject: [NSString stringWithFormat: @"downloading %@", fname] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];
      return [gwnetd fileOperationError: MAKEDATA (opinfo)];
	  }

    if ([self downloadDirectoryContentsAtPath: rpath
                                  toLocalPath: lpath] == NO) {
	    return NO;
	  }

  } else if ([fileType isEqual: NSFileTypeSymbolicLink]) { 
    [opinfo setObject: [NSString stringWithFormat: 
                      @"'%@' symbolik links not supported by ftp protocol", fname] 
               forKey: @"errorstr"];
    [opinfo setObject: [NSNumber numberWithBool: YES] 
               forKey: @"cancontinue"];
    return [gwnetd fileOperationError: MAKEDATA (opinfo)];
    
  } else {
	  if ([self downloadFileContentsAtPath: rpath
			                       toLocalPath: lpath] == NO) {
	    return NO;
    }
  }

  return YES;
}
              
- (BOOL)downloadDirectoryContentsAtPath:(NSString *)rpath
                            toLocalPath:(NSString *)lpath
{
  FTPDirectoryEnumerator *enumerator;
  NSDictionary *dirEntry;
  CREATE_AUTORELEASE_POOL (pool);

  enumerator = [self enumeratorAtPath: rpath];
  
  while ((dirEntry = [enumerator nextObject])) {
    NSString *fileName = [dirEntry objectForKey: @"name"];
    NSString *fileType = [dirEntry objectForKey: @"NSFileType"];
    NSString *sourceFile = [rpath stringByAppendingPathComponent: fileName];
    NSString *destinationFile = [lpath stringByAppendingPathComponent: fileName];
    NSString *fname = [destinationFile lastPathComponent];
  
    [opinfo setObject: sourceFile forKey: @"source"];
    [opinfo setObject: destinationFile forKey: @"destination"];
    [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];
  
    if ([fileType isEqual: NSFileTypeDirectory]) {
      if ([fm createDirectoryAtPath: destinationFile attributes: nil] == NO) {
        [opinfo setObject: [NSString stringWithFormat: @"downloading %@", fname] 
                   forKey: @"errorstr"];
        [opinfo setObject: [NSNumber numberWithBool: YES] 
                   forKey: @"cancontinue"];        
        if ([gwnetd fileOperationError: MAKEDATA (opinfo)] == NO) {
          RELEASE (pool);
          return NO;
        }
	    } else {
        [enumerator skipDescendents];

        if ([self downloadDirectoryContentsAtPath: sourceFile 
                                      toLocalPath: destinationFile] == NO) {
          RELEASE (pool);                          
	        return NO;
	      }
      }

    } else if ([fileType isEqual: NSFileTypeRegular]) {
	    if ([self downloadFileContentsAtPath: sourceFile
			                         toLocalPath: destinationFile] == NO) {
        RELEASE (pool);                           
	      return NO;
      }

    } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
      [opinfo setObject: [NSString stringWithFormat: 
                      @"'%@' symbolik links not supported by ftp protocol", fname] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];                 
      if ([gwnetd fileOperationError: MAKEDATA (opinfo)] == NO) {
        RELEASE (pool);
        return NO;
      }
      
    } else {
      [opinfo setObject: [NSString stringWithFormat: @"cannot copy %@", fname] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: NO] 
                 forKey: @"cancontinue"];
	    [gwnetd fileOperationError: MAKEDATA (opinfo)];
      continue;    
    }  
    
    if (stopped) {
      RELEASE (pool);
      return YES;
    } 
    
    [self flush];
  }

  return YES;
}
                     
- (BOOL)downloadFileContentsAtPath:(NSString *)rpath
                       toLocalPath:(NSString *)lpath
{
  NSFileHandle *srcHandle;
  NSFileHandle *dstHandle;
  NSData *data;
  int rbytes;
  int rep;
  int filesize;

#define DOWNLOAD_ERR(s) \
[opinfo setObject: s forKey: @"errorstr"]; \
[opinfo setObject: [NSNumber numberWithBool: YES] forKey: @"cancontinue"]; \
return [gwnetd fileOperationError: MAKEDATA (opinfo)]

  rep = [self sendCommand: @"TYPE" withParam: @"I" getError: &lastError];
  if (rep >= 500) {
    DOWNLOAD_ERR (lastError);
  }

  srcHandle = [self getDataHandle];
  if (srcHandle == nil) {
    DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot open file for reading %@", rpath]));
  }

  rep = [self sendCommand: @"RETR" withParam: rpath getError: &lastError];
  if (rep >= 500) {
    [srcHandle closeFile];
    DOWNLOAD_ERR (lastError);
  } else {
    if (usePasv == NO) {
      NSFileHandle *newhandle;
      struct sockaddr_in cli_addr;
      int clilen = sizeof(cli_addr);
      int sockfd;

      sockfd = accept([srcHandle fileDescriptor], (struct sockaddr *) &cli_addr, &clilen);

      if (sockfd < 0) {
	      ERROR (@"no socket!");
      }

      newhandle = [[NSFileHandle alloc] initWithFileDescriptor: sockfd
                                                closeOnDealloc: YES];
      [srcHandle closeFile];
      srcHandle = AUTORELEASE (newhandle);
    }
  }

  filesize = [self sizeOfFileAtPath: rpath];
  [opinfo setObject: [NSNumber numberWithInt: filesize] forKey: @"fsize"];
  [gwnetd fileTransferStarted: MAKEDATA (opinfo)];
  
  if ([fm createFileAtPath: lpath contents: nil attributes: nil] == NO) {
    [srcHandle closeFile];
    DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot create %@", lpath]));
  }

  dstHandle = [NSFileHandle fileHandleForWritingAtPath: lpath];
  if (dstHandle == nil) {
    [srcHandle closeFile];
    DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot open file for writing %@", lpath]));
  }

  data = [srcHandle readDataOfLength: NETBUF_SIZE];
  rbytes = [data length];
  
  if (rbytes < 0) {
    [srcHandle closeFile];
    [dstHandle closeFile];
    DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot read from file %@", rpath]));
	}

  [opinfo setObject: [NSNumber numberWithInt: rbytes] forKey: @"increment"];
  [gwnetd fileTransferUpdated: MAKEDATA (opinfo)];

	while ([data length] > 0) {
    NS_DURING
      [dstHandle writeData: data];   
	  NS_HANDLER
      [srcHandle closeFile];
      [dstHandle closeFile];
      DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot write to file %@", lpath]));
	  NS_ENDHANDLER  
     
    data = [srcHandle readDataOfLength: NETBUF_SIZE];
    rbytes = [data length];
      
    if (rbytes < 0) {
      [srcHandle closeFile];
      [dstHandle closeFile];
      DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot read from file %@", rpath]));
	  }
    
    [opinfo setObject: [NSNumber numberWithInt: rbytes] forKey: @"increment"];
    [gwnetd fileTransferUpdated: MAKEDATA (opinfo)];
    
    if (stopped) {
      break;
    } 
    
    [self flush];
	}
  
  [srcHandle closeFile];
  [dstHandle closeFile];

  return YES;
}
       
- (BOOL)removeRemotePath:(NSString *)rpath 
{
  NSString *fileType = [self typeOfFileAtPath: rpath];

  if (fileType == nil) {
    return NO;
  }

  [opinfo setObject: rpath forKey: @"source"];
  [opinfo setObject: rpath forKey: @"destination"];
  [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];

  if ([fileType isEqual: NSFileTypeDirectory] == NO) {
    if ([self removeRemoteFile: rpath] == NO) {
      [opinfo setObject: [NSString stringWithFormat: @"deleting %@", rpath] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];
      return [gwnetd fileOperationError: MAKEDATA (opinfo)];
    } else {
      return YES;
    }
    
  } else {
    NSArray *contents = [self remoteContentsAtPath: rpath];

    if (contents) {
      unsigned count = [contents count];
      unsigned i;
  
      for (i = 0; i < count; i++) {
	      CREATE_AUTORELEASE_POOL(arp);
        NSDictionary *fdict = [contents objectAtIndex: i];
        NSString *item = [fdict objectForKey: @"name"];
	      NSString *next = [rpath stringByAppendingPathComponent: item];
	      BOOL result = [self removeRemotePath: next];
        
	      RELEASE(arp);

        if (result == NO) {
	        return NO;
	      }

        if (stopped) {
          break;
        }     
      
        [self flush];
      }
     
      if ([self removeRemoteDirectory: rpath] == NO) {
        [opinfo setObject: [NSString stringWithFormat: @"deleting %@", rpath] 
                   forKey: @"errorstr"];
        [opinfo setObject: [NSNumber numberWithBool: YES] 
                   forKey: @"cancontinue"];
                   
        return [gwnetd fileOperationError: MAKEDATA (opinfo)];
      } else {
        return YES;
      }
     
    } else {
      [opinfo setObject: [NSString stringWithFormat: @"deleting %@", rpath] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];
      return [gwnetd fileOperationError: MAKEDATA (opinfo)];
    }
  }

  return YES;
}

- (BOOL)removeRemoteDirectory:(NSString *)rpath
{
  int rep = [self sendCommand: @"RMD" withParam: rpath getError: &lastError];
  return (rep < 500);
}

- (BOOL)removeRemoteFile:(NSString *)rpath
{
  int rep = [self sendCommand: @"DELE" withParam: rpath getError: &lastError];
  return (rep < 500);
}

- (BOOL)createRemoteDirectory:(NSString *)rpath
{
  int rep = [self sendCommand: @"MKD" withParam: rpath getError: &lastError];
  return (rep < 500);
}

- (NSArray *)remoteContentsAtPath:(NSString *)path
{
  NSFileHandle *handle = nil;
  NSString *outstr = nil;
  NSString *errStr = nil;
  int rep = 0;  
  
  handle = [self getDataHandle];
  if (handle == nil) {
    ERROR (@"no data handle");  
  }

  rep = [self sendCommand: @"LIST" withParam: path getError: &errStr];
  if (rep != 150) {
    ERROR (errStr);
  }

  if (usePasv == NO) {
    NSFileHandle *newhandle;
    struct sockaddr_in cli_addr;
    int clilen = sizeof(cli_addr);
    int sockfd;

    sockfd = accept([handle fileDescriptor], (struct sockaddr *) &cli_addr, &clilen);
  
    if (sockfd < 0) {
	    ERROR (@"no socket!");
    }

    newhandle = [[NSFileHandle alloc] initWithFileDescriptor: sockfd
                                              closeOnDealloc: YES];
    [handle closeFile];
    handle = AUTORELEASE (newhandle);
  }

  outstr = [self readStringFrom: handle];
  
  rep = [self getReply: &errStr];
  if (rep != 226) {
    ERROR (errStr);
  }
  
  [handle closeFile];

  if (outstr) {
    NSArray *lines = [outstr componentsSeparatedByString: @"\r\n"];
    NSMutableArray *contents = [NSMutableArray array];
    int i;    
    
    for (i = 0; i < ([lines count] - 1); i++) {
      NSString *line = [lines objectAtIndex: i];
      NSArray *lineAndLink = [line componentsSeparatedByString: @" -> "];
      int count = [lineAndLink count];
      
      if (count) {
        NSString *firstPart = [lineAndLink objectAtIndex: 0];
        NSArray *preItems = [firstPart componentsSeparatedByString: @" "];
        NSMutableArray *items = [NSMutableArray array];
        NSMutableString *fileName = [NSMutableString string];
        NSString *linkTo = @"";
        NSString *ftype = NSFileTypeRegular;
        long filesize = 0;
        int j;
        
        for (j = 0; j < [preItems count]; j++) {
				  NSString *preItem = [preItems objectAtIndex: j];
          
          if ([preItem length]) {
						[items insertObject: preItem atIndex: [items count]];
          }
        }

        if ([items count] >= 9) {
          NSString *perms = [items objectAtIndex: 0];
          
          if ([perms characterAtIndex: 0] == 'd') {
            ftype = NSFileTypeDirectory;
          } 
        
          filesize = [[items objectAtIndex: 4] intValue];
              
          [fileName appendString: [items objectAtIndex: 8]];
          
          for (j = 9; j < [items count]; j++) {
            [fileName appendString: @" "];
            [fileName appendString: [items objectAtIndex: j]];
          }

 				  if ([lineAndLink count] > 1) {
            linkTo = [lineAndLink objectAtIndex: 1];
            ftype = NSFileTypeSymbolicLink;
				  }

          if ([fileName length]) {
            NSMutableDictionary *fdict = [NSMutableDictionary dictionary];
            
            [fdict setObject: fileName forKey: @"name"];
            [fdict setObject: linkTo forKey: @"linkto"];
            [fdict setObject: ftype forKey: @"NSFileType"];
            [fdict setObject: [NSNumber numberWithInt: filesize] 
                      forKey: @"NSFileSize"];
            [fdict setObject: [NSNumber numberWithInt: i] 
                      forKey: @"index"];
            
            [contents addObject: fdict];
          }
        }
      }
    }
    
    DESTROY (lastContents);
    lastContents = [NSMutableDictionary new];
    [lastContents setObject: path forKey: @"path"];
    [lastContents setObject: contents forKey: @"contents"];
    
    return contents;
  }
  
  DESTROY (lastContents);
  
  return nil;
}

- (NSString *)typeOfFileAtPath:(NSString *)rpath
{
  NSString *basepath = [rpath stringByDeletingLastPathComponent];
  NSString *fname = [rpath lastPathComponent];
  NSArray *contents = nil;
  
  if (lastContents && [[lastContents objectForKey: @"path"] isEqual: basepath]) {
    contents = [lastContents objectForKey: @"contents"];
  } else {
    contents = [self remoteContentsAtPath: basepath];
  }
  
  if (contents) {
    int i;
    
    for (i = 0; i < [contents count]; i++) {
      NSDictionary *fdict = [contents objectAtIndex: i];

      if ([[fdict objectForKey: @"name"] isEqual: fname]) {
        return [fdict objectForKey: @"NSFileType"];
      }
    }
  }
    
  return nil;
}

- (long)sizeOfFileAtPath:(NSString *)rpath
{
  NSString *basepath = [rpath stringByDeletingLastPathComponent];
  NSString *fname = [rpath lastPathComponent];
  NSArray *contents = nil;
  
  if (lastContents && [[lastContents objectForKey: @"path"] isEqual: basepath]) {
    contents = [lastContents objectForKey: @"contents"];
  } else {
    contents = [self remoteContentsAtPath: basepath];
  }
  
  if (contents) {
    int i;
    
    for (i = 0; i < [contents count]; i++) {
      NSDictionary *fdict = [contents objectAtIndex: i];

      if ([[fdict objectForKey: @"name"] isEqual: fname]) {
        return [[fdict objectForKey: @"NSFileSize"] intValue];
      }
    }
  }
    
  return 0;
}

- (void)calculateLocalSizes
{
  int i;

  fcount = 0;
  fsize = 0;
  
  for (i = 0; i < [files count]; i++) {
    NSString *fname = [files objectAtIndex: i];
    NSString *path = [source stringByAppendingPathComponent: fname];       
    NSDictionary *attributes;
    NSString *ftype;
    
	  attributes = [fm fileAttributesAtPath: path traverseLink: NO];
    ftype = [attributes fileType];
    fsize += [attributes fileSize];
                                    
	  if ([ftype isEqual: NSFileTypeDirectory]) {
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: path];
      NSString *dirEntry;
      
      while ((dirEntry = [enumerator nextObject])) {
			  NSString *fullpath = [source stringByAppendingPathComponent: dirEntry];
        NSDictionary *subattr = [fm fileAttributesAtPath: fullpath traverseLink: NO];
        fsize += [subattr fileSize];
        fcount++;
        
        [self flush];
      }
	  } else {
		  fcount++;
	  }
    
    [self flush];
  }
}

- (void)calculateRemoteSizes
{
  int i;

  fcount = 0;
  fsize = 0;
  
  for (i = 0; i < [files count]; i++) {
    NSString *fname = [files objectAtIndex: i];
    NSString *path = [source stringByAppendingPathComponent: fname];
    NSString *ftype = [self typeOfFileAtPath: path];
    
    fsize += [self sizeOfFileAtPath: path];

    if ([ftype isEqual: NSFileTypeDirectory]) {
      FTPDirectoryEnumerator *enumerator = [self enumeratorAtPath: path];
      NSDictionary *dirEntry;

      while ((dirEntry = [enumerator nextObject])) {
        fsize += [[dirEntry objectForKey: @"NSFileSize"] longValue];
        fcount++;
        
        [self flush];
      }
    } else {
		  fcount++;
	  }

    [self flush];
  }
}

- (FTPDirectoryEnumerator *)enumeratorAtPath:(NSString *)path
{
  return AUTORELEASE ([[FTPDirectoryEnumerator alloc] 
                          initWithDirectoryPath: path  ftpFileOp: self]);
}

- (void)flush
{
  [[NSRunLoop currentRunLoop] 
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.001]];
}

- (void)connectionDidDie:(NSNotification *)notification
{
  NSLog(@"connection died!");
  exit(0);
}


//
// ftp commands methods
//
- (int)sendCommand:(NSString *)str 
         withParam:(NSString *)param 
          getError:(NSString **)errstr
{
	NSMutableString *cmd = [NSMutableString string];
  NSString *errStr = nil;
  int rep = 0;
  
  [cmd appendString: str];
  
  if (param) { 
    [cmd appendString: @" "];
    [cmd appendString: param];
  }
  [cmd appendString: @"\r\n"];
		
  NS_DURING
    [sockHandle writeData: [NSData dataWithBytes: [cmd cString] 
                                          length: [cmd cStringLength]]];
	NS_HANDLER
    *errstr = @"cannot write on handle";
    return rep;
	NS_ENDHANDLER  

  rep = [self getReply: &errStr];   
  *errstr = errStr;
  
  return rep;
}

- (int)getReply:(NSString **)errstr
{
	NSString *str = nil;
  NSString *replyErr = nil;
  int reply = 0;
  
	while (1) {
		str = [self readControlLine];
    
		if ((str != nil) && ([str length] > 3)) {
      reply = [[str substringWithRange: NSMakeRange (0, 3)] intValue];
      replyErr = [str substringWithRange: NSMakeRange (4, [str cStringLength] - 4)];      

			if ([str characterAtIndex: 3] == '-') {        
        [self flushControlLine: [str substringWithRange: NSMakeRange (0, 3)]];
      }
          
      break;
      
		} else {
      break;
    }
 	}
      
  *errstr = replyErr;
    
	return reply;
}

BOOL checkChar(NSFileHandle *handle, char c, NSMutableData *buf)
{
  if (c == EOF) {
    return YES;
  } else if (c == '\r') {
    if (recv([handle fileDescriptor], &c, 1, 0) <= 0) {
      return YES;
    }
		if ((c == '\n') || (c == EOF)) {
			return YES;
		} else if (c == '\0') {
      c = '\n';
      [buf appendBytes: &c length: 1];
		} else {
			checkChar(handle, c, buf);
		}
	} else if (c == '\n') {
    NSLog(@"telnet protocol violation: raw LF.");
    return YES;
  } else if (c == (char)IAC) {
    unsigned char	opt[3];

    if (recv([handle fileDescriptor], &c, 1, 0) <= 0) {
      return YES;
    }

		switch (c) {
			case WILL:
			case WONT:
        if (recv([handle fileDescriptor], &c, 1, 0) <= 0) {
          break;
        }
        opt[0] = IAC;
        opt[1] = DONT;
        opt[2] = c;                
        NS_DURING
          [handle writeData: [NSData dataWithBytes: opt length: 3]];
	      NS_HANDLER
          return NO;
	      NS_ENDHANDLER  
				break;

			case DO:
			case DONT:
        if (recv([handle fileDescriptor], &c, 1, 0) <= 0) {
          break;
        }
        opt[0] = IAC;
        opt[1] = WONT;
        opt[2] = c;
        NS_DURING
		      [handle writeData: [NSData dataWithBytes: opt length: 3]];
	      NS_HANDLER
          return NO;
	      NS_ENDHANDLER  
				break;

			case EOF:
				break;

			default:
				[buf appendBytes: &c length: 1];
		}
  } else {
    [buf appendBytes: &c length: 1];
  }
  
  return NO;
}

- (NSString *)readControlLine
{
	NSMutableData *buf = [NSMutableData dataWithLength: 0];
  NSString *str = nil;
  char c;
  
  while (recv([sockHandle fileDescriptor], &c, 1, 0) > 0) {
    if (checkChar(sockHandle, c, buf)) {
      break;
    }
  }

  if ([buf length]) {
    if (((unsigned char *)[buf bytes])[([buf length] - 1)] != '\0') {
      char c = '\0';
      [buf appendBytes: &c length: 1];
    }
    str = [NSString stringWithCString: [buf bytes]];

  } else {
    ERROR (@"control line error");
  }
  
  return str;
}

- (void)flushControlLine:(NSString *)codestr
{
  const char *code = [codestr cString];
  
  while (1) {
    NSString *str = [self readControlLine];
  
    if (str) {
      const char *buf = [str cString];
	    char *cp = (char *)buf;
    
		  if (strncmp(code, cp, 3) == 0) {
			  cp += 3;
        
			  if (*cp == ' ') {
				  break;
        }
        
			  ++cp;
		  }      

    } else {
      break;
    }  
  }
}

- (NSFileHandle *)getDataHandle 
{
  if (usePasv) {
    NS_DURING
		  [sockHandle writeData: [NSData dataWithBytes: [@"PASV\r\n" cString] 
			               length: [@"PASV\r\n" cStringLength]]];
	  NS_HANDLER
      return nil;
	  NS_ENDHANDLER      

	  while (1) {
		  NSString *str = [self readControlLine];

		  if ((str != nil) && ([str length] > 3)) {
        if ([str hasPrefix: @"227"]) {
	        NSRange	r = [str rangeOfString: @"("];
	        NSString *h = nil;
	        NSString *p = nil;

          if (r.length > 0) {                                
            unsigned posz = NSMaxRange(r);                                

            r = [str rangeOfString: @")"];

		        if (r.length > 0 && r.location > posz) {
		          NSArray	*a;

		          r = NSMakeRange(posz, r.location - posz);
		          str = [str substringWithRange: r];
		          a = [str componentsSeparatedByString: @","];

              if ([a count] == 6) {
			          h = [NSString stringWithFormat: @"%@.%@.%@.%@",
			                        [a objectAtIndex: 0], [a objectAtIndex: 1],
			                              [a objectAtIndex: 2], [a objectAtIndex: 3]];

			          p = [NSString stringWithFormat: @"%d",
			                      [[a objectAtIndex: 4] intValue] * 256
			                                  + [[a objectAtIndex: 5] intValue]];
			        }
		        }
          }

	        if (h == nil) {
            break;
		      } else {
            return [self fileHandleForConnectingAtPort: [p intValue]];
          }
        }

        if ([str characterAtIndex: 3] == '-') {
          break;
        }

		  } else {
        break;
      }
    }
  } else {
    return [self fileHandleForWithLocalPort];
  }
  
  return nil;
}

- (NSFileHandle *)fileHandleForConnectingAtPort:(unsigned)port
{
  struct hostent *hostinfo;
  struct sockaddr_in remoteAddr;
  int sock;
  int i;

  hostinfo = gethostbyname([hostname cString]);
  if (hostinfo == NULL) {
    return nil;
  }

  sock = socket(PF_INET, SOCK_STREAM, 0);
  if (sock < 0) {
    return nil;
  }
  
  bzero((char*)&remoteAddr, sizeof(remoteAddr));
  remoteAddr.sin_family = AF_INET;
  remoteAddr.sin_port = htons(port);
  
  for (i = 0; hostinfo->h_addr_list[i] != NULL; i++) {
    remoteAddr.sin_addr = *(struct in_addr*)hostinfo->h_addr_list[i];
    
    if (connect(sock, (struct sockaddr*)&remoteAddr, sizeof(remoteAddr)) == 0) {
      return AUTORELEASE ([[NSFileHandle alloc] initWithFileDescriptor: sock
                                                        closeOnDealloc: YES]);
    }
  }

  return nil;
}

- (NSFileHandle *)fileHandleForWithLocalPort
{
  struct hostent *hostinfo;
  struct sockaddr_in localAddr;
  int sock;
  int size;  
	char *a, *p;
  NSString *args;
  NSString *errStr;
  int rep;
  
  hostinfo = gethostbyname([[[NSHost currentHost] address] cString]);
  if (hostinfo == NULL) {
    return nil;
  }

	sock = socket(AF_INET, SOCK_STREAM, PF_UNSPEC);
	if (sock < 0) {
		return nil;
	}

  bzero((char*)&localAddr, sizeof(localAddr));
  localAddr.sin_family = AF_INET;
  localAddr.sin_addr = *(struct in_addr*)hostinfo->h_addr_list[0];
  localAddr.sin_port = 0;

  if (bind(sock, (struct sockaddr *)&localAddr, sizeof(localAddr)) < 0) {
    (void)close(sock);
		return nil;
  }

  if (listen(sock, 1) < 0) {
    (void)close(sock);
		return nil;
  }

  size = sizeof(localAddr); 
  if (getsockname(sock, (struct sockaddr*)&localAddr, &size) < 0) {
    (void)close(sock);
    return nil;
  }

#define UC(x) (int) (((int) x) & 0xff)

	a = (char *)&localAddr.sin_addr;
	p = (char *)&localAddr.sin_port;

  args = [NSString stringWithFormat: @"%d,%d,%d,%d,%d,%d",
		              UC(a[0]), UC(a[1]), UC(a[2]), UC(a[3]), UC(p[0]), UC(p[1])];

  rep = [self sendCommand: @"PORT" withParam: args getError: &errStr];
  if (rep != 200) {
    return nil;
  }

  return AUTORELEASE ([[NSFileHandle alloc] initWithFileDescriptor: sock
                                                    closeOnDealloc: YES]);
}

- (NSData *)readDataFrom:(NSFileHandle *)handle
{
  NSMutableData *mdata = [NSMutableData data];
  NSData *data;
  int rbytes;

  data = [handle readDataOfLength: NETBUF_SIZE];
  rbytes = [data length];
  
  if (rbytes < 0) {
    return nil;
	}

  [mdata appendData: data];

	while ([data length] > 0) {
    data = [handle readDataOfLength: NETBUF_SIZE];
      
    rbytes = [data length];
  
    if (rbytes < 0) {
      return nil;
	  }
      
    [mdata appendData: data];
	}

  if ([mdata length]) {
    return mdata;
  }
   
  return nil;
}

- (NSString *)readStringFrom:(NSFileHandle *)handle 
{
  NSMutableData *mdata = [NSMutableData data];
  NSData *data;
  int rbytes;

  data = [handle readDataOfLength: NETBUF_SIZE];
  rbytes = [data length];
  
  if (rbytes < 0) {
    return nil;
	}

  [mdata appendData: data];

	while ([data length] > 0) {
    data = [handle readDataOfLength: NETBUF_SIZE];
      
    rbytes = [data length];
  
    if (rbytes < 0) {
      return nil;
	  }
      
    [mdata appendData: data];
	}

  if ([mdata length]) {
    if (((unsigned char *)[mdata bytes])[([mdata length] - 1)] != '\0') {
      char c = '\0';
      [mdata appendBytes: &c length: 1];
    }
  }
   
  return [NSString stringWithCString: [mdata bytes]];
}

@end


@implementation FTPDirectoryEnumerator

- (void)dealloc
{
  RELEASE (topPath);
  RELEASE (stack);
  TEST_RELEASE (currentFilePath);

  [super dealloc];
}

- (id)initWithDirectoryPath:(NSString *)path 
                  ftpFileOp:(FTPFileOp *)op
{
  self = [super init];

  if (self) {
    NSArray *contents;
    
    fileop = op;
    stack = [NSMutableArray new];
    ASSIGN (topPath, path);
    currentFilePath = nil;
    
    contents = [fileop remoteContentsAtPath: topPath];

    if (contents) {
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      
      [dict setObject: contents forKey: @"contents"];
      [dict setObject: topPath forKey: @"dirname"];
      [dict setObject: [NSNumber numberWithInt: 0] forKey: @"index"];
      
      [stack addObject: dict];
    } else {
      NSLog(@"Failed to recurse into directory '%@'", topPath);
      RELEASE (self);
      return nil;
    }
  }
    
  return self;
}

- (NSDictionary *)nextObject
{
  NSDictionary *retFileDict = nil;

  DESTROY (currentFilePath);

  while ([stack count] > 0) {
    NSMutableDictionary *dirdict = [stack objectAtIndex: 0];
    NSString *dirname = [dirdict objectForKey: @"dirname"];
    NSArray *contents = [dirdict objectForKey: @"contents"];
    int index = [[dirdict objectForKey: @"index"] intValue];

    if (index < [contents count]) {
      NSDictionary *fdict = [contents objectAtIndex: index];
      NSString *fname = [fdict objectForKey: @"name"];
      NSString *ftype = [fdict objectForKey: @"NSFileType"];
      NSString *currFileName;

      retFileDict = fdict;
            
      if ([dirname isEqual: topPath] == NO) {
        currFileName = [dirname stringByAppendingString: @"/"];
        currFileName = [currFileName stringByAppendingString: fname];
	    } else {
        currFileName = fname;
      }

      ASSIGN (currentFilePath, [topPath stringByAppendingPathComponent: currFileName]);

      if ([ftype isEqual: NSFileTypeDirectory]) {
        NSArray *subconts = [fileop remoteContentsAtPath: currentFilePath];
      
        if (subconts) {
          NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      
          [dict setObject: subconts forKey: @"contents"];
          [dict setObject: currFileName forKey: @"dirname"];
          [dict setObject: [NSNumber numberWithInt: 0] forKey: @"index"];
      
          [stack insertObject: dict atIndex: 0];
		    } else {
		      NSLog(@"Failed to recurse into directory '%@'", currentFilePath);
		    }
      }

      index++;
      [dirdict setObject: [NSNumber numberWithInt: index] forKey: @"index"];
      
      break;

    } else {
      [stack removeObjectAtIndex: 0];
      DESTROY (currentFilePath);
    }
  }

  return retFileDict;
}

- (void)skipDescendents
{
  if ([stack count] > 0) {
    [stack removeObjectAtIndex: 0];
    DESTROY (currentFilePath);
  }
}

@end


int main(int argc, char** argv)
{
	FTPFileOp *op;
  
  CREATE_AUTORELEASE_POOL (pool);
	op = [[FTPFileOp alloc] initWithArgc: argc argv: argv];
  
  if (op != nil) {
    [op registerWithGwnetd];
    [[NSRunLoop currentRunLoop] run];
  }
  
  RELEASE(pool);
  exit(0);
}
