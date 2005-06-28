#include <DBKit/DBKBTree.h>
#include "test.h"

void test4(DBKBTree *tree)
{
  DBKBTreeNode *node;
  int index;

  NSLog(@"test 4");

  NSLog(@"insert 50 items");
  [tree insertKey: [NSNumber numberWithUnsignedLong: 122]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 245]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 491]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 474]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 440]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 372]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 236]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 473]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 438]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 368]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 228]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 457]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 406]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 304]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 100]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 201]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 403]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 298]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 88]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 177]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 355]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 202]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 405]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 302]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 96]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 193]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 387]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 266]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 24]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 49]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 99]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 199]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 399]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 290]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 72]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 145]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 291]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 74]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 149]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 299]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 90]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 181]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 363]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 218]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 437]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 366]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 224]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 449]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 390]];
  [tree insertKey: [NSNumber numberWithUnsignedLong: 272]];

  NSLog(@"Show tree structure");
  printTree(tree);

  NSLog(@"test for successful searches");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 355] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 202] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 405] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 302] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 96] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 193] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 387] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 266] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 24] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 49] getIndex: &index];
  if (node == nil) NSLog(@"************* ERROR not found *****************");

  NSLog(@"test for unsuccessful searches");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 903] getIndex: &index];
  if (node) NSLog(@"************* ERROR found unexisting element *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 182] getIndex: &index];
  if (node) NSLog(@"************* ERROR found unexisting element *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 364] getIndex: &index];
  if (node) NSLog(@"************* ERROR found unexisting element *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 219] getIndex: &index];
  if (node) NSLog(@"************* ERROR found unexisting element *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 439] getIndex: &index];
  if (node) NSLog(@"************* ERROR found unexisting element *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 367] getIndex: &index];
  if (node) NSLog(@"************* ERROR found unexisting element *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 225] getIndex: &index];
  if (node) NSLog(@"************* ERROR found unexisting element *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 441] getIndex: &index];
  if (node) NSLog(@"************* ERROR found unexisting element *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 391] getIndex: &index];
  if (node) NSLog(@"************* ERROR found unexisting element *****************");
  node = [tree nodeOfKey: [NSNumber numberWithUnsignedLong: 273] getIndex: &index];

  NSLog(@"delete some keys");
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 122]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 355]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 96]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 24]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 49]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 438]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 304]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 202]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 387]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 199]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 74]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 218]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 437]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 224]];
  [tree deleteKey: [NSNumber numberWithUnsignedLong: 272]];

  NSLog(@"Show tree structure");
  printTree(tree);

  NSLog(@"test 4 passed\n\n");
}
