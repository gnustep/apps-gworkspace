/* Inspector.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef INSPECTOR_H
#define INSPECTOR_H

#include <Foundation/Foundation.h>

@class StartAppWin;
@class InspectorPref;
@class Attributes;
@class Contents;
@class Tools;

@protocol	FSWClientProtocol

- (void)watchedPathDidChange:(NSData *)dirinfo;

@end

@protocol	FSWatcherProtocol

- (oneway void)registerClient:(id <FSWClientProtocol>)client;

- (oneway void)unregisterClient:(id <FSWClientProtocol>)client;

- (oneway void)client:(id <FSWClientProtocol>)client
                          addWatcherForPath:(NSString *)path;

- (oneway void)client:(id <FSWClientProtocol>)client
                          removeWatcherForPath:(NSString *)path;

@end


@interface Inspector : NSObject <FSWClientProtocol>
{
  IBOutlet id win;
  IBOutlet id popUp;
  IBOutlet id inspBox;

  NSMutableArray *inspectors;
	id currentInspector;
  Contents *contents;

	NSArray *currentPaths;

  id fswatcher;
  BOOL fswnotifications;
  NSString *watchedPath;
  
  InspectorPref *preferences;
  StartAppWin *startAppWin;
  
  NSNotificationCenter *nc; 
}

+ (Inspector *)inspector;

- (IBAction)activateInspector:(id)sender;

- (void)setPaths:(NSArray *)paths;

- (void)showWindow;

- (void)showAttributes;

- (void)showContents;

- (void)showTools;

- (NSWindow *)inspWin;

- (InspectorPref *)preferences;

- (void)updateDefaults;


//
// FSWatcher methods 
//
- (void)connectFSWatcher;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;


//
// Contents Inspector methods 
//
- (BOOL)canDisplayDataOfType:(NSString *)type;

- (void)showData:(NSData *)data 
          ofType:(NSString *)type;

- (id)contentViewerWithWindowName:(NSString *)wname;

- (void)disableContentViewer:(id)vwr;

- (void)addExternalViewerWithBundleData:(NSData *)bundleData;

- (void)addExternalViewerWithBundlePath:(NSString *)path;

- (BOOL)saveExternalContentViewer:(id)vwr 
                         withName:(NSString *)vwrname;


//
// Menu Operations 
//
- (void)closeMainWin:(id)sender;

- (void)showPreferences:(id)sender;

- (void)showInfo:(id)sender;

#ifndef GNUSTEP
- (void)terminate:(id)sender;
#endif

@end

#endif // INSPECTOR_H
