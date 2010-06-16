/* Contents.h
 *  
 * Copyright (C) 2004-2010 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
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

@class NSWorkspace;
@class NSImage;
@class NSView;
@class TextViewer;
@class GenericView;
@class NSTextView;
@class NSScrollView;
@class NSTextField;
@class NSButton;

@interface Contents : NSObject
{
  IBOutlet id win;
  IBOutlet NSBox *mainBox;
  IBOutlet NSBox *topBox;
  IBOutlet id iconView;
  IBOutlet id titleField;
  IBOutlet NSBox *viewersBox;  

  NSView *noContsView;
  GenericView *genericView;

  NSMutableArray *viewers;
  id currentViewer;
  
  TextViewer *textViewer;
  
  NSString *currentPath;
  
  NSImage *pboardImage;
  
  NSFileManager *fm;
  NSWorkspace *ws;
  
  id inspector;
}

- (id)initForInspector:(id)insp;

- (NSView *)inspView;

- (NSString *)winname;

- (void)activateForPaths:(NSArray *)paths;

- (id)viewerForPath:(NSString *)path;

- (id)viewerForDataOfType:(NSString *)type;

- (void)showContentsAt:(NSString *)path;

- (void)contentsReadyAt:(NSString *)path;

- (BOOL)canDisplayDataOfType:(NSString *)type;

- (void)showData:(NSData *)data 
          ofType:(NSString *)type;

- (BOOL)isShowingData;

- (void)dataContentsReadyForType:(NSString *)typeDescr
                         useIcon:(NSImage *)icon;

- (void)watchedPathDidChange:(NSDictionary *)info;

- (id)inspector;

@end


@interface TextViewer : NSView
{
  NSScrollView *scrollView;
  NSTextView *textView;
  NSTextField *errLabel;
  NSButton *editButt;
  NSString *editPath;
  NSWorkspace *ws;
  id contsinsp;
}

- (id)initWithFrame:(NSRect)frameRect
       forInspector:(id)insp;

- (BOOL)tryToDisplayPath:(NSString *)path;

- (NSData *)textContentsAtPath:(NSString *)path 
                withAttributes:(NSDictionary *)attributes;

- (void)editFile:(id)sender;

@end


@interface GenericView : NSView
{
  NSString *shComm;
  NSString *fileComm;
  NSTask *task;
  NSPipe *pipe;
  NSTextView *textview;
  NSNotificationCenter *nc;
}

- (void)showInfoOfPath:(NSString *)path;

- (void)dataFromTask:(NSNotification *)notif;

- (void)showString:(NSString *)str;

@end

