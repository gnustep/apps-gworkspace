/* FileAnnotationsManager.m
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
#include "FileAnnotationsManager.h"
#include "FileAnnotation.h"
#include "GWorkspace.h"
#include "GWFunctions.h"
#include "FSNodeRep.h"

static FileAnnotationsManager *fannmanager = nil;

@implementation FileAnnotationsManager

+ (FileAnnotationsManager *)fannmanager
{
	if (fannmanager == nil) {
		fannmanager = [[FileAnnotationsManager alloc] init];
	}	
  return fannmanager;
}

- (void)dealloc
{
  [nc removeObserver: self];
  RELEASE (annotations);
  RELEASE (watchedpaths);
  [super dealloc];
}

- (id)init
{
  self = [super init];
    
  if(self) {
    annotations = [NSMutableArray new];
    watchedpaths = [NSMutableArray new];
    gw = [GWorkspace gworkspace];
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];

    [nc addObserver: self 
           selector: @selector(fileSystemWillChange:) 
               name: @"GWFileSystemWillChangeNotification"
             object: nil];

    [nc addObserver: self 
           selector: @selector(fileSystemDidChange:) 
               name: @"GWFileSystemDidChangeNotification"
             object: nil];

    [nc addObserver: self 
           selector: @selector(watcherNotification:) 
               name: @"GWFileWatcherFileDidChangeNotification"
             object: nil];    
  }
  
  return self;
}

- (void)showAnnotationsForNodes:(NSArray *)nodes
{
  if ([gw ddbdactive] == NO) {
    [gw connectDDBd];
  }
  
  if ([gw ddbdactive]) {
    int i;
  
    for (i = 0; i < [nodes count]; i++) {
      FSNode *node = [nodes objectAtIndex: i];
      NSString *path = [node path];
      FileAnnotation *ann = [self annotationsOfNode: node];
      
      if (ann == nil) {
        NSString *contents = [gw ddbdGetAnnotationsForPath: path];
            
        ann = [[FileAnnotation alloc] initForNode: node 
                               annotationContents: contents];
        [annotations addObject: ann];
        RELEASE (ann);  
        
        [watchedpaths addObject: path];
        [gw addWatcherForPath: path];
      }
      
      [ann activate];
    }
  }
}

- (FileAnnotation *)annotationsOfNode:(FSNode *)anode
{
  int i;
  
  for (i = 0; i < [annotations count]; i++) {
    FileAnnotation *ann = [annotations objectAtIndex: i];
    
    if ([[ann node] isEqual: anode]) {
      return ann;
    }
  }
  
  return nil;
}

- (FileAnnotation *)annotationsOfPath:(NSString *)apath
{
  int i;
  
  for (i = 0; i < [annotations count]; i++) {
    FileAnnotation *ann = [annotations objectAtIndex: i];
    
    if ([[[ann node] path] isEqual: apath]) {
      return ann;
    }
  }
  
  return nil;
}

- (void)annotationsWillClose:(id)ann
{
  FSNode *node = [ann node];

  [watchedpaths removeObject: [node path]];  
  [gw removeWatcherForPath: [node path]];
  
  if ([node isValid] && ([ann invalidated] == NO)) {
    if ([gw ddbdactive]) {
      NSString *contents = [ann annotationContents];
  
      if (contents) {
        [gw ddbdSetAnnotations: contents forPath: [node path]];
      }
    }
    
  } else {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
    FSNode *baseNode = [FSNode nodeWithPath: [node parentPath]];
    NSString *dictPath = [[baseNode path] stringByAppendingPathComponent: @".gwdir"];      
    NSMutableDictionary *generalPrefs = nil;
    NSMutableDictionary *annotationsPrefs = nil;
    NSDictionary *dict;
        
    if ([baseNode isValid] && [baseNode isWritable]) {
      if ([fm fileExistsAtPath: dictPath]) {
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
    
    if (annotationsPrefs) {
      NSString *path = [node path];
      NSString *pname = [NSString stringWithFormat: @"annotation_for_%@", path];     
      [annotationsPrefs removeObjectForKey: pname];
    }
    
    if ([baseNode isValid] && [baseNode isWritable] && generalPrefs) {
      [generalPrefs setObject: annotationsPrefs forKey: @"file_annotations"];
      [generalPrefs writeToFile: dictPath atomically: YES];
    } else if (annotationsPrefs) {
      [defaults setObject: annotationsPrefs forKey: @"file_annotations"];
    }
  
    TEST_RELEASE (annotationsPrefs);
    TEST_RELEASE (generalPrefs);
  }
        
  [annotations removeObject: ann];
}

- (NSArray *)annotationsWins
{
  NSMutableArray *wins = [NSMutableArray array];
  int i;  

  for (i = 0; i < [annotations count]; i++) {
    [wins addObject: [[annotations objectAtIndex: i] win]];
  }

  return wins;
}

- (void)closeAll
{
  int count = [annotations count];
  int i;

  for (i = 0; i < count; i++) {
    [[[annotations objectAtIndex: 0] win] close];
  }
}

- (void)fileSystemWillChange:(NSNotification *)notif
{
  NSDictionary *info = (NSDictionary *)[notif object];  
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSArray *files = [info objectForKey: @"files"];
  NSMutableArray *annsToClose = [NSMutableArray array];
  int i;
    
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
    files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent]; 
  }

  for (i = 0; i < [annotations count]; i++) {
    FileAnnotation *ann = [annotations objectAtIndex: i];
    FSNode *node = [ann node];
    
    if ([node involvedByFileOperation: info]) {
      if ([node willBeValidAfterFileOperation: info] == NO) {
        if ([operation isEqual: @"NSWorkspaceMoveOperation"]
                || [operation isEqual: @"GWorkspaceRenameOperation"]) {
          [watchedpaths removeObject: [node path]];
        } else {
          [annsToClose addObject: ann];
        }
      }
    }
  }

  for (i = 0; i < [annsToClose count]; i++) {
    FileAnnotation *ann = [annsToClose objectAtIndex: i];
    [ann invalidate];
    [[ann win] close];
  }
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *info = (NSDictionary *)[notif object];  
  NSString *operation = [info objectForKey: @"operation"];
  NSString *source = [info objectForKey: @"source"];
  NSString *destination = [info objectForKey: @"destination"];
  NSArray *files = [info objectForKey: @"files"];
  NSMutableArray *annsToClose = [NSMutableArray array];
  int i;

  if ([operation isEqual: @"NSWorkspaceMoveOperation"]
            || [operation isEqual: @"GWorkspaceRenameOperation"]) {
    NSMutableArray *srcpaths;

    if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
      srcpaths = [NSArray arrayWithObject: source];
    } else {
      srcpaths = [NSMutableArray array];
    
      for (i = 0; i < [files count]; i++) {
        NSString *fname = [files objectAtIndex: i];
        [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
      }
    }

    for (i = 0; i < [annotations count]; i++) {
      FileAnnotation *ann = [annotations objectAtIndex: i];
      FSNode *node = [ann node];
      
      if ([srcpaths containsObject: [node path]]) {
        FSNode *newnode;
      
        if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
          newnode = [FSNode nodeWithPath: destination];
        } else {
          NSString *path = [destination stringByAppendingPathComponent: [node name]];
          newnode = [FSNode nodeWithPath: path];
        }
        
        [ann setNode: newnode];
        [watchedpaths addObject: [newnode path]];
        [gw addWatcherForPath: [newnode path]];
      }
    }
  }  

  for (i = 0; i < [annotations count]; i++) {
    FileAnnotation *ann = [annotations objectAtIndex: i];
    
    if ([[ann node] isValid] == NO) {
      [annsToClose addObject: ann];
    } 
  }

  for (i = 0; i < [annsToClose count]; i++) {
    FileAnnotation *ann = [annsToClose objectAtIndex: i];
    [ann invalidate];
    [[ann win] close];
  }
}

- (void)watcherNotification:(NSNotification *)notif
{
  NSDictionary *info = (NSDictionary *)[notif object];
  NSString *event = [info objectForKey: @"event"];

  if ([event isEqual: @"GWWatchedDirectoryDeleted"]
              || [event isEqual: @"GWWatchedFileDeleted"]) { 
    NSString *path = [info objectForKey: @"path"];
    
    if ([watchedpaths containsObject: path]) {
      FileAnnotation *ann = [self annotationsOfPath: path];

      if (ann) {
        [ann invalidate];
        [[ann win] close];
        
        if ([gw ddbdactive]) {    
          [gw ddbdRemovePath: path]; 
        }
      }
    }
  }
}

@end















