/*  -*-objc-*-
 *  Permissions.m: Implementation of the Permissions Class 
 *  of the GNUstep GWorkspace application
 *
 *  Copyright (c) 2001 Enrico Sersale <enrico@imago.ro>
 *  
 *  Author: Enrico Sersale
 *  Date: August 2001
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
  #ifdef GNUSTEP 
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "Permissions.h"
#include "TimeDateView.h"
#include "GNUstep.h"
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#define SET_BUTTON_STATE(b, v) { \
if ((perms & v) == v) [b setState: NSOnState]; \
else [b setState: NSOffState]; \
}

#define GET_BUTTON_STATE(b, v) { \
if ([b state] == NSOnState) { \
perms |= v; \
} else { \
if ((oldperms & v) == v) { \
if ([b image] == multipleImage) perms |= v; \
} } \
}

#ifdef __WIN32__
	#define S_IRUSR _S_IRUSR
	#define S_IWUSR _S_IWUSR
	#define S_IXUSR _S_IXUSR
#endif

static NSString *nibName = @"PermissionsPanel";

@implementation Permissions

- (void)dealloc
{
	TEST_RELEASE (inspBox);
	TEST_RELEASE (insideButt);
	TEST_RELEASE (insideBox);
	TEST_RELEASE (insppaths);
	TEST_RELEASE (currentPath);
	TEST_RELEASE (attributes);
	TEST_RELEASE (onImage);
	TEST_RELEASE (offImage);
	TEST_RELEASE (multipleImage);  
  [super dealloc];
}

- (id)init
{
	self = [super init];
	
	if(self) {
		if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"Attribute Inspector: failed to load %@!", nibName);
    } else {    
      RETAIN (inspBox);
      RETAIN (insideButt);
      RETAIN (insideBox);
      RELEASE (win); 
        
      ASSIGN (onImage, [NSImage imageNamed: @"switchOn.tiff"]);
      ASSIGN (offImage, [NSImage imageNamed: @"switchOff.tiff"]);
      ASSIGN (multipleImage, [NSImage imageNamed: @"switchMultiple.tiff"]);
      
      [ureadbutt setImage: offImage];
      [ureadbutt setAlternateImage: onImage];                 
      [greadbutt setImage: offImage];
      [greadbutt setAlternateImage: onImage];                 
      [oreadbutt setImage: offImage];
      [oreadbutt setAlternateImage: onImage];                 
      [uwritebutt setImage: offImage];
      [uwritebutt setAlternateImage: onImage];                 
      [gwritebutt setImage: offImage];
      [gwritebutt setAlternateImage: onImage];                 
      [owritebutt setImage: offImage];
      [owritebutt setAlternateImage: onImage];                
      [uexebutt setImage: offImage];
      [uexebutt setAlternateImage: onImage];  
      [gexebutt setImage: offImage];
      [gexebutt setAlternateImage: onImage];  
      [oexebutt setImage: offImage];
      [oexebutt setAlternateImage: onImage];  

	    [revertButt setEnabled: NO];
	    [okButt setEnabled: NO];

		  fm = [NSFileManager defaultManager];
		  insppaths = nil;
		  attributes = nil;
      recursive = NO;
    } 
	}		
  
	return self;
}

//
// InspectorsProtocol
//
- (void)activateForPaths:(NSArray *)paths
{
	NSString *fpath;
	NSString *ftype;
	NSString *usr, *grp, *tmpusr;
	NSDictionary *attrs;
	int perms;
	BOOL sameOwner;
	int i;
	
	attrs = [fm fileAttributesAtPath: [paths objectAtIndex: 0] traverseLink: NO];
	if(attributes && [attrs isEqualToDictionary: attributes] 
                                  && [paths isEqualToArray: insppaths]) {
		return;
	}

	ASSIGN (insppaths, paths);	
	pathscount = [insppaths count];	
	ASSIGN (currentPath, [insppaths objectAtIndex: 0]);		
	ASSIGN (attributes, attrs);	

	[revertButt setEnabled: NO];
	[okButt setEnabled: NO];
	
	if (pathscount == 1) {   // Single Selection
		usr = [attributes objectForKey: NSFileOwnerAccountName];
		grp = [attributes objectForKey: NSFileGroupOwnerAccountName];
		perms = [[attributes objectForKey: NSFilePosixPermissions] intValue];			

	#ifdef __WIN32__
		iamRoot = YES;
	#else
		iamRoot = (geteuid() == 0);
	#endif
	
		isMyFile = ([NSUserName() isEqual: usr]);

    [self setPermissions: perms isActive: (iamRoot || isMyFile)];

		ftype = [attributes objectForKey: NSFileType];
		if ([ftype isEqualToString: NSFileTypeDirectory] == NO) {		
			if ([insideButt superview]) {
				[insideButt removeFromSuperview];
				[insideButt setState: NSOffState];
			}
			if ([insideBox superview]) {
				[insideBox removeFromSuperview];
      }      
    } else {
			if ([insideButt superview] == nil) {		
			  [inspBox addSubview: insideButt]; 
			}
			[insideButt setEnabled: (iamRoot || isMyFile)];	
			[self insideButtonClicked: insideButt];
    }

	} else {	   // Multiple Selection
	
		ftype = [attributes objectForKey: NSFileType];
		usr = [attributes objectForKey: NSFileOwnerAccountName];
		grp = [attributes objectForKey: NSFileGroupOwnerAccountName];
		perms = [[attributes objectForKey: NSFilePosixPermissions] intValue];			

		sameOwner = YES;	
		for (i = 0; i < [insppaths count]; i++) {
			fpath = [insppaths objectAtIndex: i];
			attrs = [fm fileAttributesAtPath: fpath traverseLink: NO];
			tmpusr = [attrs objectForKey: NSFileOwnerAccountName];
			if ([tmpusr isEqualToString: usr] == NO) {
				sameOwner = NO;
			}
		}
		
		if(sameOwner == NO) {
			usr = @"";
    }

	#ifdef __WIN32__
		iamRoot = YES;
	#else
		iamRoot = (geteuid() == 0);
	#endif

		isMyFile = ([NSUserName() isEqualToString: usr]);
						
		[self setPermissions: 0 isActive: (iamRoot || isMyFile)];
        
	  if ([insideButt superview] == nil) {		
		  [inspBox addSubview: insideButt]; 
	  }
	  [insideButt setEnabled: (iamRoot || isMyFile)];	
	  [self insideButtonClicked: insideButt];    
	}
	
	[inspBox setNeedsDisplay: YES];
}

- (id)inspView
{
  return inspBox;
}

- (void)deactivate
{
  [inspBox removeFromSuperview];
}

- (NSString *)inspname
{
	return NSLocalizedString(@"Permissions", @"");
}

- (NSString *)winname
{
	return NSLocalizedString(@"Permissions Inspector", @"");
}

- (NSButton *)revertButton
{
	return revertButt;
}

- (NSButton *)okButton
{
	return okButt;
}
//
// end of InspectorsProtocol 
//

- (IBAction)permsButtonsAction:(id)sender
{
	if (multiplePaths == YES) {
		if ([sender state] == NSOffState) {
			if ([sender image] == multipleImage) 
				[sender setImage: offImage];	
		} else {
			if ([sender image] == offImage) {
				[sender setImage: multipleImage];
				[sender setState: NSOffState];		
			}
		}
	}	

	if(!(iamRoot || isMyFile)) {
		return;
	}

	[revertButt setEnabled: YES];	
	[okButt setEnabled: YES];
}

- (void)insideButtonClicked:(id)sender
{
	int perms;
	
	if ([sender state] == NSOnState) {
		recursive = YES;
		[self setPermissions: 0 isActive: YES];    
		if ([insideBox superview] == nil) {
			[inspBox addSubview: insideBox]; 
    }      
	} else {
		recursive = NO;
		if (pathscount == 1) {
			perms = [[attributes objectForKey: NSFilePosixPermissions] intValue];
			[self setPermissions: perms isActive: YES];
		} else {
			[self setPermissions: 0 isActive: YES];
		}
    if ([insideBox superview]) {
      [insideBox removeFromSuperview];
    }      
	}	 
}

- (IBAction)changePermissions:(id)sender
{
	NSMutableDictionary *attrs;
	NSDirectoryEnumerator *enumerator;	
	NSString *path, *fpath, *ftype;
	int oldperms, newperms, i;
	BOOL isdir;
	
	if(pathscount == 1) {
		[fm fileExistsAtPath: currentPath isDirectory: &isdir];

		if ((recursive == YES) && (isdir == YES)) {
			enumerator = [fm enumeratorAtPath: currentPath];
			while ((fpath = [enumerator nextObject])) {
				fpath = [currentPath stringByAppendingPathComponent: fpath];
				attrs = [[fm fileAttributesAtPath: fpath traverseLink: NO] mutableCopy];
				if (attrs != nil) {			
					oldperms = [[attrs objectForKey: NSFilePosixPermissions] intValue];	
					newperms = [self getPermissions: oldperms];			
					[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
					[fm changeFileAttributes: attrs atPath: fpath];
					ftype = [attrs objectForKey: NSFileType];
					if ([ftype isEqualToString: NSFileTypeDirectory]) {		
						[[NSNotificationCenter defaultCenter]
 									postNotificationName: GWDidSetFileAttributesNotification
	 					  							  object: (id)fpath];
					}
				}
			}
			ASSIGN (attributes, [fm fileAttributesAtPath: currentPath traverseLink: NO]);	
			[self setPermissions: 0 isActive: YES];

		} else {
			oldperms = [[attributes objectForKey: NSFilePosixPermissions] intValue];
			newperms = [self getPermissions: oldperms];		
			attrs = [attributes mutableCopy];
			[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
			[fm changeFileAttributes: attrs atPath: currentPath];	
			ASSIGN (attributes, [fm fileAttributesAtPath: currentPath traverseLink: NO]);	
			newperms = [[attributes objectForKey: NSFilePosixPermissions] intValue];				
			[self setPermissions: newperms isActive: YES];
		}
	
	} else {
	
		for (i = 0; i < [insppaths count]; i++) {
			path = [insppaths objectAtIndex: i];
			[fm fileExistsAtPath: path isDirectory: &isdir];
			
			if ((recursive == YES) && (isdir == YES)) {
				enumerator = [fm enumeratorAtPath: path];
				while ((fpath = [enumerator nextObject])) {
					fpath = [path stringByAppendingPathComponent: fpath];
					attrs = [[fm fileAttributesAtPath: fpath traverseLink: NO] mutableCopy];
					if (attrs != nil) {			
						oldperms = [[attrs objectForKey: NSFilePosixPermissions] intValue];	
						newperms = [self getPermissions: oldperms];			
						[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
						[fm changeFileAttributes: attrs atPath: fpath];
						ftype = [attrs objectForKey: NSFileType];
						if ([ftype isEqualToString: NSFileTypeDirectory]) {		
							[[NSNotificationCenter defaultCenter]
 										postNotificationName: GWDidSetFileAttributesNotification
	 					  								  object: (id)fpath];
						}
					}
				}
				
			} else {
				attrs = [[fm fileAttributesAtPath: path traverseLink: NO] mutableCopy];
				oldperms = [[attrs objectForKey: NSFilePosixPermissions] intValue];	
				newperms = [self getPermissions: oldperms];			
				[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
				[fm changeFileAttributes: attrs atPath: path];				
			}
		}
		
		ASSIGN (attributes, [fm fileAttributesAtPath: currentPath traverseLink: NO]);	
		[self setPermissions: 0 isActive: YES];
	}

	[[NSNotificationCenter defaultCenter]
 		postNotificationName: GWDidSetFileAttributesNotification
	 					  object: (id)[currentPath stringByDeletingLastPathComponent]];

	[okButt setEnabled: NO];
	[revertButt setEnabled: NO];
}

- (IBAction)revertToOldPermissions:(id)sender
{
	if(pathscount == 1) {
		int perms = [[attributes objectForKey: NSFilePosixPermissions] intValue];
		[self setPermissions: perms isActive: YES];	
	} else {
		[self setPermissions: 0 isActive: YES];
	}
	
	[revertButt setEnabled: NO];
	[okButt setEnabled: NO];
}

- (void)setPermissions:(int)perms isActive:(BOOL)active
{
	if (active == NO) {
		[ureadbutt setEnabled: NO];						
		[uwritebutt setEnabled: NO];	
		[uexebutt setEnabled: NO];	

	#ifndef __WIN32__
		[greadbutt setEnabled: NO];						
		[gwritebutt setEnabled: NO];
		[gexebutt setEnabled: NO];			
		[oreadbutt setEnabled: NO];						
		[owritebutt setEnabled: NO];
		[oexebutt setEnabled: NO];	
	#endif
								
	} else {
		[ureadbutt setEnabled: YES];						
		[uwritebutt setEnabled: YES];		
		[uexebutt setEnabled: YES];	

	#ifndef __WIN32__
		[greadbutt setEnabled: YES];						
		[gwritebutt setEnabled: YES];		
		[gexebutt setEnabled: YES];	
		[oreadbutt setEnabled: YES];						
		[owritebutt setEnabled: YES];			
		[oexebutt setEnabled: YES];	
	#endif
	
	}

	if (perms == 0) {
		multiplePaths = YES;
		[ureadbutt setImage: multipleImage];
		[ureadbutt setState: NSOffState];
		[uwritebutt setImage: multipleImage];
		[uwritebutt setState: NSOffState];
		[uexebutt setImage: multipleImage];
		[uexebutt setState: NSOffState];	

	#ifndef __WIN32__
		[greadbutt setImage: multipleImage];
		[greadbutt setState: NSOffState];
		[gwritebutt setImage: multipleImage];
		[gwritebutt setState: NSOffState];
		[gexebutt setImage: multipleImage];
		[gexebutt setState: NSOffState];
		[oreadbutt setImage: multipleImage];
		[oreadbutt setState: NSOffState];
		[owritebutt setImage: multipleImage];
		[owritebutt setState: NSOffState];
		[oexebutt setImage: multipleImage];
		[oexebutt setState: NSOffState];
	#endif
	
		return;
	} else {
		multiplePaths = NO;
		[ureadbutt setImage: offImage];
		[uwritebutt setImage: offImage];
		[uexebutt setImage: offImage];	

	#ifndef __WIN32__
		[greadbutt setImage: offImage];
		[gwritebutt setImage: offImage];
		[gexebutt setImage: offImage];
		[oreadbutt setImage: offImage];
		[owritebutt setImage: offImage];
		[oexebutt setImage: offImage];
	#endif
	
	}

	SET_BUTTON_STATE (ureadbutt, S_IRUSR);				
	SET_BUTTON_STATE (uwritebutt, S_IWUSR);
	SET_BUTTON_STATE (uexebutt, S_IXUSR);

#ifndef __WIN32__
	SET_BUTTON_STATE (greadbutt, S_IRGRP);
	SET_BUTTON_STATE (gwritebutt, S_IWGRP);
	SET_BUTTON_STATE (gexebutt, S_IXGRP);
	SET_BUTTON_STATE (oreadbutt, S_IROTH);
	SET_BUTTON_STATE (owritebutt, S_IWOTH);
	SET_BUTTON_STATE (oexebutt, S_IXOTH);
#endif
}

- (int)getPermissions:(int)oldperms
{
	int perms = 0;

	GET_BUTTON_STATE (ureadbutt, S_IRUSR);
	GET_BUTTON_STATE (uwritebutt, S_IWUSR);
	GET_BUTTON_STATE (uexebutt, S_IXUSR);

#ifndef __WIN32__	
	if ((oldperms & S_ISUID) == S_ISUID) perms |= S_ISUID;

	GET_BUTTON_STATE (greadbutt, S_IRGRP);
	GET_BUTTON_STATE (gwritebutt, S_IWGRP);
	GET_BUTTON_STATE (gexebutt, S_IXGRP);
		
	if ((oldperms & S_ISGID) == S_ISGID) perms |= S_ISGID;

	GET_BUTTON_STATE (oreadbutt, S_IROTH);
	GET_BUTTON_STATE (owritebutt, S_IWOTH);
	GET_BUTTON_STATE (oexebutt, S_IXOTH);
		
	if ((oldperms & S_ISVTX) == S_ISVTX) perms |= S_ISVTX;
#endif

	return perms;
}

@end
