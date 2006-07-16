/* SoundViewer.h
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef SOUNDVIEWER_H
#define SOUNDVIEWER_H

#include <Foundation/Foundation.h>
#include <AppKit/NSView.h>
#include "ContentViewersProtocol.h"

@class NSBox;
@class NSTextField;
@class NSButton;
@class NSProgressIndicator;
@class NSWorkspace;
@class NSSound;

@protocol ContentInspectorProtocol

- (void)contentsReadyAt:(NSString *)path;

@end 

@interface SoundViewer : NSView <ContentViewersProtocol>
{
	NSString *soundPath;
	NSSound *sound;
	BOOL valid;

  NSBox *playBox;
  NSTextField *errLabel;
	NSButton *playButt, *pauseButt, *stopButt;
	NSProgressIndicator *indicator;

	NSButton *editButt;
	
  id <ContentInspectorProtocol>inspector;
  NSWorkspace *ws;
}

- (void)buttonsAction:(id)sender;

- (void)editFile:(id)sender;

- (void)setContextHelp;

@end

#endif // SOUNDVIEWER_H
