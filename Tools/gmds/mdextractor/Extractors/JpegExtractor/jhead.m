//--------------------------------------------------------------------------
// Program to pull the information out of various types of EXIF digital 
// camera files and show it in a reasonably consistent way
//
// Version 2.4-2
//
//
// Compiling under Windows:  Use microsoft's compiler.  from command line:
// cl -Ox jhead.c exif.c myglob.c
//
// Dec 1999 - Jun 2005
//
// by Matthias Wandel   www.sentex.net/~mwandel
//--------------------------------------------------------------------------

#include "jhead.h"

//--------------------------------------------------------------------------
// Report non fatal errors.  Now that microsoft.net modifies exif headers,
// there's corrupted ones, and there could be more in the future.
//--------------------------------------------------------------------------
void ErrNonfatal(char *msg, int a1, int a2)
{
  fprintf(stderr,"Nonfatal Error : ");
  fprintf(stderr, msg, a1, a2);
  fprintf(stderr, "\n");
} 


