 /*
 *  AppsViewer.h: Interface and declarations for the AppsViewer Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */
 
#ifndef APPSVIEWER_H
#define APPSVIEWER_H

#include <Foundation/NSObject.h>

@class NSWindow;
@class NSView;
@class NSMatrix;
@class NSMutableArray;
@class NSNotification;
@class NSWorkspace;
@class NSTextField;
@class NSButton;

@interface AppsViewer : NSObject 
{
  NSWindow *win;
  NSMatrix *appsMatrix; 
  NSButton *appButt;
  NSTextField *appNameField, *appPathField;
  NSWorkspace *ws;
}

- (void)activate;

- (void)setApplicationInfo:(id)sender;

- (void)applicationLaunched:(NSNotification *)aNotification;

- (void)applicationTerminated:(NSNotification *)aNotification;

- (void)updateDefaults;

- (NSWindow *)myWin;

@end

#endif // APPSVIEWER_H

