/* Inspector.h
 *  
 * Copyright (C) 2004-2014 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
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

#ifndef INSPECTOR_H
#define INSPECTOR_H

#import <Foundation/Foundation.h>
#import "FSNodeRep.h"

@class Attributes;
@class Contents;
@class Tools;
@class IconView;
@class NSPopUpButton;
@class NSWindow;

@interface Inspector : NSObject 
{
  IBOutlet NSWindow *win;
  IBOutlet NSPopUpButton *popUp;
  IBOutlet NSBox *inspBox;

  NSMutableArray *inspectors;
  id currentInspector;

  NSArray *currentPaths;
  NSString *watchedPath;
    
  NSNotificationCenter *nc; 

  id <DesktopApplication> desktopApp;
}

- (void)activate;

- (void)setCurrentSelection:(NSArray *)selection;

- (BOOL)canDisplayDataOfType:(NSString *)type;

- (void)showData:(NSData *)data 
          ofType:(NSString *)type;

- (IBAction)activateInspector:(id)sender;

- (void)showAttributes;

- (id)attributes;

- (void)showContents;

- (id)contents;

- (void)showTools;

- (id)tools;

- (void)showAnnotations;

- (id)annotations;

- (NSWindow *)win;

- (void)updateDefaults;

- (void)addWatcherForPath:(NSString *)path;

- (void)removeWatcherForPath:(NSString *)path;

- (void)watcherNotification:(NSNotification *)notif;

- (id)desktopApp;

@end


@interface Inspector (CustomDirectoryIcons)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
                        inIconView:(IconView *)iview;

- (void)draggingExited: (id <NSDraggingInfo>)sender
            inIconView:(IconView *)iview;

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender 
                   inIconView:(IconView *)iview;

@end

#endif // INSPECTOR_H
