/* GWSplitView.h
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef GWSPLITVIEW_H
#define GWSPLITVIEW_H

#include <AppKit/NSSplitView.h>

@class NSString;
@class NSMutableArray;
@class NSTextFieldCell;
@class GWSplitView;

@interface FileOpIndicator : NSObject 
{
  NSString *operation;
  NSString *statusStr;
  NSTimer *timer;
  GWSplitView *gwsplit;
  BOOL valid;
}

- (id)initInSplitView:(GWSplitView *)split 
    withOperationName:(NSString *)opname;

- (void)update:(id)sender;

- (NSString *)operation;

- (void)invalidate;

- (BOOL)isValid;

@end

@interface GWSplitView : NSSplitView 
{
  id vwr;
  NSTextFieldCell *diskInfoField;
  NSString *diskInfoString;
  NSRect diskInfoRect;
  NSTextFieldCell *fopInfoField;
  NSString *fopInfoString;   
  NSRect fopInfoRect;
  NSMutableArray *indicators; 
#ifndef GNUSTEP
	NSColor *_backgroundColor;
#endif  
}

- (id)initWithFrame:(NSRect)frameRect viewer:(id)viewer;

- (void)updateDiskSpaceInfo:(NSString *)info;

- (void)updateFileOpInfo:(NSString *)info;

- (void)startIndicatorForOperation:(NSString *)operation;

- (void)stopIndicatorForOperation:(NSString *)operation;

- (FileOpIndicator *)firstIndicatorForOperation:(NSString *)operation;

#ifndef GNUSTEP
	- (NSColor*)backgroundColor;
	- (void)setBackgroundColor:(NSColor *)aColor;
#endif

@end

#endif // GWSPLITVIEW_H
