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

#include "AppDelegate.h"

/*
 * Non-Public methods.
 */
@interface AppDelegate(Private)
@end


/*
 * Camera's delegate.
 */
@implementation AppDelegate

- (id) init
{
   if ((self = [super init]))
   {
      // ...
   }
   return self;
}


- (void) dealloc
{
   [super dealloc];
}


- (void) applicationDidFinishLaunching: (NSNotification*) notification
{
   [[NSApplication sharedApplication] setServicesProvider: self];
   NSLog(@"Service provider registered");
}


/*
 * A service that downloads all files from the camera
 * to a directory.
 */
- (void) downloadFilesToPlace: (NSPasteboard*)pboard
                     userData: (NSString*)userData
                        error: (NSString**)error
{
   NSString* directory;

   NSLog(@"Service downloadFilesToPlace invoked");

   directory = [pboard stringForType: NSFilenamesPboardType];
   if (!directory)
   {
      *error = @"No directory selected.";
      return;
   }

   NSLog(@"downloading files to %@", directory);
}

@end
