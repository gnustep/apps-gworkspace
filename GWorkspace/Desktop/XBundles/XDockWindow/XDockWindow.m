/* XDockWindow.m
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2005
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include <GNUstepGUI/GSDisplayServer.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include "XDockWindow.h"

@implementation XDockWindow

- (void)activate
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
  GSDisplayServer *server = GSCurrentServer();
  Display *dpy = (Display *)[server serverDevice];
  void *winptr = [server windowDevice: [self windowNumber]];
  Window win = *(Window *)winptr;
  long data = 1;

  if ([defaults boolForKey: @"NET_WM"]) {
    long l = -1;
    Atom atoms[3];

	  [self orderFront: nil];

    atoms[0] = XInternAtom(dpy, "_NET_WM_DESKTOP", False);

    XChangeProperty(dpy, win, atoms[0], XA_CARDINAL,
                          32, PropModeReplace, (unsigned char*)&l, 1);

    atoms[1] = XInternAtom(dpy, "_NET_WM_STATE", False);

    XChangeProperty(dpy, win, atoms[1], atoms[1], 32, 
                          PropModeReplace, (unsigned char *)&data, 1);

    atoms[2] = XInternAtom(dpy, "_NET_WM_STATE_STICKY", False);

    XChangeProperty(dpy, win, atoms[1], XA_ATOM, 32, 
                          PropModeReplace, (unsigned char *)&atoms[2], 1);
  } else {
    Atom atom = 0;  
 
    atom = XInternAtom(dpy, "KWM_WIN_STICKY", False);

    XChangeProperty(dpy, win, atom, atom, 32, 
                          PropModeReplace, (unsigned char *)&data, 1);

    atom = XInternAtom(dpy, "WIN_STATE_STICKY", False);

    XChangeProperty(dpy, win, atom, atom, 32, 
                          PropModeReplace, (unsigned char *)&data, 1);

	  [self orderFront: nil];
  }
}

- (void)orderWindow:(NSWindowOrderingMode)place 
         relativeTo:(int)otherWin
{
  [super orderWindow: place relativeTo: otherWin];
  [self setLevel: NSDesktopWindowLevel];
}

@end
