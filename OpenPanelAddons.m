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

#include "OpenPanelAddons.h"

/*
 * Accessory view for an open panel to let the user
 * select whether the downloaded files should be
 * placed in a timestamped directory.
 */
@implementation OpenPanelAccessoryView

- (id) init
{
   if ((self = [super initWithFrame: NSMakeRect(0, 0, 0, 0)]))
   {
      useTimestampDirectory = [[NSButton alloc] initWithFrame: [self frame]];
      [useTimestampDirectory setTitle: @"place files in timestamped directory"];
      [useTimestampDirectory setButtonType: NSSwitchButton];

      [self addSubview: AUTORELEASE(useTimestampDirectory)];
      [useTimestampDirectory sizeToFit];
      [self setFrame: [useTimestampDirectory frame]];
   }
   return self;
}


/*
 * Factory method for convinience. The width of the accessory
 * view is adjusted to the width of the specified panel.
 */
+ (OpenPanelAccessoryView*) accessoryView
{
   id view = [[OpenPanelAccessoryView alloc] init];
   return AUTORELEASE(view);
}


- (void) setUseTimestampeDirectory: (BOOL)use
{
   [useTimestampDirectory setState: (use ? NSOnState : NSOffState)];
}


- (BOOL) useTimestampDirectory
{
   return ([useTimestampDirectory state] == NSOnState);
}

@end
