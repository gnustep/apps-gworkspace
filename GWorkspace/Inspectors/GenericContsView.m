/*  -*-objc-*-
 *  GenericContsView.m: Implementation of the GenericContsView Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
  #else
#include <GWorkspace/GWFunctions.h>
  #endif
#include "GenericContsView.h"
#include "config.h"
#include "GNUstep.h"

@implementation GenericContsView

- (void)dealloc
{
  [nc removeObserver: self];
  if (task && [task isRunning]) {
    [task terminate];
	}
  TEST_RELEASE (task);
  TEST_RELEASE (shComm);
  TEST_RELEASE (fileComm);  
	[super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame: frameRect];
	
	if (self) {	
    NSString *comm;
    
		[self setDrawsBackground: NO];
    [self setRichText: YES];
    [self setEditable: NO];
    [self setSelectable: NO];
        
    comm = [NSString stringWithCString: SHPATH];
    if ([comm isEqual: @"none"] == NO) {
      ASSIGN (shComm, comm);
    } else {
      shComm = nil;
    }
    
    comm = [NSString stringWithCString: FILEPATH];
    if ([comm isEqual: @"none"] == NO) {
      ASSIGN (fileComm, comm);
    } else {
      fileComm = nil;
    }
    
		nc = [NSNotificationCenter defaultCenter];
    task = nil;
	}
	
	return self;
}

- (void)findContentsAtPath:(NSString *)apath
{
  NSArray *args;
	NSFileHandle *fileHandle;

  if (shComm && fileComm) {  
    if (task && [task isRunning]) {
		  [task terminate];
		  DESTROY (task);		
	  }

	  ASSIGN (task, [NSTask new]); 
    [task setLaunchPath: shComm];
    
    args = [NSArray arrayWithObjects: @"-c", [NSString stringWithFormat: @"%@ -b %@", fileComm, apath], nil];
    [task setArguments: args];

    ASSIGN (pipe, [NSPipe pipe]);
	  AUTORELEASE (pipe);
    [task setStandardOutput: pipe];

    fileHandle = [pipe fileHandleForReading];
    [nc addObserver: self
    		   selector: @selector(dataFromTask:)
    				   name: NSFileHandleReadToEndOfFileCompletionNotification
    			   object: (id)fileHandle];

    [fileHandle readToEndOfFileInBackgroundAndNotify];    

    [nc addObserver: self 
           selector: @selector(endOfTask:) 
               name: NSTaskDidTerminateNotification 
             object: (id)task];

    [task launch];      
  
  } else {  
    [self setString: NSLocalizedString(@"No Contents Inspector", @"")];
  }        
}

- (void)dataFromTask:(NSNotification *)notification
{
  NSDictionary *userInfo = [notification userInfo];
  NSData *readData = [userInfo objectForKey: NSFileHandleNotificationDataItem];
  NSString *s = [[NSString alloc] initWithData: readData 
                          encoding: [NSString defaultCStringEncoding]];
  NSAttributedString *attrstr = [[NSAttributedString alloc] initWithString: s];
  NSRange range = NSMakeRange(0, [attrstr length]);
  NSFont *font = [NSFont systemFontOfSize: 18];
  NSTextStorage *storage = [self textStorage];
  NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];

  [style setParagraphStyle: [NSParagraphStyle defaultParagraphStyle]];   
  [style setAlignment: NSCenterTextAlignment];

  [storage setAttributedString: attrstr];

  [storage addAttribute: NSParagraphStyleAttributeName 
                  value: style 
                  range: range];

  [storage addAttribute: NSFontAttributeName value: font range: range];

	[storage addAttribute: NSForegroundColorAttributeName 
										value: [NSColor grayColor] 
										range: range];			

	[self setNeedsDisplay: YES];		

  RELEASE (s);
  RELEASE (attrstr);
  RELEASE (style);
}

- (void)endOfTask:(NSNotification *)notification
{
	if ([notification object] == task) {		
		[nc removeObserver: self name: NSTaskDidTerminateNotification object: task];
		DESTROY (task);										
	}
}

@end
