/* LSFolder.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: October 2004
 *
 * This file is part of the GNUstep Finder application
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
#include <math.h>
#include "LSFolder.h"
#include "LSFUpdater.h"
#include "ResultsTableView.h"
#include "ResultsTextCell.h"
#include "ResultsPathsView.h"
#include "Finder.h"
#include "FinderModulesProtocol.h"
#include "Functions.h"
#include "config.h"

#define LSF_INFO(x) [x stringByAppendingPathComponent: @"lsf.info"]
#define LSF_FOUND(x) [x stringByAppendingPathComponent: @"lsf.found"]

static NSString *nibName = @"LSFolder";

BOOL isPathInResults(NSString *path, NSArray *results);

@implementation LSFolder

- (void)dealloc
{
	[nc removeObserver: self];

  if (updater) {
    [updater exitThread];
    DESTROY (updater);
    DESTROY (updaterconn);
  }
    
  if (watcherSuspended == NO) {
    [finder removeWatcherForPath: [node path]];
  }
  
  TEST_RELEASE (node);
  TEST_RELEASE (lsfinfo);

  TEST_RELEASE (win);
         
  [super dealloc];
}

- (id)initForNode:(FSNode *)anode
    needsIndexing:(BOOL)index
{
	self = [super init];

  if (self) {
    NSDictionary *dict = nil;

    updater = nil;
    actionPending = NO;
    updaterbusy = NO;
    
    win = nil;
    
    fm = [NSFileManager defaultManager];
    
    if ([anode isValid] && [anode isDirectory]) {
      NSString *dpath = LSF_INFO([anode path]);
      
      if ([fm fileExistsAtPath: dpath]) {
        dict = [NSDictionary dictionaryWithContentsOfFile: dpath];
      }
    }
    
    if (dict) {
      ASSIGN (node, anode);
      ASSIGN (lsfinfo, dict);
      
      finder = [Finder finder];
      [finder addWatcherForPath: [node path]];
      watcherSuspended = NO;
      nc = [NSNotificationCenter defaultCenter];

      if (index) {
        nextSelector = @selector(ddbdInsertTrees);
        actionPending = YES;    
        [self startUpdater];
      }

    } else {
      DESTROY (self);
    }    
  }
  
	return self;
}

- (void)loadInterface
{
  if ([NSBundle loadNibNamed: nibName owner: self]) {













  } else {
    NSLog(@"failed to load %@!", nibName);
  }
}

- (void)setNode:(FSNode *)anode
{
  if (watcherSuspended == NO) {
    [finder removeWatcherForPath: [node path]];
  }
  ASSIGN (node, anode);
  [finder addWatcherForPath: [node path]];
}

- (FSNode *)node
{
  return node;
}

- (NSString *)infoPath
{
  return LSF_INFO([node path]);
}

- (NSString *)foundPath
{
  return LSF_FOUND([node path]);
}

- (BOOL)watcherSuspended
{
  return watcherSuspended;
}

- (void)setWatcherSuspended:(BOOL)value
{
  watcherSuspended = value;
}

- (void)startUpdater
{
  NSMutableDictionary *info = [NSMutableDictionary dictionary];
  NSPort *port[2];
  NSArray *ports;

  port[0] = (NSPort *)[NSPort port];
  port[1] = (NSPort *)[NSPort port];

  ports = [NSArray arrayWithObjects: port[1], port[0], nil];

  updaterconn = [[NSConnection alloc] initWithReceivePort: port[0]
				                                         sendPort: port[1]];
  [updaterconn setRootObject: self];
  [updaterconn setDelegate: self];

  [nc addObserver: self
         selector: @selector(connectionDidDie:)
             name: NSConnectionDidDieNotification
           object: updaterconn];    

  [info setObject: ports forKey: @"ports"];
  [info setObject: lsfinfo forKey: @"lsfinfo"];
  
  [nc addObserver: self
         selector: @selector(threadWillExit:)
             name: NSThreadWillExitNotification
           object: nil];     
  
  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(newUpdater:)
		                           toTarget: [LSFUpdater class]
		                         withObject: info];
    }
  NS_HANDLER
    {
      NSRunAlertPanel(nil, 
                      NSLocalizedString(@"A fatal error occured while detaching the thread!", @""), 
                      NSLocalizedString(@"Continue", @""), 
                      nil, 
                      nil);
      [self endUpdate];
    }
  NS_ENDHANDLER
}

- (IBAction)update:(id)sender
{
  if (sender == nil) {
    [self loadInterface];
  }

  if (actionPending) {
    NSLog(@"update return 1");
    return;
  }
  
  if (updater == nil) {
    nextSelector = @selector(update);
    actionPending = YES;    
    [self startUpdater];
    NSLog(@"update return 2");
    return;
  }
  
  if (updaterbusy) {
    nextSelector = @selector(update);
    actionPending = YES;
    NSLog(@"update return 3");
    return;
  }

  [updater update];
}

- (void)setUpdater:(id)anObject
{
  [anObject setProtocolForProxy: @protocol(LSFUpdaterProtocol)];
  updater = (id <LSFUpdaterProtocol>)[anObject retain];
  
  NSLog(@"updater registered");

  if (actionPending) {
    actionPending = NO;
    updaterbusy = YES;
    [(id)updater performSelector: nextSelector];
  }
}

- (void)updaterDidEndAction
{
  updaterbusy = NO;
  
  if (actionPending) {
    actionPending = NO;
    updaterbusy = YES;
    [(id)updater performSelector: nextSelector];
  }
}

- (void)endUpdate
{
  if (updater) {
    [nc removeObserver: self
	                name: NSConnectionDidDieNotification 
                object: updaterconn];
    [updater exitThread];
    DESTROY (updater);
    DESTROY (updaterconn);
    
    [nc removeObserver: self
	                name: NSThreadWillExitNotification 
                object: nil];
  }

  actionPending = NO;
  updaterbusy = NO;
}
         
- (BOOL)connection:(NSConnection*)ancestor 
								shouldMakeNewConnection:(NSConnection*)newConn
{
	if (ancestor == updaterconn) {
  	[newConn setDelegate: self];
  	[nc addObserver: self 
					 selector: @selector(connectionDidDie:)
	    				 name: NSConnectionDidDieNotification 
             object: newConn];
  	return YES;
	}
		
  return NO;
}

- (void)connectionDidDie:(NSNotification *)notification
{
  [nc removeObserver: self
	              name: NSConnectionDidDieNotification 
              object: [notification object]];

//  if (opdone == NO) {
    NSRunAlertPanel(nil, 
                    NSLocalizedString(@"updater connection died!", @""), 
                    NSLocalizedString(@"Continue", @""), 
                    nil, 
                    nil);
    [self endUpdate];
//  }
}

- (void)threadWillExit:(NSNotification *)notification
{
  NSLog(@"lsf update thread will exit");
}

@end


@implementation ProgrView

#define PROG_IND_MAX (-40)

- (void)dealloc
{
  RELEASE (image);
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frameRect 
    refreshInterval:(float)refresh
{
  self = [super initWithFrame: frameRect];

  if (self) {
    ASSIGN (image, [NSImage imageNamed: @"progind"]);
    rfsh = refresh;
    orx = PROG_IND_MAX;
    animating = NO;
  }

  return self;
}

- (void)start
{
  animating = YES;
  progTimer = [NSTimer scheduledTimerWithTimeInterval: rfsh 
						            target: self selector: @selector(animate:) 
																					userInfo: nil repeats: YES];
}

- (void)stop
{
  animating = NO;
  if (progTimer && [progTimer isValid]) {
    [progTimer invalidate];
  }
  [self setNeedsDisplay: YES];
}

- (void)animate:(id)sender
{
  orx++;
  [self setNeedsDisplay: YES];
  
  if (orx == 0) {
    orx = PROG_IND_MAX;
  }
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  
  if (animating) {
    [image compositeToPoint: NSMakePoint(orx, 0) 
                  operation: NSCompositeSourceOver];
  }
}

@end










