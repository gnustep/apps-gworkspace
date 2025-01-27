/* Annotations.h
 *  
 * Copyright (C) 2005-2024 Free Software Foundation, Inc.
 *
 * Authors: Enrico Sersale
 *          Riccardo Mottola
 *
 * Date: February 2005
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
 * Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */


#import <Foundation/Foundation.h>

@class NSWindow;
@class FSNode;
@class NSView;
@class IconView;
@class NSTextView;

@interface Annotations: NSObject
{
  IBOutlet NSWindow *win;
  IBOutlet NSBox *mainBox;
  IBOutlet NSBox *topBox;
  IBOutlet IconView *iconView;
  IBOutlet NSTextField *titleField;
  IBOutlet NSBox *toolsBox;
  IBOutlet NSTextView *textView;
  IBOutlet NSButton *okButt;

  NSString *currentPath;
  NSView *noContsView; 
  id inspector;
  id desktopApp;
}

- (instancetype)initForInspector:(id)insp;

- (NSView *)inspView;

- (NSString *)winname;

- (void)activateForPaths:(NSArray *)paths;

- (IBAction)setAnnotations:(id)sender;

@end

