/* Test DBKit */

#include <Foundation/Foundation.h>
#include <DBKit/DBKBTree.h>
#include <DBKit/DBKBTreeNode.h>
#include <DBKit/DBKVarLenRecordsFile.h>
#include "test.h"
#include "dbpath.h"

@interface TreeDelegate: NSObject <DBKBTreeDelegate>
{
}

- (unsigned long)nodesize;  

- (NSArray *)keysFromData:(NSData *)data
               withLength:(unsigned *)dlen;

- (NSData *)dataFromKeys:(NSArray *)keys;

- (NSComparisonResult)compareNodeKey:(id)akey 
                             withKey:(id)bkey;

@end

@implementation	TreeDelegate

- (unsigned long)nodesize
{
  return 512;
} 

- (NSArray *)keysFromData:(NSData *)data
               withLength:(unsigned *)dlen
{
  NSMutableArray *keys = [NSMutableArray array];
  NSRange range;
  unsigned kcount;
  unsigned long key;
  int i;
  
  range = NSMakeRange(0, sizeof(unsigned));
  [data getBytes: &kcount range: range];
  range.location += sizeof(unsigned);
  
  range.length = sizeof(unsigned long);

  for (i = 0; i < kcount; i++) {
    [data getBytes: &key range: range];
    [keys addObject: [NSNumber numberWithUnsignedLong: key]];
    range.location += sizeof(unsigned long);
  }
  
  *dlen = range.location;
  
  return keys;
}

- (NSData *)dataFromKeys:(NSArray *)keys
{
  NSMutableData *data = [NSMutableData dataWithCapacity: 1];
  unsigned kcount = [keys count];
  int i;
  
  [data appendData: [NSData dataWithBytes: &kcount length: sizeof(unsigned)]];
    
  for (i = 0; i < kcount; i++) {
    unsigned long kl = [[keys objectAtIndex: i] unsignedLongValue];
    [data appendData: [NSData dataWithBytes: &kl length: sizeof(unsigned long)]];
  }
  
  return data;  
}

- (NSComparisonResult)compareNodeKey:(id)akey 
                             withKey:(id)bkey
{
  return [(NSNumber *)akey compare: (NSNumber *)bkey];
}
                             
@end


int main(int argc, char** argv)
{
  CREATE_AUTORELEASE_POOL (pool);
  TreeDelegate *delegate = [TreeDelegate new];
  DBKBTree *tree = [[DBKBTree alloc] initWithPath: dbpath order: 3 delegate: delegate];
  NSDate *date = [NSDate date];
  
  [tree begin];
  test1(tree);
  [tree end];

  [tree begin];
  test2(tree);
  [tree end];

  [tree begin];
  test3(tree);
  [tree end];

  [tree begin];
  test4(tree);
  [tree end];

  [tree begin];
  test5(tree);
  [tree end];

  [tree begin];
  test6(tree);
  [tree end];
    
  NSLog(@"%.2f", [[NSDate date] timeIntervalSinceDate: date]);
  NSLog(@"done");
      
  RELEASE (tree);
  RELEASE (delegate);
  
  RELEASE (pool);
  exit(EXIT_SUCCESS);
}













