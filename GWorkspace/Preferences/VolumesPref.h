/* VolumesPref.h
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
 
#ifndef VOLUMES_PREFS_H
#define VOLUMES_PREFS_H

#include <Foundation/Foundation.h>
#include "PrefProtocol.h"

@class NSMatrix;
@class FSNodeRep;

@interface VolumesPref : NSObject <PrefProtocol>
{
  IBOutlet id win;
  IBOutlet id prefbox;
  
  IBOutlet id mtabBox;
  IBOutlet id mtabField;
  IBOutlet id mediaBox;
  IBOutlet id mediaScroll;
  NSMatrix *mediaMatrix;
  IBOutlet id mediaField;
  IBOutlet id remMediaButt;
  IBOutlet id addMediaButt;
  IBOutlet id setMediaButt;

  FSNodeRep *fsnoderep;
}

- (IBAction)addMediaMountPoint:(id)sender;

- (IBAction)removeMediaMountPoint:(id)sender;

- (IBAction)setMediaMountPoints:(id)sender;

@end

#endif // VOLUMES_PREFS_H
