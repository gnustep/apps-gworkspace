
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "MDFinder.h"

void createMenu();
NSMenuItem *addItemToMenu(NSMenu *menu, NSString *str, 
														NSString *comm, NSString *sel, NSString *key);
  
int main(int argc, char **argv, char **env)
{
	CREATE_AUTORELEASE_POOL (pool);
	NSApplication *app = [NSApplication sharedApplication];
  
	createMenu();
	
  [app setDelegate: [MDFinder mdfinder]];    
	[app run];
	RELEASE (pool);
  
  return 0;
}

void createMenu()
{
  NSMenu *mainMenu;

	// Main
  mainMenu = AUTORELEASE ([[NSMenu alloc] initWithTitle: @"OpenGLTest"]);
    	
	addItemToMenu(mainMenu, @"Show", @"", @"showwin:", @"a");
	addItemToMenu(mainMenu, @"Activate context help", @"", @"activateContextHelp:", @";");
	addItemToMenu(mainMenu, @"Quit", @"", @"terminate:", @"q");

	[mainMenu update];

	[[NSApplication sharedApplication] setMainMenu: mainMenu];		
}

NSMenuItem *addItemToMenu(NSMenu *menu, NSString *str, 
																NSString *comm, NSString *sel, NSString *key)
{
	NSMenuItem *item = [menu addItemWithTitle: NSLocalizedString(str, comm)
												action: NSSelectorFromString(sel) keyEquivalent: key]; 
	return item;
}
