 /*
 *  Banner.h: Interface and declarations for the Banner 
 *  Class of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2002 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: February 2002
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

#ifndef BANNER_H
#define BANNER_H

#include <AppKit/NSView.h>

@class NSDictionary;
@class NSTextField;
@class PathsPopUp;
@class Banner;

@interface FOpIndicator : NSObject 
{
  NSString *operation;
  NSString *statusStr;
  NSTimer *timer;
  Banner *banner;
  BOOL valid;
}

- (id)initForBanner:(Banner *)abanner operationName:(NSString *)opname;

- (void)update:(id)sender;

- (NSString *)operation;

- (void)invalidate;

- (BOOL)isValid;

@end

@interface Banner : NSView 
{
	PathsPopUp *pathsPopUp;
	NSTextField *leftLabel;
	NSTextField *rightLabel;
  NSMutableArray *indicators;   
}

- (void)updateInfo:(NSString *)infoString;

- (PathsPopUp *)pathsPopUp;

- (void)updateRightLabel:(NSString *)info;

- (void)startIndicatorForOperation:(NSString *)operation;

- (void)stopIndicatorForOperation:(NSString *)operation;

- (FOpIndicator *)firstIndicatorForOperation:(NSString *)operation;

@end

#endif // BANNER_H

