/* SQLite.h
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
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

#ifndef SQLITE_CLIENT_H
#define SQLITE_CLIENT_H

#include <Foundation/Foundation.h>
#include <sqlite3.h>

sqlite3 *opendbAtPath(NSString *dbpath);

void closedb(sqlite3 *db);

BOOL createDatabaseWithTable(sqlite3 *db, NSDictionary *table);

NSArray *performQueryOnDb(sqlite3 *db, NSString *query);

BOOL performWriteQueryOnDb(sqlite3 *db, NSString *query);

BOOL checkPathInDb(sqlite3 *db, NSString *path);

NSString *blobFromData(NSData *data);

void decodeBlobUnit(unsigned char *unit, const char *src);

NSData *dataFromBlob(const char *blob);

NSString *stringForQuery(NSString *str);

#endif // SQLITE_CLIENT_H
