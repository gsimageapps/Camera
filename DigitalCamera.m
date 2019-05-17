/*
 * Copyright (C) 2003  Stefan Kleine Stegemann
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#include "DigitalCamera.h"

#include <Foundation/NSException.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSPanel.h>

#include <gphoto2.h>


// some usefull macros
#define CHECK_GP(result)       if (result < 0) { GPError(result); return; }
#define CHECK_GP_RV(result)    if (result < 0) { GPError(result); return nil; }
#define CHECK_GP_RNULL(result) if (result < 0) { GPError(result); return NULL; }
#define CHECK_PORT(result)     if (result < 0) { GPPortError(result); return; }
#define CHECK_PORT_RV(result)  if (result < 0) { GPPortError(result); return nil; }


/*
 * Functions.
 */

void ShowGPError(int result, const char *msg)
{
   // TODO: localize this
   //NSRunAlertPanel(@"Error while interacting with camera!",
   //                [NSString stringWithFormat: @"%s (Errorcode: %d)", msg, result],
   //                @"Confirm", nil, nil);
   NSLog(@"Error while interacting with camera: %s (Error: %d)", msg, result);
}


void GPError(int result)
{
   ShowGPError(result, gp_result_as_string(result));
}


void GPPortError(int result)
{
   ShowGPError(result, gp_port_result_as_string(result));
}


static GPContext* globalGPContext = 0;

GPContext* GetGPContext()
{
   if (globalGPContext == 0)
   {
      globalGPContext = gp_context_new();
      // TODO: globalGPContext has to be unref-ed somewhere
   }
   
   return globalGPContext;
}


/*
 * Non-Public methods.
 */
@interface DigitalCamera(Private)
- (void) _collectFilesIntoArray: (NSMutableArray*)array
               startingAtFolder: (NSString*)folder;
- (Camera*) _gpCamera;
- (GPContext*) _gpContext;
- (NSString*) _temporaryThumbnailFileFor: (NSString*)filename;
- (CameraFile*) _createGPFile: (DigitalCameraFile*)file
                       ofType: (CameraFileType)fileType;
@end


/*
 * An instance of this class represents a connection to
 * a camera that is connected to your system. Use 
 * autodetectCameras to get a list with all available
 * cameras.
 */
@implementation DigitalCamera

/*
 * Designated initializer. Creates a new camera at
 * a specific port.
 */
- (id) initWithName: (NSString*)_name 
             atPort: (NSString*)_portName
           gpCamera: (void*)_gpCamera
          gpContext: (void*)_gpContext
{
   if ((self = [super init]))
   {
      name = [_name copy];
      portName = [_portName copy];

      gpContext = _gpContext;
      gp_context_ref([self _gpContext]);

      gpCamera = _gpCamera;
      gp_camera_ref([self _gpCamera]);
   }

   return self;
}


- (void) dealloc
{
   RELEASE(name);
   RELEASE(portName);
   gp_camera_unref([self _gpCamera]);
   gp_context_unref([self _gpContext]);

   [super dealloc];
}


/*
 * Get the name of this camera.
 */
- (NSString*) name
{
   return name;
}


/*
 * Get the name of the port to which this camera is connected.
 */
- (NSString*) portName
{
   return portName;
}


/*
 * Get all files that are available on this camera.
 * This method walks through all folders recursively
 * and returns all files found. The returned array is 
 * autoreleased. The array contains elements of the
 * type DigitalCameraFile, each element is retained only
 * by the array itself. If this method fails, it 
 * returns nil.
 */
- (NSArray*) availableFiles
{
   NSMutableArray* files = [[NSMutableArray alloc] initWithCapacity: 0];
   [self _collectFilesIntoArray: files startingAtFolder: @"/"];
   AUTORELEASE(files);
   return files;
}


/*
 * Get a thumbnail image for a file on the camera. The
 * returned image is autoreleased. 
 * Returns nil if a thumbnail is not available for the
 * specified file.
 */
- (NSImage*) thumbnailForFile: (DigitalCameraFile*)file
{
   CameraFile*      thumbFile;
   NSString*        tempFile;
   NSFileManager*   fileMan = [NSFileManager defaultManager];
   NSImage*         thumbnail = nil;

   NSAssert(file, @"file is nil");

   thumbFile = [self _createGPFile: file ofType: GP_FILE_TYPE_PREVIEW];

   tempFile = [self _temporaryThumbnailFileFor: [file filename]];

   NSLog(@"Saving Thumbnail for %@/%@ to %@", [file folder], [file filename], tempFile);
   CHECK_GP_RV(gp_file_save(thumbFile, [tempFile cString]));

   gp_file_unref(thumbFile);

   NSAssert([fileMan fileExistsAtPath: tempFile], @"file with thumbnail not found");

   // this is a temporary workaround to disable
   // thumbnails on systems that use wraster for
   // jpeg processing. this is not multi-thread-
   // capable.
   thumbnail = [[NSImage alloc] initWithContentsOfFile: tempFile];
   AUTORELEASE(thumbnail);

   if (![fileMan removeFileAtPath: tempFile handler: nil])
   {
      NSLog(@"cannot remove temporary file %@", tempFile);
   }

   return thumbnail;
}


/*
 * Downloads a file from the camera to the speicified
 * destination.
 */
- (void) downloadFile: (DigitalCameraFile*)file to: (NSString*)destination
{
   CameraFile*  camFile;
   
   NSAssert(file, @"file is nil");
   //NSAssert([[NSFileManager defaultManager] isWritableFileAtPath: destination],
   //         @"cannot write to destination");

   camFile = [self _createGPFile: file ofType: GP_FILE_TYPE_NORMAL];

   NSLog(@"Saving file %@/%@ to %@", [file folder], [file filename], destination);
   CHECK_GP(gp_file_save(camFile, [destination cString]));

   gp_file_unref(camFile);
}


/*
 * Deletes a file on the camera.
 */
- (void) deleteFile: (DigitalCameraFile*)file
{
   NSAssert(file, @"file is nil");

   NSLog(@"Deleting file %@/%@", [file folder], [file filename]);
   gp_camera_file_delete([self _gpCamera],
                         [[file folder] cString],
                         [[file filename] cString],
                         [self _gpContext]);
}


/*
 * Detects all available cameras. The returned array
 * is autoreleased. The contained objects are retained
 * only by the array itself. This method returns nil if
 * an error occured.
 */
+ (NSArray*) autodetectCameras
{
   CameraList*          cameras;
   CameraAbilitiesList* abilities;
   Camera*              cam;
   CameraAbilities      camAbilities;
   GPPortInfoList*      portInfos;
   GPPortInfo           portInfo;
   NSMutableArray*      result;
   int                  camCount, i, m;
   const char*          lname;
   const char*          lval;
   DigitalCamera*       aCamera;

   CHECK_GP_RV(gp_list_new(&cameras));

   CHECK_GP_RV(gp_abilities_list_new(&abilities));
   CHECK_GP_RV(gp_abilities_list_load(abilities, GetGPContext()));

   CHECK_PORT_RV(gp_port_info_list_new(&portInfos));
   CHECK_PORT_RV(gp_port_info_list_load(portInfos));
   
   CHECK_GP_RV(gp_abilities_list_detect(abilities, portInfos, cameras, GetGPContext()));

   camCount = gp_list_count(cameras);
   if (camCount > 0)
   {
      result = [[NSMutableArray alloc] initWithCapacity: camCount];
      AUTORELEASE(result);
      for (i = 0; i < camCount; i++)
      {
         CHECK_GP_RV(gp_camera_new(&cam));

         CHECK_GP_RV(gp_list_get_name(cameras, i, &lname));
         CHECK_GP_RV(gp_list_get_value(cameras, i, &lval));

         CHECK_GP_RV((m = gp_abilities_list_lookup_model(abilities, lname)));
         CHECK_GP_RV(gp_abilities_list_get_abilities(abilities, m, &camAbilities));
         //CHECK_GP_RV(gp_camera_set_abilities(cam, camAbilities));

         CHECK_GP_RV((m = gp_port_info_list_lookup_path(portInfos, lval)));
         CHECK_GP_RV(gp_port_info_list_get_info(portInfos, m, &portInfo));
         CHECK_GP_RV(gp_camera_set_port_info(cam, portInfo));
         
         aCamera = [[DigitalCamera alloc] initWithName: [NSString stringWithCString: lname]
                                          atPort: [NSString stringWithCString: lval]
                                          gpCamera: cam
                                          gpContext: GetGPContext()];

         //CHECK_GP_RV(gp_camera_unref(cam));

         AUTORELEASE(aCamera);
         [result addObject: aCamera];
      }
   }
   else
   {
      // TODO: localize this
      NSRunAlertPanel(@"No Camera found!",
                      @"No digital camera could be detected on your system.",
                      @"Confirm", nil, nil);
      result = nil;
   }
   
   CHECK_GP_RV(gp_abilities_list_free(abilities));
   CHECK_GP_RV(gp_port_info_list_free(portInfos));
   CHECK_GP_RV(gp_list_free(cameras));

   return result;
}

@end


@implementation DigitalCamera(Private)

- (void) _collectFilesIntoArray: (NSMutableArray*)array
               startingAtFolder: (NSString*)folder
{
   CameraList*        list;
   int                count, i;
   const char*        lname;
   NSString*          subfolder;
   DigitalCameraFile* aFile;

   NSLog(@"collecting files in folder %@", folder);

   // list all files in start folder
   CHECK_GP(gp_list_new(&list));   
   CHECK_GP(gp_camera_folder_list_files([self _gpCamera],
                                        [folder cString],
                                        list,
                                        [self _gpContext]));

   count = gp_list_count(list);
   for (i = 0; i < count; i++)
   {
      CHECK_GP(gp_list_get_name(list, i, &lname));
      // TODO: create file info object and add to array
      aFile = [[DigitalCameraFile alloc] initWithFilename:
                                            [NSString stringWithCString: lname]
                                         inFolder: folder
                                         onCamera: self];
      [array addObject: aFile];
      AUTORELEASE(aFile);
   }
   CHECK_GP(gp_list_free(list));


   // recurse through subfolders of the start folder
   CHECK_GP(gp_list_new(&list));
   CHECK_GP(gp_camera_folder_list_folders([self _gpCamera],
                                          [folder cString],
                                          list,
                                          [self _gpContext]));
   count = gp_list_count(list);
   for (i = 0; i < count; i++)
   {
      CHECK_GP(gp_list_get_name(list, i, &lname));
      if ([folder isEqualToString: @"/"])
      {
         // first level under root folder
         subfolder = [NSString stringWithFormat: @"/%s", lname];
      }
      else
      {
         subfolder = [NSString stringWithFormat: @"%@/%s", folder, lname];
      }
      [self _collectFilesIntoArray: array startingAtFolder: subfolder];
   }
   CHECK_GP(gp_list_free(list));
}


- (Camera*) _gpCamera
{
   return (Camera*)gpCamera;
}


- (GPContext*) _gpContext
{
   return (GPContext*)gpContext; // TODO
}


- (NSString*) _temporaryThumbnailFileFor: (NSString*)filename
{
   NSFileManager* fileman = [NSFileManager defaultManager];

   NSString* tmpPath =
      [(NSString*)NSTemporaryDirectory() stringByAppendingPathComponent:
                     @"dc_thumbnails"];

   if (![fileman fileExistsAtPath: tmpPath])
   {
      [fileman createDirectoryAtPath: tmpPath attributes: nil];
   }

   NSAssert([fileman fileExistsAtPath: tmpPath],
            @"temporary thumbnail directory not found");

   return [tmpPath stringByAppendingPathComponent: filename];
}


- (CameraFile*) _createGPFile: (DigitalCameraFile*)file
                       ofType: (CameraFileType)fileType
{
   CameraFile* camFile;

   CHECK_GP_RNULL(gp_file_new(&camFile));
   CHECK_GP_RNULL(gp_camera_file_get([self _gpCamera],
                                     [[file folder] cString],
                                     [[file filename] cString],
                                     fileType,
                                     camFile,
                                     [self _gpContext]));
   return camFile;
}

@end


/* ----------------------------------------------------------------------- */

/*
 * A file that exists on a particular Camera.
 */
@implementation DigitalCameraFile

- (id) initWithFilename: (NSString*)_filename
               inFolder: (NSString*)_folder
               onCamera: (DigitalCamera*)camera
{
   if ((self = [super init]))
   {
      filename = [_filename copy];
      folder = [_folder copy];

      // TODO: obtain more detailed information(s)
   }

   return self;
}


- (void) dealloc
{
   [filename release];
   [folder release];
   [super dealloc];
}


- (NSString*) filename
{
   return filename;
}


- (NSString*) folder
{
   return folder;
}

@end
