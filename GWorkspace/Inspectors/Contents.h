/*
 *  Contents.h: Interface and declarations for the Contents Class 
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
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#ifndef CONTENTS_H
#define CONTENTS_H

#include <Foundation/Foundation.h>
  #ifdef GNUSTEP 
#include "InspectorsProtocol.h"
  #else
#include <GWorkspace/InspectorsProtocol.h>
  #endif

@class NSWiew;
@class GenericContsView;
@class GWorkspace;
@class NSFileManager;
@class NSWorkspace;

@interface Contents : NSObject <InspectorsProtocol>
{
  IBOutlet id win;
  IBOutlet id inspBox;

  IBOutlet id vwrsBox;

  IBOutlet id revertButt;
  IBOutlet id okButt;

  NSMutableArray *searchPaths;
	NSArray *insppaths;
	NSString *currentPath;	
	int pathscount;
  NSView *noContsView;
  NSView *genericView;
	GenericContsView *genericContsView;
  
	NSMutableArray *viewers;
  id currentViewer;
  GWorkspace *gw;
	NSFileManager *fm;
	NSWorkspace *ws;
	NSString *winName;
}

- (NSMutableArray *)bundlesWithExtension:(NSString *)extension 
																	inPath:(NSString *)path;

- (void)addViewer:(id)vwr;

- (void)removeViewer:(id)vwr;

- (void)watcherNotification:(NSNotification *)notification;

- (id)viewerWithBundlePath:(NSString *)path;

- (id)viewerForFileAtPath:(NSString *)path;

- (IBAction)doNothing:(id)sender;

@end

#endif // CONTENTS_H
