/* Attributes.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
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


#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>
  #ifdef GNUSTEP 
#include "GWFunctions.h"
#include "GWNotifications.h"
  #else
#include <GWorkspace/GWFunctions.h>
#include <GWorkspace/GWNotifications.h>
  #endif
#include "Attributes.h"
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

static NSString *nibName = @"AttributesPanel";

@implementation Attributes

- (void)dealloc
{
	TEST_RELEASE (inspBox);
	TEST_RELEASE (insppaths);
	TEST_RELEASE (currentPath);
	TEST_RELEASE (attributes);
	TEST_RELEASE (timeDateView);
	TEST_RELEASE (yearlabel);
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
      RELEASE (win); 
        
      timeDateView = [[TimeDateView alloc] init];
      [timeDateView setFrame: NSMakeRect(6, 13, 55, 57)];
      [changedDateBox addSubview: timeDateView];      

		  MAKE_LABEL (yearlabel, NSMakeRect(6, 1, 55, 12), nil, 'l', NO, changedDateBox);
		  [yearlabel setFont: [NSFont systemFontOfSize: 8]];
		  [yearlabel setAlignment: NSCenterTextAlignment];

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

	    [revertButt setEnabled: NO];
	    [okButt setEnabled: NO];

		  fm = [NSFileManager defaultManager];
		  insppaths = nil;
		  attributes = nil;
    } 
	}		
  
	return self;
}

//
// InspectorsProtocol
//
- (id)inspView
{
  return inspBox;
}

- (void)activateForPaths:(NSArray *)paths
{
	NSString *fpath;
	NSString *ftype, *fsize, *s;
	NSString *usr, *grp, *tmpusr, *tmpgrp;
	NSDate *date;
  NSDate *tmpdate = nil;
	NSCalendarDate *cdate;
	NSDictionary *attrs;
  NSImage *image;
	int perms;
	BOOL sameOwner, sameGroup;
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
		date = [attributes objectForKey: NSFileModificationDate];
		perms = [[attributes objectForKey: NSFilePosixPermissions] intValue];			

	#ifdef __WIN32__
		iamRoot = YES;
	#else
		iamRoot = (geteuid() == 0);
	#endif
	
		isMyFile = ([NSUserName() isEqual: usr]);

		ftype = [attributes objectForKey: NSFileType];
		if([ftype isEqualToString: NSFileTypeDirectory] == NO) {			
			fsize = fileSizeDescription([[attributes objectForKey: NSFileSize] intValue]);
		} else {
			fsize = @"";
		}

		s = [currentPath stringByDeletingLastPathComponent];

		if ([ftype isEqual: NSFileTypeSymbolicLink]) {
			s = [fm pathContentOfSymbolicLinkAtPath: currentPath];
			s = relativePathFittingInContainer(linkToField, s);
			[linkToField setStringValue: s];
      [linkToLabel setTextColor: [NSColor blackColor]];		
			[linkToField setTextColor: [NSColor blackColor]];		      
		} else {
			[linkToField setStringValue: @""];
      [linkToLabel setTextColor: [NSColor grayColor]];		
			[linkToField setTextColor: [NSColor grayColor]];		
		}
			
		[sizeField setStringValue: fsize]; 
		[ownerField setStringValue: usr]; 
		[groupField setStringValue: grp]; 

		if ([ftype isEqual: NSFileTypeDirectory]) {
      image = [NSImage imageNamed: @"ComputeSize.tiff"];
			[calculateButt setEnabled: YES];
		} else {
      image = [NSImage imageNamed: @"ComputeSize_dimm.tiff"];
			[calculateButt setEnabled: NO];		
		}
		[calculateButt setImage: image];

    [self setPermissions: perms isActive: (iamRoot || isMyFile)];

		cdate = [date dateWithCalendarFormat: nil timeZone: nil];	
		[timeDateView setDate: cdate];
		[yearlabel setStringValue: [NSString stringWithFormat: @"%d", [cdate yearOfCommonEra]]];

	} else {	   // Multiple Selection
	
		ftype = [attributes objectForKey: NSFileType];
		fsize = @"";
		usr = [attributes objectForKey: NSFileOwnerAccountName];
		grp = [attributes objectForKey: NSFileGroupOwnerAccountName];
		date = [attributes objectForKey: NSFileModificationDate];
		perms = [[attributes objectForKey: NSFilePosixPermissions] intValue];			

		sameOwner = YES;
		sameGroup = YES;
		
		for (i = 0; i < [insppaths count]; i++) {
			fpath = [insppaths objectAtIndex: i];
			attrs = [fm fileAttributesAtPath: fpath traverseLink: NO];
			tmpusr = [attrs objectForKey: NSFileOwnerAccountName];
			if ([tmpusr isEqualToString: usr] == NO) {
				sameOwner = NO;
			}
			tmpgrp = [attrs objectForKey: NSFileGroupOwnerAccountName];
			if ([tmpgrp isEqualToString: grp] == NO) {
				sameGroup = NO;
			}
			tmpdate = [date earlierDate: [attrs objectForKey: NSFileModificationDate]];
		}
		
		if(!sameOwner) {
			usr = @"-";
		}
		if(!sameGroup) {
			grp = @"-";
		}

	#ifdef __WIN32__
		iamRoot = YES;
	#else
		iamRoot = (geteuid() == 0);
	#endif

		isMyFile = ([NSUserName() isEqualToString: usr]);
		
		cdate = [tmpdate dateWithCalendarFormat: nil timeZone: nil];	
				
		[linkToLabel setTextColor: [NSColor grayColor]];		
		[linkToField setStringValue: @""];

		[sizeField setStringValue: fsize]; 
		[ownerField setStringValue: usr]; 
		[groupField setStringValue: grp]; 

    image = [NSImage imageNamed: @"ComputeSize.tiff"];
		[calculateButt setEnabled: YES];
		[calculateButt setImage: image];

		[self setPermissions: 0 isActive: (iamRoot || isMyFile)];
		
		cdate = [date dateWithCalendarFormat: nil timeZone: nil];	
		[timeDateView setDate: cdate];
		[yearlabel setStringValue: [NSString stringWithFormat: @"%d", [cdate yearOfCommonEra]]];	
	}
	
	[inspBox setNeedsDisplay: YES];
}

- (void)showPasteboardData:(NSData *)data 
                    ofType:(NSString *)type
{
}

- (void)deactivate
{
  [inspBox removeFromSuperview];
}

- (NSString *)inspname
{
	return NSLocalizedString(@"Attributes", @"");
}

- (NSString *)winname
{
	return NSLocalizedString(@"Attributes Inspector", @"");
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

- (IBAction)computeSize:(id)sender
{							
	NSImage *image;
	float dirsize;
	int fsize, i;
	
	[calculateButt setEnabled: NO];	
	dirsize = 0;

 	for(i = 0; i < [insppaths count]; i++) {
		NSString *path, *filePath;
		NSDictionary *fileAttrs;
		BOOL isdir;
		
		path = [insppaths objectAtIndex: i];
		[fm fileExistsAtPath: path isDirectory: &isdir];
		 
		if (isdir) {
			NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: path];
			
			while((filePath = [enumerator nextObject])) {
				filePath = [path stringByAppendingPathComponent: filePath];
				fileAttrs = [fm fileAttributesAtPath: filePath traverseLink: NO];
				if(fileAttrs != nil) {
					fsize = [[fileAttrs objectForKey: NSFileSize] intValue];
					dirsize += fsize;
				}
			}
			
		} else {
			fileAttrs = [fm fileAttributesAtPath: path traverseLink: NO];
			if (fileAttrs != nil) {
				fsize = [[fileAttrs objectForKey: NSFileSize] intValue];
				dirsize += fsize;
			}
		}
	}	
		
	[sizeField setStringValue: fileSizeDescription(dirsize)]; 
  image = [NSImage imageNamed: @"ComputeSize_dimm.tiff"];  
	[calculateButt setImage: image];
	[inspBox setNeedsDisplay: YES];
}

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

- (IBAction)changePermissions:(id)sender
{
	NSMutableDictionary *attrs;
	NSString *fpath;
	int oldperms, newperms, i;
	
	if (pathscount == 1) {	
		oldperms = [[attributes objectForKey: NSFilePosixPermissions] intValue];
		newperms = [self getPermissions: oldperms];		
		attrs = [attributes mutableCopy];
		[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
		[fm changeFileAttributes: attrs atPath: currentPath];	
		RELEASE (attrs);	
		ASSIGN (attributes, [fm fileAttributesAtPath: currentPath traverseLink: NO]);
		newperms = [[attributes objectForKey: NSFilePosixPermissions] intValue];				
		[self setPermissions: newperms isActive: YES];
				
	} else {	
		for(i = 0; i < [insppaths count]; i++) {
			fpath = [insppaths objectAtIndex: i];
			attrs = [[fm fileAttributesAtPath: fpath traverseLink: NO] mutableCopy];
			oldperms = [[attrs objectForKey: NSFilePosixPermissions] intValue];	
			newperms = [self getPermissions: oldperms];			
			[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
			[fm changeFileAttributes: attrs atPath: fpath];
			RELEASE (attrs);
		}		
		ASSIGN (attributes, [fm fileAttributesAtPath: currentPath traverseLink: NO]);
		[self setPermissions: 0 isActive: YES];
	}

	[okButt setEnabled: NO];
	[revertButt setEnabled: NO];
	[inspBox setNeedsDisplay: YES];
	
	[[NSNotificationCenter defaultCenter]
 				postNotificationName: GWDidSetFileAttributesNotification
	 					  object: [currentPath stringByDeletingLastPathComponent]];
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

	#ifndef __WIN32__
		[greadbutt setEnabled: NO];						
		[gwritebutt setEnabled: NO];						
		[oreadbutt setEnabled: NO];						
		[owritebutt setEnabled: NO];	
	#endif
						
	} else {
		[ureadbutt setEnabled: YES];						
		[uwritebutt setEnabled: YES];						
	
	#ifndef __WIN32__
		[greadbutt setEnabled: YES];						
		[gwritebutt setEnabled: YES];						
		[oreadbutt setEnabled: YES];						
		[owritebutt setEnabled: YES];						
	#endif
	}
		
	if (perms == 0) {
		multiplePaths = YES;
		[ureadbutt setImage: multipleImage];
		[ureadbutt setState: NSOffState];
		[uwritebutt setImage: multipleImage];
		[uwritebutt setState: NSOffState];

	#ifndef __WIN32__
		[greadbutt setImage: multipleImage];
		[greadbutt setState: NSOffState];
		[gwritebutt setImage: multipleImage];
		[gwritebutt setState: NSOffState];
		[oreadbutt setImage: multipleImage];
		[oreadbutt setState: NSOffState];
		[owritebutt setImage: multipleImage];
		[owritebutt setState: NSOffState];
	#endif
	
		return;
	} else {
		multiplePaths = NO;
		[ureadbutt setImage: offImage];
		[uwritebutt setImage: offImage];

	#ifndef __WIN32__
		[greadbutt setImage: offImage];
		[gwritebutt setImage: offImage];
		[oreadbutt setImage: offImage];
		[owritebutt setImage: offImage];
	#endif
	
	}

	SET_BUTTON_STATE (ureadbutt, S_IRUSR);				
	SET_BUTTON_STATE (uwritebutt, S_IWUSR);

#ifndef __WIN32__
	SET_BUTTON_STATE (greadbutt, S_IRGRP);
	SET_BUTTON_STATE (gwritebutt, S_IWGRP);
	SET_BUTTON_STATE (oreadbutt, S_IROTH);
	SET_BUTTON_STATE (owritebutt, S_IWOTH);
#endif
}

- (int)getPermissions:(int)oldperms
{
	int perms = 0;

	GET_BUTTON_STATE (ureadbutt, S_IRUSR);
	GET_BUTTON_STATE (uwritebutt, S_IWUSR);

	if ((oldperms & S_IXUSR) == S_IXUSR) perms |= S_IXUSR;	
	
#ifndef __WIN32__
	if ((oldperms & S_ISUID) == S_ISUID) perms |= S_ISUID;

	GET_BUTTON_STATE (greadbutt, S_IRGRP);
	GET_BUTTON_STATE (gwritebutt, S_IWGRP);

	if ((oldperms & S_IXGRP) == S_IXGRP) perms |= S_IXGRP;		
	if ((oldperms & S_ISGID) == S_ISGID) perms |= S_ISGID;

	GET_BUTTON_STATE (oreadbutt, S_IROTH);
	GET_BUTTON_STATE (owritebutt, S_IWOTH);
	
	if ((oldperms & S_IXOTH) == S_IXOTH) perms |= S_IXOTH;
	if ((oldperms & S_ISVTX) == S_ISVTX) perms |= S_ISVTX;
#endif

	return perms;
}

@end
