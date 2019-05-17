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

#include "CameraController.h"
#include "OpenPanelAddons.h"

#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDictionary.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSButton.h>
#include <AppKit/NSProgressIndicator.h>
#include <AppKit/NSImageView.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSPanel.h>
#include <AppKit/NSOpenPanel.h>
#include <AppKit/NSTextField.h>
#include <AppKit/NSWorkspace.h>


NSString* PREF_DOWNLOAD_BASE_PATH = @"DownloadBasePath";
NSString* PREF_USE_TIMESTAMP_DIR  = @"UseTimestampDirectory";

static NSString* DEFAULT_DOWNLOAD_PATH  =  @"Multimedia/Pictures/Photos";
static NSString* DOWNLOAD_PATH          =  @"DownloadPath";
static NSString* CAMERA                 =  @"Camera";
static NSString* FILES_TO_DOWNLOAD      =  @"FilesToDownload";
static NSString* DELETE_FILES           =  @"DeleteFilesAfterDownload";
static NSString* GOTO_DOWNLOAD_LOCATION =  @"GotoDownloadLocation";

// this is a temporary workaround to disable
// thumbnails on systems that use wraster for
// jpeg processing. this is not multi-thread-
// capable.
static BOOL WithThumbnails;


/*
 * Non-Public methods.
 */
@interface CameraController(Private)
- (void) _downloadFiles: (id)params;
- (NSString*) _downloadBasePath;
- (void) _ensurePathExists: (NSString*)path;
- (NSString*) _getUnusedFilenameBasedOn: (NSString*)filename;
- (NSImage*) _defaultThumbnail;
@end


/*
 * Controls the Camera Application.
 */
@implementation CameraController

/*
 * Designated initializer.
 */
- (id) init
{
   if ((self = [super init]))
   {
      selectedCamera = nil;
      [self setDownloadIsActive: NO];
   }

   return self;
}


- (void) dealloc
{
   [self setSelectedCamera: nil];
   [super dealloc];
}


/*
 * only as long as we need to take care about
 * wraster-based guis
 */
+ (void) initialize
{
   NSUserDefaults* defs = [NSUserDefaults standardUserDefaults];
   NSMutableDictionary* standardDefaults = [NSMutableDictionary dictionary];
   NSString* defaultDestination;

   // use timestamp directory by default
   [standardDefaults setObject: [NSNumber numberWithBool: YES]
                     forKey: PREF_USE_TIMESTAMP_DIR];

   defaultDestination = [NSHomeDirectory() stringByAppendingPathComponent:
                                           DEFAULT_DOWNLOAD_PATH];
   [standardDefaults setObject: defaultDestination forKey: PREF_DOWNLOAD_BASE_PATH];

   [defs registerDefaults: standardDefaults];
   
   // use thumbnails?
   WithThumbnails = [defs boolForKey: @"WithThumbnails"];
}


- (void) awakeFromNib
{
   [self downloadFinished];
   [progressInfoMsg setStringValue: @""];

   // remove thumbnail if thumbnails are disabled
   if (!WithThumbnails)
   {
      float height = [thumbnailView frame].size.height;

      NSRect frame = [window frame];
      frame.size.height -=  height;      
      [thumbnailView removeFromSuperview];
      [window setFrame: frame display: YES];

      [cameraInfo setFrameOrigin: NSMakePoint([cameraInfo frame].origin.x,
                                              [cameraInfo frame].origin.y - height)];

      [cameraIcon setFrameOrigin: NSMakePoint([cameraIcon frame].origin.x,
                                              [cameraIcon frame].origin.y - height)];
   }

   [self detectCamera: nil];
}


/*
 * Tries to detect a connected camera.
 */
- (void) detectCamera: (id)sender
{
   NSArray* cameras;

   cameras = [DigitalCamera autodetectCameras];
   if ([cameras count])
   {
      // use the first detected camera
      [self setSelectedCamera: [cameras objectAtIndex: 0]];
   }
   else
   {
      [self setSelectedCamera: nil];
   }
}


/*
 * Set the selected camera.
 */
- (void) setSelectedCamera: (DigitalCamera*)aCamera
{
   RELEASE(selectedCamera);
   selectedCamera = aCamera;
   RETAIN(selectedCamera);
   
   if (selectedCamera)
   {
      [cameraInfo setStringValue: [aCamera name]];
      NSLog(@"using camera %@ at port %@", [aCamera name], [aCamera portName]);
   }
   else
   {
      [cameraInfo setStringValue: @"no camera"];
   }
}


/*
 * Get the selected camera.
 */
- (DigitalCamera*) selectedCamera
{
   return selectedCamera;
}


/*
 * Set a status that indicates whether a download
 * is active at the moment.
 */
- (void) setDownloadIsActive: (BOOL)active
{
   downloadIsActive = active;
}


/*
 * Returns YES if a download is currently active.
 */
- (BOOL) downloadIsActive
{
   return downloadIsActive;
}


/*
 * Start downloading the files from the selected
 * Camera.
 */
- (void) initiateDownloadFiles: (id)sender
{
   NSMutableDictionary* threadParams;
   NSString*            downloadPath;
   BOOL                 deleteFiles;
   NSArray*             files;

   if (![self selectedCamera])
   {
      // TODO: localize this
      NSRunAlertPanel(@"Error while downloading files!",
                      @"No camera was found on your system.",
                      @"Confirm", nil, nil);
      return;
   }

   // initiate download parameters
   downloadPath = [self _downloadBasePath];
   [self _ensurePathExists: downloadPath];
   
   deleteFiles = ([deleteFilesAfterDownload state] == NSOnState);
   // TODO: save in user prefs

   files = [[self selectedCamera] availableFiles];
   if ([files count] == 0)
   {
      // TODO: localize this
      NSRunAlertPanel(@"Nothing to download!",
                      @"There are no files on this camera.",
                      @"Confirm", nil, nil);
      return;
   }


   // adjust progressbar min/max
   [progressBar setMinValue: 0];
   if (!deleteFiles)
   {
      [progressBar setMaxValue: [files count]];
   }
   else
   {
      // add 1/4 for deleting
      [progressBar setMaxValue: ([files count] + ([files count] * 0.25))];
   }


   // detach a thread that downloads the files
   threadParams = [[NSMutableDictionary alloc] initWithCapacity: 0];
   [threadParams setObject: downloadPath forKey: DOWNLOAD_PATH];
   [threadParams setObject: [self selectedCamera] forKey: CAMERA];
   [threadParams setObject: files forKey: FILES_TO_DOWNLOAD];
   [threadParams setObject: [NSNumber numberWithBool: deleteFiles] forKey: DELETE_FILES];
   [threadParams setObject: [NSNumber numberWithBool: YES] forKey: GOTO_DOWNLOAD_LOCATION];

   [self setDownloadIsActive: YES];
   [NSThread detachNewThreadSelector: @selector(_downloadFiles:)
             toTarget: self
             withObject: threadParams];


   // the user can now abort the download
   [transferButton setTitle: @"Abort"];
}


/*
 * Abort the currently running download. If no
 * download is active, nothing happens.
 */
- (void) abortDownloadFiles: (id)sender
{
   [transferButton setEnabled: NO];
   // will be re-enabled by downloadFinished
   [self setDownloadIsActive: NO];
}


/*
 * If no download is active, this method will intiate one.
 * Otherwise, the active download will be aborted.
 */
- (void) initiateOrAbortDownload: (id)sender
{
   if (![self downloadIsActive])
   {
      [self initiateDownloadFiles: sender];
   }
   else
   {
      [self abortDownloadFiles: sender];
   }
}


/*
 * Let the User select the destination directory
 * where the downloaded files should go into.
 */
- (void) setDestination: (id)sender
{
   NSUserDefaults*  defs = [NSUserDefaults standardUserDefaults];
   id               panel;
   id               accessoryView;
   int              answer;

   panel = [NSOpenPanel openPanel];
   [panel setCanChooseDirectories: YES];
   [panel setCanChooseFiles: NO];
   [panel setAllowsMultipleSelection: NO];
   [panel setTitle: @"Set download Destination"];

   accessoryView = [OpenPanelAccessoryView accessoryView];
   [accessoryView setUseTimestampeDirectory: [defs boolForKey: PREF_USE_TIMESTAMP_DIR]];
   [panel setAccessoryView: accessoryView];
   
   answer = [panel runModalForDirectory:  [defs stringForKey: PREF_DOWNLOAD_BASE_PATH] 
                   file: nil
                   types: nil];

   if (answer == NSOKButton)
   {
      [defs setObject: [[panel filenames] objectAtIndex: 0]
            forKey: PREF_DOWNLOAD_BASE_PATH];
      [defs setObject: [NSNumber numberWithBool: [accessoryView useTimestampDirectory]]
            forKey: PREF_USE_TIMESTAMP_DIR];
   }
}


/*
 * Update the progress information about the
 * current download. Thumbnail may be nil
 * of not available for downloaded file.
 */
- (void) willDownloadFile: (DigitalCameraFile*)file
                       at: (int)index
                       of: (int)total
                thumbnail: (NSImage*)thumbnail
{
   NSString* msg;

   msg = [NSString stringWithFormat: @"download %@ (%d of %d) ....",
                   [file filename], index, total];
   
   [progressInfoMsg setStringValue: msg];
   NSLog(msg);

   if (thumbnail)
   {
      [thumbnailView setImage: thumbnail];
   }

   [progressBar setDoubleValue: index];
}


/*
 * Inform the controller the a file file will
 * be deleted from the camera.
 */
- (void) willDeleteFile: (DigitalCameraFile*)file
                     at: (int)index
                     of: (int)total
{
   NSString* msg;
   
   msg = [NSString stringWithFormat: @"delete file %@ (%d of %d) ....",
                   [file filename], index, total];
   
   [progressInfoMsg setStringValue: msg];
   NSLog(msg);

   [progressBar setDoubleValue: (total + (index * 0.25))];
}


/*
 * Invoked when the download has finished.
 */
- (void) downloadFinished;
{
   NSLog(@"download finished");
   [self setDownloadIsActive: NO];

   // TODO: reset all UI elements
   [progressInfoMsg setStringValue: @"download complete"];
   [progressBar setDoubleValue: 0.0];
   [transferButton setTitle: @"Download Files"];
   [transferButton setEnabled: YES];
}


@end



@implementation CameraController(Private)

/*
 * Download all files from the camera. This method
 * is intended to be used in a separate thread. The
 * controller is notified about the progress.
 */
- (void) _downloadFiles: (id)params
{
   NSString*           downloadPath = [params objectForKey: DOWNLOAD_PATH];
   DigitalCamera*      camera = [params objectForKey: CAMERA];
   NSArray*            files  = [params objectForKey: FILES_TO_DOWNLOAD];
   BOOL                deleteFiles  = [[params objectForKey: DELETE_FILES] boolValue];
   BOOL                gotoDownloadLocation = [[params objectForKey: GOTO_DOWNLOAD_LOCATION]
                                                 boolValue];
   NSEnumerator*       e;
   DigitalCameraFile*  aFile;
   NSImage*            aThumbnail = nil;
   int                 counter;
   NSString*           targetFile;
   NSAutoreleasePool*  autoreleasePool;
   BOOL                aborted;

   autoreleasePool = [[NSAutoreleasePool alloc] init];

   NSAssert(downloadPath, @"no download path");
   NSAssert(camera, @"no camera");
   NSAssert(files, @"no files");

   // download the files
   counter = 0;
   e = [files objectEnumerator];
   while ((aFile = [e nextObject]) && [self downloadIsActive])
   {
      counter++;

      if (WithThumbnails)
      {
         aThumbnail = [camera thumbnailForFile: aFile];
         if (!aThumbnail)
         {
            aThumbnail = [self _defaultThumbnail];
         }
      }

      [self willDownloadFile: aFile
            at: counter
            of: [files count] 
            thumbnail: aThumbnail];
      
      targetFile = [downloadPath stringByAppendingPathComponent: [aFile filename]];
      targetFile = [self _getUnusedFilenameBasedOn: targetFile];

      [camera downloadFile: aFile to: targetFile];
   }


   // delete files if requested
   if (deleteFiles)
   {
      counter = 0;
      e = [files objectEnumerator];
      while ((aFile = [e nextObject]) && [self downloadIsActive])
      {
         counter++;

         [self willDeleteFile: aFile
               at: counter
               of: [files count]];

         [camera deleteFile: aFile];
      }
   }

   aborted = ![self downloadIsActive];
   [self downloadFinished];
   
   // open the download location in workspace (if not aborted)
   if (!aborted && gotoDownloadLocation)
   {
      [[NSWorkspace sharedWorkspace] noteFileSystemChanged];
      [[NSWorkspace sharedWorkspace] selectFile: downloadPath
                                     inFileViewerRootedAtPath:
                                        [downloadPath stringByDeletingLastPathComponent]];      
   }

   RELEASE(autoreleasePool);
}


/*
 * Returns a default image that can be used instead
 * of a thumbnail.
 */
- (NSImage*) _defaultThumbnail
{
   static NSImage* DefaultThumbnail = nil;
   if (!DefaultThumbnail)
   {
      NSLog(@"loading default thumbnail");
      DefaultThumbnail = [NSImage imageNamed: @"no_thumbnail.jpg"];
      [DefaultThumbnail setScalesWhenResized: NO];
      RETAIN(DefaultThumbnail);
   }

   return DefaultThumbnail;
}


/*
 * Returns the base path to where images should
 * be downloaded.
 */
- (NSString*) _downloadBasePath
{
   NSUserDefaults*  defs = [NSUserDefaults standardUserDefaults];
   NSString*        basePath;
   BOOL             useTimestampDir;
   NSCalendarDate*  now;
   NSString*        timestampDir;

   basePath = [defs stringForKey: PREF_DOWNLOAD_BASE_PATH];

   useTimestampDir = [defs boolForKey: PREF_USE_TIMESTAMP_DIR];
   if (useTimestampDir)
   {
      now = [NSCalendarDate calendarDate];
      timestampDir = [NSString stringWithFormat: @"%4d%2d%2d",
                               [now yearOfCommonEra],
                               [now monthOfYear],
                               [now dayOfMonth]];

      basePath = [basePath stringByAppendingPathComponent: timestampDir];
      basePath = [self _getUnusedFilenameBasedOn: basePath];
   }

   return basePath;
}


/*
 * Ensures that a directory exists. If necessary, the
 * complete path will be created (like mkdir -p).
 */
- (void) _ensurePathExists: (NSString*)path
{
   NSEnumerator*   e;
   NSString*       currentPath = @"";
   NSString*       aPathComp;
   NSFileManager*  fileman = [NSFileManager defaultManager];
   BOOL            success;

   e = [[path pathComponents] objectEnumerator];
   while ((aPathComp = [e nextObject]))
   {
      currentPath = [currentPath stringByAppendingPathComponent: aPathComp];

      if (![fileman fileExistsAtPath: currentPath])
      {
         NSLog(@"directory %@ does not exist, create it", currentPath);
         success = [fileman createDirectoryAtPath: currentPath
                            attributes: nil];
         
         NSAssert(success, [@"Failed to create directory: "
                                stringByAppendingString: currentPath]);
      }
      else
      {
         NSLog(@"directory %@ exists, good", currentPath);
      }
   }
}


/*
 * ....
 */
- (NSString*) _getUnusedFilenameBasedOn: (NSString*)filename
{
   NSString*      basename;
   NSString*      basedir;
   NSString*      extension;
   NSString*      result;
   NSString*      indexedBasename;
   int            indexCounter = 1;
   NSFileManager* fileman = [NSFileManager defaultManager];

   if (![fileman fileExistsAtPath: filename])
   {
      return filename;
   }

   basedir = [filename stringByDeletingLastPathComponent];
   basename = [[filename lastPathComponent] stringByDeletingPathExtension];
   extension = [filename pathExtension];

   do
   {
      indexedBasename = [NSString stringWithFormat: @"%@_%d", basename, indexCounter++];
      result = [basedir stringByAppendingPathComponent: indexedBasename];
      if ([extension length])
      {
         result = [result stringByAppendingPathExtension: extension];
      }
   } while ([fileman fileExistsAtPath: result]);

   return result;
}

@end
