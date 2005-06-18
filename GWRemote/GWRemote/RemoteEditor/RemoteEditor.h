/* RemoteEditor.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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

#ifndef REMOTE_EDITOR_H
#define REMOTE_EDITOR_H

#include <Foundation/NSObject.h>
#include <AppKit/NSView.h>

@class RemoteEditorView;

@interface RemoteEditor : NSObject
{
  NSString *serverName;
  NSString *filePath;
  NSString *fileName;
  
  IBOutlet id win;
  IBOutlet id scrollView;
  
  RemoteEditorView *editorView;
  
  id gwremote;
}

- (id)initForEditFile:(NSString *)filepath
         withContents:(NSString *)contents
         onRemoteHost:(NSString *)hostname;

- (void)activate;

- (void)setEdited;

- (BOOL)isEdited;

- (BOOL)trySave;

- (NSString *)serverName;

- (NSString *)filePath;
     
@end

#endif // REMOTE_EDITOR_H


