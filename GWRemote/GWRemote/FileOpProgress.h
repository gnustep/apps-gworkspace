#ifndef FILE_OPERATION_H
#define FILE_OPERATION_H

#include <Foundation/NSObject.h>
#include <AppKit/NSView.h>

@class NSTimer;
@class GWRemote;
@class NSImage;
@class ProgressView;

@interface FileOpProgress : NSObject 
{
  IBOutlet id win;
  IBOutlet id fromField;
  IBOutlet id toField;    
  IBOutlet id progressBox;
  ProgressView *pView;
  IBOutlet id pauseButt;
  IBOutlet id stopButt;

  NSString *serverName;
  NSString *title;
  int operationRef;
  BOOL paused;
  
  GWRemote *gwremote;
}

- (id)initWithOperationRef:(int)ref
             operationName:(NSString *)opname
                sourcePath:(NSString *)source
           destinationPath:(NSString *)destination
                serverName:(NSString *)sname
                windowRect:(NSRect)wrect;

- (void)activate;

- (void)done;

- (NSString *)serverName;

- (NSString *)title;

- (int)operationRef;

- (NSRect)windowRect;

- (IBAction)pauseOperation:(id)sender;

- (IBAction)stopOperation:(id)sender;

@end

@interface ProgressView : NSView 
{
  NSImage *image;
  float orx;
  NSTimer *progTimer;
}

- (void)start;

- (void)stop;

- (void)animate:(id)sender;

@end

#endif // FILE_OPERATION_H
