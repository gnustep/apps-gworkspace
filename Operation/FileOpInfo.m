/* FileOpInfo.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Operation application
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "FileOpInfo.h"
#include "Operation.h"
#include "Functions.h"
#include "GNUstep.h"

#define PROGR_STEPS (100.0)

static NSString *nibName = @"FileOperationWin";

@implementation FileOpInfo

- (void)dealloc
{
	[nc removeObserver: self];

  RELEASE (operationDict);
  RELEASE (type);
  TEST_RELEASE (source);
  TEST_RELEASE (destination);
  TEST_RELEASE (files);
  TEST_RELEASE (notifNames);
  TEST_RELEASE (win);
  TEST_RELEASE (progInd);
  TEST_RELEASE (progView);
  
  DESTROY (executor);
  DESTROY (execconn);
  
  [super dealloc];
}

+ (id)operationOfType:(NSString *)tp
                  ref:(int)rf
               source:(NSString *)src
          destination:(NSString *)dst
                files:(NSArray *)fls
         confirmation:(BOOL)conf
            usewindow:(BOOL)uwnd
              winrect:(NSRect)wrect
           controller:(id)cntrl
{
  return AUTORELEASE ([[self alloc] initWithOperationType: tp ref: rf
                                source: src destination: dst files: fls 
                                      confirmation: conf usewindow: uwnd 
                                        winrect: wrect controller: cntrl]);
}

- (id)initWithOperationType:(NSString *)tp
                        ref:(int)rf
                     source:(NSString *)src
                destination:(NSString *)dst
                      files:(NSArray *)fls
               confirmation:(BOOL)conf
                  usewindow:(BOOL)uwnd
                    winrect:(NSRect)wrect
                 controller:(id)cntrl
{
	self = [super init];

  if (self) {
    win = nil;
    showwin = uwnd;
  
    if (showwin) {
      NSRect r;
      
		  if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
        NSLog(@"failed to load %@!", nibName);
        DESTROY (self);
        return self;
      }
      
      if (NSEqualRects(wrect, NSZeroRect) == NO) {
        [win setFrame: wrect display: NO];
      } else if ([win setFrameUsingName: @"fopinfo"] == NO) {
        [win setFrame: NSMakeRect(300, 300, 282, 102) display: NO];
      }

      RETAIN (progInd);
      r = [[(NSBox *)progBox contentView] frame];
      progView = [[ProgressView alloc] initWithFrame: r refreshInterval: 0.05];

      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [pauseButt setTitle: NSLocalizedString(@"Pause", @"")];
      [stopButt setTitle: NSLocalizedString(@"Stop", @"")];      
    }
    
    ref = rf;
    controller = cntrl;
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
    dnc = [NSDistributedNotificationCenter defaultCenter];
    
    ASSIGN (type, tp);
    ASSIGN (source, src);
    ASSIGN (destination, dst);
		files = [fls mutableCopy];	
    
    operationDict = [NSMutableDictionary new];
    [operationDict setObject: type forKey: @"operation"]; 
    [operationDict setObject: [NSNumber numberWithInt: ref] forKey: @"ref"];
    [operationDict setObject: source forKey: @"source"]; 
    [operationDict setObject: destination forKey: @"destination"]; 
    [operationDict setObject: files forKey: @"files"]; 

    confirm = conf;
    executor = nil;
    opdone = NO;
  }
  
	return self;
}

- (void)startOperation
{
  NSPort *port[2];
  NSArray *ports;

  if (confirm) {    
	  NSString *title;
	  NSString *msg, *msg1, *msg2;

	  if ([type isEqual: @"NSWorkspaceMoveOperation"]) {
		  title = NSLocalizedString(@"Move", @"");
		  msg1 = NSLocalizedString(@"Move from: ", @"");
		  msg2 = NSLocalizedString(@"\nto: ", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	  } else if ([type isEqual: @"NSWorkspaceCopyOperation"]) {
		  title = NSLocalizedString(@"Copy", @"");
		  msg1 = NSLocalizedString(@"Copy from: ", @"");
		  msg2 = NSLocalizedString(@"\nto: ", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	  } else if ([type isEqual: @"NSWorkspaceLinkOperation"]) {
		  title = NSLocalizedString(@"Link", @"");
		  msg1 = NSLocalizedString(@"Link ", @"");
		  msg2 = NSLocalizedString(@"\nto: ", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	  } else if ([type isEqual: @"NSWorkspaceRecycleOperation"]) {
		  title = NSLocalizedString(@"Recycler", @"");
		  msg1 = NSLocalizedString(@"Move from: ", @"");
		  msg2 = NSLocalizedString(@"\nto the Recycler", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@?", msg1, source, msg2];
	  } else if ([type isEqual: @"GWorkspaceRecycleOutOperation"]) {
		  title = NSLocalizedString(@"Recycler", @"");
		  msg1 = NSLocalizedString(@"Move from the Recycler ", @"");
		  msg2 = NSLocalizedString(@"\nto: ", @"");
		  msg = [NSString stringWithFormat: @"%@%@%@?", msg1, msg2, destination];
	  } else if ([type isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
		  title = NSLocalizedString(@"Recycler", @"");
		  msg = NSLocalizedString(@"Empty the Recycler?", @"");
	  } else if ([type isEqual: @"NSWorkspaceDestroyOperation"]) {
		  title = NSLocalizedString(@"Delete", @"");
		  msg = NSLocalizedString(@"Delete the selected objects?", @"");
	  } else if ([type isEqual: @"NSWorkspaceDuplicateOperation"]) {
		  title = NSLocalizedString(@"Duplicate", @"");
		  msg = NSLocalizedString(@"Duplicate the selected objects?", @"");
	  }

    if (NSRunAlertPanel(title, msg, 
                        NSLocalizedString(@"OK", @""), 
				                NSLocalizedString(@"Cancel", @""), 
                        nil) != NSAlertDefaultReturn) {
      [self endOperation];
      return;
    }
  } 

  port[0] = (NSPort *)[NSPort port];
  port[1] = (NSPort *)[NSPort port];

  ports = [NSArray arrayWithObjects: port[1], port[0], nil];

  execconn = [[NSConnection alloc] initWithReceivePort: port[0]
				                                      sendPort: port[1]];
  [execconn setRootObject: self];
  [execconn setDelegate: self];

  [nc addObserver: self
         selector: @selector(connectionDidDie:)
             name: NSConnectionDidDieNotification
           object: execconn];    

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(setPorts:)
		                           toTarget: [FileOpExecutor class]
		                         withObject: ports];
    }
  NS_HANDLER
    {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"A fatal error occured while detaching the thread!", @""), 
                      NSLocalizedString(@"Continue", @""), 
                      nil, 
                      nil);
      [self endOperation];
    }
  NS_ENDHANDLER

  [nc addObserver: self
         selector: @selector(threadWillExit:)
             name: NSThreadWillExitNotification
           object: nil];    
}

- (void)threadWillExit:(NSNotification *)notification
{
  NSLog(@"operation thread will exit");
}

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title
{
  return NSRunAlertPanel(NSLocalizedString(title, @""),
												 NSLocalizedString(message, @""),
											   NSLocalizedString(@"OK", @""), 
												 NSLocalizedString(@"Cancel", @""), 
                         nil);       
}

- (int)showErrorAlertWithMessage:(NSString *)message
{
  return NSRunAlertPanel(nil, 
                         NSLocalizedString(message, @""), 
												 NSLocalizedString(@"Continue", @""), 
                         nil, 
                         nil);
}

- (IBAction)pause:(id)sender
{
  if (executor) {  
	  if ([executor isPaused] == NO) {
		  [pauseButt setTitle: NSLocalizedString(@"Continue", @"")];
		  [stopButt setEnabled: NO];	
      [executor Pause];
	  } else {
		  [pauseButt setTitle: NSLocalizedString(@"Pause", @"")];
		  [stopButt setEnabled: YES];	
		  [executor performOperation];
	  }
  }
}

- (IBAction)stop:(id)sender
{
  if (executor) {
	  [executor Stop];
  }
}

- (void)showProgressWin
{  
  if ([win isVisible] == NO) {
    if ([type isEqual: @"NSWorkspaceMoveOperation"]) {
      [win setTitle: NSLocalizedString(@"Move", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInContainer(fromField, destination)];
    
    } else if ([type isEqual: @"NSWorkspaceCopyOperation"]) {
      [win setTitle: NSLocalizedString(@"Copy", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInContainer(fromField, destination)];
    
    } else if ([type isEqual: @"NSWorkspaceLinkOperation"]) {
      [win setTitle: NSLocalizedString(@"Link", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInContainer(fromField, destination)];
    
    } else if ([type isEqual: @"NSWorkspaceDuplicateOperation"]) {
      [win setTitle: NSLocalizedString(@"Duplicate", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"In:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, destination)];
      [toLabel setStringValue: @""];
      [toField setStringValue: @""];
    
    } else if ([type isEqual: @"NSWorkspaceDestroyOperation"]) {
      [win setTitle: NSLocalizedString(@"Destroy", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"In:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, destination)];
      [toLabel setStringValue: @""];
      [toField setStringValue: @""];
    
    } else if ([type isEqual: @"NSWorkspaceRecycleOperation"]) {
      [win setTitle: NSLocalizedString(@"Move", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: NSLocalizedString(@"the Recycler", @"")];
        
    } else if ([type isEqual: @"GWorkspaceRecycleOutOperation"]) {
      [win setTitle: NSLocalizedString(@"Move", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: NSLocalizedString(@"the Recycler", @"")];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInContainer(fromField, destination)];
                            
    } else if ([type isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
      [win setTitle: NSLocalizedString(@"Destroy", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"In:", @"")];
      [fromField setStringValue: NSLocalizedString(@"the Recycler", @"")];
      [toLabel setStringValue: @""];
      [toField setStringValue: @""];    
    }
    
    [(NSBox *)progBox setContentView: progView];
    [progView start];
  }
  
  [win makeKeyAndOrderFront: nil];
  showwin = YES;
}

- (void)setNumFiles:(int)n
{
  [progView stop];  
  [(NSBox *)progBox setContentView: progInd];
  [progInd setMinValue: 0.0];
  [progInd setMaxValue: n];
  [progInd setDoubleValue: 0.0];
  [executor performOperation]; 
}

- (void)setProgIndicatorValue:(int)n
{
  [progInd setDoubleValue: n];
}

- (void)endOperation
{
  if (showwin) {
    if ([(NSBox *)progBox contentView] == progView) {
      [progView stop];  
    }
    [win saveFrameUsingName: @"fopinfo"];
    [win close];
  }
  
  if (executor) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: execconn];
    [executor exitThread];
    DESTROY (executor);
    DESTROY (execconn);
  }
  
  [controller endOfFileOperation: self];
}

- (void)sendWillChangeNotification
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];	
  int i;
    
  notifNames = [NSMutableArray new];
  
  for (i = 0; i < [files count]; i++) {
    NSDictionary *fdict = [files objectAtIndex: i];
    NSString *name = [fdict objectForKey: @"name"]; 
    [notifNames addObject: name];
  }
  
	[dict setObject: type forKey: @"operation"];	
  [dict setObject: source forKey: @"source"];	
  [dict setObject: destination forKey: @"destination"];	
  [dict setObject: notifNames forKey: @"files"];	

	[dnc postNotificationName: @"GWFileSystemWillChangeNotification"
	 								   object: nil 
                   userInfo: dict];
}

- (void)sendDidChangeNotification
{
  NSMutableDictionary *notifObj = [NSMutableDictionary dictionary];		

	[notifObj setObject: type forKey: @"operation"];	
  [notifObj setObject: source forKey: @"source"];	
  [notifObj setObject: destination forKey: @"destination"];	
  
  if (executor) {
    NSData *data = [executor processedFiles];
    NSArray *procFiles = [NSUnarchiver unarchiveObjectWithData: data];
    
    [notifObj setObject: procFiles forKey: @"files"];	
    [notifObj setObject: notifNames forKey: @"origfiles"];	
  } else {
    [notifObj setObject: notifNames forKey: @"files"];
    [notifObj setObject: notifNames forKey: @"origfiles"];	
  }
  
  opdone = YES;			

	[dnc postNotificationName: @"GWFileSystemDidChangeNotification"
	 						       object: nil 
                   userInfo: notifObj];  
}

- (void)registerExecutor:(id)anObject
{
  NSData *opinfo = [NSArchiver archivedDataWithRootObject: operationDict];
  BOOL samename;

  [anObject setProtocolForProxy: @protocol(FileOpExecutorProtocol)];
  executor = (id <FileOpExecutorProtocol>)[anObject retain];
  
  [executor setOperation: opinfo];  
  samename = [executor checkSameName];
  
  if (samename) {
	  NSString *msg, *title;
    int result;
    
		if ([type isEqual: @"NSWorkspaceMoveOperation"]) {	
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Move";
		
		} else if ([type isEqual: @"NSWorkspaceCopyOperation"]) {
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Copy";

		} else if ([type isEqual: @"NSWorkspaceLinkOperation"]) {
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Link";

		} else if ([type isEqual: @"NSWorkspaceRecycleOperation"]) {
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Recycle";

		} else if ([type isEqual: @"GWorkspaceRecycleOutOperation"]) {
			msg = @"Some items have the same name;\ndo you want to replace them?";
			title = @"Recycle";
		}
  
    result = NSRunAlertPanel(NSLocalizedString(title, @""),
														 NSLocalizedString(msg, @""),
														 NSLocalizedString(@"OK", @""), 
														 NSLocalizedString(@"Cancel", @""), 
                             NSLocalizedString(@"Only older", @"")); 

		if (result == NSAlertAlternateReturn) {  
      [controller endOfFileOperation: self];
      return;   
		} else if (result == NSAlertOtherReturn) {  
      [executor setOnlyOlder];
    }
  } 
      
  if (showwin) {
    [self showProgressWin];
  }

  [self sendWillChangeNotification];  
  [executor calculateNumFiles];
}

- (BOOL)connection:(NSConnection*)ancestor 
								shouldMakeNewConnection:(NSConnection*)newConn
{
	if (ancestor == execconn) {
  	[newConn setDelegate: self];
  	[nc addObserver: self 
					 selector: @selector(connectionDidDie:)
	    				 name: NSConnectionDidDieNotification 
             object: newConn];
  	return YES;
	}
		
  return NO;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  [nc removeObserver: self
	              name: NSConnectionDidDieNotification 
              object: [notification object]];

  if (opdone == NO) {
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"executor connection died!", @""), 
                    NSLocalizedString(@"Continue", @""), 
                    nil, 
                    nil);
    [self sendDidChangeNotification];
    [self endOperation];
  }
}

- (NSString *)type
{
  return type;
}

- (NSString *)source
{
  return source;
}

- (NSString *)destination
{
  return destination;
}

- (NSArray *)files
{
  return files;
}

- (int)ref
{
  return ref;
}

- (BOOL)showsWindow
{
  return showwin;
}

- (NSWindow *)win
{
  return win;
}

- (NSRect)winRect
{
  if (win && [win isVisible]) {
    return [win frame];
  }
  return NSZeroRect;
}

@end


@implementation FileOpExecutor

+ (void)setPorts:(NSArray *)thePorts
{
  NSAutoreleasePool *pool;
  NSPort *port[2];
  NSConnection *conn;
  FileOpExecutor *executor;
               
  pool = [[NSAutoreleasePool alloc] init];
               
  port[0] = [thePorts objectAtIndex: 0];             
  port[1] = [thePorts objectAtIndex: 1];             

  conn = [NSConnection connectionWithReceivePort: (NSPort *)port[0]
                                        sendPort: (NSPort *)port[1]];
  
  executor = [[self alloc] init];
  [executor setFileop: thePorts];
  [(id)[conn rootProxy] registerExecutor: executor];
  RELEASE (executor);
                              
  [[NSRunLoop currentRunLoop] run];
  RELEASE (pool);
}

- (void)dealloc
{
  TEST_RELEASE (operation);
  TEST_RELEASE (source);
  TEST_RELEASE (destination);
  TEST_RELEASE (files);
  TEST_RELEASE (procfiles);
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {
    fm = [NSFileManager defaultManager];
		stopped = NO;
		paused = NO;  
		samename = NO;
    onlyolder = NO;
  }
  
  return self;
}

- (void)setFileop:(NSArray *)thePorts
{
  NSPort *port[2];
  NSConnection *conn;
  id anObject;
  
  port[0] = [thePorts objectAtIndex: 0];             
  port[1] = [thePorts objectAtIndex: 1];             

  conn = [NSConnection connectionWithReceivePort: (NSPort *)port[0]
                                        sendPort: (NSPort *)port[1]];

  anObject = (id)[conn rootProxy];
  [anObject setProtocolForProxy: @protocol(FileOpInfoProtocol)];
  fileOp = (id <FileOpInfoProtocol>)anObject;
}

- (BOOL)setOperation:(NSData *)opinfo
{
  NSDictionary *opDict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  id dictEntry;
  int i;

  dictEntry = [opDict objectForKey: @"operation"];
  if (dictEntry) {
    ASSIGN (operation, dictEntry);   
  } 

  dictEntry = [opDict objectForKey: @"source"];
  if (dictEntry) {
    ASSIGN (source, dictEntry);
  }  

  dictEntry = [opDict objectForKey: @"destination"];
  if (dictEntry) {
    ASSIGN (destination, dictEntry);
  }  

  files = [NSMutableArray new];
  dictEntry = [opDict objectForKey: @"files"];
  if (dictEntry) {
    for (i = 0; i < [dictEntry count]; i++) {
      [files addObject: [dictEntry objectAtIndex: i]];
    }
  }		
  
  procfiles = [NSMutableArray new];
  
  return YES;
}

- (BOOL)checkSameName
{
	NSArray *dirContents;
	int i;
    
	samename = NO;
	
	if (destination && [files count]) {
		dirContents = [fm directoryContentsAtPath: destination];
		for (i = 0; i < [files count]; i++) {
      NSDictionary *dict = [files objectAtIndex: i];
      NSString *name = [dict objectForKey: @"name"]; 
    
      if ([dirContents containsObject: name]) {
        samename = YES;
        break;
      }
		}
	}
	
	if (samename) {
		if (([operation isEqual: @"NSWorkspaceMoveOperation"]) 
          || ([operation isEqual: @"NSWorkspaceCopyOperation"])
          || ([operation isEqual: @"NSWorkspaceLinkOperation"])
          || ([operation isEqual: @"GWorkspaceRecycleOutOperation"])) {
          
      return YES;
      
		} else if (([operation isEqual: @"NSWorkspaceDestroyOperation"]) 
          || ([operation isEqual: @"NSWorkspaceDuplicateOperation"])
          || ([operation isEqual: @"NSWorkspaceRecycleOperation"])
          || ([operation isEqual: @"GWorkspaceEmptyRecyclerOperation"])) {
			
      return NO;
		} 
	}
  
  return NO;
}

- (void)setOnlyOlder
{
  onlyolder = YES;
}

- (oneway void)calculateNumFiles
{
	BOOL isDir;
  NSDirectoryEnumerator *enumerator;
  NSString *dirEntry;
  int i, fnum = 0;

  for (i = 0; i < [files count]; i++) {
    NSDictionary *dict = [files objectAtIndex: i];
    NSString *name = [dict objectForKey: @"name"]; 
    NSString *path = [source stringByAppendingPathComponent: name];       

	  isDir = NO;
	  [fm fileExistsAtPath: path isDirectory: &isDir];
	  if (isDir) {
      enumerator = [fm enumeratorAtPath: path];
      while ((dirEntry = [enumerator nextObject])) {
        if (stopped) {
          break;
        }
			  fnum++;
      }
	  } else {
		  fnum++;
	  }
    
    if (stopped) {
      break;
    }
  }

  if (stopped) {
    [self done];
  }

  fcount = 0;
  stepcount = 0;
  
  if (fnum < PROGR_STEPS) {
    progstep = 1.0;
  } else {
    progstep = fnum / PROGR_STEPS;
  }
  
  [fileOp setNumFiles: fnum];
}

- (oneway void)performOperation
{
	canupdate = YES; 
  stopped = NO;
  paused = NO;
          
	if ([operation isEqual: @"NSWorkspaceMoveOperation"]
						|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
		[self doMove];
	} else if ([operation isEqual: @"NSWorkspaceCopyOperation"]) {  
		[self doCopy];
	} else if ([operation isEqual: @"NSWorkspaceLinkOperation"]) {
		[self doLink];
	} else if ([operation isEqual: @"NSWorkspaceDestroyOperation"]
					|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
		[self doRemove];
	} else if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) {
		[self doDuplicate];
	} else if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
		[self doTrash];
  }
}

- (NSData *)processedFiles
{
  return [NSArchiver archivedDataWithRootObject: procfiles];
}

#define CHECK_DONE \
if (([files count] == 0) || stopped || paused) break

#define GET_FILENAME \
fileinfo = [files objectAtIndex: 0]; \
filename =  [fileinfo objectForKey: @"name"]

- (void)doMove
{
  while (1) {
	  GET_FILENAME;    

    if ((samename == NO) || (samename && [self removeExisting: fileinfo])) {
	    [fm movePath: [source stringByAppendingPathComponent: filename]
				    toPath: [destination stringByAppendingPathComponent: filename]
	 		     handler: self];
      [procfiles addObject: filename];	
    }
	  [files removeObject: fileinfo];	
    
	  CHECK_DONE;	
  }
  
  if (([files count] == 0) || stopped) {
    [self done];
  }
}

- (void)doCopy
{
  while (1) {
	  GET_FILENAME;   

    if ((samename == NO) || (samename && [self removeExisting: fileinfo])) {
	    [fm copyPath: [source stringByAppendingPathComponent: filename]
				    toPath: [destination stringByAppendingPathComponent: filename]
	 		    handler: self];
      [procfiles addObject: filename];	     
    }
	  [files removeObject: fileinfo];	 
    
	  CHECK_DONE;	
  }

  if (([files count] == 0) || stopped) {
    [self done];
  }                                          
}

- (void)doLink
{
  while (1) {
	  GET_FILENAME;    
    
    if ((samename == NO) || (samename && [self removeExisting: fileinfo])) {
      NSString *dst = [destination stringByAppendingPathComponent: filename];
      NSString *src = [source stringByAppendingPathComponent: filename];
  
      [fm createSymbolicLinkAtPath: dst pathContent: src];
      [procfiles addObject: filename];	      
    }
	  [files removeObject: fileinfo];	    
    
	  CHECK_DONE;	
  }

  if (([files count] == 0) || stopped) {
    [self done];
  }                                            
}

- (void)doRemove
{
  while (1) {
	  GET_FILENAME;  
	
	  [fm removeFileAtPath: [destination stringByAppendingPathComponent: filename]
				         handler: self];

    [procfiles addObject: filename];	 
	  [files removeObject: fileinfo];	
    
	  CHECK_DONE;	
  }

  if (([files count] == 0) || stopped) {
    [self done];
  }                                       
}

- (void)doDuplicate
{
  NSString *copystr = NSLocalizedString(@"_copy", @"");
  NSString *base;
  NSString *ext;
	NSString *destpath;
	NSString *newname;
  NSString *ntmp;

  while (1) {
    int count = 1;
    
	  GET_FILENAME;  

	  newname = [NSString stringWithString: filename];
    ext = [newname pathExtension]; 
    base = [newname stringByDeletingPathExtension];
    
	  while (1) {
      if (count == 1) {
        ntmp = [NSString stringWithFormat: @"%@%@", base, copystr];
        if ([ext length]) {
          ntmp = [ntmp stringByAppendingPathExtension: ext];
        }
      } else {
        ntmp = [NSString stringWithFormat: @"%@%@%i", base, copystr, count];
        if ([ext length]) {
          ntmp = [ntmp stringByAppendingPathExtension: ext];
        }
      }
      
		  destpath = [destination stringByAppendingPathComponent: ntmp];

		  if ([fm fileExistsAtPath: destpath] == NO) {
        newname = ntmp;
			  break;
      } else {
        count++;
      }
	  }

	  [fm copyPath: [destination stringByAppendingPathComponent: filename]
				  toPath: destpath 
			   handler: self];

    [procfiles addObject: newname];	 
	  [files removeObject: fileinfo];	   
    
	  CHECK_DONE;
  }
  
  if (([files count] == 0) || stopped) {
    [self done];
  }                                             
}

- (void)doTrash
{
  NSString *copystr = NSLocalizedString(@"_copy", @"");
	NSString *destpath;
	NSString *newname;
  NSString *ntmp;

  while (1) {    
	  GET_FILENAME;  

    newname = [NSString stringWithString: filename];
    destpath = [destination stringByAppendingPathComponent: newname];
    
    if ([fm fileExistsAtPath: destpath]) {
      NSString *ext = [filename pathExtension]; 
      NSString *base = [filename stringByDeletingPathExtension]; 

      newname = [NSString stringWithString: filename];
      int count = 1;

	    while (1) {
        if (count == 1) {
          ntmp = [NSString stringWithFormat: @"%@%@", base, copystr];
          if ([ext length]) {
            ntmp = [ntmp stringByAppendingPathExtension: ext];
          }
        } else {
          ntmp = [NSString stringWithFormat: @"%@%@%i", base, copystr, count];
          if ([ext length]) {
            ntmp = [ntmp stringByAppendingPathExtension: ext];
          }
        }

		    destpath = [destination stringByAppendingPathComponent: ntmp];

		    if ([fm fileExistsAtPath: destpath] == NO) {
          newname = ntmp;
			    break;
        } else {
          count++;
        }
	    }
    }

	  [fm movePath: [source stringByAppendingPathComponent: filename]
				  toPath: destpath 
			   handler: self];
    
    [procfiles addObject: newname];	 
	  [files removeObject: fileinfo];	   
    
	  CHECK_DONE;
  }
  
  if (([files count] == 0) || stopped) {
    [self done];
  }                                             
}

- (BOOL)removeExisting:(NSDictionary *)info
{
  NSString *fname =  [info objectForKey: @"name"];
	NSString *destpath = [destination stringByAppendingPathComponent: fname]; 
    
	canupdate = NO; 
  
	if ([fm fileExistsAtPath: destpath]) {
    if (onlyolder) {
      NSDictionary *attributes = [fm fileAttributesAtPath: destpath traverseLink: NO];
      NSDate *dstdate = [attributes objectForKey: NSFileModificationDate];
      NSDate *srcdate = [info objectForKey: @"date"];
    
      if ([srcdate isEqual: dstdate] == NO) {
        if ([[srcdate earlierDate: dstdate] isEqual: srcdate]) {
          canupdate = YES;
          return NO;
        }
      } else {
        canupdate = YES;
        return NO;
      }
    }
  
		[fm removeFileAtPath: destpath handler: self]; 
	}
  
	canupdate = YES;
  
  return YES;
}

- (void)Pause
{
  paused = YES;
}

- (void)Stop
{
  stopped = YES;
}

- (BOOL)isPaused
{
  return paused;
}

- (void)done
{
  [fileOp sendDidChangeNotification];
  [fileOp endOperation];  
}

- (oneway void)exitThread
{
  [NSThread exit];
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{  
  NSString *path, *msg;
  BOOL iserror = NO;
  int result;
  
  path = [errorDict objectForKey: @"Path"];
  
  msg = [NSString stringWithFormat: @"%@ %@\n%@ %@\n",
							NSLocalizedString(@"File operation error:", @""),
							[errorDict objectForKey: @"Error"],
							NSLocalizedString(@"with file:", @""),
							path];

  result = [fileOp requestUserConfirmationWithMessage: msg title: @"Error"];
    
	if(result != NSAlertDefaultReturn) {
    [fileOp sendDidChangeNotification];
    [fileOp endOperation];
    
	} else {  
    NSString *fname = [path lastPathComponent];
    BOOL found = NO;
    
    while (1) {     
      if ([path isEqualToString: source] == YES) {
        break;      
      }    
     
      if ([files containsObject: fname] == YES) {
        [files removeObject: fname];
        found = YES;
        break;
      }
         
      path = [path stringByDeletingLastPathComponent];
      fname = [path lastPathComponent];
    }   
    
    if (found == YES) {
      [self performOperation]; 
    } else {
      result = [fileOp showErrorAlertWithMessage: @"File Operation Error!"];
      [fileOp sendDidChangeNotification];
      [fileOp endOperation];
      return NO;
    }
  }
  
	return !iserror;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
  if (canupdate) {
    fcount++;
    stepcount++;
    
    if (stepcount >= progstep) {
      stepcount = 0;
      [fileOp setProgIndicatorValue: fcount];
    }
  }
}

@end

@implementation ProgressView

#define PROG_IND_MAX (-28)

- (void)dealloc
{
  RELEASE (image);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(float)refresh
{
  self = [super initWithFrame: frameRect];

  if (self) {
    ASSIGN (image, [NSImage imageNamed: @"progind.tiff"]);
    rfsh = refresh;
    orx = PROG_IND_MAX;
  }

  return self;
}

- (void)start
{
  progTimer = [NSTimer scheduledTimerWithTimeInterval: rfsh 
						            target: self selector: @selector(animate:) 
																					userInfo: nil repeats: YES];
}

- (void)stop
{
  if (progTimer && [progTimer isValid]) {
    [progTimer invalidate];
  }
}

- (void)animate:(id)sender
{
  orx++;
  [self setNeedsDisplay: YES];
  
  if (orx == 0) {
    orx = PROG_IND_MAX;
  }
}

- (void)drawRect:(NSRect)rect
{
  [image compositeToPoint: NSMakePoint(orx, 2) 
                operation: NSCompositeSourceOver];
}

@end
