
#ifndef MDFINDER_H
#define MDFINDER_H

#include <Foundation/Foundation.h>

@class MDKWindow;

@interface MDFinder: NSObject 
{
  NSMutableArray *mdkwindows;
}

+ (MDFinder *)mdfinder;

- (void)activateContextHelp:(id)sender;

- (void)mdkwindowWillClose:(MDKWindow *)window;

@end

#endif // MDFINDER_H
