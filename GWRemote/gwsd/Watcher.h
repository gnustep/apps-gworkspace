
#ifndef WATCHER_H
#define WATCHER_H

#include <Foundation/NSObject.h>

@class NSString;
@class NSDictionary;
@class NSArray;
@class NSDate;
@class NSFileManager;
@class NSLock;
@class GWSd;

@interface Watcher : NSObject
{
  NSString *watchedPath;  
  NSArray *pathContents;
  int listeners;
  NSDate *date;
	NSFileManager *fm;
	BOOL isOld;
  BOOL suspended;
  GWSd *gwsd;
  NSRecursiveLock *clientLock;
}

- (id)initForforGWSd:(GWSd *)gw watchAtPath:(NSString *)path;

- (void)watchFile;

- (void)addListener;

- (void)removeListener;

- (int)listeners;

- (BOOL)isWathcingPath:(NSString *)apath;

- (NSString *)watchedPath;

- (void)setPathContents:(NSArray *)conts;

- (void)setDate:(NSDate *)d;

- (BOOL)isOld;

- (void)setIsOld;

- (BOOL)isSuspended;

- (void)setSuspended:(BOOL)value;

@end

#endif // WATCHER_H

