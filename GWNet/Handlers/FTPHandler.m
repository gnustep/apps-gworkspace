/* FTPHandler.m
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
#include "FTPHandler.h"
#include "FileOperation.h"
#include "GWNet.h"
#include "GNUstep.h"

#define	NETBUF_SIZE	1024

#ifndef WILL
  #define	WILL 251
  #define	WONT 252
  #define	DO 253
  #define	DONT 254
  #define	IAC 255
#endif

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


@implementation FTPHandler

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];

  if (tmoutTimer && [tmoutTimer isValid]) {
    [tmoutTimer invalidate];
  }
  TEST_RELEASE (hostname);
  TEST_RELEASE (usrname);
  TEST_RELEASE (usrpass);
  TEST_RELEASE (sockHandle);

  TEST_RELEASE (commandReply);
  
	[super dealloc];
}

+ (BOOL)canViewScheme:(NSString *)scheme
{
  return [scheme isEqual: @"ftp"]; 
}

+ (void)connectWithPorts:(NSArray *)portArray
{
  NSAutoreleasePool *pool;
  id dsp;
  NSConnection *conn;
  NSPort *port[2];
  FTPHandler *ftpHandler;
	
  pool = [[NSAutoreleasePool alloc] init];
	  
  port[0] = [portArray objectAtIndex: 0];
  port[1] = [portArray objectAtIndex: 1];
  
  conn = [NSConnection connectionWithReceivePort: port[0] sendPort: port[1]];

  dsp = (id)[conn rootProxy];
	
  ftpHandler = [[FTPHandler alloc] initWithDispatcheConnection: conn];
  
  [dsp _setHandler: ftpHandler];
  
  RELEASE (ftpHandler);
	
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
    
    currentComm = nil;
  }
  
  return self;
}

- (NSString *)hostname
{
  return hostname;
}

- (id)dispatcher
{
  return dispatcher;
}

- (oneway void)_unregister
{
  NSString *errStr;
  int i, count;
  
  count = [fileOperations count];
  for (i = 0; i < count; i++) {
    [[fileOperations objectAtIndex: 0] stopOperation];
  }
  
  [self sendCommand: @"QUIT" withParam: nil getError: &errStr];
  [NSThread exit];
}

- (void)connectToHostWithName:(NSString *)hname
                     userName:(NSString *)name
                     password:(NSString *)passwd
                      timeout:(int)tmout
{
  NSString *errStr = nil;
  int rep = 0;

  timeout = tmout;
  repTimeout = NO;
  waitingReply = NO;
  tmoutTimer = nil;
    
  ASSIGN (hostname, hname);
  
  if (name == nil) {
    ASSIGN (usrname, [NSString stringWithString: @"anonymous"]);
  } else {
    ASSIGN (usrname, name);
  }
  
  if (passwd == nil) {
    ASSIGN (usrpass, [NSString stringWithString: @"anonymous"]);
  } else {
    ASSIGN (usrpass, passwd);
  }
  
  sockHandle = [self fileHandleForConnectingAtPort: 21];
  if (sockHandle == nil) {
    ERROR (@"no socket!");
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

  rep = [self sendCommand: @"CWD" withParam: @"/" getError: &errStr];
  if (rep != 250) {
    ERROR (errStr);
  }
   
  SEND_REPLY;
}

- (void)checkTimeout:(id)sender
{  
  if (waitingReply) {
    repTimeout = YES;  
    ERROR (@"timeout");
  }
}

- (int)sendCommand:(NSString *)str 
         withParam:(NSString *)param 
          getError:(NSString **)errstr
{
	NSMutableString *cmd = [NSMutableString string];
  NSString *errStr = nil;
  int rep = 0;
  
  currentComm = str;  
  [cmd appendString: str];
  
  if (param) { 
    [cmd appendString: @" "];
    [cmd appendString: param];
  }
  [cmd appendString: @"\r\n"];
		
  if (repTimeout == NO) {
    waitingReply = YES;
    
    tmoutTimer = [NSTimer scheduledTimerWithTimeInterval: timeout
											target: self selector: @selector(checkTimeout:) 
																					          userInfo: nil repeats: NO];
                                                    
    NS_DURING
      [sockHandle writeData: [NSData dataWithBytes: [cmd cString] 
                                            length: [cmd cStringLength]]];
	  NS_HANDLER
      *errstr = @"cannot write on handle";
      return rep;
	  NS_ENDHANDLER  
    
    rep = [self getReply: &errStr];   
  }
  
  *errstr = errStr;
  
  return rep;
}

- (int)getReply:(NSString **)errstr
{
	NSString *str = nil;
  int reply = 0;
    
	while (1) {
		str = [self readControlLine];
        
		if ((str != nil) && ([str length] > 3)) {
      reply = [[str substringWithRange: NSMakeRange (0, 3)] intValue];
      *errstr = [str substringWithRange: NSMakeRange (4, [str cStringLength] - 4)];      

			if ([str characterAtIndex: 3] == '-') {        
        [self flushControlLine: [str substringWithRange: NSMakeRange (0, 3)]];
      }
          
      break;
      
		} else {
      break;
    }
 	}
    
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
    waitingReply = NO;

  } else {
    ERROR_RET (@"control line error", str);
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
  if (repTimeout == NO) {
    if (usePasv) {
      currentComm = @"PASV";

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

    //      if ([str characterAtIndex: 3] == '-') {
   //         [self flushControlLine: [str substringWithRange: NSMakeRange (0, 3)]];
   //         break;
   //       }

		    } else {
          break;
        }
      }
    } else {
      return [self fileHandleForWithLocalPort];
    }
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

- (oneway void)_nextCommand:(NSData *)cmdinfo
{
  NSDictionary *cmdDict = [NSUnarchiver unarchiveObjectWithData: cmdinfo];
  int cmdtype = [[cmdDict objectForKey: @"cmdtype"] intValue];
  NSNumber *cmdRef = [cmdDict objectForKey: @"cmdref"];
  NSString *errStr = nil;

  DESTROY (commandReply);
  commandReply = [NSMutableDictionary new];
  [commandReply setObject: [NSNumber numberWithInt: cmdtype] forKey: @"cmdtype"];
  [commandReply setObject: cmdRef forKey: @"cmdref"];
  
  switch (cmdtype) {
    case LOGIN:
      {
        NSString *hstname = [cmdDict objectForKey: @"hostname"];
        NSString *usr = [cmdDict objectForKey: @"user"];
        NSString *psw = [cmdDict objectForKey: @"password"];
        usePasv = [[cmdDict objectForKey: @"usepasv"] boolValue];
        
        [self connectToHostWithName: hstname 
                           userName: usr 
                           password: psw 
                            timeout: 10];    
      }
      break;

    case NOOP:
      [self sendCommand: @"NOOP" withParam: nil getError: &errStr];
      break;

    case LIST:
      [self doList: [cmdDict objectForKey: @"path"]];
      break;


    default:
      break;
  }
}

- (void)doList:(NSString *)path
{
  NSFileHandle *handle = nil;
  NSString *outstr = nil;
  NSString *errStr = nil;
  int rep = 0;  

  [commandReply setObject: path forKey: @"path"];
  
  handle = [self getDataHandle];
  CHECK_ERROR (handle, @"no data handle");

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
    NSMutableArray *files = [NSMutableArray array];
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
        long fsize = 0;
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
        
          fsize = [[items objectAtIndex: 4] intValue];
              
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
            [fdict setObject: [NSNumber numberWithInt: fsize] 
                      forKey: @"NSFileSize"];
            [fdict setObject: [NSNumber numberWithInt: i] 
                      forKey: @"index"];
            
            [files addObject: fdict];
          }
        }
      }
    }
  
    [commandReply setObject: files forKey: @"files"];
  
    SEND_REPLY;
        
  } else {
    [commandReply setObject: [NSArray array] forKey: @"files"];
    SEND_REPLY;
  }
}

- (void)sendReplyToDispatcher
{
  [dispatcher _replyToViewer: [NSArchiver archivedDataWithRootObject: commandReply]];
}

- (oneway void)_startFileOperation:(NSData *)opinfo
{
  NSDictionary *info;  
  NSMutableDictionary *opdict;
  FileOperation *op;
  
  info = [NSUnarchiver unarchiveObjectWithData: opinfo];  
  opdict = [NSMutableDictionary dictionary];
      
  [opdict setObject: hostname forKey: @"hostname"]; 
  
  if (usrname) {
    [opdict setObject: usrname forKey: @"usrname"]; 
  }   
  if (usrpass) {
    [opdict setObject: usrpass forKey: @"usrpass"]; 
  } 
  
  [opdict setObject: [NSNumber numberWithBool: usePasv] forKey: @"usepasv"]; 

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



