#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <GWorkspace/GWFunctions.h>
#include "GWSDServerPref.h"
#include "GWRemote.h"
#include "GNUstep.h"

static NSString *nibName = @"GWSDServerPref";

static NSString *prefName = nil;

@implementation GWSDServerPref

+ (void)initialize
{
  ASSIGN (prefName, NSLocalizedString(@"gwsd server", @""));
}

+ (NSString *)prefName
{
  return prefName;
}

- (void)dealloc
{
  TEST_RELEASE (prefbox);
  TEST_RELEASE (serversNames);
  TEST_RELEASE (serverName);
  
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {  
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
    } else {
	    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      
      id entry;
      
      RETAIN (prefbox);
      RELEASE (win);
      
      [nameField setStringValue: @""];
            
      gwremote = [GWRemote gwremote];
      
      serverName = nil;
      serversNames = [NSMutableArray new];

      entry = [defaults objectForKey: @"serversnames"];
      if (entry && [entry count]) {
        [serversNames addObjectsFromArray: entry];
      }
      
      [self makePopUp];
    }
  }
  
  return self;
}

- (NSView *)prefView
{
  return prefbox;
}

- (NSString *)prefName
{
  return prefName;
}

- (IBAction)chooseServer:(id)sender
{
  ASSIGN (serverName, [sender titleOfSelectedItem]);
  [nameField setStringValue: serverName];
}

- (IBAction)addServer:(id)sender
{
  NSString *sname = [nameField stringValue];
  NSArray *items = [popUp itemArray];
  BOOL duplicate = NO;
  int i;
  
  for (i = 0; i < [items count]; i++) {
    if ([[[items objectAtIndex: i] title] isEqual: sname]) {
      duplicate = YES;
      break;
    }
  }
  
  if (duplicate == NO) {
    [serversNames addObject: sname];
    [self makePopUp];
    [self updateDefaults];
  }
}

- (IBAction)removeServer:(id)sender
{
  if ([[popUp itemArray] count] == 1) {
    NSRunAlertPanel(NULL, NSLocalizedString(@"You can't remove the last server!", @""), 
                                  NSLocalizedString(@"OK", @""), NULL, NULL);   
  } else {
    NSString *title = [popUp titleOfSelectedItem];
    
    [serversNames removeObject: title];
    DESTROY (serverName);
    [self makePopUp];
    [self updateDefaults];
  }
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
  
  if ([serversNames count]) {
    [defaults setObject: serversNames forKey: @"serversnames"];
	  [defaults synchronize];
    [gwremote serversListChanged];
  }
}

- (void)makePopUp
{
  [popUp removeAllItems];

  if (serversNames && [serversNames count]) {
    int i;

    for (i = 0; i < [serversNames count]; i++) {
      [popUp addItemWithTitle: [serversNames objectAtIndex: i]];
    }

    [popUp selectItemAtIndex: ([[popUp itemArray] count] -1)];
    [self chooseServer: popUp];
  
  } else {
    [popUp addItemWithTitle: NSLocalizedString(@"no servers", @"")];
  }
}

@end
