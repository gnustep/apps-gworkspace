/* pathutils.h
 *  
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: November 2005
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

#include <Foundation/Foundation.h>
#include "GNUstep.h"

#ifndef PATH_UTILS_H
#define PATH_UTILS_H

#ifdef IN_PATHUTILS_M
  #define	PT_SCOPE extern
#else
  #define	PT_SCOPE static inline
#endif

#define MAX_PATH_DEEP 128
#define MAX_DIR_ENTRIES 256
#define MAX_COMP_LEN 128

static SEL pathCompsSel = NULL;
static IMP pathCompsImp = NULL;

typedef struct _pcomp
{
  NSString *name;
  struct _pcomp *subcomps[MAX_DIR_ENTRIES];
  unsigned sub_count;
  struct _pcomp *parent;
  int ins_count;
} pcomp;


PT_SCOPE pcomp *newCompWithName(NSString *name)
{
  pcomp *comp = (pcomp *)malloc(sizeof(pcomp));

  comp->name = [[NSString alloc] initWithString: name];
  comp->sub_count = 0;  
  comp->parent = NULL;
  comp->ins_count = 0;  
  
  if (pathCompsSel == NULL) {
    pathCompsSel = @selector(pathComponents);
  }  
  if (pathCompsImp == NULL) {
    pathCompsImp = [NSString instanceMethodForSelector: pathCompsSel];
  }
  
  return comp;
}

PT_SCOPE pcomp *compInsertingName(NSString *name, pcomp *parent)
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
      result = [parent->subcomps[pos]->name compare: name];

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

  for (i = parent->sub_count; i > ins; i--) {
    parent->subcomps[i] = parent->subcomps[i - 1];
  }

  parent->subcomps[ins] = newCompWithName(name);
  parent->subcomps[ins]->parent = parent;
  parent->subcomps[ins]->ins_count++;
  parent->sub_count++;
  
  return parent->subcomps[ins];
}

PT_SCOPE pcomp *subcompWithName(NSString *name, pcomp *parent)
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
      result = [parent->subcomps[pos]->name compare: name];

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

PT_SCOPE void removeSubcomp(pcomp *comp, pcomp *parent)
{
  unsigned i, j;

  for (i = 0; i < parent->sub_count; i++) {
    if (parent->subcomps[i] == comp) {
      for (j = i; j < (parent->sub_count - 1); j++) {
        parent->subcomps[j] = parent->subcomps[j + 1];
      }
      
      DESTROY (parent->subcomps[parent->sub_count - 1]->name);
      free(parent->subcomps[parent->sub_count - 1]);
      parent->sub_count--;
      
      break;
    }
  }
}

PT_SCOPE void insertComponentsOfPath(NSString *path, pcomp *base)
{
  NSArray *components = (*pathCompsImp)(path, pathCompsSel);
  pcomp *comp = base;
  unsigned i;

  for (i = 0; i < [components count]; i++) {
    comp = compInsertingName([components objectAtIndex: i], comp);
  }
}

PT_SCOPE void removeComponentsOfPath(NSString *path, pcomp *base)
{
  NSArray *components = (*pathCompsImp)(path, pathCompsSel);
  pcomp *comp = base;
  pcomp *comps[MAX_PATH_DEEP];
  unsigned count = 0;  
  int i;

  for (i = 0; i < [components count]; i++) {
    comp = subcompWithName([components objectAtIndex: i], comp);
    
    if (comp) {
      comp->ins_count--;
      comps[count] = comp;
      count++;
    } else {
      break;
    }
  }
  
  for (i = count - 1; i >= 0; i--) {  
    if ((comps[i]->ins_count <= 0) && (comps[i]->sub_count == 0)) {
      removeSubcomp(comps[i], comps[i]->parent);
    }
  }
}

PT_SCOPE void emptyTreeWithBase(pcomp *comp)
{
  unsigned i;
  
  for (i = 0; i < comp->sub_count; i++) {
    emptyTreeWithBase(comp->subcomps[i]);
  }
  
  if (comp->parent) {
    for (i = 0; i < comp->parent->sub_count; i++) {
      if (comp->parent->subcomps[i] == comp) {
        DESTROY (comp->parent->subcomps[i]->name);
        free(comp->parent->subcomps[i]);
      }
    }   
    
  } else {
    comp->sub_count = 0;
  }
}

PT_SCOPE BOOL fullPathInTree(NSString *path, pcomp *base)
{
  NSArray *components = (*pathCompsImp)(path, pathCompsSel);
  pcomp *comp = base;
  unsigned count = [components count]; 
  unsigned i;
  
  for (i = 0; i < count; i++) {
    comp = subcompWithName([components objectAtIndex: i], comp);

    if (comp == NULL) {
      break;
    } else if ((i == (count -1)) && (comp->sub_count == 0)) {
      return YES;
    }
  }
  
  return NO;
}

/*
  This verifies if the first part of a path has been inserted in the three.
  It can be used to filter events happened deeper than the inserted path;
  that is, if the first part exists in the three, this means that also
  the entire path is allowed or denied.
*/
PT_SCOPE BOOL isInTreeFirstPartOfPath(NSString *path, pcomp *base)
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


PT_SCOPE BOOL pathModified(NSString *path)
{
  static NSFileManager *fm = nil;
  NSDictionary *attributes;
  
  if (fm == nil) {
    fm = [NSFileManager defaultManager];
  }
  
  attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes) {
    return (abs([[attributes fileModificationDate] timeIntervalSinceNow]) < 5);
  }
  
  return NO;
}

PT_SCOPE BOOL isDotFile(NSString *path)
{
  int len = ([path length] - 1);
  unichar c;
  int i;
  
  for (i = len; i >= 0; i--) {
    c = [path characterAtIndex: i];
    
    if (c == '.') {
      if ((i > 0) && ([path characterAtIndex: (i - 1)] == '/')) {
        return YES;
      }
    }
  }
  
  return NO;  
}

#endif // PATH_UTILS_H
