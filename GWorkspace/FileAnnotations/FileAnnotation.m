/* FileAnnotation.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2004
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

#include <AppKit/AppKit.h>
#include "FileAnnotation.h"
#include "FileAnnotationsManager.h"
#include "GWFunctions.h"
#include "FSNodeRep.h"

#define ICON_SIZE 48

static NSString *nibName = @"FileAnnotation";

@implementation FileAnnotation

- (void)dealloc
{
  RELEASE (node);
  RELEASE (win);
  [super dealloc];
}

- (id)initForNode:(FSNode *)anode 
          annotationContents:(NSString *)contents
{
  self = [super init];
    
  if(self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"Preferences: failed to load %@!", nibName);
    } else {
      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
      FSNode *baseNode = [FSNode nodeWithPath: [anode parentPath]];
      NSDictionary *annotationsPrefs = nil;
      NSString *rectstr = nil;
      id defEntry;

      ASSIGN (node, anode);
      manager = [FileAnnotationsManager fannmanager];
      [win setDelegate: self];
      
      if ([baseNode isWritable]) {
		    NSString *dictPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];      

        if ([[NSFileManager defaultManager] fileExistsAtPath: dictPath]) {
          NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: dictPath];

          if (dict) {
            annotationsPrefs = [dict objectForKey: @"file_annotations"];
          }   
        }
      }
      
      if (annotationsPrefs == nil) {
        defEntry = [defaults dictionaryForKey: @"file_annotations"];

        if (defEntry) {
          annotationsPrefs = [defEntry objectForKey: @"file_annotations"];
        } 
      }
      
      if (annotationsPrefs) {
        NSString *pname = [NSString stringWithFormat: @"annotation_for_%@", [node path]];
        rectstr = [annotationsPrefs objectForKey: pname];
      }
      
      if (rectstr) {
        [win setFrameFromString: rectstr];
      } else {
        [win setFrame: rectForWindow([manager annotationsWins], [win frame], NO) 
              display: NO];
      }
            
      [imview setImage: [[FSNodeRep sharedInstance] iconOfSize: ICON_SIZE forNode: node]];
      [nameField setStringValue: [node name]];
    
      if (contents) {
        [textView setString: contents];
      }
      
      invalidated = NO;
      
      /* Internationalization */
      [win setTitle: NSLocalizedString(@"Annotations", @"")];
    }
  }
  
  return self;
}

- (NSString *)annotationContents
{
  NSString *contents = [textView string];
  return [contents length] ? contents : nil;
}

- (void)setAnnotationContents:(NSString *)contents
{
  [textView setString: contents];
}

- (FSNode *)node
{
  return node;
}

- (void)setNode:(FSNode *)anode
{
  ASSIGN (node, anode);
  [imview setImage: [[FSNodeRep sharedInstance] iconOfSize: ICON_SIZE forNode: node]];
  [nameField setStringValue: [node name]];
  invalidated = NO;
}

- (void)activate
{
  [win makeKeyAndOrderFront: nil];
}

- (void)invalidate
{
  invalidated = YES;
}

- (BOOL)invalidated
{
  return invalidated;
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
  FSNode *baseNode = [FSNode nodeWithPath: [node parentPath]];
  NSString *dictPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];      
  NSMutableDictionary *generalPrefs = nil;
  NSMutableDictionary *annotationsPrefs = nil;
  NSString *pname = [NSString stringWithFormat: @"annotation_for_%@", [node path]];
  NSDictionary *dict;
  
  if ([baseNode isWritable]) {
    if ([[NSFileManager defaultManager] fileExistsAtPath: dictPath]) {
      dict = [NSDictionary dictionaryWithContentsOfFile: dictPath];

      if (dict) {
        generalPrefs = [dict mutableCopy];
        dict = [generalPrefs objectForKey: @"file_annotations"];

        if (dict) {
          annotationsPrefs = [dict mutableCopy];
        }   
      }   
    }

  } else { 
    dict = [defaults dictionaryForKey: @"file_annotations"];

    if (dict) {
      annotationsPrefs = [dict mutableCopy];
    }
  }

  if (generalPrefs == nil) {
    generalPrefs = [NSMutableDictionary new];
  }

  if (annotationsPrefs == nil) {
    annotationsPrefs = [NSMutableDictionary new];
  }

  [annotationsPrefs setObject: [win stringWithSavedFrame] forKey: pname];

  if ([baseNode isWritable]) {
    [generalPrefs setObject: annotationsPrefs forKey: @"file_annotations"];
    [generalPrefs writeToFile: dictPath atomically: YES];
  } else {
    [defaults setObject: annotationsPrefs forKey: @"file_annotations"];
  }

  RELEASE (annotationsPrefs);
  RELEASE (generalPrefs);
}

- (id)win
{
  return win;
}

- (BOOL)windowShouldClose:(id)sender
{
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
  if ([node isValid]) {
    [self updateDefaults];
  }
  [manager annotationsWillClose: self]; 
}

@end
