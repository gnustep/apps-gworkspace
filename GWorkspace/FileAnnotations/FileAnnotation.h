/* FileAnnotation.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
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

#ifndef FILE_ANNOTATION_H
#define FILE_ANNOTATION_H

#include <Foundation/Foundation.h>

@class FSNode;

@interface FileAnnotation: NSObject
{
  FSNode *node;
  id manager;
  BOOL invalidated;
  IBOutlet id win;
  IBOutlet id topBox;
  IBOutlet id imview;
  IBOutlet id nameField;
  IBOutlet id textView;
}

- (id)initForNode:(FSNode *)anode 
          annotationContents:(NSString *)contents;

- (NSString *)annotationContents;

- (void)setAnnotationContents:(NSString *)contents;

- (FSNode *)node;

- (void)setNode:(FSNode *)anode;

- (void)activate;

- (void)invalidate;

- (BOOL)invalidated;

- (id)win;

- (void)updateDefaults;

@end

#endif // FILE_ANNOTATION_H
