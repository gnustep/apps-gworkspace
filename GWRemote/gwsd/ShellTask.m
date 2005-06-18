/* ShellTask.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep gwsd tool
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

#include <Foundation/Foundation.h>
#include "ShellTask.h"
#include "gwsd.h"
#include "externs.h"
#include "GNUstep.h"

@implementation GWSd (shellTasks)

- (void)_openShellOnPath:(NSString *)path refNumber:(NSNumber *)ref
{
  ShellTask *shtask = [[ShellTask alloc] initWithShellCommand: shellCommand
            onPath: path forGWSd: self withClient: gwsdClient refNumber: ref];
  [shellTasks addObject: shtask];
  RELEASE (shtask);
}

- (void)_remoteShellWithRef:(NSNumber *)ref 
             newCommandLine:(NSString *)line
{
  ShellTask *shtask = [self taskWithRefNumber: ref];
  
  if (shtask) {
    [shtask newCommandLine: line];
  }
}

- (void)_closedRemoteTerminalWithRefNumber:(NSNumber *)ref
{
  ShellTask *shtask = [self taskWithRefNumber: ref];
  
  if (shtask) {
    [shtask stopTask];
    [shellTasks removeObject: shtask];
  }
}

- (ShellTask *)taskWithRefNumber:(NSNumber *)ref
{
  int i;

  for (i = 0; i < [shellTasks count]; i++) {
    ShellTask *shtask = [shellTasks objectAtIndex: i];
    NSNumber *shref = [shtask refNumber];
    
    if ([shref isEqual: ref]) {
      return shtask;
    }
  }

  return nil;
}

- (void)shellDone:(ShellTask *)atask
{
  [gwsdClient exitedShellTaskWithRef: [atask refNumber]];
  [shellTasks removeObject: atask];
}

@end

@implementation ShellTask

- (void)dealloc
{
  if (task && [task isRunning]) {
		[nc removeObserver: self];
    [task terminate];
	} 
	DESTROY (task);
  
  RELEASE (shellPath);
  RELEASE (ref);
  [super dealloc];
}

- (id)initWithShellCommand:(NSString *)cmd
                    onPath:(NSString *)apath
                   forGWSd:(GWSd *)gw
                withClient:(id)client
                 refNumber:(NSNumber *)refn
{
	self = [super init];
  
  if (self) {   
	  NSPipe *pipe[3];
    NSFileHandle *handle;  
  
    gwsd = gw;
    gwsdClient = (id <GWSdClientProtocol>)client;
    ASSIGN (shellPath, apath);
    ref = RETAIN (refn);
    nc = [NSNotificationCenter defaultCenter];   
       
    task = [NSTask new];
    [task setLaunchPath: cmd];

  //  [task setArguments: [NSArray arrayWithObject: @"-c"]];
	  [task setCurrentDirectoryPath: shellPath];			

    pipe[0] = [NSPipe pipe];
    [task setStandardInput: pipe[0]];

    pipe[1] = [NSPipe pipe];
	  [task setStandardOutput: pipe[1]];		
    handle = [pipe[1] fileHandleForReading];

	  [nc addObserver: self 
      	   selector: @selector(taskOut:) 
      			   name: NSFileHandleReadCompletionNotification
      		   object: handle];

	  [handle readInBackgroundAndNotify];

    pipe[2] = [NSPipe pipe];
	  [task setStandardError: pipe[2]];		
    handle = [pipe[2] fileHandleForReading];

    [nc addObserver: self 
      	   selector: @selector(taskErr:) 
      			   name: NSFileHandleReadCompletionNotification
      		   object: handle];

	  [handle readInBackgroundAndNotify];

    [nc addObserver: self 
      	   selector: @selector(endOfTask:) 
      			   name: NSTaskDidTerminateNotification
      		   object: task];

	  [task launch]; 
	}			

	return self;
}

- (void)stopTask
{
  if (task && [task isRunning]) {
		[nc removeObserver: self];
    [task terminate];
	} 
	DESTROY (task);
}

- (void)newCommandLine:(NSString *)line
{
  NSFileHandle *handle = [[task standardInput] fileHandleForWriting];

  [handle writeData: [line dataUsingEncoding: [NSString defaultCStringEncoding]]];
}

- (void)taskOut:(NSNotification *)notif
{
	NSFileHandle *handle = [notif object];
  NSDictionary *userInfo = [notif userInfo];
  NSData *data = [userInfo objectForKey: NSFileHandleNotificationDataItem];

  [gwsdClient remoteShellWithRef: ref hasAvailableData: data];
  
  if (task && [task isRunning]) {
		[handle readInBackgroundAndNotify];
  }
}

- (void)taskErr:(NSNotification *)notif
{
	NSFileHandle *handle = [notif object];
  NSDictionary *userInfo = [notif userInfo];
  NSData *data = [userInfo objectForKey: NSFileHandleNotificationDataItem];

  [gwsdClient remoteShellWithRef: ref hasAvailableData: data];

  if (task && [task isRunning]) {
		[handle readInBackgroundAndNotify];
  }
}

- (void)endOfTask:(NSNotification *)notif
{
	if ([notif object] == task) {
  
  
        NSLog(@"Task status = %i", [task terminationStatus]);
  
  
		[nc removeObserver: self];
  	RELEASE (task);
    
    NSLog(@"END OF TASK");
    
    

    [gwsd shellDone: self];
    
	}
}

- (NSNumber *)refNumber
{
  return ref;
}

@end
