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
#include "XDockWindow.h"

@implementation XDockWindow

- (void)makeKeyAndOrderFront:(id)sender
{
  GSDisplayServer *server = GSCurrentServer();
  Display *dpy = (Display *)[server serverDevice];
  void *winptr = [server windowDevice: [self windowNumber]];
  Window win = *(Window *)winptr;
  Atom atom = 0;
  long data = 1;
    
  atom = XInternAtom(dpy, "KWM_WIN_STICKY", False);
  
  if (atom != 0) {
    XChangeProperty(dpy, win, atom, atom, 32, 
                        PropModeReplace, (unsigned char *)&data, 1);
  }
  
  atom = XInternAtom(dpy, "WIN_STATE_STICKY", False);

  if (atom != 0) {  
    XChangeProperty(dpy, win, atom, atom, 32, 
                        PropModeReplace, (unsigned char *)&data, 1);
  }
  
	[super makeKeyAndOrderFront: sender];
}

@end
