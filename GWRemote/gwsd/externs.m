
#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#ifndef CACHED_MAX
  #define CACHED_MAX 20;
#endif

/* Class variables */
NSMutableDictionary *cachedContents = nil;
int cachedMax = CACHED_MAX;

NSMutableArray *lockedPaths = nil;

NSRecursiveLock *gwsdLock = nil;

/* File Operations */
NSString *NSWorkspaceMoveOperation = @"NSWorkspaceMoveOperation";
NSString *NSWorkspaceCopyOperation = @"NSWorkspaceCopyOperation";
NSString *NSWorkspaceLinkOperation = @"NSWorkspaceLinkOperation";
NSString *NSWorkspaceDestroyOperation = @"NSWorkspaceDestroyOperation";
NSString *NSWorkspaceDuplicateOperation = @"NSWorkspaceDuplicateOperation";
NSString *NSWorkspaceRecycleOperation = @"NSWorkspaceRecycleOperation";
NSString *GWorkspaceRecycleOutOperation = @"GWorkspaceRecycleOutOperation";
NSString *GWorkspaceEmptyRecyclerOperation = @"GWorkspaceEmptyRecyclerOperation";

/* Notifications */
NSString *GWFileSystemWillChangeNotification = @"GWFileSystemWillChangeNotification";
NSString *GWFileSystemDidChangeNotification = @"GWFileSystemDidChangeNotification"; 

NSString *GWFileWatcherFileDidChangeNotification = @"GWFileWatcherFileDidChangeNotification"; 
NSString *GWWatchedDirectoryDeleted = @"GWWatchedDirectoryDeleted"; 
NSString *GWFileDeletedInWatchedDirectory = @"GWFileDeletedInWatchedDirectory"; 
NSString *GWFileCreatedInWatchedDirectory = @"GWFileCreatedInWatchedDirectory"; 
