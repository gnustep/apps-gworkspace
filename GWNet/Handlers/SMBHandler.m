/* SMBHandler.m
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

#include <SMBKit/SMBKit.h>
#include <SMBKit/SMBFileManager.h>
#include <SMBKit/SMBFileHandle.h>
#include "SMBHandler.h"
#include "FileOperation.h"
#include "GWNet.h"
#include "GNUstep.h"


#define ERROR(s) \
[commandReply setObject: [NSNumber numberWithBool: YES] forKey: @"error"]; \
[commandReply setObject: s forKey: @"errstr"]; \
[self sendReplyToDispatcher]; \
return

#define ERROR_RET(s, r) \
[commandReply setObject: [NSNumber numberWithBool: YES] forKey: @"error"]; \
[commandReply setObject: s forKey: @"errstr"]; \
[self sendReplyToDispatcher]; \
return r

#define CHECK_ERROR(c, s) if (!c) { ERROR(s); }

#define SEND_REPLY \
[commandReply setObject: [NSNumber numberWithBool: NO] forKey: @"error"]; \
[self sendReplyToDispatcher]

@implementation SMBHandler

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  TEST_RELEASE (hosturl);
  TEST_RELEASE (usrname);
  TEST_RELEASE (usrpass);
  DESTROY (manager);
  TEST_RELEASE (commandReply);
  RELEASE (fileOperations);
  
	[super dealloc];
}

+ (BOOL)canViewScheme:(NSString *)scheme
{
  return [scheme isEqual: @"smb"]; 
}

+ (void)connectWithPorts:(NSArray *)portArray
{
  NSAutoreleasePool *pool;
  id dsp;
  NSConnection *conn;
  NSPort *port[2];
  SMBHandler *smbHandler;
	
  pool = [[NSAutoreleasePool alloc] init];
	  
  port[0] = [portArray objectAtIndex: 0];
  port[1] = [portArray objectAtIndex: 1];
  
  conn = [NSConnection connectionWithReceivePort: port[0] sendPort: port[1]];

  dsp = (id)[conn rootProxy];
	
  smbHandler = [[SMBHandler alloc] initWithDispatcheConnection: conn];
  
  [dsp _setHandler: smbHandler];
  
  RELEASE (smbHandler);
	
  [[NSRunLoop currentRunLoop] run];
  [pool release];
}

- (id)initWithDispatcheConnection:(NSConnection *)conn
{
  self = [super init];
  
  if (self) {
    id dsp = (id)[conn rootProxy];

    [dsp setProtocolForProxy: @protocol(DispatcherProtocol)];
    dispatcher = (id <DispatcherProtocol>)dsp;
    
    commandReply = nil;
    
    fileOperations = [NSMutableArray new];
    opindex = 0;    
  }
  
  return self;
}

- (NSString *)hosturl
{
  return hosturl;
}

- (id)dispatcher
{
  return dispatcher;
}

- (SMBFileManager *)manager
{
  return manager;
}

- (void)connectToHost:(NSString *)hostname
             userName:(NSString *)name
             password:(NSString *)passwd
{
  ASSIGN (hosturl, ([NSString stringWithFormat: @"smb://%@", hostname]));
  
  usrname = nil;
  usrpass = nil;
  
  if (name) {
    ASSIGN (usrname, name);
  } 
  
  if (passwd) {
    ASSIGN (usrpass, passwd);
  } 

  manager = [SMBFileManager managerForBaseUrl: hosturl
                                     userName: usrname
                                     password: usrpass];

  if (manager == nil) {
    ERROR (@"no manager!");
  }
  
  RETAIN (manager);
  
  SEND_REPLY;
}

- (oneway void)_unregister
{
  int i, count;
  
  count = [fileOperations count];
  for (i = 0; i < count; i++) {
    [[fileOperations objectAtIndex: 0] stopOperation];
  }

  [SMBKit unregisterManager: manager];
  [NSThread exit];
}

- (oneway void)_nextCommand:(NSData *)cmdinfo
{
  NSDictionary *cmdDict = [NSUnarchiver unarchiveObjectWithData: cmdinfo];
  int cmdtype = [[cmdDict objectForKey: @"cmdtype"] intValue];
  NSNumber *cmdRef = [cmdDict objectForKey: @"cmdref"];

  DESTROY (commandReply);
  commandReply = [NSMutableDictionary new];
  [commandReply setObject: [NSNumber numberWithInt: cmdtype] forKey: @"cmdtype"];
  [commandReply setObject: cmdRef forKey: @"cmdref"];
  
  switch (cmdtype) {
    case CONNECT:
      {
        NSString *hostname = [cmdDict objectForKey: @"hostname"];
        NSString *usr = [cmdDict objectForKey: @"user"];
        NSString *psw = [cmdDict objectForKey: @"password"];
      
        [self connectToHost: hostname userName: usr password: psw];    
      }
      break;

    case CONTENTS:
      [self contentsAt: [cmdDict objectForKey: @"path"]];
      break;

    default:
      break;
  }
}

- (void)sendReplyToDispatcher
{
  [dispatcher _replyToViewer: [NSArchiver archivedDataWithRootObject: commandReply]];
}

- (void)contentsAt:(NSString *)path
{
  NSString *url;
  NSArray *contents;
  NSMutableArray *files;
  int i;
  
  [commandReply setObject: path forKey: @"path"];

  if ([path isEqual: @"/"] == NO) {
    url = [hosturl stringByAppendingString: path];
  } else {
    url = hosturl;
  }
  
  contents = [manager directoryContentsAtUrl: url];
  CHECK_ERROR (contents, @"no contents");
  
  files = [NSMutableArray array];
  
  for (i = 0; i < [contents count]; i++) {
    NSString *fileName = [contents objectAtIndex: i];
    NSString *fullPath = [url stringByAppendingUrlPathComponent: fileName];
    NSDictionary *attributes;
    NSMutableDictionary *fdict = nil;
            
    attributes = [manager fileAttributesAtUrl: fullPath traverseLink: NO];
            
    if (attributes) {
      fdict = [attributes mutableCopy];
      
      [fdict setObject: fileName forKey: @"name"];
      [fdict setObject: @"" 
                forKey: @"linkto"];
      [fdict setObject: [NSNumber numberWithInt: i] 
                forKey: @"index"];
                
    } else {
      fdict = [[self dummyAttributes] mutableCopy];
      
      [fdict setObject: fileName forKey: @"name"];
      [fdict setObject: @"" 
                forKey: @"linkto"];
      [fdict setObject: [NSNumber numberWithInt: i] 
                forKey: @"index"];
                
      if ([url isEqual: hosturl] == NO) {
        attributes = [manager fileAttributesAtUrl: url traverseLink: NO];
        
        [fdict setObject: [attributes objectForKey: @"NSFileOwnerAccountID"] 
                  forKey: @"NSFileOwnerAccountID"];
        [fdict setObject: [attributes objectForKey: @"NSFileOwnerAccountName"] 
                  forKey: @"NSFileOwnerAccountName"];
        [fdict setObject: [attributes objectForKey: @"NSFileGroupOwnerAccountID"] 
                  forKey: @"NSFileGroupOwnerAccountID"];
        [fdict setObject: [attributes objectForKey: @"NSFileGroupOwnerAccountName"] 
                  forKey: @"NSFileGroupOwnerAccountName"];
        [fdict setObject: [attributes objectForKey: @"NSFileDeviceIdentifier"] 
                  forKey: @"NSFileDeviceIdentifier"];
        [fdict setObject: [attributes objectForKey: @"NSFileSystemFileNumber"] 
                  forKey: @"NSFileSystemFileNumber"];      
      }
    }
    
    [files addObject: fdict];
    RELEASE (fdict);
  }
  
  [commandReply setObject: files forKey: @"files"];
  SEND_REPLY;
}

- (NSDictionary *)dummyAttributes
{
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  [dict setObject: NSFileTypeUnknown forKey: @"NSFileType"];
  [dict setObject: [NSDate date] 
           forKey: @"NSFileCreationDate"];
  [dict setObject: [NSDate date] 
           forKey: @"NSFileCreationDate"];
  [dict setObject: [NSDate date] 
           forKey: @"NSFileModificationDate"];    
  [dict setObject: [NSNumber numberWithUnsignedLongLong: 0] 
           forKey: @"NSFileSize"];
  [dict setObject: [NSNumber numberWithUnsignedLong: 0] 
           forKey: @"NSFilePosixPermissions"];
  [dict setObject: [NSNumber numberWithUnsignedLong: 0] 
           forKey: @"NSFileOwnerAccountID"];
  [dict setObject: @"0" 
           forKey: @"NSFileOwnerAccountName"];
  [dict setObject: [NSNumber numberWithUnsignedLong: 0] 
           forKey: @"NSFileGroupOwnerAccountID"];
  [dict setObject: @"0" 
           forKey: @"NSFileGroupOwnerAccountName"];
  [dict setObject: [NSNumber numberWithUnsignedInt: 1] 
           forKey: @"NSFileReferenceCount"];
  [dict setObject: [NSNumber numberWithUnsignedInt: 0] 
           forKey: @"NSFileDeviceIdentifier"];
  [dict setObject: [NSNumber numberWithUnsignedLong: 0] 
           forKey: @"NSFileSystemFileNumber"];

  return dict;
}

- (oneway void)_startFileOperation:(NSData *)opinfo
{
  NSDictionary *info;  
  NSMutableDictionary *opdict;
  FileOperation *op;
  
  info = [NSUnarchiver unarchiveObjectWithData: opinfo];  
  opdict = [NSMutableDictionary dictionary];
      
  [opdict setObject: hosturl forKey: @"hosturl"]; 
  if (usrname) {
    [opdict setObject: usrname forKey: @"usrname"]; 
  }   
  if (usrpass) {
    [opdict setObject: usrpass forKey: @"usrpass"]; 
  } 

  [opdict setObject: [info objectForKey: @"source"]
             forKey: @"source"]; 
  [opdict setObject: [info objectForKey: @"destination"]
             forKey: @"destination"]; 
  [opdict setObject: [info objectForKey: @"files"]
             forKey: @"files"]; 
  [opdict setObject: [info objectForKey: @"type"]
             forKey: @"type"]; 
  [opdict setObject: [info objectForKey: @"ref"] 
             forKey: @"ref"]; 
    
  op = [[FileOperation alloc] initWithOperationInfo: opdict 
                                         forHandler: self];
  [fileOperations addObject: op];
  RELEASE (op);
}

- (oneway void)_stopFileOperation:(NSData *)opinfo
{
  NSDictionary *info = [NSUnarchiver unarchiveObjectWithData: opinfo];
  int ref = [[info objectForKey: @"ref"] intValue];
  int i;
  
  for (i = 0; i < [fileOperations count]; i++) {
    FileOperation *op = [fileOperations objectAtIndex: i];
    
    if ([op ref] == ref) {
      [op stopOperation];
      break;
    }
  }
}

- (void)fileOperationTerminated:(id)op
{
  [fileOperations removeObject: op];
}

@end















