#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "GNUstep.h"
#include "GWRemote.h"
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWFunctions.h>
#include "RemoteTerminalView.h"
#include "RemoteTerminal.h"

@implementation RemoteTerminalView

- (void) dealloc
{
  RELEASE (fontDict);
  RELEASE (prompt);  
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frame 
         inTerminal:(RemoteTerminal *)aTerminal
         remoteHost:(NSString *)hostname
{
  self = [super initWithFrame: frame];
  
  if (self) {
    NSFont *font;
    NSSize size;
    
    [self setRichText: NO];
    [self setImportsGraphics: NO];
    [self setUsesFontPanel: NO];
    [self setUsesRuler: NO];
    [self setEditable: YES];
    [self setAllowsUndo: YES];
    [self setMinSize: NSMakeSize(0,0)];
    [self setMaxSize: NSMakeSize(1e7, 1e7)];
    [self setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
    [self setVerticallyResizable: YES];
    [self setHorizontallyResizable: NO];
  
    size = NSMakeSize([self frame].size.width, 1e7);
    [[self textContainer] setContainerSize: size];
    [[self textContainer] setWidthTracksTextView: YES];
    
    font = [NSFont userFixedPitchFontOfSize: 12];
    fontDict = [[NSDictionary alloc] initWithObjects: 
                          [NSArray arrayWithObject: font] 
                     forKeys: [NSArray arrayWithObject: NSFontAttributeName]];
    
    terminal = aTerminal;
    ASSIGN (prompt, ([NSString stringWithFormat: @"%@ > ", hostname]));   
    [self insertText: prompt];
    cursor = [prompt length];
  }
    
  return self;
}

- (void)insertShellOutput:(NSString *)str
{
  cursor = [[self string] length] + [str length] + [prompt length];

  [self insertText: str];
  [self insertText: prompt];
}

- (void)insertText:(id)aString
{
  [super insertText: aString];
  [[self textStorage] setAttributes: fontDict
                              range: NSMakeRange(0, [[self string] length])];
  [self setSelectedRange: NSMakeRange([[self string] length], 0)];
}

- (void)keyDown:(NSEvent *)theEvent
{
  NSString *str = [theEvent characters];
  
  [super keyDown: theEvent];
  
  if([str isEqualToString: @"\r"]) {  
    int linelength = [[self string] length] - cursor;
    NSRange range = NSMakeRange(cursor, linelength);
    NSString *str = [[self string] substringWithRange: range];
    
    [terminal newCommandLine: str];
    [self insertText: prompt];
    cursor += ([str length] + [prompt length]);
  }
}

@end
