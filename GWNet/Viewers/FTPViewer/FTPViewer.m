/* FTPViewer.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: January 2004
 *
 * This file is part of the GNUstep GWNet application
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
#include "FTPViewer.h"
#include "GWNet.h"
#include "Browser.h"
#include "FileOpInfo.h"
#include "Notifications.h"
#include "GWNetFunctions.h"
#include "GNUstep.h"

#define SETRECT(o, x, y, w, h) { \
NSRect rct = NSMakeRect(x, y, w, h); \
if (rct.size.width < 0) rct.size.width = 0; \
if (rct.size.height < 0) rct.size.height = 0; \
[o setFrame: rct]; \
}

#define DEFAULT_WIDTH 150
#define DEFAULT_ICONS_WIDTH 120

#ifndef LONG_DELAY
  #define LONG_DELAY 86400.0
#endif


@implementation FTPViewer

- (void)dealloc
{
  [nc removeObserver: self];  

  RELEASE (cachedContents);
  RELEASE (preContents);
  RELEASE (pathSeparator);
  TEST_RELEASE (selectedPaths);
  TEST_RELEASE (nextPathComponents);
  TEST_RELEASE (progrPath);
  TEST_RELEASE (nextSelection[0]);
  TEST_RELEASE (nextSelection[1]);
	RELEASE (lockedPaths);
  
  RELEASE (hostname);
  RELEASE (user);
  RELEASE (password);

  RELEASE (browser);

  RELEASE (hostIcon);
  RELEASE (folderIcon);
  RELEASE (toolIcon);
  RELEASE (unknownIcon);

  RELEASE (commandsQueue);  
  RELEASE (tmoutTimers);

  RELEASE (fileOperations);
  
  DESTROY (dispatcher);
  DESTROY (dispatcherConn);  

  RELEASE (dndConnName);
	DESTROY (dndConn);
  
  [super dealloc];
}

+ (BOOL)canViewScheme:(NSString *)scheme
{
  return [scheme isEqual: @"ftp"]; 
}

- (id)initForUrl:(NSURL *)url 
            user:(NSString *)usr
        password:(NSString *)passwd
{
  unsigned int style = NSTitledWindowMask | NSClosableWindowMask 
				         | NSMiniaturizableWindowMask | NSResizableWindowMask;

  self = [super initWithContentRect: NSZeroRect styleMask: style
                               backing: NSBackingStoreBuffered defer: NO];

  if (self) {
    unsigned long cnref;
    NSString *dspconnName;
  
	  [self setReleasedWhenClosed: NO];

		gwnetapp = [GWNet gwnet];    
    
    ASSIGN (hostname, [url host]);
		ASSIGN (pathSeparator, fixPath(@"/", 0));	
    selectedPaths = nil;
    nextPathComponents = nil;
    progrPath = nil;
    nextSelection[0] = nil;
    nextSelection[1] = nil;
    loadingSelection = NO;    
	  lockedPaths = [NSMutableArray new];	
    
    if (usr && [usr length]) {
      ASSIGN (user, usr);
    } else {
      ASSIGN (user, [NSString stringWithString: @"anonymous"]);
    }

    if (passwd && [passwd length]) {
      ASSIGN (password, passwd);
    } else {
      ASSIGN (password, [NSString stringWithString: @"anonymous"]);
    }

    cachedContents = [NSMutableDictionary new];
    preContents = [NSMutableDictionary new];
    
    [self createIcons];

    commandsQueue = [NSMutableArray new];
    commref = 0;
    tmoutTimers = [NSMutableArray new];
    
    fileOperations = [NSMutableArray new];
    fopRef = 0;

    nc = [NSNotificationCenter defaultCenter];

    cnref = (unsigned long)self;
    
    ASSIGN (dndConnName, ([NSString stringWithFormat: @"gwnet_viewer_dnd_%i", cnref]));
    
    dndConn = [[NSConnection alloc] initWithReceivePort: (NSSocketPort *)[NSSocketPort port] 
																			         sendPort: nil];
    [dndConn enableMultipleThreads];
    [dndConn setRootObject: self];
    [dndConn registerName: dndConnName];
    [dndConn setRequestTimeout: LONG_DELAY];
    [dndConn setReplyTimeout: LONG_DELAY];
    [dndConn setDelegate: self];

    [nc addObserver: self
           selector: @selector(connectionDidDie:)
               name: NSConnectionDidDieNotification
             object: dndConn];    

    connected = NO;
    dispatcher = nil;
    
    dspconnName = [NSString stringWithFormat: @"gwnet_viewer_dsp_%i", cnref];

    dispatcherConn = [[NSConnection alloc] initWithReceivePort: (NSSocketPort *)[NSSocketPort port] 
																			                sendPort: nil];
    [dispatcherConn enableMultipleThreads];
    [dispatcherConn setRootObject: self];
    [dispatcherConn registerName: dspconnName];
    [dispatcherConn setRequestTimeout: LONG_DELAY];
    [dispatcherConn setReplyTimeout: LONG_DELAY];
    [dispatcherConn setDelegate: self];

    [nc addObserver: self 
				   selector: @selector(connectionDidDie:)
	    			   name: NSConnectionDidDieNotification 
             object: dispatcherConn];

    [gwnetapp dispatcherForViewerWithScheme: [self scheme]
                             connectionName: dspconnName];
    
    [tmoutTimers addObject: [NSTimer scheduledTimerWithTimeInterval: 5.0 target: self 
          	selector: @selector(checkConnection:) userInfo: nil repeats: NO]];                                             
  }
  
  return self;
}

- (void)setPathAndSelection:(NSArray *)selection
{
  NSString *path = [selection objectAtIndex: 0];

  path = [path stringByDeletingLastPathComponent];
  nextPathComponents = [[path componentsSeparatedByString: pathSeparator] mutableCopy];
  ASSIGN (nextSelection[0], [NSArray arrayWithObject: path]);
  ASSIGN (nextSelection[1], selection);
  ASSIGN (progrPath, pathSeparator);
  
  [self removeCachedContentsStartingAt: pathSeparator];
  loadingSelection = YES;
  [self setNextSelectionComponent];
  [browser setPathAndSelection: [NSArray arrayWithObject: pathSeparator]];
}

- (void)createInterface
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id defEntry;
  int winwidth;

  defEntry = [defaults objectForKey: @"browserColsWidth"];
  if (defEntry) {
    resizeIncrement = [defEntry intValue];
  } else {
    resizeIncrement = DEFAULT_WIDTH;
  }

  defEntry = [defaults objectForKey: @"iconsCellsWidth"];
  if (defEntry) {
    iconCellsWidth = [defEntry intValue];
  } else {
    iconCellsWidth = DEFAULT_ICONS_WIDTH;
  }

  [self setTitle: hostname];
  if ([self setFrameUsingName: [NSString stringWithFormat: @"viewver_for_%@", hostname]] == NO) {
    [self setFrame: NSMakeRect(200, 200, resizeIncrement * 3, 500) display: NO];
  } 
  [self setMinSize: NSMakeSize(resizeIncrement * 2, 250)];    
  [self setResizeIncrements: NSMakeSize(resizeIncrement, 1)];
  
	winwidth = (int)[self frame].size.width;			
  columns = (int)winwidth / resizeIncrement;      
  columnsWidth = (winwidth - 16) / columns;

  [[self contentView] setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
  [[self contentView] setPostsFrameChangedNotifications: YES];

  [nc addObserver: self 
         selector: @selector(viewFrameDidChange:) 
             name: NSViewFrameDidChangeNotification
           object: [self contentView]];

  browser = [[Browser alloc] initWithDelegate: self
                                pathSeparator: pathSeparator
                                     hostName: hostname
                               visibleColumns: columns];

  [[self contentView] addSubview: browser];   
  
  autoSynchronize = YES;
  
  [self activate];
  
  [browser setPathAndSelection: [NSArray arrayWithObject: pathSeparator]];
  [self setSelectedPaths: [NSArray arrayWithObject: pathSeparator]];
}

- (void)createIcons
{
  ASSIGN (hostIcon, [NSImage imageNamed: @"common_Root_PC.tiff"]);
  ASSIGN (folderIcon, [NSImage imageNamed: @"folder.tiff"]);
  ASSIGN (toolIcon, [NSImage imageNamed: @"tool.tiff"]);
  ASSIGN (unknownIcon, [NSImage imageNamed: @"unknown.tiff"]);
}

- (void)activate
{
  [self makeKeyAndOrderFront: nil];
  [self adjustSubviews];	
  [self makeFirstResponder: browser];  
}

- (void)adjustSubviews
{
  NSRect r = [[self contentView] frame];
  float w = r.size.width;
	float h = r.size.height;   	

	SETRECT (browser, 8, 0, w - 16, h - 8);
  [browser resizeWithOldSuperviewSize: [browser frame].size]; 
}

- (void)viewFrameDidChange:(NSNotification *)notification
{
  [self adjustSubviews];

  if (autoSynchronize == YES) {
    NSRect r = [[self contentView] frame];
    int col = columns;
  
    columns = (int)(r.size.width / resizeIncrement);
  
    if (col != columns) {
	    if (browser != nil) {
		    [browser removeFromSuperview];
		    RELEASE (browser);
        
        browser = [[Browser alloc] initWithDelegate: self
                                      pathSeparator: pathSeparator
                                           hostName: hostname
                                     visibleColumns: columns];

        [[self contentView] addSubview: browser]; 
        [self adjustSubviews];	
        [self makeFirstResponder: browser];  
	    }
    }
  }
}

- (void)selectAll
{
  [browser selectAllInLastColumn];
}

- (void)setNextSelectionComponent
{
  if (nextPathComponents && [nextPathComponents count]) {
    NSString *component = [nextPathComponents objectAtIndex: 0];
    ASSIGN (progrPath, [progrPath stringByAppendingPathComponent: component]);
    [nextPathComponents removeObjectAtIndex: 0];
  }
}

- (NSString *)hostname
{
  return hostname;
}

- (NSString *)scheme
{
  return @"ftp";
}

- (NSArray *)fileOperations
{
  return fileOperations;
}

- (void)updateDefaults
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	

  if (connected == NO) {
    return;
  }

  [self saveFrameUsingName: [NSString stringWithFormat: @"viewver_for_%@", hostname]];

  [defaults setObject: [NSString stringWithFormat: @"%i", resizeIncrement]
               forKey: @"browserColsWidth"];

  [defaults setObject: [NSString stringWithFormat: @"%i", iconCellsWidth]
               forKey: @"iconsCellsWidth"];

  [defaults synchronize];
}

- (BOOL)windowShouldClose:(id)sender
{
  [self updateDefaults];
  return YES;
}

- (void)close
{
  int i;
  
  for (i = 0; i < [tmoutTimers count]; i++) {
    NSTimer *timer = [tmoutTimers objectAtIndex: 0];
  
    if ([timer isValid]) {
      [timer invalidate];
    }
    [tmoutTimers removeObject: timer];
  }

  [self updateDefaults];
  [super close];
  
  if (dispatcher) {
    [dispatcher unregister];
    DESTROY (dispatcher);
  }
  
  if (dispatcherConn) {
    [dispatcherConn registerName: nil];
    DESTROY (dispatcherConn); 
  }

  if (dndConn) {
    [dndConn registerName: nil];
    DESTROY (dndConn);
  } 
  
  [gwnetapp viewerHasClosed: self]; 
}


//
// gwnetd connection methods
//
- (void)setDispatcher:(id)dsp
{
  [dsp setProtocolForProxy: @protocol(DispatcherProtocol)];
  dispatcher = RETAIN (dsp);
  [self newCommand: LOGIN withArguments: nil];
}

- (void)checkConnection:(id)sender
{
  if ([tmoutTimers containsObject: sender]) {
    [tmoutTimers removeObject: sender];
  }
  if (dispatcher == nil) {
    NSString *msg = NSLocalizedString(@"can't contact the gwnetd ftp handler", @"");
    NSRunAlertPanel(NULL, msg, NSLocalizedString(@"Ok", @""), NULL, NULL);  
    [self close]; 
  }
}

- (void)connectionDidDie:(NSNotification *)notification
{
	id diedconn = [notification object];

  if (diedconn == dispatcherConn) {
    NSString *msg = NSLocalizedString(@"the gwnetd ftp daemon connection has died", @"");

    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: diedconn];
    NSRunAlertPanel(NULL, msg, NSLocalizedString(@"Ok", @""), NULL, NULL); 
    [self close]; 
    
  } else if (diedconn == dndConn) {
    NSString *msg = NSLocalizedString(@"the viewer connection for remote dnd has died", @"");

    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: diedconn];
    NSRunAlertPanel(NULL, msg, NSLocalizedString(@"Ok", @""), NULL, NULL); 
    [self close];   
  }
}


//
// ftp commands methods
//
- (void)newCommand:(int)cmd 
     withArguments:(NSArray *)args
{
  NSMutableDictionary *cmdInfo = [NSMutableDictionary dictionary];
    
  [cmdInfo setObject: [NSNumber numberWithInt: cmd] forKey: @"cmdtype"];
  [cmdInfo setObject: [self commandRef] forKey: @"cmdref"];

  switch (cmd) {
    case LOGIN:
      [cmdInfo setObject: hostname forKey: @"hostname"];
      [cmdInfo setObject: user forKey: @"user"];
      [cmdInfo setObject: password forKey: @"password"];
      [cmdInfo setObject: [NSNumber numberWithBool: YES] forKey: @"usepasv"];
      [cmdInfo setObject: [NSNumber numberWithInt: 30] forKey: @"timeout"];
      break;

    case LIST:
      [cmdInfo setObject: [NSNumber numberWithInt: 30] forKey: @"timeout"];  
      [cmdInfo setObject: [args objectAtIndex: 0] forKey: @"path"];
      break;

    default:
      return;
  }
  
  [commandsQueue insertObject: cmdInfo atIndex: 0];

  if ([commandsQueue count] == 1) {
    [self nextCommand];
  }
}

- (void)nextCommand
{
  int count = [commandsQueue count];
  
  if (count) {
    NSDictionary *cmdInfo = [commandsQueue objectAtIndex: count - 1];
    
    if ([self isQueuedCommand: cmdInfo] == NO) {
      int timeout = [[cmdInfo objectForKey: @"timeout"] intValue]; 

      [tmoutTimers addObject: [NSTimer scheduledTimerWithTimeInterval: timeout 
                                     target: self 
          		                     selector: @selector(timeoutCommand:) 
                                   userInfo: cmdInfo 
                                    repeats: NO]]; 

      [dispatcher nextCommand: [NSArchiver archivedDataWithRootObject: cmdInfo]];
    }
  }
}

- (void)timeoutCommand:(id)sender
{
  NSDictionary *command = (NSDictionary *)[sender userInfo];
  NSString *msg = NSLocalizedString(@"timeout waiting for reply", @"");

  [commandsQueue removeObject: command];

  if ([tmoutTimers containsObject: sender]) {
    [tmoutTimers removeObject: sender];
  }

  NSRunAlertPanel(NULL, msg, NSLocalizedString(@"Ok", @""), NULL, NULL); 
}

- (void)removeTimerForCommand:(NSDictionary *)cmdInfo
{
  int i;

  for (i = 0; i < [tmoutTimers count]; i++) {
    NSTimer *timer = [tmoutTimers objectAtIndex: i];
    NSDictionary *tmrInfo = [timer userInfo];

    if ([tmrInfo isEqual: cmdInfo] && [timer isValid]) {
      [timer invalidate];
      [tmoutTimers removeObject: timer];
      break;
    }
  }
}

- (NSDictionary *)commandWithRef:(NSNumber *)ref
{
  int i;
  
  for (i = 0; i < [commandsQueue count]; i++) {
    NSDictionary *cmdInfo = [commandsQueue objectAtIndex: i];
  
    if ([[cmdInfo objectForKey: @"cmdref"] isEqual: ref]) {
      return cmdInfo;
    }
  }
  
  return nil;
}

- (NSNumber *)commandRef
{
  return [NSNumber numberWithInt: commref++];
}

- (BOOL)isQueuedCommand:(NSDictionary *)cmdInfo
{
  int i;

  for (i = 0; i < [tmoutTimers count]; i++) {
    NSTimer *timer = [tmoutTimers objectAtIndex: i];
  
    if ([timer isValid]) {
      NSDictionary *tmrInfo = [timer userInfo];
    
      if (tmrInfo && [tmrInfo isEqual: cmdInfo]) {
        return YES;
      }
    }
  }

  return NO;
}

- (void)commandReplyReady:(NSData *)data
{
  NSDictionary *cmdInfo = [NSUnarchiver unarchiveObjectWithData: data];
  BOOL error = [[cmdInfo objectForKey: @"error"] boolValue];
  int cmdtype = [[cmdInfo objectForKey: @"cmdtype"] intValue];
  NSNumber *cmdref = [cmdInfo objectForKey: @"cmdref"];
  NSDictionary *queued = [self commandWithRef: cmdref];
  
  if (queued) {
    [self removeTimerForCommand: queued];
    [commandsQueue removeObject: queued];
  }
        
  if (error) {
    NSString *errstr = [cmdInfo objectForKey: @"errstr"];
    NSRunAlertPanel(NULL, errstr, NSLocalizedString(@"Ok", @""), NULL, NULL);
//    [self close]; 
    return;
  }
    
  switch(cmdtype) {
    case LOGIN:
      connected = YES;
      [self createInterface];
      break;

    case LIST:
      {
        NSString *path = [cmdInfo objectForKey: @"path"];
        NSDictionary *contents = [self createPathCache: cmdInfo];
        BOOL exists = [self fileExistsAtPath: path];

        if (exists) {
          [browser directoryContents: contents readyForPath: path];
        } else {
	        NSString *title = NSLocalizedString(@"error", @"");
	        NSString *msg = NSLocalizedString(@"no such file or directory!", @"");
          NSString *fname = [path lastPathComponent];
          NSString *lastvalid = [path stringByDeletingLastPathComponent];
                    
	        msg = [NSString stringWithFormat: @"%@: %@", fname, msg];
          NSRunAlertPanel(title, msg, NSLocalizedString(@"OK", @""), NULL, NULL);

          [browser setPathAndSelection: [NSArray arrayWithObject: lastvalid]];
        }            
                            
        if (nextSelection[0] && exists) {
          if ([progrPath isEqual: pathSeparator]) {
            [browser setPathAndSelection: nextSelection[0]]; 
            
          } else if ([progrPath isEqual: [nextSelection[0] objectAtIndex: 0]]) {
            [browser addAndLoadColumnForPaths: nextSelection[1]];
            DESTROY (nextPathComponents);
            DESTROY (progrPath);
            DESTROY (nextSelection[0]);
            DESTROY (nextSelection[1]);
            loadingSelection = NO;
          }
          
          if (nextPathComponents) {
            [self setNextSelectionComponent];
          }
        } else if (exists == NO) {
          DESTROY (nextPathComponents);
          DESTROY (progrPath);
          DESTROY (nextSelection[0]);
          DESTROY (nextSelection[1]);
          loadingSelection = NO;
        }
      }
      break;

    default:
      break;
  }
  
  [self nextCommand];
}


//
// remote file operation methods
//
- (int)fileOpRef
{
  return fopRef++;
}

- (BOOL)confirmOperation:(FileOpInfo *)op
{
  NSString *destination = [[op destination] lastPathComponent];
  int type = [op type];
	NSString *title;
	NSString *msg;
	int result;

	if (type == UPLOAD) {
		title = NSLocalizedString(@"Upload", @"");
		msg = NSLocalizedString(@"Upload in: ", @"");
		msg = [NSString stringWithFormat: @"%@%@?", msg, destination];
	} else if (type == DOWNLOAD) {
		title = NSLocalizedString(@"Download", @"");
		msg = NSLocalizedString(@"Download in: ", @"");
		msg = [NSString stringWithFormat: @"%@%@?", msg, destination];
	} else if (type == DELETE) {
		title = NSLocalizedString(@"Delete", @"");
		msg = NSLocalizedString(@"Delete in: ", @"");
		msg = [NSString stringWithFormat: @"%@%@?", msg, destination];
  } else if (type == DUPLICATE) {
		title = NSLocalizedString(@"Duplicate", @"");
		msg = NSLocalizedString(@"Duplicate in: ", @"");
		msg = [NSString stringWithFormat: @"%@%@?", msg, destination];
	}
	
	result = NSRunAlertPanel(title, msg, NSLocalizedString(@"OK", @""), 
																		NSLocalizedString(@"Cancel", @""), NULL);
	if (result != NSAlertDefaultReturn) {
		return NO;
  }
	
  return YES;
}

- (void)startOperation:(FileOpInfo *)op
{
  int optype;
  NSString *opbase;
  NSArray *opfiles;
  NSMutableArray *oppaths;
  BOOL canstart;
  NSString *lockedPath;
  NSData *data;
  int i, j, m;    
  
  optype = [op type];
  
  if (optype == RENAME) {
    opbase = [[op source] stringByDeletingLastPathComponent];
    opfiles = [NSArray arrayWithObject: [[op source] lastPathComponent]];
  } else if (optype == DOWNLOAD) {
    opbase = [op source];
    opfiles = [op files];
  } else {
    opbase = [op destination];
    opfiles = [op files];
  }

  oppaths = [NSMutableArray array];
  for (i = 0; i < [opfiles count]; i++) {
    NSString *opfile = [opfiles objectAtIndex: i];
    [oppaths addObject: [opbase stringByAppendingPathComponent: opfile]];
  }
  
  canstart = YES;
     
  for (i = 0; i < [fileOperations count]; i++) {
    FileOpInfo *info;
    int inftype;
    NSString *chkbase;
    NSArray *chkfiles;
    NSMutableArray *chkpaths;
    
    info = [fileOperations objectAtIndex: i];
    inftype = [info type];
    
    if (inftype == RENAME) {
      chkbase = [[info source] stringByDeletingLastPathComponent];
      chkfiles = [NSArray arrayWithObject: [[info source] lastPathComponent]];
    } else if (inftype == DOWNLOAD) {
      chkbase = [info source];
      chkfiles = [info files];
    } else {
      chkbase = [info destination];
      chkfiles = [info files];
    }
    
    chkpaths = [NSMutableArray array];
    for (j = 0; j < [chkfiles count]; j++) {
      NSString *chkfile = [chkfiles objectAtIndex: j];
      [chkpaths addObject: [chkbase stringByAppendingPathComponent: chkfile]];
    }
    
    /*                                                              */
    /* ogni path in chkfiles e discendenti di ogni path in chkfiles */
    /*                                                              */
    if ((inftype == DOWNLOAD) || (inftype == UPLOAD)
            || (inftype == DELETE) || (inftype == DUPLICATE)
                                              || (inftype == RENAME)) {
      for (j = 0; j < [chkpaths count]; j++) {
        NSString *chkpath = [chkpaths objectAtIndex: j];

        if ([oppaths containsObject: chkpath]) {
          lockedPath = chkpath;
          canstart = NO;
          break;
        }

        for (m = 0; m < [oppaths count]; m++) {
          if (subPathOfPath(chkpath, [oppaths objectAtIndex: m])) {
            lockedPath = chkpath;
            canstart = NO;
            break;
          }
        }
        
        if (canstart == NO) {
          break;
        }
      }
    }      

    /*                                 */
    /* chkbase e precedenti di chkbase */
    /*                                 */
    if ((inftype == DOWNLOAD) || (inftype == UPLOAD)
            || (inftype == DELETE) || (inftype == DUPLICATE)
                                        || (inftype == NEWFOLDER)) {
      if ((optype == RENAME) || (optype == DELETE)) {
        if ([oppaths containsObject: chkbase]) {
          lockedPath = chkbase;
          canstart = NO;
          break;
        }

        for (m = 0; m < [oppaths count]; m++) {
          if (subPathOfPath([oppaths objectAtIndex: m], chkbase)) {
            lockedPath = chkbase;
            canstart = NO;
            break;
          }
        }
      }
    }

    /*                                 */
    /* chkbase e precedenti di chkbase */
    /*                                 */
    if ((inftype == DELETE) || (inftype == DUPLICATE) 
                                            || (inftype == UPLOAD)) {
      if ((optype == DOWNLOAD) || (optype == DUPLICATE)) {
        if ([oppaths containsObject: chkbase]) {
          lockedPath = chkbase;
          canstart = NO;
          break;
        }

        for (m = 0; m < [oppaths count]; m++) {
          if (subPathOfPath([oppaths objectAtIndex: m], chkbase)) {
            lockedPath = chkbase;
            canstart = NO;
            break;
          }
        }
      }
    }
          
    if (canstart == NO) {
      break;
    }
  }   
   
  if (canstart == NO) {
    NSString *error = NSLocalizedString(@"is in use by an other operation!", @"");
    NSString *msg = [NSString stringWithFormat: @"%@ %@", lockedPath, error];
    
    NSRunAlertPanel(NSLocalizedString(@"error", @""), msg,
						                      NSLocalizedString(@"OK", @""), NULL, NULL);  
    return;
  }
   
  [fileOperations insertObject: op atIndex: [fileOperations count]];
  data = [NSArchiver archivedDataWithRootObject: [op description]];
  [dispatcher startFileOperation: data];
  
  
  


/*
  int type = [op type];
  NSString *source = [op source];
  NSString *destination = [op destination];
  NSArray *files = [op files];
  NSData *data = [NSArchiver archivedDataWithRootObject: [op description]];
    
  if ((type == DUPLICATE) || (type == DELETE) || (type == UPLOAD)) {
    [self lockFiles: files inDirectory: destination];

    if ([browser isShowingPath: destination]) {      
      [browser lockCellsWithNames: files
                 inColumnWithPath: destination];
      [browser extendSelectionWithDimmedFiles: files 
                           fromColumnWithPath: destination];
    }
  } else if (type == DOWNLOAD) {
    [self lockFiles: files inDirectory: source];

    if ([browser isShowingPath: source]) {      
      [browser lockCellsWithNames: files
                 inColumnWithPath: source];
      [browser extendSelectionWithDimmedFiles: files 
                           fromColumnWithPath: source];
    }
  }

  [fileOperations insertObject: op atIndex: [fileOperations count]];
  [dispatcher startFileOperation: data];
*/
}

- (void)stopOperation:(FileOpInfo *)op
{
  NSData *data = [NSArchiver archivedDataWithRootObject: [op description]];
  [dispatcher stopFileOperation: data];
}

- (FileOpInfo *)infoForOperationWithRef:(int)ref
{
  int i;
  
  for (i = 0; i < [fileOperations count]; i++) {
    FileOpInfo *op = [fileOperations objectAtIndex: i];
    
    if ([op ref] == ref) {
      return op;
    }
  }
  
  return nil;
}

- (oneway void)fileOperationStarted:(NSData *)opinfo
{
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  int type = [[dict objectForKey: @"type"] intValue];
  int ref = [[dict objectForKey: @"ref"] intValue];
  int fcount = [[dict objectForKey: @"fcount"] intValue];
  FileOpInfo *op = [self infoForOperationWithRef: ref];
  
  if ([op win]) {
    switch(type) {               
      case UPLOAD:
        [op showWindowWithTitle: @"Upload" filesCount: fcount];
        break;

      case DOWNLOAD:
        [op showWindowWithTitle: @"Download" filesCount: fcount];
        break;

      case DELETE:
        [op showWindowWithTitle: @"Destroy" filesCount: fcount];
        break;

      case DUPLICATE:
        [op showWindowWithTitle: @"Duplicate" filesCount: fcount];
        break;

      case RENAME:
        break;  

      case NEWFOLDER:
        break;  
    
      default:
        break;
    }
  }  
}

- (oneway void)fileOperationUpdated:(NSData *)opinfo
{
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  int ref = [[dict objectForKey: @"ref"] intValue];
  FileOpInfo *op = [self infoForOperationWithRef: ref];

  if ([op win]) {
    NSString *fname = [[dict objectForKey: @"source"] lastPathComponent];
    [op updateGlobalProgress: fname];
  }
}

- (void)fileTransferStarted:(NSData *)opinfo
{
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  int ref = [[dict objectForKey: @"ref"] intValue];
  FileOpInfo *op = [self infoForOperationWithRef: ref];
  NSWindow *win = [op win];

  if (win) {
    int fsize = [[dict objectForKey: @"fsize"] intValue];
    [op startFileProgress: fsize];
  }
}

- (void)fileTransferUpdated:(NSData *)opinfo
{
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  int ref = [[dict objectForKey: @"ref"] intValue];
  FileOpInfo *op = [self infoForOperationWithRef: ref];
  NSWindow *win = [op win];

  if (win) {
    int increment = [[dict objectForKey: @"increment"] intValue];
    [op updateFileProgress: increment];
  }
}

- (oneway void)fileOperationDone:(NSData *)opinfo
{
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  int ref = [[dict objectForKey: @"ref"] intValue];
  FileOpInfo *op = [self infoForOperationWithRef: ref];

  if (op) {
    NSString *source = [op source];
    NSString *destination = [op destination];
    NSArray *files = [op files];
    int type = [op type];

    if ([op win]) {
      [op closeWindow];
    }

    if ((type == DUPLICATE) || (type == DELETE) || (type == UPLOAD)) {
      [self unlockFiles: files inDirectory: destination];
    } else if (type == DOWNLOAD) {
      [self unlockFiles: files inDirectory: source];
    }
    
    if (type == RENAME) {
      destination = [destination stringByDeletingLastPathComponent];
    }

    if ((type == UPLOAD) || (type == DELETE) || (type == NEWFOLDER) 
                            || (type == DUPLICATE) || (type == RENAME)) {
      [self removeCachedContentsStartingAt: destination];
      
      if ([browser isShowingPath: destination]) {
        [browser reloadFromColumnWithPath: destination];   
      } 
    } else if (type == DOWNLOAD) {
      if ([browser isShowingPath: source]) {
        [browser reloadFromColumnWithPath: source];   
      }     
    }

      // SE UN PATH MODIFICATO INTERFERISCE CON LA SELEZIONE CURRENTE
      // BISOGNA TAGLIARE IL BROWSER ALLA COLONNA CON "destination"
      // ALTRIMENTI E' SUFFICIENTE RELOADARE SOLO QUELLA COLONNA

  
    [fileOperations removeObject: op];
  }  
}

- (BOOL)fileOperationError:(NSData *)opinfo
{
  NSDictionary *dict = [NSUnarchiver unarchiveObjectWithData: opinfo];
  NSString *error = [dict objectForKey: @"errorstr"];
  
  if ([[dict objectForKey: @"cancontinue"] boolValue]) {
    int result = NSRunAlertPanel(NSLocalizedString(@"error", @""), error,
						                                NSLocalizedString(@"OK", @""), 
                                    NSLocalizedString(@"Cancel", @""), NULL);  
    return (result == NSAlertDefaultReturn);
  } else {
    NSRunAlertPanel(NSLocalizedString(@"error", @""), error,
						                      NSLocalizedString(@"OK", @""), NULL, NULL);  
  }
  
  return NO;
}

- (oneway void)remoteDraggingDestinationReply:(NSData *)reply
{
  NSDictionary *replydict = [NSUnarchiver unarchiveObjectWithData: reply];
  NSString *destination = [replydict objectForKey: @"destination"];
  BOOL bookmark = [[replydict objectForKey: @"bookmark"] boolValue];
  BOOL dndok = [[replydict objectForKey: @"dndok"] boolValue];

  if (dndok == NO) {
    NSString *msg = [NSString stringWithFormat: @"duplicate file name in '%@'", destination];
    NSRunAlertPanel(NULL, msg, NSLocalizedString(@"Ok", @""), NULL, NULL);  
  } else {
    NSArray *srcPaths;
    NSString *source;
    NSMutableArray *files;
    FileOpInfo *op;
    int i;
    
    srcPaths = [replydict objectForKey: @"paths"];
    source = [srcPaths objectAtIndex: 0];
    source = [source stringByDeletingLastPathComponent];    
    
    files = [NSMutableArray array];
    for (i = 0; i < [srcPaths count]; i++) {
      [files addObject: [[srcPaths objectAtIndex: i] lastPathComponent]];
    }
  	
    if (bookmark) {
      NSString *bookmarkName;
      NSString *bookmarkPath;
      NSMutableDictionary *bmkDict;
      NSString *path;
      NSArray	*subStrings;
      NSString *prgPath;
      NSDictionary *contents;
      unsigned count;      
      
      bookmarkName = [srcPaths objectAtIndex: 0];
      bookmarkPath = [destination stringByAppendingPathComponent: bookmarkName];
      bmkDict = [NSMutableDictionary dictionary];
      
      [bmkDict setObject: hostname forKey: @"hostname"];
      [bmkDict setObject: @"ftp" forKey: @"scheme"];
      [bmkDict setObject: selectedPaths forKey: @"selection"];
    
      if ([selectedPaths count] > 1) {
        path = [[selectedPaths objectAtIndex: 0] stringByDeletingLastPathComponent];
      } else {
        path = [selectedPaths objectAtIndex: 0];
      }

      subStrings = [path componentsSeparatedByString: pathSeparator];
	    count = [subStrings count];
 
      prgPath = [NSString stringWithString: pathSeparator];
      contents = [self contentsForPath: prgPath];
      if (contents) {
        [bmkDict setObject: contents forKey: prgPath];
      }

      for (i = 0; i < count; i++) {
		    NSString *str = [subStrings objectAtIndex: i];

		    if ([str isEqualToString: @""] == NO) {
          prgPath = [prgPath stringByAppendingPathComponent: str];
          contents = [self contentsForPath: prgPath];
          
          if (contents) {
            [bmkDict setObject: contents forKey: prgPath];
          }
		    }
	    }
 
      if ([bmkDict writeToFile: bookmarkPath atomically: YES] == NO) {
        NSString *msg = NSLocalizedString(@"can't save the bookmark", @"");
        NSRunAlertPanel(NULL, msg, NSLocalizedString(@"Ok", @""), NULL, NULL);  
      }

    } else {    
      op = [FileOpInfo fileOpInfoForViewer: self
                                      type: DOWNLOAD
                                       ref: [self fileOpRef]
                                    source: source
                               destination: destination
                                     files: files
                                 usewindow: YES
                                   winrect: [gwnetapp rectForFileOpWindow]];

      if ([self confirmOperation: op]) {
        [self startOperation: op];
      }
    }
  }   
}


//
// directory contents methods
//
- (NSDictionary *)createPathCache:(NSDictionary *)pathInfo
{
  NSString *path = [pathInfo objectForKey: @"path"];
  NSArray *files = [pathInfo objectForKey: @"files"];
  NSMutableDictionary *pathContents = [NSMutableDictionary dictionary];
  int i;
  
  for (i = 0; i < [files count]; i++) {
    NSDictionary *dict = [files objectAtIndex: i];
    NSString *name = [dict objectForKey: @"name"];

    [pathContents setObject: dict forKey: name];
  }

  [self addCachedContents: pathContents forPath: path];
        
  return pathContents;
}

- (void)addCachedContents:(NSDictionary *)conts 
                  forPath:(NSString *)path
{
  [cachedContents setObject: conts forKey: path];
}                  

- (void)removeCachedContentsForPath:(NSString *)path
{
  [cachedContents removeObjectForKey: path];
}

- (void)removeCachedContentsStartingAt:(NSString *)apath
{
  NSArray *paths = [[cachedContents allKeys] copy];
  int i;
  
  [self removeCachedContentsForPath: apath];
  
  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];

    if (subPathOfPath(apath, path)) {
      [self removeCachedContentsForPath: path];
    }
  }
  
  RELEASE (paths);
}

- (void)setPreContents:(NSDictionary *)conts 
{
  DESTROY (preContents);
  preContents = [conts mutableCopy];
}

- (void)removePreContents
{
  DESTROY (preContents);
}

- (NSDictionary *)infoForPath:(NSString *)path
{
  id fileDict = nil;
  
  if ([path isEqual: pathSeparator]) {
    fileDict = [NSMutableDictionary dictionary];  
  
    [fileDict setObject: hostname forKey: @"name"];
    [fileDict setObject: @"" forKey: @"linkto"];
    [fileDict setObject: NSFileTypeDirectory forKey: @"NSFileType"];
    [fileDict setObject: [NSNumber numberWithUnsignedLong: 0] 
                 forKey: @"NSFileSize"];
    [fileDict setObject: [NSNumber numberWithInt: 0] 
                 forKey: @"index"];
  } else {
    NSString *fname = [path lastPathComponent];  
    NSString *basepath = [path stringByDeletingLastPathComponent];  
    NSDictionary *contents = [self contentsForPath: basepath];
  
    if (contents) {
      fileDict = [contents objectForKey: fname];
    }
  }
  
  return fileDict;  
}

- (void)lockFiles:(NSArray *)files 
      inDirectory:(NSString *)path
{
	int i;
	  
	for (i = 0; i < [files count]; i++) {
		NSString *file = [files objectAtIndex: i];
		NSString *fpath = [path stringByAppendingPathComponent: file];    
    
		if ([lockedPaths containsObject: fpath] == NO) {
			[lockedPaths addObject: fpath];
		} 
	}
}

- (void)unlockFiles:(NSArray *)files 
        inDirectory:(NSString *)path
{
	int i;
	  
	for (i = 0; i < [files count]; i++) {
		NSString *file = [files objectAtIndex: i];
		NSString *fpath = [path stringByAppendingPathComponent: file];
	
		if ([lockedPaths containsObject: fpath]) {
			[lockedPaths removeObject: fpath];
		} 
	}
}


//
// browser delegate methods
//
- (BOOL)fileExistsAtPath:(NSString *)path
{
  if ([self infoForPath: path]) {
    return YES;
  }
  return NO;
}

- (BOOL)existsAndIsDirectoryFileAtPath:(NSString *)path
{
  NSString *type = [self typeOfFileAt: path];

  if (type && [type isEqual: NSFileTypeDirectory]) {
    return YES;
  }

  return NO;
}

- (BOOL)isWritableFileAtPath:(NSString *)path
{
  return YES;
}

- (NSString *)typeOfFileAt:(NSString *)path
{
  NSDictionary *info = [self infoForPath: path];

  if (info) {
    return [info objectForKey: @"NSFileType"];
  }

  return nil;
}

- (BOOL)isPakageAtPath:(NSString *)path
{
  return NO;
}

- (BOOL)isLockedPath:(NSString *)path
{
	int i;  
  
	if ([lockedPaths containsObject: path]) {
		return YES;
	}
	
	for (i = 0; i < [lockedPaths count]; i++) {
		NSString *lpath = [lockedPaths objectAtIndex: i];
	
    if (subPathOfPath(lpath, path)) {
			return YES;
		}
	}
	
	return NO;
}

- (void)prepareContentsForPath:(NSString *)path
{
  [self newCommand: LIST withArguments: [NSArray arrayWithObject: path]];
//  [self newCommand: NOOP withArguments: nil];
}

- (NSDictionary *)contentsForPath:(NSString *)path
{
  return [cachedContents objectForKey: path];
}

- (NSDictionary *)preContentsForPath:(NSString *)path
{
  return [preContents objectForKey: path];
}

- (void)invalidateContentsRequestForPath:(NSString *)path
{
  NSDictionary *cmdInfo = nil;
  int i;
  
  for (i = 0; i < [commandsQueue count]; i++) {
    NSDictionary *info = [commandsQueue objectAtIndex: i];

    if ([[info objectForKey: @"cmdtype"] intValue] == LIST) {
      NSString *contspath = [info objectForKey: @"path"];
  
      if ([contspath isEqual: path]) {
        ASSIGN (cmdInfo, info);
        [commandsQueue removeObject: info];
        break;
      }
    }
  }
    
  if (cmdInfo) {
    [self removeTimerForCommand: cmdInfo];
  }

  DESTROY (cmdInfo);
}

- (BOOL)isLoadingSelection
{
  return loadingSelection;
}

- (void)stopLoadSelection
{
  DESTROY (nextPathComponents);
  DESTROY (progrPath);
  DESTROY (nextSelection[0]);
  DESTROY (nextSelection[1]);
  loadingSelection = NO;
}

- (void)setSelectedPaths:(NSArray *)paths
{
  ASSIGN (selectedPaths, paths);
}

- (void)openSelectedPaths:(NSArray *)paths 
                newViewer:(BOOL)isnew
{

}            

- (void)renamePath:(NSString *)oldPath 
            toPath:(NSString *)newPath
{
  FileOpInfo *op = [FileOpInfo fileOpInfoForViewer: self
                                        type: RENAME
                                         ref: [self fileOpRef]
                                      source: oldPath
                                 destination: newPath
                                       files: [NSArray array]
                                   usewindow: NO
                                     winrect: NSZeroRect];

  [self startOperation: op];
}

- (void)uploadFiles:(NSDictionary *)info
{
  FileOpInfo *op = [FileOpInfo fileOpInfoForViewer: self
                                    type: UPLOAD
                                     ref: [self fileOpRef]
                                  source: [info objectForKey: @"source"]
                             destination: [info objectForKey: @"destination"]
                                   files: [info objectForKey: @"files"]
                               usewindow: YES
                                 winrect: [gwnetapp rectForFileOpWindow]];

  if ([self confirmOperation: op]) {
    [self startOperation: op];
  }
}

- (NSImage *)iconForFile:(NSString *)fullPath 
                  ofType:(NSString *)type
{
  if ([type isEqual: NSFileTypeDirectory]) {
    if ([fullPath isEqualToString: pathSeparator]) {
      return hostIcon;
    } else {
      return folderIcon;
    }
  } else {
    NSString *ext = [fullPath pathExtension]; 
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFileType: ext];

    if (icon) {
      return icon;
    } else {
      return unknownIcon;
    }
  }
  
  return nil;
}

- (NSString *)dndConnName
{
  return dndConnName;
}


//
// Menu operations
//
- (void)newFolder:(id)sender
{
  NSString *basePath = [selectedPaths objectAtIndex: 0];
	NSString *ftype = [self typeOfFileAt: basePath];
  
  if (ftype) {
    NSString *fileName;
    NSString *fullPath;
    FileOpInfo *op;
  
    if ([ftype isEqual: NSFileTypeDirectory] == NO) {
      basePath = [basePath stringByDeletingLastPathComponent];
    }
    
    fileName = @"NewFolder";
    fullPath = [basePath stringByAppendingPathComponent: fileName];
    
    if ([self fileExistsAtPath: fullPath]) {    
      int suff = 1;
      
      while (1) {    
        NSString *s = [fileName stringByAppendingFormat: @"%i", suff];
        fullPath = [basePath stringByAppendingPathComponent: s];
        
        if ([self fileExistsAtPath: fullPath] == NO) {
          fileName = [NSString stringWithString: s];
          break;      
        }      
        suff++;
      }     
    }
    
    op = [FileOpInfo fileOpInfoForViewer: self
                                    type: NEWFOLDER
                                     ref: [self fileOpRef]
                                  source: basePath
                             destination: basePath
                                   files: [NSArray arrayWithObject: fileName]
                               usewindow: NO
                                 winrect: NSZeroRect];

    [self startOperation: op];
  }
}

- (void)duplicateFiles:(id)sender
{
  NSString *destination = [[selectedPaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  NSMutableArray *files = [NSMutableArray array];
  FileOpInfo *op;
  int i;
  	
  for (i = 0; i < [selectedPaths count]; i++) {
    [files addObject: [[selectedPaths objectAtIndex: i] lastPathComponent]];
  }

  op = [FileOpInfo fileOpInfoForViewer: self
                                  type: DUPLICATE
                                   ref: [self fileOpRef]
                                source: destination
                           destination: destination
                                 files: files
                             usewindow: YES
                               winrect: [gwnetapp rectForFileOpWindow]];
            
  if ([self confirmOperation: op]) {
    [self startOperation: op];
  }
}

- (void)deleteFiles:(id)sender
{
  NSString *destination = [[selectedPaths objectAtIndex: 0] stringByDeletingLastPathComponent];
  NSMutableArray *files = [NSMutableArray array];
  FileOpInfo *op;
  int i;
  	
  for (i = 0; i < [selectedPaths count]; i++) {
    [files addObject: [[selectedPaths objectAtIndex: i] lastPathComponent]];
  }

  op = [FileOpInfo fileOpInfoForViewer: self
                                  type: DELETE
                                   ref: [self fileOpRef]
                                source: destination
                           destination: destination
                                 files: files
                             usewindow: YES
                               winrect: [gwnetapp rectForFileOpWindow]];
            
  if ([self confirmOperation: op]) {
    [self startOperation: op];
  }
}

- (void)selectAllInViewer:(id)sender
{
  [browser selectAllInLastColumn];
}

- (void)reloadLastColumn:(id)sender
{
  NSString *lastpath = [browser pathToLastColumn];
  
  if (lastpath) {
    [self removeCachedContentsStartingAt: lastpath];
    [browser reloadLastColumn];
  } 
}

- (void)reloadAll:(id)sender
{
  [self setPathAndSelection: selectedPaths];
}

- (void)print:(id)sender
{
  [super print: sender];
}

@end
