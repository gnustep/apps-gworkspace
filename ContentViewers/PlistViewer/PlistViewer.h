/*
 *  PlistViewer.h: Interface and declarations for the PlistViewer Class 
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

#ifndef PLISTVIEWER_H
#define PLISTVIEWER_H

  #ifdef GNUSTEP 
#include "ContentViewersProtocol.h"
  #else
#include <GWorkspace/ContentViewersProtocol.h>
  #endif

@class NSString;
@class NSArray;
@class NSOutlineView;
@class NSTextView;

@interface PlistViewer : NSView <ContentViewersProtocol>
{
  id panel;
  id buttOk;
  NSArray *extsarr;
  NSRect imrect;
  NSOutlineView *outlineView;
  NSTextView *textView;
  NSString *bundlePath;
  
  BOOL valid;	
  int index;
  NSString *editPath;
  NSString *localizedStr;
  NSArray *keysArray;
  NSArray *valueArray;
  NSDictionary *plistDict;
  id workspace;
}

- (void)editFile:(id)sender;

@end

#endif // PLISTVIEWER_H
