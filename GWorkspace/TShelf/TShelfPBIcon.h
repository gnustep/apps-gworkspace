/* TShelfPBIcon.h
 *  
 * Copyright (C) 2003-2021 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale <enrico@imago.ro>
 *          Riccardo Mottola <rm@gnu.org>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef TSHELF_PB_ICON_H
#define TSHELF_PB_ICON_H

#import <AppKit/NSView.h>

#import "TShelfIcon.h"

@class NSImage;
@class NSBezierPath;
@class TShelfIconsView;

@interface TShelfPBIcon : TShelfIcon
{
  NSString *dataPath;
  NSString *dataType;
}

+ (NSArray *)dataTypes;

- (id)initForPBDataAtPath:(NSString *)dpath
                   ofType:(NSString *)type
                gridIndex:(NSUInteger)index
              inIconsView:(TShelfIconsView *)aview;

- (NSString *)dataPath;

- (NSString *)dataType;

- (NSData *)data;

@end

@interface TShelfPBIcon (DraggingSource)

- (void)declareAndSetShapeOnPasteboard:(NSPasteboard *)pb;

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag;

@end

#endif // TSHELF_PB_ICON_H

