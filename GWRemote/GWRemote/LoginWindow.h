#ifndef LOGIN_WINDOW_H
#define LOGIN_WINDOW_H

#include <Foundation/NSObject.h>

@interface LoginWindow : NSObject 
{
  IBOutlet id win;
  IBOutlet id popUp;
  IBOutlet id nameField;  
  IBOutlet id passwordField;    
  IBOutlet id loginButt;

  NSMutableArray *serversNames;
  NSString *serverName;
  id gwremote;  
}

- (void)activate;

- (IBAction)chooseServer:(id)sender;

- (IBAction)tryLogin:(id)sender;

- (id)myWin;

@end

#endif // LOGIN_WINDOW_H
