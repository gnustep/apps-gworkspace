/* Operation.m
 *  
 * Copyright (C) 2004-2015 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
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
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "Operation.h"
#import "FileOpInfo.h"
#import "Functions.h"


@implementation Operation

- (void)dealloc
{
  RELEASE (fileOperations);
    
	[super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {  
    fileOperations = [NSMutableArray new];
    fopRef = 0;
    fm = [NSFileManager defaultManager];
    nc = [NSNotificationCenter defaultCenter];
  }
  
  return self;
}

- (void)setFilenamesCut:(BOOL)value
{
  filenamesCut = value;
}

- (BOOL)filenamesWasCut
{
  return filenamesCut;
}

- (void)performOperation:(NSDictionary *)opdict
{
  NSString *operation = [opdict objectForKey: @"operation"];
  NSString *source = [opdict objectForKey: @"source"];
  NSString *destination = [opdict objectForKey: @"destination"];
  NSArray *files = [opdict objectForKey: @"files"];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString *confirmString = [operation stringByAppendingString: @"Confirm"];
  BOOL confirm = !([defaults boolForKey: confirmString]);
  BOOL usewin = ![defaults boolForKey: @"fopstatusnotshown"];
  NSString *opbase;
  NSArray *opfiles;
  NSMutableArray *oppaths;
  NSMutableArray *filesInfo;
  int action;
  FileOpInfo *info;
  NSUInteger i;

  if (files == nil)
    {
      files = [NSArray arrayWithObject: @""];
    }

  opfiles = files;

  if ([operation isEqual: @"GWorkspaceRenameOperation"]
      || [operation isEqual: @"GWorkspaceCreateDirOperation"]
      || [operation isEqual: @"GWorkspaceCreateFileOperation"])
    {    
      confirm = NO;
      usewin = NO;
    }
   
  if ([operation isEqual: NSWorkspaceMoveOperation]
      || [operation isEqual: NSWorkspaceCopyOperation]
      || [operation isEqual: NSWorkspaceLinkOperation]
      || [operation isEqual: NSWorkspaceDuplicateOperation]
      || [operation isEqual: NSWorkspaceRecycleOperation]
      || [operation isEqual: NSWorkspaceDestroyOperation] 
      || [operation isEqual: @"GWorkspaceRecycleOutOperation"])
    {
      opbase = source;
    }
  else
    {
      opbase = destination;
    }

  if ([operation isEqual: @"GWorkspaceRenameOperation"])
    {
      opfiles = [NSArray arrayWithObject: [source lastPathComponent]];
      opbase = [source stringByDeletingLastPathComponent];
    }
  
  action = MOVE;
  if ([operation isEqual: NSWorkspaceMoveOperation]
      || [operation isEqual: NSWorkspaceRecycleOperation]
      || [operation isEqual: @"GWorkspaceRecycleOutOperation"])
    {    
      action = MOVE;
    } else if ([operation isEqual: NSWorkspaceDestroyOperation] 
	       || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"])
    {
      action = DESTROY;
    } else if ([operation isEqual: NSWorkspaceCopyOperation] 
	       || [operation isEqual: NSWorkspaceLinkOperation]
	       || [operation isEqual: NSWorkspaceDuplicateOperation]) 
    {
      action = COPY;
    } else if ([operation isEqual: @"GWorkspaceRenameOperation"])
    {
      action = RENAME;
    } else if ([operation isEqual: @"GWorkspaceCreateDirOperation"] 
	       || [operation isEqual: @"GWorkspaceCreateFileOperation"])
    {
      action = CREATE;
    }

  if ([self verifyFileAtPath: opbase forOperation: nil] == NO)
    {
      return;
    }

  oppaths = [NSMutableArray array];
  filesInfo = [NSMutableArray array];

  for (i = 0; i < [opfiles count]; i++)
    {
      NSString *opfile = [opfiles objectAtIndex: i];
      NSString *oppath = [opbase stringByAppendingPathComponent: opfile];

      if ([self verifyFileAtPath: oppath forOperation: operation])
	{
	  NSDictionary *attributes = [fm fileAttributesAtPath: oppath traverseLink: NO];
	  NSData *date = [attributes objectForKey: NSFileModificationDate];
	  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: opfile, @"name", date, @"date", nil]; 
          
	  [oppaths addObject: oppath];
	  [filesInfo addObject: dict];
	} else
	{
	  return;
	}
    }
  
  for (i = 0; i < [oppaths count]; i++)
    {
      NSString *oppath = [oppaths objectAtIndex: i];

      if ([self isLockedAction: action onPath: oppath])
	{
	  NSRunAlertPanel(nil, 
			  NSLocalizedString(@"Some files are in use by another operation!", @""),
			  NSLocalizedString(@"OK", @""), 
			  nil, 
			  nil);  
	  return;
	}
    }
  
  info = [FileOpInfo operationOfType: operation
                                 ref: [self fileOpRef]
                              source: source
                         destination: destination
                               files: filesInfo
                        confirmation: confirm
                           usewindow: usewin
                             winrect: [self rectForFileOpWindow]
                          controller: self];
  
  [fileOperations insertObject: info atIndex: [fileOperations count]];
  [info startOperation];
}

- (BOOL)isLockedAction:(int)action
                onPath:(NSString *)path 
{
  NSUInteger i;
  
  for (i = 0; i < [fileOperations count]; i++) {
    FileOpInfo *info = [fileOperations objectAtIndex: i];
    
    if ([self isLockedByOperation: info action: action onPath: path]) {
      return YES;
    }
  }
  
  return NO;
}

- (BOOL)isLockedByOperation:(FileOpInfo *)opinfo
                     action:(int)action
                     onPath:(NSString *)path 
{
  NSString *optype = [opinfo type];
  NSString *opsrc = [opinfo source];
  NSString *opdst = [opinfo destination];
  NSArray *opfiles = [opinfo files];
  NSMutableArray *opsrcpaths = [NSMutableArray array];
  NSMutableArray *opdstpaths = [NSMutableArray array];
  NSUInteger i;

  if ([optype isEqual: NSWorkspaceDuplicateOperation] == NO) {
    for (i = 0; i < [opfiles count]; i++) {
      NSDictionary *fdict = [opfiles objectAtIndex: i];
      NSString *opfile = [fdict objectForKey: @"name"];

      [opsrcpaths addObject: [opsrc stringByAppendingPathComponent: opfile]];
      [opdstpaths addObject: [opdst stringByAppendingPathComponent: opfile]];
    }
  
  } else {
    NSArray *dupfiles = [opinfo dupfiles];
  
    for (i = 0; i < [opfiles count]; i++) {
      NSDictionary *fdict = [opfiles objectAtIndex: i];
      NSString *opfile = [fdict objectForKey: @"name"];

      [opsrcpaths addObject: [opsrc stringByAppendingPathComponent: opfile]];
    }

    for (i = 0; i < [dupfiles count]; i++) {
      NSString *dupfile = [dupfiles objectAtIndex: i];

      [opdstpaths addObject: [opdst stringByAppendingPathComponent: dupfile]];
    }
  }
    
  if (action == CREATE) {    
    path = [path stringByDeletingLastPathComponent];
  }

  if ([optype isEqual: NSWorkspaceMoveOperation]
                    || [optype isEqual: NSWorkspaceRecycleOperation]
                    || [optype isEqual: @"GWorkspaceRecycleOutOperation"]) {
    //
    // source
    //
    if ([opsrcpaths containsObject: path]
            || [self descendentOfPath: path inPaths: opsrcpaths]
                  || [self ascendentOfPath: path inPaths: opsrcpaths]) {
      return YES;
    }
     
    //             
    // destination
    //
    if ((action == MOVE) || (action == RENAME) 
                              || (action == DESTROY) || (action == CREATE)) {
      if ([self descendentOfPath: path inPaths: opdstpaths]) {
        return YES;
      }
    }
    if ([opdstpaths containsObject: path]) {  
      return YES;
    }
    if ([self ascendentOfPath: path inPaths: opdstpaths]) {
      return YES;
    }
  }

  if ([optype isEqual: NSWorkspaceCopyOperation]
                  || [optype isEqual: NSWorkspaceLinkOperation]
                  || [optype isEqual: NSWorkspaceDuplicateOperation]) {
    //
    // source
    //    
    if ((action == MOVE) || (action == RENAME) 
                              || (action == DESTROY) || (action == CREATE)) {
      if ([opsrcpaths containsObject: path]
              || [self descendentOfPath: path inPaths: opsrcpaths]
                    || [self ascendentOfPath: path inPaths: opsrcpaths]) {
        return YES;
      } 
    }

    //             
    // destination
    //
    if ((action == MOVE) || (action == RENAME) 
                              || (action == DESTROY) || (action == CREATE)) {
      if ([self descendentOfPath: path inPaths: opdstpaths]) {
        return YES;
      }
    }
    if ([opdstpaths containsObject: path]) {  
      return YES;
    }
    if ([self ascendentOfPath: path inPaths: opdstpaths]) {
      return YES;
    }
  }

  if ([optype isEqual: NSWorkspaceDestroyOperation]
            || [optype isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    //             
    // destination
    //
    if ([opdstpaths containsObject: path]
            || [self descendentOfPath: path inPaths: opdstpaths]
                  || [self ascendentOfPath: path inPaths: opdstpaths]) {
      return YES;
    }
  }

  return NO;
}

- (void)endOfFileOperation:(FileOpInfo *)op
{
  [fileOperations removeObject: op];
}

- (FileOpInfo *)fileOpWithRef:(NSUInteger)ref
{
  NSUInteger i;
  
  for (i = 0; i < [fileOperations count]; i++) {
    FileOpInfo *op = [fileOperations objectAtIndex: i];
  
    if ([op ref] == ref) {
      return op;
    }
  }

  return nil;
}

- (NSUInteger)fileOpRef
{
  return fopRef++;
}

- (NSRect)rectForFileOpWindow
{
  NSRect scr = [[NSScreen mainScreen] visibleFrame];
  NSRect wrect = NSZeroRect;
  NSUInteger i;  
  
#define WMARGIN 40
#define WSHIFT 40
  
  if ([fileOperations count] == 0)
    return wrect;
  
  scr.origin.x += WMARGIN;
  scr.origin.y += WMARGIN;
  scr.size.width -= (WMARGIN * 2);
  scr.size.height -= (WMARGIN * 2);
  
  i = [fileOperations count];
  while (i > 0 && NSEqualRects(wrect, NSZeroRect) == YES)
    {
      FileOpInfo *op = [fileOperations objectAtIndex: i-1];
  
      if ([op win])
        {
          NSRect wr;

          [op getWinRect: &wr];
          if (NSEqualRects(wr, NSZeroRect) == NO)
            {
              wrect = NSMakeRect(wr.origin.x + WSHIFT, 
                                 wr.origin.y - wr.size.height - WSHIFT,
                                 wr.size.width,
                                 wr.size.height);
              
              if (NSContainsRect(scr, wrect) == NO)
                {
                  wrect = NSMakeRect(scr.origin.x, 
                                     scr.size.height - wr.size.height,
                                     wr.size.width, 
                                     wr.size.height);
                }
            }
        }
      i--;
    }

  return wrect;
}

- (BOOL)verifyFileAtPath:(NSString *)path
            forOperation:(NSString *)operation
{
  NSString *chpath = path;
  BOOL valid;
  BOOL isDir;
  
  if (operation && ([operation isEqual: @"GWorkspaceCreateDirOperation"]
                  || [operation isEqual: @"GWorkspaceCreateFileOperation"]))
    {    
      chpath = [path stringByDeletingLastPathComponent];
    }
  
  valid = [fm fileExistsAtPath: chpath isDirectory:&isDir];
  
  if (valid == NO)
    {
    /* case of broken symlink */
    valid = ([fm fileAttributesAtPath: chpath traverseLink: NO] != nil);
  }
  
  if (valid == NO)
    {
      NSString *err = NSLocalizedString(@"Error", @"");
      NSString *msg = NSLocalizedString(@": no such file or directory!", @"");
      NSString *buttstr = NSLocalizedString(@"Continue", @"");
      NSMutableDictionary *notifObj = [NSMutableDictionary dictionaryWithCapacity: 1];		
      NSString *basePath = [chpath stringByDeletingLastPathComponent];
      
      NSRunAlertPanel(err, [NSString stringWithFormat: @"%@%@", chpath, msg], buttstr, nil, nil);   
      
      [notifObj setObject: NSWorkspaceDestroyOperation forKey: @"operation"];	
      [notifObj setObject: basePath forKey: @"source"];	
      [notifObj setObject: basePath forKey: @"destination"];	
      [notifObj setObject: [NSArray arrayWithObject: [chpath lastPathComponent]] 
                   forKey: @"files"];	
      
      [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemWillChangeNotification"
                                              object: nil userInfo: notifObj];
      
      [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemDidChangeNotification"
                                              object: nil userInfo: notifObj];
      
      return NO;
    }
  else
    {
      if ([operation isEqual: NSWorkspaceMoveOperation]
          || [operation isEqual: NSWorkspaceRecycleOperation]
          || [operation isEqual: NSWorkspaceDestroyOperation] 
          || [operation isEqual: @"GWorkspaceRecycleOutOperation"]
          || [operation isEqual: @"GWorkspaceRenameOperation"])
        {
          if (isDir)
            {
              NSArray *specialPathArray;
              NSString *fullPath;
              BOOL protected = NO;

              NSString *err = NSLocalizedString(@"Error", @"");
              NSString *msg = NSLocalizedString(@": Directory Protected!", @"");
              NSString *buttstr = NSLocalizedString(@"Continue", @"");	
      
              
              fullPath = [path stringByExpandingTildeInPath];
              specialPathArray = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSAllDomainsMask, YES);
              if ([specialPathArray indexOfObject:fullPath] != NSNotFound)
                protected = YES;

              if (!protected)
                {
                  specialPathArray = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
                  if ([specialPathArray indexOfObject:fullPath] != NSNotFound)
                    protected = YES;
                }

              if (!protected)
                {
                  specialPathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSAllDomainsMask, YES);
                  if ([specialPathArray indexOfObject:fullPath] != NSNotFound)
                    protected = YES;
                }

              if (!protected)
                {
                  specialPathArray = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSAllDomainsMask, YES);
                  if ([specialPathArray indexOfObject:fullPath] != NSNotFound)
                    protected = YES;
                }

              if (protected)
                {
                  NSRunAlertPanel(err, [NSString stringWithFormat: @"%@%@", path, msg], buttstr, nil, nil);
                  return NO;
                }
            }        
        }
    }
  
  return YES;
}

- (BOOL)ascendentOfPath:(NSString *)path 
                inPaths:(NSArray *)paths
{
  NSUInteger i;

  for (i = 0; i < [paths count]; i++) {  
    if (isSubpath([paths objectAtIndex: i], path)) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)descendentOfPath:(NSString *)path 
                 inPaths:(NSArray *)paths
{
  NSUInteger i;

  for (i = 0; i < [paths count]; i++) {  
    if (isSubpath(path, [paths objectAtIndex: i])) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)operationsPending
{
  return ([fileOperations count] > 0);
}

@end
