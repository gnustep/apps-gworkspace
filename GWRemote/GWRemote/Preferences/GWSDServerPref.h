#ifndef GWSD_SERVER_PREF_H
#define GWSD_SERVER_PREF_H

#include <Foundation/NSObject.h>
#include "PreferencesProtocol.h"

@interface GWSDServerPref : NSObject <PreferencesProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;
  IBOutlet id serverbox;    
  IBOutlet id popUp;
  IBOutlet id addButt;
  IBOutlet id removeButt;
  IBOutlet id nameField;  

  NSMutableArray *serversNames;
  NSString *serverName;
  id gwremote;  
}

- (IBAction)chooseServer:(id)sender;

- (IBAction)addServer:(id)sender;

- (IBAction)removeServer:(id)sender;

- (void)updateDefaults;

- (void)makePopUp;

@end

#endif // GWSD_SERVER_PREF_H
