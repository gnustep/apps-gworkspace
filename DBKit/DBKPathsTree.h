/* DBKPathsTree.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: December 2005
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#ifndef DBK_PATHS_TREE_H
#define DBK_PATHS_TREE_H

#include <Foundation/Foundation.h>

#define MAX_PATH_DEEP 256

typedef struct _pcomp
{
  id name;
  struct _pcomp **subcomps;
  unsigned sub_count;
  unsigned capacity;
  struct _pcomp *parent;
  int ins_count;
  unsigned last_path_comp;
} pcomp;


@interface DBKPathsTree: NSObject 
{
  pcomp *tree;
  id identifier;
}

- (id)initWithIdentifier:(id)ident;

- (id)identifier;

- (void)insertComponentsOfPath:(NSString *)path;

- (void)removeComponentsOfPath:(NSString *)path;

- (void)emptyTree;

- (BOOL)inTreeFullPath:(NSString *)path;

- (BOOL)inTreeFirstPartOfPath:(NSString *)path;

- (BOOL)containsElementsOfPath:(NSString *)path;

- (NSArray *)paths;

@end


pcomp *newTreeWithIdentifier(id identifier);

pcomp *compInsertingName(NSString *name, pcomp *parent);

pcomp *subcompWithName(NSString *name, pcomp *parent);

void removeSubcomp(pcomp *comp, pcomp *parent);

void insertComponentsOfPath(NSString *path, pcomp *base);

void removeComponentsOfPath(NSString *path, pcomp *base);

void emptyTreeWithBase(pcomp *base);

void freeTree(pcomp *base);

void freeComp(pcomp *comp);

BOOL fullPathInTree(NSString *path, pcomp *base);

BOOL inTreeFirstPartOfPath(NSString *path, pcomp *base);

BOOL containsElementsOfPath(NSString *path, pcomp *base);

NSArray *pathsOfTreeWithBase(pcomp *base);

void appendComponentToArray(pcomp *comp, NSString *path, NSMutableArray *paths);

unsigned deepOfComponent(pcomp *comp);

#endif // DBK_PATHS_TREE_H



