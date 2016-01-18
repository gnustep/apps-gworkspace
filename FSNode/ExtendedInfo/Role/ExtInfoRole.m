/* ExtInfoRole.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>
#import "ExtInfoRole.h"


@implementation ExtInfoRole

- (void)dealloc
{
  [super dealloc];
}

- (NSString *)menuName
{
  return NSLocalizedStringFromTableInBundle(@"Role", nil, [NSBundle bundleForClass:[self class]], @"");
}

- (NSDictionary *)extendedInfoForNode:(FSNode *)anode
{
  if ([anode isApplication]) {
    NSBundle *bundle = [NSBundle bundleWithPath: [anode path]];
    NSDictionary *info = [bundle infoDictionary];

    if (info) {
      NSString *role = [info objectForKey: @"NSRole"];

      if (role) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];

        [dict setObject: NSLocalizedStringFromTableInBundle(role, nil, [NSBundle bundleForClass:[self class]], @"")
                 forKey: @"labelstr"];
      
        return dict;
      }
    }
  }

  return nil;
}

@end
