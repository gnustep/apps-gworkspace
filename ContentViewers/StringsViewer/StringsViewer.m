/*  -*-objc-*-
 *  StringsViewer.m: Implementation of the StringViewer Class 
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
#include "StringsViewer.h"
#include "StringsFile.h"
#include "StringsEntry.h"
#include "GNUstep.h"

  #ifdef GNUSTEP 
#include "GWLib.h"
  #else
#include <GWorkspace/GWLib.h>
  #endif

@implementation StringsViewer

- (void)dealloc
{
  RELEASE (extsarr);
  RELEASE(tableView);
  RELEASE(stringsArray);
  RELEASE (textView);
  [super dealloc];
}
    

- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
  self = [super init];
  
  if(self) 
    {
      NSTableColumn *englishColumn;
      NSString *suffs = @"strings";
      NSScrollView *scrollView;
      [self setFrame: frame];
      stringsArray = [[NSMutableArray alloc] retain] ;
      //      panel = (id<InspectorsProtocol>)apanel;
      workspace = [NSWorkspace sharedWorkspace];
      index = idx;
      extsarr = [[NSArray alloc] initWithArray: [suffs componentsSeparatedByString:@", "]];

      englishColumn = [[NSTableColumn alloc] initWithIdentifier: @"englishColumn"];
      [englishColumn setEditable: NO];
      [[englishColumn headerCell] setStringValue: _(@"English")];
      [englishColumn setMinWidth: 100];

      
      tableView = [[NSTableView alloc] initWithFrame: NSMakeRect(0,55,250,190)];
      [tableView addTableColumn: englishColumn];
      [tableView setDrawsGrid: YES];

      [tableView setDelegate:self];
      
      scrollView = [[NSScrollView alloc] initWithFrame: NSMakeRect(0,55,250,190)];
      [scrollView setBorderType: NSBezelBorder];
      [scrollView setHasVerticalScroller : YES];
      [scrollView setHasHorizontalScroller : YES];
      [scrollView setDocumentView: tableView];

      textView = [[NSTextView alloc] initWithFrame : NSMakeRect(0,5,250,50)];
      [[textView textContainer] setContainerSize: NSMakeSize (250,45)];
      [[textView textContainer] setWidthTracksTextView: YES];
      
      [self addSubview:textView ];
      [self addSubview: scrollView];
      RELEASE(scrollView); 

      //label if error
      errorLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 250, 250)];	
      [errorLabel setFont: [NSFont systemFontOfSize: 18]];
      [errorLabel setAlignment: NSCenterTextAlignment];
      [errorLabel setBackgroundColor: [NSColor windowBackgroundColor]];
      [errorLabel setTextColor: [NSColor grayColor]];	
      [errorLabel setBezeled: NO];
      [errorLabel setEditable: NO];
      [errorLabel setSelectable: NO];

      
    }
  return self;
  
}

- (void)activateForPath:(NSString *)path
{
  NSLog(@"activate for path");
  //Verify path
  if (path == nil)
    { 
      NSLog(@" - (void)activateForPath:(NSString *)path : path == nil");
      return; 
    }
  else 
    {

      StringsFile *stringFile;
      NSLog(@" Miaou");
      stringsArray = nil;
      
      NS_DURING
	{
	  stringFile = [[StringsFile alloc] initWithFile:path];
	}
      NS_HANDLER
	{
	  [self _displayError:_(@"The file is not valid")]; 
	  return;			
	}
      NS_ENDHANDLER
	
	
      NS_DURING
	{
	  stringsArray = [stringFile strings];
	}
      NS_HANDLER
	{
	  [self _displayError:_(@"The file is not valid")]; 
	  return;			
	}
      NS_ENDHANDLER
   }
  

  NSLog(@"change");
  if (  [errorLabel superview] )
    { 
      NSLog(@"and ??");
      [errorLabel removeFromSuperview];  
    }

  [tableView setDataSource:self];
  [tableView reloadData];
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

- (int)index
{
  return index;
}

-(void) setIndex:(int) idx
{
  index = idx;
}

- (void)setBundlePath:(NSString *)path
{
  ASSIGN (bundlePath, path);
}

- (NSString *)bundlePath
{
  return bundlePath;
}

-(BOOL) stopTasks
{
  return YES;
}

- (NSString *)winname
{
  return NSLocalizedString(@"Localize  Inspector", @"");	
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

-(void) _displayError: (NSString *) error
{
  if ( ! [errorLabel superview] )
    {
      [self addSubview: errorLabel];
    }
  [errorLabel setStringValue: error];
  [buttOk setEnabled: NO];
  [self display];
} 



//************************************************//
//          TableView delegate & DataSource       //
//*************************************************//


- (int) numberOfRowsInTableView: (NSTableView *) aView
{
//  NSDebugLog(@"StringsViewer - (int) numberOfRowsInTableView: (NSTableView *) aView");
  if ( aView ==  tableView )
    {
      return [stringsArray count];
    }
  else
    return 0;

}// End: numberOfRowsInTableView: 



- (id) tableView: (NSTableView *) aView
           objectValueForTableColumn: (NSTableColumn *) aColumn
           row: (int) row
{
//  NSDebugLog(@"- (id) tableView: (NSTableView *) aView 
// objectValueForTableColumn: (NSTableColumn *) aColumn row: (int) row");

  if ( aView ==  tableView )
    {
      return [[stringsArray objectAtIndex:row] key];
    }
  else
    return @"BUG?";
}

-(BOOL) tableView: (NSTableView *) aTableView 
         shouldSelectRow: (int) row
{
  return YES;
}

- (void) tableViewSelectionDidChange: (NSNotification *) not
{
//  NSDebugLog(@"StringsViewer - (void) tableViewSelectionDidChange: (NSNotification *) not");
  [textView setString: [[stringsArray objectAtIndex:[tableView selectedRow]] translated]];  
  [textView display];
}



@end







