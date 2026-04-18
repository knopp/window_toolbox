// Copyright (c) 2021 Microsoft, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#pragma once

#import <Cocoa/Cocoa.h>

// Manipulating the window buttons.
@interface WindowButtonsProxy : NSObject

- (id)initWithWindow:(NSWindow *)window;

// Set left-top margin of the window buttons..
- (void)setMargin:(const NSPoint *)margin;

// Return the bounds of all 3 buttons, with margin on all sides.
- (NSRect)getButtonsBounds;

// Update the button layout. This needs to be called every time the
// container view relayouts.
- (void)performLayout;
@end
