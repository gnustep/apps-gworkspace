 /*
 *  FopExec.m: Implementation of the FindFile Class 
 *  of the FindFile tool for the GNUstep Backgrounder application
 *
 *  Copyright (c) 2003 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: January 2003
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

#include "findfile.h"
#include "GNUstep.h"

#define PosixExecutePermission	(0111)

static NSFileManager *fm;

typedef struct {
  int findName;
  int nameIs;
  int doesntContain;
  int nameContains;
  int nameStarts;
  int nameEnds;
  
  int findType;
  int typeIs;
  
  int findCreation;
  int creationExactly;
  int creationBefore;
  int creationAfter;

  int findModification;
  int modifExactly;
  int modifBefore;
  int modifAfter;
  
  int findSize;
  int sizeLess;
  int sizeGreater;
  
  int findOwner;
  int ownerIs;
  
  int findGroup;
  int groupIs;
  
  int findContents;
} FindStruct;

static FindStruct findStruct = {
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

BOOL checkName(NSString *str, NSString *path)
{
  NSString *fname = [path lastPathComponent];

  if (findStruct.nameIs) {
    return [fname isEqual: str];
  } else if (findStruct.doesntContain) {    
    return ([fname rangeOfString: str].location == NSNotFound);
  } else if (findStruct.nameContains) {
    return ([fname rangeOfString: str].location != NSNotFound);
  } else if (findStruct.nameStarts) {
    return [fname hasPrefix: str];
  } else if (findStruct.nameEnds) {
    return [fname hasSuffix: str];
  } 

  return NO;
}

BOOL checkType(NSString *str, NSString *path)
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];
  NSString *extension = [path pathExtension];
  
#define RETURN_IF_EQUAL(x) if ([str isEqual: x]) return YES

  if (attributes != nil) {
    NSString *fileType = [attributes fileType];

    if ([fileType isEqualToString: @"NSFileTypeRegular"]) {
	    if ([attributes filePosixPermissions] & PosixExecutePermission) {
        RETURN_IF_EQUAL (@"NSShellCommandFileType");
	    } else {
        RETURN_IF_EQUAL (@"NSPlainFileType");
	    }
	  } else if ([fileType isEqualToString: @"NSFileTypeDirectory"]) {
	    if (extension && ([extension isEqualToString: @"app"]
	                      || [extension isEqualToString: @"debug"]
	                        || [extension isEqualToString: @"profile"])) {
        RETURN_IF_EQUAL (@"NSApplicationFileType");
	    } else if (extension && [extension isEqualToString: @"bundle"]) {
        RETURN_IF_EQUAL (@"NSPlainFileType");
	    } else {
        RETURN_IF_EQUAL (@"NSDirectoryFileType");
	    }
    } else if ([fileType isEqualToString: NSFileTypeSymbolicLink]) {
      RETURN_IF_EQUAL (@"NSFileTypeSymbolicLink");
    } else {
      RETURN_IF_EQUAL (@"NSPlainFileType");
	  }
  }
  
  return NO;
}

BOOL checkCreation(NSDate *date, NSString *path)
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes != nil) {
    NSDate *cd = [attributes fileCreationDate];

    if (findStruct.creationExactly) {
      return (labs([cd timeIntervalSinceDate: date]) < 60);
      
    } else {  
      NSDate *d = [date earlierDate: cd];
    
      if (findStruct.creationBefore) {  
        return [d isEqualToDate: cd];
      } else if (findStruct.creationAfter) {
        return [d isEqualToDate: date];
      }
    } 

  } else {
    return NO;
  }
  
  return NO;
}

BOOL checkModification(NSDate *date, NSString *path)
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes != nil) {
    NSDate *cd = [attributes fileModificationDate];

    if (findStruct.modifExactly) {
      return (labs([cd timeIntervalSinceDate: date]) < 60);
      
    } else {  
      NSDate *d = [date earlierDate: cd];
    
      if (findStruct.modifBefore) {  
        return [d isEqualToDate: cd];
      } else if (findStruct.modifAfter) {
        return [d isEqualToDate: date];
      }
    } 

  } else {
    return NO;
  }
  
  return NO;
}

BOOL checkSize(unsigned long long size, NSString *path)
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes != nil) {
    unsigned long long fs = [attributes fileSize];

    if (fs < size) {
      return (findStruct.sizeLess) ? YES : NO;    
    } else if (fs > size) {
      return (findStruct.sizeGreater) ? YES : NO;    
    } 
    
    return NO;
    
  } else {
    return NO;
  }

  return NO;
}

BOOL checkOwner(NSString *owner, NSString *path)
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes != nil) {
    if ([owner isEqual: [attributes fileOwnerAccountName]]) {
      return YES;
    }
  } 

  return NO;
}

BOOL checkGroup(NSString *group, NSString *path)
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes != nil) {
    if ([group isEqual: [attributes fileGroupOwnerAccountName]]) {
      return YES;
    } 
  }

  return NO;
}

BOOL checkContents(NSString *str, NSString *path)
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes) {
    NSString *fileType = [attributes fileType];

    if ([fileType isEqualToString: @"NSFileTypeRegular"]) {
      NSString *contents = [NSString stringWithContentsOfFile: path];

      if (contents) {
        return ([contents rangeOfString: str].location != NSNotFound);
      }
    }
  }

  return NO;
}


@implementation FindFile

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (findPath);
  TEST_RELEASE (criteria);
	[super dealloc];
}

- (id)init
{  
	self = [super init];
  if(self) {
    NSConnection *connection;
    id anObject;
        
    connection = [NSConnection connectionWithRegisteredName: @"Finder" host: @""];
    if (connection == nil) {
      NSLog(@"FindFile - failed to get the connection - bye.");
	    exit(1);               
    }

    anObject = [connection rootProxy];
    
    if (anObject == nil) {
      NSLog(@"FindFile - failed to contact GWorkspace - bye.");
	    exit(1);           
    } 

    [anObject setProtocolForProxy: @protocol(FinderProtocol)];
    finder = (id <FinderProtocol>)anObject;
    
    [[NSNotificationCenter defaultCenter] addObserver: self
                            selector: @selector(connectionDidDie:)
                                name: NSConnectionDidDieNotification
                              object: connection];    

    fm = [NSFileManager defaultManager];    
  }
    
	return self;
}

- (void)registerWithFinder
{  
  [finder registerFindFile: self];  
}

- (oneway void)findAtPath:(NSString *)apath 
             withCriteria:(NSDictionary *)crit
{
  findPath = [[NSString alloc] initWithString: apath];
  criteria = [[NSMutableDictionary alloc] initWithDictionary: crit];
 
#define GET_VALUE(k, x) \
if ([[criteria objectForKey: k] intValue]) (findStruct.x) = 1;

  GET_VALUE (@"findName", findName);
  GET_VALUE (@"nameIs", nameIs);     
  GET_VALUE (@"doesntContain", doesntContain);     
  GET_VALUE (@"nameContains", nameContains);     
  GET_VALUE (@"nameStarts", nameStarts);     
  GET_VALUE (@"nameEnds", nameEnds);       
  GET_VALUE (@"findType", findType);     
  GET_VALUE (@"typeIs", typeIs);       
  GET_VALUE (@"findCreation", findCreation);     
  GET_VALUE (@"creationExactly", creationExactly);     
  GET_VALUE (@"creationBefore", creationBefore);     
  GET_VALUE (@"creationAfter", creationAfter);     
  GET_VALUE (@"findModification", findModification);     
  GET_VALUE (@"modifExactly", modifExactly);     
  GET_VALUE (@"modifBefore", modifBefore);     
  GET_VALUE (@"modifAfter", modifAfter);       
  GET_VALUE (@"findSize", findSize);     
  GET_VALUE (@"sizeLess", sizeLess);     
  GET_VALUE (@"sizeGreater", sizeGreater);      
  GET_VALUE (@"findOwner", findOwner);     
  GET_VALUE (@"ownerIs", ownerIs);       
  GET_VALUE (@"findGroup", findGroup);     
  GET_VALUE (@"groupIs", groupIs);       
  GET_VALUE (@"findContents", findContents);     

  [self doFind];
}

- (void)doFind
{
  NSDirectoryEnumerator *enumerator = nil;
  NSString *currentPath;
  NSString *name;    
  NSString *type;
  NSNumber *size;
  NSString *owner;
  NSDate *crDate;
  NSDate *modDate;    
  NSString *contents;

  if (findStruct.findName) {  
    name = [criteria objectForKey: @"name"];
  }  
  if (findStruct.findType) {  
    type = [criteria objectForKey: @"type"];
  }  
  if (findStruct.findSize) {  
    size = [criteria objectForKey: @"size"];
  }  
  if (findStruct.findOwner) {  
    owner = [criteria objectForKey: @"owner"];
  }  
  if (findStruct.findCreation) {  
    crDate = [criteria objectForKey: @"created"];
  }  
  if (findStruct.findModification) {  
    modDate = [criteria objectForKey: @"modified"];
  }  
  if (findStruct.findContents) {
    contents = [criteria objectForKey: @"contents"];
  }  

  enumerator = [fm enumeratorAtPath: findPath];

  if (enumerator == nil) {
    [self done];  
  }

  while ((currentPath = [enumerator nextObject])) {
    NSString *fullPath = [findPath stringByAppendingPathComponent: currentPath];
    BOOL canContinue = YES;
    BOOL found = YES;
    
    if (findStruct.findName && found) {    
      found = checkName(name, fullPath);
    }        
    if (findStruct.findType && found) {      
      found = checkType(type, fullPath);
      found = findStruct.typeIs ? found : !found;
    }
    if (findStruct.findSize && found) {    
      found = checkSize(([size intValue] * 1024), fullPath);
    }
    if (findStruct.findOwner && found) {      
      found = checkOwner(owner, fullPath);
      found = findStruct.ownerIs ? found : !found;
    }
    if (findStruct.findCreation && found) {      
      found = checkCreation(crDate, fullPath);
    }
    if (findStruct.findModification && found) {      
      found = checkModification(modDate, fullPath);
    }
    if (findStruct.findContents && found) {      
      found = checkContents(contents, fullPath);
    }
 
    if (found) {
      canContinue = [finder getFoundPath: fullPath];
      if (canContinue == NO) {
        break; 
      }
    }
  }

  [self done]; 
}

- (void)done
{
  [finder findDone]; 
  exit(0);
}

- (void)connectionDidDie:(NSNotification *)notification
{
  NSLog(@"connection died!");
  exit(0);
}

- (BOOL)fileManager:(NSFileManager *)manager 
              shouldProceedAfterError:(NSDictionary *)errorDict
{  
	return NO;
}

@end

int main(int argc, char** argv)
{
	FindFile *findfile;
  
  CREATE_AUTORELEASE_POOL (pool);
	findfile = [[FindFile alloc] init];
  
  if (findfile != nil) {
    [findfile registerWithFinder];
    [[NSRunLoop currentRunLoop] run];
  }
  
  RELEASE(pool);
  exit(0);
}
