/* FileOpInfo.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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

#ifndef FILE_OP_INFO_H
#define FILE_OP_INFO_H

#include <Foundation/Foundation.h>

@interface FileOpInfo: NSObject
{
  id viewer;
  NSString *source;
  NSString *destination;
  NSArray *files;
  int ref;
  int type;
  
  IBOutlet id win;
  IBOutlet id nameField;
  IBOutlet id sizeField;
  IBOutlet id globProgInd;
  IBOutlet id fileProgInd;
  IBOutlet id stopButt;  
}

+ (id)fileOpInfoForViewer:(id)vwr
                     type:(int)tp
                      ref:(int)rf
                   source:(NSString *)src
              destination:(NSString *)dst
                    files:(NSArray *)fls
                usewindow:(BOOL)uwnd
                  winrect:(NSRect)wrect;

- (id)initForViewer:(id)vwr
               type:(int)tp
                ref:(int)rf
             source:(NSString *)src
        destination:(NSString *)dst
              files:(NSArray *)fls
          usewindow:(BOOL)uwnd
            winrect:(NSRect)wrect;

- (void)showWindowWithTitle:(NSString *)title 
                 filesCount:(int)fcount;
                 
- (void)updateGlobalProgress:(NSString *)fname;

- (void)startFileProgress:(int)fsize;

- (void)updateFileProgress:(int)increment;

- (IBAction)stopAction:(id)sender;

- (void)closeWindow;

- (NSString *)source;

- (NSString *)destination;

- (NSArray *)files;

- (NSDictionary *)description;

- (int)ref;

- (int)type;

- (NSWindow *)win;

- (NSRect)winRect;

- (void)checkWinFrame;

- (NSDictionary *)description;

@end 

#endif // FILE_OP_INFO_H
