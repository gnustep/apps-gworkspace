/* FSNIconContainer.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: March 2004
 *
 * This file is part of the GNUstep FSNode framework
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
#include <math.h>
#include "FSNIconContainer.h"
#include "FSNIcon.h"
#include "FSNFunctions.h"
#include "GNUstep.h"

#define DEF_ICN_SIZE 48
#define DEF_TEXT_SIZE 12
#define DEF_ICN_POS NSImageAbove

#define LABEL_W_FACT (8)

#define X_MARGIN (10)
#define Y_MARGIN (12)

#define EDIT_MARGIN (4)

#ifndef max
  #define max(a,b) ((a) >= (b) ? (a):(b))
#endif

#ifndef min
  #define min(a,b) ((a) <= (b) ? (a):(b))
#endif

#define CHECK_SIZE(s) \
if (s.width < 1) s.width = 1; \
if (s.height < 1) s.height = 1; \
if (s.width > maxr.size.width) s.width = maxr.size.width; \
if (s.height > maxr.size.height) s.height = maxr.size.height


@implementation FSNIconContainer

- (void)dealloc
{
  TEST_RELEASE (node);
  TEST_RELEASE (infoPath);
  TEST_RELEASE (nodeInfo);
  RELEASE (icons);
  RELEASE (nameEditor);
  RELEASE (horizontalImage);
  RELEASE (verticalImage);
  TEST_RELEASE (lastSelection);
  RELEASE (backColor);

  [super dealloc];
}

- (id)init
{
  self = [super init];
    
  if (self) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
    id defentry;

    defentry = [defaults dictionaryForKey: @"backcolor"];
    if (defentry) {
      float red = [[defentry objectForKey: @"red"] floatValue];
      float green = [[defentry objectForKey: @"green"] floatValue];
      float blue = [[defentry objectForKey: @"blue"] floatValue];
      float alpha = [[defentry objectForKey: @"alpha"] floatValue];
    
      ASSIGN (backColor, [NSColor colorWithCalibratedRed: red 
                                                   green: green 
                                                    blue: blue 
                                                   alpha: alpha]);
    } else {
      ASSIGN (backColor, [NSColor windowBackgroundColor]);
    }

    defentry = [defaults objectForKey: @"iconsize"];
    iconSize = defentry ? [defentry intValue] : DEF_ICN_SIZE;
    [FSNIcon setLabelFont: [NSFont systemFontOfSize: iconSize]];

    defentry = [defaults objectForKey: @"labeltxtsize"];
    labelTextSize = defentry ? [defentry intValue] : DEF_TEXT_SIZE;
    
    defentry = [defaults objectForKey: @"iconposition"];
    iconPosition = defentry ? [defentry intValue] : DEF_ICN_POS;
        
    defentry = [defaults objectForKey: @"fsn_info_type"];
    infoType = defentry ? [defentry intValue] : FSNInfoNameType;

    [FSNodeRep setUseThumbnails: [defaults boolForKey: @"use_thumbnails"]];
    
    icons = [NSMutableArray new];
        
    nameEditor = [FSNIconNameEditor new];
    [nameEditor setDelegate: self];  
		[nameEditor setFont: [FSNIcon labelFont]];
		[nameEditor setBezeled: NO];
		[nameEditor setAlignment: NSCenterTextAlignment];
	  [nameEditor setBackgroundColor: backColor];
    editIcon = nil;
    
    isDragTarget = NO;
    
    [self registerForDraggedTypes: [NSArray arrayWithObjects: 
                                                NSFilenamesPboardType, 
                                                @"GWRemoteFilenamesPboardType", 
                                                nil]];    

    selectionMask = NSSingleSelectionMask;
  }
   
  return self;
}

- (void)tile
{

}






- (void)resizeWithOldSuperviewSize:(NSSize)oldFrameSize
{
  [self tile];
}

@end
























