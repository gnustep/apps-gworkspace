/* Contents.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep Inspector application
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

#ifndef CONTENTS_H
#define CONTENTS_H

#include <Foundation/Foundation.h>

@interface Contents : NSObject
{
  IBOutlet id win;
  IBOutlet id mainBox;
  IBOutlet id topBox;
  IBOutlet id iconView;
  IBOutlet id titleField;
  IBOutlet id viewersBox;  

  NSMutableArray *searchPaths;
  NSString *userDir;
  NSString *disabledDir;
  
  NSView *noContsView;
  NSView *genericView;
  NSTextField *genericField;

	NSMutableArray *viewers;
  id currentViewer;
  unsigned long viewerTmpRef;
  
  NSString *currentPath;
  
  NSFileManager *fm;
	NSWorkspace *ws;
  NSNotificationCenter *nc; 
  
  id inspector;
}

- (id)initForInspector:(id)insp;

- (NSView *)inspView;

- (NSString *)winname;

- (void)activateForPaths:(NSArray *)paths;

- (BOOL)prepareToTerminate;

- (void)addViewersFromBundlePaths:(NSArray *)bundlesPaths 
                      userViewers:(BOOL)isuservwr;

- (NSMutableArray *)bundlesWithExtension:(NSString *)extension 
																	inPath:(NSString *)path;

- (void)addViewer:(id)vwr;

- (void)removeViewer:(id)vwr;

- (void)disableViewer:(id)vwr;

- (BOOL)saveExternalViewer:(id)vwr 
                  withName:(NSString *)vwrname;

- (id)viewerWithBundlePath:(NSString *)path;

- (id)viewerWithWindowName:(NSString *)wname;

- (id)viewerForPath:(NSString *)path;

- (id)viewerForDataOfType:(NSString *)type;

- (void)addExternalViewerWithBundleData:(NSData *)bundleData;

- (void)addExternalViewerWithBundlePath:(NSString *)path;

- (void)showContentsAt:(NSString *)path;

- (void)contentsReadyAt:(NSString *)path;

- (BOOL)canDisplayDataOfType:(NSString *)type;

- (void)showData:(NSData *)data 
          ofType:(NSString *)type;

- (void)dataContentsReadyForType:(NSString *)typeDescr
                         useIcon:(NSImage *)icon;

@end


@interface Contents (PackedBundles)

- (NSData *)dataRepresentationAtPath:(NSString *)path;

- (BOOL)writeDataRepresentation:(NSData *)data 
                         toPath:(NSString *)path;

- (NSString *)tempBundleName;

- (id)viewerFromPackedBundle:(NSData *)packedBundle;

@end

#endif // CONTENTS_H
