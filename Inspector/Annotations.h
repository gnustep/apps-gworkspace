/* Annotations.h
 *  
 * Copyright (C) 2005-2010 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */


#import <Foundation/Foundation.h>

@class FSNode;
@class NSView;

@interface Annotations: NSObject
{
  IBOutlet id win;
  IBOutlet NSBox *mainBox;
  IBOutlet NSBox *topBox;
  IBOutlet id iconView;
  IBOutlet id titleField;
  IBOutlet NSBox *toolsBox;
  IBOutlet id textView;
  IBOutlet id okButt;

  NSString *currentPath;
  NSView *noContsView; 
  id inspector;
  id desktopApp;
}

- (id)initForInspector:(id)insp;

- (NSView *)inspView;

- (NSString *)winname;

- (void)activateForPaths:(NSArray *)paths;

- (IBAction)setAnnotations:(id)sender;

@end

