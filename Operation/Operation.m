/* Operation.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep Operation application
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "Operation.h"
#include "Preferences/OperationPrefs.h"
#include "FileOpInfo.h"
#include "Functions.h"
#include "GNUstep.h"

static Operation *operation = nil;

@implementation Operation

+ (Operation *)operation
{
	if (operation == nil) {
		operation = [[Operation alloc] init];
	}	
  return operation;
}

+ (void)initialize
{
	static BOOL initialized = NO;
	
	if (initialized == YES) {
		return;
  }
	
	initialized = YES;
}

- (void)dealloc
{
  RELEASE (fileOperations);
  RELEASE (preferences);
    
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  fileOperations = [NSMutableArray new];
  fopRef = 0;
  preferences = [OperationPrefs new];
  fm = [NSFileManager defaultManager];
  nc = [NSNotificationCenter defaultCenter];
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
#define TEST_CLOSE(o, w) if ((o) && ([w isVisible])) [w close]
  
  if ([fileOperations count]) {
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"Wait the operations to terminate!", @""),
					          NSLocalizedString(@"OK", @""), 
                    nil, 
                    nil);  
    return NO;
  }

  [self updateDefaults];

  TEST_CLOSE (preferences, [preferences win]);
    		
	return YES;
}

- (void)setFilenamesCutted:(BOOL)value
{
  filenamesCutted = value;
}

- (BOOL)filenamesWasCutted
{
  return filenamesCutted;
}

- (void)performOperation:(NSData *)opinfo
{
  NSDictionary *opdict = [NSUnarchiver unarchiveObjectWithData: opinfo];
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
  int i;

  if (files == nil) {
    files = [NSArray arrayWithObject: @""];
  }
  
  if ([operation isEqual: @"NSWorkspaceMoveOperation"]
         || [operation isEqual: @"NSWorkspaceCopyOperation"]
         || [operation isEqual: @"NSWorkspaceLinkOperation"]
         || [operation isEqual: @"NSWorkspaceRecycleOperation"]
         || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) {
    opbase = source;
  } else {
    opbase = destination;
  }

  if ([operation isEqual: @"NSWorkspaceMoveOperation"]
               || [operation isEqual: @"NSWorkspaceRecycleOperation"]
               || [operation isEqual: @"GWorkspaceRecycleOutOperation"]) {    
    action = MOVE;
  } else if ([operation isEqual: @"NSWorkspaceDestroyOperation"] 
            || [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    action = DESTROY;
  } else if ([operation isEqual: @"NSWorkspaceCopyOperation"] 
                || [operation isEqual: @"NSWorkspaceLinkOperation"]
                || [operation isEqual: @"NSWorkspaceDuplicateOperation"]) {
    action = COPY;
  }

  opfiles = files;

	if ([self verifyFileAt: opbase] == NO) {
		return;
	}

  oppaths = [NSMutableArray array];
  filesInfo = [NSMutableArray array];

	for (i = 0; i < [opfiles count]; i++) {
		NSString *opfile = [opfiles objectAtIndex: i];
		NSString *oppath = [opbase stringByAppendingPathComponent: opfile];

		if ([self verifyFileAt: oppath]) {
      NSDictionary *attributes = [fm fileAttributesAtPath: oppath traverseLink: NO];
      NSData *date = [attributes objectForKey: NSFileModificationDate];
      NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys: opfile, @"name", date, @"date", nil]; 
          
      [oppaths addObject: oppath];
      [filesInfo addObject: dict];
		} else {
			return;
    }
	}
  
  for (i = 0; i < [oppaths count]; i++) {
    NSString *oppath = [oppaths objectAtIndex: i];

    if ([self isLockedAction: action onPath: oppath]) {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"some files are in use by an other operation!", @""),
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
  int i;
  
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
  int i;

  for (i = 0; i < [opfiles count]; i++) {
    NSDictionary *fdict = [opfiles objectAtIndex: i];
    NSString *opfile = [fdict objectForKey: @"name"];
  
    [opsrcpaths addObject: [opsrc stringByAppendingPathComponent: opfile]];
    
    if ([optype isEqual: @"NSWorkspaceDuplicateOperation"] == NO) {
      [opdstpaths addObject: [opdst stringByAppendingPathComponent: opfile]];
    
    } else {
      NSString *copystr = NSLocalizedString(@"copy", @"");
      NSString *ofstr = NSLocalizedString(@"_of_", @"");
      NSString *ntmp;
      NSString *destpath;
      int count = 1;
    
			while(1) {
        if (count == 1) {
          ntmp = [NSString stringWithFormat: @"%@%@%@", copystr, ofstr, opfile];
        } else {
          ntmp = [NSString stringWithFormat: @"%@%i%@%@", copystr, count, ofstr, opfile];
        }
        
				destpath = [opdst stringByAppendingPathComponent: ntmp];  
              
				if ([fm fileExistsAtPath: destpath] == NO) {
          [opdstpaths addObject: destpath];
					break;
        } else {
          count++;
        }
			}
    }
  }

  if ([optype isEqual: @"NSWorkspaceMoveOperation"]
                    || [optype isEqual: @"NSWorkspaceRecycleOperation"]
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
    if ((action == MOVE) || (action == RENAME) || (action == DESTROY)) {
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

  if ([optype isEqual: @"NSWorkspaceCopyOperation"]
                  || [optype isEqual: @"NSWorkspaceLinkOperation"]
                  || [optype isEqual: @"NSWorkspaceDuplicateOperation"]) {
    //
    // source
    //    
    if ((action == MOVE) || (action == RENAME) || (action == DESTROY)) {
      if ([opsrcpaths containsObject: path]
              || [self descendentOfPath: path inPaths: opsrcpaths]
                    || [self ascendentOfPath: path inPaths: opsrcpaths]) {
        return YES;
      } 
    }

    //             
    // destination
    //
    if ((action == MOVE) || (action == RENAME) || (action == DESTROY)) {
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

  if ([optype isEqual: @"NSWorkspaceDestroyOperation"]
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

- (FileOpInfo *)fileOpWithRef:(int)ref
{
  int i;
  
  for (i = 0; i < [fileOperations count]; i++) {
    FileOpInfo *op = [fileOperations objectAtIndex: i];
  
    if ([op ref] == ref) {
      return op;
    }
  }

  return nil;
}

- (int)fileOpRef
{
  return fopRef++;
}

- (NSRect)rectForFileOpWindow
{
  NSRect scr = [[NSScreen mainScreen] visibleFrame];
  NSRect wrect = NSZeroRect;
  int i;  

  #define WMARGIN 50
  #define WSHIFT 50

  scr.origin.x += WMARGIN;
  scr.origin.y += WMARGIN;
  scr.size.width -= (WMARGIN * 2);
  scr.size.height -= (WMARGIN * 2);

	for (i = [fileOperations count] - 1; i >= 0; i--) {
    FileOpInfo *op = [fileOperations objectAtIndex: i];

    if ([op win]) {
      NSRect wr = [op winRect];

      if (NSEqualRects(wr, NSZeroRect) == NO) {
        wrect = NSMakeRect(wr.origin.x + WSHIFT, 
                           wr.origin.y - wr.size.height - WSHIFT,
                           wr.size.width,
                           wr.size.height);

        if (NSContainsRect(scr, wrect) == NO) {
          wrect = NSMakeRect(scr.origin.x, 
                             scr.size.height - wr.size.height,
                             wr.size.width, 
                             wr.size.height);
          break;
        }
      }
    }
  }

  return wrect;
}

- (BOOL)verifyFileAt:(NSString *)path
{
	if ([fm fileExistsAtPath: path] == NO) {
		NSString *err = NSLocalizedString(@"Error", @"");
		NSString *msg = NSLocalizedString(@": no such file or directory!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
		NSMutableDictionary *notifObj = [NSMutableDictionary dictionaryWithCapacity: 1];		
		NSString *basePath = [path stringByDeletingLastPathComponent];
		
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@%@", path, msg], buttstr, nil, nil);   

		[notifObj setObject: @"NSWorkspaceDestroyOperation" forKey: @"operation"];	
  	[notifObj setObject: basePath forKey: @"source"];	
  	[notifObj setObject: basePath forKey: @"destination"];	
  	[notifObj setObject: [NSArray arrayWithObjects: path, nil] forKey: @"files"];	

    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemWillChangeNotification"
	 								object: nil userInfo: notifObj];

    [[NSDistributedNotificationCenter defaultCenter]
 				postNotificationName: @"GWFileSystemDidChangeNotification"
	 								object: nil userInfo: notifObj];

		return NO;
	}
	
	return YES;
}

- (BOOL)ascendentOfPath:(NSString *)path 
                inPaths:(NSArray *)paths
{
  int i;

  for (i = 0; i < [paths count]; i++) {  
    if (subPathOfPath([paths objectAtIndex: i], path)) {
      return YES;
    }
  }

  return NO;
}

- (BOOL)descendentOfPath:(NSString *)path 
                 inPaths:(NSArray *)paths
{
  int i;

  for (i = 0; i < [paths count]; i++) {  
    if (subPathOfPath(path, [paths objectAtIndex: i])) {
      return YES;
    }
  }

  return NO;
}

- (void)updateDefaults
{
  if ([[preferences win] isVisible]) {
    [preferences updateDefaults];
  }
}


//
// Menu Operations
//
- (void)showPreferences:(id)sender
{
  [preferences activate];
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"Operation" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"-----------------------", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"Operation 0.7" forKey: @"ApplicationRelease"];
  [d setObject: @"04 2004" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: @"Enrico Sersale <enrico@imago.ro>.", nil]
        forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gworkspace", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2004 Free Software Foundation, Inc."
        forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
        forKey: @"CopyrightDescription"];
  
#ifdef GNUSTEP	
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
#else
	[NSApp orderFrontStandardAboutPanel: d];
#endif
}

#ifndef GNUSTEP
- (void)terminate:(id)sender
{
  [NSApp terminate: self];
}
#endif

@end
