/* dbversion.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2004
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

#ifndef DB_VERSION_H
#define DB_VERSION_H

#include <Foundation/Foundation.h>

static int dbversion = 2;

static NSString *deftable = @"\
{ \
tablename = files; \
fields = ( \
{ \
name = path; \
type = TEXT; \
}, \
{ \
name = type; \
type = TEXT; \
}, \
{ \
name = moddate; \
type = TEXT;\
}, \
{ \
name = annotations; \
type = TEXT; \
}, \
{ \
name = icon; \
type = BLOB; \
} \
); \
indexes = ( \
{ \
name = path_ind; \
fields = path; \
unique = 0; \
} \
); \
}";

#endif // DB_VERSION_H
