#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "GNUstep.h"
#include "GWRemote.h"
#include "RemoteTerminal.h"
#include "RemoteTerminalView.h"
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWFunctions.h>

static NSString *nibName = @"RemoteTerminal";

@implementation RemoteTerminal

- (void)dealloc
{
  TEST_RELEASE (win);
  TEST_RELEASE (terminalView);
  TEST_RELEASE (serverName);
  TEST_RELEASE (refNumber);
  
  [super dealloc];
}

- (id)initForRemoteHost:(NSString *)hostname refNumber:(NSNumber *)ref
{
  self = [super init];
  
  if (self) {  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
      NSRect rect;
      
      if ([win setFrameUsingName: @"remoteTerminal"] == NO) {
        [win setFrame: NSMakeRect(300, 200, 438, 300) display: NO];
      }

      [win setDelegate: self];  
      [scrollView setBorderType: NSBezelBorder];
      [scrollView setHasVerticalScroller: YES];      
      [scrollView setHasHorizontalScroller: YES];  
  
      rect = [[scrollView contentView] frame];
      terminalView = [[RemoteTerminalView alloc] initWithFrame: rect 
                                                    inTerminal: self
                                                    remoteHost: hostname];
      [scrollView setDocumentView: terminalView];
      
      gwremote = [GWRemote gwremote];
      
      ASSIGN (serverName, hostname);
      refNumber = RETAIN (ref);
      shellDidExit = NO;
      
      [win setTitle: [NSString stringWithFormat: @"%@ - term", serverName]];
      [win makeKeyAndOrderFront: nil];
    }    
  }
  
  return self;    
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
}

- (void)shellOutput:(NSString *)str
{
  [terminalView insertShellOutput: str];
}

- (void)newCommandLine:(NSString *)line
{
  [gwremote terminalWithRef: refNumber newCommandLine: line];
}

- (void)shellDidExit
{
  shellDidExit = YES;
  [win close];
}

- (NSString *)serverName
{
  return serverName;
}

- (NSNumber *)refNumber
{
  return refNumber;
}

- (BOOL)windowShouldClose:(id)sender
{
  [win saveFrameUsingName: @"remoteTerminal"];
  
  if (shellDidExit == NO) {
    [gwremote remoteTerminalHasClosed: self]; 
  }
  
  return YES;
}

@end
