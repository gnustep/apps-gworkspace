/*
 *  Interface and declarations for the DefEditorPref Class 
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

#ifndef DEF_EDITOR_PREF_H
#define DEF_EDITOR_PREF_H

#include <Foundation/NSObject.h>
  #ifdef GNUSTEP 
#include "PreferencesProtocol.h"
  #else
#include <GWorkspace/PreferencesProtocol.h>
  #endif

@class NSWorkspace;
@class GWorkspace;
@class NSFont;

@interface DefEditorPref : NSObject <PreferencesProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;
  IBOutlet id iconbox;
  IBOutlet id imView;
  IBOutlet id nameLabel;
  IBOutlet id chooseButt;

  NSString *defEditor;
  NSString *noEditorStr;
  NSFont *font;
  float iconBoxWidth;
  float labelHeight;
  NSPoint labelOrigin;
	NSWorkspace *ws;
  GWorkspace *gw;  
}

- (IBAction)chooseEditor:(id)sender;

- (void)setEditor:(NSString *)editor;

- (void)tile;

@end

#endif // DEF_EDITOR_PREF_H
