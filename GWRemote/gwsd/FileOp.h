#ifndef FILEOPERATION_H
#define FILEOPERATION_H

#include <Foundation/NSObject.h>

@class NSString;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSFileManager;
@class GWSd;

@interface LocalFileOp: NSObject
{
	NSString *operation;
	NSString *source;
	NSString *destination;
	NSMutableArray *files;
	NSMutableArray *addedFiles;
	NSMutableArray *removedFiles;
  NSMutableDictionary *operationDict;
  int fileOperationRef;
  int filescount;
  NSString *filename;
	BOOL stopped;
	BOOL paused;
  BOOL samename; 
  NSFileManager *fm;
  GWSd *gwsd;
  id gwsdClient;
}

- (id)initWithOperationDescription:(NSDictionary *)opDict
                           forGWSd:(GWSd *)gw
                        withClient:(id)client;

- (void)checkSameName;

- (void)calculateNumFiles;

- (void)performOperation;

- (void)doMove;

- (void)doCopy;

- (void)doLink;

- (void)doRemove;

- (void)doDuplicate;

- (void)removeExisting:(NSString *)fname;
                            
- (BOOL)prepareFileOperationAlert;

- (void)showProgressWinOnClient;

- (BOOL)pauseOperation;

- (BOOL)continueOperation;

- (BOOL)stopOperation;

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (int)showErrorAlertWithMessage:(NSString *)message;

- (void)endOperation;

- (int)fileOperationRef;
                 
@end

#endif // FILEOPERATION_H
