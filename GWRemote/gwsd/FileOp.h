/* FileOp.h
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep gwsd tool
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef FILEOPERATION_H
#define FILEOPERATION_H

#include <Foundation/NSObject.h>

@class NSString;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSFileManager;
@class GWSd;

@interface LocalFileOp: NSObject
{
	NSString *operation;
	NSString *source;
	NSString *destination;
	NSMutableArray *files;
	NSMutableArray *addedFiles;
	NSMutableArray *removedFiles;
  NSMutableDictionary *operationDict;
  int fileOperationRef;
  int filescount;
  NSString *filename;
	BOOL stopped;
	BOOL paused;
  BOOL samename; 
  NSFileManager *fm;
  GWSd *gwsd;
  id gwsdClient;
}

- (id)initWithOperationDescription:(NSDictionary *)opDict
                           forGWSd:(GWSd *)gw
                        withClient:(id)client;

- (void)checkSameName;

- (void)calculateNumFiles;

- (void)performOperation;

- (void)doMove;

- (void)doCopy;

- (void)doLink;

- (void)doRemove;

- (void)doDuplicate;

- (void)removeExisting:(NSString *)fname;
                            
- (BOOL)prepareFileOperationAlert;

- (void)showProgressWinOnClient;

- (BOOL)pauseOperation;

- (BOOL)continueOperation;

- (BOOL)stopOperation;

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title;

- (int)showErrorAlertWithMessage:(NSString *)message;

- (void)endOperation;

- (int)fileOperationRef;
                 
@end

#endif // FILEOPERATION_H
