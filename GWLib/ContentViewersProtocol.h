#ifndef CONTENTVIEWERSPROTOCOL_H
#define CONTENTVIEWERSPROTOCOL_H

@protocol ContentViewersProtocol

- (id)initInPanel:(id)apanel withFrame:(NSRect)frame index:(int)idx;

- (void)setBundlePath:(NSString *)path;

- (NSString *)bundlePath;

- (void)setIndex:(int)idx;

- (void)activateForPath:(NSString *)path;

- (BOOL)stopTasks;

- (void)deactivate;

- (BOOL)canDisplayFileAtPath:(NSString *)path;

- (int)index;

- (NSString *)winname;

@end 

#endif // CONTENTVIEWERSPROTOCOL_H

