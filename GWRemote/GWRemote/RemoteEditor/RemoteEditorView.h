
#ifndef REMOTE_EDITOR_VIEW
#define REMOTE_EDITOR_VIEW

#include <Foundation/Foundation.h>
#include <AppKit/NSTextView.h>

@class NSString;
@class RemoteEditor;

@interface RemoteEditorView: NSTextView
{
  RemoteEditor *editor;
  NSDictionary *fontDict;
  BOOL edited;
  
  IBOutlet id findWin;
  IBOutlet id findField;
  IBOutlet id findButt;  
}

- (id)initWithFrame:(NSRect)frame inEditor:(RemoteEditor *)anEditor;

- (void)setStringToEdit:(NSString *)string;

- (NSString *)editedString;

- (BOOL)isEdited;

- (void)saveRemoteFile:(id)sender;

- (void)showFindWin:(id)sender;

- (IBAction)Find:(id)sender;

@end

#endif // REMOTE_EDITOR_VIEW

