/*  -*-objc-*-
 *  FontViewer.m:
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
#include "FontViewer.h"
#include "GNUstep.h"

  #ifdef GNUSTEP 
#include "GWLib.h"
  #else
#include <GWorkspace/GWLib.h>
  #endif

@implementation FontViewer

- (void)dealloc
{

  TEST_RELEASE(labelDescription);
  TEST_RELEASE(errorLabel);
  TEST_RELEASE(fontText);
  RELEASE(extsarr);
  
  [super dealloc];
}


- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx
{
  self = [super init];
  if(self) {
    index = idx;
    NSString *suffs = @"nfont";
    extsarr = [[NSArray alloc] initWithArray: [suffs componentsSeparatedByString:@", "]];
    workspace = [NSWorkspace sharedWorkspace];

    labelDescription=[[NSTextField alloc] initWithFrame: NSMakeRect(0,220,250,20)];
    [labelDescription setEditable : NO];
    [labelDescription setSelectable : NO];
    [labelDescription setFont:[NSFont systemFontOfSize: 18]];
    [labelDescription setAlignment: NSCenterTextAlignment];
    [labelDescription setBackgroundColor : [NSColor windowBackgroundColor]];
    [labelDescription setBezeled: NO];
    
    fontText=[[NSTextField alloc] initWithFrame: NSMakeRect(0,10,250,200)];
    [fontText setEditable : NO];
    [fontText setSelectable : NO];



    

    [self addSubview: labelDescription];
    [self addSubview: fontText];


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
  NSString *fontdescription = [path stringByAppendingPathComponent:@"FontInfo.plist"];
  NSDictionary *plistDict = [[NSString stringWithContentsOfFile: fontdescription] propertyList];
  [plistDict retain];
  
  NSLog(@"====> %@",[plistDict objectForKey:@"Foundry"]);
  
  [labelDescription setStringValue:[plistDict objectForKey:@"Foundry"]];

  [plistDict release];
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

  if(([fileType isEqual: NSPlainFileType] == NO)
                  && ([fileType isEqual: NSShellCommandFileType] == NO)) {
    return NO;
  }

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
  return NSLocalizedString(@"Font Inspector",@"");
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

@end
