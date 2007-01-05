
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <MDKit/MDKit.h>
#include <MDKit/MDKWindow.h>
#include <MDKit/MDKQuery.h>
#include "MDFinder.h"

static MDFinder *mdfinder = nil;

@implementation MDFinder

+ (MDFinder *)mdfinder;
{
	if (mdfinder == nil) {
		mdfinder = [[MDFinder alloc] init];
	}	
  return mdfinder;
}

- (void)dealloc
{
  RELEASE (mdkwindows);
	[super dealloc];
}

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
  mdkwindows = [NSMutableArray new];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSDictionary *dict = nil;
  MDKWindow *window;
  
//  dict = [NSDictionary dictionaryWithContentsOfFile: @"/root/Desktop/aa.plist"];
  
  window = [[MDKWindow alloc] initWithDelegate: self
                                    windowRect: NSZeroRect
                                     savedInfo: dict];
  [mdkwindows addObject: window];
  RELEASE (window);
  
  [window activate];
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
  BOOL canterminate = YES;
  int i;
  
  for (i= 0; i < [mdkwindows count]; i++) {
    MDKWindow *window = [mdkwindows objectAtIndex: i];
    MDKQuery *query = [window currentQuery];
    
    if ([query isGathering] || [query waitingStart]) {
      [window stopCurrentQuery];
      canterminate = NO;
    }
  }
  
	return canterminate;
}

- (void)mdkwindowWillClose:(MDKWindow *)window
{
  [mdkwindows removeObject: window];
}

- (void)activateContextHelp:(id)sender
{
  if ([NSHelpManager isContextHelpModeActive] == NO) {
    [NSHelpManager setContextHelpModeActive: YES];
  }
}

@end

