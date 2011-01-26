/* DBKPathsTree.m
 *  
 * Copyright (C) 2005-2011 Free Software Foundation, Inc.
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

#import "DBKPathsTree.h"

#define GROW_FACTOR 32

static SEL pathCompsSel = NULL;
static IMP pathCompsImp = NULL;

typedef int (*intIMP)(id, SEL, id);
static SEL pathCompareSel = NULL;
static intIMP pathCompareImp = NULL;

@implementation DBKPathsTree

- (void)dealloc
{
  freeTree(tree);
  RELEASE (identifier);

  [super dealloc];
}

- (id)initWithIdentifier:(id)ident
{
  self = [super init];
  
  if (self) {
    ASSIGN (identifier, ident);
    tree = newTreeWithIdentifier(identifier);
  }
  
  return self;
}

- (id)identifier
{
  return identifier;
}

- (NSUInteger)hash
{
  return [identifier hash];
}

- (BOOL)isEqual:(id)other
{
  if (other == self) {
    return YES;
  }
  if ([other isKindOfClass: [DBKPathsTree class]]) {
    return [identifier isEqual: [other identifier]];
  }
  return NO;
}

- (void)insertComponentsOfPath:(NSString *)path
{
  insertComponentsOfPath(path, tree);
}

- (void)removeComponentsOfPath:(NSString *)path
{
  removeComponentsOfPath(path, tree);
}

- (void)emptyTree
{
  emptyTreeWithBase(tree);
}

- (BOOL)inTreeFullPath:(NSString *)path
{
  return fullPathInTree(path, tree);
}

- (BOOL)inTreeFirstPartOfPath:(NSString *)path
{
  return inTreeFirstPartOfPath(path, tree);
}

- (BOOL)containsElementsOfPath:(NSString *)path
{
  return containsElementsOfPath(path, tree);
}

- (NSArray *)paths
{
  return pathsOfTreeWithBase(tree);
}

@end


pcomp *newTreeWithIdentifier(id identifier)
{
  if (identifier) {
    pcomp *comp = NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(pcomp));

    comp->name = [identifier retain];
    comp->subcomps = NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(pcomp *)); 
    comp->sub_count = 0;  
    comp->capacity = 0;
    comp->parent = NULL;
    comp->ins_count = 1;  
    comp->last_path_comp = 0;  

    if (pathCompsSel == NULL) {
      pathCompsSel = @selector(pathComponents);
    }  
    if (pathCompsImp == NULL) {
      pathCompsImp = [NSString instanceMethodForSelector: pathCompsSel];
    }

    if (pathCompareSel == NULL) {
      pathCompareSel = @selector(compare:);
    }  
    if (pathCompareImp == NULL) {
      pathCompareImp = (intIMP)[NSString instanceMethodForSelector: pathCompareSel];
    }
  
    return comp;
  }
  
  return NULL;
}

pcomp *compInsertingName(NSString *name, pcomp *parent)
{
  unsigned ins = 0;  
  unsigned i;

  if (parent->sub_count) {
    unsigned first = 0;
    unsigned last = parent->sub_count;
    unsigned pos = 0; 
    NSComparisonResult result;
    
    while (1) {
      if (first == last) {
        ins = first;
        break;
      }
      
      pos = (first + last) / 2;
      result = (*pathCompareImp)(parent->subcomps[pos]->name, pathCompareSel, name);

      if (result == NSOrderedSame) {
        parent->subcomps[pos]->ins_count++;
        return parent->subcomps[pos];
          
      } else if (result == NSOrderedAscending) { 
        first = pos + 1;
      } else {
        last = pos;	
      }
    }
  }

  if ((parent->sub_count + 1) > parent->capacity) {
    size_t size;
    pcomp **ptr;
    
    parent->capacity += GROW_FACTOR;
    size = parent->capacity * sizeof(pcomp *);
    
    ptr = NSZoneRealloc(NSDefaultMallocZone(), parent->subcomps, size);
    
    if (ptr == 0) {
	    [NSException raise: NSMallocException format: @"Unable to grow tree"];
	  } 
    
    parent->subcomps = ptr;
  }

  for (i = parent->sub_count; i > ins; i--) {
    parent->subcomps[i] = parent->subcomps[i - 1];
  }

  parent->sub_count++;
    
  parent->subcomps[ins] = NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(pcomp));
  parent->subcomps[ins]->name = [[NSString alloc] initWithString: name];
  parent->subcomps[ins]->subcomps = NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(pcomp *)); 
  parent->subcomps[ins]->sub_count = 0;  
  parent->subcomps[ins]->capacity = 0;
  parent->subcomps[ins]->parent = parent;
  parent->subcomps[ins]->ins_count = 1;  
  parent->subcomps[ins]->last_path_comp = 0;  
  
  return parent->subcomps[ins];
}

pcomp *subcompWithName(NSString *name, pcomp *parent)
{
  if (parent->sub_count) {
    unsigned first = 0;
    unsigned last = parent->sub_count;
    unsigned pos = 0; 
    NSComparisonResult result;
    
    while (1) {
      if (first == last) {
        break;
      }
      
      pos = (first + last) / 2;
      result = (*pathCompareImp)(parent->subcomps[pos]->name, pathCompareSel, name);

      if (result == NSOrderedSame) {
        return parent->subcomps[pos];
      } else if (result == NSOrderedAscending) { 
        first = pos + 1;
      } else {
        last = pos;	
      }
    }
  }
  
  return NULL;
}

void removeSubcomp(pcomp *comp, pcomp *parent)
{
  unsigned i, j;

  for (i = 0; i < parent->sub_count; i++) {
    if (parent->subcomps[i] == comp) {
      freeComp(parent->subcomps[i]);
      
      for (j = i; j < (parent->sub_count - 1); j++) {
        parent->subcomps[j] = parent->subcomps[j + 1];
      }
      
      parent->sub_count--;
      break;
    }
  }
}

void insertComponentsOfPath(NSString *path, pcomp *base)
{
  NSArray *components = (*pathCompsImp)(path, pathCompsSel);
  pcomp *comp = base;
  unsigned i;

  for (i = 0; i < [components count]; i++) {
    comp = compInsertingName([components objectAtIndex: i], comp);
  }
  
  comp->last_path_comp = 1;
}

void removeComponentsOfPath(NSString *path, pcomp *base)
{
  NSArray *components = (*pathCompsImp)(path, pathCompsSel);
  unsigned compcount = [components count];  
  pcomp *comp = base;
  pcomp *comps[MAX_PATH_DEEP];
  unsigned count = 0;  
  int i;

  for (i = 0; i < compcount; i++) {
    comp = subcompWithName([components objectAtIndex: i], comp);
    
    if (comp) {
      comp->ins_count--;
      if (i == (compcount -1)) {
        comp->last_path_comp = 0;
      }
      comps[count] = comp;
      count++;
      
    } else {
      break;
    }
  }
  
  for (i = count - 1; i >= 0; i--) {  
    if ((comps[i]->sub_count == 0) && (comps[i]->ins_count <= 0)) {
      removeSubcomp(comps[i], comps[i]->parent);
    }
  }
}

void emptyTreeWithBase(pcomp *base)
{
  unsigned i;
  
  for (i = 0; i < base->sub_count; i++) {
    emptyTreeWithBase(base->subcomps[i]);
  }
    
  if (base->parent) {
    for (i = 0; i < base->parent->sub_count; i++) {
      if (base->parent->subcomps[i] == base) {
        base->parent->sub_count--;
        freeComp(base->parent->subcomps[i]);
        break;
      }
    }   
    
  } else {    
    NSZoneFree(NSDefaultMallocZone(), base->subcomps);
    base->subcomps = NSZoneCalloc(NSDefaultMallocZone(), GROW_FACTOR, sizeof(pcomp *)); 
    base->capacity = GROW_FACTOR;
    base->sub_count = 0;
  }
}

void freeTree(pcomp *base)
{
  unsigned i;
  
  for (i = 0; i < base->sub_count; i++) {
    emptyTreeWithBase(base->subcomps[i]);
  }
  
  if (base->parent) {
    for (i = 0; i < base->parent->sub_count; i++) {
      if (base->parent->subcomps[i] == base) {
        base->parent->sub_count--;
        freeComp(base->parent->subcomps[i]);
        break;
      }
    }   
    
  } else {  
    freeComp(base);  
  }
}

void freeComp(pcomp *comp)
{
  DESTROY (comp->name);
  NSZoneFree(NSDefaultMallocZone(), comp->subcomps);
  NSZoneFree(NSDefaultMallocZone(), comp);
}

/*
  This verifies if the full path has been inserted in the tree.
*/
BOOL fullPathInTree(NSString *path, pcomp *base)
{
  NSArray *components = (*pathCompsImp)(path, pathCompsSel);
  pcomp *comp = base;
  unsigned count = [components count]; 
  unsigned i;
  
  for (i = 0; i < count; i++) {
    comp = subcompWithName([components objectAtIndex: i], comp);

    if (comp == NULL) {
      break;
    } else if ((i == (count -1)) && (comp->last_path_comp == 1)) {
      return YES;
    }
  }
  
  return NO;
}

/*
  This verifies if the first part of a path has been inserted in the tree.
  It can be used to filter events happened deeper than the inserted path;
  that is, if the first part exists in the three, this means that also
  the entire path is allowed or denied.
*/
BOOL inTreeFirstPartOfPath(NSString *path, pcomp *base)
{
  NSArray *components = (*pathCompsImp)(path, pathCompsSel);
  pcomp *comp = base;
  unsigned count = [components count]; 
  unsigned i;
  
  for (i = 0; i < count; i++) {
    comp = subcompWithName([components objectAtIndex: i], comp);

    if (comp == NULL) {
      break;
    } else if (comp->sub_count == 0) {
      return YES;
    }
  }
  
  return NO;
}

/*
  This verifies if the tree contains all the elements of the path,
*/
BOOL containsElementsOfPath(NSString *path, pcomp *base)
{
  NSArray *components = (*pathCompsImp)(path, pathCompsSel);
  pcomp *comp = base;
  unsigned count = [components count]; 
  unsigned i;
  
  for (i = 0; i < count; i++) {
    comp = subcompWithName([components objectAtIndex: i], comp);

    if (comp == NULL) {
      return NO;
    } 
  }
  
  return YES;
}

NSArray *pathsOfTreeWithBase(pcomp *base)
{
  NSMutableArray *paths = [NSMutableArray array];
  
  if ((base->parent == NULL) && (base->sub_count == 1)) {
    base = base->subcomps[0];
  }
  
  appendComponentToArray(base, nil, paths);
  
  return (([paths count] > 0) ? [paths makeImmutableCopyOnFail: NO] : nil);
}

void appendComponentToArray(pcomp *comp, NSString *path, NSMutableArray *paths)
{
  if (path == nil) {
    path = [NSString stringWithString: comp->name];
  } else {
    path = [path stringByAppendingPathComponent: comp->name];
  }
  
  if (comp->last_path_comp) {
    [paths addObject: path];
  }
    
  if (comp->sub_count) {
    unsigned i;
    
    for (i = 0; i < comp->sub_count; i++) {
      appendComponentToArray(comp->subcomps[i], path, paths);
    }
  } 
}

unsigned deepOfComponent(pcomp *comp)
{
  if (comp->parent != NULL) {
    return (1 + deepOfComponent(comp->parent));
  }
  
  return 0;
}














