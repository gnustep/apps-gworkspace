/* GWNet.h
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
  IBOutlet id topBox;
  IBOutlet id iconView;
  IBOutlet id titleField;
  IBOutlet id viewersBox;  

  NSMutableArray *searchPaths;
  NSString *userDir;
  NSString *disabledDir;
  
  NSView *noContsView;
  NSView *genericView;
  NSTextField *genericField;

	NSMutableArray *viewers;
  id currentViewer;
  unsigned long viewerTmpRef;
  
  NSConnection *conn;

  id fswatcher;
  BOOL fswnotifications;
  NSString *currentPath;
  
  InspectorPref *preferences;
  StartAppWin *startAppWin;
  
  NSFileManager *fm;
	NSWorkspace *ws;
  NSNotificationCenter *nc; 
}

+ (Inspector *)inspector;

- (void)addViewersFromBundlePaths:(NSArray *)bundlesPaths 
                      userViewers:(BOOL)isuservwr;

- (NSMutableArray *)bundlesWithExtension:(NSString *)extension 
																	inPath:(NSString *)path;

- (void)addViewer:(id)vwr;

- (void)removeViewer:(id)vwr;

- (void)disableViewer:(id)vwr;

- (BOOL)saveExternalViewer:(id)vwr 
                  withName:(NSString *)vwrname;

- (id)viewerWithBundlePath:(NSString *)path;

- (id)viewerWithWindowName:(NSString *)wname;

- (id)viewerForPath:(NSString *)path;

- (id)viewerForDataOfType:(NSString *)type;

- (void)updateDefaults;

- (void)connectFSWatcher;

- (void)fswatcherConnectionDidDie:(NSNotification *)notif;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (void)addExternalViewerWithBundleData:(NSData *)bundleData;

- (void)addExternalViewerWithBundlePath:(NSString *)path;

- (void)showContentsAt:(NSString *)path;

- (void)contentsReadyAt:(NSString *)path;

- (BOOL)canDisplayDataOfType:(NSString *)type;

- (void)showData:(NSData *)data 
          ofType:(NSString *)type;

- (void)dataContentsReadyForType:(NSString *)typeDescr
                         useIcon:(NSImage *)icon;


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


@interface Inspector (PackedBundles)

- (NSData *)dataRepresentationAtPath:(NSString *)path;

- (BOOL)writeDataRepresentation:(NSData *)data 
                         toPath:(NSString *)path;

- (NSString *)tempBundleName;

- (id)viewerFromPackedBundle:(NSData *)packedBundle;

@end

#endif // INSPECTOR_H
