/* GWRemote.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This file is part of the GNUstep GWRemote application
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
#include "GWRemote.h"
//#include "Dialogs/Dialogs.h"
#include "Preferences/PrefController.h"
#include "LoginWindow.h"
#include "ViewerWindow.h"
#include "RemoteEditor.h"
#include "FileOpProgress.h"
#include "RemoteTerminal.h"
#include "GNUstep.h"
#include <GWorkspace/GWProtocol.h>
#include <GWorkspace/GWNotifications.h>
#include <GWorkspace/GWFunctions.h>

static GWRemote *gwremote = nil;

@implementation GWRemote

#define byname 0
#define bykind 1
#define bydate 2
#define bysize 3
#define byowner 4

#define CACHED_MAX 20;

#define CELLS_WIDTH 90

+ (GWRemote *)gwremote
{
	if (gwremote == nil) {
		gwremote = [[GWRemote alloc] init];
	}	
  return gwremote;
}

+ (void)initialize
{
	static BOOL initialized = NO;
	
	if (initialized == YES) {
		return;
  }
	
	initialized = YES;
}

+ (void)registerForServices
{
	NSArray *sendTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, nil];	
	NSArray *returnTypes = [NSArray arrayWithObjects: NSFilenamesPboardType, nil];	
	[NSApp registerServicesMenuSendTypes: sendTypes returnTypes: returnTypes];
}

- (void)dealloc
{
  [dstnc removeObserver: self];
  [nc removeObserver: self];

  if (connectTimer && [connectTimer isValid]) {
    [connectTimer invalidate];
  }
  
  TEST_RELEASE (serversNames);
  RELEASE (serversDict);
  TEST_RELEASE (currentServer);
  TEST_RELEASE (userName);
  TEST_RELEASE (userPassword);  
  
  RELEASE (prefController);
  RELEASE (loginWindow);
  
  RELEASE (viewers);  
  RELEASE (cachedContents);
  RELEASE (editors);
  RELEASE (terminals);
  RELEASE (fileOpIndicators);
    
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];			
  id entry;
  
  [isa registerForServices];

  haveServersList = NO;
  
  fm = [NSFileManager defaultManager];
	ws = [NSWorkspace sharedWorkspace];
  nc = [NSNotificationCenter defaultCenter];
  dstnc = [NSDistributedNotificationCenter defaultCenter];

  serversDict = [NSMutableDictionary new];
  serversNames = [NSMutableArray new];
  currentServer = nil;
  loginServer = nil;

  viewers = [NSMutableArray new];
  cachedContents = [NSMutableDictionary new];
  editors = [NSMutableArray new];
  terminals = [NSMutableArray new];
  remoteTermRef = [NSNumber numberWithInt: 0];
  fileOpIndicators = [NSMutableArray new];
  
  prefController = [[PrefController alloc] init];  
   
	entry = [defaults objectForKey: @"serversnames"];
  if (entry && [entry count]) {
    [serversNames addObjectsFromArray: entry];    
  } else {
    [defaults setObject: serversNames forKey: @"serversnames"];
    [defaults synchronize];
    
    NSRunAlertPanel(NULL, NSLocalizedString(@"No gwsd server defined!\n\
You must choose one from the preferences!", @""),
                                  NSLocalizedString(@"OK", @""), NULL, NULL);   
    [prefController activateServerPref];
    [self showPreferences: nil];
  }
  
  loginWindow = [[LoginWindow alloc] init];

  animateChdir = ![defaults boolForKey: @"nochdiranim"];
  animateLaunck = ![defaults boolForKey: @"nolaunchanim"];
  animateSlideBack = ![defaults boolForKey: @"noslidebackanim"];  

  showFileOpStatus = [defaults boolForKey: @"showfopstatus"];
  
	entry = [defaults objectForKey: @"shelfcellswidth"];
	if (entry == nil) {
    shelfCellsWidth = CELLS_WIDTH;
	} else {
    shelfCellsWidth = [entry intValue];
  }
  
  entry = [defaults objectForKey: @"cachedmax"];
  if (entry) {
    cachedMax = [entry intValue];
  } else {  
    cachedMax = CACHED_MAX;
  }  
}

- (BOOL)applicationShouldTerminate:(NSApplication *)app 
{
	int i;

#define TEST_CLOSE(o, w) if ((o) && ([w isVisible])) [w close]

  for (i = 0; i < [editors count]; i++) {
    if ([[editors objectAtIndex: i] isEdited]) {
      unsigned result = NSRunAlertPanel(NSLocalizedString(@"Alert", @""),
				          NSLocalizedString(@"There are remote edited files.\n\
Do you want to save them?", @""), 
								  NSLocalizedString(@"Ok", @""), 
                  NSLocalizedString(@"No", @""), 
                  NULL);

		  if (result == NSAlertDefaultReturn) {
			  return NO;
		  } else {
        break;
      }
    }
  }

  [self updateDefaults];

	for (i = 0; i < [viewers count]; i++) {
		id vwr = [viewers objectAtIndex: i];
		TEST_CLOSE (vwr, vwr);
  }
	TEST_CLOSE (prefController, [prefController myWin]);
  		
	return YES;
}

//
// Login methods
//
- (void)serversListChanged
{
  haveServersList = YES;
}

- (void)tryLoginOnServer:(NSString *)servername 
            withUserName:(NSString *)usrname 
            userPassword:(NSString *)userpass
{
  id server;

  [[loginWindow myWin] close];  
  
  if ([serversDict objectForKey: servername]) {
    NSString *message = [NSString stringWithFormat: @"%@ %@!", 
                NSLocalizedString(@"already connected to", @""), servername];
    NSRunAlertPanel(NULL, message, NSLocalizedString(@"OK", @""), NULL, NULL);   
    return;
  }

  ASSIGN (loginServer, servername);
  ASSIGN (userName, usrname);
  ASSIGN (userPassword, userpass);

  server = [NSConnection rootProxyForConnectionWithRegisteredName: @"gwsd"  
                                                             host: servername];
  if (server != nil) {
    connectTimer = [NSTimer scheduledTimerWithTimeInterval: 10.0 target: self 
          		 selector: @selector(checkConnection:) userInfo: nil repeats: NO];                                             
    
    [server setProtocolForProxy: @protocol(GWSDProtocol)];
    server = (id <GWSDProtocol>)server;

    [server registerRemoteClient: self];          
  } else {
    NSRunAlertPanel(NULL, NSLocalizedString(@"Can't contact the server!", @""),
                                      NSLocalizedString(@"OK", @""), NULL, NULL);   
    DESTROY (loginServer);
    DESTROY (userName);
    DESTROY (userPassword);
  }
}

- (void)checkConnection:(id)sender
{
  if (loginServer != nil) {
    NSRunAlertPanel(NULL, NSLocalizedString(@"Time out contacting the server!", @""),
                                      NSLocalizedString(@"OK", @""), NULL, NULL);   
    DESTROY (loginServer);
    DESTROY (userName);
    DESTROY (userPassword);
  }
}

//
// GWSdClientProtocol
//
- (void)setServerConnection:(NSConnection *)conn
{
  id anObject;
  NSMutableDictionary *dict;

//  [conn setIndependentConversationQueueing: YES];
    
  anObject = [conn rootObject];
  [anObject setProtocolForProxy: @protocol(GWSDProtocol)];
  
  dict = [NSMutableDictionary dictionary];
  [dict setObject: loginServer forKey: @"name"];
  [dict setObject: conn forKey: @"connection"];
  [dict setObject: (id <GWSDProtocol>)anObject forKey: @"server"];

  [serversDict setObject: dict forKey: loginServer];
  
  [self readDefaultsForServer: loginServer];

  DESTROY (loginServer);
  DESTROY (userName);
  DESTROY (userPassword); 

  [[NSNotificationCenter defaultCenter] addObserver: self 
				 selector: @selector(connectionDidDie:)
	    			 name: NSConnectionDidDieNotification object: conn];
}

- (NSString *)userName
{
  return userName;
}

- (NSString *)userPassword
{
  return userPassword;
}

- (oneway void)connectionRefused
{
  NSRunAlertPanel(NULL, NSLocalizedString(@"Connection refused!", @""),
                                  NSLocalizedString(@"OK", @""), NULL, NULL);   
  DESTROY (loginServer);
  DESTROY (userName);
  DESTROY (userPassword);
}

- (int)requestUserConfirmationWithMessage:(NSString *)message 
                                    title:(NSString *)title
{
  return NSRunAlertPanel(NSLocalizedString(title, @""),
														NSLocalizedString(message, @""),
																NSLocalizedString(@"OK", @""), 
																		NSLocalizedString(@"Cancel", @""), NULL);       
}

- (int)showErrorAlertWithMessage:(NSString *)message
{
  return NSRunAlertPanel(nil, NSLocalizedString(message, @""), 
																NSLocalizedString(@"Continue", @""), nil, nil);
}

- (oneway void)showProgressForFileOperationWithName:(NSString *)name
                                         sourcePath:(NSString *)source
                                    destinationPath:(NSString *)destination
                                       operationRef:(int)ref
                                           onServer:(id)server
{
  NSString *sname = [self nameOfServer: server];
  int count = [fileOpIndicators count];
  FileOpProgress *fopProgress;
  NSRect rect;

  if (count) {
//    NSRect screct = [[NSScreen mainScreen] frame];
//      int i;
      
//    for (i = 0; i < count; i++) {
//      FileOpProgress *fopProgress = [fileOpIndicators objectAtIndex: i];
//      NSRect r = [fopProgress windowRect];
//      float w = r.size.width;
//      float h = r.size.height;
  
  
  
//    }
    
    rect = NSZeroRect;

  } else {
    rect = NSZeroRect;
  }

  fopProgress = [[FileOpProgress alloc] initWithOperationRef: ref
          operationName: name sourcePath: source destinationPath: destination
                                            serverName: sname windowRect: rect];
  [fopProgress activate];
  [fileOpIndicators addObject: fopProgress];
  RELEASE (fopProgress);  
}

- (void)endOfFileOperationWithRef:(int)ref onServer:(id)server
{
  NSString *sname = [self nameOfServer: server];

  if (sname) {
    int i;

    for (i = 0; i < [fileOpIndicators count]; i++) {
      FileOpProgress *fopProgress = [fileOpIndicators objectAtIndex: i];
  
      if ([[fopProgress serverName] isEqual: sname]
                              && ([fopProgress operationRef] == ref)) {
        [fopProgress done];
        [fileOpIndicators removeObject: fopProgress]; 
        break;                     
      }
    }
  }
}

- (oneway void)server:(id)aserver fileSystemDidChange:(NSDictionary *)info
{
  NSString *path = [info objectForKey: @"path"];
  NSString *serverName = [self nameOfServer: aserver];
  int i;

  [self removeCachedRepresentationForPath: path onServer: serverName];

  for (i = 0; i < [viewers count]; i++) {
    [[viewers objectAtIndex: i] fileSystemDidChange: info];
  }
}

- (oneway void)exitedShellTaskWithRef:(NSNumber *)ref
{
  [self _exitedShellTaskWithRef: ref];
}

- (oneway void)remoteShellWithRef:(NSNumber *)ref 
                 hasAvailableData:(NSData *)data
{
  [self _remoteShellWithRef: ref hasAvailableData: data];
}

//
// GWProtocol (GWRemote methods)
//
- (void)performFileOperationWithDictionary:(id)opdict
                            fromSourceHost:(NSString *)fromName 
                         toDestinationHost:(NSString *)toName
{
  if ([fromName isEqual: toName]) {
    id <GWSDProtocol> server = [self serverWithName: toName];

    if (server) {
      [server performLocalFileOperationWithDictionary: opdict];
    }  
  }
}

- (BOOL)server:(NSString *)serverName isPakageAtPath:(NSString *)path
{
  return NO;
}

- (BOOL)server:(NSString *)serverName fileExistsAtPath:(NSString *)path
{
  return [[self serverWithName: serverName] existsFileAtPath: path];
}

- (BOOL)server:(NSString *)serverName isWritableFileAtPath:(NSString *)path
{
  return [[self serverWithName: serverName] isWritableFileAtPath: path];
}

- (BOOL)server:(NSString *)serverName 
            existsAndIsDirectoryFileAtPath:(NSString *)path
{
  return [[self serverWithName: serverName] existsAndIsDirectoryFileAtPath: path];
}

- (NSString *)server:(NSString *)serverName typeOfFileAt:(NSString *)path
{
  return [[self serverWithName: serverName] typeOfFileAt: path];
}

- (int)server:(NSString *)serverName sortTypeForPath:(NSString *)aPath
{
  return byname;
}

- (void)server:(NSString *)serverName  
   setSortType:(int)type 
        atPath:(NSString *)aPath
{
  [[self serverWithName: serverName] setSortType: type 
                              forDirectoryAtPath: aPath];
}

- (NSArray *)server:(NSString *)serverName 
   checkHiddenFiles:(NSArray *)files 
             atPath:(NSString *)path
{
  return files;
}

- (NSArray *)server:(NSString *)serverName 
        sortedDirectoryContentsAtPath:(NSString *)path
{
  id <GWSDProtocol>server = [self serverWithName: serverName];
  
  if (server) {
    NSDictionary *contentsDict = [self cachedRepresentationForPath: path 
                                                          onServer: serverName];
    if (contentsDict) {
      return [contentsDict objectForKey: @"files"];
    }
   
    contentsDict = [server directoryContentsAtPath: path];
    
    if (contentsDict) {
      if ([self entriesInCacheOfServer: serverName] >= cachedMax) {
        [self removeOlderCachedForServer: serverName];
      }

      [self addCachedRepresentation: contentsDict
                        ofDirectory: path
                           onServer: serverName];

      return [contentsDict objectForKey: @"files"];
    }
  }
 
  return nil;
}

- (void)server:(NSString *)serverName setSelectedPaths:(NSArray *)paths
{
  NSMutableDictionary *dict = [self dictionaryForServer: serverName];

  [dict setObject: paths forKey: @"selectedPaths"];
}

- (NSArray *)selectedPathsForServerWithName:(NSString *)serverName
{
  return [[self dictionaryForServer: serverName] objectForKey: @"selectedPaths"];
}

- (NSString *)homeDirectoryForServerWithName:(NSString *)serverName
{
  NSDictionary *serverDict = [self dictionaryForServer: serverName];
  id <GWSDProtocol> server = [serverDict objectForKey: @"server"];

  return [server homeDirectory];
}

- (BOOL)server:(NSString *)serverName isLockedPath:(NSString *)aPath
{
  return NO;
}

- (void)server:(NSString *)serverName addWatcherForPath:(NSString *)path
{
  [[self serverWithName: serverName] addWatcherForPath: path];
}

- (void)server:(NSString *)serverName removeWatcherForPath:(NSString *)path
{
  [[self serverWithName: serverName] removeWatcherForPath: path];
}

- (void)server:(NSString *)serverName 
    renamePath:(NSString *)oldname 
     toNewName:(NSString *)newname
{
  [[self serverWithName: serverName] renamePath: oldname toNewName: newname];
}


//
// GWProtocol (other methods)
//
+ (id)gworkspace
{
	if (gwremote == nil) {
		gwremote = [[GWRemote alloc] init];
	}	
  return gwremote;
}

- (BOOL)performFileOperation:(NSString *)operation 
                      source:(NSString *)source 
                 destination:(NSString *)destination 
                       files:(NSArray *)files 
                         tag:(int *)tag
{
  return NO;
}

- (void)performFileOperationWithDictionary:(id)opdict
{
}

- (BOOL)application:(NSApplication *)theApplication 
           openFile:(NSString *)filename
{
  return NO;
}

- (BOOL)openFile:(NSString *)fullPath
{
  return NO;
}

- (BOOL)openFile:(NSString *)fullPath 
			 fromImage:(NSImage *)anImage 
			  			at:(NSPoint)point 
					inView:(NSView *)aView
{
  return NO;
}

- (BOOL)selectFile:(NSString *)fullPath
							inFileViewerRootedAtPath:(NSString *)rootFullpath
{
  return NO;
}

- (void)rootViewerSelectFiles:(NSArray *)paths
{
}

- (void)slideImage:(NSImage *)image 
							from:(NSPoint)fromPoint 
								to:(NSPoint)toPoint
{
	[[NSWorkspace sharedWorkspace] slideImage: image from: fromPoint to: toPoint];
}

- (void)noteFileSystemChanged
{
}

- (void)noteFileSystemChanged:(NSString *)path
{
}

- (BOOL)isPakageAtPath:(NSString *)path
{
  return NO;
}

- (int)sortTypeForDirectoryAtPath:(NSString *)aPath
{
  return 0;
}

- (void)setSortType:(int)type forDirectoryAtPath:(NSString *)aPath
{
}

- (void)openSelectedPaths:(NSArray *)paths newViewer:(BOOL)newv
{
}

- (void)openSelectedPathsWith
{
}

- (ViewersWindow *)newViewerAtPath:(NSString *)path canViewApps:(BOOL)viewapps
{
  return nil;
}

- (NSImage *)iconForFile:(NSString *)fullPath ofType:(NSString *)type
{
  NSImage *icon = nil;

  if ([type isEqual: NSDirectoryFileType] 
                || [type isEqual: NSFilesystemFileType]
                    || [type isEqual: NSApplicationFileType]) {
    icon = [self folderImage];
  } else {
    icon = [self unknownFiletypeImage];
  }

  return icon;
}

- (NSImage *)smallIconForFile:(NSString*)aPath
{
  return nil;
}

- (NSImage *)smallIconForFiles:(NSArray*)pathArray
{
  return nil;
}

- (NSImage *)smallHighlightIcon
{
  return nil;
}

- (NSArray *)getSelectedPaths
{
  return nil;
}

- (NSString *)trashPath
{
  return nil;
}

- (NSArray *)viewersSearchPaths
{
  return nil;
}

- (NSArray *)imageExtensions
{
  return nil;
}

- (void)lockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path
{
}

- (void)unLockFiles:(NSArray *)files inDirectoryAtPath:(NSString *)path
{
}

- (BOOL)isLockedPath:(NSString *)path
{
  return NO;
}

- (void)addWatcherForPath:(NSString *)path
{
}

- (void)removeWatcherForPath:(NSString *)path
{
}

- (BOOL)hideSysFiles
{
  return NO;
}

- (BOOL)animateChdir
{
  return YES;
}

- (BOOL)animateLaunck
{
  return NO;
}

- (BOOL)animateSlideBack
{
  return YES;
}

//
// GWProtocol end
//

- (void)readDefaultsForServer:(NSString *)serverName
{
  NSMutableDictionary *dict = [self dictionaryForServer: serverName];
  id <GWSDProtocol> server = [dict objectForKey: @"server"];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray *viewersPaths = nil;
  id sdict = [defaults objectForKey: serverName];
  int i, count;
  
  if (sdict) {
    NSMutableDictionary *serverPrefs = [sdict mutableCopy];
    NSMutableDictionary *viewersPrefs;
  	NSArray *keys;
    id entry;
    
	  entry = [serverPrefs objectForKey: @"defaultsorttype"];	
	  if (entry == nil) { 
		  [serverPrefs setObject: [NSNumber numberWithInt: byname]
                      forKey: @"defaultsorttype"];
      [dict setObject: [NSNumber numberWithInt: byname]
               forKey: @"defaultsorttype"];
	  } else {
      [dict setObject: [NSNumber numberWithInt: [entry intValue]]
               forKey: @"defaultsorttype"];
	  }

    entry = [serverPrefs objectForKey: @"GSFileBrowserHideDotFiles"];
    if (entry) {
      [dict setObject: [NSNumber numberWithBool: [entry boolValue]]
               forKey: @"GSFileBrowserHideDotFiles"];
    } else {  
      NSDictionary *domain = [defaults persistentDomainForName: NSGlobalDomain];

      entry = [domain objectForKey: @"GSFileBrowserHideDotFiles"];
      if (entry) {
        [dict setObject: [NSNumber numberWithBool: [entry boolValue]]
                 forKey: @"GSFileBrowserHideDotFiles"];
      } else {  
        [dict setObject: [NSNumber numberWithBool: NO]
                 forKey: @"GSFileBrowserHideDotFiles"];
      }
    }

	  entry = [serverPrefs objectForKey: @"viewersprefs"];
	  if (entry) { 
		  viewersPrefs = [entry mutableCopy];
	  } else {
		  viewersPrefs = [NSMutableDictionary new];
	  }
	  keys = [viewersPrefs allKeys];
    for (i = 0; i < [keys count]; i++) {
		  NSString *key = [keys objectAtIndex: i];	

      if ([key isEqual: @"rootViewer"] == NO) {
		    if([server existsAndIsDirectoryFileAtPath: key] == NO) {
          [viewersPrefs removeObjectForKey: key];
        }
      }
    }  
	  [serverPrefs setObject: viewersPrefs forKey: @"viewersprefs"];
	  RELEASE (viewersPrefs);

	  entry = [serverPrefs objectForKey: @"viewerspaths"];
	  if (entry == nil) {
		  viewersPaths = [NSMutableArray new];
	  } else {
		  viewersPaths = [entry mutableCopy];
    }
    count = [viewersPaths count];
    for (i = 0; i < count; i++) {
      NSString *path = [viewersPaths objectAtIndex: i];
      
		  if([server existsAndIsDirectoryFileAtPath: path] == NO) {
        [viewersPaths removeObjectAtIndex: i];
        i--;
        count--;
      }
    }  
	  [serverPrefs setObject: viewersPaths forKey: @"viewerspaths"];
    
    [defaults setObject: serverPrefs forKey: serverName];
    RELEASE (serverPrefs);
  } else {
    [dict setObject: [NSNumber numberWithInt: byname]
             forKey: @"defaultsorttype"];
  
    [dict setObject: [NSNumber numberWithBool: NO]
             forKey: @"GSFileBrowserHideDotFiles"];
  
    [defaults setObject: [NSDictionary dictionary] forKey: serverName];
  }
  
  [defaults synchronize];
    
  [dict setObject: [NSArray arrayWithObject: [server homeDirectory]]
           forKey: @"selectedPaths"];
  
  [dict setObject: [NSMutableArray array]
           forKey: @"lockedPaths"];
    
  [dict setObject: [NSMutableArray array]
           forKey: @"watchedpaths"];

  starting = YES;   
  currentServer = serverName; 	
  rootViewer = nil;
  [self showViewer: nil];
  
  if (viewersPaths) {  
    for (i = 0; i < [viewersPaths count]; i++) {
      NSString *path = [viewersPaths objectAtIndex: i]; 
      
      if ([path isEqual: fixPath(@"/", 0)] == NO) {
        BOOL canView = ([server isPakageAtPath: path] ? YES : NO);
    
        [self server: serverName newViewerAtPath: path canViewApps: canView];
      }
    }
    
    RELEASE (viewersPaths);
  }
  
  starting = NO;
}

- (NSMutableDictionary *)dictionaryForServer:(NSString *)serverName
{
  return [serversDict objectForKey: serverName];
}

- (id <GWSDProtocol>)serverWithName:(NSString *)serverName
{
  NSDictionary *serverDict = [self dictionaryForServer: serverName];
  id <GWSDProtocol> server = [serverDict objectForKey: @"server"];

  return server;
}

- (id <GWSDProtocol>)serverWithConnection:(NSConnection *)conn
{
  NSArray *names = [serversDict allKeys];
  int i;
  
  for (i = 0; i < [names count]; i++) { 
    NSString *name = [names objectAtIndex: i];
    NSDictionary *dict = [serversDict objectForKey: name];
    id <GWSDProtocol> server = [dict objectForKey: @"server"];
    NSConnection *connection = [dict objectForKey: @"connection"];
    
    if (connection == conn) {
      return server;
    }
  }
  
  return nil;
}

- (NSString *)nameOfServer:(id)server
{
  NSArray *names = [serversDict allKeys];
  int i;
  
  for (i = 0; i < [names count]; i++) { 
    NSString *name = [names objectAtIndex: i];
    NSDictionary *dict = [serversDict objectForKey: name];
    id srwr = [dict objectForKey: @"server"];
    
    if (srwr == server) {
      return name;
    }
  }
  
  return nil;
}

- (NSArray *)viewersOfServer:(NSString *)serverName
{
  NSMutableArray *vwrs = [NSMutableArray array];
  int i;
  
  for (i = 0; i < [viewers count]; i++) {
    ViewerWindow *viewer = [viewers objectAtIndex: i];

    if ([[viewer serverName] isEqual: serverName]) {
      [vwrs addObject: viewer];
    }
  }
  
  if ([vwrs count]) {
    return vwrs;
  }
  
  return nil;
}

- (NSDictionary *)server:(NSString *)serverName 
            fileSystemAttributesAtPath:(NSString *)path
{
  return [[self serverWithName: serverName] fileSystemAttributesAtPath: path];
}

- (NSImage *)getImageWithName:(NSString *)name
		                alternate:(NSString *)alternate
{
  NSImage	*image = nil;

  image = [NSImage imageNamed: name];
  
  if (image == nil) {
    image = [NSImage imageNamed: alternate];
  }
  
  return image;
}

- (NSImage *)folderImage
{
  static NSImage *image = nil;

  if (image == nil) {
    image = RETAIN ([self getImageWithName: @"Folder.tiff"
				                         alternate: @"common_Folder.tiff"]);
  }

  return image;
}

- (NSImage *)unknownFiletypeImage
{
  static NSImage *image = nil;

  if (image == nil) {
    image = RETAIN([self getImageWithName: @"Unknown.tiff"
				                        alternate: @"common_Unknown.tiff"]);
  }

  return image;
}

- (ViewerWindow *)server:(NSString *)serverName
          newViewerAtPath:(NSString *)path 
              canViewApps:(BOOL)viewapps
{
  ViewerWindow *viewer = [[ViewerWindow alloc] initForPath: path
                                  onServer: currentServer viewPakages: viewapps 
                                        isRootViewer: NO onStart: starting];
  [viewer activate];
  [viewers addObject: viewer];
  RELEASE (viewer);
	
	return [viewers objectAtIndex: [viewers count] -1];
}

- (void)setCurrentViewer:(ViewerWindow *)viewer
{
  currentViewer = viewer;
}

- (id)rootViewer
{
  return rootViewer;
}

- (void)viewerHasClosed:(id)sender
{
  if (sender != rootViewer) {
    [viewers removeObject: sender];
  }
}

- (void)server:(NSString *)serverName 
        openSelectedPaths:(NSArray *)paths 
                newViewer:(BOOL)newv
{
  int i, j;
  
  [self server: serverName setSelectedPaths: paths];
      
  for (i = 0; i < [paths count]; i++) {
    NSString *apath = [paths objectAtIndex: i];
    NSString *type = [self server: serverName typeOfFileAt: apath];
    
    if ([type isEqual: NSDirectoryFileType] 
                      || [type isEqual: NSFilesystemFileType]) {
      if (newv) {    
        [self server: serverName newViewerAtPath: apath canViewApps: NO];    
      }
    } else if ([type isEqual: NSPlainFileType]
                        || [type isEqual: NSShellCommandFileType]) {
      if ([self server: serverName isPakageAtPath: apath]) {
        if (newv) {    
          [self server: serverName newViewerAtPath: apath canViewApps: YES];    
        } else {
     //     [self openFile: apath];
        }
      } else {
        BOOL found = NO;
        
        for (j = 0; j < [editors count]; j++) {
          RemoteEditor *editor = [editors objectAtIndex: j];
        
          if (([serverName isEqual: [editor serverName]]) 
                                 && ([apath isEqual: [editor filePath]])) {
            [editor activate];
            found = YES;
            break;
          }
        }
        
        if (found == NO) {
          id <GWSDProtocol> server = [self serverWithName: serverName];
          NSString *contents = [server contentsOfFileAt: apath];
        
          if (contents) {
            RemoteEditor *editor = [[RemoteEditor alloc] initForEditFile: apath
                                withContents: contents onRemoteHost: serverName];
            [editors addObject: editor];
            RELEASE (editor);
          } else {
            NSRunAlertPanel(NULL, NSLocalizedString(@"This file is too big!\n\
  To edit it increase the maxim remote file size from the Preferences", @""),
                                    NSLocalizedString(@"OK", @""), NULL, NULL);   
          }
        }
        
    //    [self openFile: apath];
      }    
    } else if ([type isEqual: NSApplicationFileType]) {
      if (newv) {    
        [self server: serverName newViewerAtPath: apath canViewApps: YES];    
      } else {
   //     [ws launchApplication: apath];
      }
    }
  }
}

- (BOOL)editor:(RemoteEditor *)editor 
      didEditContents:(NSString *)contents
               ofFile:(NSString *)filepath
         onRemoteHost:(NSString *)serverName
{
  id <GWSDProtocol> server = [self serverWithName: serverName];

  if ([server saveString: contents atPath: filepath] == NO) {
    NSRunAlertPanel(NULL, NSLocalizedString(@"Error in saving the remote file!", @""),
                                NSLocalizedString(@"OK", @""), NULL, NULL);   
    return NO;
  }
  
  return YES;
}

- (void)remoteEditorHasClosed:(RemoteEditor *)editor
{
  [editors removeObject: editor];
}

- (void)newTerminal
{
  NSString *serverName = [currentViewer serverName];
  id <GWSDProtocol> server = [self serverWithName: serverName];
  NSString *path = [currentViewer currentViewedPath];
  NSNumber *tref = [self remoteTerminalRef];
  RemoteTerminal *terminal = [[RemoteTerminal alloc] initForRemoteHost: serverName
                                                             refNumber: tref];
  
  if (path == nil) {
    NSArray *selPaths = [self selectedPathsForServerWithName: serverName];
  
    if ([selPaths count] > 1) {
      path = [[selPaths objectAtIndex: 0] stringByDeletingLastPathComponent];
    } else {
      path = [selPaths objectAtIndex: 0];
      
      if ([server existsAndIsDirectoryFileAtPath: path] == NO) {
        path = [path stringByDeletingLastPathComponent];
      }
    }
	}

  [terminal activate];
  [terminals addObject: terminal];
  RELEASE (terminal);
  
  [server openShellOnPath: path refNumber: tref];
}

- (void)remoteTerminalHasClosed:(RemoteTerminal *)terminal
{
  NSString *serverName = [terminal serverName];
  NSNumber *refNumber = [terminal refNumber];
  id <GWSDProtocol> server = [self serverWithName: serverName];

  [terminals removeObject: terminal];

  [server closedRemoteTerminalWithRefNumber: refNumber];  
}

- (void)_exitedShellTaskWithRef:(NSNumber *)ref
{
  RemoteTerminal *terminal = [self remoteTerminalWithRef: ref];
  
  if (terminal) {
    [terminal shellDidExit];
    [terminals removeObject: terminal];
  }
}

- (RemoteTerminal *)remoteTerminalWithRef:(NSNumber *)ref
{
  int i;

  for (i = 0; i < [terminals count]; i++) {
    RemoteTerminal *terminal = [terminals objectAtIndex: i];
    NSNumber *tref = [terminal refNumber];
    
    if ([tref isEqual: ref]) {
      return terminal;
    }
  }

  return nil;
}

- (void)_remoteShellWithRef:(NSNumber *)ref hasAvailableData:(NSData *)data
{
  RemoteTerminal *terminal = [self remoteTerminalWithRef: ref];
  
  if (terminal) {
    NSString *str = [[NSString alloc] initWithData: data 
                          encoding: [NSString defaultCStringEncoding]];
    [terminal shellOutput: str];
    RELEASE (str);
  }
}

- (void)terminalWithRef:(NSNumber *)ref newCommandLine:(NSString *)line
{
  RemoteTerminal *terminal = [self remoteTerminalWithRef: ref];
  NSString *serverName = [terminal serverName];
  id <GWSDProtocol> server = [self serverWithName: serverName];

  [server remoteShellWithRef: ref newCommandLine: line];
}

- (NSNumber *)remoteTerminalRef
{
  int ref = [remoteTermRef intValue];

  ref++;
  if (ref == 1000) {
    ref = 0;  
  }
  remoteTermRef = [NSNumber numberWithInt: ref];

  return remoteTermRef;
}

- (NSMutableDictionary *)cachedRepresentationForPath:(NSString *)path
                                            onServer:(NSString *)serverName 
{
  NSMutableDictionary *serverCache = [cachedContents objectForKey: serverName];

  if (serverCache == nil) {
    [cachedContents setObject: [NSMutableDictionary dictionary] 
                       forKey: serverName];
    return nil;
    
  } else {
    NSMutableDictionary *contents = [serverCache objectForKey: path];

    if (contents) {
      NSDate *modDate = [contents objectForKey: @"moddate"];
      id <GWSDProtocol>server = [self serverWithName: serverName];
      NSDate *date = [server modificationDateForPath: path];

      if ([modDate isEqualToDate: date]) {
        return contents;
      } else {
        [serverCache removeObjectForKey: path];
      }
    }
  }
  
  return nil;
}

- (void)addCachedRepresentation:(NSDictionary *)contentsDict
                    ofDirectory:(NSString *)path
                       onServer:(NSString *)serverName
{
  NSMutableDictionary *serverCache = [cachedContents objectForKey: serverName];
  NSMutableArray *watchedPaths = [[self dictionaryForServer: serverName] 
                                               objectForKey: @"watchedpaths"];

  [serverCache setObject: contentsDict forKey: path];
  
  if ([watchedPaths containsObject: path] == NO) {
    [watchedPaths addObject: path];
    [self server: serverName addWatcherForPath: path];
  }
}

- (void)removeCachedRepresentationForPath:(NSString *)path
                                 onServer:(NSString *)serverName
{
  NSMutableDictionary *serverCache = [cachedContents objectForKey: serverName];
  NSMutableArray *watchedPaths = [[self dictionaryForServer: serverName] 
                                               objectForKey: @"watchedpaths"];

  [serverCache removeObjectForKey: path];
  
  if ([watchedPaths containsObject: path]) {
    [self server: serverName removeWatcherForPath: path];
    [watchedPaths removeObject: path];
  }
}

- (void)removeOlderCachedForServer:(NSString *)serverName
{
  NSMutableDictionary *serverCache = [cachedContents objectForKey: serverName];
  NSMutableArray *watchedPaths = [[self dictionaryForServer: serverName] 
                                               objectForKey: @"watchedpaths"];

  if (serverCache) {
    NSArray *keys = [serverCache allKeys];
    NSDate *date = [NSDate date];
    NSString *removeKey = nil;
    int i;
  
    if ([keys count]) {
      for (i = 0; i < [keys count]; i++) {
        NSString *key = [keys objectAtIndex: i];
        NSDate *stamp = [[serverCache objectForKey: key] objectForKey: @"datestamp"];
        NSDate *d = [date earlierDate: stamp];

        if ([date isEqualToDate: d] == NO) {
          date = d;
          removeKey = key;
        }
      }
     
      if (removeKey == nil) {
        removeKey = [keys objectAtIndex: 0];
      }
      
      [serverCache removeObjectForKey: removeKey];
 
      if ([watchedPaths containsObject: removeKey]) {
        [self server: serverName removeWatcherForPath: removeKey];
        [watchedPaths removeObject: removeKey];
      }
    }
  }
}

- (int)entriesInCacheOfServer:(NSString *)serverName
{
  return [[cachedContents objectForKey: serverName] count];
}

- (BOOL)server:(NSString *)serverName verifyFileAtPath:(NSString *)path
{
	if ([[self serverWithName: serverName] existsFileAtPath: path] == NO) {
		NSString *err = NSLocalizedString(@"Error", @"");
		NSString *msg = NSLocalizedString(@": no such file or directory!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");
		NSMutableDictionary *notifObj = [NSMutableDictionary dictionaryWithCapacity: 1];		
		NSString *basePath = [path stringByDeletingLastPathComponent];
		
    NSRunAlertPanel(err, [NSString stringWithFormat: @"%@%@", path, msg], buttstr, nil, nil);   

		[notifObj setObject: NSWorkspaceDestroyOperation forKey: @"operation"];	
  	[notifObj setObject: basePath forKey: @"source"];	
  	[notifObj setObject: basePath forKey: @"destination"];	
  	[notifObj setObject: [NSArray arrayWithObjects: path, nil] forKey: @"files"];	

		[nc postNotificationName: GWFileSystemWillChangeNotification
	 									  object: notifObj];

		[nc postNotificationName: GWFileSystemDidChangeNotification
	 									object: notifObj];
		return NO;
	}
	
	return YES;
}

- (void)fileSystemWillChangeNotification:(NSNotification *)notif
{
}

- (void)fileSystemDidChangeNotification:(NSNotification *)notif
{
}

- (void)server:(NSString *)serverName 
        newObjectAtPath:(NSString *)basePath 
            isDirectory:(BOOL)directory
{
  id <GWSDProtocol> server = [self serverWithName: serverName];

  if (server) {
    [server newObjectAtPath: basePath isDirectory: directory];
  }
}

- (void)duplicateFilesOnServerName:(NSString *)serverName
{
  id <GWSDProtocol> server = [self serverWithName: serverName];

  if (server) {
    NSArray *selection = [self selectedPathsForServerWithName: serverName];
    NSString *basePath = [NSString stringWithString: [selection objectAtIndex: 0]];
    NSMutableArray *files = [NSMutableArray array];
    int i;

    basePath = [basePath stringByDeletingLastPathComponent];

    for (i = 0; i < [selection count]; i++) {
      [files addObject: [[selection objectAtIndex: i] lastPathComponent]];
    }

    [server duplicateFiles: files inDirectory: basePath];
  }
}

- (void)deleteFilesOnServerName:(NSString *)serverName
{
  id <GWSDProtocol> server = [self serverWithName: serverName];

  if (server) {
    NSArray *selection = [self selectedPathsForServerWithName: serverName];
    NSString *basePath = [NSString stringWithString: [selection objectAtIndex: 0]];
    NSMutableArray *files = [NSMutableArray array];
    int i;

    basePath = [basePath stringByDeletingLastPathComponent];

    for (i = 0; i < [selection count]; i++) {
      [files addObject: [[selection objectAtIndex: i] lastPathComponent]];
    }

    [server deleteFiles: files inDirectory: basePath];
  }
}

- (BOOL)pauseFileOperationWithRef:(int)ref 
                 onServerWithName:(NSString *)serverName
{
  id <GWSDProtocol> server = [self serverWithName: serverName];

  if (server) {
    return [server pauseFileOpeRationWithRef: ref];
  }
  
  return NO;  
}

- (BOOL)continueFileOperationWithRef:(int)ref
                    onServerWithName:(NSString *)serverName
{
  id <GWSDProtocol> server = [self serverWithName: serverName];

  if (server) {
    return [server continueFileOpeRationWithRef: ref];
  }

  return NO;
}

- (BOOL)stopFileOperationWithRef:(int)ref
                onServerWithName:(NSString *)serverName
{
  id <GWSDProtocol> server = [self serverWithName: serverName];

  if (server) {
    return [server stopFileOpeRationWithRef: ref];
  }

  return NO;
}

- (int)shelfCellsWidth
{
  return shelfCellsWidth;
}

- (int)defaultShelfCellsWidth
{
  [self setShelfCellsWidth: 90];
  return 90;
}

- (void)setShelfCellsWidth:(int)w
{
  shelfCellsWidth = w;
    
	[nc postNotificationName: GWShelfCellsWidthChangedNotification
	 								   object: nil];  
}

- (BOOL)usesContestualMenu
{
  return NO;
}

- (void)updateDefaults
{
	NSUserDefaults *defaults;
  NSArray *snames;
  int i, j;
 		
  defaults = [NSUserDefaults standardUserDefaults];  
  [defaults setObject: [NSString stringWithFormat: @"%i", shelfCellsWidth]
               forKey: @"shelfcellswidth"];

  [defaults setBool: !animateChdir forKey: @"nochdiranim"];
  [defaults setBool: !animateLaunck forKey: @"nolaunchanim"];
  [defaults setBool: !animateSlideBack forKey: @"noslidebackanim"];

  snames = [serversDict allKeys];
  
  for (i = 0; i < [snames count]; i++) {
    NSString *serverName = [snames objectAtIndex: i];
    NSDictionary *serverDict = [self dictionaryForServer: serverName]; 
    NSMutableDictionary *serverPrefs;
    NSArray *sviewers;
    id entry;
    
    entry = [defaults objectForKey: serverName];
    if (entry) {
      serverPrefs = [entry mutableCopy];
      [serverPrefs removeObjectForKey: @"viewerspaths"];
    } else {
      serverPrefs = [NSMutableDictionary new];
    }
    
    [serverPrefs setObject: [serverDict objectForKey: @"defaultsorttype"]
                    forKey: @"defaultsorttype"];
    
    [serverPrefs setObject: [serverDict objectForKey: @"GSFileBrowserHideDotFiles"] 
                    forKey: @"GSFileBrowserHideDotFiles"];
 
    sviewers = [self viewersOfServer: serverName];
    
    if (sviewers) {
      NSMutableArray *viewersPaths = [NSMutableArray array];
      
      for (j = 0; j < [sviewers count]; j++) {
        ViewerWindow *viewer = [sviewers objectAtIndex: j];
        
        if ([viewer isVisible]) {
          [viewersPaths addObject: [viewer rootPath]];
        } 
      }  
      
      [serverPrefs setObject: viewersPaths forKey: @"viewerspaths"];
    }
    
    [defaults setObject: serverPrefs forKey: serverName];
    RELEASE (serverPrefs);
  }

	[defaults synchronize];

	if ([[prefController myWin] isVisible]) {  
		[prefController updateDefaults]; 
	}

  for (i = 0; i < [viewers count]; i++) {
    [[viewers objectAtIndex: i] updateDefaults];
  }
}

- (void)connectionDidDie:(NSNotification *)notification
{
	id diedconn = [notification object];
	id <GWSDProtocol> server = [self serverWithConnection: diedconn];
  
  [[NSNotificationCenter defaultCenter] removeObserver: self
	                      name: NSConnectionDidDieNotification object: diedconn];

  if (server) {
    NSString *name = [self nameOfServer: server];
    NSArray *sviewers = [self viewersOfServer: name];
    int i;
    
    for (i = 0; i < [sviewers count]; i++) {
      ViewerWindow *viewer = [sviewers objectAtIndex: i];
      
      [viewer updateDefaults];
      [viewer close];
    }
    
    [serversDict removeObjectForKey: name];
    
    NSRunAlertPanel(NULL, 
        [NSString stringWithFormat: @"the connection with %@ died!", name],
                                                          @"OK", NULL, NULL);   
  }  
}


//
// Menu Operations
//
- (void)showViewer:(id)sender
{
	if(rootViewer == nil) {
    rootViewer = [[ViewerWindow alloc] initForPath: fixPath(@"/", 0)
                                  onServer: currentServer viewPakages: NO 
                                        isRootViewer: YES onStart: starting];
    [viewers addObject: rootViewer];
    RELEASE (rootViewer);
  } else {
    [self server: currentServer 
              newViewerAtPath: fixPath(@"/", 0) canViewApps: NO];
  }
   
	[rootViewer activate];
}

- (void)openRemoteTerminal:(id)sender
{
  [self newTerminal];
}

- (void)closeMainWin:(id)sender
{
  [[[NSApplication sharedApplication] keyWindow] performClose: sender];
}

- (void)showPreferences:(id)sender
{
  [prefController activate]; 
}

- (void)showLoginWindow:(id)sender
{
  [loginWindow activate]; 
}

- (void)logout:(id)sender
{
  NSString *serverName = [currentViewer serverName];
  NSDictionary *dict = [serversDict objectForKey: serverName];
  NSArray *sviewers = [self viewersOfServer: serverName];
  int i;

  if (NSRunAlertPanel(@"Logout",
				 [NSString stringWithFormat: @"Logout from %@?", serverName], 
								          @"Ok", @"No", NULL) != NSAlertDefaultReturn) {
    return;
  }

  for (i = 0; i < [sviewers count]; i++) {
    ViewerWindow *viewer = [sviewers objectAtIndex: i];

    [viewer updateDefaults];
    [viewer close];
  }
  
  [self updateDefaults];
  
  if (dict) {
    [serversDict removeObjectForKey: serverName];
  }
}

- (void)showInfo:(id)sender
{
  NSMutableDictionary *d = AUTORELEASE ([NSMutableDictionary new]);
  [d setObject: @"GWRemote" forKey: @"ApplicationName"];
  [d setObject: NSLocalizedString(@"GNUstep Remote Workspace Manager", @"")
      	forKey: @"ApplicationDescription"];
  [d setObject: @"GWRemote 0.1" forKey: @"ApplicationRelease"];
  [d setObject: @"06 2003" forKey: @"FullVersionID"];
  [d setObject: [NSArray arrayWithObjects: 
      @"Enrico Sersale <enrico@imago.ro>.",
      nil]
     forKey: @"Authors"];
  [d setObject: NSLocalizedString(@"See http://www.gnustep.it/enrico/gwremote", @"") forKey: @"URL"];
  [d setObject: @"Copyright (C) 2003 Enrico Sersale."
     forKey: @"Copyright"];
  [d setObject: NSLocalizedString(@"Released under the GNU General Public License 2.0", @"")
     forKey: @"CopyrightDescription"];
  
#ifdef GNUSTEP	
  [NSApp orderFrontStandardInfoPanelWithOptions: d];
#else
	[NSApp orderFrontStandardAboutPanel: d];
#endif
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem 
{	
	NSString *title = [anItem title];
	
	if ([title isEqual: NSLocalizedString(@"Viewer", @"")]) {
    return (currentServer != nil);
  }

	if ([title isEqual: NSLocalizedString(@"Logout", @"")]) {
    return (currentServer != nil);
  }

	if ([title isEqual: NSLocalizedString(@"Remote Terminal", @"")]) {
    return (currentServer != nil);
  }
  
	return YES;
}

@end
