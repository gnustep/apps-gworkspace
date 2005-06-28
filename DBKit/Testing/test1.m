#include <DBKit/DBKBTree.h>
#include "test.h"

void test1(DBKBTree *tree)
{
  DBKBTreeNode *node;
  int index;

  NSLog(@"test 1");

  NSLog(@"insert 10 items");
  [tree insertKey: [NSNumber numberWithUnsignedLong: 372]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 245]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 491]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 474]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 440]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 122]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 418]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 125]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 934]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 752]];

  NSLog(@"Show tree structure");
  printTree(tree);

  NSLog(@"search for item 122 in tree");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 122] 
                getIndex: &index];
  if (node) {
    NSLog(@"found 122");
  } else {
    NSLog(@"************* ERROR 122 not found *****************");
  }

  NSLog(@"search for item 441 not in tree");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 441] 
                getIndex: &index];
  if (node == nil) {
    NSLog(@"441 not found");
  } else {
    NSLog(@"************* ERROR found 441 *****************");
  }

  NSLog(@"test 1 passed\n\n");
}
