/* FSNFunctions.h
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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

#ifndef FSN_FUNCTIONS_H
#define FSN_FUNCTIONS_H

NSString *path_separator(void);

BOOL isSubpathOfPath(NSString *p1, NSString *p2);

NSString *subtractFirstPartFromPath(NSString *path, NSString *firstpart);

NSComparisonResult compareWithExtType(id r1, id r2, void *context);

NSString *sizeDescription(unsigned long long size);

NSArray *makePathsSelection(NSArray *selnodes);

double myrintf(double a);

void showAlertNoPermission(Class c, NSString *name);
void showAlertInRecycler(Class c);
void showAlertInvalidName(Class c);
NSInteger showAlertExtensionChange(Class c, NSString *extension);
void showAlertNameInUse(Class c, NSString *newname);

#endif // FSN_FUNCTIONS_H
