#ifndef REMOTE_EDITOR_H
#define REMOTE_EDITOR_H

#include <Foundation/NSObject.h>
#include <AppKit/NSView.h>

@class RemoteEditorView;

@interface RemoteEditor : NSObject
{
  NSString *serverName;
  NSString *filePath;
  NSString *fileName;
  
  IBOutlet id win;
  IBOutlet id scrollView;
  
  RemoteEditorView *editorView;
  
  id gwremote;
}

- (id)initForEditFile:(NSString *)filepath
         withContents:(NSString *)contents
         onRemoteHost:(NSString *)hostname;

- (void)activate;

- (void)setEdited;

- (BOOL)isEdited;

- (BOOL)trySave;

- (NSString *)serverName;

- (NSString *)filePath;
     
@end

#endif // REMOTE_EDITOR_H


