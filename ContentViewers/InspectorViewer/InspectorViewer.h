/*
 *  InspectorViewer.h: Interface and declarations for the FolderViewer Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Fabien VALLON <fabien.vallon@fr.alcove.com>
 *  
 *  Author: Fabien Vallon
 *  Date: July 2002
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

#ifndef INSPECTORVIEWER_H
#define INSPECTORVIEWER_H

#include <AppKit/NSView.h>
  #ifdef GNUSTEP 
#include "ContentViewersProtocol.h"
  #else
#include <GWorkspace/ContentViewersProtocol.h>
  #endif
#include <AppKit/NSTextField.h>
#include <AppKit/NSTextView.h>

@class NSArray;

@interface InspectorViewer : NSView <ContentViewersProtocol>
{
  id panel;
  id buttCancel, buttOk;

  NSTextField *textName,*textVersion,*textStatus;
  NSTextView *textDescription;
  NSTextField *errorLabel;
  
  NSArray *extsarr;
  id workspace;
  NSString *bundlePath;
  NSString *localizedStr;
  int index;
  
}

-(void) _displayError: (NSString *) error;
-(BOOL) _isInstalled:(NSString *) path;
@end

#endif
