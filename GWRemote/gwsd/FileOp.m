#include <AppKit/AppKit.h>
#include "FileOp.h"
#include "gwsd.h"
#include "externs.h"
#include "Functions.h"
#include "GNUstep.h"

#ifndef LONG_DELAY
  #define LONG_DELAY 86400.0
#endif

@implementation GWSd (FileOperations)

- (int)fileOperationRef
{
  oprefnum++;  
  if (oprefnum == 1000) oprefnum = 0;  
  return oprefnum;
}

- (LocalFileOp *)fileOpWithRef:(int)ref
{
  int i;
  
  for (i = 0; i < [operations count]; i++) {
    LocalFileOp *op = [operations objectAtIndex: i];
  
    if ([op fileOperationRef] == ref) {
      return op;
    }
  }

  return nil;
}

- (void)endOfFileOperation:(LocalFileOp *)op
{
  [operations removeObject: op];
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  [gwsdClient server: self fileSystemDidChange: [[notif object] propertyList]]; 
}

@end


@implementation LocalFileOp

- (void)dealloc
{
  RELEASE (operationDict);
  RELEASE (operation);
  TEST_RELEASE (source);
  TEST_RELEASE (destination);
  TEST_RELEASE (files);
  TEST_RELEASE (addedFiles);
  TEST_RELEASE (removedFiles);
  
  [super dealloc];
}

- (id)initWithOperationDescription:(NSDictionary *)opDict
                           forGWSd:(GWSd *)gw
                        withClient:(id)client
{
	self = [super init];
  
  if (self) {
    id entry;
    int i;
    
    gwsd = gw;
    
    gwsdClient = (id <GWSdClientProtocol>)client;
    fileOperationRef = [gwsd fileOperationRef];
       
		operation = RETAIN ([opDict objectForKey: @"operation"]);
    operationDict = [NSMutableDictionary new];
    [operationDict setObject: operation forKey: @"operation"]; 

    entry = [opDict objectForKey: @"source"];
		if (entry) {
			source = [[NSString alloc] initWithString: entry];
      [operationDict setObject: source forKey: @"source"]; 
		}

    entry = [opDict objectForKey: @"destination"];
		if (entry) {
			destination = [[NSString alloc] initWithString: entry];
      [operationDict setObject: destination forKey: @"destination"]; 
		}
    
    entry = [opDict objectForKey: @"files"];
		if (entry) {
			files = [[NSMutableArray alloc] initWithCapacity: 1];	
			for(i = 0; i < [entry count]; i++) {
				[files addObject: [entry objectAtIndex: i]];
      }
      [operationDict setObject: files forKey: @"files"]; 
		}
    
    if([self prepareFileOperationAlert] == NO) {                	        
      [self endOperation];
      return self; 
      
    } else {
      fm = [NSFileManager defaultManager];
		  samename = NO;

      [self checkSameName];

      if (samename) {
	      NSString *msg, *title;
        unsigned result;
        
		    if ([operation isEqual: @"NSWorkspaceMoveOperation"]) {	
			    msg = @"Some items have the same name;\ndo you want to replace them?";
			    title = @"Move";

		    } else if ([operation isEqual: @"NSWorkspaceCopyOperation"]) {
			    msg = @"Some items have the same name;\ndo you want to replace them?";
			    title = @"Copy";

		    } else if([operation isEqual: @"NSWorkspaceLinkOperation"]) {
			    msg = @"Some items have the same name;\ndo you want to replace them?";
			    title = @"Link";

		    } else if([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
			    msg = @"Some items have the same name;\ndo you want to replace them?";
			    title = @"Recycle";

		    } else if([operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
			    msg = @"Some items have the same name;\ndo you want to replace them?";
			    title = @"Recycle";
		    }

        result = [gwsdClient requestUserConfirmationWithMessage: msg
                                                          title: title];
		    if (result != NSAlertDefaultReturn) {      
          [self endOperation];
          return self; 
		    }
      } 
      
      addedFiles = [NSMutableArray new];
      removedFiles = [NSMutableArray new];
      
      [self calculateNumFiles];  
      [self showProgressWinOnClient];
      [self performOperation]; 
    }
	}			

	return self;
}

- (void)checkSameName
{
	samename = NO;

	if (([operation isEqual: NSWorkspaceMoveOperation]) 
        || ([operation isEqual: NSWorkspaceCopyOperation])
        || ([operation isEqual: NSWorkspaceLinkOperation])
        || ([operation isEqual: NSWorkspaceRecycleOperation])
        || ([operation isEqual: GWorkspaceRecycleOutOperation])) {
	
	  if (destination && [files count]) {
		  NSArray *dirContents = [fm directoryContentsAtPath: destination];
      int i;
      
		  for (i = 0; i < [files count]; i++) {
        if ([dirContents containsObject: [files objectAtIndex: i]]) {
          samename = YES;
          break;
        }
		  }
	  }
	}
}

- (void)calculateNumFiles
{
	BOOL isDir;
  NSDirectoryEnumerator *enumerator;
  NSString *dirEntry;
  int i;
  
  filescount = 0;
  
  for(i = 0; i < [files count]; i++) {
    NSString *path = [source stringByAppendingPathComponent: [files objectAtIndex: i]];       

	  isDir = NO;
	  [fm fileExistsAtPath: path isDirectory: &isDir];
	  if (isDir) {
      enumerator = [fm enumeratorAtPath: path];
      while ((dirEntry = [enumerator nextObject])) {
			  filescount++;
      }
	  } else {
		  filescount++;
	  }
  }
}

- (void)performOperation
{
  stopped = NO;
  paused = NO;
          
	if ([operation isEqual: NSWorkspaceMoveOperation]
				|| [operation isEqual: NSWorkspaceRecycleOperation]
						|| [operation isEqual: GWorkspaceRecycleOutOperation]) {
    [gwsd suspendWatchingForPath: source];        
    [gwsd suspendWatchingForPath: destination];         
		[self doMove];
	} else if ([operation isEqual: NSWorkspaceCopyOperation]) {
    [gwsd suspendWatchingForPath: destination];  
		[self doCopy];
	} else if([operation isEqual: NSWorkspaceLinkOperation]) {
    [gwsd suspendWatchingForPath: destination];
		[self doLink];
	} else if([operation isEqual: NSWorkspaceDestroyOperation]
					|| [operation isEqual: GWorkspaceEmptyRecyclerOperation]) {
    [gwsd suspendWatchingForPath: destination];      
		[self doRemove];
	} else if([operation isEqual: NSWorkspaceDuplicateOperation]) {
    [gwsd suspendWatchingForPath: destination];
		[self doDuplicate];
	}
}

#define CHECK_DONE \
if (![files count] || stopped) [self endOperation]; \
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

	  [addedFiles addObject: filename];     
	  [removedFiles addObject: filename];     
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

	  [addedFiles addObject: filename];     
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

	  [addedFiles addObject: filename];     
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

	  [removedFiles addObject: filename];     
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
        [addedFiles addObject: newname];     
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
  
	fulldestpath = [destination stringByAppendingPathComponent: fname]; 
    
	if ([fm fileExistsAtPath: fulldestpath]) {
		[fm removeFileAtPath: fulldestpath handler: self]; 
	}
}

- (BOOL)prepareFileOperationAlert
{
	NSString *title;
	NSString *msg, *msg1, *msg2;
	int result;
	  	
	if ([operation isEqual: @"NSWorkspaceMoveOperation"]) {
		title = @"Move";
		msg1 = @"Move from: ";
		msg2 = @"\nto: ";
		msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	} else if ([operation isEqual: @"NSWorkspaceCopyOperation"]) {
		title = @"Copy";
		msg1 = @"Copy from: ";
		msg2 = @"\nto: ";
		msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	} else if ([operation isEqual: @"NSWorkspaceLinkOperation"]) {
		title = @"Link";
		msg1 = @"Link ";
		msg2 = @"\nto: ";
		msg = [NSString stringWithFormat: @"%@%@%@%@?", msg1, source, msg2, destination];
	} else if ([operation isEqual: @"NSWorkspaceRecycleOperation"]) {
		title = @"Recycler";
		msg1 = @"Move from: ";
		msg2 = @"\nto the Recycler";
		msg = [NSString stringWithFormat: @"%@%@%@?", msg1, source, msg2];
	} else if ([operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
		title = @"Recycler";
		msg1 = @"Move from the Recycler ";
		msg2 = @"\nto: ";
		msg = [NSString stringWithFormat: @"%@%@%@?", msg1, msg2, destination];
	} else if ([operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
		title = @"Recycler";
		msg = @"Empty the Recycler?";
	} else if ([operation isEqual: @"NSWorkspaceDestroyOperation"]) {
		title = @"Delete";
		msg = @"Delete the selected objects?";
	} else if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) {
		title = @"Duplicate";
		msg = @"Duplicate the selected objects?";
	}
	  
  result = [gwsdClient requestUserConfirmationWithMessage: msg title: title];  
  
	if (result != NSAlertDefaultReturn) {
		return NO;
  }
	
	return YES;	
}

- (BOOL)pauseOperation
{
  if (paused == NO) { 
    paused = YES;
    return YES;
  }

  return NO;
}

- (BOOL)continueOperation
{
  if (paused) { 
    [self performOperation];
    return YES;
  }
 
  return NO;  
}

- (BOOL)stopOperation
{
  stopped = YES;
  return YES;
}

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title
{
  return [gwsdClient requestUserConfirmationWithMessage: message title: title];
}

- (void)showProgressWinOnClient
{  
  NSString *optitle;

  if ([operation isEqual: @"NSWorkspaceMoveOperation"]) {
    optitle = @"Move";
  } else if ([operation isEqual: @"NSWorkspaceCopyOperation"]) {
    optitle = @"Copy";
  } else if ([operation isEqual: @"NSWorkspaceLinkOperation"]) {
    optitle = @"Link";
  } else if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) {
    optitle = @"Duplicate";
  } else if ([operation isEqual: @"NSWorkspaceDestroyOperation"]) {
    optitle = @"Destroy";
  } else if (([operation isEqual: @"NSWorkspaceRecycleOperation"]) 
                  || ([operation isEqual: @"GWorkspaceRecycleOutOperation"])
                          || ([operation isEqual: @"GWorkspaceEmptyRecyclerOperation"])) {
    optitle = @"Recycler";
  }
     
  [gwsdClient showProgressForFileOperationWithName: optitle
                                        sourcePath: source
                                   destinationPath: destination
                                      operationRef: fileOperationRef
                                          onServer: gwsd];
}

- (int)showErrorAlertWithMessage:(NSString *)message
{
  return [gwsdClient showErrorAlertWithMessage: message];
}

- (void)endOperation
{
#define NOTIFY \
[[NSDistributedNotificationCenter defaultCenter] \
postNotificationName: GWFileSystemDidChangeNotification \
object: [dict description]]

  NSMutableDictionary *dict = [NSMutableDictionary dictionary];

  [gwsdClient endOfFileOperationWithRef: fileOperationRef
                               onServer: gwsd];

	if ([operation isEqual: NSWorkspaceMoveOperation]
				|| [operation isEqual: NSWorkspaceRecycleOperation]
        || [operation isEqual: GWorkspaceRecycleOutOperation]) {
    
    if ([removedFiles count]) {
      [dict setObject: source forKey: @"path"];            
      [dict setObject: GWFileDeletedInWatchedDirectory forKey: @"event"];        
      [dict setObject: removedFiles forKey: @"files"];        
    
      NOTIFY; 

      [[NSRunLoop currentRunLoop] 
          runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
    }
    
    if ([addedFiles count]) {
      [dict setObject: destination forKey: @"path"];            
      [dict setObject: GWFileCreatedInWatchedDirectory forKey: @"event"];        
      [dict setObject: addedFiles forKey: @"files"];        
    
      NOTIFY;
    }
    
    [gwsd restartWatchingForPath: source];
    [gwsd restartWatchingForPath: destination]; 
    
	} else if ([operation isEqual: NSWorkspaceCopyOperation]
              || [operation isEqual: NSWorkspaceLinkOperation]
              || [operation isEqual: NSWorkspaceDuplicateOperation]) { 
   
    if ([addedFiles count]) {
      [dict setObject: destination forKey: @"path"];            
      [dict setObject: GWFileCreatedInWatchedDirectory forKey: @"event"];        
      [dict setObject: addedFiles forKey: @"files"];        
    
      NOTIFY; 
    }
    
    [gwsd restartWatchingForPath: destination];
     
	} else if([operation isEqual: NSWorkspaceDestroyOperation]
					|| [operation isEqual: GWorkspaceEmptyRecyclerOperation]) {
    
    if ([removedFiles count]) {      
      [dict setObject: destination forKey: @"path"];            
      [dict setObject: GWFileDeletedInWatchedDirectory forKey: @"event"];        
      [dict setObject: removedFiles forKey: @"files"];        
    
      NOTIFY;
    }
    
    [gwsd restartWatchingForPath: destination];
	}

  [[NSRunLoop currentRunLoop] 
        runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];

  [gwsd endOfFileOperation: self];
}

- (int)fileOperationRef
{
  return fileOperationRef;
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

  result = [self requestUserConfirmationWithMessage: msg title: @"Error"];
    
	if(result != NSAlertDefaultReturn) {
    [self endOperation];
    
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
      result = [self showErrorAlertWithMessage: @"File Operation Error!"];
      [self endOperation];
      return NO;
    }
  }
  
	return !iserror;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

@end


