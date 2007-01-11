//--------------------------------------------------------------------------
// Program to pull the information out of various types of EXIF digital 
// camera files and show it in a reasonably consistent way
//
// This module handles basic Jpeg file handling
//
// Matthias Wandel,  Dec 1999 - Dec 2002 
//--------------------------------------------------------------------------
#include "jhead.h"

// Storage for simplified info extracted from file.

#define SET_IF_EXISTS(v, k) \
  do { value = v; if (value) [imageInfo setObject: value forKey: k]; } while (0)
#define MAX_SECTIONS 100
static Section_t Sections[MAX_SECTIONS];
static int SectionsRead;
static int HaveAll;

//--------------------------------------------------------------------------
// Get 16 bits motorola order (always) for jpeg header stuff.
//--------------------------------------------------------------------------
static int Get16m(const void * Short)
{
  return (((uchar *)Short)[0] << 8) | ((uchar *)Short)[1];
}

//--------------------------------------------------------------------------
// Process a COM marker.
// We want to print out the marker contents as legible text;
// we must guard against random junk and varying newline representations.
//--------------------------------------------------------------------------
static void process_COM (const uchar *Data, int length,
                                        NSMutableDictionary *imageInfo)
{
  int ch;
  char Comment[MAX_COMMENT+1];
  id value;
  int nch;
  int a;

  nch = 0;

  if (length > MAX_COMMENT) {
    length = MAX_COMMENT; // Truncate if it won't fit in our structure.
  }
  
  for (a = 2; a < length; a++) {
    ch = Data[a];

    if (ch == '\r' && Data[a+1] == '\n') {
      continue; // Remove cr followed by lf.
    }
    
    if (ch >= 32 || ch == '\n' || ch == '\t') {
      Comment[nch++] = (char)ch;
    } else {
      Comment[nch++] = '?';
    }
  }

  Comment[nch] = '\0'; // Null terminate  
  SET_IF_EXISTS ([NSString stringWithCString: Comment], @"GSMDItemComment");
}

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// AcquisitionModel 
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 
//--------------------------------------------------------------------------
// Process a SOFn marker.  This is useful for the image dimensions
//--------------------------------------------------------------------------
static void process_SOFn (const uchar *Data, int marker,
                                  NSMutableDictionary *imageInfo)
{
  int data_precision = Data[2];
//  int num_components = Data[7];
//  BOOL isColor = (num_components >= 3);
  id value;
    
#define SET_IF_EXISTS(v, k) \
  do { value = v; if (value) [imageInfo setObject: value forKey: k]; } while (0)
  
  SET_IF_EXISTS ([NSNumber numberWithInt: Get16m(Data+3)], @"GSMDItemFNumber");
  SET_IF_EXISTS ([NSNumber numberWithInt: Get16m(Data+5)], @"GSMDItemPixelWidth");
//  SET_IF_EXISTS ([NSNumber numberWithUnsignedInt: isColor], @"iscolor");
//  SET_IF_EXISTS ([NSNumber numberWithInt: marker], @"process");
  SET_IF_EXISTS ([NSNumber numberWithInt: data_precision], @"GSMDItemBitsPerSample");
//  SET_IF_EXISTS ([NSNumber numberWithInt: num_components], @"colorcomponents");
}


//--------------------------------------------------------------------------
// Parse the marker stream until SOS or EOI is seen;
//--------------------------------------------------------------------------
BOOL ReadJpegSections(FILE *infile, NSMutableDictionary *imageInfo)
{
  int a;
  BOOL HaveCom = NO;

  a = fgetc(infile);

  if (a != 0xff || fgetc(infile) != M_SOI){
    return NO;
  }
  
  while(1) {
    int itemlen;
    int marker = 0;
    int ll, lh, got;
    uchar *Data;

    if (SectionsRead >= MAX_SECTIONS) {
      fprintf(stderr, "Too many sections in jpg file\n");
      return NO;
    }

    for (a = 0; a < 7; a++) {
      marker = fgetc(infile);
      
      if (marker != 0xff) {
        break;
      }
      
      if (a >= 6){
        fprintf(stderr, "too many padding bytes\n");
        return NO;
      }
    }

    if (marker == 0xff){
      // 0xff is legal padding, but if we get that many, something's wrong.
      fprintf(stderr, "too many padding bytes!\n");
      return NO;
    }

    Sections[SectionsRead].Type = marker;

    // Read the length of the section.
    lh = fgetc(infile);
    ll = fgetc(infile);

    itemlen = (lh << 8) | ll;

    if (itemlen < 2){
      fprintf(stderr, "invalid marker\n");
      return NO;
    }

    Sections[SectionsRead].Size = itemlen;

    Data = (uchar *)malloc(itemlen);
    if (Data == NULL){
      fprintf(stderr, "Could not allocate memory\n");
      return NO;
    }
    Sections[SectionsRead].Data = Data;

    // Store first two pre-read bytes.
    Data[0] = (uchar)lh;
    Data[1] = (uchar)ll;

    got = fread(Data + 2, 1, itemlen - 2, infile); // Read the whole section.
    if (got != itemlen-2) {
      fprintf(stderr, "Premature end of file?\n");
      return NO;
    }
    
    SectionsRead += 1;

    switch(marker) {
      case M_SOS:   // stop before hitting compressed data 
        return YES;

      case M_EOI:   // in case it's a tables-only JPEG stream
        fprintf(stderr, "No image in jpeg!\n");
        return NO;

      case M_COM: // Comment section
        if (HaveCom){
          // Discard this section.
          free(Sections[--SectionsRead].Data);
        } else{
          process_COM(Data, itemlen, imageInfo);
          HaveCom = YES;
        }
        break;

      case M_JFIF:
        // Regular jpegs always have this tag, exif images have the exif
        // marker instead, althogh ACDsee will write images with both markers.
        // this program will re-create this marker on absence of exif marker.
        // hence no need to keep the copy from the file.
        free(Sections[--SectionsRead].Data);
        break;

      case M_EXIF:
        // Seen files from some 'U-lead' software with Vivitar scanner
        // that uses marker 31 for non exif stuff.  Thus make sure 
        // it says 'Exif' in the section before treating it as exif.
        if (memcmp(Data+2, "Exif", 4) == 0){
          process_EXIF(Data, itemlen, imageInfo);
        } else {
          // Discard this section.
          free(Sections[--SectionsRead].Data);
        }
        break;

      case M_SOF0: 
      case M_SOF1: 
      case M_SOF2: 
      case M_SOF3: 
      case M_SOF5: 
      case M_SOF6: 
      case M_SOF7: 
      case M_SOF9: 
      case M_SOF10:
      case M_SOF11:
      case M_SOF13:
      case M_SOF14:
      case M_SOF15:
        process_SOFn(Data, marker, imageInfo);
        break;
        
      default:
        // Skip any other sections.
        break;
    }
  }
  
  return YES;
}

//--------------------------------------------------------------------------
// Discard read data.
//--------------------------------------------------------------------------
void DiscardData(void)
{
  int a;
  
  for (a = 0; a < SectionsRead; a++){
    free(Sections[a].Data);
  }
  
  SectionsRead = 0;
  HaveAll = 0;
}

//--------------------------------------------------------------------------
// Read image data.
//--------------------------------------------------------------------------
BOOL ReadJpegFile(const char * FileName, NSMutableDictionary *imageInfo)
{
  FILE *infile;
  BOOL ret;

  infile = fopen(FileName, "rb"); // Unix ignores 'b', windows needs it.

  if (infile == NULL) {
    fprintf(stderr, "can't open '%s'\n", FileName);
    return NO;
  }

  // Scan the JPEG headers.
  ret = ReadJpegSections(infile, imageInfo);
  
  if (ret == NO) {
    fprintf(stderr, "Not JPEG: '%s'\n", FileName);
  }

  fclose(infile);

  if (ret == NO) {
    DiscardData();
  }
  
  return ret;
}

//--------------------------------------------------------------------------
// Initialisation.
//--------------------------------------------------------------------------
void ResetJpgfile(void)
{
  memset(&Sections, 0, sizeof(Sections));
  SectionsRead = 0;
  HaveAll = 0;
}
