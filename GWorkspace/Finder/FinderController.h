/* FinderController.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
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
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */


#ifndef FINDER_CONTROLLER_H
#define FINDER_CONTROLLER_H

#include <Foundation/NSObject.h>
#include <AppKit/NSView.h>

@class NSString;
@class NSMutableArray;
@class NSTask;
@class NSTimer;
@class NSNotification;
@class FinderShelf;
@class GWorkspace;

@protocol FindFileProtocol

- (oneway void)findAtPath:(NSString *)apath 
             withCriteria:(NSString *)crit;

@end 

@protocol FinderProtocol

- (void)registerFindFile:(id)anObject;

- (BOOL)getFoundPath:(NSString *)fpath;

- (void)findDone;

@end 

@interface SelectedFileView : NSView
{
  NSImage *icon, *highlightImage;
  NSTextField *nameField;
  BOOL isactive;
}

- (void)activateForFileAtPath:(NSString *)fpath;

- (void)deactivate;

@end

@interface FinderController : NSObject <FinderProtocol>
{
  IBOutlet id fWin;
  IBOutlet id split;
  IBOutlet id shelfBox;
  
  FinderShelf *shelf;
  float shelfHeight;
  
  IBOutlet id lowBox;
  IBOutlet id findButt; 
  IBOutlet id stopButt; 
  IBOutlet id namePopUp; 
  IBOutlet id nameField;  
  IBOutlet id filenamelabel;
  IBOutlet id iconBox;
  
  SelectedFileView *selectFileView;

  IBOutlet id optionsSplit;  
  IBOutlet id closableBox;
  BOOL optionsClosed;
  float optionsHeight;

  IBOutlet id generallabel;
  
  IBOutlet id kindPopUp;
  IBOutlet id kindTypePopUp;
  IBOutlet id kindlabel;
  
  IBOutlet id sizePopUp;
  IBOutlet id sizeField;
  IBOutlet id sizelabel;
  
  IBOutlet id ownerPopUp;
  IBOutlet id ownerField;
  IBOutlet id ownerlabel;

  IBOutlet id crDatePopUp;
  IBOutlet id crDateField;
  IBOutlet id crDateStepper;
  IBOutlet id datecrlabel;

  IBOutlet id modDatePopUp;
  IBOutlet id modDateField;
  IBOutlet id modDateStepper;
  IBOutlet id datemdlabel;

  IBOutlet id contentsField;
  IBOutlet id contentslabel;
  IBOutlet id includeslabel;
  
  IBOutlet id scrollBox;
  IBOutlet id scrollView;
  IBOutlet id foundMatrix;
  
  NSMutableDictionary *criteria;
  NSArray *currentSelection;
  NSMutableArray *foundPaths;
  NSTask *task;
  NSConnection *connection;
  NSTimer *timer;
  id <FindFileProtocol> findfile;
  GWorkspace *gw;
  BOOL donefind;
}

- (void)activate;

- (IBAction)startFind:(id)sender;

- (void)initNameControls;

- (void)initOptions;

- (NSDictionary *)initializeFindCriteria;

- (void)clearLastFound;

- (void)checkFindFile:(id)sender;

- (void)connectionDidDie:(NSNotification *)notification;

- (IBAction)stopFind:(id)sender;

- (IBAction)namePopUpAction:(id)sender; 

- (IBAction)kindPopUpAction:(id)sender; 

- (IBAction)kindTypePopUpAction:(id)sender;
 
- (IBAction)sizePopUpAction:(id)sender; 

- (IBAction)ownerPopUpAction:(id)sender; 

- (IBAction)crDatePopUpAction:(id)sender; 

- (IBAction)crDateStepperAction:(id)sender; 

- (IBAction)modDatePopUpAction:(id)sender; 

- (IBAction)modDateStepperAction:(id)sender; 

- (IBAction)choseFile:(id)sender; 

- (IBAction)openFile:(id)sender; 

- (void)updateIcons;

- (void)tile;

- (void)updateDefaults;

- (NSWindow *)myWin;

@end

#endif // FINDER_CONTROLLER_H
