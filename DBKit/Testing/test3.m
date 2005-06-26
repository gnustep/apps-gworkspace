#include <DBKit/DBKBTree.h>

void test3(DBKBTree *tree)
{
  NSLog(@"test 3");

  NSLog(@"insert 15 items");
  [tree insertKey: [NSNumber numberWithUnsignedLong: 122]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 125]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 245]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 372]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 418]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 440]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 474]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 491]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 752]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 803]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 853]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 934]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 957]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 968]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 986]];

  NSLog(@"Show tree structure");
  [tree print];

  printf("delete item 968 from a leaf and show result\n");
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 968]];
  [tree print];

  printf("delete item 957 which causes a merge\n");
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 957]];
  [tree print];

  printf("delete item 474 - causes a right borrow\n");
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 474]];
  [tree print];

  printf("delete internal item 803 - replaced by successor\n");
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 803]];
  [tree print];

  printf("delete internal item 440 - causes a merge\n");
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 440]];
  [tree print];

  printf("delete internal item 853 - replaced by predecessor\n");
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 853]];
  [tree print];

  printf("delete item 934 - causes a left borrow\n");
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 934]];
  [tree print];

  NSLog(@"test 3 passed\n\n");
}
