/*  -*-objc-*-
 *  OSXCompatibility.m
 *
 *  Copyright (c) 2003 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Parts of variuos authors taken from the GNUstep Libraries
 *  Date: August 2003
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
#include "OSXCompatibility.h"
#include "GNUstep.h"
#include "config.h"

#include <stdlib.h>		// for getenv()
#ifdef HAVE_UNISTD_H
#include <unistd.h>		// for getlogin()
#endif
#ifdef HAVE_GETPWNAM
#include <pwd.h>		  // for getpwnam()
#endif
#include <sys/types.h>
#include <stdio.h>

#define PosixExecutePermission	(0111)

int make_services(void);
static void scanDirectory(NSMutableDictionary *services, NSString *path);
NSString *homeDirectory(void);
NSString *homeDirectoryForUser(NSString *loginName);
static NSString *importPath(NSString *s, const char *c);

static NSDictionary *applications = nil;
static NSString *extPrefPath = nil;
static NSDictionary *extPreferences = nil;

static NSMutableDictionary *applicationMap = nil;
static NSMutableDictionary *extensionsMap = nil;

static Class aClass;
static Class dClass;
static Class sClass;

static NSRecursiveLock *lock = nil;

@implementation NSString (OSXCompatibility)

- (BOOL)boolValue
{
  if ([self caseInsensitiveCompare: @"YES"] == NSOrderedSame) {
    return YES;
  }
  if ([self caseInsensitiveCompare: @"true"] == NSOrderedSame) {
    return YES;
  }
  
  return [self intValue] != 0 ? YES : NO;
}

@end

@implementation	NSWorkspace (OSXCompatibility)

+ (void)initialize
{
  if (self == [NSWorkspace class]) {
    static BOOL	beenHere = NO;
    BOOL isDir;
    BOOL isService = NO;
    NSFileManager	*mgr = [NSFileManager defaultManager];
    NSString *service;
    NSData *data;
    NSDictionary *dict;

    [self setVersion: 1];

    lock = [NSRecursiveLock new];

    [lock lock];
    
    if (beenHere == YES) {
	    [lock unlock];
	    return;
	  }

    beenHere = YES;

    NS_DURING
	  {
      service = homeDirectory();
      service = [service stringByAppendingPathComponent: @"GNUstep"];

      if (([mgr fileExistsAtPath: service isDirectory: &isDir] && isDir) == NO) {
        if ([mgr createDirectoryAtPath: service attributes: nil] == NO) {
	        NSLog(@"couldn't create %@\n", service);
	      } else {
          isService = YES;
        }
      } else {
        isService = YES;
      }

      if (isService) {
        service = [service stringByAppendingPathComponent: @"Services"];
      
        if (([mgr fileExistsAtPath: service isDirectory: &isDir] && isDir) == NO) {
          if ([mgr createDirectoryAtPath: service attributes: nil] == NO) {
	          NSLog(@"couldn't create %@\n", service);
            isService = NO;
	        } 
        }
      }
	  
      if (isService) {
	      /*
	      *	Load file extension preferences.
	      */
	      extPrefPath = [service
			        stringByAppendingPathComponent: @".GNUstepExtPrefs"];
	      RETAIN (extPrefPath);
	      if ([mgr isReadableFileAtPath: extPrefPath] == YES) {
	        data = [NSData dataWithContentsOfFile: extPrefPath];
	        if (data) {
		        dict = [NSDeserializer deserializePropertyListFromData: data
					                                       mutableContainers: NO];
		        extPreferences = RETAIN (dict);
		      }
	      }

	      /*
	      *	Load cached application information.
	      */        
        if (make_services()) {
          applications = RETAIN (applicationMap); 
        }       
      }
	  }
    NS_HANDLER
	  {
	    [lock unlock];
	    [localException raise];
	  }
    NS_ENDHANDLER
    {
      [lock unlock];
    }
  }
}

- (NSString *)fullPathForApplication:(NSString *)appName
{
  NSString *base;
  NSString *path;
  NSString *ext;

  if ([appName length] == 0) {
    return nil;
  }
  if ([[appName lastPathComponent] isEqual: appName] == NO) {
    if ([appName isAbsolutePath] == YES) {
	    return appName;		// MacOS-X implementation behavior.
	  }
    /*
     * Relative path ... get standarized absolute path
     */
    path = [[NSFileManager defaultManager] currentDirectoryPath];
    appName = [path stringByAppendingPathComponent: appName];
    appName = [appName stringByStandardizingPath];
  }
  
  base = [appName stringByDeletingLastPathComponent];
  appName = [appName lastPathComponent];
  ext = [appName pathExtension];
  if ([ext length] == 0) { // no extension, let's find one
    path = [appName stringByAppendingPathExtension: @"app"];
    path = [applications objectForKey: path];
    
    if (path == nil) {
	    path = [appName stringByAppendingPathExtension: @"debug"];
	    path = [applications objectForKey: path];
	  }
    if (path == nil) {
	    path = [appName stringByAppendingPathExtension: @"profile"];
	    path = [applications objectForKey: path];
	  }
  } else {
    path = [applications objectForKey: appName];
  }

  /*
   * If the original name included a path, check that the located name
   * matches it.  If it doesn't we return nil as MacOS-X does.
   */
  if ([base length] > 0
        && [base isEqual: [path stringByDeletingLastPathComponent]] == NO) {
    path = nil;
  }
  
  return path;
}

- (BOOL)getInfoForFile:(NSString*)fullPath
	         application:(NSString **)appName
		              type:(NSString **)type
{
  NSFileManager	*fm = [NSFileManager defaultManager];
  NSDictionary *attributes;
  NSString *fileType;
  NSString *extension = [fullPath pathExtension];

  attributes = [fm fileAttributesAtPath: fullPath traverseLink: YES];

  if (attributes != nil) {
    *appName = [self getBestAppInRole: nil forExtension: extension];
    fileType = [attributes fileType];
    
    if ([fileType isEqualToString: NSFileTypeRegular]) {
	    if ([attributes filePosixPermissions] & PosixExecutePermission) {
	      *type = NSShellCommandFileType;
	    } else {
	      *type = NSPlainFileType;
	    }
	  } else if ([fileType isEqualToString: NSFileTypeDirectory]) {
	    if ([extension isEqualToString: @"app"]
	                || [extension isEqualToString: @"debug"]
	                        || [extension isEqualToString: @"profile"]) {
        *type = NSApplicationFileType;
      } else if ([extension isEqualToString: @"bundle"]) {
	      *type = NSPlainFileType;
	    } else if (*appName != nil && [extension length] > 0) {
	      *type = NSPlainFileType;
	    } else if ([[fm fileAttributesAtPath:
	            [fullPath stringByDeletingLastPathComponent]
	                      traverseLink: YES] fileSystemNumber]
	                                != [attributes fileSystemNumber]) {
	      *type = NSFilesystemFileType;
	    } else {
	      *type = NSDirectoryFileType;
	    }
	  } else {
	    *type = NSPlainFileType;
	  }
    return YES;
    
  } else {
    return NO;
  }
}

- (BOOL)isFilePackageAtPath:(NSString*)fullPath
{
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSDictionary *attributes;
  NSString *fileType;

  attributes = [mgr fileAttributesAtPath: fullPath traverseLink: YES];
  fileType = [attributes objectForKey: NSFileType];

  if ([fileType isEqual: NSFileTypeDirectory] == YES) {
    return YES;
  }

  return NO;
}

/**
 * Returns the 'best' application to open a file with the specified extension
 * using the given role.  If the role is nil then apps which can edit are
 * preferred but viewers are also acceptable.  Uses a user preferred app
 * or picks any good match.
 */
- (NSString *)getBestAppInRole:(NSString*)role
		              forExtension:(NSString*)ext
{
  NSString *appName = nil;

  if ([self extension: ext role: role app: &appName] == NO) {
    appName = nil;
  }
  
  return appName;
}

/**
 * Gets the applications cache (generated by the make_services tool)
 * and looks up the special entry that contains a dictionary of all
 * file extensions recognised by GNUstep applications.  Then finds
 * the dictionary of applications that can handle our file and
 * returns it.
 */
- (NSDictionary*)infoForExtension:(NSString*)ext
{
  NSDictionary *map;

  ext = [ext lowercaseString];
  map = [applications objectForKey: @"GSExtensionsMap"];
  return [map objectForKey: ext];
}

/**
 * Returns the application bundle for the named application. Accepts
 * either a full path to an app or just the name. The extension (.app,
 * .debug, .profile) is optional, but if provided it will be used.<br />
 * Returns nil if the specified app does not exist as requested.
 */
- (NSBundle*)bundleForApp:(NSString*)appName
{
  if ([appName length] == 0)
    {
      return nil;
    }
  if ([[appName lastPathComponent] isEqual: appName]) // it's a name
    {
      appName = [self fullPathForApplication: appName];
    }
  else
    {
      NSFileManager	*fm;
      NSString		*ext;
      BOOL		flag;

      fm = [NSFileManager defaultManager];
      ext = [appName pathExtension];
      if ([ext length] == 0) // no extension, let's find one
	{
	  NSString	*path;

	  path = [appName stringByAppendingPathExtension: @"app"];
	  if ([fm fileExistsAtPath: path isDirectory: &flag] == NO
	    || flag == NO)
	    {
	      path = [appName stringByAppendingPathExtension: @"debug"];
	      if ([fm fileExistsAtPath: path isDirectory: &flag] == NO
		|| flag == NO)
		{
		  path = [appName stringByAppendingPathExtension: @"profile"];
		}
	    }
	  appName = path;
	}
      if ([fm fileExistsAtPath: appName isDirectory: &flag] == NO
	|| flag == NO)
	{
	  appName = nil;
	}
    }
  if (appName == nil)
    {
      return nil;
    }
  return [NSBundle bundleWithPath: appName];
}

/**
 * Requires the path to an application wrapper as an argument, and returns
 * the full path to the executable.
 */
- (NSString*)locateApplicationBinary:(NSString*)appName
{
  NSString	*path;
  NSString	*file;
  NSBundle	*bundle = [self bundleForApp: appName];

  if (bundle == nil)
    {
      return nil;
    }
  path = [bundle bundlePath];
  file = [[bundle infoDictionary] objectForKey: @"NSExecutable"];

  if (file == nil)
    {
      /*
       * If there is no executable specified in the info property-list, then
       * we expect the executable to reside within the app wrapper and to
       * have the same name as the app wrapper but without the extension.
       */
      file = [path lastPathComponent];
      file = [file stringByDeletingPathExtension];
      path = [path stringByAppendingPathComponent: file];
    }
  else
    {
      /*
       * If there is an executable specified in the info property-list, then
       * it can be either an absolute path, or a path relative to the app
       * wrapper, so we make sure we end up with an absolute path to return.
       */
      if ([file isAbsolutePath] == YES)
	{
	  path = file;
	}
      else
	{
	  path = [path stringByAppendingFormat: @"/%@", file];
	}
    }

  return path;
}

/**
 * Sets up a user preference  for which app should be used to open files
 * of the specified extension.
 */
- (void) setBestApp: (NSString*)appName
	     inRole: (NSString*)role
       forExtension: (NSString*)ext
{
  NSMutableDictionary	*map;
  NSMutableDictionary	*inf;
  NSData		*data;

  ext = [ext lowercaseString];
  if (extPreferences != nil)
    map = [extPreferences mutableCopy];
  else
    map = [NSMutableDictionary new];

  inf = [[map objectForKey: ext] mutableCopy];
  if (inf == nil)
    {
      inf = [NSMutableDictionary new];
    }
  if (appName == nil)
    {
      if (role == nil)
	{
	  NSString	*iconPath = [inf objectForKey: @"Icon"];

	  RETAIN(iconPath);
	  [inf removeAllObjects];
	  if (iconPath)
	    {
	      [inf setObject: iconPath forKey: @"Icon"];
	      RELEASE(iconPath);
	    }
	}
      else
	{
	  [inf removeObjectForKey: role];
	}
    }
  else
    {
      [inf setObject: appName forKey: (role ? role : @"Editor")];
    }
  [map setObject: inf forKey: ext];
  RELEASE(inf);
  RELEASE(extPreferences);
  extPreferences = map;
  data = [NSSerializer serializePropertyList: extPreferences];
  [data writeToFile: extPrefPath atomically: YES];
}

- (BOOL)extension:(NSString*)ext
             role:(NSString*)role
	            app:(NSString**)app
{
  NSEnumerator *enumerator;
  NSString *appName = nil;
  NSDictionary *apps = [self infoForExtension: ext];
  NSDictionary *prefs;
  NSDictionary *info;

  ext = [ext lowercaseString];

  /*
   *	Look for the name of the preferred app in this role.
   *	A 'nil' roll is a wildcard - find the preferred Editor or Viewer.
   */
  prefs = [extPreferences objectForKey: ext];
  if (role == nil || [role isEqualToString: @"Editor"])
    {
      appName = [prefs objectForKey: @"Editor"];
      if (appName != nil)
	{
	  info = [apps objectForKey: appName];
	  if (info != nil)
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	  else if ([self locateApplicationBinary: appName] != nil)
	    {
	      /*
	       * Return the preferred application even though it doesn't
	       * say it opens this type of file ... preferences overrule.
	       */
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	}
    }
  if (role == nil || [role isEqualToString: @"Viewer"])
    {
      appName = [prefs objectForKey: @"Viewer"];
      if (appName != nil)
	{
	  info = [apps objectForKey: appName];
	  if (info != nil)
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	  else if ([self locateApplicationBinary: appName] != nil)
	    {
	      /*
	       * Return the preferred application even though it doesn't
	       * say it opens this type of file ... preferences overrule.
	       */
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	}
    }

  /*
   * Go through the dictionary of apps that know about this file type and
   * determine the best application to open the file by examining the
   * type information for each app.
   * The 'NSRole' field specifies what the app can do with the file - if it
   * is missing, we assume an 'Editor' role.
   */
  if (apps == nil || [apps count] == 0)
    {
      return NO;
    }
  enumerator = [apps keyEnumerator];

  if (role == nil)
    {
      BOOL	found = NO;

      /*
       * If the requested role is 'nil', we can accept an app that is either
       * an Editor (preferred) or a Viewer.
       */
      while ((appName = [enumerator nextObject]) != nil)
	{
	  NSString	*str;

	  info = [apps objectForKey: appName];
	  str = [info objectForKey: @"NSRole"];
	  if (str == nil || [str isEqualToString: @"Editor"])
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	  else if ([str isEqualToString: @"Viewer"])
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      found = YES;
	    }
	}
      return found;
    }
  else
    {
      while ((appName = [enumerator nextObject]) != nil)
	{
	  NSString	*str;

	  info = [apps objectForKey: appName];
	  str = [info objectForKey: @"NSRole"];
	  if ((str == nil && [role isEqualToString: @"Editor"])
	    || [str isEqualToString: role])
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	}
      return NO;
    }
}

@end

int make_services(void)
{
  NSAutoreleasePool	*pool;
  NSMutableDictionary	*services;
  NSMutableArray *osxroots;
  unsigned index;
  NSDictionary *oldMap;

  pool = [NSAutoreleasePool new];

  aClass = [NSArray class];
  dClass = [NSDictionary class];
  sClass = [NSString class];

  applicationMap = [[NSMutableDictionary alloc] initWithCapacity: 64];
  extensionsMap = [NSMutableDictionary dictionaryWithCapacity: 64];

  osxroots = [NSMutableArray arrayWithCapacity: 1];
  [osxroots addObject: @"/Applications"];
  [osxroots addObject: @"/Applications/Utilities"];
  [osxroots addObject: @"/Network/Applications"];
  [osxroots addObject: @"/Developer/Applications"];
  [osxroots addObject: @"/Developer/Applications/Extras"];
  
  for (index = 0; index < [osxroots count]; index++) {
    scanDirectory(services, [osxroots objectAtIndex: index]);
  }
  
  [applicationMap setObject: extensionsMap forKey: @"GSExtensionsMap"];

  [pool release];
  
  return 1;
}

static void addExtensionsForApplication(NSDictionary *info, NSString *app)
{
  unsigned int i;
  id o0;
  NSArray *a0;

  o0 = [info objectForKey: @"CFBundleDocumentTypes"];

  if (o0) {
    if ([o0 isKindOfClass: aClass] == NO) {
      NSLog(@"bad app NSTypes (not an array) - %@\n", app);
      return;
    }
    
    a0 = (NSArray*)o0;
    i = [a0 count];

    while (i-- > 0) {
      NSDictionary *t;
      NSArray *a1;
      id o1 = [a0 objectAtIndex: i];
      unsigned int j;

      if ([o1 isKindOfClass: dClass] == NO) {
        NSLog(@"bad app CFBundleDocumentTypes (type not a dictionary) - %@\n", app);
        return;
      }
	    /*
	    * Set 't' to the dictionary defining a particular file type.
	    */
      t = (NSDictionary *)o1;
      o1 = [t objectForKey: @"CFBundleTypeExtensions"];
      
      if (o1) {
        if ([o1 isKindOfClass: aClass] == NO) {
          NSLog(@"bad app CFBundleTypeExtensions (extensions not an array) - %@\n", app);
          return;
        }

        a1 = (NSArray*)o1;
        j = [a1 count];

        while (j-- > 0) {
          NSString *e;
          NSMutableDictionary	*d;

          e = [[a1 objectAtIndex: j] lowercaseString];
          d = [extensionsMap objectForKey: e];

          if (d == nil) {
            d = [NSMutableDictionary dictionaryWithCapacity: 1];
            [extensionsMap setObject: d forKey: e];
          }

          if ([d objectForKey: app] == NO) {
            [d setObject: t forKey: app];
          } 
        }      
      }
    }    
  } else {
    o0 = [info objectForKey: @"NSExtensions"];

    if (o0) {
      NSDictionary *d;
      NSArray *ak;
      
      if ([o0 isKindOfClass: dClass] == NO) {
        NSLog(@"bad app NSExtensions (not a dictionary) - %@\n", app);
        return;
      }
      
      d = (NSDictionary *)o0;
      ak = [d allKeys];
      i = [ak count];
            
      while (i-- > 0) {
        NSString *e = [[ak objectAtIndex: i] lowercaseString];
        NSMutableDictionary	*d = [extensionsMap objectForKey: e];

        if (d == nil) {
	        d = [NSMutableDictionary dictionaryWithCapacity: 1];
	        [extensionsMap setObject: d forKey: e];
        }
        
        if ([d objectForKey: app] == nil) {
	        NSDictionary	*info = [NSDictionary dictionaryWithObjectsAndKeys: nil];
          [d setObject: info forKey: app];
        } 
      }        
    
    } else {
      NSLog(@"bad app Dictionary - %@\n", app);
    }
  }
}

static void scanDirectory(NSMutableDictionary *services, NSString *path)
{
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSArray *contents = [mgr directoryContentsAtPath: path];
  unsigned index;

  for (index = 0; index < [contents count]; index++) {
    NSString *name = [contents objectAtIndex: index];
    NSString *ext = [name pathExtension];
    NSString *newPath;
    BOOL isDir;

    if (ext != nil
	      && ([ext isEqualToString: @"app"] || [ext isEqualToString: @"debug"]
	                                      || [ext isEqualToString: @"profile"])) {
      
      newPath = [path stringByAppendingPathComponent: name];
	    
      if ([mgr fileExistsAtPath: newPath isDirectory: &isDir] && isDir) {
	      NSString *oldPath;
	      NSBundle *bundle;
	      NSDictionary *info;

        if ((oldPath = [applicationMap objectForKey: name]) == nil) {
          [applicationMap setObject: newPath forKey: name];
        } else {
          NSLog(@"duplicate app (%@) at '%@' and '%@'\n", name, oldPath, newPath);
          continue;
        }

	      bundle = [NSBundle bundleWithPath: newPath];
	      info = [bundle infoDictionary];
        
	      if (info) {
		      addExtensionsForApplication(info, name);
		    } else {
		      NSLog(@"bad app info - %@\n", newPath);
		    }
      } else {
	      NSLog(@"bad application - %@\n", newPath);
	    }
      
	  } else if (ext != nil && [ext isEqualToString: @"service"]) {
      
	  } else {
	    newPath = [path stringByAppendingPathComponent: name];
	    
      if ([mgr fileExistsAtPath: newPath isDirectory: &isDir] && isDir) {
	      scanDirectory(services, newPath);
	    }
	  }
  }
  
  [arp release];
}

static NSString *importPath(NSString *s, const char *c)
{
  static NSFileManager *mgr = nil;
  const char *ptr = c;
  unsigned len;

  if (mgr == nil) {
    mgr = [NSFileManager defaultManager];
    RETAIN (mgr);
  }
  
  if (ptr == 0) {
    if (s == nil) {
	    return nil;
	  }
    ptr = [s cString];
  }
  
  len = strlen(ptr);

  return [mgr stringWithFileSystemRepresentation: ptr length: len]; 
}

NSString *homeDirectory(void)
{
  return homeDirectoryForUser(NSUserName());
}

NSString *homeDirectoryForUser(NSString *loginName)
{
  NSString	*s = nil;
  struct passwd *pw;

  [lock lock];
  pw = getpwnam ([loginName cString]);
  if (pw != 0) {
    s = [NSString stringWithCString: pw->pw_dir];
  }
  [lock unlock];
  s = importPath(s, 0);

  return s;
}
