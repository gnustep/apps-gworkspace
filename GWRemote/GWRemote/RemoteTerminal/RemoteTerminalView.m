/* RemoteTerminalView.m
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
#include "GNUstep.h"
#include "GWRemote.h"
#include <GWorkspace/GWNotifications.h>
#include "RemoteTerminalView.h"
#include "RemoteTerminal.h"
#include "Functions.h"

@implementation RemoteTerminalView

- (void) dealloc
{
  RELEASE (fontDict);
  RELEASE (prompt);  
  [super dealloc];
}

- (id)initWithFrame:(NSRect)frame 
         inTerminal:(RemoteTerminal *)aTerminal
         remoteHost:(NSString *)hostname
{
  self = [super initWithFrame: frame];
  
  if (self) {
    NSFont *font;
    NSSize size;
    
    [self setRichText: NO];
    [self setImportsGraphics: NO];
    [self setUsesFontPanel: NO];
    [self setUsesRuler: NO];
    [self setEditable: YES];
    [self setAllowsUndo: YES];
    [self setMinSize: NSMakeSize(0,0)];
    [self setMaxSize: NSMakeSize(1e7, 1e7)];
    [self setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
    [self setVerticallyResizable: YES];
    [self setHorizontallyResizable: NO];
  
    size = NSMakeSize([self frame].size.width, 1e7);
    [[self textContainer] setContainerSize: size];
    [[self textContainer] setWidthTracksTextView: YES];
    
    font = [NSFont userFixedPitchFontOfSize: 12];
    fontDict = [[NSDictionary alloc] initWithObjects: 
                          [NSArray arrayWithObject: font] 
                     forKeys: [NSArray arrayWithObject: NSFontAttributeName]];
    
    terminal = aTerminal;
    ASSIGN (prompt, ([NSString stringWithFormat: @"%@ > ", hostname]));   
    [self insertText: prompt];
    cursor = [prompt length];
  }
    
  return self;
}

- (void)insertShellOutput:(NSString *)str
{
  cursor = [[self string] length] + [str length] + [prompt length];

  [self insertText: str];
  [self insertText: prompt];
}

- (void)insertText:(id)aString
{
  [super insertText: aString];
  [[self textStorage] setAttributes: fontDict
                              range: NSMakeRange(0, [[self string] length])];
  [self setSelectedRange: NSMakeRange([[self string] length], 0)];
}

- (void)keyDown:(NSEvent *)theEvent
{
  NSString *str = [theEvent characters];
  
  [super keyDown: theEvent];
  
  if([str isEqualToString: @"\r"]) {  
    int linelength = [[self string] length] - cursor;
    NSRange range = NSMakeRange(cursor, linelength);
    NSString *str = [[self string] substringWithRange: range];
    
    [terminal newCommandLine: str];
    [self insertText: prompt];
    cursor += ([str length] + [prompt length]);
  }
}

@end
