
#ifndef REMOTE_TERMINAL_VIEW
#define REMOTE_TERMINAL_VIEW

#include <Foundation/Foundation.h>
#include <AppKit/NSTextView.h>

@class NSString;
@class RemoteTerminal;

@interface RemoteTerminalView: NSTextView
{
  RemoteTerminal *terminal;
  NSString *prompt;
  NSDictionary *fontDict;
  long cursor;
}

- (id)initWithFrame:(NSRect)frame 
         inTerminal:(RemoteTerminal *)aTerminal
         remoteHost:(NSString *)hostname;

- (void)insertShellOutput:(NSString *)str;

@end

#endif // REMOTE_TERMINAL_VIEW

