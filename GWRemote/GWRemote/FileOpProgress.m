#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <GWorkspace/GWFunctions.h>
#include "FileOpProgress.h"
#include "GWRemote.h"
#include "GNUstep.h"

static NSString *nibName = @"FileOperationWin";

@implementation FileOpProgress

- (void)dealloc
{
  TEST_RELEASE (win);
  TEST_RELEASE (serverName);
  TEST_RELEASE (title);

  [super dealloc];
}

- (id)initWithOperationRef:(int)ref
             operationName:(NSString *)opname
                sourcePath:(NSString *)source
           destinationPath:(NSString *)destination
                serverName:(NSString *)sname
                windowRect:(NSRect)wrect
{
  self = [super init];
  
  if (self) {  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
      gwremote = [GWRemote gwremote];
      ASSIGN (title, opname);
      ASSIGN (serverName, sname);
      operationRef = ref;
      paused = NO;

      [fromField setStringValue: relativePathFittingInContainer(fromField, source)];
      [toField setStringValue: relativePathFittingInContainer(fromField, destination)];

      if (NSEqualRects(wrect, NSZeroRect) == NO) {
        [win setFrame: wrect display: NO];
      } else {
        if ([win setFrameUsingName: @"fileopprogress"] == NO) {
          [win setFrame: NSMakeRect(300, 300, 282, 102) display: NO];
        }
      }    
      [win setTitle: [NSString stringWithFormat: @"%@ - %@", serverName, opname]];  
      [win setDelegate: self];  
      
      pView = [[ProgressView alloc] initWithFrame: NSMakeRect(0, 0, 144, 16)];
      [(NSBox *)progressBox setContentView: pView];
      RELEASE (pView);
    }
  }
  
  return self;
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
  [pView start];
}

- (void)done
{
  [pView stop];
  [win saveFrameUsingName: @"fileopprogress"];
  [win close];
}

- (NSString *)serverName
{
  return serverName;
}

- (NSString *)title
{
  return title;
}

- (int)operationRef
{
  return operationRef;
}

- (NSRect)windowRect
{
  return [win frame];
}

- (IBAction)pauseOperation:(id)sender
{
  if (paused == NO) {
    if ([gwremote pauseFileOperationWithRef: operationRef
                           onServerWithName: serverName]) {
      paused = YES;
      [pauseButt setTitle: NSLocalizedString(@"Continue", @"")];
      [stopButt setEnabled: NO];	
    }
  } else {
    if ([gwremote continueFileOperationWithRef: operationRef
                              onServerWithName: serverName]) {
      paused = YES;
      [pauseButt setTitle: NSLocalizedString(@"Pause", @"")];
      [stopButt setEnabled: YES];	
    }
  }
}

- (IBAction)stopOperation:(id)sender
{
  if ([gwremote stopFileOperationWithRef: operationRef
                        onServerWithName: serverName]) {
    [pauseButt setEnabled: NO];	
    [stopButt setEnabled: NO];	
  }
}

- (BOOL)windowShouldClose:(id)sender
{
  [win saveFrameUsingName: @"fileopprogress"];
	return YES;
}

@end

@implementation ProgressView

#define PROG_IND_STEP 1
#define PROG_IND_MAX (-64)

- (void)dealloc
{
  if (progTimer && [progTimer isValid]) {
    [progTimer invalidate];
  }
  RELEASE (image);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect
{
  self = [super initWithFrame: frameRect];

  if (self) {
    ASSIGN (image, [NSImage imageNamed: @"progindindet.tiff"]);
    orx = PROG_IND_MAX;
  }

  return self;
}

- (void)start
{
  progTimer = [NSTimer scheduledTimerWithTimeInterval: 0.05 
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
  if (orx >= 0) {
    orx = PROG_IND_MAX;
  }

  orx += PROG_IND_STEP;
  [self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  [image compositeToPoint: NSMakePoint(orx, 0) 
                operation: NSCompositeSourceOver];
}

@end
