#ifndef REMOTE_TERMINAL_H
#define REMOTE_TERMINAL_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>

@class RemoteTerminalView;

@interface RemoteTerminal : NSObject
{
  NSString *serverName;
  NSNumber *refNumber;
  BOOL shellDidExit;
  
  IBOutlet id win;
  IBOutlet id scrollView;
  
  RemoteTerminalView *terminalView;
  
  id gwremote;
}

- (id)initForRemoteHost:(NSString *)hostname refNumber:(NSNumber *)ref;

- (void)activate;

- (void)shellOutput:(NSString *)str;

- (void)newCommandLine:(NSString *)line;

- (void)shellDidExit;

- (NSString *)serverName;

- (NSNumber *)refNumber;
   
@end

#endif // REMOTE_TERMINAL_H


