#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
#include "GWLib.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "FileOperation.h"
#include "GWorkspace.h"
#include "GNUstep.h"

#ifndef LONG_DELAY
  #define LONG_DELAY 86400.0
#endif

static NSString *nibName = @"FileOperationWin";

@implementation GWorkspace (FileOperations)

- (int)fileOperationRef
{
  oprefnum++;  
  if (oprefnum == 1000) {
    oprefnum = 0;
  }  
  return oprefnum;
}

- (FileOperation *)fileOpWithRef:(int)ref
{
  int i;
  
  for (i = 0; i < [operations count]; i++) {
    FileOperation *op = [operations objectAtIndex: i];
  
    if ([op fileOperationRef] == ref) {
      return op;
    }
  }

  return nil;
}

- (void)endOfFileOperation:(FileOperation *)op
{
  [operations removeObject: op];
}

@end


@implementation FileOperation

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];

  if (timer && [timer isValid]) {
    [timer invalidate];
  }
  
  RELEASE (operationDict);
  RELEASE (operation);
  TEST_RELEASE (source);
  TEST_RELEASE (destination);
  TEST_RELEASE (files);
  TEST_RELEASE (notifNames);
  TEST_RELEASE (win);
  
  DESTROY (executor);
  
  [super dealloc];
}

- (id)initWithOperation:(NSString *)opr
                 source:(NSString *)src
		 	      destination:(NSString *)dest
                  files:(NSArray *)fls
        useConfirmation:(BOOL)conf
             showWindow:(BOOL)showw
             windowRect:(NSRect)wrect
{
	self = [super init];

  if (self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {   
      int i;

      /* Internationalization */
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [pauseButt setTitle: NSLocalizedString(@"Pause", @"")];
      [stopButt setTitle: NSLocalizedString(@"Stop", @"")];      

      if (NSEqualRects(wrect, NSZeroRect) == NO) {
        [win setFrame: wrect display: NO];
      } else if ([win setFrameUsingName: @"fileopprogress"] == NO) {
        [win setFrame: NSMakeRect(300, 300, 282, 102) display: NO];
      }
      [win setDelegate: self];  

      gw = [GWorkspace gworkspace];
      fm = [NSFileManager defaultManager];
      dnc = [NSDistributedNotificationCenter defaultCenter];

      fileOperationRef = [gw fileOperationRef];

		  operation = RETAIN (opr);
      operationDict = [[NSMutableDictionary alloc] initWithCapacity: 1];
      [operationDict setObject: operation forKey: @"operation"]; 

		  if (src != nil) {
			  source = [[NSString alloc] initWithString: src];
        [operationDict setObject: source forKey: @"source"]; 
		  }
		  if (dest != nil) {
			  destination = [[NSString alloc] initWithString: dest];
        [operationDict setObject: destination forKey: @"destination"]; 
		  }
		  if (fls != nil) {
			  files = [[NSMutableArray alloc] initWithCapacity: 1];	
			  for(i = 0; i < [fls count]; i++) {
				  [files addObject: [fls objectAtIndex: i]];
        }
        [operationDict setObject: files forKey: @"files"]; 
		  }
    
      confirm = conf;
      showwin = showw;
      executor = nil;
      opdone = NO;

      if([self showFileOperationAlert] == NO) {                	        
        [self endOperation];
        return self; 
      } else {
        NSPort *port[2];
        NSArray *ports;

        port[0] = (NSPort *)[NSPort port];
        port[1] = (NSPort *)[NSPort port];
        ports = [NSArray arrayWithObjects: port[1], port[0], nil];

        execconn = [[NSConnection alloc] initWithReceivePort: port[0]
				                                            sendPort: port[1]];
        [execconn setRootObject: self];
        [execconn setDelegate: self];
        [execconn setRequestTimeout: LONG_DELAY];
        [execconn setReplyTimeout: LONG_DELAY];

        [[NSNotificationCenter defaultCenter] addObserver: self
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
            NSLog(@"Error! A fatal error occured while detaching the thread.");
          }
        NS_ENDHANDLER
        
        timer = [NSTimer scheduledTimerWithTimeInterval: 5.0 target: self 
          										          selector: @selector(checkExecutor:) 
                                                  userInfo: nil repeats: NO];                                             
      }
	  }			
  }
  
	return self;
}

- (void)checkExecutor:(id)sender
{
  if ((executor == nil) && (opdone == NO)) {  
	  NSString *msg = NSLocalizedString(@"A fatal error occured while detaching the thread!", @"");
	  NSString *buttstr = NSLocalizedString(@"Continue", @"");
	
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);
    [self sendDidChangeNotification];
    [self endOperation];
  }
}

- (BOOL)showFileOperationAlert
{
	NSString *title;
	NSString *msg, *msg1, *msg2;
	int result;
	
  if(confirm == NO) {
    return YES;
  }
  	
	if ([operation isEqual: @"NSWorkspaceMoveOperation"]) {
		title = NSLocalizedString(@"Move", @"");
		msg1 = NSLocalizedString(@"Move from: ", @"");
		msg2 = NSLocalizedString(@"\nto: ", @"");
		msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	} else if ([operation isEqual: @"NSWorkspaceCopyOperation"]) {
		title = NSLocalizedString(@"Copy", @"");
		msg1 = NSLocalizedString(@"Copy from: ", @"");
		msg2 = NSLocalizedString(@"\nto: ", @"");
		msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	} else if ([operation isEqual: @"NSWorkspaceLinkOperation"]) {
		title = NSLocalizedString(@"Link", @"");
		msg1 = NSLocalizedString(@"Link ", @"");
		msg2 = NSLocalizedString(@"\nto: ", @"");
		msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	} else if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
		title = NSLocalizedString(@"Recycler", @"");
		msg1 = NSLocalizedString(@"Move from: ", @"");
		msg2 = NSLocalizedString(@"\nto the Recycler", @"");
		msg = [NSString stringWithFormat: @"%@%@%@?", msg1, source, msg2];
	} else if ([operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
		title = NSLocalizedString(@"Recycler", @"");
		msg1 = NSLocalizedString(@"Move from the Recycler ", @"");
		msg2 = NSLocalizedString(@"\nto: ", @"");
		msg = [NSString stringWithFormat: @"%@%@%@?", msg1, msg2, destination];
	} else if ([operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
		title = NSLocalizedString(@"Recycler", @"");
		msg = NSLocalizedString(@"Empty the Recycler?", @"");
	} else if ([operation isEqual: @"NSWorkspaceDestroyOperation"]) {
		title = NSLocalizedString(@"Delete", @"");
		msg = NSLocalizedString(@"Delete the selected objects?", @"");
	} else if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) {
		title = NSLocalizedString(@"Duplicate", @"");
		msg = NSLocalizedString(@"Duplicate the selected objects?", @"");
	}
	
	result = NSRunAlertPanel(title, msg, NSLocalizedString(@"OK", @""), 
																		NSLocalizedString(@"Cancel", @""), NULL);
	if (result != NSAlertDefaultReturn) {
		return NO;
  }
	
	return YES;	
}

- (void)registerExecutor:(id)anObject
{
  BOOL result;

  [anObject setProtocolForProxy: @protocol(FileOpExecutorProtocol)];
  executor = (id <FileOpExecutorProtocol>)[anObject retain];
  
  result = [executor setOperation: operationDict];  
  result = [executor checkSameName];
  
  if (result == YES) {
	  NSString *msg, *title;
  
		if ([operation isEqual: @"NSWorkspaceMoveOperation"]) {	
			msg = @"Some items have the same name;\ndo you want to sobstitute them?";
			title = @"Move";
		
		} else if ([operation isEqual: @"NSWorkspaceCopyOperation"]) {
			msg = @"Some items have the same name;\ndo you want to sobstitute them?";
			title = @"Copy";

		} else if([operation isEqual: @"NSWorkspaceLinkOperation"]) {
			msg = @"Some items have the same name;\ndo you want to sobstitute them?";
			title = @"Link";

		} else if([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
			msg = @"Some items have the same name;\ndo you want to sobstitute them?";
			title = @"Recycle";

		} else if([operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
			msg = @"Some items have the same name;\ndo you want to sobstitute them?";
			title = @"Recycle";
		}
  
    result = NSRunAlertPanel(NSLocalizedString(title, @""),
														      NSLocalizedString(msg, @""),
																   NSLocalizedString(@"OK", @""), 
																		NSLocalizedString(@"Cancel", @""), NULL); 

		if (result != NSAlertDefaultReturn) {  
      [gw endOfFileOperation: self];
      return;   
		}
  } 
  
  filescount = [executor calculateNumFiles];  
  if (showwin) {
    [self showProgressWin];
  }
  [self sendWillChangeNotification];  
  [executor performOperation]; 
}

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title
{
  return NSRunAlertPanel(NSLocalizedString(title, @""),
														NSLocalizedString(message, @""),
																NSLocalizedString(@"OK", @""), 
																		NSLocalizedString(@"Cancel", @""), NULL);       
}

- (void)showProgressWin
{  
  if ([win isVisible] == NO) {
    if ([operation isEqual: @"NSWorkspaceMoveOperation"]) {
      [win setTitle: NSLocalizedString(@"Move", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInContainer(fromField, destination)];
    
    } else if ([operation isEqual: @"NSWorkspaceCopyOperation"]) {
      [win setTitle: NSLocalizedString(@"Copy", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInContainer(fromField, destination)];
    
    } else if ([operation isEqual: @"NSWorkspaceLinkOperation"]) {
      [win setTitle: NSLocalizedString(@"Link", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInContainer(fromField, destination)];
    
    } else if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) {
      [win setTitle: NSLocalizedString(@"Duplicate", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"In:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, destination)];
      [toLabel setStringValue: @""];
      [toField setStringValue: @""];
    
    } else if ([operation isEqual: @"NSWorkspaceDestroyOperation"]) {
      [win setTitle: NSLocalizedString(@"Destroy", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"In:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, destination)];
      [toLabel setStringValue: @""];
      [toField setStringValue: @""];
    
    } else if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
      [win setTitle: NSLocalizedString(@"Move", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: relativePathFittingInContainer(fromField, source)];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: NSLocalizedString(@"the Recycler", @"")];
        
    } else if ([operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
      [win setTitle: NSLocalizedString(@"Move", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"From:", @"")];
      [fromField setStringValue: NSLocalizedString(@"the Recycler", @"")];
      [toLabel setStringValue: NSLocalizedString(@"To:", @"")];
      [toField setStringValue: relativePathFittingInContainer(fromField, destination)];
                            
    } else if ([operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
      [win setTitle: NSLocalizedString(@"Destroy", @"")];
      [fromLabel setStringValue: NSLocalizedString(@"In:", @"")];
      [fromField setStringValue: NSLocalizedString(@"the Recycler", @"")];
      [toLabel setStringValue: @""];
      [toField setStringValue: @""];    
    }

    [progInd setMinValue: 0];
    [progInd setMaxValue: filescount];
  }
  
  [win makeKeyAndOrderFront: nil];
  showwin = YES;
}

- (int)showErrorAlertWithMessage:(NSString *)message
{
  return NSRunAlertPanel(nil, NSLocalizedString(message, @""), 
																NSLocalizedString(@"Continue", @""), nil, nil);
}

- (void)updateProgressIndicator
{
  [progInd incrementBy: 1.0];
}

- (void)endOperation
{  
  DESTROY (executor);
  if (showwin) {
    [win saveFrameUsingName: @"fileopprogress"];
    [win close];
  }
  [gw endOfFileOperation: self];
}

- (void)sendWillChangeNotification
{
  NSString *fulldestpath;
	NSMutableDictionary *dict;
  int i;
    
  notifNames = [[NSMutableArray alloc] initWithCapacity: 1];
  
  if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) {       
    for(i = 0; i < [files count]; i++) {
      NSString *name = [NSString stringWithString: [files objectAtIndex: i]];     
			while(1) {
				name = [name stringByAppendingString: @"_copy"];
				fulldestpath = [destination stringByAppendingPathComponent: name];        
				if (![fm fileExistsAtPath: fulldestpath]) {          
          [notifNames addObject: name];
					break;
        }
			}
    }
  } else {
    [notifNames addObjectsFromArray: files];
  }
  
	dict = [NSMutableDictionary dictionaryWithCapacity: 1];		
	[dict setObject: operation forKey: @"operation"];	
  [dict setObject: source forKey: @"source"];	
  [dict setObject: destination forKey: @"destination"];	
  [dict setObject: notifNames forKey: @"files"];	

	[dnc postNotificationName: GWFileSystemWillChangeNotification
	 								   object: nil 
                   userInfo: dict];
}

- (int)sendDidChangeNotification
{
  NSMutableDictionary *notifObj = [NSMutableDictionary dictionary];		

	[notifObj setObject: operation forKey: @"operation"];	
  [notifObj setObject: source forKey: @"source"];	
  [notifObj setObject: destination forKey: @"destination"];	
  [notifObj setObject: notifNames forKey: @"files"];	

  opdone = YES;			

	[dnc postNotificationName: GWFileSystemDidChangeNotification
	 						       object: nil 
                   userInfo: notifObj];  
                 
  return 0;
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

- (int)fileOperationRef
{
  return fileOperationRef;
}

- (NSRect)winRect
{
  if (win && [win isVisible]) {
    return [win frame];
  }
  return NSZeroRect;
}

- (BOOL)showsWindow
{
  return showwin;
}

- (BOOL)connection:(NSConnection*)ancestor 
								shouldMakeNewConnection:(NSConnection*)newConn
{
	if (ancestor == execconn) {
  	[[NSNotificationCenter defaultCenter] addObserver: self 
										selector: @selector(connectionDidDie:)
	    									name: NSConnectionDidDieNotification object: newConn];
  	[newConn setDelegate: self];
  	return YES;
	}
		
  return NO;
}

- (void)connectionDidDie:(NSNotification *)notification
{
	id conn = [notification object];
	
  [[NSNotificationCenter defaultCenter] removeObserver: self
	      name: NSConnectionDidDieNotification object: conn];

  if (opdone == NO) {
	  NSString *msg = NSLocalizedString(@"thread connection died!", @"");
	  NSString *buttstr = NSLocalizedString(@"Continue", @"");
  
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);
    [self sendDidChangeNotification];
    [self endOperation];
  }
}

- (BOOL)windowShouldClose:(id)sender
{
  [win saveFrameUsingName: @"fileopprogress"];
	return YES;
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
  [anObject setProtocolForProxy: @protocol(FileOpProtocol)];
  fileOp = (id <FileOpProtocol>)anObject;
}

- (BOOL)setOperation:(NSDictionary *)opDict
{
  id dictEntry;
  int i;

  dictEntry = [opDict objectForKey: @"operation"];
  if (dictEntry != nil) {
    ASSIGN (operation, dictEntry);   
  } 

  dictEntry = [opDict objectForKey: @"source"];
  if (dictEntry != nil) {
    ASSIGN (source, dictEntry);
  }  

  dictEntry = [opDict objectForKey: @"destination"];
  if (dictEntry != nil) {
    ASSIGN (destination, dictEntry);
  }  

  files = [[NSMutableArray alloc] initWithCapacity: 1];
  dictEntry = [opDict objectForKey: @"files"];
  if (dictEntry != nil) {
    for (i = 0; i < [dictEntry count]; i++) {
      [files addObject: [dictEntry objectAtIndex: i]];
    }
  }		
  
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
      if ([dirContents containsObject: [files objectAtIndex: i]]) {
        samename = YES;
        break;
      }
		}
	}
	
	if (samename) {
		if (([operation isEqual: NSWorkspaceMoveOperation]) 
          || ([operation isEqual: NSWorkspaceCopyOperation])
          || ([operation isEqual: NSWorkspaceLinkOperation])
          || ([operation isEqual: NSWorkspaceRecycleOperation])
          || ([operation isEqual: GWorkspaceRecycleOutOperation])) {
          
      return YES;
      
		} else if (([operation isEqual: NSWorkspaceDestroyOperation]) 
          || ([operation isEqual: NSWorkspaceDuplicateOperation])
          || ([operation isEqual: GWorkspaceEmptyRecyclerOperation])) {
			
      return NO;
		} 
	}
  
  return NO;
}

- (int)calculateNumFiles
{
	BOOL isDir;
  NSDirectoryEnumerator *enumerator;
  NSString *dirEntry;
  int i;

  for(i = 0; i < [files count]; i++) {
    NSString *path = [source stringByAppendingPathComponent: [files objectAtIndex: i]];       

	  isDir = NO;
	  [fm fileExistsAtPath: path isDirectory: &isDir];
	  if (isDir) {
      enumerator = [fm enumeratorAtPath: path];
      while ((dirEntry = [enumerator nextObject])) {
			  fcount++;
      }
	  } else {
		  fcount++;
	  }
  }

  return fcount;	
}

- (oneway void)performOperation
{
	canupdate = YES; 
  stopped = NO;
  paused = NO;
	fcount = [files count];
          
	if ([operation isEqual: NSWorkspaceMoveOperation]
				|| [operation isEqual: NSWorkspaceRecycleOperation]
						|| [operation isEqual: GWorkspaceRecycleOutOperation]) {
		[self doMove];
	} else if ([operation isEqual: NSWorkspaceCopyOperation]) {  
		[self doCopy];
	} else if([operation isEqual: NSWorkspaceLinkOperation]) {
		[self doLink];
	} else if([operation isEqual: NSWorkspaceDestroyOperation]
					|| [operation isEqual: GWorkspaceEmptyRecyclerOperation]) {
		[self doRemove];
	} else if([operation isEqual: NSWorkspaceDuplicateOperation]) {
		[self doDuplicate];
	}
}

#define CHECK_DONE \
if (![files count] || stopped) [self done]; \
if (paused) break 

#define GET_FILENAME filename = [files objectAtIndex: 0]

#define CHECK_SAME_NAME \
if (samename) [self removeExisting: filename]

#define WAIT \
[[NSRunLoop currentRunLoop] \
runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.01]]

- (void)doMove
{
  while (1) {
	  CHECK_DONE;	
	  GET_FILENAME;    
	  CHECK_SAME_NAME;

	  [fm movePath: [source stringByAppendingPathComponent: filename]
				  toPath: [destination stringByAppendingPathComponent: filename]
	 		   handler: self];

	  [files removeObject: filename];	    
    WAIT; 
  }                                          
}

- (void)doCopy
{
  while (1) {
	  CHECK_DONE;	
	  GET_FILENAME;   
	  CHECK_SAME_NAME;

	  [fm copyPath: [source stringByAppendingPathComponent: filename]
				  toPath: [destination stringByAppendingPathComponent: filename]
	 		   handler: self];

	  [files removeObject: filename];	 
    WAIT;    
  }                                        
}

- (void)doLink
{
  while (1) {
	  CHECK_DONE;	
	  GET_FILENAME;    
	  CHECK_SAME_NAME;

	  [fm linkPath: [source stringByAppendingPathComponent: filename]
				  toPath: [destination stringByAppendingPathComponent: filename]
	 	     handler: self];

	  [files removeObject: filename];	     
    WAIT;
  }                                            
}

- (void)doRemove
{
  while (1) {
	  CHECK_DONE;	
	  GET_FILENAME;  
	
	  [fm removeFileAtPath: [destination stringByAppendingPathComponent: filename]
				          handler: self];

	  [files removeObject: filename];	
    WAIT;     
  }                                       
}

- (void)doDuplicate
{
	NSString *fulldestpath;
	NSString *newname;

  while (1) {
	  CHECK_DONE;
	  GET_FILENAME;  

	  newname = [NSString stringWithString: filename];

	  while (1) {
		  newname = [newname stringByAppendingString: @"_copy"];
		  fulldestpath = [destination stringByAppendingPathComponent: newname];

		  if (![fm fileExistsAtPath: fulldestpath]) {
			  break;
      }
	  }

	  [fm copyPath: [destination stringByAppendingPathComponent: filename]
				  toPath: fulldestpath 
			  handler: self];

	  [files removeObject: filename];	   
    WAIT;  
  }                                             
}

- (void)removeExisting:(NSString *)fname
{
	NSString *fulldestpath;
  
	canupdate = NO; 
	fulldestpath = [destination stringByAppendingPathComponent: fname]; 
    
	if ([fm fileExistsAtPath: fulldestpath]) {
		[fm removeFileAtPath: fulldestpath handler: self]; 
	}
	canupdate = YES;
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
    [fileOp updateProgressIndicator];
  }
}

@end
