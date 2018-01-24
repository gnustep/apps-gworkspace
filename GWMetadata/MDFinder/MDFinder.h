/* MDFinder.h
 *  
 * Copyright (C) 2007-2018 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@fibernet.ro>
 * Date: January 2007
 *
 * This file is part of the GNUstep GWorkspace application
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef MDFINDER_H
#define MDFINDER_H

#import <Foundation/Foundation.h>

@class MDKWindow;
@class StartAppWin;

@protocol	WorkspaceAppProtocol

- (oneway void)showExternalSelection:(NSArray *)selection;

@end


@interface MDFinder: NSObject 
{
  NSMutableArray *mdkwindows;
  MDKWindow *activeWindow;
  
  NSString *lastSaveDir;
  
  NSFileManager *fm;
  NSNotificationCenter *nc;
  
  id workspaceApp;
  
  StartAppWin *startAppWin;  
}

+ (MDFinder *)mdfinder;

- (MDKWindow *)windowWithSavedPath:(NSString *)path;

- (NSRect)frameForNewWindow;

- (void)connectWorkspaceApp;

- (void)workspaceAppConnectionDidDie:(NSNotification *)notif;


//
// Menu
//
- (void)newQuery:(id)sender;

- (void)openQuery:(id)sender;

- (void)saveQuery:(id)sender;

- (void)saveQueryAs:(id)sender;

- (void)closeMainWin:(id)sender;

- (void)activateContextHelp:(id)sender;


//
// MDKWindow delegate
//
- (void)setActiveWindow:(MDKWindow *)window;

- (void)window:(MDKWindow *)window 
          didChangeSelection:(NSArray *)selection;

- (void)mdkwindowWillClose:(MDKWindow *)window;

@end


@interface StartAppWin: NSObject
{
  IBOutlet id win;
  IBOutlet id startLabel;
  IBOutlet id nameField;
  IBOutlet id progInd;
}
                 
- (void)showWindowWithTitle:(NSString *)title
                    appName:(NSString *)appname
                  operation:(NSString *)operation              
               maxProgValue:(double)maxvalue;

- (void)updateProgressBy:(double)incr;

- (NSWindow *)win;

@end 


id<NSMenuItem> addItemToMenu(NSMenu *menu, NSString *str, 
														NSString *comm, NSString *sel, NSString *key);

#endif // MDFINDER_H
