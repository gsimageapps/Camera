/*
 * Copyright (C) 2004  Stefan Kleine Stegemann
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

#ifndef _H_APPDELEGATE
#define _H_APPDELEGATE

#include <Foundation/NSObject.h>
#include <Foundation/NSNotification.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSPasteboard.h>


@interface AppDelegate : NSObject
{
}

- (id) init;
- (void) dealloc;

- (void) applicationDidFinishLaunching: (NSNotification*) notification;

// Services
- (void) downloadFilesToPlace: (NSPasteboard*) pboard
                     userData: (NSString*) userData
                        error: (NSString**) error;

@end

#endif
