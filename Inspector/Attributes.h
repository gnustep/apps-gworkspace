/* Attributes.h
 *  
 * Copyright (C) 2004-2024 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale
 *         Riccardo Mottola
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

@class NSWindow;
@class NSImage;
@class NSTextField;
@class NSButton;
@class Sizer;
@class IconView;
@class TimeDateView;


@protocol SizerProtocol

- (oneway void)computeSizeOfPaths:(NSArray *)paths;

- (oneway void)stopComputeSize;

@end

@protocol AttributesSizeProtocol

- (oneway void)setSizer:(id)anObject;

- (oneway void)sizeReady:(NSString *)sizeStr;

@end


@interface Attributes : NSObject
{
  IBOutlet NSWindow *win;
  IBOutlet NSBox *mainBox;

  IBOutlet NSBox *topBox;
  IBOutlet IconView *iconView;
  IBOutlet NSTextField *titleField;

  IBOutlet NSTextField *linkToLabel;
  IBOutlet NSTextField *linkToField;
  
  IBOutlet NSTextField *sizeLabel;
  IBOutlet NSTextField *sizeField;
  IBOutlet NSButton *calculateButt;
  IBOutlet NSTextField *ownerLabel;
  IBOutlet NSTextField *ownerField;
  IBOutlet NSTextField *groupLabel;
  IBOutlet NSTextField *groupField;

  IBOutlet NSBox *changedDateBox;
  IBOutlet TimeDateView *timeDateView;
  IBOutlet NSBox *permsBox;

  IBOutlet NSTextField *readLabel;
  IBOutlet NSTextField *writeLabel;
  IBOutlet NSTextField *executeLabel;
  IBOutlet NSTextField *uLabel;
  IBOutlet NSTextField *gLabel;
  IBOutlet NSTextField *oLabel;
  IBOutlet NSButton *ureadbutt;
  IBOutlet NSButton *uwritebutt;
  IBOutlet NSButton *uexebutt;
  IBOutlet NSButton *greadbutt;
  IBOutlet NSButton *gwritebutt;
  IBOutlet NSButton *gexebutt;
  IBOutlet NSButton *oreadbutt;
  IBOutlet NSButton *owritebutt;
  IBOutlet NSButton *oexebutt; 
  IBOutlet NSButton *insideButt;

  IBOutlet NSButton *revertButt;
  IBOutlet NSButton *okButt;

  NSArray *insppaths;
  
  NSDictionary *attributes;
  BOOL iamRoot, isMyFile;
  NSImage *onImage, *offImage, *multipleImage;
  BOOL multiplePaths;
    
  NSString *currentPath;	
    
  NSConnection *sizerConn;
  id <SizerProtocol>sizer;
  BOOL autocalculate;
  id inspector;
  
  NSFileManager *fm;
  NSNotificationCenter *nc;  
}

- (id)initForInspector:(id)insp;

- (NSView *)inspView;

- (NSString *)winname;

- (void)activateForPaths:(NSArray *)paths;

- (IBAction)permsButtonsAction:(id)sender;

- (IBAction)insideButtonAction:(id)sender;

- (IBAction)changePermissions:(id)sender;

- (IBAction)revertToOldPermissions:(id)sender;

- (void)setPermissions:(unsigned long)perms 
              isActive:(BOOL)active;

- (unsigned long)getPermissions:(unsigned long)oldperms;

- (void)watchedPathDidChange:(NSDictionary *)info;

- (void)setCalculateSizes:(BOOL)value;

- (IBAction)calculateSizes:(id)sender;

- (void)startSizer;

- (void)sizerConnDidDie:(NSNotification *)notification;

- (void)setSizer:(id)anObject;

- (void)sizeReady:(NSString *)sizeStr;

- (void)updateDefaults;

@end


@interface Sizer : NSObject
{
  id attributes;
  NSFileManager *fm;
}

+ (void)createSizerWithPorts:(NSArray *)portArray;

- (id)initWithAttributesConnection:(NSConnection *)conn;

- (void)computeSizeOfPaths:(NSArray *)paths;

@end

