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

#ifndef _H_CAMERA_CONTROLLER
#define _H_CAMERA_CONTROLLER

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSLock.h>
#include <AppKit/NSImage.h>

#include "DigitalCamera.h"

extern NSString* PREF_DOWNLOAD_BASE_PATH;
extern NSString* PREF_USE_TIMESTAMP_DIR;


@interface CameraController : NSObject
{
   DigitalCamera*    selectedCamera;
   BOOL              downloadIsActive;
   
   // Outlets
   id  deleteFilesAfterDownload;
   id  progressInfoMsg;
   id  progressBar;
   id  thumbnailView;
   id  transferButton;
   id  cameraInfo;
   id  cameraIcon;
   id  window;
}

- (id) init;
- (void) dealloc;

- (void) awakeFromNib;

- (void) setSelectedCamera: (DigitalCamera*)aCamera;
- (DigitalCamera*) selectedCamera;
- (void) setDownloadIsActive: (BOOL)active;
- (BOOL) downloadIsActive;

// Notifications
- (void) willDownloadFile: (DigitalCameraFile*)file
                       at: (int)index
                       of: (int)total
                thumbnail: (NSImage*)thumbnail;

- (void) willDeleteFile: (DigitalCameraFile*)file
                     at: (int)index
                     of: (int)total;

- (void) downloadFinished;


// Actions
- (void) detectCamera: (id)sender;
- (void) initiateDownloadFiles: (id)sender;
- (void) abortDownloadFiles: (id)sender;
- (void) initiateOrAbortDownload: (id)sender;
- (void) setDestination: (id)sender;

@end

#endif
