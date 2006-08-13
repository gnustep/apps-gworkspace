//--------------------------------------------------------------------------
// Include file for jhead program.
//
// This include file only defines stuff that goes across modules.  
// I like to keep the definitions for macros and structures as close to 
// where they get used as possible, so include files only get stuff that 
// gets used in more than one file.
//--------------------------------------------------------------------------

#ifndef JHEAD_H
#define JHEAD_H

#include <Foundation/Foundation.h>

typedef unsigned char uchar;

#define MAX_COMMENT 2000

//--------------------------------------------------------------------------
// This structure is used to store jpeg file sections in memory.
typedef struct {
  uchar *Data;
  int Type;
  unsigned Size;
} Section_t;

// prototypes for jhead.c functions
void ErrNonfatal(char *msg, int a1, int a2);

// Prototypes for exif.c functions.
void process_EXIF (unsigned char * CharBuf, unsigned int length,
                                        NSMutableDictionary *imageInfo);
double ConvertAnyFormat(void * ValuePtr, int Format);
int Get16u(void * Short);
unsigned Get32u(void * Long);
int Get32s(void * Long);

//--------------------------------------------------------------------------
// Exif format descriptor stuff
extern const int BytesPerFormat[];

#define NUM_FORMATS 12

#define FMT_BYTE       1 
#define FMT_STRING     2
#define FMT_USHORT     3
#define FMT_ULONG      4
#define FMT_URATIONAL  5
#define FMT_SBYTE      6
#define FMT_UNDEFINED  7
#define FMT_SSHORT     8
#define FMT_SLONG      9
#define FMT_SRATIONAL 10
#define FMT_SINGLE    11
#define FMT_DOUBLE    12

// Prototypes from jpgfile.c
BOOL ReadJpegSections (FILE *infile, NSMutableDictionary *imageInfo);
void DiscardData(void);
BOOL ReadJpegFile(const char *FileName, NSMutableDictionary *imageInfo);
void ResetJpgfile(void);

//--------------------------------------------------------------------------
// JPEG markers consist of one or more 0xFF bytes, followed by a marker
// code byte (which is not an FF).  Here are the marker codes of interest
// in this program.  (See jdmarker.c for a more complete list.)
//--------------------------------------------------------------------------

#define M_SOF0  0xC0            // Start Of Frame N
#define M_SOF1  0xC1            // N indicates which compression process
#define M_SOF2  0xC2            // Only SOF0-SOF2 are now in common use
#define M_SOF3  0xC3
#define M_SOF5  0xC5            // NB: codes C4 and CC are NOT SOF markers
#define M_SOF6  0xC6
#define M_SOF7  0xC7
#define M_SOF9  0xC9
#define M_SOF10 0xCA
#define M_SOF11 0xCB
#define M_SOF13 0xCD
#define M_SOF14 0xCE
#define M_SOF15 0xCF
#define M_SOI   0xD8            // Start Of Image (beginning of datastream)
#define M_EOI   0xD9            // End Of Image (end of datastream)
#define M_SOS   0xDA            // Start Of Scan (begins compressed data)
#define M_JFIF  0xE0            // Jfif marker
#define M_EXIF  0xE1            // Exif marker
#define M_COM   0xFE            // COMment 
#define M_DQT   0xDB
#define M_DHT   0xC4
#define M_DRI   0xDD

#endif // JHEAD_H
