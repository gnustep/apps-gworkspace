#ifndef TEST_H
#define TEST_H

#include <Foundation/Foundation.h>
#include <DBKit/DBKBTree.h>
#include <DBKit/DBKBTreeNode.h>

void test1(DBKBTree *tree);
void test2(DBKBTree *tree);
void test3(DBKBTree *tree);
void test4(DBKBTree *tree);
void test5(DBKBTree *tree);
void test6(DBKBTree *tree);
void test7(DBKBTree *tree);

void printTree(DBKBTree *tree);
void printTreeFromNode(DBKBTree *tree, DBKBTreeNode *node, int depth);

#endif // TEST_H
