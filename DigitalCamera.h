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

#ifndef _H_DIGITAL_CAMERA
#define _H_DIGITAL_CAMERA

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <AppKit/NSImage.h>

@class DigitalCameraFile;

@interface DigitalCamera : NSObject
{
   NSString* name;
   NSString* portName;

   // libgphoto stuff
   void* gpCamera;
   void* gpContext;
}

- (id) initWithName: (NSString*)_name
             atPort: (NSString*)_portName
           gpCamera: (void*)_gpCamera
          gpContext: (void*)_gpContext;
- (void) dealloc;

- (NSString*) name;
- (NSString*) portName;

- (NSArray*) availableFiles;
- (NSImage*) thumbnailForFile: (DigitalCameraFile*)file;
- (void) downloadFile: (DigitalCameraFile*)file to: (NSString*)destination;
- (void) deleteFile: (DigitalCameraFile*)file;

+ (NSArray*) autodetectCameras;

@end



@interface DigitalCameraFile : NSObject
{
   NSString* filename;
   NSString* folder;
}

- (id) initWithFilename: (NSString*)_filename
               inFolder: (NSString*)_folder
               onCamera: (DigitalCamera*)camera;
- (void) dealloc;
- (NSString*) filename;
- (NSString*) folder;

@end

#endif
