 /*
 *  InspectorsController.h: Interface and declarations for the 
 *  InspectorsController Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
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
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifndef INSPECTORS_CONTROLLER_H
#define INSPECTORS_CONTROLLER_H

#include <Foundation/Foundation.h>

@class NSMutableArray;

@interface InspectorsController : NSObject
{
  IBOutlet id win;
  IBOutlet id topBox;
  IBOutlet id popUp;
  IBOutlet id middleBox;
  IBOutlet id iconView;
  IBOutlet id nameField;
  IBOutlet id pathField;
  IBOutlet id lowBox;

	NSArray *currentPaths;
	NSMutableArray *inspectors;
	id currentInspector;
}

- (id)initForPaths:(NSArray *)paths;

- (void)setPaths:(NSArray *)paths;

- (IBAction)activateInspector:(id)sender;

- (void)showAttributes;

- (void)showContents;

- (void)showTools;

- (void)showPermissions;

- (NSArray *)currentPaths;

- (void)updateDefaults;

- (id)myWin;

@end

#endif // INSPECTORS_CONTROLLER_H
