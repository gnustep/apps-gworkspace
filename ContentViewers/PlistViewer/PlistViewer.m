/*  -*-objc-*-
 *  PlistViewer.m: Implementation of the PlistViewer Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2002 Fabien VALLON <fabien.vallon@fr.alcove.com>
 *                     Alcove <http://www.alcove.com>
 *
 *  Author: Fabien VALLON <fabien.vallon@fr.alcove.com>
 *  Date: August 2002
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "PlistViewer.h"
#include "GNUstep.h"

  #ifdef GNUSTEP 
#include "GWLib.h"
  #else
#include <GWorkspace/GWLib.h>
  #endif

@implementation PlistViewer

- (void)dealloc
{
  RELEASE (extsarr);
  RELEASE (textView);
  [super dealloc];
}
    

- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
  self = [super init];
  
  if(self) 
    {
      NSTableColumn *plistBoxColumn;
      NSString *suffs = @"plist, classes";
      NSScrollView *scrollView,*scrollViewText;
      [self setFrame: frame];
      //      panel = (id<InspectorsProtocol>)apanel;
      workspace = [NSWorkspace sharedWorkspace];
      index = idx;
      extsarr = [[NSArray alloc] initWithArray: [suffs componentsSeparatedByString:@", "]];

      plistBoxColumn = [[NSTableColumn alloc] initWithIdentifier: @"plop"];
      [plistBoxColumn setEditable: NO];
      [[plistBoxColumn headerCell] setStringValue: _(@"Plist")];
      [plistBoxColumn setMinWidth: 100];

      
      outlineView = [[NSOutlineView alloc] initWithFrame: NSMakeRect(0,50,250,180)];
      [outlineView addTableColumn: plistBoxColumn];
      [outlineView setDrawsGrid: NO];
      [outlineView setIndentationPerLevel: 5];
      [outlineView setDataSource:self];
      [outlineView setDelegate:self];
      
      scrollView = [[NSScrollView alloc] initWithFrame: NSMakeRect(0,50,250,180)];
      [scrollView setBorderType: NSBezelBorder];
      [scrollView setHasVerticalScroller : YES];
      [scrollView setHasHorizontalScroller : YES];
      [scrollView setDocumentView: outlineView];

      textView = [[NSTextView alloc] initWithFrame : NSMakeRect(0,0,250,45)];

      scrollViewText = [[NSScrollView alloc] initWithFrame: NSMakeRect(0,0,250,45)];
      [scrollViewText setBorderType: NSBezelBorder];
      [scrollViewText setHasVerticalScroller : NO];
      [scrollViewText setHasHorizontalScroller : NO];
      [scrollViewText setDocumentView: textView];
     

      //[self addSubview:textView ];
      [self addSubview: scrollView];
      [self addSubview: scrollViewText];
      // RELEASE(scrollView); 
    }
      return self;
  
}

- (void)activateForPath:(NSString *)path
{
  //Verify path
  if (path == nil)
    { 
      NSLog(@" - (void)activateForPath:(NSString *)path : path == nil");
      return; 
    }
  
  plistDict = [[NSString stringWithContentsOfFile: path] propertyList];
  [plistDict retain];
  keysArray = [[plistDict allKeys] retain];
  valueArray = [[plistDict allValues] retain];
  [outlineView reloadData];
}

- (void)deactivate
{
  [self removeFromSuperview];
}

- (BOOL)canDisplayFileAtPath:(NSString *)path
{
  NSDictionary *attributes;
  NSString *defApp, *fileType, *extension;
  int i;
  
  attributes = [[NSFileManager defaultManager] fileAttributesAtPath: path
                                                       traverseLink: YES];
  if ([attributes objectForKey: NSFileType] == NSFileTypeDirectory) {
    return NO;
  }		
 
  [workspace getInfoForFile: path application: &defApp type: &fileType];
  extension = [path pathExtension];
  
  if(([fileType isEqual: NSPlainFileType] == NO)
                  && ([fileType isEqual: NSShellCommandFileType] == NO)) {
    return NO;
  }
  
  for(i = 0; i < [extsarr count]; i++) {
    if([[extsarr objectAtIndex: i] isEqualToString: extension]) {
      return YES;
    }
  }

  return NO;
}

- (void)setBundlePath:(NSString *)path
{
  ASSIGN (bundlePath, path);
}

- (NSString *)bundlePath
{
  return bundlePath;
}

- (void)setIndex:(int)idx
{
  index = idx;
}

- (BOOL)stopTasks
{
  return YES;
}


- (int)index
{
  return index;
}

- (NSString *)winname
{
  return NSLocalizedString(@"Property List Inspector", @"");	
}




- (void)editFile:(id)sender
{
	NSString *appName;
  NSString *type;

  [[NSWorkspace sharedWorkspace] getInfoForFile: editPath application: &appName type: &type];
  
  if (appName != nil) {
    [workspace openFile: editPath withApplication: appName];
  }
}

//
// Outline Data Source 
//
- (id) outlineView: (NSOutlineView *) outlineView
	     child: (int) idx
	    ofItem: (id) item
{
  

  if ( !item ) 
    {
      NSLog(@"----> != item");
      return [keysArray objectAtIndex:idx];
    }
  else 
    {
      return [plistDict objectForKey: [keysArray objectAtIndex:idx]];
    }
}


- (BOOL) outlineView: (NSOutlineView *) outlineView
    isItemExpandable: (id) item
{
    return YES;
}

- (int)        outlineView: (NSOutlineView *) outlineView 
    numberOfChildrenOfItem: (id) item
{
  if ( !item )
    {
      return  [keysArray count];
    }
  else 
    {
      return 0;
    }

}

- (id)         outlineView: (NSOutlineView *) outlineView 
 objectValueForTableColumn: (NSTableColumn *) tableColumn 
		    byItem: (id) item
{
  if ( !item ) 
    {
      return @"plopplop";
    }
  else 
    {
      return item;
    }
}

- (void) outlineViewSelectionIsChanging: (NSNotification *) aNotification
{
   int row = [outlineView selectedRow];
   if ( [[plistDict objectForKey: [keysArray objectAtIndex:row]] isKindOfClass: [NSString class]] )
     [textView setString : [plistDict objectForKey:[keysArray objectAtIndex:row]]];
   [textView display];
}

@end







