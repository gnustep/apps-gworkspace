#ifndef EXTERNS_H
#define EXTERNS_H

/* Class variables */
extern NSMutableDictionary *cachedContents;
extern int cachedMax;

extern NSMutableArray *lockedPaths;

extern NSRecursiveLock *gwsdLock;

/* File Operations */
extern NSString *NSWorkspaceMoveOperation;
extern NSString *NSWorkspaceCopyOperation;
extern NSString *NSWorkspaceLinkOperation;
extern NSString *NSWorkspaceDestroyOperation;
extern NSString *NSWorkspaceDuplicateOperation;
extern NSString *NSWorkspaceRecycleOperation;
extern NSString *GWorkspaceRecycleOutOperation;
extern NSString *GWorkspaceEmptyRecyclerOperation;

/* Notifications */
extern NSString *GWFileSystemWillChangeNotification;
extern NSString *GWFileSystemDidChangeNotification; 

extern NSString *GWFileWatcherFileDidChangeNotification; 
extern NSString *GWWatchedDirectoryDeleted; 
extern NSString *GWFileDeletedInWatchedDirectory; 
extern NSString *GWFileCreatedInWatchedDirectory;

#endif // EXTERNS_H
