/* Attributes.h
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


#ifndef ATTRIBUTES_H
#define ATTRIBUTES_H

#include <Foundation/Foundation.h>
  #ifdef GNUSTEP 
#include "InspectorsProtocol.h"
  #else
#include <GWorkspace/InspectorsProtocol.h>
  #endif

@class NSTextField;
@class NSButton;
@class NSImage;
@class TimeDateView;

@interface Attributes : NSObject <InspectorsProtocol>
{
  IBOutlet id win;
  IBOutlet id inspBox;

  IBOutlet id linkToLabel;
  IBOutlet id linkToField;
  IBOutlet id sizeField;
  IBOutlet id ownerField;
  IBOutlet id groupField;

  IBOutlet id calculateButt;

  IBOutlet id permsBox;

  IBOutlet id ureadbutt;
  IBOutlet id uwritebutt;
  IBOutlet id uexebutt;
  IBOutlet id greadbutt;
  IBOutlet id gwritebutt;
  IBOutlet id gexebutt;
  IBOutlet id oreadbutt;
  IBOutlet id owritebutt;
  IBOutlet id oexebutt; 

  IBOutlet id changedDateBox;

  IBOutlet id revertButt;
  IBOutlet id okButt;

	NSArray *insppaths;
	int pathscount;
  
	NSDictionary *attributes;
	BOOL iamRoot, isMyFile;
	NSImage *onImage, *offImage, *multipleImage;
	BOOL multiplePaths;
    
	NSString *currentPath;	
  
	TimeDateView *timeDateView;
	NSTextField *yearlabel;
  
	NSString *localizedStr;
	id fm;
}

- (IBAction)computeSize:(id)sender;

- (IBAction)permsButtonsAction:(id)sender;

- (IBAction)changePermissions:(id)sender;

- (IBAction)revertToOldPermissions:(id)sender;

- (void)setPermissions:(int)perms isActive:(BOOL)active;

- (int)getPermissions:(int)oldperms;

@end

#endif // ATTRIBUTES_H
