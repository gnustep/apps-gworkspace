#ifndef FILEOPERATION_H
#define FILEOPERATION_H

#include <Foundation/NSObject.h>

@class NSString;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSFileManager;
@class NSTimer;
@class NSLock;
@class GWorkspace;
@class FileOpExecutor;

@protocol FileOpProtocol

- (void)registerExecutor:(id)anObject;
                            
- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (int)showErrorAlertWithMessage:(NSString *)message;

- (void)updateProgressIndicator;

- (int)sendDidChangeNotification;

- (void)endOperation;

@end

@protocol FileOpExecutorProtocol

+ (void)setPorts:(NSArray *)thePorts;

- (void)setFileop:(NSArray *)thePorts;

- (BOOL)setOperation:(NSDictionary *)opDict;

- (BOOL)checkSameName;

- (int)calculateNumFiles;

- (oneway void)performOperation;

- (void)Pause;

- (void)Stop;

- (BOOL)isPaused;

- (void)done;

@end

@interface FileOperation: NSObject <FileOpProtocol>
{
	NSString *operation;
	NSString *source;
	NSString *destination;
	NSMutableArray *files;
  NSMutableDictionary *operationDict;
  NSMutableArray *notifNames;
  int fileOperationRef;
  int filescount;
  BOOL confirm;
  BOOL showwin;
  BOOL opdone;
  NSConnection *execconn;
  id <FileOpExecutorProtocol> executor;
  NSTimer *timer;
  NSNotificationCenter *dnc;
  NSFileManager *fm;
  GWorkspace *gw;

  IBOutlet id win;
  IBOutlet id fromLabel;
  IBOutlet id fromField;
  IBOutlet id toLabel;
  IBOutlet id toField;
  IBOutlet id progInd;
  IBOutlet id pauseButt;
  IBOutlet id stopButt;  
}

- (id)initWithOperation:(NSString *)opr
                 source:(NSString *)src
		 	      destination:(NSString *)dest
                  files:(NSArray *)fls
        useConfirmation:(BOOL)conf
             showWindow:(BOOL)showw
             windowRect:(NSRect)wrect;

- (void)checkExecutor:(id)sender;

- (BOOL)showFileOperationAlert;

- (void)showProgressWin;

- (void)sendWillChangeNotification;

- (IBAction)pause:(id)sender;

- (IBAction)stop:(id)sender;

- (int)fileOperationRef;

- (NSRect)winRect;

- (BOOL)showsWindow;
                 
@end


@interface FileOpExecutor: NSObject <FileOpExecutorProtocol>
{
	NSString *operation;
	NSString *source;
	NSString *destination;
	NSMutableArray *files;
	NSString *filename;
	int fcount;
	BOOL stopped;
	BOOL paused;
	BOOL canupdate;
  BOOL samename;
  NSFileManager *fm;
  NSConnection *fopConn;
  id <FileOpProtocol> fileOp;
}

- (void)doMove;

- (void)doCopy;

- (void)doLink;

- (void)doRemove;

- (void)doDuplicate;

- (void)removeExisting:(NSString *)fname;

@end 

#endif // FILEOPERATION_H
