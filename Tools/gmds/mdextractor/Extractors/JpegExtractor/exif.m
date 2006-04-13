//--------------------------------------------------------------------------
// Program to pull the information out of various types of EXIF digital 
// camera files and show it in a reasonably consistent way
//
// This module parses the very complicated exif structures.
//
// Matthias Wandel,  Dec 1999 - Dec 2002 
//--------------------------------------------------------------------------
#include <math.h>
#include "jhead.h"

static unsigned char *LastExifRefd;
static int MotorolaOrder = 0;

const int BytesPerFormat[] = {0,1,1,2,4,8,1,1,2,4,8,4,8};

//--------------------------------------------------------------------------
// Describes tag values

#define TAG_INTEROP_INDEX               0x001  
#define TAG_INTEROP_VERSION             0x002  
#define TAG_IMAGE_WIDTH                 0x100  
#define TAG_IMAGE_LENGTH                0x101  
#define TAG_BITS_PER_SAMPLE             0x102  
#define TAG_COMPRESSION                 0x103  
#define TAG_PHOTOMETRIC_INTERPRETATION  0x106  
#define TAG_FILL_ORDER                  0x10A  
#define TAG_DOCUMENT_NAME               0x10D  
#define TAG_IMAGE_DESCRIPTION           0x10E  
#define TAG_MAKE                        0x010F
#define TAG_MODEL                       0x0110
#define TAG_STRIP_OFFSETS               0x111  
#define TAG_ORIENTATION                 0x0112
#define TAG_SAMPLES_PER_PIXEL           0x115  
#define TAG_ROWS_PER_STRIP              0x116  
#define TAG_STRIP_BYTE_COUNTS           0x117  
#define TAG_X_RESOLUTION                0x11A  
#define TAG_Y_RESOLUTION                0x11B  
#define TAG_PLANAR_CONFIGURATION        0x11C  
#define TAG_RESOLUTION_UNIT             0x128  
#define TAG_TRANSFER_FUNCTION           0x12D  
#define TAG_SOFTWARE                    0x131  
#define TAG_DATETIME                    0x0132
#define TAG_ARTIST                      0x13B  
#define TAG_WHITE_POINT                 0x13E  
#define TAG_PRIMARY_CHROMATICITIES      0x13F  
#define TAG_TRANSFER_RANGE              0x156  
#define TAG_JPEG_PROC                   0x200  
#define TAG_THUMBNAIL_OFFSET            0x0201
#define TAG_THUMBNAIL_LENGTH            0x0202
#define TAG_YCBCR_COEFICIENTS           0x211  
#define TAG_YCBCR_SUBSAMPLING           0x212  
#define TAG_YCBCR_POSITIONING           0x213  
#define TAG_REFERENCE_BLACK_WHITE       0x214  
#define TAG_RELATED_IMAGE_WIDTH         0x1001 
#define TAG_RELATED_IMAGE_LENGTH        0x1002 
#define TAG_CFA_REPEAT_PATTERN_DIM      0x828D 
#define TAG_CFA_PATTERN_                0x828E 
#define TAG_BATTERY_LEVEL               0x828F 
#define TAG_COPYRIGHT                   0x8298 
#define TAG_EXPOSURETIME                0x829A
#define TAG_FNUMBER                     0x829D
#define TAG_IPTC_NAA                    0x83BB 
#define TAG_EXIF_OFFSET                 0x8769
#define TAG_INTER_COLOR_PROFILE         0x8773 
#define TAG_EXPOSURE_PROGRAM            0x8822
#define TAG_SPECTRAL_SENSITIVITY        0x8824 
#define TAG_GPSINFO                     0x8825
#define TAG_ISO_EQUIVALENT              0x8827
#define TAG_OECF                        0x8828 
#define TAG_EXIF_VERSION                0x9000 
#define TAG_DATETIME_ORIGINAL           0x9003
#define TAG_DATETIME_DIGITIZED          0x9004
#define TAG_COMPONENTS_CONFIGURATION    0x9101 
#define TAG_COMPRESSED_BITS_PER_PIXEL   0x9102 
#define TAG_SHUTTERSPEED                0x9201
#define TAG_APERTURE                    0x9202
#define TAG_BRIGHTNESS_VALUE            0x9203 
#define TAG_EXPOSURE_BIAS               0x9204
#define TAG_MAXAPERTURE                 0x9205
#define TAG_SUBJECT_DISTANCE            0x9206
#define TAG_METERING_MODE               0x9207
#define TAG_LIGHT_SOURCE                0x9208
#define TAG_FLASH                       0x9209
#define TAG_FOCALLENGTH                 0x920A
#define TAG_MAKER_NOTE                  0x927C
#define TAG_USERCOMMENT                 0x9286
#define TAG_SUB_SEC_TIME                0x9290 
#define TAG_SUB_SEC_TIME_ORIGINAL       0x9291 
#define TAG_SUB_SEC_TIME_DIGITIZED      0x9292 
#define TAG_FLASH_PIX_VERSION           0xA000 
#define TAG_COLORSPACE                  0xA001 
#define TAG_EXIF_IMAGEWIDTH             0xa002
#define TAG_EXIF_IMAGELENGTH            0xa003
#define TAG_RELATED_AUDIO_FILE          0xA004 
#define TAG_INTEROP_OFFSET              0xa005
#define TAG_FLASH_ENERGY                0xA20B 
#define TAG_SPATIAL_FREQUENCY_RESPONSE  0xA20C 
#define TAG_FOCALPLANEXRES              0xa20E
#define TAG_FOCALPLANEYRES              0xA20F 
#define TAG_FOCALPLANEUNITS             0xa210
#define TAG_SUBJECT_LOCATION            0xA214 
#define TAG_EXPOSURE_INDEX              0xa215
#define TAG_SENSING_METHOD              0xA217 
#define TAG_FILE_SOURCE                 0xA300 
#define TAG_SCENE_TYPE                  0xA301 
#define TAG_CFA_PATTERN                 0xA301 
#define TAG_CUSTOM_RENDERED             0xA401 
#define TAG_EXPOSURE_MODE               0xa402
#define TAG_WHITEBALANCE                0xa403
#define TAG_DIGITALZOOMRATIO            0xA404
#define TAG_FOCALLENGTH_35MM            0xa405
#define TAG_SCENE_CAPTURE_TYPE          0xA406 
#define TAG_GAIN_CONTROL                0xA407 
#define TAG_CONTRAST                    0xA408 
#define TAG_SATURATION                  0xA409 
#define TAG_SHARPNESS                   0xA40a 
#define TAG_SUBJECT_DISTANCE_RANGE      0xA40c 


//--------------------------------------------------------------------------
// Convert a 16 bit unsigned value from file's native byte order
//--------------------------------------------------------------------------
int Get16u(void * Short)
{
  if (MotorolaOrder){
    return (((uchar *)Short)[0] << 8) | ((uchar *)Short)[1];
  } else {
    return (((uchar *)Short)[1] << 8) | ((uchar *)Short)[0];
  }
}

//--------------------------------------------------------------------------
// Convert a 32 bit signed value from file's native byte order
//--------------------------------------------------------------------------
int Get32s(void * Long)
{
  if (MotorolaOrder) {
    return (((char *)Long)[0] << 24) | (((uchar *)Long)[1] << 16)
            | (((uchar *)Long)[2] << 8 ) | (((uchar *)Long)[3] << 0 );
  } else {
    return (((char *)Long)[3] << 24) | (((uchar *)Long)[2] << 16)
            | (((uchar *)Long)[1] << 8 ) | (((uchar *)Long)[0] << 0 );
  }
}

//--------------------------------------------------------------------------
// Convert a 32 bit unsigned value from file's native byte order
//--------------------------------------------------------------------------
unsigned Get32u(void * Long)
{
  return (unsigned)Get32s(Long) & 0xffffffff;
}

//--------------------------------------------------------------------------
// Evaluate number, be it int, rational, or float from directory.
//--------------------------------------------------------------------------
double ConvertAnyFormat(void * ValuePtr, int Format)
{
  double Value;
  Value = 0;

  switch(Format){
    case FMT_SBYTE:     Value = *(signed char *)ValuePtr;  break;
    case FMT_BYTE:      Value = *(uchar *)ValuePtr;        break;

    case FMT_USHORT:    Value = Get16u(ValuePtr);          break;
    case FMT_ULONG:     Value = Get32u(ValuePtr);          break;

    case FMT_URATIONAL:
    case FMT_SRATIONAL: 
      {
        int Num, Den;
        Num = Get32s(ValuePtr);
        Den = Get32s(4+(char *)ValuePtr);
        if (Den == 0) {
          Value = 0;
        } else {
          Value = (double)Num/Den;
        }
        break;
      }

    case FMT_SSHORT:    Value = (signed short)Get16u(ValuePtr);  break;
    case FMT_SLONG:     Value = Get32s(ValuePtr);                break;

    // Not sure if this is correct (never seen float used in Exif format)
    case FMT_SINGLE:    Value = (double)*(float *)ValuePtr;      break;
    case FMT_DOUBLE:    Value = *(double *)ValuePtr;             break;
  }
  
  return Value;
}

NSString *removeUnprintables(unsigned char *valuePtr, int byteCount)
{
  NSMutableString *str = [NSMutableString string];
  BOOL noprint = NO;
  int i;

  for (i = 0; i < byteCount; i++) {
    if (valuePtr[i] >= 32) {
      [str appendFormat: @"%c", valuePtr[i]];
      noprint = NO;
    } else {
      if ((noprint == NO) && (i != byteCount-1)) {
        [str appendString: @"?"];
        noprint = YES;
      }
    }
  }
  
  return str;  
}

//--------------------------------------------------------------------------
// Process one of the nested EXIF directories.
//--------------------------------------------------------------------------
static void ProcessExifDir(unsigned char *DirStart, unsigned char *OffsetBase, 
        unsigned ExifLength, int NestingLevel, NSMutableDictionary *imageInfo)
{
  int de;
  int a;
  int NumDirEntries;
  char IndentString[25];

  if (NestingLevel > 4){
    ErrNonfatal("Maximum directory nesting exceeded (corrupt exif header)", 0,0);
    return;
  }

  memset(IndentString, ' ', 25);
  IndentString[NestingLevel * 4] = '\0';

  NumDirEntries = Get16u(DirStart);
  #define DIR_ENTRY_ADDR(Start, Entry) (Start+2+12*(Entry))

  {
    unsigned char *DirEnd = DIR_ENTRY_ADDR(DirStart, NumDirEntries);
    
    if (DirEnd+4 > (OffsetBase+ExifLength)) {
      if (DirEnd+2 == OffsetBase+ExifLength || DirEnd == OffsetBase+ExifLength){
        // Version 1.3 of jhead would truncate a bit too much.
        // This also caught later on as well.
      } else {
        ErrNonfatal("Illegally sized directory",0,0);
        return;
      }
    }
    
    if (DirEnd > LastExifRefd) {
      LastExifRefd = DirEnd;
    }
  }

  for (de = 0; de < NumDirEntries; de++) {
    char buff[255];
    int Tag, Format, Components;
    unsigned char *ValuePtr;
    int ByteCount;
    unsigned char *DirEntry;
    
    DirEntry = DIR_ENTRY_ADDR(DirStart, de);

    Tag = Get16u(DirEntry);
    Format = Get16u(DirEntry+2);
    Components = Get32u(DirEntry+4);

    if ((Format-1) >= NUM_FORMATS) {
      // (-1) catches illegal zero case as unsigned underflows to positive large.
      ErrNonfatal("Illegal number format %d for tag %04x", Format, Tag);
      continue;
    }

    ByteCount = Components * BytesPerFormat[Format];

    if (ByteCount > 4){
      unsigned OffsetVal;
      OffsetVal = Get32u(DirEntry+8);
      // If its bigger than 4 bytes, the dir entry contains an offset.
      if (OffsetVal+ByteCount > ExifLength){
        // Bogus pointer offset and / or bytecount value
        ErrNonfatal("Illegal value pointer for tag %04x", Tag,0);
        continue;
      }
      ValuePtr = OffsetBase+OffsetVal;
    }else{
      // 4 bytes or less and value is in the dir entry itself
      ValuePtr = DirEntry+8;
    }

    if (LastExifRefd < ValuePtr+ByteCount){
      // Keep track of last byte in the exif header that was actually referenced.
      // That way, we know where the discardable thumbnail data begins.
      LastExifRefd = ValuePtr+ByteCount;
    }

    if (Tag == TAG_MAKER_NOTE){
      continue;
    }


    // Extract useful components of tag
    switch(Tag) {
    
      /*********************************************/
      case TAG_COLORSPACE:
        {
          int space = (int)ConvertAnyFormat(ValuePtr, Format);
          NSString *spacestr;
          
          switch (space) {
            case 1:
              spacestr = @"RGB";
              break;
            default:
              spacestr = @"Unknown";
              break;
          }
    
          [imageInfo setObject: spacestr forKey: @"kMDItemColorSpace"];
          
          break;
        }

      case TAG_EXIF_VERSION:
        {
          [imageInfo setObject: removeUnprintables(ValuePtr, ByteCount)
                        forKey: @"kMDItemEXIFVersion"];
          
          break;
        }
    
      case TAG_X_RESOLUTION:
        {      
          int xres = (int)ConvertAnyFormat(ValuePtr, Format);
      
          [imageInfo setObject: [NSNumber numberWithInt: xres] 
                        forKey: @"kMDItemResolutionWidthDPI"];
          break;
        }

      case TAG_Y_RESOLUTION:
        {      
          int yres = (int)ConvertAnyFormat(ValuePtr, Format);
      
          [imageInfo setObject: [NSNumber numberWithInt: yres] 
                        forKey: @"kMDItemResolutionHeightDPI"];
          break;
        }
        
      case TAG_DOCUMENT_NAME:
        {
          [imageInfo setObject: removeUnprintables(ValuePtr, ByteCount)
                        forKey: @"kMDItemTitle"];
          break;
        }
      
      case TAG_ARTIST:
        {
          NSString *author = removeUnprintables(ValuePtr, ByteCount);
          
          [imageInfo setObject: [NSArray arrayWithObject: author] 
                        forKey: @"kMDItemAuthors"];
          break;
        }
      
      case TAG_COPYRIGHT:
        {
          [imageInfo setObject: removeUnprintables(ValuePtr, ByteCount)
                        forKey: @"kMDItemCopyright"];
          break;
        }
        
        // TAG_INTER_COLOR_PROFILE
      /*********************************************/

      case TAG_MAKE:
        strncpy(buff, (char *)ValuePtr, ByteCount < 31 ? ByteCount : 31);
        
        [imageInfo setObject: [NSString stringWithCString: buff]
                      forKey: @"kMDItemAcquisitionMake"];
        break;

      case TAG_MODEL:
        strncpy(buff, (char *)ValuePtr, ByteCount < 39 ? ByteCount : 39);
      
        [imageInfo setObject: [NSString stringWithCString: buff]
                      forKey: @"kMDItemAcquisitionModel"];
        break;

      case TAG_DATETIME_ORIGINAL:
        // If we get a DATETIME_ORIGINAL, we use that one.
        strncpy(buff, (char *)ValuePtr, strlen((char *)ValuePtr) + 1);
        
        [imageInfo setObject: [NSString stringWithCString: buff]
                      forKey: @"kMDItemExposureTimeString"];

      case TAG_DATETIME_DIGITIZED:
      case TAG_DATETIME:
        if ([imageInfo objectForKey: @"kMDItemExposureTimeString"] == nil) {
          strncpy(buff, (char *)ValuePtr, strlen((char *)ValuePtr) + 1);
          [imageInfo setObject: [NSString stringWithCString: buff]
                        forKey: @"kMDItemExposureTimeString"];      
        }
       
        break;

      case TAG_USERCOMMENT:
        {
          NSString *comments = [imageInfo objectForKey: @"kMDItemComment"];
        
          if (comments == nil) {
            comments = [NSString string];
          }
          
          // Olympus has this padded with trailing spaces. Remove these first.
          for (a = ByteCount;;) {
            a--;
            if ((ValuePtr)[a] == ' ') {
              (ValuePtr)[a] = '\0';
            } else {
              break;
            }
            if (a == 0) {
              break;
            }
          }

          // Copy the comment
          if (memcmp(ValuePtr, "ASCII", 5) == 0) {
            for (a = 5; a < 10; a++) {
              int c;
              c = (ValuePtr)[a];
              if (c != '\0' && c != ' ') {
                strncpy(buff, (char *)ValuePtr + a, 199);
                comments = [comments stringByAppendingString: [NSString stringWithCString: buff]];
                break;
              }
            }

          } else {
            strncpy(buff, (char *)ValuePtr + a, 199);
            comments = [comments stringByAppendingString: [NSString stringWithCString: buff]];
          }
          
          [imageInfo setObject: comments forKey: @"kMDItemComment"];      
          
          break;
        }
        
      case TAG_FNUMBER:
        {
          float aperture = (float)ConvertAnyFormat(ValuePtr, Format);

          // Simplest way of expressing aperture, so I trust it the most.
          // (overwrite previously computd value if there is one)

          [imageInfo setObject: [NSNumber numberWithFloat: aperture]
                        forKey: @"kMDItemFNumber"];

          [imageInfo setObject: [NSNumber numberWithFloat: aperture]
                        forKey: @"kMDItemMaxAperture"];

          break;
        }
      case TAG_APERTURE:
      case TAG_MAXAPERTURE:
        {
          float aperture = (float)exp(ConvertAnyFormat(ValuePtr, Format) * log(2) * 0.5);

          [imageInfo setObject: [NSNumber numberWithFloat: aperture]
                        forKey: @"kMDItemAperture"];

          break;
        }
        
      case TAG_FOCALLENGTH:
        {
          // Nice digital cameras actually save the focal length as a function
          // of how farthey are zoomed in.        
          float flen = (float)ConvertAnyFormat(ValuePtr, Format);
          
          [imageInfo setObject: [NSNumber numberWithFloat: flen]
                        forKey: @"kMDItemFocalLength"];

          break;
        }
        
      case TAG_SUBJECT_DISTANCE:
        {
          // Inidcates the distacne the autofocus camera is focused to.
          // Tends to be less accurate as distance increases.
        
          float distance = (float)ConvertAnyFormat(ValuePtr, Format);
                              
          [imageInfo setObject: [NSNumber numberWithFloat: distance]
                        forKey: @"distance"];
          
          break;
        }
        
      case TAG_EXPOSURETIME:
        {
          // Simplest way of expressing exposure time, so I trust it most.
          // (overwrite previously computd value if there is one)        
          float exptime = (float)ConvertAnyFormat(ValuePtr, Format);
                    
          [imageInfo setObject: [NSNumber numberWithFloat: exptime]
                        forKey: @"kMDItemExposureTimeSeconds"];
          
          break;
        }
        
      case TAG_SHUTTERSPEED:
        // More complicated way of expressing exposure time, so only use
        // this value if we don't already have it from somewhere else.      
        if ([imageInfo objectForKey: @"kMDItemExposureTimeSeconds"] == nil) {
          float exptime = (float)(1/exp(ConvertAnyFormat(ValuePtr, Format)*log(2)));

          [imageInfo setObject: [NSNumber numberWithFloat: exptime]
                        forKey: @"kMDItemExposureTimeSeconds"];        
        }
        
        break;

      case TAG_FLASH:
        {
          int flash = (int)ConvertAnyFormat(ValuePtr, Format);
          BOOL flashused = (flash > 0);
          BOOL redeye = ((flash == 0x41) || (flash == 0x45) || (flash == 0x47) 
                      || (flash == 0x49) || (flash == 0x4d) || (flash == 0x4f) 
                      || (flash == 0x59) || (flash == 0x5d) || (flash == 0x5f));

          [imageInfo setObject: [NSNumber numberWithUnsignedInt: flashused]
                        forKey: @"kMDItemFlashOnOff"];        

          [imageInfo setObject: [NSNumber numberWithUnsignedInt: redeye]
                        forKey: @"kMDItemRedEyeOnOff"];        

          break;
        }
        
      case TAG_ORIENTATION:
        if ([imageInfo objectForKey: @"kMDItemOrientation"] == nil) {
          int orientation = (int)ConvertAnyFormat(ValuePtr, Format);

          if (orientation < 1 || orientation > 8) {
            ErrNonfatal("Undefined rotation value %d", orientation, 0);
            orientation = 0;
          }

          [imageInfo setObject: [NSNumber numberWithInt: orientation] 
                        forKey: @"kMDItemOrientation"];        
        }
        break;
        
      case TAG_EXIF_IMAGELENGTH:
      case TAG_EXIF_IMAGEWIDTH:
        break;

      case TAG_FOCALPLANEXRES:
        break;

      case TAG_FOCALPLANEUNITS:
        break;

      case TAG_EXPOSURE_BIAS:
        {
          float bias = (float)ConvertAnyFormat(ValuePtr, Format);
          
          [imageInfo setObject: [NSNumber numberWithFloat: bias]
                        forKey: @"exposurebias"];        
          break;
        }
        
      case TAG_WHITEBALANCE:
        {
          int balance = (int)ConvertAnyFormat(ValuePtr, Format);
      
          [imageInfo setObject: [NSNumber numberWithInt: balance]
                        forKey: @"kMDItemWhiteBalance"];              
          break;
        }
        
      case TAG_LIGHT_SOURCE:
        {
          int lsource = (int)ConvertAnyFormat(ValuePtr, Format);

          [imageInfo setObject: [NSNumber numberWithInt: lsource]
                        forKey: @"lightsource"];                
          break;
        }
        
      case TAG_METERING_MODE:
        {
          int mode = (int)ConvertAnyFormat(ValuePtr, Format);
          NSString *modestr;

          switch (mode) {
            case 2:
              modestr = @"Center weight";
              break;
            case 3:
              modestr = @"Spot";
              break;
            case 5:
              modestr = @"Matrix";
              break;
            default:
              modestr = @"Unknown";
              break;
          }

          [imageInfo setObject: modestr forKey: @"kMDItemMeteringMode"];        
        
          break;
        }
        
      case TAG_EXPOSURE_PROGRAM:
        {
          int exprog = (int)ConvertAnyFormat(ValuePtr, Format);
          NSString *expstr;
          
          switch (exprog) {
            case 1:
              expstr = @"Manual";
              break;
            case 2:
              expstr = @"Normal";
              break;
            case 3:
              expstr = @"Aperture priority";
              break;
            case 4:
              expstr = @"Shutter priority";
              break;
            case 5:
              expstr = @"Creative Program (based towards depth of field)";
              break;
            case 6:
              expstr = @"Action program (based towards fast shutter speed)";
              break;
            case 7:
              expstr = @"Portrait Mode";
              break;
            case 8:
              expstr = @"Landscape Mode";
              break;
            default:
              expstr = @"Unknown";
              break;
          }
        
          [imageInfo setObject: expstr forKey: @"kMDItemExposureProgram"];        

          break;
        }
        
      case TAG_EXPOSURE_INDEX:
        if ([imageInfo objectForKey: @"kMDItemISOSpeed"] == nil) {  
          int iso = (int)ConvertAnyFormat(ValuePtr, Format);
      
          [imageInfo setObject: [NSNumber numberWithInt: iso]
                        forKey: @"kMDItemISOSpeed"];        
        }

        break;

      case TAG_EXPOSURE_MODE:
        {
          int mode = (int)ConvertAnyFormat(ValuePtr, Format);

          [imageInfo setObject: [NSNumber numberWithInt: mode]
                        forKey: @"kMDItemExposureMode"];        
          break;
        }
        
      case TAG_ISO_EQUIVALENT:
        {
          int isoeq = (int)ConvertAnyFormat(ValuePtr, Format);
          
          if (isoeq < 50) {
            // Fixes strange encoding on some older digicams.
            isoeq *= 200;
          }

          [imageInfo setObject: [NSNumber numberWithInt: isoeq]
                        forKey: @"kMDItemISOSpeed"];        
          break;
        }
        
      case TAG_DIGITALZOOMRATIO:
        {
      //    float zoom = (float)ConvertAnyFormat(ValuePtr, Format);
          
       //   [imageInfo setObject: [NSNumber numberWithFloat: zoom]
       //                 forKey: @"digitalzoomratio"];        
          break;
        }
        
      case TAG_THUMBNAIL_OFFSET:
        break;

      case TAG_THUMBNAIL_LENGTH:
        break;

      case TAG_EXIF_OFFSET:
      case TAG_INTEROP_OFFSET:
        {
          unsigned char *SubdirStart = OffsetBase + Get32u(ValuePtr);
          
          if (SubdirStart < OffsetBase || SubdirStart > OffsetBase + ExifLength){
            ErrNonfatal("Illegal exif or interop ofset directory link",0,0);
          } else {
            ProcessExifDir(SubdirStart, OffsetBase, ExifLength, NestingLevel+1, imageInfo);
          }
          
          continue;
          break;
        }
        

      case TAG_GPSINFO:
        {
          unsigned char *SubdirStart = OffsetBase + Get32u(ValuePtr);

          if (SubdirStart < OffsetBase || SubdirStart > OffsetBase+ExifLength){
            ErrNonfatal("Illegal GPS directory link",0,0);
          } else {
         //   ProcessGpsInfo(SubdirStart, ByteCount, OffsetBase, ExifLength);
          }
          
          continue;
          break;
        }

      case TAG_FOCALLENGTH_35MM:
        {
          // The focal length equivalent 35 mm is a 2.2 tag (defined as of April 2002)
          // if its present, use it to compute equivalent focal length instead of 
          // computing it from sensor geometry and actual focal length.        
          unsigned flength = (unsigned)ConvertAnyFormat(ValuePtr, Format);
        
          [imageInfo setObject: [NSNumber numberWithUnsignedInt: flength]
                        forKey: @"focallength35mmequiv"];        
          break;
        }
    }
  }


  {
    // In addition to linking to subdirectories via exif tags, 
    // there's also a potential link to another directory at the end of each
    // directory.  this has got to be the result of a comitee!
    unsigned char * SubdirStart;
    unsigned Offset;

    if (DIR_ENTRY_ADDR(DirStart, NumDirEntries) + 4 <= OffsetBase+ExifLength){
      Offset = Get32u(DirStart+2+12*NumDirEntries);
      
      if (Offset){
        SubdirStart = OffsetBase + Offset;
        
        if (SubdirStart > OffsetBase+ExifLength || SubdirStart < OffsetBase){
          if (SubdirStart > OffsetBase && SubdirStart < OffsetBase+ExifLength+20){
            // Jhead 1.3 or earlier would crop the whole directory!
            // As Jhead produces this form of format incorrectness, 
            // I'll just let it pass silently
          } else {
            ErrNonfatal("Illegal subdirectory link",0,0);
          }
        } else {
          if (SubdirStart <= OffsetBase+ExifLength){
            ProcessExifDir(SubdirStart, OffsetBase, ExifLength, NestingLevel+1, imageInfo);
          }
        }
      }
    } else {
        // The exif header ends before the last next directory pointer.
    }
  }
}

//--------------------------------------------------------------------------
// Process a EXIF marker
// Describes all the drivel that most digital cameras include...
//--------------------------------------------------------------------------
void process_EXIF (unsigned char * ExifSection, unsigned int length,
                                        NSMutableDictionary *imageInfo)
{
  static uchar ExifHeader[] = "Exif\0\0";
  int FirstOffset;

  // Check the EXIF header component      
  if (memcmp(ExifSection+2, ExifHeader,6)){
    ErrNonfatal("Incorrect Exif header",0,0);
    return;
  }

  if (memcmp(ExifSection+8,"II",2) == 0) {
    MotorolaOrder = 0;
  } else{
    if (memcmp(ExifSection+8,"MM",2) == 0){
      MotorolaOrder = 1;
    } else {
      ErrNonfatal("Invalid Exif alignment marker.",0,0);
      return;
    }
  }

  // Check the next value for correctness.
  if (Get16u(ExifSection+10) != 0x2a){
    ErrNonfatal("Invalid Exif start (1)",0,0);
    return;
  }

  FirstOffset = Get32u(ExifSection+12);
  if (FirstOffset < 8 || FirstOffset > 16){
    // I used to ensure this was set to 8 (website I used indicated its 8)
    // but PENTAX Optio 230 has it set differently, and uses it as offset. (Sept 11 2002)
    ErrNonfatal("Suspicious offset of first IFD value",0,0);
  }

  LastExifRefd = ExifSection;

  // First directory starts 16 bytes in.  All offset are relative to 8 bytes in.
  ProcessExifDir(ExifSection+8+FirstOffset, ExifSection+8, length-6, 0, imageInfo);
}

