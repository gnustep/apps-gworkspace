#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <GWorkspace/GWFunctions.h>
#include "LoginWindow.h"
#include "GWRemote.h"
#include "GNUstep.h"

static NSString *nibName = @"LoginWindow";

@implementation LoginWindow

- (void)dealloc
{
  TEST_RELEASE (win);
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
    } 
  }
  
  return self;
}

- (void)activate
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];      
  id entry;
  int i;

  [nameField setStringValue: @""];
  [passwordField setStringValue: @""];

  gwremote = [GWRemote gwremote];
       
  serverName = nil;
  serversNames = [NSMutableArray new];
  
  [popUp removeAllItems];
  
  entry = [defaults objectForKey: @"serversnames"];
  if (entry && [entry count]) {
    [serversNames addObjectsFromArray: entry];


    for (i = 0; i < [serversNames count]; i++) {
      [popUp addItemWithTitle: [serversNames objectAtIndex: i]];
    }
    
    
/*
    while ([[popUp itemArray] count] > [serversNames count]) {
      [popUp removeItemAtIndex: ([[popUp itemArray] count] -1)];
    }
    while ([[popUp itemArray] count] < [serversNames count]) {
      [popUp addItemWithTitle: @""];
    }

    for (i = 0; i < [serversNames count]; i++) {
      [[popUp itemAtIndex: i] setTitle: [serversNames objectAtIndex: i]];
    }
*/

    entry = [defaults objectForKey: @"currentserver"];
    if (entry) {
      [popUp selectItemWithTitle: entry];
      [self chooseServer: popUp];
    }
  } else {
    [popUp addItemWithTitle: NSLocalizedString(@"no servers", @"")];
//    [[popUp itemAtIndex: 0] setTitle: NSLocalizedString(@"no servers", @"")];
  }

  [win makeKeyAndOrderFront: nil];
}

- (IBAction)chooseServer:(id)sender
{
  ASSIGN (serverName, [sender titleOfSelectedItem]);
}

- (IBAction)tryLogin:(id)sender
{
  NSString *server = [popUp titleOfSelectedItem];
  NSString *name = [nameField stringValue];
  NSString *pass = [passwordField stringValue];

  if ([name length] && [pass length]) {
    [gwremote tryLoginOnServer: server withUserName: name userPassword: pass];
  } else {
    NSRunAlertPanel(NULL, NSLocalizedString(@"You must enter an user name and a password!", @""),
                                  NSLocalizedString(@"OK", @""), NULL, NULL);   
  }
  
  [nameField setStringValue: @""];
  [passwordField setStringValue: @""];
}

- (id)myWin
{
  return win;
}

@end
