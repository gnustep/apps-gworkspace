/*  -*-objc-*-
 *  InspectorViewer.m:
 *
 *  Copyright (c) 2002 Fabien Vallon <fabien.vallon@fr.alcove.com>
 *                     Alcove <http://www.alcove.com>             
 *
 *  Author: Fabien VALLON
 *  Date: July 2002
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
#include "GNUstep.h"
#include "InspectorViewer.h"

  #ifdef GNUSTEP 
#include "GWLib.h"
  #else
#include <GWorkspace/GWLib.h>
  #endif

@implementation InspectorViewer

- (void)dealloc
{
  TEST_RELEASE(textName);
  TEST_RELEASE(textVersion);
  TEST_RELEASE(textStatus);
  TEST_RELEASE(textDescription);
  TEST_RELEASE(errorLabel);
  RELEASE(extsarr);
  
  [super dealloc];
}


- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
  self = [super init];
  if(self) {
    NSTextField *labelVersion,*labelStatus,*labelIntroduction;
    NSString *suffs = @"inspector";
    index = idx;
    extsarr = [[NSArray alloc] initWithArray: [suffs componentsSeparatedByString:@", "]];
    workspace = [NSWorkspace sharedWorkspace];

    textName=[[NSTextField alloc] initWithFrame: NSMakeRect(0,220,250,20)];
    [textName setEditable : NO];
    [textName setSelectable : NO];
    [textName setFont:[NSFont systemFontOfSize: 18]];
    [textName setAlignment: NSCenterTextAlignment];
    [textName setBackgroundColor : [NSColor windowBackgroundColor]];
    [textName setBezeled: NO];
    
    labelIntroduction = [[NSTextField alloc] initWithFrame: NSMakeRect(0,190,250,20)];
    [labelIntroduction setEditable : NO];
    [labelIntroduction setSelectable : NO];
    [labelIntroduction setAlignment:NSCenterTextAlignment];
    [labelIntroduction setTextColor: [NSColor grayColor]];	
    [labelIntroduction setStringValue: _(@"This is a GWorkspace bundle")];
    [labelIntroduction setBackgroundColor : [NSColor windowBackgroundColor]];
    [labelIntroduction setBezeled: NO];

    textDescription=[[NSTextView alloc] initWithFrame: NSMakeRect(0,150,250,30)];
    [textDescription setBackgroundColor :[NSColor windowBackgroundColor]];

    labelStatus = [[NSTextField alloc] initWithFrame: NSMakeRect(0,45,60,20)];
    [labelStatus setEditable : NO];
    [labelStatus setSelectable : NO];
    [labelStatus setAlignment:NSLeftTextAlignment];
    [labelStatus setStringValue: _(@"Status: ")];
    [labelStatus setBackgroundColor : [NSColor windowBackgroundColor]];
    [labelStatus setBezeled: NO];

    textStatus=[[NSTextField alloc] initWithFrame: NSMakeRect(65,45,185,20)];
    [textStatus setEditable : NO];
    [textStatus setSelectable : NO];
    [textStatus setBackgroundColor : [NSColor windowBackgroundColor]];
    [textStatus setAlignment: NSLeftTextAlignment];
    [textStatus setBezeled: NO];

    labelVersion = [[NSTextField alloc] initWithFrame: NSMakeRect(0,20,60,20)];
    [labelVersion setEditable : NO];
    [labelVersion setSelectable : NO];
    [labelVersion setAlignment:NSLeftTextAlignment];
    [labelVersion setStringValue: _(@"Release: ")];
    [labelVersion setBackgroundColor : [NSColor windowBackgroundColor]];
    [labelVersion setBezeled: NO];

    textVersion=[[NSTextField alloc] initWithFrame: NSMakeRect(65,20,185,20)];
    [textVersion setEditable : NO];
    [textVersion setSelectable : NO];
    [textVersion setBackgroundColor : [NSColor windowBackgroundColor]];
    [textVersion setAlignment: NSLeftTextAlignment];
    [textVersion setBezeled: NO];

    [self addSubview: textName];
    [self addSubview:labelIntroduction];
    [self addSubview: textDescription];
    [self addSubview: labelStatus];
    [self addSubview: textStatus];
    [self addSubview: labelVersion];
    [self addSubview: textVersion];


    //label if error
    errorLabel = [[NSTextField alloc] initWithFrame: NSMakeRect(0, 0, 250, 240)];	
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
  NSBundle *bundle;
  NSString *plistpath; 
  NSString *infos;
  NSDictionary  *inspectorInfo;
  
  //TODO check if path exists
  if (path == nil) {
    NSLog(@" activateForPath:(NSString *)path : path nil"); 
    return;
  }
  
  bundle = [NSBundle bundleWithPath: path];
  
  if (bundle == nil ) {
    NSLog(@"- (void)activateForPath:(NSString *)path Bundle nil");
    [self _displayError:_(@"This is not a valid Path")]; 
    return;			
  }
   
  plistpath=[bundle pathForResource:@"InspectorInfo" ofType:@"plist"];
  
  //TODO Exception : Not valid ... NSParseErrorException
  NS_DURING
    {
      inspectorInfo  = [[NSString stringWithContentsOfFile: plistpath]
			 propertyList];
    }
  NS_HANDLER
    {
      [self _displayError:_(@"The information is not valid")]; 
      return;			
    }
  NS_ENDHANDLER


   [inspectorInfo retain];

  if (inspectorInfo == nil) {
    NSLog(@"InspectorViewer- (void)activateForPath:(NSString *)path : InspectorInfo empty"); 
    [self _displayError:_(@"No description available")];
    return;			
  }

  infos=[inspectorInfo objectForKey: @"InspectorName"];
  if (infos == nil) 
    [textName setStringValue:_(@"N/A")];
  else
    [textName setStringValue:infos];

  infos=[inspectorInfo objectForKey: @"InspectorDescription"];
  if (infos == nil) 
    [textDescription setString:_(@"N/A")];
  else
    [textDescription  setString:infos];

  infos=[inspectorInfo objectForKey: @"InspectorRelease"];
  if (infos == nil) 
    [textVersion setStringValue:_(@"N/A")];
  else
    [textVersion setStringValue: infos];
  
  if ( [self _isInstalled:path] ) 
    [textStatus setStringValue: _(@"Installed")];
  else 
    [textStatus setStringValue: _(@"Not Installed")];


  if (  [errorLabel superview] )
    { 
      [errorLabel removeFromSuperview];
    }

  RELEASE(inspectorInfo);
  [self display];
}

- (void)deactivate
{
  [self removeFromSuperview];
}

- (BOOL)canDisplayFileAtPath:(NSString *)path
{
  NSString *defApp, *fileType, *extension;
  
  [workspace getInfoForFile: path application: &defApp type: &fileType];
  extension = [path pathExtension];

//  if([fileType isEqual: NSPlainFileType] == YES) {
//    return NO;
//  }

  if ([extsarr containsObject: extension]) {
    return YES;
  }

  return NO;
}

- (int)index
{
  return index;
}

- (BOOL)stopTasks
{
  return YES;
}


- (NSString *)winname
{
  return NSLocalizedString(@"Inspector Inspector",@"");
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

-(BOOL) _isInstalled:(NSString *) path
{
  return YES;
}
@end
