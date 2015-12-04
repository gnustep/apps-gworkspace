/* GWThumbnailer.h
 *  
 * Copyright (C) 2003-2015 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 *         Riccardo Mottola <rm@gnu.org>
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

#define TMBMAX (64.0)
#define RESZLIM 4

@protocol TMBProtocol

- (BOOL)canProvideThumbnailForPath:(NSString *)path;

- (NSData *)makeThumbnailForPath:(NSString *)path;

- (NSString *)fileNameExtension;

- (NSString *)description;

@end


@interface Thumbnailer: NSObject
{
  NSMutableArray *thumbnailers;
  NSMutableDictionary *extProviders;
  id current;
  NSString *thumbnailDir;
  NSString *dictPath;
  NSMutableDictionary *thumbsDict;
  long thumbref; 
  NSTimer *timer; 
  NSConnection *conn;
  NSFileManager *fm;
  NSLock *dictLock;
  NSMutableArray *pathsInProcessing;
}

+ (Thumbnailer *)sharedThumbnailer;

- (void)writeDictToFile;

- (void)loadThumbnailers;

- (BOOL)addThumbnailer:(id)tmb;

- (id)thumbnailerForPath:(NSString *)path;

- (NSString *)nextThumbName;

- (void)checkThumbnails:(id)sender;

- (BOOL)registerThumbnailData:(NSData *)data 
                      forPath:(NSString *)path
                nameExtension:(NSString *)ext;

- (BOOL)removeThumbnailForPath:(NSString *)path;

- (void)makeThumbnails:(NSString*)path;

- (void)removeThumbnails:(NSString*)path;


- (NSArray *)bundlesWithExtension:(NSString *)extension
inDirectory:(NSString *)dirpath;

@end
