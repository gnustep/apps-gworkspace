/* ddbd.m
 *  
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: February 2004
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

#include <AppKit/AppKit.h>
#include "ddbd.h"

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifdef __MINGW__
  #include "process.h"
#endif
#include <fcntl.h>
#ifdef HAVE_SYSLOG_H
  #include <syslog.h>
#endif
#include <signal.h>

#define SYNC_INTERVAL (3600.0)
#define MIN_INTERVAL (60.0)
#define MAX_INTERVAL (86400.0)

#define PATHSIZE 512
#define ANNSIZE 8192

typedef struct {
  char path[PATHSIZE];
  unsigned long long annoffset;
  double timestamp;
} dbpath;

typedef struct {
  char ann[ANNSIZE];
  char path[PATHSIZE];
} annotation;

enum {   
  DDBdPrepareDbUpdate,
  DDBdInsertTreeUpdate,
  DDBdRemoveTreeUpdate,
  DDBdFileOperationUpdate,
  DDBdSynchronize
};

static BOOL inited = NO;

static NSString *dbdir = nil;

static NSMutableSet *dirsSet = nil;
static NSFileHandle *dirsAddHandle = nil; 
static NSFileHandle *dirsRmvHandle = nil; 
static NSRecursiveLock *dirslock = nil; 

static NSMutableDictionary *pathsDict = nil;
static NSFileHandle *pathsAddHandle = nil; 
static NSFileHandle *pathsRmvHandle = nil; 
static NSRecursiveLock *pathslock = nil; 

static NSFileHandle *annsHandle = nil; 
static NSRecursiveLock *annslock = nil; 

static NSFileManager *fm = nil;
static SEL existsSel = @selector(fileExistsAtPath:);
typedef BOOL (*boolIMP)(id, SEL, id);
boolIMP existsImp;  

BOOL createDb(void);

BOOL readDirectories(void);
BOOL writeDirectories(void);
void addDirectory(NSString *path);
void removeDirectory(NSString *path);
void checkDirectories(void);
void synchronizeDirectories(void);

void readPaths(void);
BOOL writePaths(void);    
NSMutableDictionary *addPath(NSString *path);
void removePath(NSString *path);
void pathUpdated(NSString *path);
void checkPaths(void);
void synchronizePaths(void);

NSString *annotationsForPath(NSString *path);
void setAnnotationsForPath(NSString *annotations, NSString *path);
NSString *pathForAnnotationsOffset(unsigned long long offset);
void checkAnnotations(void);

void duplicatePathInfo(NSString *srcpath, NSString *dstpath);
BOOL subpathOfPath(NSString *p1, NSString *p2);
NSString *path_separator(void);
NSString *pathRemovingPrefix(NSString *path, NSString *prefix);

@implementation	DDBd

- (void)dealloc
{
  if (syncTimer && [syncTimer isValid]) {
    [syncTimer invalidate];
    DESTROY (syncTimer);
  }

  [[NSDistributedNotificationCenter defaultCenter] removeObserver: self];

  if (conn) {
    [nc removeObserver: self
		              name: NSConnectionDidDieNotification
		            object: conn];
    DESTROY (conn);
  }
            
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (self) {   
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	      
    id interval = [defaults objectForKey: @"sync-interval"];
    
    syncinterval = SYNC_INTERVAL;
    
    if (interval) {
      float f = [interval floatValue];
  
      if ((f >= MIN_INTERVAL) && (f <= MAX_INTERVAL)) {
        syncinterval = f;
        NSLog(@"synchronize interval set to %.2f", syncinterval);
      } 
    }
   
    fm = [NSFileManager defaultManager];	
    existsImp = (boolIMP)[fm methodForSelector: existsSel];  
    nc = [NSNotificationCenter defaultCenter];
    
    dirslock = [NSRecursiveLock new];
    pathslock = [NSRecursiveLock new];
    annslock = [NSRecursiveLock new];
   
    dirsSet = [[NSMutableSet alloc] initWithCapacity: 1];
    pathsDict = [NSMutableDictionary new];   
           
    conn = [NSConnection defaultConnection];
    [conn setRootObject: self];
    [conn setDelegate: self];

    if ([conn registerName: @"ddbd"] == NO) {
	    NSLog(@"unable to register with name server - quiting.");
	    DESTROY (self);
	    return self;
	  }
          
    [nc addObserver: self
           selector: @selector(connectionBecameInvalid:)
	             name: NSConnectionDidDieNotification
	           object: conn];
    
    [nc addObserver: self
       selector: @selector(threadWillExit:)
           name: NSThreadWillExitNotification
         object: nil];    

    [[NSDistributedNotificationCenter defaultCenter] addObserver: self 
                				  selector: @selector(fileSystemDidChange:) 
                					    name: @"GWFileSystemDidChangeNotification"
                					  object: nil];

    syncTimer = [NSTimer scheduledTimerWithTimeInterval: syncinterval
                                     target: self
                                   selector: @selector(synchronize:)
                                   userInfo: nil
                                    repeats: YES];
    RETAIN (syncTimer);
    
    NSLog(@"ddbd started");
  }
  
  return self;    
}

- (void)prepareDb
{
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
    
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdPrepareDbUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: [NSDictionary dictionary] forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DBUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occured while detaching the thread!");
    }
  NS_ENDHANDLER
}

- (BOOL)dbactive
{
  return inited;
}

- (BOOL)insertPath:(NSString *)path
{
  NSDictionary *attributes = [fm fileAttributesAtPath: path traverseLink: NO];

  if (attributes) {
    addPath(path);
    if ([attributes fileType] == NSFileTypeDirectory) {
      addDirectory(path);
    }
  }

  return YES; 
}

- (BOOL)removePath:(NSString *)path
{
  removePath(path);
  removeDirectory(path);
  
  return YES; 
}

- (void)insertDirectoryTreesFromPaths:(NSData *)info
{
  NSArray *paths = [NSUnarchiver unarchiveObjectWithData: info];
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
  NSDictionary *dict = [NSDictionary dictionaryWithObject: paths 
                                                   forKey: @"paths"];
    
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdInsertTreeUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: dict forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DBUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occured while detaching the thread!");
    }
  NS_ENDHANDLER
}

- (void)removeTreesFromPaths:(NSData *)info
{
  NSArray *paths = [NSUnarchiver unarchiveObjectWithData: info];
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
  NSDictionary *dict = [NSDictionary dictionaryWithObject: paths 
                                                   forKey: @"paths"];

  [updaterInfo setObject: [NSNumber numberWithInt: DDBdRemoveTreeUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: dict forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DBUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occured while detaching the thread!");
    }
  NS_ENDHANDLER
}

- (NSData *)directoryTreeFromPath:(NSString *)apath
{
  CREATE_AUTORELEASE_POOL(pool);
  NSMutableArray *directories = [NSMutableArray array];  
  NSEnumerator *enumerator;
  NSString *path;
        
  [dirslock lock];
  enumerator = [dirsSet objectEnumerator];
    
  while ((path = [enumerator nextObject])) {
    if (subpathOfPath(apath, path) && (*existsImp)(fm, existsSel, path)) {
      [directories addObject: path];
    }
  }   
    
  [dirslock unlock];
    
  if ([directories count]) { 
    NSData *data = [NSArchiver archivedDataWithRootObject: directories]; 
  
    RETAIN (data);
    RELEASE (pool);
  
    return AUTORELEASE (data);
  }

  RELEASE (pool);
  
  return nil;
}

- (NSString *)annotationsForPath:(NSString *)path
{
  return annotationsForPath(path);
}

- (oneway void)setAnnotations:(NSString *)annotations
                      forPath:(NSString *)path
{
  setAnnotationsForPath(annotations, path);
}

- (void)connectionBecameInvalid:(NSNotification *)notification
{
  id connection = [notification object];

  [nc removeObserver: self
	              name: NSConnectionDidDieNotification
	            object: connection];

  if (connection == conn) {
    NSLog(@"argh - ddbd root connection has been destroyed.");
    exit(EXIT_FAILURE);
  } 
}

- (BOOL)connection:(NSConnection *)ancestor
            shouldMakeNewConnection:(NSConnection *)newConn;
{
  [nc addObserver: self
         selector: @selector(connectionBecameInvalid:)
	           name: NSConnectionDidDieNotification
	         object: newConn];
           
  [newConn setDelegate: self];
  
  return YES;
}

- (void)fileSystemDidChange:(NSNotification *)notif
{
  NSDictionary *info = [notif userInfo];
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
    
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdFileOperationUpdate] 
                  forKey: @"type"];
  [updaterInfo setObject: info forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DBUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occured while detaching the thread!");
    }
  NS_ENDHANDLER
}

- (void)synchronize:(id)sender
{
  NSMutableDictionary *updaterInfo = [NSMutableDictionary dictionary];
  id interval;
    
  [updaterInfo setObject: [NSNumber numberWithInt: DDBdSynchronize] 
                  forKey: @"type"];
  [updaterInfo setObject: [NSDictionary dictionary] forKey: @"taskdict"];

  NS_DURING
    {
      [NSThread detachNewThreadSelector: @selector(updaterForTask:)
		                           toTarget: [DBUpdater class]
		                         withObject: updaterInfo];
    }
  NS_HANDLER
    {
      NSLog(@"A fatal error occured while detaching the thread!");
    }
  NS_ENDHANDLER
  
  interval = [[NSUserDefaults standardUserDefaults] objectForKey: @"sync-interval"];

  if (interval) {
    float f = [interval floatValue];

    if ((f != syncinterval) && (f >= MIN_INTERVAL) && (f <= MAX_INTERVAL)) {
      syncinterval = f;

      if (syncTimer && [syncTimer isValid]) {
        [syncTimer invalidate];
        DESTROY (syncTimer);
      }

      syncTimer = [NSTimer scheduledTimerWithTimeInterval: syncinterval
                                     target: self
                                   selector: @selector(synchronize:)
                                   userInfo: nil
                                    repeats: YES];
      RETAIN (syncTimer);
      NSLog(@"synchronize interval set to %.2f", syncinterval);
    } 
  }
}

- (void)threadWillExit:(NSNotification *)notification
{
  NSLog(@"db update thread will exit");
}

@end


@implementation	DBUpdater

- (void)dealloc
{
  RELEASE (updinfo);
	[super dealloc];
}

+ (void)updaterForTask:(NSDictionary *)info
{
  CREATE_AUTORELEASE_POOL(arp);
  DBUpdater *updater = [[self alloc] init];
  
  [updater setUpdaterTask: info];
  RELEASE (updater);
                              
  [[NSRunLoop currentRunLoop] run];
  RELEASE (arp);
}

- (void)setUpdaterTask:(NSDictionary *)info
{
  NSDictionary *dict = [info objectForKey: @"taskdict"];
  int type = [[info objectForKey: @"type"] intValue];
  
  ASSIGN (updinfo, dict);
  
  RETAIN (self);
    
  NSLog(@"starting db update");

  switch(type) {
    case DDBdPrepareDbUpdate:
      [self prepareDb];
      break;

    case DDBdInsertTreeUpdate:
      [self insertTrees];
      break;

    case DDBdRemoveTreeUpdate:
      [self removeTrees];
      break;

    case DDBdFileOperationUpdate:
      [self fileSystemDidChange];
      break;

    case DDBdSynchronize:
      [self synchronize];
      break;

    default:
      [self done];
      break;
  }
}

- (void)done
{
  RELEASE (self);
  [NSThread exit];
}

- (void)prepareDb
{
  if (createDb() == NO) {
    NSLog(@"unable to create the database files.");
    exit(EXIT_FAILURE);
  }

  fprintf(stderr, "reading directories... "); 
  if (readDirectories() == NO) {
    NSLog(@"\nunable to read from the db.");
    exit(EXIT_FAILURE);
  }
  fprintf(stderr, "done\n");
  
  fprintf(stderr, "checking directories... ");
  checkDirectories();  
  fprintf(stderr, "done\n");
  
  fprintf(stderr, "synchronizing directories... ");
  synchronizeDirectories();
  fprintf(stderr, "done\n");

  fprintf(stderr, "reading paths... ");   
  readPaths();
  fprintf(stderr, "done\n");
  
  fprintf(stderr, "checking paths... ");   
  checkPaths();  
  fprintf(stderr, "done\n"); 
  
  fprintf(stderr, "synchronizing paths... ");
  synchronizePaths(); 
  fprintf(stderr, "done\n");

  fprintf(stderr, "checking file annotations... ");   
  checkAnnotations();
  fprintf(stderr, "done\n");
  
  inited = YES;
  
  [self done];
}

- (void)insertTrees
{
  NSArray *basePaths = [updinfo objectForKey: @"paths"];
  int i;

  for (i = 0; i < [basePaths count]; i++) {
    CREATE_AUTORELEASE_POOL(arp);
    NSString *base = [basePaths objectAtIndex: i];  
    NSDictionary *attributes = [fm fileAttributesAtPath: base traverseLink: NO];
    NSString *type = [attributes fileType];

    if (type == NSFileTypeDirectory) {
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: base];
      IMP nxtImp = [enumerator methodForSelector: @selector(nextObject)];  
      NSString *path;    
        
      while ((path = (*nxtImp)(enumerator, @selector(nextObject))) != nil) {
        CREATE_AUTORELEASE_POOL(arp1);

        if ([[enumerator fileAttributes] fileType] == NSFileTypeDirectory) {
          addDirectory([base stringByAppendingPathComponent: path]);
        }
        
        DESTROY (arp1);
      } 
      
      addDirectory(base);
    }
    
    DESTROY (arp); 
  }
  
  [self done];
}

- (void)removeTrees
{
  NSArray *basePaths = [updinfo objectForKey: @"paths"];
  int i, j;
  
  for (i = 0; i < [basePaths count]; i++) {  
    CREATE_AUTORELEASE_POOL(arp);
    NSString *base = [basePaths objectAtIndex: i];
    NSMutableArray *toremove = [NSMutableArray array];
    NSArray *keys;
    NSEnumerator *enumerator;
    NSString *path;
    
    [dirslock lock];
    enumerator = [dirsSet objectEnumerator];
    
    while ((path = [enumerator nextObject])) {
      if ([path isEqual: base] || subpathOfPath(base, path)) {
        [toremove addObject: path];
      }
    }   

    for (j = 0; j < [toremove count]; j++) {  
      removeDirectory([toremove objectAtIndex: j]);
    }
    
    [dirsRmvHandle synchronizeFile];
    [dirslock unlock];
     
    [toremove removeAllObjects];

    [pathslock lock]; 
    keys = [pathsDict allKeys];
    enumerator = [keys objectEnumerator];
    
    while ((path = [enumerator nextObject])) {
      if ([path isEqual: base] || subpathOfPath(base, path)) {
        [toremove addObject: path];
      }
    }   
    
    for (j = 0; j < [toremove count]; j++) {  
      removePath([toremove objectAtIndex: j]);
    }
    
    [pathsRmvHandle synchronizeFile];
    [pathslock unlock];

    DESTROY (arp);
  }
  
  [self done];
}

- (void)fileSystemDidChange
{
  NSString *operation = [updinfo objectForKey: @"operation"];
  
  if ([operation isEqual: @"NSWorkspaceMoveOperation"] 
                || [operation isEqual: @"NSWorkspaceCopyOperation"]
                || [operation isEqual: @"NSWorkspaceDuplicateOperation"]
                || [operation isEqual: @"GWorkspaceRenameOperation"]) {
    CREATE_AUTORELEASE_POOL(arp);
    NSString *source = [updinfo objectForKey: @"source"];
    NSString *destination = [updinfo objectForKey: @"destination"];
    NSArray *files = [updinfo objectForKey: @"files"];
    NSArray *origfiles = [updinfo objectForKey: @"origfiles"];
    NSMutableArray *srcpaths = [NSMutableArray array];
    NSMutableArray *dstpaths = [NSMutableArray array];
    NSArray *keys;
    NSEnumerator *enumerator;
    int i;

    if ([operation isEqual: @"GWorkspaceRenameOperation"]) {
      srcpaths = [NSArray arrayWithObject: source];
      dstpaths = [NSArray arrayWithObject: destination];
    } else {
      if ([operation isEqual: @"NSWorkspaceDuplicateOperation"]) { 
        for (i = 0; i < [files count]; i++) {
          NSString *fname = [origfiles objectAtIndex: i];
          [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
          fname = [files objectAtIndex: i];
          [dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
        }
      } else {  
        for (i = 0; i < [files count]; i++) {
          NSString *fname = [files objectAtIndex: i];
          [srcpaths addObject: [source stringByAppendingPathComponent: fname]];
          [dstpaths addObject: [destination stringByAppendingPathComponent: fname]];
        }
      }
    }

    [pathslock lock]; 
    keys = [pathsDict allKeys];
    RETAIN (keys);
    enumerator = [keys objectEnumerator];
    [pathslock unlock]; 

    for (i = 0; i < [srcpaths count]; i++) {
      CREATE_AUTORELEASE_POOL(pool);
      NSString *srcpath = [srcpaths objectAtIndex: i];
      NSString *dstpath = [dstpaths objectAtIndex: i];
      NSDictionary *attrs = [fm fileAttributesAtPath: dstpath traverseLink: NO];

      if ([keys containsObject: srcpath]) {
        duplicatePathInfo(srcpath, dstpath);
      }

      if ([attrs fileType] == NSFileTypeDirectory) {
        NSString *path;

        while ((path = [enumerator nextObject])) {
          if (subpathOfPath(srcpath, path)) {
            NSString *newpath = pathRemovingPrefix(path, srcpath);
            
            newpath = [dstpath stringByAppendingPathComponent: newpath];
          
            if ((*existsImp)(fm, existsSel, newpath)) {
              duplicatePathInfo(path, newpath);  
            }
          }
        }   
      }

      RELEASE (pool);
    }
    
    RELEASE (keys);
    RELEASE (arp);
  }
  
  [self done];
}

- (void)synchronize
{
  checkAnnotations();
  
  checkDirectories();
  synchronizeDirectories();
  
  checkPaths();
  synchronizePaths(); 

  [self done];
}

@end


BOOL createDb()
{
  NSString *basepath;
  NSString *dirs;  
  NSString *paths;  
  NSString *fpath;
  BOOL isdir;
  BOOL created;
        
  basepath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject];
  ASSIGN (dbdir, [basepath stringByAppendingPathComponent: @"ddb"]);
  created = YES;
  
  if (([fm fileExistsAtPath: dbdir isDirectory: &isdir] &isdir) == NO) {
    if ([fm createDirectoryAtPath: dbdir attributes: nil] == NO) { 
      return NO;
    }
  }
  
  dirs = [dbdir stringByAppendingPathComponent: @"dirs"];
  [dirslock lock];

  if ([fm fileExistsAtPath: dirs] == NO) {
    if ([fm createFileAtPath: dirs contents: nil attributes: nil] == NO) { 
      created = NO;
    }    
  }
    
  fpath = [dirs stringByAppendingPathExtension: @"add"];

  if ([fm fileExistsAtPath: fpath] == NO) {
    if ([fm createFileAtPath: fpath contents: nil attributes: nil] == NO) { 
      created = NO;
    }
  }
    
  dirsAddHandle = [NSFileHandle fileHandleForUpdatingAtPath: fpath];
  RETAIN (dirsAddHandle);
    
  fpath = [dirs stringByAppendingPathExtension: @"rmv"];

  if ([fm fileExistsAtPath: fpath] == NO) {
    if ([fm createFileAtPath: fpath contents: nil attributes: nil] == NO) { 
      created = NO;
    }
  }
    
  dirsRmvHandle = [NSFileHandle fileHandleForUpdatingAtPath: fpath];
  RETAIN (dirsRmvHandle);
  [dirslock unlock];
  
  paths = [dbdir stringByAppendingPathComponent: @"paths"];
  [pathslock lock];
  
  if ([fm fileExistsAtPath: paths] == NO) {
    if ([fm createFileAtPath: paths contents: nil attributes: nil] == NO) { 
      created = NO;
    }
  }

  fpath = [paths stringByAppendingPathExtension: @"add"];

  if ([fm fileExistsAtPath: fpath] == NO) {
    if ([fm createFileAtPath: fpath contents: nil attributes: nil] == NO) {
      created = NO;
    }
  }

  pathsAddHandle = [NSFileHandle fileHandleForUpdatingAtPath: fpath];
  RETAIN (pathsAddHandle);

  fpath = [paths stringByAppendingPathExtension: @"rmv"];

  if ([fm fileExistsAtPath: fpath] == NO) {
    if ([fm createFileAtPath: fpath contents: nil attributes: nil] == NO) { 
      created = NO;
    }
  }

  pathsRmvHandle = [NSFileHandle fileHandleForUpdatingAtPath: fpath];
  RETAIN (pathsRmvHandle);
  [pathslock unlock];
  
  fpath = [dbdir stringByAppendingPathComponent: @"annotations"];
  [annslock lock];
  
  if ([fm fileExistsAtPath: fpath] == NO) {
    unsigned annsize = sizeof(annotation);
    annotation dummy;
    
    memset(dummy.ann, 0, sizeof(dummy.ann));
    memset(dummy.path, 0, sizeof(dummy.path));

    if ([fm createFileAtPath: fpath 
                    contents: [NSData dataWithBytes: &dummy length: annsize]
                  attributes: nil] == NO) { 
      created = NO;
    }
  }

  annsHandle = [NSFileHandle fileHandleForUpdatingAtPath: fpath];
  RETAIN (annsHandle);
  [annslock unlock];

  return created;
}

BOOL readDirectories()
{
  NSString *dirspath = [dbdir stringByAppendingPathComponent: @"dirs"];
  char path[BUFSIZ];
  FILE *fp;
  char buf[BUFSIZ];
  char *s;
  
  if ([dirspath getFileSystemRepresentation: path
			                            maxLength: sizeof(path)-1] == NO) {
    return NO;
  }
  
  [dirslock lock];
  
  fp = fopen(path, "r");

  if (fp == NULL) {
    [dirslock unlock];
    return NO;
  }

  while (fgets(buf, sizeof(buf), fp) != NULL) {
    CREATE_AUTORELEASE_POOL(pool);

    s = strchr(buf, '\n');
    if (s) {
      *s = '\0';
    }
    
    [dirsSet addObject: [NSString stringWithUTF8String: buf]];
  
    RELEASE (pool);
  }
  
  fclose(fp);
  [dirslock unlock];
    
  return YES;
}

BOOL writeDirectories()
{
  NSString *dirspath = [dbdir stringByAppendingPathComponent: @"dirs"];
  NSString *path = [dirspath stringByAppendingPathExtension: @"tmp"];
  NSEnumerator *enumerator;
  NSString *directory;
  NSFileHandle *handle;
  
  [dirslock lock];
     
  if ([fm fileExistsAtPath: path] == NO) {
    if ([fm createFileAtPath: path contents: nil attributes: nil] == NO) { 
      [dirslock unlock];
      return NO;
    }
  }
    
  handle = [NSFileHandle fileHandleForWritingAtPath: path];
  
  enumerator = [dirsSet objectEnumerator];
  
  while ((directory = [enumerator nextObject])) {
    CREATE_AUTORELEASE_POOL(pool);
    const char *buf = [directory UTF8String];
    NSData *data = [NSData dataWithBytes: buf length: strlen(buf)];

    [handle writeData: data];
    data = [NSData dataWithBytes: "\n" length: 1];
    [handle writeData: data];
    
    RELEASE (pool);
  }

  [handle synchronizeFile];
  [handle closeFile];
  
  if ([fm removeFileAtPath: dirspath handler: nil]) {
    if ([fm movePath: path toPath: dirspath handler: nil]) {
      [dirslock unlock];
      return YES;
    }
  }
  
  [dirslock unlock];
  
  return NO;
}

void addDirectory(NSString *path)
{
  [dirslock lock];

  if ([dirsSet containsObject: path] == NO) {
    const char *buf = [path UTF8String];
    NSData *data = [NSData dataWithBytes: buf length: strlen(buf)];
    
    [dirsAddHandle seekToEndOfFile];
    [dirsAddHandle writeData: data];
    data = [NSData dataWithBytes: "\n" length: 1];
    [dirsAddHandle writeData: data];
//    [dirsAddHandle synchronizeFile];

    [dirsSet addObject: path];
  }

  [dirslock unlock];
}

void removeDirectory(NSString *path)
{
  [dirslock lock];
  
  if ([dirsSet containsObject: path]) {
    const char *buf = [path UTF8String];
    NSData *data = [NSData dataWithBytes: buf length: strlen(buf)];

    [dirsRmvHandle seekToEndOfFile];
    [dirsRmvHandle writeData: data];
    data = [NSData dataWithBytes: "\n" length: 1];
    [dirsRmvHandle writeData: data];
//    [dirsRmvHandle synchronizeFile];

    [dirsSet removeObject: path];
  }

  [dirslock unlock];
}

void checkDirectories()
{
  NSArray *dirs;
  int i;
  
  [dirslock lock];
  dirs = [dirsSet allObjects];
  RETAIN (dirs);
  [dirslock unlock];
  
  for (i = 0; i < [dirs count]; i++) {
    NSString *dir = [dirs objectAtIndex: i];
    
    if ((*existsImp)(fm, existsSel, dir) == NO) {
      removeDirectory(dir);
    }
  }
  
  RELEASE (dirs);  
}

void synchronizeDirectories()
{
  CREATE_AUTORELEASE_POOL(pool);
  NSData *data;
  const char *bytes;
  unsigned length;
  char *buf;
  unsigned bufind;
  NSString *path;
  BOOL isdir;
  int i;
  
  [dirslock lock];
  
  buf = NSZoneMalloc(NSDefaultMallocZone(), sizeof(char) * BUFSIZ);

  [dirsRmvHandle synchronizeFile];
  [dirsRmvHandle seekToFileOffset: 0];
  
  data = [dirsRmvHandle readDataToEndOfFile];
  
  if ([data length]) {  
    bytes = [data bytes];
    length = strlen(bytes);

    memset(buf, 0, sizeof(buf));
    bufind = 0;

    for (i = 0; i < length; i++) {
      char c = bytes[i];

      if (c != '\n') {
        buf[bufind] = c;
        bufind++;
      } else {
        buf[bufind] = '\0';        
        path = [NSString stringWithUTF8String: buf];
        if (([fm fileExistsAtPath: path isDirectory: &isdir] && isdir) == NO) {
          [dirsSet removeObject: path];
        }
        memset(buf, 0, sizeof(buf));
        bufind = 0;
      }
    }
  }
    
  [dirsAddHandle synchronizeFile];
  [dirsAddHandle seekToFileOffset: 0];

  data = [dirsAddHandle readDataToEndOfFile];
  
  if ([data length]) {
    bytes = [data bytes];
    length = strlen(bytes);

    memset(buf, 0, sizeof(buf));
    bufind = 0;

    for (i = 0; i < length; i++) {
      char c = bytes[i];

      if (c != '\n') {
        buf[bufind] = c;
        bufind++;
      } else {
        buf[bufind] = '\0';
        path = [NSString stringWithUTF8String: buf];
        if ([fm fileExistsAtPath: path isDirectory: &isdir] && isdir) {
          [dirsSet addObject: path];
        }
        memset(buf, 0, sizeof(buf));
        bufind = 0;
      }
    }
  }  
  
  NSZoneFree(NSDefaultMallocZone(), buf);
  
  if (writeDirectories()) {
    [dirsRmvHandle truncateFileAtOffset: 0];
    [dirsRmvHandle synchronizeFile];  
    [dirsAddHandle truncateFileAtOffset: 0];
    [dirsAddHandle synchronizeFile];
  }
  
  [dirslock unlock];
    
  RELEASE (pool);  
}

void readPaths()
{
  NSString *path = [dbdir stringByAppendingPathComponent: @"paths"];
  NSFileHandle *handle;  
  dbpath dbp;
  NSData *data;
  NSRange range;
  
  [pathslock lock];
  handle = [NSFileHandle fileHandleForReadingAtPath: path];
                    
  while (1) {
    CREATE_AUTORELEASE_POOL(pool);

    data = [handle readDataOfLength: sizeof(dbpath)];
        
    if ([data length]) {
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
      memset(dbp.path, 0, sizeof(dbp.path));
      dbp.annoffset = 0;
        
      range = NSMakeRange(0, sizeof(dbp.path) - 1);
      [data getBytes: &dbp.path range: range];
      
      range = NSMakeRange(sizeof(dbp.path), sizeof(dbp.annoffset) -1);
      [data getBytes: &dbp.annoffset range: range];

      [dict setObject: [NSNumber numberWithUnsignedLongLong: dbp.annoffset]
               forKey: @"annoffset"];

      range = NSMakeRange(sizeof(dbp.path) + sizeof(dbp.annoffset), sizeof(dbp.timestamp) -1);
      [data getBytes: &dbp.timestamp range: range];
               
      [dict setObject: [NSNumber numberWithDouble: dbp.timestamp]
               forKey: @"timestamp"];
        
      [pathsDict setObject: dict 
                    forKey: [NSString stringWithUTF8String: dbp.path]];
    } else {
      break;
    }
    
    RELEASE (pool);
  }
  
  [handle closeFile]; 
  [pathslock unlock];   
}    

BOOL writePaths()
{
  NSString *pathspath = [dbdir stringByAppendingPathComponent: @"paths"];
  NSString *path = [pathspath stringByAppendingPathExtension: @"tmp"];
  
  [pathslock lock]; 
  
  if ([fm fileExistsAtPath: path] == NO) {
    if ([fm createFileAtPath: path contents: nil attributes: nil] == NO) { 
      [pathslock unlock]; 
      return NO;
    }
  }

  if ([pathsDict count]) {
    NSArray *keys = [pathsDict allKeys];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath: path];
    dbpath dbp;
    int i;

    for (i = 0; i < [keys count]; i++) {
      CREATE_AUTORELEASE_POOL(pool);
      NSString *key = [keys objectAtIndex: i];
      const char *buf = [key UTF8String];
      NSDictionary *dict = [pathsDict objectForKey: key];
      NSNumber *annoffset = [dict objectForKey: @"annoffset"];
      NSNumber *timestamp = [dict objectForKey: @"timestamp"];
      NSData *data;
      
      memset(dbp.path, 0, sizeof(dbp.path));
      memcpy(dbp.path, buf, strlen(buf));   

      dbp.annoffset = [annoffset unsignedLongLongValue];
      dbp.timestamp = [timestamp doubleValue];

      data = [NSData dataWithBytes: &dbp length: sizeof(dbpath)];
      [handle writeData: data];
      RELEASE (pool);
    }
    
    [handle synchronizeFile];
    [handle closeFile];
  }

  if ([fm removeFileAtPath: pathspath handler: nil]) {
    if ([fm movePath: path toPath: pathspath handler: nil]) {
      [pathslock unlock]; 
      return YES;
    }
  }
  
  [pathslock unlock]; 
    
  return NO;
}
    
NSMutableDictionary *addPath(NSString *path)
{
  NSMutableDictionary *dict;
  
  [pathslock lock]; 
  dict = [pathsDict objectForKey: path];
  
  if (dict) {
    RETAIN (dict);
  } else {
    CREATE_AUTORELEASE_POOL(pool);
    const char *buf = [path UTF8String];
    dbpath dbp;
    NSData *data;
    
    memset(dbp.path, 0, sizeof(dbp.path));
    memcpy(dbp.path, buf, strlen(buf));
    dbp.annoffset = 0;
    dbp.timestamp = [[NSDate date] timeIntervalSinceReferenceDate];

    data = [NSData dataWithBytes: &dbp length: sizeof(dbpath)];

    [pathsAddHandle seekToEndOfFile];
    [pathsAddHandle writeData: data];
//    [pathsAddHandle synchronizeFile];
    
    dict = [NSMutableDictionary dictionary];
    
    [dict setObject: [NSNumber numberWithUnsignedLongLong: 0]
             forKey: @"annoffset"];
    [dict setObject: [NSNumber numberWithDouble: dbp.timestamp]
             forKey: @"timestamp"];
        
    [pathsDict setObject: dict forKey: path];
  
    RETAIN (dict);
    RELEASE (pool);
  } 
  
  [pathslock unlock]; 
    
  return AUTORELEASE (dict);
}

void removePath(NSString *path)
{
  NSDictionary *dict;
  
  [pathslock lock]; 
  dict = [pathsDict objectForKey: path];
  
  if (dict) {
    const char *buf = [path UTF8String]; 
    NSNumber *num = [dict objectForKey: @"annoffset"];
    dbpath dbp;
    NSData *data;

    memset(dbp.path, 0, sizeof(dbp.path));
    memcpy(dbp.path, buf, strlen(buf));
    dbp.annoffset = [num unsignedLongLongValue];
    dbp.timestamp = [[NSDate date] timeIntervalSinceReferenceDate];
  
    data = [NSData dataWithBytes: &dbp length: sizeof(dbpath)];
  
    [pathsRmvHandle seekToEndOfFile];
    [pathsRmvHandle writeData: data];
//    [pathsRmvHandle synchronizeFile];

    [pathsDict removeObjectForKey: path];  
  }
  
  [pathslock unlock]; 
}

void pathUpdated(NSString *path)
{
  const char *buf = [path UTF8String];
  NSMutableDictionary *dict;
  NSNumber *num;
  unsigned long long offset;
  dbpath dbp;  
  NSData *data;

  [pathslock lock];

  dict = [pathsDict objectForKey: path];
  num = [dict objectForKey: @"annoffset"];
  offset = [num unsignedLongLongValue];

  memset(dbp.path, 0, sizeof(dbp.path));
  memcpy(dbp.path, buf, strlen(buf));
  dbp.annoffset = offset;
  dbp.timestamp = [[NSDate date] timeIntervalSinceReferenceDate];

  [dict setObject: [NSNumber numberWithDouble: dbp.timestamp]
           forKey: @"timestamp"];

  data = [NSData dataWithBytes: &dbp length: sizeof(dbpath)];

  [pathsAddHandle seekToEndOfFile];
  [pathsAddHandle writeData: data];
//  [pathsAddHandle synchronizeFile];
  [pathslock unlock];
}

void checkPaths()
{
  NSArray *paths;
  int i;
  
  [pathslock lock];
  paths = [pathsDict allKeys];
  RETAIN (paths);
  [pathslock unlock];
  
  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];
    
    if ((*existsImp)(fm, existsSel, path) == NO) {
      removePath(path);
    }
  }
  
  RELEASE (paths);  
}

void synchronizePaths()
{
  CREATE_AUTORELEASE_POOL(pool);
  NSMutableDictionary *toadd = [NSMutableDictionary dictionary];
  NSMutableArray *toremove = [NSMutableArray array];
  NSDictionary *adddict;
  NSArray *paths;
  dbpath dbp;
  NSData *data;
  int i;
  
  [pathslock lock];
  
  [pathsAddHandle synchronizeFile];
  [pathsAddHandle seekToFileOffset: 0];

  while (1) {
    CREATE_AUTORELEASE_POOL(arp);

    data = [pathsAddHandle readDataOfLength: sizeof(dbpath)];

    if ([data length]) {
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      NSString *path;
      NSRange range;
      
      memset(dbp.path, 0, sizeof(dbp.path));
      dbp.annoffset = 0;
      dbp.timestamp = 0.0;
        
      range = NSMakeRange(0, sizeof(dbp.path) - 1);    
      [data getBytes: &dbp.path range: range];

      range = NSMakeRange(sizeof(dbp.path), sizeof(dbp.annoffset) -1);
      [data getBytes: &dbp.annoffset range: range];
               
      [dict setObject: [NSNumber numberWithUnsignedLongLong: dbp.annoffset]
               forKey: @"annoffset"];
        
      range = NSMakeRange(sizeof(dbp.path) + sizeof(dbp.annoffset), sizeof(dbp.timestamp) -1);
      [data getBytes: &dbp.timestamp range: range];
               
      [dict setObject: [NSNumber numberWithDouble: dbp.timestamp]
               forKey: @"timestamp"];
            
      path = [NSString stringWithUTF8String: dbp.path];      
            
      adddict = [toadd objectForKey: path];
      
      if (adddict) {
        double tstamp = [[adddict objectForKey: @"timestamp"] doubleValue];
      
        if (tstamp < dbp.timestamp) {
          [toadd setObject: dict forKey: path];
        }
      } else {
        [toadd setObject: dict forKey: path];
      }
    
    } else {
      break;
    }
    
    RELEASE (arp);
  }
  
  [pathsRmvHandle synchronizeFile];
  [pathsRmvHandle seekToFileOffset: 0];

  while (1) {
    CREATE_AUTORELEASE_POOL(arp);

    data = [pathsRmvHandle readDataOfLength: sizeof(dbpath)];

    if ([data length]) {
      NSString *path;
      NSRange range;
      
      memset(dbp.path, 0, sizeof(dbp.path));
      dbp.annoffset = 0;
      dbp.timestamp = 0.0;
        
      range = NSMakeRange(0, sizeof(dbp.path) - 1);    
      [data getBytes: &dbp.path range: range];

      range = NSMakeRange(sizeof(dbp.path), sizeof(dbp.annoffset) -1);
      [data getBytes: &dbp.annoffset range: range];
               
      range = NSMakeRange(sizeof(dbp.path) + sizeof(dbp.annoffset), sizeof(dbp.timestamp) -1);
      [data getBytes: &dbp.timestamp range: range];
      
      path = [NSString stringWithUTF8String: dbp.path];
      adddict = [toadd objectForKey: path];
      
      if (adddict) {
        double tstamp = [[adddict objectForKey: @"timestamp"] doubleValue];
      
        if (tstamp < dbp.timestamp) {
          [toadd removeObjectForKey: path];
          
          if ([toremove containsObject: path] == NO) {
            [toremove addObject: path];
          }
        }
      } else if ([toremove containsObject: path] == NO) {
        [toremove addObject: path];
      }

    } else {
      break;
    }
    
    RELEASE (arp);
  }

  paths = [toadd allKeys];

  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];
    NSMutableDictionary *dict = [toadd objectForKey: path];
    
    [pathsDict setObject: dict forKey: path];
  }

  for (i = 0; i < [toremove count]; i++) {
    [pathsDict removeObjectForKey: [toremove objectAtIndex: i]];
  }

  if (writePaths()) {
    [pathsAddHandle truncateFileAtOffset: 0];
    [pathsAddHandle synchronizeFile];
    [pathsRmvHandle truncateFileAtOffset: 0];
    [pathsRmvHandle synchronizeFile];
  }
  
  [pathslock unlock];
    
  RELEASE (pool);  
}

NSString *annotationsForPath(NSString *path)
{
  NSDictionary *dict;
  
  [annslock lock];
  dict = [pathsDict objectForKey: path];
  
  if (dict) {
    NSNumber *num = [dict objectForKey: @"annoffset"];
    unsigned long long offset = [num unsignedLongLongValue];

    [annsHandle seekToEndOfFile];
    
    if ((offset != 0) 
          && (offset <= ([annsHandle offsetInFile] - sizeof(annotation)))) {
      annotation annot;
      NSData *data;
      
      [annsHandle seekToFileOffset: offset];
      
      data = [annsHandle readDataOfLength: sizeof(annotation)];
      
      if ([data length] == sizeof(annotation)) {
        [data getBytes: &annot.ann range: NSMakeRange(0, sizeof(annot.ann) - 1)];
        [data getBytes: &annot.path 
                 range: NSMakeRange(sizeof(annot.ann), sizeof(annot.path) - 1)];
      
        [annslock unlock];
        
        return [NSString stringWithUTF8String: annot.ann];
      }
    }
  }
  
  [annslock unlock];
  
  return nil;
}

void setAnnotationsForPath(NSString *annotations, NSString *path)
{
  NSMutableDictionary *dict;
  annotation annot;
  NSNumber *num;
  unsigned long long offset;
  const char *buf;
  NSData *data;
  
  [annslock lock];
  dict = [pathsDict objectForKey: path];
  
  if (dict == nil) {
    dict = addPath(path);
  }
  
  num = [dict objectForKey: @"annoffset"];
  offset = [num unsignedLongLongValue];

  [annsHandle seekToEndOfFile];
  
  if ((offset == 0) 
        || (offset > ([annsHandle offsetInFile] - sizeof(annotation)))) {
    offset = [annsHandle offsetInFile];
    num = [NSNumber numberWithUnsignedLongLong: offset];
    [dict setObject: num forKey: @"annoffset"];
    pathUpdated(path);
  } else {
    [annsHandle seekToFileOffset: offset];
  }
  
  buf = [annotations UTF8String];
  memset(annot.ann, 0, sizeof(annot.ann));
  memcpy(&annot.ann, buf, strlen(buf));

  buf = [path UTF8String];
  memset(annot.path, 0, sizeof(annot.path));
  memcpy(&annot.path, buf, strlen(buf));

  data = [NSData dataWithBytes: &annot length: sizeof(annotation)];
  [annsHandle writeData: data];
  [annsHandle synchronizeFile];
  
  [annslock unlock];
}

NSString *pathForAnnotationsOffset(unsigned long long offset)
{
  NSArray *paths;
  int i;
  
  [pathslock lock]; 
  paths = [pathsDict allKeys];  

  for (i = 0; i < [paths count]; i++) {
    NSString *path = [paths objectAtIndex: i];
    NSDictionary *dict = [pathsDict objectForKey: path];
      
    if ([[dict objectForKey: @"annoffset"] unsignedLongLongValue] == offset) {
      [pathslock unlock];
      return path;
    }
  }
  
  [pathslock unlock];
  
  return nil;
}

void checkAnnotations()
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString *fpath = [dbdir stringByAppendingPathComponent: @"annotations.tmp"];
  NSFileHandle *handle; 
  NSMutableDictionary *written;
  annotation annot;
  unsigned annsize;
  NSData *data;
  NSString *path;
  BOOL changed;
  
  if ([fm fileExistsAtPath: fpath]) {
    if ([fm removeFileAtPath: fpath handler: nil] == NO) {
      NSLog(@"unable to remove the annotations tmp file");
      RELEASE (arp);
      return;    
    }
  }

  if ([fm createFileAtPath: fpath contents: nil attributes: nil] == NO) { 
    NSLog(@"unable to create the annotations tmp file");
    RELEASE (arp);
    return;
  }

  handle = [NSFileHandle fileHandleForUpdatingAtPath: fpath];  
  written = [NSMutableDictionary dictionary];
   
  [annslock lock];
  changed = NO;
  
  [annsHandle synchronizeFile];
  [annsHandle seekToFileOffset: 0];
  annsize = sizeof(annotation);

  while (1) {
    data = [annsHandle readDataOfLength: annsize];
    
    if ([data length] == annsize) {
      NSMutableDictionary *dict;
      
      memset(annot.ann, 0, sizeof(annot.ann));
      memset(annot.path, 0, sizeof(annot.path));

      [data getBytes: &annot.ann range: NSMakeRange(0, sizeof(annot.ann) - 1)];
      [data getBytes: &annot.path 
               range: NSMakeRange(sizeof(annot.ann), sizeof(annot.path) - 1)];
    
      path = [NSString stringWithUTF8String: annot.path];
      dict = [pathsDict objectForKey: path];
      
      if (dict) {
        NSDictionary *wrdict = [written objectForKey: path];
        unsigned long long newoffset;
        NSNumber *newoffnum;

        if (wrdict) {
          newoffnum = [wrdict objectForKey: @"annoffset"];
          newoffset = [newoffnum unsignedLongLongValue];
          [handle seekToFileOffset: newoffset];
        } else {
          [handle seekToEndOfFile];
          newoffset = [handle offsetInFile];
          newoffnum = [NSNumber numberWithUnsignedLongLong: newoffset];
        } 

        if ([[dict objectForKey: @"annoffset"] isEqual: newoffnum] == NO) {
          [dict setObject: newoffnum forKey: @"annoffset"];
          pathUpdated(path);
          changed = YES;
        }

        [handle writeData: data]; 
        [written setObject: dict forKey: path];
        
      } else {
        if ([annsHandle offsetInFile] == annsize) {
          [handle writeData: data]; 
        } else {
          changed = YES;
        }
      }
      
    } else {
      break;
    }
  }
    
  [handle synchronizeFile];
  [handle seekToFileOffset: 0];
  
  if (changed) {
    [annsHandle truncateFileAtOffset: 0];

    while (1) {
      data = [handle readDataOfLength: sizeof(annotation)];

      if ([data length] == sizeof(annotation)) {
        [annsHandle writeData: data];
      } else {
        break;
      }
    }
    
    [annsHandle synchronizeFile];
  }

  [handle closeFile];
  [fm removeFileAtPath: fpath handler: nil];
  [annslock unlock];
  RELEASE (arp);
}

void duplicatePathInfo(NSString *srcpath, NSString *dstpath)
{
  NSString *annotations = annotationsForPath(srcpath);
  
  if (annotations) {
    setAnnotationsForPath(annotations, dstpath);
  }
}

BOOL subpathOfPath(NSString *p1, NSString *p2)
{
  int l1 = [p1 length];
  int l2 = [p2 length];  

  if ((l1 > l2) || ([p1 isEqualToString: p2])) {
    return NO;
  } else if ([[p2 substringToIndex: l1] isEqualToString: p1]) {
    if ([[p2 pathComponents] containsObject: [p1 lastPathComponent]]) {
      return YES;
    }
  }

  return NO;
}

static NSString *fixpath(NSString *s, const char *c)
{
  static NSFileManager *mgr = nil;
  const char *ptr = c;
  unsigned len;

  if (mgr == nil) {
    mgr = [NSFileManager defaultManager];
    RETAIN (mgr);
  }
  
  if (ptr == 0) {
    if (s == nil) {
	    return nil;
	  }
    ptr = [s cString];
  }
  
  len = strlen(ptr);

  return [mgr stringWithFileSystemRepresentation: ptr length: len]; 
}

static NSString *path_sep(void)
{
  static NSString *separator = nil;

  if (separator == nil) {
    separator = fixpath(@"/", 0);
    RETAIN (separator);
  }

  return separator;
}

NSString *path_separator(void)
{
  return path_sep();
}

NSString *pathRemovingPrefix(NSString *path, NSString *prefix)
{
  if ([path hasPrefix: prefix]) {
	  return [path substringFromIndex: [path rangeOfString: prefix].length + 1];
  }

  return path;  	
}


int main(int argc, char** argv)
{
	DDBd *ddbd;

	switch (fork()) {
	  case -1:
	    fprintf(stderr, "ddbd - fork failed - bye.\n");
	    exit(1);

	  case 0:
	    setsid();
	    break;

	  default:
	    exit(0);
	}
  
  CREATE_AUTORELEASE_POOL (pool);
	ddbd = [[DDBd alloc] init];
  RELEASE (pool);
  
  if (ddbd != nil) {
	  CREATE_AUTORELEASE_POOL (pool);
    [ddbd prepareDb];
    [[NSRunLoop currentRunLoop] run];
  	RELEASE (pool);
  }
  
  exit(0);
}




/*
  CREATE_AUTORELEASE_POOL(arp);
  NSString *base = @"/home/enrico/Butt/GNUstep/CopyPix";  
  NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath: base];
  NSString *path;    

  while ((path = [enumerator nextObject])) {
    if ([[enumerator fileAttributes] fileType] == NSFileTypeDirectory) {
      addDirectory([base stringByAppendingPathComponent: path]);
    }
    addPath([base stringByAppendingPathComponent: path]);
  } 

  DESTROY (arp); 
*/
