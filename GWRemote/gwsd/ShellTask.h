
#ifndef SHELL_TASK_H
#define SHELL_TASK_H

#include <Foundation/NSObject.h>

@class NSString;
@class NSTask;
@class NSFileHandle;
@class NSNumber;
@class NSNotificationCenter;
@class NSNotification;
@class GWSd;

@interface ShellTask : NSObject
{
  NSString *shellPath;
  NSTask *task;  
  NSNotificationCenter *nc;
  GWSd *gwsd;
  id gwsdClient;  
  NSNumber *ref;
}

- (id)initWithShellCommand:(NSString *)cmd
                    onPath:(NSString *)apath
                   forGWSd:(GWSd *)gw
                withClient:(id)client
                 refNumber:(NSNumber *)refn;

- (void)stopTask;

- (void)newCommandLine:(NSString *)line;

- (void)taskOut:(NSNotification *)notif;

- (void)taskErr:(NSNotification *)notif;

- (void)endOfTask:(NSNotification *)notif;

- (NSNumber *)refNumber;

@end

#endif // SHELL_TASK_H

