/* Recycler.m
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWLib.h"
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWLib.h>
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "Recycler.h"
#include "RecyclerViews.h"
#include "RecyclerIcon.h"
#include "GWorkspace.h"
#include "GNUstep.h"

@implementation RecyclerWindow

- (id)initWithContentRect:(NSRect)contentRect 
                styleMask:(unsigned int)styleMask 
                  backing:(NSBackingStoreType)backingType 
                    defer:(BOOL)flag
{
  self = [super initWithContentRect: contentRect
                  styleMask: styleMask backing: backingType defer: flag];
  
  [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];  
  
  return self;
}

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
  return [[self contentView] draggingEntered: sender];
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
	return [[self contentView] draggingUpdated: sender];
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[[self contentView] draggingExited: sender];  
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return [[self contentView] prepareForDragOperation: sender];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return [[self contentView] performDragOperation: sender];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  [[self contentView] concludeDragOperation: sender];
}

@end


@implementation Recycler

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	RELEASE (tile);
	RELEASE (emptyImg);
	RELEASE (fullImg);
	RELEASE (recyclerView);
	RELEASE (iconsView);
	RELEASE (icons);
	RELEASE (recyclerWin);
	RELEASE (trashPath);
	RELEASE (contentsDict);
	TEST_RELEASE (selectedPath);
	[super dealloc];
}

- (id)initWithTrashPath:(NSString *)trashpath
{
	self = [super initWithFrame: NSMakeRect(0, 0, 64, 64)];
  if (self) {
		NSUserDefaults *defaults;
		id result;
		NSScrollView *scroll;
		unsigned int style;
		
		defaults = [NSUserDefaults standardUserDefaults];

		result = [defaults objectForKey: @"recyclercontents"];
		if (result == nil) {
    	contentsDict = [[NSMutableDictionary alloc] initWithCapacity: 1];
		} else {
    	contentsDict = [result mutableCopy];    
  	}
		
		ASSIGN (trashPath, trashpath);
    ASSIGN (tile, [NSImage imageNamed: @"common_Tile.tiff"]);
    ASSIGN (emptyImg, [NSImage imageNamed: @"Recycler.tiff"]);
    ASSIGN (fullImg, [NSImage imageNamed: @"RecyclerFull.tiff"]);
		icons = [[NSMutableArray alloc] initWithCapacity: 1];
		fm = [NSFileManager defaultManager];
    gw = [GWorkspace gworkspace];
		isDragTarget = NO;
		isOpen = NO;
		selectedPath = nil;
	  [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];  
		
		style = NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask;
		
	  recyclerWin = [[NSWindow alloc] initWithContentRect: NSZeroRect
						  		styleMask: style backing: NSBackingStoreBuffered defer: NO];
    if ([recyclerWin setFrameUsingName: @"recyclerwin"] == NO) {
      [recyclerWin setFrame: NSMakeRect(100, 100, 400, 128) display: NO];
    }            
    [recyclerWin setMinSize: NSMakeSize(220, 128)];
    [recyclerWin setMaxSize: NSMakeSize(2000, 128)];
    [recyclerWin setTitle: NSLocalizedString(@"Recycler", @"")];
    [recyclerWin setReleasedWhenClosed: NO]; 
    [recyclerWin setDelegate: self];
		
		recyclerView = [[RecyclerView alloc] init];
		[recyclerView setFrame: [[recyclerWin contentView] frame]];

		logoView = [[LogoView alloc] init];
		[recyclerView addSubview: logoView];

		scroll = [NSScrollView new];
    [scroll setBorderType: NSBezelBorder];
    [scroll setHasHorizontalScroller: YES];
    [scroll setHasVerticalScroller: NO]; 
    [scroll setAutoresizingMask: NSViewWidthSizable];
		[scroll setBorderType: NSNoBorder];
		
		iconsView = [[IconsView alloc] initForRecycler: self];
	  [scroll setDocumentView: iconsView];

    [recyclerView addSubview: scroll]; 
		RELEASE (scroll);
		
		[recyclerWin setContentView: recyclerView];	

		[self makeTrashContents];

    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(fileSystemWillChange:) 
                					    name: GWFileSystemWillChangeNotification
                					  object: nil];
		
    [[NSNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(fileSystemDidChange:) 
                					    name: GWFileSystemDidChangeNotification
                					  object: nil];
														
  	[[NSNotificationCenter defaultCenter] addObserver: self 
                			selector: @selector(watcherNotification:) 
                					name: GWFileWatcherFileDidChangeNotification
                				object: nil];
														
		[self setWatcher];
		
		win = [[RecyclerWindow alloc] initWithContentRect: NSZeroRect
					                          styleMask: NSBorderlessWindowMask  
                              backing: NSBackingStoreRetained defer: NO];

    if ([win setFrameUsingName: @"recycler"] == NO) {
			NSRect r = [[NSScreen mainScreen] frame];
      [win setFrame: NSMakeRect(r.size.width - 64, 0, 64, 64) display: NO];
    }      
    [win setReleasedWhenClosed: NO]; 
    [win setContentView: self];
  }
	
  return self;
}

- (void)activate
{
	[win orderFront: nil]; 
}

- (NSWindow *)myWin
{
	return win;
}

- (NSWindow *)recyclerWin
{
	return recyclerWin;
}

- (void)makeTrashContents
{
	NSArray *dirContents = [fm directoryContentsAtPath: trashPath];
	NSArray *refnames = [contentsDict allKeys];
	int i, count;

	for (i = 0; i < [refnames count]; i++) {
		NSString *refname = [refnames objectAtIndex: i];			
		if ([dirContents containsObject: refname] == NO) {
			[contentsDict removeObjectForKey: refname];				
		}
	}

	count = [icons count];
	for (i = 0; i < count; i++) {
		RecyclerIcon *icon = [icons objectAtIndex: 0];
		[iconsView removeIcon: icon];
		[icons removeObject: icon];
	}

	for (i = 0; i < [dirContents count]; i++) {
		NSString *fname = [dirContents objectAtIndex: i];
		NSString *fpath = [trashPath stringByAppendingPathComponent: fname];
		RecyclerIcon *icon;
				
		[self verifyDictionaryForFileName: fname];
		icon = [[RecyclerIcon alloc] initWithPath: fpath inIconsView: iconsView];
		[icons addObject: icon];										
		[iconsView addIcon: icon];
		RELEASE (icon);
	}

	if ([dirContents count] > 0) {
		isFull = YES;
		[logoView setIsFull: YES];	
		[self setNeedsDisplay: YES];
	} else {
		isFull = NO;
		[logoView setIsFull: NO];	
		[self setNeedsDisplay: YES];
	}
		
	TEST_RELEASE (selectedPath);
	selectedPath = nil;
		
	[self saveDictionary];
}

- (BOOL)isFull
{
	return isFull;
}

- (BOOL)isOpen
{
	return isOpen;
}

- (NSString *)selectedPath
{
	return selectedPath;
}

- (BOOL)verifyDictionaryForFileName:(NSString *)fname
{
	NSString *fpath = [trashPath stringByAppendingPathComponent: fname];
	NSDictionary *attributes = [fm fileAttributesAtPath: fpath traverseLink: NO];
	NSDictionary *fdict = [contentsDict objectForKey: fname];

	if (fdict != nil) {			
		NSNumber *s1 = [attributes objectForKey: @"NSFileSize"];
		NSNumber *s2 = [NSNumber numberWithInt: [[fdict objectForKey: @"size"] intValue]];
		NSNumber *p1 = [attributes objectForKey: @"NSFilePosixPermissions"];
		NSNumber *p2 = [NSNumber numberWithInt: [[fdict objectForKey: @"permissions"] intValue]];
		NSDate *d1 = [attributes objectForKey: @"NSFileModificationDate"];
		NSDate *d2 = [NSDate dateWithString: [fdict objectForKey: @"modifdate"]];
		
		if (([s1 isEqual: s2] == NO) 
							|| ([p1 isEqual: p2] == NO) 
											|| ([d1 isEqual: d2] == NO)) {
			[contentsDict removeObjectForKey: fname];
			return NO;
		}
	} else {
		return NO;
	}
	
	return YES;
}

- (void)setCurrentSelection:(NSString *)path
{
	if (path != nil) {
		ASSIGN (selectedPath, path);
		[gw setSelectedPaths: [NSArray arrayWithObject: selectedPath]];
	} else {
		TEST_RELEASE (selectedPath);
		selectedPath = nil;
	}
}

- (void)updateDefaults
{
	if ([win isVisible]) {
  	[win saveFrameUsingName: @"recycler"];
	}
	if ([recyclerWin isVisible]) {
  	[recyclerWin saveFrameUsingName: @"recyclerwin"];
	}	
}

- (void)saveDictionary
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
	[defaults setObject: contentsDict forKey: @"recyclercontents"];
	[defaults synchronize];
}

- (void)setWatcher
{
	[GWLib addWatcherForPath: trashPath];
	watching = YES;
}

- (void)unsetWatcher
{
  [[NSNotificationCenter defaultCenter] removeObserver: self 
                name: GWFileWatcherFileDidChangeNotification object: nil];

	[GWLib removeWatcherForPath: trashPath];
	
	watching = NO;
}

- (void)watcherNotification:(NSNotification *)notification
{
  NSDictionary *notifdict = (NSDictionary *)[notification object];
  NSString *path = [notifdict objectForKey: @"path"];

	if ([path isEqualToString: trashPath]) {
		NSString *event = [notifdict objectForKey: @"event"];
		
		if ((event == GWFileDeletedInWatchedDirectory)
											|| (event == GWFileCreatedInWatchedDirectory)) {
			[self makeTrashContents];
		}
	}
}

- (void)fileSystemWillChange:(NSNotification *)notification
{
	NSDictionary *dict = (NSDictionary *)[notification object];
  NSString *operation = [dict objectForKey: @"operation"];
	NSString *source = [dict objectForKey: @"source"];
	NSString *destination = [dict objectForKey: @"destination"];

	if (operation == NSWorkspaceRecycleOperation
									|| operation == NSWorkspaceMoveOperation) {
		if ([destination isEqualToString: trashPath]) {
			NSArray *files = [dict objectForKey: @"files"];
			int i;
			
			for (i = 0; i < [files count]; i++) {		
				NSString *fname = [files objectAtIndex: i];
				NSString *origpath = [source stringByAppendingPathComponent: fname];
				NSDictionary *attributes = [fm fileAttributesAtPath: origpath traverseLink: NO];
				NSString *owner = [attributes objectForKey: @"NSFileOwnerAccountName"];
				NSString *group = [attributes objectForKey: @"NSFileGroupOwnerAccountName"];
				NSString *permissions = [[attributes objectForKey: @"NSFilePosixPermissions"] stringValue];
				NSString *size = [[attributes objectForKey: @"NSFileSize"] stringValue];
				NSString *modifdate = [[attributes objectForKey: @"NSFileModificationDate"] description];
				NSMutableDictionary *fdict = [NSMutableDictionary dictionaryWithCapacity: 1];
	
				[fdict setObject: fname forKey: @"fname"];
				[fdict setObject: origpath forKey: @"origpath"];
				[fdict setObject: owner forKey: @"owner"];
				[fdict setObject: group forKey: @"group"];
				[fdict setObject: permissions forKey: @"permissions"];
				[fdict setObject: size forKey: @"size"];
				[fdict setObject: modifdate forKey: @"modifdate"];
				
				[contentsDict setObject: fdict forKey: fname];
			}
		}
	}
	
	if (operation == GWorkspaceRecycleOutOperation) {
		[self unsetWatcher];	
	}
}

- (void)fileSystemDidChange:(NSNotification *)notification
{
  NSDictionary *dict = (NSDictionary *)[notification object];
  NSString *operation = [dict objectForKey: @"operation"];
	NSString *source = [dict objectForKey: @"source"];
	NSString *destination = [dict objectForKey: @"destination"];
		
	if (operation == GWorkspaceRecycleOutOperation) {
		NSArray *files = 	[dict objectForKey: @"files"];
		int i;

		for (i = 0; i < [files count]; i++) {
			NSString *fname = [files objectAtIndex: i];
			NSDictionary *fdict = [contentsDict objectForKey: fname];
			NSString *fpath = [destination stringByAppendingPathComponent: fname];
		
 			[fm changeFileAttributes: fdict atPath: fpath];	
		}
		
		[self makeTrashContents];
		
		if (watching == NO) {
			[self setWatcher];	
		}
		
		return;
	}
	
  if (operation == GWorkspaceRenameOperation) {
    destination = [destination stringByDeletingLastPathComponent];
  }  
     
	if ([source isEqualToString: trashPath] 
													|| [destination isEqualToString: trashPath]) { 
		[self makeTrashContents];
	}				
}

- (void)emptyRecycler
{
	NSArray *files = [fm directoryContentsAtPath: trashPath];
	int tag;
	
  [gw performFileOperation: GWorkspaceEmptyRecyclerOperation 
				source: trashPath destination: trashPath files: files tag: &tag];
}

- (void)putAway
{
	RecyclerIcon *icon;
	NSString *name, *path;
	NSDictionary *dict;
	NSString *origpath;
	BOOL isdir;
	int i, tag;
	
	for (i = 0; i < [icons count]; i++) {
		icon = [icons objectAtIndex: i];
		
		if ([icon isSelect] == NO) {
			continue;
		}
		
		name = [icon name];
		path = [icon path];
	
		if ([self verifyDictionaryForFileName: name] == NO) {
			return;
		}
		
		dict = [contentsDict objectForKey: name];

		origpath = [dict objectForKey: @"origpath"];
		if (origpath != nil) {
			origpath = [origpath stringByDeletingLastPathComponent];
			if (([fm fileExistsAtPath: origpath isDirectory: &isdir] && isdir) == NO) {
				return;
			}
		} else {
			return;
		}
	
  	[gw performFileOperation: GWorkspaceRecycleOutOperation 
					source: trashPath destination: origpath 
								files: [NSArray arrayWithObject: name] tag: &tag];
	}
}

- (void)mouseDown:(NSEvent*)theEvent
{
	NSEvent *nextEvent;
  NSPoint location, lastLocation, origin;
  float initx, inity;
	      
	if ([theEvent clickCount] > 1) {  
		[recyclerWin orderFront: nil];
    return;
	}  
  
  initx = [win frame].origin.x;
  inity = [win frame].origin.y;
  
  lastLocation = [theEvent locationInWindow];

  while (1) {
	  nextEvent = [win nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];

    if ([nextEvent type] == NSLeftMouseUp) {    
      [self updateDefaults];
      break;
    } else if ([nextEvent type] == NSLeftMouseDragged) {
 		  location = [win mouseLocationOutsideOfEventStream];
      origin = [win frame].origin;
		  origin.x += (location.x - lastLocation.x);
		  origin.y += (location.y - lastLocation.y);
      [win setFrameOrigin: origin];
    }
  }
}                                                        

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

- (void)drawRect:(NSRect)rect
{
  [self lockFocus];
	[tile compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver]; 
	if (isFull) {
		[fullImg compositeToPoint: NSMakePoint(8, 8) operation: NSCompositeSourceOver]; 
	} else {
		[emptyImg compositeToPoint: NSMakePoint(8, 8) operation: NSCompositeSourceOver]; 
	}
  [self unlockFocus];  
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
	isOpen = NO;
	return YES;
}

- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	isOpen = YES;
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	isOpen = NO;
}

@end

@implementation Recycler (DraggingDestination)

- (unsigned int)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
  if([[pb types] indexOfObject: NSFilenamesPboardType] != NSNotFound) {
  	NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
		
		if ((sourceDragMask == NSDragOperationCopy) 
											|| (sourceDragMask == NSDragOperationLink)) {
			return NSDragOperationNone;
		}
	
    isDragTarget = YES;
  	return NSDragOperationAll;
  }
     
  return NSDragOperationNone;
}

- (unsigned int)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;
	
	if (isDragTarget == NO) {
		return NSDragOperationNone;
	}

	sourceDragMask = [sender draggingSourceOperationMask];

	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
		return NSDragOperationNone;
	}

	return NSDragOperationAll;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	isDragTarget = NO;  
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb;
	NSString *source;
	NSArray *sourcePaths;
	NSMutableArray *files;
  int i, tag;
	
	isDragTarget = NO;
	
  pb = [sender draggingPasteboard];
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
	source = [[sourcePaths objectAtIndex: 0] stringByDeletingLastPathComponent];
	
	files = [NSMutableArray arrayWithCapacity: 1];
	for (i = 0; i < [sourcePaths count]; i++) {
    [files addObject: [[sourcePaths objectAtIndex: i] lastPathComponent]];  
	}
	
  [gw performFileOperation: NSWorkspaceRecycleOperation source: source
							  destination: trashPath files: files tag: &tag];	
}

@end

