/* SoundViewer.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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


#ifndef SOUNDVIEWER_H
#define SOUNDVIEWER_H

#include <AppKit/NSView.h>
  #ifdef GNUSTEP 
#include "ContentViewersProtocol.h"
  #else
#include <GWorkspace/ContentViewersProtocol.h>
  #endif

@class NSString;
@class NSTask;
@class NSPipe;
@class NSFileHandle;
@class NSNotificationCenter;
@class NSTextView;
@class NSButton;
@class NSProgressIndicator;
@class NSSound;

@interface SoundViewer : NSView <ContentViewersProtocol>
{
	id panel;
	id buttOk;
	NSString *editPath;
  NSString *bundlePath;
	int index;
	
	NSString *soundPath;
	NSSound *sound;
	
	NSButton *playButt, *pauseButt, *stopButt;
	NSProgressIndicator *indicator;
	
	NSTask *task;	
	NSPipe *pipe;
	NSTextView *textView;	
	NSNotificationCenter *nc;
	id ws;
}

- (void)buttonsAction:(id)sender;

- (void)findContentsAtPath:(NSString *)apath;

- (void)dataFromTask:(NSNotification *)notification;

- (void)endOfTask:(NSNotification *)notification;

- (void)editFile:(id)sender;

@end

#endif // SOUNDVIEWER_H
