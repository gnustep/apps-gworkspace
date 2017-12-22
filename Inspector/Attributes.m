/* Attributes.m
 *  
 * Copyright (C) 2004-2016 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
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

#include <math.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "Attributes.h"
#import "Inspector.h"
#import "IconView.h"
#import "TimeDateView.h"
#import "Functions.h"
#import "FSNodeRep.h"

#define SINGLE 0
#define MULTIPLE 1

#ifdef __WIN32__
	#define S_IRUSR _S_IRUSR
	#define S_IWUSR _S_IWUSR
	#define S_IXUSR _S_IXUSR
#endif

#define ICNSIZE 48

static NSString *nibName = @"Attributes";

static BOOL sizeStop = NO;

@implementation Attributes

- (void)dealloc
{
  [nc removeObserver: self];  
  DESTROY (sizerConn);
  DESTROY (sizer);
  RELEASE (mainBox);
  RELEASE (calculateButt);
  RELEASE (insppaths);
  RELEASE (attributes);
  RELEASE (currentPath);
  RELEASE (onImage);
  RELEASE (offImage);
  RELEASE (multipleImage);  
  
  [super dealloc];
}

- (id)initForInspector:(id)insp
{
  self = [super init];
  
  if (self) {
    NSBundle *bundle = [NSBundle bundleForClass: [insp class]];
    NSString *imagepath;

    if ([NSBundle loadNibNamed: nibName owner: self] == NO) {
      NSLog(@"failed to load %@!", nibName);
      DESTROY (self);
      return self;
    } 

    RETAIN (mainBox);
    RELEASE (win);

    inspector = insp;
    [iconView setInspector: inspector];
		insppaths = nil;
		attributes = nil;    
    currentPath = nil;
    sizer = nil;
    
    fm = [NSFileManager defaultManager];	
    nc = [NSNotificationCenter defaultCenter];
    
    autocalculate = [[NSUserDefaults standardUserDefaults] boolForKey: @"auto_calculate_sizes"];
    RETAIN (calculateButt);
    
    if (autocalculate) {
      [calculateButt removeFromSuperview];
    }
        
    imagepath = [bundle pathForResource: @"switchOn" ofType: @"tiff"];
    onImage = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    imagepath = [bundle pathForResource: @"switchOff" ofType: @"tiff"];
    offImage = [[NSImage alloc] initWithContentsOfFile: imagepath]; 
    imagepath = [bundle pathForResource: @"switchMultiple" ofType: @"tiff"];
    multipleImage = [[NSImage alloc] initWithContentsOfFile: imagepath]; 

    [ureadbutt setImage: offImage];
    [ureadbutt setAlternateImage: onImage];           
    [ureadbutt setTag: SINGLE];           
    [greadbutt setImage: offImage];
    [greadbutt setAlternateImage: onImage]; 
    [greadbutt setTag: SINGLE];               
    [oreadbutt setImage: offImage];
    [oreadbutt setAlternateImage: onImage];  
    [oreadbutt setTag: SINGLE];             
    [uwritebutt setImage: offImage];
    [uwritebutt setAlternateImage: onImage]; 
    [uwritebutt setTag: SINGLE];              
    [gwritebutt setImage: offImage];
    [gwritebutt setAlternateImage: onImage]; 
    [gwritebutt setTag: SINGLE];              
    [owritebutt setImage: offImage];
    [owritebutt setAlternateImage: onImage]; 
    [owritebutt setTag: SINGLE];              
    [uexebutt setImage: offImage];
    [uexebutt setAlternateImage: onImage];   
    [uexebutt setTag: SINGLE];             
    [gexebutt setImage: offImage];
    [gexebutt setAlternateImage: onImage];   
    [gexebutt setTag: SINGLE];             
    [oexebutt setImage: offImage];
    [oexebutt setAlternateImage: onImage];     
    [oexebutt setTag: SINGLE];       

    [revertButt setEnabled: NO];
    [okButt setEnabled: NO];
  
    /* Internationalization */
    [linkToLabel setStringValue: NSLocalizedString(@"Link to:", @"")];
    [sizeLabel setStringValue: NSLocalizedString(@"Size:", @"")];
    [calculateButt setTitle: NSLocalizedString(@"Calculate", @"")];
    [ownerLabel setStringValue: NSLocalizedString(@"Owner:", @"")];
    [groupLabel setStringValue: NSLocalizedString(@"Group:", @"")];
    [changedDateBox setTitle: NSLocalizedString(@"Changed", @"")];
    [permsBox setTitle: NSLocalizedString(@"Permissions", @"")];
    [readLabel setStringValue: NSLocalizedString(@"Read", @"")];
    [writeLabel setStringValue: NSLocalizedString(@"Write", @"")];
    [executeLabel setStringValue: NSLocalizedString(@"Execute", @"")];
    [uLabel setStringValue: NSLocalizedString(@"Owner_short", @"")];
    [gLabel setStringValue: NSLocalizedString(@"Group", @"")];
    [oLabel setStringValue: NSLocalizedString(@"Other", @"")];
    [insideButt setTitle: NSLocalizedString(@"also apply to files inside selection", @"")];
    [revertButt setTitle: NSLocalizedString(@"Revert", @"")];
    [okButt setTitle: NSLocalizedString(@"OK", @"")];
  } 
		
  return self;
}

- (NSView *)inspView
{
  return mainBox;
}

- (NSString *)winname
{
  return NSLocalizedString(@"Attributes Inspector", @"");
}

- (void)activateForPaths:(NSArray *)paths
{
  NSString *fpath;
  NSString *ftype;
  NSString *usr, *grp, *tmpusr, *tmpgrp;
  NSDate *date;
  NSCalendarDate *cdate;
  NSDictionary *attrs;
  unsigned long perms;
  BOOL sameOwner, sameGroup;
  int i;

  sizeStop = YES;

  if (paths == nil) {
    DESTROY (insppaths);
    return;
  }
  	
  attrs = [fm fileAttributesAtPath: [paths objectAtIndex: 0] traverseLink: NO];

  ASSIGN (insppaths, paths);
  pathscount = [insppaths count];	
  ASSIGN (currentPath, [paths objectAtIndex: 0]);		
  ASSIGN (attributes, attrs);	

  [revertButt setEnabled: NO];
  [okButt setEnabled: NO];
  	
  if (pathscount == 1)
    { /* Single Selection */

      FSNode *node = [FSNode nodeWithPath: currentPath];
      NSImage *icon = [[FSNodeRep sharedInstance] iconOfSize: ICNSIZE forNode: node];
      
      [iconView setImage: icon];
      [titleField setStringValue: [node name]];
      
      usr = [attributes objectForKey: NSFileOwnerAccountName];
      grp = [attributes objectForKey: NSFileGroupOwnerAccountName];
      date = [attributes objectForKey: NSFileModificationDate];
      perms = [[attributes objectForKey: NSFilePosixPermissions] unsignedLongValue];			
      
#ifdef __WIN32__
      iamRoot = YES;
#else
      iamRoot = (geteuid() == 0);
#endif
      
      isMyFile = ([NSUserName() isEqual: usr]);
      
      [insideButt setState: NSOffState];
      
      ftype = [attributes objectForKey: NSFileType];
      if ([ftype isEqual: NSFileTypeDirectory] == NO)
        {	
          NSString *fsize = fsDescription([[attributes objectForKey: NSFileSize] unsignedLongLongValue]);
          [sizeField setStringValue: fsize]; 
          [calculateButt setEnabled: NO];
          [insideButt	setEnabled: NO];
        }
      else
        {
          [sizeField setStringValue: @"--"]; 
          
          if (autocalculate)
            {
              if (sizer == nil)
                [self startSizer];
              else
                [sizer computeSizeOfPaths: insppaths];
            }
          else
            {
              [calculateButt setEnabled: YES];
            }
          
          [insideButt	setEnabled: YES];
        }
      
                
      if ([ftype isEqual: NSFileTypeSymbolicLink])
        {
          NSString *s;

          s = [fm pathContentOfSymbolicLinkAtPath: currentPath];
          s = relativePathFit(linkToField, s);
          [linkToField setStringValue: s];
          [linkToLabel setTextColor: [NSColor blackColor]];		
          [linkToField setTextColor: [NSColor blackColor]];		      
        }
      else
        {
          [linkToField setStringValue: @""];
          [linkToLabel setTextColor: [NSColor darkGrayColor]];		
          [linkToField setTextColor: [NSColor darkGrayColor]];		
        }
      
      [ownerField setStringValue: usr]; 
      [groupField setStringValue: grp]; 
      
      [self setPermissions: perms isActive: (iamRoot || isMyFile)];
      
      cdate = [date dateWithCalendarFormat: nil timeZone: nil];	
      [timeDateView setDate: cdate];
      
    }
  else
    { /* Multiple Selection */
      NSImage *icon = [[FSNodeRep sharedInstance] multipleSelectionIconOfSize: ICNSIZE];
      NSString *items = NSLocalizedString(@"items", @"");
      
      items = [NSString stringWithFormat: @"%lu %@", (unsigned long)[paths count], items];
      [titleField setStringValue: items];  
      [iconView setImage: icon];
  
      [attributes objectForKey: NSFileType];
      
      [sizeField setStringValue: @"--"]; 
      
      if (autocalculate)
        {
          if (sizer == nil)
            [self startSizer];
          else
            [sizer computeSizeOfPaths: insppaths];
        }
      else
        {
          [calculateButt setEnabled: YES];
        }
    
      usr = [attributes objectForKey: NSFileOwnerAccountName];
      grp = [attributes objectForKey: NSFileGroupOwnerAccountName];
      date = [attributes objectForKey: NSFileModificationDate];		

      sameOwner = YES;
      sameGroup = YES;
		
      for (i = 0; i < [insppaths count]; i++)
        {
          fpath = [insppaths objectAtIndex: i];
          attrs = [fm fileAttributesAtPath: fpath traverseLink: NO];
          tmpusr = [attrs objectForKey: NSFileOwnerAccountName];
          if ([tmpusr isEqualToString: usr] == NO)
            sameOwner = NO;
          tmpgrp = [attrs objectForKey: NSFileGroupOwnerAccountName];
          if ([tmpgrp isEqualToString: grp] == NO)
            sameGroup = NO;
        }
      
      if(sameOwner == NO)
        usr = @"-";

      if(sameGroup == NO)
        grp = @"-";

      
#ifdef __WIN32__
      iamRoot = YES;
#else
      iamRoot = (geteuid() == 0);
#endif
                
      isMyFile = ([NSUserName() isEqualToString: usr]);	
				
      [linkToLabel setTextColor: [NSColor darkGrayColor]];		
      [linkToField setStringValue: @""];

      [ownerField setStringValue: usr]; 
      [groupField setStringValue: grp]; 
    
      [insideButt setEnabled: YES];
    
      [self setPermissions: 0 isActive: (iamRoot || isMyFile)];
		
      cdate = [date dateWithCalendarFormat: nil timeZone: nil];	
      [timeDateView setDate: cdate];
    }
	
  [mainBox setNeedsDisplay: YES];
}

- (IBAction)permsButtonsAction:(id)sender
{
	if (multiplePaths == YES) {
		if ([sender state] == NSOffState) {
			if ([sender tag] == MULTIPLE) {
				[sender setImage: offImage];	
				[sender setTag: SINGLE];	
      }
		} else {
			if ([sender tag] == SINGLE) {
				[sender setImage: multipleImage];
				[sender setTag: MULTIPLE];	
			}
		}
	}	

	if ((iamRoot || isMyFile) == NO) {
		return;
	}

	[revertButt setEnabled: YES];	
	[okButt setEnabled: YES];
}

- (IBAction)insideButtonAction:(id)sender
{
  [okButt setEnabled: YES];
}

- (IBAction)changePermissions:(id)sender
{
	NSMutableDictionary *attrs;
	NSDirectoryEnumerator *enumerator;	
	NSString *path, *fpath;
	unsigned long oldperms, newperms;
  int i;
	BOOL isdir;
	BOOL recursive;
  
  recursive = ([insideButt isEnabled] && ([insideButt state] == NSOnState));
  
	if (pathscount == 1) {
		oldperms = [[attributes objectForKey: NSFilePosixPermissions] unsignedLongValue];
		newperms = [self getPermissions: oldperms];		
		attrs = [attributes mutableCopy];
		[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
		[fm changeFileAttributes: attrs atPath: currentPath];	
    RELEASE (attrs);

		[fm fileExistsAtPath: currentPath isDirectory: &isdir];

		if (isdir && recursive) {
			enumerator = [fm enumeratorAtPath: currentPath];
      
      while ((fpath = [enumerator nextObject])) {
        CREATE_AUTORELEASE_POOL(arp);  
      
				fpath = [currentPath stringByAppendingPathComponent: fpath];
				attrs = [[fm fileAttributesAtPath: fpath traverseLink: NO] mutableCopy];
				oldperms = [[attrs objectForKey: NSFilePosixPermissions] unsignedLongValue];	
				newperms = [self getPermissions: oldperms];			
				[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
				[fm changeFileAttributes: attrs atPath: fpath];
        RELEASE (attrs);
        
        RELEASE (arp);
      }
                  
			ASSIGN (attributes, [fm fileAttributesAtPath: currentPath traverseLink: NO]);	
			[self setPermissions: 0 isActive: YES];

		} else {
			ASSIGN (attributes, [fm fileAttributesAtPath: currentPath traverseLink: NO]);	
			newperms = [[attributes objectForKey: NSFilePosixPermissions] unsignedLongValue];				
			[self setPermissions: newperms isActive: YES];
		}
	
	} else {
		for (i = 0; i < [insppaths count]; i++) {
			path = [insppaths objectAtIndex: i];			
 			attrs = [[fm fileAttributesAtPath: path traverseLink: NO] mutableCopy];
			oldperms = [[attrs objectForKey: NSFilePosixPermissions] unsignedLongValue];	
			newperms = [self getPermissions: oldperms];			
			[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
			[fm changeFileAttributes: attrs atPath: path];	
      RELEASE (attrs);			

			[fm fileExistsAtPath: path isDirectory: &isdir];
     
			if (isdir && recursive) {
				enumerator = [fm enumeratorAtPath: path];
        
        while ((fpath = [enumerator nextObject])) {
          CREATE_AUTORELEASE_POOL(arp);  

					fpath = [path stringByAppendingPathComponent: fpath];
					attrs = [[fm fileAttributesAtPath: fpath traverseLink: NO] mutableCopy];
					oldperms = [[attrs objectForKey: NSFilePosixPermissions] unsignedLongValue];	
					newperms = [self getPermissions: oldperms];			
					[attrs setObject: [NSNumber numberWithInt: newperms] forKey: NSFilePosixPermissions];
					[fm changeFileAttributes: attrs atPath: fpath];
					RELEASE (attrs);

          RELEASE (arp);
        }
			}
		}
		
		ASSIGN (attributes, [fm fileAttributesAtPath: currentPath traverseLink: NO]);	
		[self setPermissions: 0 isActive: YES];
	}

	[okButt setEnabled: NO];
	[revertButt setEnabled: NO];
}

- (IBAction)revertToOldPermissions:(id)sender
{
	if(pathscount == 1) {
		unsigned long perms = [[attributes objectForKey: NSFilePosixPermissions] unsignedLongValue];
		[self setPermissions: perms isActive: YES];	
	} else {
		[self setPermissions: 0 isActive: YES];
	}
	
	[revertButt setEnabled: NO];
	[okButt setEnabled: NO];
}

- (void)setPermissions:(unsigned long)perms 
              isActive:(BOOL)active
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
    [ureadbutt setTag: MULTIPLE];           
		[uwritebutt setImage: multipleImage];
		[uwritebutt setState: NSOffState];
    [uwritebutt setTag: MULTIPLE];               
		[uexebutt setImage: multipleImage];
		[uexebutt setState: NSOffState];	
    [uexebutt setTag: MULTIPLE];           

	#ifndef __WIN32__
		[greadbutt setImage: multipleImage];
		[greadbutt setState: NSOffState];
    [greadbutt setTag: MULTIPLE];               
		[gwritebutt setImage: multipleImage];
		[gwritebutt setState: NSOffState];
    [gwritebutt setTag: MULTIPLE];               
		[gexebutt setImage: multipleImage];
		[gexebutt setState: NSOffState];
    [gexebutt setTag: MULTIPLE];               
		[oreadbutt setImage: multipleImage];
		[oreadbutt setState: NSOffState];
    [oreadbutt setTag: MULTIPLE];               
		[owritebutt setImage: multipleImage];
		[owritebutt setState: NSOffState];
    [owritebutt setTag: MULTIPLE];               
		[oexebutt setImage: multipleImage];
		[oexebutt setState: NSOffState];
    [oexebutt setTag: MULTIPLE];           
	#endif
	
		return;
	} else {
		multiplePaths = NO;
		[ureadbutt setImage: offImage];
    [ureadbutt setTag: SINGLE];               
		[uwritebutt setImage: offImage];
    [uwritebutt setTag: SINGLE];               
		[uexebutt setImage: offImage];	
    [uexebutt setTag: SINGLE];           

	#ifndef __WIN32__
		[greadbutt setImage: offImage];
    [greadbutt setTag: SINGLE];               
		[gwritebutt setImage: offImage];
    [gwritebutt setTag: SINGLE];               
		[gexebutt setImage: offImage];
    [gexebutt setTag: SINGLE];               
		[oreadbutt setImage: offImage];
    [oreadbutt setTag: SINGLE];               
		[owritebutt setImage: offImage];
    [owritebutt setTag: SINGLE];               
		[oexebutt setImage: offImage];
    [oexebutt setTag: SINGLE];           
    
	#endif
	}

#define SET_BUTTON_STATE(b, v) { \
if ((perms & v) == v) [b setState: NSOnState]; \
else [b setState: NSOffState]; \
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

- (unsigned long)getPermissions:(unsigned long)oldperms
{
	unsigned long perms = 0;

#define GET_BUTTON_STATE(b, v) { \
if ([b state] == NSOnState) { \
perms |= v; \
} else { \
if ((oldperms & v) == v) { \
if ([b tag] == MULTIPLE) perms |= v; \
} } \
}

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

- (void)watchedPathDidChange:(NSDictionary *)info
{
}

- (void)setCalculateSizes:(BOOL)value
{
  autocalculate = value;
  
  if (autocalculate) {
    if ([calculateButt superview]) {
      [calculateButt removeFromSuperview];
    }
  } else {
    if ([calculateButt superview] == nil) {
      [mainBox addSubview: calculateButt];
    }
  }
}

- (IBAction)calculateSizes:(id)sender
{
  if (sizer == nil) {
    [self startSizer];
  } else {
    [sizeField setStringValue: @"--"]; 
    [sizer computeSizeOfPaths: insppaths];
  }
  [calculateButt setEnabled: NO];
}

- (void)startSizer
{
  NSPort *port[2];  
  NSArray *portArray;

  port[0] = (NSPort *)[NSPort port];
  port[1] = (NSPort *)[NSPort port];
  portArray = [NSArray arrayWithObjects: port[1], port[0], nil];

  sizerConn = [[NSConnection alloc] initWithReceivePort: (NSPort *)port[0]
                                               sendPort: (NSPort *)port[1]];
  [sizerConn setRootObject: self];
  [sizerConn setDelegate: self];
  [sizerConn enableMultipleThreads];

  [nc addObserver: self 
				 selector: @selector(sizerConnDidDie:)
	    			 name: NSConnectionDidDieNotification 
           object: sizerConn];

  NS_DURING
  {
    [NSThread detachNewThreadSelector: @selector(createSizerWithPorts:)
                             toTarget: [Sizer class]
                           withObject: portArray];
  }
  NS_HANDLER
  {
    NSLog(@"Error! A fatal error occurred while detaching the thread.");
  }
  NS_ENDHANDLER
}

- (void)sizerConnDidDie:(NSNotification *)notification
{
  id diedconn = [notification object];

  if (diedconn == sizerConn)
    {
      [nc removeObserver: self
		    name: NSConnectionDidDieNotification 
		  object: sizerConn];
      DESTROY (sizer);
      DESTROY (sizerConn);
      NSLog(@"sizer connection died");
    }
}

- (void)setSizer:(id)anObject
{
  if (sizer == nil) {
    [anObject setProtocolForProxy: @protocol(SizerProtocol)];
    sizer = (id <SizerProtocol>)anObject;
    RETAIN (sizer);
    if (insppaths) {
      sizeStop = YES;
      [sizeField setStringValue: @"--"];
      [sizer computeSizeOfPaths: insppaths];
    }
  }
}

- (void)sizeReady:(NSString *)sizeStr
{
	[sizeField setStringValue: sizeStr]; 
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setBool: autocalculate forKey: @"auto_calculate_sizes"];
}

@end


@implementation Sizer

- (void)dealloc
{
  [super dealloc];
}

+ (void)createSizerWithPorts:(NSArray *)portArray
{
  NSAutoreleasePool *pool;
  id attrs;
  NSConnection *conn;
  NSPort *port[2];
  Sizer *sizer;
	
  pool = [[NSAutoreleasePool alloc] init];
	  
  port[0] = [portArray objectAtIndex: 0];
  port[1] = [portArray objectAtIndex: 1];
  conn = [NSConnection connectionWithReceivePort: port[0] sendPort: port[1]];
  attrs = (id)[conn rootProxy];
  sizer = [[Sizer alloc] initWithAttributesConnection: conn];
  [attrs setSizer: sizer];
  RELEASE (sizer);
	
  [[NSRunLoop currentRunLoop] run];
  [pool release];
}

- (id)initWithAttributesConnection:(NSConnection *)conn
{
  self = [super init];
  
  if (self) {
    id attrs = (id)[conn rootProxy];
    [attrs setProtocolForProxy: @protocol(AttributesSizeProtocol)];
    attributes = (id <AttributesSizeProtocol>)attrs;
    fm = [NSFileManager defaultManager];	
  }
  
  return self;
}

- (void)computeSizeOfPaths:(NSArray *)paths
{
	unsigned long long dirsize = 0;
	unsigned long long fsize = 0;
  int i;
	
  sizeStop = NO;
  
 	for (i = 0; i < [paths count]; i++) {
    CREATE_AUTORELEASE_POOL (arp1);
		NSString *path, *filePath;
		NSDictionary *fileAttrs;
		BOOL isdir;
		
    if (sizeStop) {
      RELEASE (arp1);
      return;
    }
    
		path = [paths objectAtIndex: i];
		 
		fileAttrs = [fm fileAttributesAtPath: path traverseLink: NO];
		if (fileAttrs) {
			fsize = [[fileAttrs objectForKey: NSFileSize] unsignedLongLongValue];
			dirsize += fsize;
		}
     
		[fm fileExistsAtPath: path isDirectory: &isdir];
          
		if (isdir) {
			NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: path];
			
      while (1) {
        CREATE_AUTORELEASE_POOL (arp2);
        
        filePath = [enumerator nextObject];
      
        if (filePath) {
          if (sizeStop) {
            RELEASE (arp2);
            RELEASE (arp1);
            return;
          }
        
			    filePath = [path stringByAppendingPathComponent: filePath];
			    fileAttrs = [fm fileAttributesAtPath: filePath traverseLink: NO];
			    if (fileAttrs) {
				    fsize = [[fileAttrs objectForKey: NSFileSize] unsignedLongLongValue];
				    dirsize += fsize;
			    }
      
        } else {
          RELEASE (arp2);
          break;   
        } 
      
        RELEASE (arp2);
      }
		}
    
    RELEASE (arp1);
	}	

  if (sizeStop == NO) {
    [attributes sizeReady: fsDescription(dirsize)]; 
  }
}

@end
