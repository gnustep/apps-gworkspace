/* Fiend.m
 *  
 * Copyright (C) 2003-2013 Free Software Foundation, Inc.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepBase/GNUstep.h>

#import "FSNode.h"
#import "FSNFunctions.h"
#import "GWFunctions.h"
#import "Fiend.h"
#import "FiendLeaf.h"
#import "Dialogs/Dialogs.h"
#import "GWorkspace.h"


@implementation Fiend

- (void)dealloc
{
  NSEnumerator *enumerator = [watchedPaths objectEnumerator];  
  NSString *wpath;
            
  while ((wpath = [enumerator nextObject])) {
    [gw removeWatcherForPath: wpath];
  }
  RELEASE (watchedPaths);
  
  [[NSNotificationCenter defaultCenter] removeObserver: self];	

  RELEASE (layers);
  RELEASE (namelabel);
  RELEASE (ffButt);
  RELEASE (rewButt);
  RELEASE (leftArr);
  RELEASE (rightArr);
  RELEASE (currentName);
  RELEASE (freePositions);
  RELEASE (tile);  
  RELEASE (myWin);
  [super dealloc];
}

- (id)init
{
  self = [super initWithFrame: NSMakeRect(0, 0, 64, 64)];
  if (self)
    {
      NSUserDefaults *defaults;
      NSDictionary *myPrefs;
    id leaf;
    NSRect r;
    int i, j;
	
	  gw = [GWorkspace gworkspace];

	  myWin = [[NSWindow alloc] initWithContentRect: NSZeroRect
					                      styleMask: NSBorderlessWindowMask  
                                    backing: NSBackingStoreBuffered defer: NO];

    if ([myWin setFrameUsingName: @"fiend_window"] == NO) {
      [myWin setFrame: NSMakeRect(100, 100, 64, 64) display: NO];
    }      
    r = [myWin frame];      
    r.size = NSMakeSize(64, 64);
    [myWin setFrame: r display: NO];
    
    [myWin setReleasedWhenClosed: NO]; 
    [myWin setExcludedFromWindowsMenu: YES];
    
    defaults = [NSUserDefaults standardUserDefaults];	

    layers = [[NSMutableDictionary alloc] initWithCapacity: 1];
		watchedPaths = [[NSCountedSet alloc] initWithCapacity: 1];
    
    myPrefs = [defaults dictionaryForKey: @"fiendlayers"];
    if (myPrefs != nil) {
      NSArray *names = [myPrefs allKeys];

      for (i = 0; i < [names count]; i++) {
        NSString *layername = [names objectAtIndex: i];       
        NSDictionary *pathsAndRects = [myPrefs objectForKey: layername];
        NSArray *paths = [pathsAndRects allKeys];
        NSMutableArray *leaves = [NSMutableArray arrayWithCapacity: 1];
        
        for (j = 0; j < [paths count]; j++) {
          NSString *path = [paths objectAtIndex: j];
	        NSString *watched = [path stringByDeletingLastPathComponent];	
          
          if ([[NSFileManager defaultManager] fileExistsAtPath: path]) { 
            NSDictionary *dict = [pathsAndRects objectForKey: path];
            int posx = [[dict objectForKey: @"posx"] intValue];
            int posy = [[dict objectForKey: @"posy"] intValue];            

            leaf = [[FiendLeaf alloc] initWithPosX: posx 
                                              posY: posy
                                   relativeToPoint: r.origin 
                                           forPath: path 
                                           inFiend: self  
                                         layerName: layername
                                        ghostImage: nil];
            [leaves addObject: leaf];
            RELEASE (leaf);
            
	          if ([watchedPaths containsObject: watched] == NO) {
              [gw addWatcherForPath: watched];
	          }
            
            [watchedPaths addObject: watched];
          }                 
        }
                
        [layers setObject: leaves forKey: layername];        
      }    
      currentName = [defaults stringForKey: @"fiendcurrentlayer"];
      if (currentName == nil) {
        ASSIGN (currentName, [names objectAtIndex: 0]);
      } else {
        RETAIN (currentName);
      }
      
    } else {
      NSMutableArray *leaves = [NSMutableArray arrayWithCapacity: 1];
      ASSIGN (currentName, @"Workspace");
      [layers setObject: leaves forKey: currentName];      
    }

    namelabel = [NSTextFieldCell new];
		[namelabel setFont: [NSFont boldSystemFontOfSize: 10]];
		[namelabel setBordered: NO];
		[namelabel setAlignment: NSLeftTextAlignment];
    [namelabel setStringValue: cutFileLabelText(currentName, namelabel, 52)];
	  [namelabel setDrawsBackground: NO];
	
    ASSIGN (leftArr, [NSImage imageNamed: @"FFArrow.tiff"]);
    
  	ffButt = [[NSButton alloc] initWithFrame: NSMakeRect(49, 6, 9, 9)];
		[ffButt setButtonType: NSMomentaryLight];    
    [ffButt setBordered: NO];    
    [ffButt setTransparent: YES];    
    [ffButt setTarget: self];
    [ffButt setAction: @selector(switchLayer:)];
		[self addSubview: ffButt]; 
    
    ASSIGN (rightArr, [NSImage imageNamed: @"REWArrow.tiff"]);

  	rewButt = [[NSButton alloc] initWithFrame: NSMakeRect(37, 6, 9, 9)];
		[rewButt setButtonType: NSMomentaryLight];    
    [rewButt setBordered: NO];  
    [rewButt setTransparent: YES];    
    [rewButt setTarget: self];
    [rewButt setAction: @selector(switchLayer:)];
		[self addSubview: rewButt]; 
  
    ASSIGN (tile, [NSImage imageNamed: @"common_Tile.tiff"]);
    
    [self registerForDraggedTypes: [NSArray arrayWithObjects: NSFilenamesPboardType, nil]];  
    [self findFreePositions];
    leaveshidden = NO;
    isDragTarget = NO;
		
		[myWin setContentView: self];	

		[[NSNotificationCenter defaultCenter] 
               addObserver: self 
                	selector: @selector(fileSystemDidChange:) 
                			name: @"GWFileSystemDidChangeNotification"
                		object: nil];                     
    
		[[NSNotificationCenter defaultCenter] 
               addObserver: self 
                  selector: @selector(watcherNotification:) 
                		  name: @"GWFileWatcherFileDidChangeNotification"
                	  object: nil];
  }
  
  return self;
}

- (void)activate
{
	[self orderFrontLeaves];
}

- (NSWindow *)myWin
{
  return myWin;
}

- (NSPoint)positionOfLeaf:(id)aleaf
{
	return [aleaf iconPosition];
}

- (BOOL)dissolveLeaf:(id)aleaf
{
	return [aleaf dissolveAndReturnWhenDone];
}

- (void)addLayer
{
  SympleDialog *dialog;
  NSString *layerName;
  NSMutableArray *leaves;
  int result;
  
  if ([myWin isVisible] == NO) {
    return;
  }

  dialog = [[SympleDialog alloc] initWithTitle: NSLocalizedString(@"New Layer", @"") 
                                      editText: @""
                                   switchTitle: nil];
  [dialog center];
  [dialog makeKeyWindow];
  [dialog orderFrontRegardless];
  
  result = [dialog runModal];
  [dialog release];

  if(result != NSAlertDefaultReturn)
    return;
  
  layerName = [dialog getEditFieldText];

  if ([layerName length] == 0) {
		NSString *msg = NSLocalizedString(@"No name supplied!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }
  
  if ([[layers allKeys] containsObject: layerName]) {
		NSString *msg = NSLocalizedString(@"A layer with this name is already present!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
	}
		
  leaves = [NSMutableArray arrayWithCapacity: 1];
  [layers setObject: leaves forKey: layerName];
  [self goToLayerNamed: layerName];
}

- (void)removeCurrentLayer
{
  NSArray *names, *leaves;
  NSString *newname;
	NSString *title, *msg, *buttstr;
  int i, index, result;

  if ([myWin isVisible] == NO) {
    return;
  }
  
  if ([layers count] == 1) {
		msg = NSLocalizedString(@"You can't remove the last layer!", @"");
		buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
  }

	title = NSLocalizedString(@"Remove layer", @"");
	msg = NSLocalizedString(@"Are you sure that you want to remove this layer?", @"");
	buttstr = NSLocalizedString(@"Continue", @"");
  result = NSRunAlertPanel(title, msg, NSLocalizedString(@"OK", @""), buttstr, NULL);
  if(result != NSAlertDefaultReturn) {
    return;
  }
  
  names = [layers allKeys];  	
	index = [names indexOfObject: currentName];
	
  if (index == 0) {
    index = [names count];
  }
  index--;
  
  newname = [names objectAtIndex: index];

  leaves = [layers objectForKey: currentName];  
  for (i = 0; i < [leaves count]; i++) {
    id leaf = [leaves objectAtIndex: i];    
    NSString *watched = [[[leaf node] path] stringByDeletingLastPathComponent];    

	  if ([watchedPaths containsObject: watched]) {
		  [watchedPaths removeObject: watched];
      
      if ([watchedPaths containsObject: watched] == NO) {
        [gw removeWatcherForPath: watched];
      }
	  }
    
    [[leaf window] close];    
  }

  [layers removeObjectForKey: currentName];     
  ASSIGN (currentName, newname);  
  
  [self switchLayer: ffButt];
}

- (void)renameCurrentLayer
{
  SympleDialog *dialog;
  NSString *layerName;
  NSMutableArray *leaves;
  int result;
  
  if ([myWin isVisible] == NO) {
    return;
  }
  
  dialog = [[SympleDialog alloc] initWithTitle: NSLocalizedString(@"Rename Layer", @"") 
                                      editText: currentName
                                   switchTitle: nil];
  [dialog center];
  [dialog makeKeyWindow];
  [dialog orderFrontRegardless];
  
  result = [dialog runModal];
  [dialog release];
  
  if(result != NSAlertDefaultReturn)
    return;
  
  layerName = [dialog getEditFieldText];
  if ([layerName isEqual: currentName]) {  
    return;
  }
  
  if ([[layers allKeys] containsObject: layerName]) {
		NSString *msg = NSLocalizedString(@"A layer with this name is already present!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);  
    return;
	}
  
  leaves = [layers objectForKey: currentName];
  RETAIN (leaves);
  [layers removeObjectForKey: currentName];  
  ASSIGN (currentName, layerName);
  [layers setObject: leaves forKey: currentName];
  RELEASE (leaves);
  
  [namelabel setStringValue: cutFileLabelText(currentName, namelabel, 52)];
  [self setNeedsDisplay: YES];  
}

- (void)goToLayerNamed:(NSString *)lname
{
  NSArray *leaves;
  int i;

  if ([myWin isVisible] == NO) {
    return;
  }
  
  leaves = [layers objectForKey: currentName];  
  for (i = 0; i < [leaves count]; i++) {
    [[[leaves objectAtIndex: i] window] orderOut: self];
  }

  ASSIGN (currentName, lname);
	[self orderFrontLeaves];
  [self findFreePositions];
  
  [namelabel setStringValue: cutFileLabelText(currentName, namelabel, 52)];
  [self setNeedsDisplay: YES];
}

- (void)switchLayer:(id)sender
{
  NSArray *names, *leaves;
  NSString *newname;
  int i, index;

  if ([myWin isVisible] == NO) {
    return;
  }
  
  names = [layers allKeys];  
	index = [names indexOfObject: currentName];
	
  if (sender == ffButt) {
    if (index == [names count] -1) {
      index = -1;
    }
    index++;
  } else {
    if (index == 0) {
      index = [names count];
    }
    index--;
  }

  newname = [names objectAtIndex: index];
      
  leaves = [layers objectForKey: currentName];  
  for (i = 0; i < [leaves count]; i++) {
    [[[leaves objectAtIndex: i] window] orderOut: self];
  }

  ASSIGN (currentName, newname);
	[self orderFrontLeaves];
  [self findFreePositions];
  
  [namelabel setStringValue: cutFileLabelText(currentName, namelabel, 52)];
  [self setNeedsDisplay: YES];
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}

- (void)mouseDown:(NSEvent*)theEvent
{
	NSEvent *nextEvent;
  NSPoint location, lastLocation, origin, leaforigin;
  float initx, inity;
  id leaf;
  NSWindow *leafWin;
  NSArray *names, *leaves;
  int i, j;
  BOOL hidden = NO, dragged = NO;
  
  [self orderFrontLeaves];

  leaves = [layers objectForKey: currentName];
    
	if ([theEvent clickCount] > 1) {    
    if (leaveshidden == NO) {    
      leaveshidden = YES;
      for (i = 0; i < [leaves count]; i++) {
        leafWin = [[leaves objectAtIndex: i] window];
        [leafWin orderOut: nil];
      }  
    } else {
      leaveshidden = NO;
      [self orderFrontLeaves];
    }    
    return;
	}  

  names = [layers allKeys];
  
  initx = [myWin frame].origin.x;
  inity = [myWin frame].origin.y;
  
  lastLocation = [theEvent locationInWindow];

  while (1) {
	  nextEvent = [myWin nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];

    if ([nextEvent type] == NSLeftMouseUp) {    
      if (dragged == YES) {
        float nowx = [myWin frame].origin.x;
        float nowy = [myWin frame].origin.y;
        
        for (i = 0; i < [names count]; i++) {
          leaves = [layers objectForKey: [names objectAtIndex: i]];  

          for (j = 0; j < [leaves count]; j++) {
            leaf = [leaves objectAtIndex: j];
            leafWin = [leaf window];
            leaforigin = [leafWin frame].origin;            
 		        leaforigin.x -= (initx - nowx);
		        leaforigin.y -= (inity - nowy);                        
            [leafWin setFrameOrigin: leaforigin];        
          }
        }
      }
    
      [self findFreePositions];            
      [self orderFrontLeaves];
      [self updateDefaults];
      break;

    } else if ([nextEvent type] == NSLeftMouseDragged) {
      dragged = YES;
      
      if (hidden == NO) {
        for (i = 0; i < [names count]; i++) {
          leaves = [layers objectForKey: [names objectAtIndex: i]];          
          for (j = 0; j < [leaves count]; j++) {
            leaf = [leaves objectAtIndex: j];        
            [[leaf window] orderOut: self];                                   
          }
        }
        hidden = YES;
      }
      
 		  location = [myWin mouseLocationOutsideOfEventStream];
      origin = [myWin frame].origin;
		  origin.x += (location.x - lastLocation.x);
		  origin.y += (location.y - lastLocation.y);
      [myWin setFrameOrigin: origin];
      
    }
  }
}                                                        

- (void)draggedFiendLeaf:(FiendLeaf *)leaf
                 atPoint:(NSPoint)location 
                 mouseUp:(BOOL)mouseup
{
  LeafPosition *leafpos;
  static NSMutableArray *leaves;
  static FiendLeaf *hlightleaf;
  BOOL hlight, newpos;
  int i;
  NSRect r;
  static BOOL started = NO;
    
  if (started == NO) {  
    leaves = [layers objectForKey: currentName];  
    hlightleaf = nil;
    leafpos = [[LeafPosition alloc] initWithPosX: [leaf posx] posY: [leaf posy] 
                                 relativeToPoint: [[self window] frame].origin];
    [freePositions addObject: leafpos];
    RELEASE (leafpos);
    started = YES;
  }
  
  r = [myWin frame];
  
  if (mouseup == NO) {  
    hlight = NO;
    for (i = 0; i < [freePositions count]; i++) {
      LeafPosition *lfpos = [freePositions objectAtIndex: i];
      
      if ([lfpos containsPoint: location]) {
        if (hlightleaf == nil) {        
          hlightleaf = [[FiendLeaf alloc] initWithPosX: [lfpos posx] 
                                                  posY: [lfpos posy] 
                                       relativeToPoint: r.origin 
                                               forPath: nil 
                                               inFiend: self 
                                             layerName: nil
                                            ghostImage: [leaf icon]];
          [[hlightleaf window] display];                           
          [[hlightleaf window] orderBack: self];                                 
        } else {        
          [hlightleaf setPosX: [lfpos posx] posY: [lfpos posy] relativeToPoint: r.origin];        
          [[hlightleaf window] orderBack: self];                                 
        }
                             
        hlight = YES;
        break;
      }
    }
      
    if ((hlight == NO) && (hlightleaf != nil)) { 
      [[hlightleaf window] orderOut: self]; 
      RELEASE (hlightleaf);
      hlightleaf = nil;
    }
    
  } else {
    if (hlightleaf != nil) { 
      [[hlightleaf window] orderOut: nil]; 
      RELEASE (hlightleaf);
      hlightleaf = nil;
    }
      
    newpos = NO;
    for (i = 0; i < [freePositions count]; i++) {
      leafpos = [freePositions objectAtIndex: i];
      
      if ([leafpos containsPoint: location]) {
        [leaf setPosX: [leafpos posx] posY: [leafpos posy] relativeToPoint: r.origin];        
        newpos = YES;
        break;
      }
    }
      
    if (newpos == NO) {    
      NSString *watched = [[[leaf node] path] stringByDeletingLastPathComponent];    

	    if ([watchedPaths containsObject: watched]) {
		    [watchedPaths removeObject: watched];
        
        if ([watchedPaths containsObject: watched] == NO) {
          [gw removeWatcherForPath: watched];
        }
	    }
    
      [[leaf window] close];
      [leaves removeObject: leaf];
    }
      
    [self orderFrontLeaves];
    [self findFreePositions];
    started = NO;
  }
}

- (void)findFreePositions
{
  NSArray *leaves;
  id leaf;
  NSArray *positions;
  int posx, posy;
  int i, j, m, count;
      
  RELEASE (freePositions);
  freePositions = [[NSMutableArray alloc] initWithCapacity: 1];

  positions = [self positionsAroundLeafAtPosX: 0 posY: 0];
  [freePositions addObjectsFromArray: positions];

  leaves = [layers objectForKey: currentName];
  
  for (i = 0; i < [leaves count]; i++) {
    leaf = [leaves objectAtIndex: i];
    posx = [leaf posx];
    posy = [leaf posy];   
    positions = [self positionsAroundLeafAtPosX: posx posY: posy];
    [freePositions addObjectsFromArray: positions];
  }

  count = [freePositions count];
  for (i = 0; i < count; i++) {
    BOOL inuse = NO;
    LeafPosition *lpos = [freePositions objectAtIndex: i];
    posx = [lpos posx];
    posy = [lpos posy];

    inuse = (posx == 0 && posy == 0);

    if (inuse == NO) {    
      for (j = 0; j < [leaves count]; j++) {
        leaf = [leaves objectAtIndex: j];
        inuse = (posx == [leaf posx] && posy == [leaf posy]);
        if (inuse == YES) {
          break;
        }
      }
    }
    
    if (inuse == NO) {    
      for (m = 0; m < count; m++) {
        LeafPosition *lpos2 = [freePositions objectAtIndex: m]; 
        if (m != i) {    
          inuse = (posx == [lpos2 posx] && posy == [lpos2 posy]);
          if (inuse == YES) {
            break;
          }    
        }
      }
    }
    
    if (inuse == YES) { 
      [freePositions removeObjectAtIndex: i];
      i--;
      count--;
    }
  }
  
}

- (NSArray *)positionsAroundLeafAtPosX:(int)posx posY:(int)posy
{
  NSMutableArray *leafpositions;
  LeafPosition *leafpos;  
  NSPoint or;
  int x, y;

  or = [myWin frame].origin;
  
  leafpositions = [NSMutableArray arrayWithCapacity: 1];
    
  for (x = posx - 1; x <= posx + 1; x++) {
    for (y = posy + 1; y >= posy - 1; y--) {      
      if ((x == posx && y == posy) == NO) {
        leafpos = [[LeafPosition alloc] initWithPosX: x posY: y relativeToPoint: or];
        [leafpositions addObject: leafpos];
        RELEASE (leafpos);
      }
    }
  }

  return leafpositions;
}

- (void)orderFrontLeaves
{
  NSArray *leaves;
  int i;

  leaves = [layers objectForKey: currentName];  
	[myWin orderFront: nil]; 
	[myWin setLevel: NSNormalWindowLevel];
	
	[self setNeedsDisplay: YES];
  if (leaveshidden == NO) {
    for (i = 0; i < [leaves count]; i++) {
			NSWindow *win = [[leaves objectAtIndex: i] window];
    	[win orderFront: nil];
			[win setLevel: NSNormalWindowLevel];
    }
  }   
}

- (void)hide
{
  NSArray *leaves;
  int i;

  leaves = [layers objectForKey: currentName];  
  for (i = 0; i < [leaves count]; i++) {
    [[[leaves objectAtIndex: i] window] orderOut: self];
  }
  
  [myWin orderOut: self]; 
}

- (void)verifyDraggingExited:(id)sender
{
  NSArray *leaves;
  int i;

  leaves = [layers objectForKey: currentName];  
  
  for (i = 0; i < [leaves count]; i++) {
    FiendLeaf *leaf = [leaves objectAtIndex: i];
    
    if ((leaf != (FiendLeaf *)sender) && ([leaf isDragTarget] == YES)) {
      [leaf draggingExited: nil];
    }
  }
}

- (void)removeInvalidLeaf:(FiendLeaf *)leaf
{
  NSString *layerName = [leaf layerName];
  NSMutableArray *leaves = [layers objectForKey: layerName];
  NSString *watched = [[[leaf node] path] stringByDeletingLastPathComponent];    

  if ([watchedPaths containsObject: watched]) {
    [watchedPaths removeObject: watched];
    
    if ([watchedPaths containsObject: watched] == NO) {
      [gw removeWatcherForPath: watched];
    }
  }
  
  [[leaf window] close];
  [leaves removeObject: leaf]; 
}

- (void)checkIconsAfterDotsFilesChange
{
  NSArray *names = [layers allKeys];
  int i;

  for (i = 0; i < [names count]; i++) {
    NSString *lname = [names objectAtIndex: i];
    NSMutableArray *leaves = [layers objectForKey: lname];
    int count = [leaves count];
    BOOL modified = NO;  
    int j;

    for (j = 0; j < count; j++) {
      id leaf = [leaves objectAtIndex: j];
      NSString *leafpath = [[leaf node] path];
      
      if ([leafpath rangeOfString: @"."].location != NSNotFound) {
        [self removeInvalidLeaf: leaf];
        modified = YES;   
        count--;
        j--;
      }
    }
    
    if (modified && ([lname isEqual: currentName])) {
      [self orderFrontLeaves];
      [self findFreePositions];
    }
  }
}

- (void)checkIconsAfterHidingOfPaths:(NSArray *)paths
{
  NSArray *names = [layers allKeys];
  int i;

  for (i = 0; i < [names count]; i++) {
    NSString *lname = [names objectAtIndex: i];
    NSMutableArray *leaves = [layers objectForKey: lname];
    int count = [leaves count];
    BOOL modified = NO;  
    int j, m;

    for (j = 0; j < count; j++) {
      id leaf = [leaves objectAtIndex: j];
      NSString *leafpath = [[leaf node] path];
      
      for (m = 0; m < [paths count]; m++) {
        NSString *path = [paths objectAtIndex: m]; 
      
        if (isSubpathOfPath(path, leafpath) || [path isEqual: leafpath]) {
          [self removeInvalidLeaf: leaf];          
          modified = YES;   
          count--;
          j--;
          break;
        }
      }
    }
    
    if (modified && ([lname isEqual: currentName])) {
      [self orderFrontLeaves];
      [self findFreePositions];
    }
  }
}

- (void)fileSystemDidChange:(NSNotification *)notification
{
  CREATE_AUTORELEASE_POOL(arp);
  NSDictionary *dict = [notification object];
  NSString *operation = [dict objectForKey: @"operation"];
  NSString *source = [dict objectForKey: @"source"];
  NSArray *files = [dict objectForKey: @"files"];
  
  if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
		files = [NSArray arrayWithObject: [source lastPathComponent]];
    source = [source stringByDeletingLastPathComponent];
  }	

  if ([operation isEqual: NSWorkspaceMoveOperation] 
        || [operation isEqual: NSWorkspaceDestroyOperation]
				|| [operation isEqual: @"GWorkspaceRenameOperation"]
				|| [operation isEqual: NSWorkspaceRecycleOperation]
				|| [operation isEqual: @"GWorkspaceRecycleOutOperation"]
				|| [operation isEqual: @"GWorkspaceEmptyRecyclerOperation"]) {
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity: 1];
    NSArray *names = [layers allKeys];    
    int i;
    
    for (i = 0; i < [files count]; i++) {
      NSString *s = [source stringByAppendingPathComponent: [files objectAtIndex: i]];
      [paths addObject: s];
    }

    for (i = 0; i < [names count]; i++) {
      NSString *lname = [names objectAtIndex: i];
      NSMutableArray *leaves = [layers objectForKey: lname];
      int count = [leaves count];
      BOOL modified = NO;  
      int j, m;

      for (j = 0; j < count; j++) {
        id leaf = [leaves objectAtIndex: j];
        NSString *leafpath = [[leaf node] path];

        for (m = 0; m < [paths count]; m++) {
          NSString *path = [paths objectAtIndex: m]; 

          if (isSubpathOfPath(path, leafpath) || [path isEqual: leafpath]) {
            [self removeInvalidLeaf: leaf];          
            modified = YES;   
            count--;
            j--;
            break;
          }
        }
      }
      
      if (modified && ([lname isEqual: currentName])) {
        [self orderFrontLeaves];
        [self findFreePositions];
      }
    }
  }
  
  RELEASE (arp);
}

- (void)watcherNotification:(NSNotification *)notification
{
  CREATE_AUTORELEASE_POOL(arp);
	NSDictionary *notifdict = (NSDictionary *)[notification object];
  NSString *path = [notifdict objectForKey: @"path"];
	NSString *event = [notifdict objectForKey: @"event"];
  NSEnumerator *enumerator;
  NSString *wpath;
	BOOL contained = NO;
	
	if ([event isEqual: @"GWFileCreatedInWatchedDirectory"]) {
    RELEASE (arp);
		return;
	}
  
  enumerator = [watchedPaths objectEnumerator];  
            
  while ((wpath = [enumerator nextObject])) {
		if (([wpath isEqual: path]) || (isSubpathOfPath(path, wpath))) {
			contained = YES;
			break;
		}
  }

  if (contained) {
    NSArray *names = [layers allKeys];
    int i;

    for (i = 0; i < [names count]; i++) {
      NSString *lname = [names objectAtIndex: i];
      NSMutableArray *leaves = [layers objectForKey: lname];
      int count = [leaves count];
      BOOL modified = NO;  
      int j;
      
      if ([event isEqual: @"GWWatchedPathDeleted"]) {
        for (j = 0; j < count; j++) {
          id leaf = [leaves objectAtIndex: j];
          NSString *leafpath = [[leaf node] path];

				  if (isSubpathOfPath(path, leafpath)) {
					  [self removeInvalidLeaf: leaf];
            modified = YES; 
					  count--;
					  j--;
				  }
        }

      } else if ([event isEqual: @"GWFileDeletedInWatchedDirectory"]) {
			  NSArray *files = [notifdict objectForKey: @"files"];
      
        for (j = 0; j < count; j++) {
          id leaf = [leaves objectAtIndex: j];
          NSString *leafpath = [[leaf node] path];
          int m;
          
          for (m = 0; m < [files count]; m++) {
            NSString *fname = [files objectAtIndex: m];
            NSString *fullPath = [path stringByAppendingPathComponent: fname];

            if ((isSubpathOfPath(fullPath, leafpath))
															      || ([fullPath isEqual: leafpath])) {
					    [self removeInvalidLeaf: leaf];
              modified = YES; 
					    count--;
					    j--;
              break;
            }
          }
        }
      }
      
      if (modified && ([lname isEqual: currentName])) {
        [self orderFrontLeaves];
        [self findFreePositions];
      }
    }
  }
  
  RELEASE (arp);
}

- (void)updateDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];		
  NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithCapacity: 1];
  NSArray *names = [layers allKeys];
  int i, j;
    
  for (i = 0; i < [names count]; i++) {
    NSString *name = [names objectAtIndex: i];   
    NSArray *leaves = [layers objectForKey: name];      
    NSMutableDictionary *pathsAndRects = [NSMutableDictionary dictionaryWithCapacity: 1];    
    
    for (j = 0; j < [leaves count]; j++) {
      NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity: 1];    
      id leaf = [leaves objectAtIndex: j];
      [dict setObject: [NSString stringWithFormat: @"%i", [leaf posx]] forKey: @"posx"];      
      [dict setObject: [NSString stringWithFormat: @"%i", [leaf posy]] forKey: @"posy"];      
      [pathsAndRects setObject: dict forKey: [[leaf node] path]];
    }
    
    [prefs setObject: pathsAndRects forKey: name];    
  }

 	[defaults setObject: prefs forKey: @"fiendlayers"];  
  [defaults setObject: currentName forKey: @"fiendcurrentlayer"];  
  
  [myWin saveFrameUsingName: @"fiend_window"];
}

- (void)drawRect:(NSRect)rect
{
  [self lockFocus];
	[tile compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver]; 
  [leftArr compositeToPoint: NSMakePoint(49, 6) 
                  operation: NSCompositeSourceOver]; 
  [rightArr compositeToPoint: NSMakePoint(37, 6) 
                   operation: NSCompositeSourceOver]; 
	[namelabel drawWithFrame: NSMakeRect(4, 50, 56, 10) inView: self];   
  [self unlockFocus];  
}

@end

@implementation Fiend (DraggingDestination)

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	
  if([[pb types] indexOfObject: NSFilenamesPboardType] != NSNotFound) {
  	NSDragOperation sourceDragMask = [sender draggingSourceOperationMask];
		
		if ((sourceDragMask == NSDragOperationCopy) 
											|| (sourceDragMask == NSDragOperationLink)) {
			return NSDragOperationNone;
		}
	
    isDragTarget = YES;
  	return NSDragOperationAll;
  }
     
  return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation sourceDragMask;
	
	if (isDragTarget == NO) {
		return NSDragOperationNone;
	}

	sourceDragMask = [sender draggingSourceOperationMask];

	if ((sourceDragMask == NSDragOperationCopy) 
												|| (sourceDragMask == NSDragOperationLink)) {
		return NSDragOperationNone;
	}

	return NSDragOperationAll;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	isDragTarget = NO;  
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return isDragTarget;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard *pb;
	NSArray *sourcePaths;
  NSString *path;
  NSString *basepath;
  NSMutableArray *leaves;
  id leaf;
  NSRect r;
  int px, py, posx, posy;
  int i;

  pb = [sender draggingPasteboard];
  sourcePaths = [pb propertyListForType: NSFilenamesPboardType];
  
  if ([sourcePaths count] > 1) {
		NSString *msg = NSLocalizedString(@"You can't dock multiple paths!", @"");
		NSString *buttstr = NSLocalizedString(@"Continue", @"");		
    NSRunAlertPanel(nil, msg, buttstr, nil, nil);
    isDragTarget = NO;
    return;
  }

  leaves = [layers objectForKey: currentName];  

  path = [sourcePaths objectAtIndex: 0];
  basepath = [path stringByDeletingLastPathComponent];

  if ([basepath isEqual: [gw trashPath]]) {
    isDragTarget = NO;
    return;
  }
    
  for (i = 0; i < [leaves count]; i++) {
    leaf = [leaves objectAtIndex: i];    
    if ([[[leaf node] path] isEqual: path] == YES) {
			NSString *msg = NSLocalizedString(@"This object is already present in this layer!", @"");
			NSString *buttstr = NSLocalizedString(@"Continue", @"");		
      NSRunAlertPanel(nil, msg, buttstr, nil, nil);
      isDragTarget = NO;
      return;
    }
  }
      
  r = [myWin frame];

  posx = 0;
  posy = 0;
  for (i = 0; i < [leaves count]; i++) {
    leaf = [leaves objectAtIndex: i];
    px = [leaf posx];
    py = [leaf posy];
    if ((px == posx) && (py < posy)) {
      posy = py;
    }
  }
  posy--;
                  
  leaf = [[FiendLeaf alloc] initWithPosX: posx 
                                    posY: posy
                         relativeToPoint: r.origin 
                                 forPath: path 
                                 inFiend: self 
                               layerName: currentName 
                              ghostImage: nil];                          
  [leaves addObject: leaf];
  RELEASE (leaf);
  
	if ([watchedPaths containsObject: basepath] == NO) {
    [gw addWatcherForPath: basepath];
	}
  
  [watchedPaths addObject: basepath];
  
  leaf = [leaves objectAtIndex: [leaves count] -1];
  [[leaf window] display]; 
  [self findFreePositions];  
  [self orderFrontLeaves];
  
  isDragTarget = NO;
  
  [self updateDefaults];
}

@end
