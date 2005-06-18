/* smbfileop.m
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

#include "smbfileop.h"
#include "GNUstep.h"

#define BUFSIZE 8096

#define MAKEDATA(d) [NSArchiver archivedDataWithRootObject: d]

@implementation SMBFileOp

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  
  TEST_RELEASE (hosturl);
  TEST_RELEASE (usrname);
  TEST_RELEASE (usrpass);
  TEST_RELEASE (source);
  TEST_RELEASE (destination);
  TEST_RELEASE (files);
  TEST_RELEASE (opinfo);
  DESTROY (manager);
  
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

    connName = [NSString stringWithFormat: @"smb_fileop_ref_%@_%i", refStr, ref];

    connection = [NSConnection connectionWithRegisteredName: connName host: @""];
    if (connection == nil) {
      NSLog(@"smbfileop - failed to get the connection - bye.");
	    exit(1);               
    }

    anObject = [connection rootProxy];
    
    if (anObject == nil) {
      NSLog(@"smbfileop - failed to contact gwnetd - bye.");
	    exit(1);           
    } 

    [anObject setProtocolForProxy: @protocol(GWNetdProtocol)];
    gwnetd = (id <GWNetdProtocol>)anObject;
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                            selector: @selector(connectionDidDie:)
                                name: NSConnectionDidDieNotification
                              object: connection];    
    
    usrname = nil;
    usrpass = nil;
    manager = nil;
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
      
  ASSIGN (hosturl, [info objectForKey: @"hosturl"]);
  
  entry = [info objectForKey: @"usrname"];
  if (entry) {
    ASSIGN (usrname, entry);
  } 

  entry = [info objectForKey: @"usrpass"];
  if (entry) {
    ASSIGN (usrpass, entry);
  } 
  
  ASSIGN (source, [info objectForKey: @"source"]);
  ASSIGN (destination, [info objectForKey: @"destination"]);
  ASSIGN (files, [info objectForKey: @"files"]);    

  type = [[info objectForKey: @"type"] intValue];
    
  opinfo = [NSMutableDictionary new];
  [opinfo setObject: [NSNumber numberWithInt: ref] forKey: @"ref"];    
  [opinfo setObject: [NSNumber numberWithInt: type] forKey: @"type"];        

  manager = [SMBFileManager managerForBaseUrl: hosturl
                                     userName: usrname
                                     password: usrpass];

  if (manager == nil) {
    NSLog(@"no smbmanager!");
    exit(0);
  }
  
  RETAIN (manager);
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
          NSString *fname, *srcPath, *destUrl;
          
          fname = [files objectAtIndex: i];
          srcPath = [source stringByAppendingPathComponent: fname];
          destUrl = [hosturl stringByAppendingUrlPathComponent: destination];
          destUrl = [destUrl stringByAppendingUrlPathComponent: fname];
          
          if ([self uploadLocalPath: srcPath toRemoteUrl: destUrl] == NO) {
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
          NSString *fname, *srcUrl, *dstPath;
          
          fname = [files objectAtIndex: i];
          srcUrl = [hosturl stringByAppendingUrlPathComponent: source];
          dstPath = [destination stringByAppendingPathComponent: fname];
          srcUrl = [srcUrl stringByAppendingUrlPathComponent: fname];
          
          if ([self downloadRemoteUrl: srcUrl toLocalPath: dstPath] == NO) {
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
          NSString *fname, *url;
          
          fname = [files objectAtIndex: i];
          url = [hosturl stringByAppendingUrlPathComponent: destination];
          url = [url stringByAppendingUrlPathComponent: fname];
          
          if ([self removeRemoteUrl: url] == NO) {
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

    case DUPLICATE:
      {
        NSString *copystr = @"copy";
        NSString *ofstr = @"_of_";

        [self calculateRemoteSizes];
        [opinfo setObject: [NSNumber numberWithInt: fcount] forKey: @"fcount"];
        [gwnetd fileOperationStarted: MAKEDATA (opinfo)];
        
        for (i = 0; i < [files count]; i++) {
          NSString *fname, *url, *srcurl, *dsturl;
          int count;
          
          fname = [files objectAtIndex: i];
          url = [hosturl stringByAppendingUrlPathComponent: destination];
          srcurl = [url stringByAppendingUrlPathComponent: fname];
          
          count = 1;
          
			    while(1) {
            NSString *ntmp;

            if (count == 1) {
              ntmp = [NSString stringWithFormat: @"%@%@%@", copystr, ofstr, fname];
            } else {
              ntmp = [NSString stringWithFormat: @"%@%i%@%@", copystr, count, ofstr, fname];
            }

				    dsturl = [url stringByAppendingUrlPathComponent: ntmp];
            
				    if ([manager fileExistsAtUrl: dsturl] == NO) {
              break;
            } else {
              count++;
            }
            
            [self flush];
			    }          
          
          if ([manager copyUrl: srcurl toUrl: dsturl handler: self] == NO) {
            [opinfo setObject: [NSString stringWithFormat: @"duplicating %@", fname] 
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

    case RENAME:
      {
        NSString *srcurl, *dsturl;
        
        srcurl = [hosturl stringByAppendingUrlPathComponent: source];
        dsturl = [hosturl stringByAppendingUrlPathComponent: destination];
      
        [opinfo setObject: [NSNumber numberWithInt: 1] forKey: @"fcount"];
        [gwnetd fileOperationStarted: MAKEDATA (opinfo)];
        
        if ([manager moveUrl: srcurl toUrl: dsturl handler: self] == NO) {
          [opinfo setObject: [NSString stringWithFormat: @"renaming %@", srcurl] 
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
        NSString *url, *fname;
        
        url = [hosturl stringByAppendingUrlPathComponent: destination];
        fname = [files objectAtIndex: 0];
        
        url = [url stringByAppendingUrlPathComponent: fname];
      
        [opinfo setObject: [NSNumber numberWithInt: 1] forKey: @"fcount"];
        [gwnetd fileOperationStarted: MAKEDATA (opinfo)];
        
        if ([manager createDirectoryAtUrl: url attributes: nil] == NO) {
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
  if (manager) {
    [SMBKit unregisterManager: manager];
  }
  [gwnetd fileOperationDone: MAKEDATA (opinfo)];
  exit(0);
}

- (oneway void)stopOperation
{
  stopped = YES;
}

- (BOOL)uploadLocalPath:(NSString *)lpath
            toRemoteUrl:(NSString *)rurl
{
  NSDictionary *attrs = [fm fileAttributesAtPath: lpath traverseLink: NO];
  NSString *fname = [lpath lastPathComponent];
  NSString *fileType;
  
  if (attrs == nil) {
    return NO;
  }

  [opinfo setObject: lpath forKey: @"source"];
  [opinfo setObject: rurl forKey: @"destination"];
  [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];
  
  fileType = [attrs fileType];

  if ([fileType isEqual: NSFileTypeDirectory]) {
    if ([manager createDirectoryAtUrl: rurl attributes: attrs] == NO) {
      [opinfo setObject: [NSString stringWithFormat: @"uploading %@", fname] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];
      return [gwnetd fileOperationError: MAKEDATA (opinfo)];
	  }

    if ([self uploadDirectoryContentsAtPath: lpath 
                                toRemoteUrl: rurl] == NO) {
	    return NO;
	  }
    
  } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
    [opinfo setObject: [NSString stringWithFormat: 
                      @"'%@' symbolik links not supported by samba", fname] 
               forKey: @"errorstr"];
    [opinfo setObject: [NSNumber numberWithBool: YES] 
               forKey: @"cancontinue"];
    return [gwnetd fileOperationError: MAKEDATA (opinfo)];
  
  } else {
	  if ([self uploadFileContentsAtPath: lpath
			                     toRemoteUrl: rurl] == NO) {
	    return NO;
    }
  }
  
  return YES;
}

- (BOOL)uploadDirectoryContentsAtPath:(NSString *)lpath
                          toRemoteUrl:(NSString *)rurl
{
  NSDirectoryEnumerator *enumerator;
  NSString *dirEntry;
  CREATE_AUTORELEASE_POOL (pool);

  enumerator = [fm enumeratorAtPath: lpath];

  while ((dirEntry = [enumerator nextObject])) {
    NSString *sourceFile = [lpath stringByAppendingPathComponent: dirEntry];
    NSString *destinationFile = [rurl stringByAppendingUrlPathComponent: dirEntry];
    NSString *fname = [sourceFile lastPathComponent];
    NSDictionary *attributes = [fm fileAttributesAtPath: sourceFile traverseLink: NO];
    NSString *fileType = [attributes fileType];

    [opinfo setObject: sourceFile forKey: @"source"];
    [opinfo setObject: destinationFile forKey: @"destination"];
    [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];
    
    if ([fileType isEqual: NSFileTypeDirectory]) {
      if ([manager createDirectoryAtUrl: destinationFile 
                             attributes: attributes] == NO) {
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
                                    toRemoteUrl: destinationFile] == NO) {
          RELEASE (pool);                          
	        return NO;
	      }
      }

    } else if ([fileType isEqual: NSFileTypeRegular]) {
	    if ([self uploadFileContentsAtPath: sourceFile
			                       toRemoteUrl: destinationFile] == NO) {
        RELEASE (pool);                           
	      return NO;
      }
  
    } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
      [opinfo setObject: [NSString stringWithFormat: 
                      @"'%@' symbolik links not supported by samba", fname] 
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
                     toRemoteUrl:(NSString *)rurl
{
  NSDictionary *attributes;
  NSFileHandle *srcHandle;
  SMBFileHandle *dstHandle;
  NSData *buff;
  int fileSize;
  int rbytes;
  int wbytes;

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

  dstHandle = [SMBFileHandle fileHandleForWritingAtUrl: rurl];
  if (dstHandle == nil) {
    [srcHandle closeFile];
    UPLOAD_ERR (([NSString stringWithFormat: @"cannot open file for writing %@", rurl]));
  }

  buff = [srcHandle readDataOfLength: BUFSIZE];
  rbytes = [buff length];
  
  if (rbytes < 0) {
    [srcHandle closeFile];
    [dstHandle closeFile];
    UPLOAD_ERR (([NSString stringWithFormat: @"cannot read from file %@", lpath]));
	}

	while ([buff length] > 0) {
    wbytes = [dstHandle write: [buff bytes] length: rbytes];

    if (wbytes != rbytes) {
      [srcHandle closeFile];
      [dstHandle closeFile];
      UPLOAD_ERR (([NSString stringWithFormat: @"cannot write to file %@", rurl]));
    }

    [opinfo setObject: [NSNumber numberWithInt: wbytes] forKey: @"increment"];
    [gwnetd fileTransferUpdated: MAKEDATA (opinfo)];

    buff = [srcHandle readDataOfLength: BUFSIZE];
    rbytes = [buff length];
    
    if (rbytes < 0) {
      [srcHandle closeFile];
      [dstHandle closeFile];
      UPLOAD_ERR (([NSString stringWithFormat: @"cannot read from file %@", lpath]));
	  }
    
    if (stopped) {
      break;
    }     
    
    [self flush];
  }
  
  [srcHandle closeFile];
  [dstHandle closeFile];

  return YES;
}

- (BOOL)downloadRemoteUrl:(NSString *)rurl
              toLocalPath:(NSString *)lpath
{
  NSString *locRep = [rurl pathPartOfSmbUrl];
  NSString *fname = [locRep lastPathComponent];
  NSDictionary *attrs = [manager fileAttributesAtUrl: rurl traverseLink: NO];
  NSString *fileType;

  if (attrs == nil) {
    return NO;
  }

  [opinfo setObject: locRep forKey: @"source"];
  [opinfo setObject: locRep forKey: @"destination"];
  [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];
  
  fileType = [attrs fileType];

  if ([fileType isEqual: NSFileTypeDirectory]) {
    if ([fm createDirectoryAtPath: lpath attributes: nil] == NO) {
      [opinfo setObject: [NSString stringWithFormat: @"downloading %@", fname] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];
      return [gwnetd fileOperationError: MAKEDATA (opinfo)];
	  }

    if ([self downloadDirectoryContentsAtUrl: rurl
                                 toLocalPath: lpath] == NO) {
	    return NO;
	  }

  } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
    [opinfo setObject: [NSString stringWithFormat: 
                      @"'%@' symbolik links not supported by samba", fname] 
               forKey: @"errorstr"];
    [opinfo setObject: [NSNumber numberWithBool: YES] 
               forKey: @"cancontinue"];
    return [gwnetd fileOperationError: MAKEDATA (opinfo)];
    
  } else {
	  if ([self downloadFileContentsAtUrl: rurl
			                      toLocalPath: lpath] == NO) {
	    return NO;
    }
  }

  return YES;
}

- (BOOL)downloadDirectoryContentsAtUrl:(NSString *)rurl
                           toLocalPath:(NSString *)lpath
{
  SMBDirectoryEnumerator *enumerator;
  NSString *dirEntry;
  CREATE_AUTORELEASE_POOL (pool);
  
  enumerator = [manager enumeratorAtUrl: rurl];
  
  while ((dirEntry = [enumerator nextObject])) {
    NSString *sourceFile = [rurl stringByAppendingUrlPathComponent: dirEntry];
    NSString *destinationFile = [lpath stringByAppendingPathComponent: dirEntry];
    NSString *fname = [destinationFile lastPathComponent];
    NSDictionary *attributes;
    NSString *fileType;

    attributes = [manager fileAttributesAtUrl: sourceFile traverseLink: NO];
    
    fileType = [attributes fileType];
    
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

        if ([self downloadDirectoryContentsAtUrl: sourceFile 
                                     toLocalPath: destinationFile] == NO) {
          RELEASE (pool);                          
	        return NO;
	      }
      }

    } else if ([fileType isEqual: NSFileTypeRegular]) {
	    if ([self downloadFileContentsAtUrl: sourceFile
			                        toLocalPath: destinationFile] == NO) {
        RELEASE (pool);                           
	      return NO;
      }

    } else if ([fileType isEqual: NSFileTypeSymbolicLink]) {
      [opinfo setObject: [NSString stringWithFormat: 
                      @"'%@' symbolik links not supported by samba", fname] 
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

- (BOOL)downloadFileContentsAtUrl:(NSString *)rurl
                      toLocalPath:(NSString *)lpath
{
  NSDictionary *attributes;
  NSFileHandle *dstHandle;
  SMBFileHandle *srcHandle;
  char buffer[BUFSIZE];
  int fileSize;
  int rbytes;
  int i;

#define DOWNLOAD_ERR(s) \
[opinfo setObject: s forKey: @"errorstr"]; \
[opinfo setObject: [NSNumber numberWithBool: YES] forKey: @"cancontinue"]; \
return [gwnetd fileOperationError: MAKEDATA (opinfo)]
  
  attributes = [manager fileAttributesAtUrl: rurl traverseLink: NO];
  fileSize = [attributes fileSize];
  
  srcHandle = [SMBFileHandle fileHandleForReadingAtUrl: rurl];
  
  if (srcHandle == nil) {
    DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot open file for reading %@", rurl]));
  }

  if ([fm createFileAtPath: lpath contents: nil attributes: nil] == NO) {
    [srcHandle closeFile];
    DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot create %@", lpath]));
  }
  
  dstHandle = [NSFileHandle fileHandleForWritingAtPath: lpath];
  if (dstHandle == nil) {
    [srcHandle closeFile];
    DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot open file for writing %@", lpath]));
  }

  [opinfo setObject: [NSNumber numberWithInt: fileSize] forKey: @"fsize"];
  [gwnetd fileTransferStarted: MAKEDATA (opinfo)];

  for (i = 0; i < fileSize; i += rbytes) {
    rbytes = [srcHandle read: buffer length: BUFSIZE];
    
    if (rbytes < 0) {
      [srcHandle closeFile];
      [dstHandle closeFile];
      DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot read from file %@", rurl]));
	  }

    NS_DURING
      [dstHandle writeData: [NSData dataWithBytes: buffer length: rbytes]];
	  NS_HANDLER
      [srcHandle closeFile];
      [dstHandle closeFile];
      DOWNLOAD_ERR (([NSString stringWithFormat: @"cannot write to file %@", lpath]));
	  NS_ENDHANDLER  

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

- (BOOL)removeRemoteUrl:(NSString *)rurl
{
  NSString *locRep = [rurl pathPartOfSmbUrl];
  NSDictionary *attrs = [manager fileAttributesAtUrl: rurl traverseLink: NO];
  NSString *fileType;
  
  if (attrs == nil) {
    return NO;
  }

  [opinfo setObject: locRep forKey: @"source"];
  [opinfo setObject: locRep forKey: @"destination"];
  [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];

  fileType = [attrs fileType];

  if ([fileType isEqual: NSFileTypeDirectory] == NO) {
    if ([manager removeFileAtUrl: rurl] == NO) {
      [opinfo setObject: [NSString stringWithFormat: @"deleting %@", rurl] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];
      return [gwnetd fileOperationError: MAKEDATA (opinfo)];
    } else {
      return YES;
    }
    
  } else {
    NSArray *contents = [manager directoryContentsAtUrl: rurl];
    
    if (contents) {
      unsigned count = [contents count];
      unsigned i;
  
      for (i = 0; i < count; i++) {
	      CREATE_AUTORELEASE_POOL(arp);
	      NSString *item = [contents objectAtIndex: i];
	      NSString *next = [rurl stringByAppendingUrlPathComponent: item];
	      BOOL result = [self removeRemoteUrl: next];
        
	      RELEASE(arp);
        
        if (result == NO) {
	        return NO;
	      }
      
        if (stopped) {
          break;
        }     

        [self flush];
      }
      
      if ([manager removeDirectoryAtUrl: rurl] == NO) {
        [opinfo setObject: [NSString stringWithFormat: @"deleting %@", rurl] 
                   forKey: @"errorstr"];
        [opinfo setObject: [NSNumber numberWithBool: YES] 
                   forKey: @"cancontinue"];
        return [gwnetd fileOperationError: MAKEDATA (opinfo)];
      } else {
        return YES;
      }
  
    } else {
      [opinfo setObject: [NSString stringWithFormat: @"deleting %@", rurl] 
                 forKey: @"errorstr"];
      [opinfo setObject: [NSNumber numberWithBool: YES] 
                 forKey: @"cancontinue"];
      return [gwnetd fileOperationError: MAKEDATA (opinfo)];
    }
  }

  return YES;
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
    NSString *url;
    NSDictionary *attributes;
    NSString *ftype;

    url = [hosturl stringByAppendingUrlPathComponent: source];
    url = [url stringByAppendingUrlPathComponent: fname];
	  attributes = [manager fileAttributesAtUrl: url traverseLink: NO];
    
    ftype = [attributes fileType];
    fsize += [attributes fileSize];

    if ([ftype isEqual: NSFileTypeDirectory]) {
      SMBDirectoryEnumerator *enumerator = [manager enumeratorAtUrl: url];
      NSString *dirEntry;
      
      while ((dirEntry = [enumerator nextObject])) {
			  NSString *fullUrl = [url stringByAppendingUrlPathComponent: dirEntry];
        NSDictionary *subattr = [manager fileAttributesAtUrl: fullUrl traverseLink: NO];
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

- (void)flush
{
  [[NSRunLoop currentRunLoop] 
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.001]];
}

- (void)connectionDidDie:(NSNotification *)notification
{
  NSLog(@"connection died!");
  if (manager) {
    [SMBKit unregisterManager: manager];
  }
  exit(0);
}

//
// SMBFileManagerHandler delegate methods
//
- (BOOL)smbFileManager:(SMBFileManager *)fileManager
        shouldProceedAfterError:(NSDictionary *)errorDictionary
{
  [opinfo setObject: [errorDictionary objectForKey: @"error"] 
             forKey: @"errorstr"];
  [opinfo setObject: [NSNumber numberWithBool: YES] 
             forKey: @"cancontinue"];
  return [gwnetd fileOperationError: MAKEDATA (opinfo)];
}

- (void)smbFileManager:(SMBFileManager *)fileManager
        willProcessUrl:(NSString *)url
{
  if (type == DUPLICATE) {
    NSString *fname = [url lastUrlPathComponent];

    [opinfo setObject: fname forKey: @"source"];
    [opinfo setObject: fname forKey: @"destination"];
    [gwnetd fileOperationUpdated: MAKEDATA (opinfo)];
  }
}

@end

int main(int argc, char** argv)
{
	SMBFileOp *op;
  
  CREATE_AUTORELEASE_POOL (pool);
	op = [[SMBFileOp alloc] initWithArgc: argc argv: argv];
  
  if (op != nil) {
    [op registerWithGwnetd];
    [[NSRunLoop currentRunLoop] run];
  }
  
  RELEASE(pool);
  exit(0);
}
