// Copyright (c) 2021 Microsoft, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#pragma once

#import <Cocoa/Cocoa.h>

@interface CWWindowButtonsProxyInactiveConfiguration : NSObject

@property(readwrite, nonatomic) NSColor *backgroundColor;
@property(readwrite, nonatomic) NSColor *borderColor;
@property(readwrite, nonatomic) CGFloat borderWidth;
@property(readwrite, nonatomic) BOOL showAsInactiveInKeyWindow;

@end

// Manipulating the window buttons.
@interface CWWindowButtonsProxy : NSObject

- (id)initWithContainer:(NSView *)container;

- (void)setInactiveConfiguration:
    (CWWindowButtonsProxyInactiveConfiguration *)configuration;

- (void)setButttonAppearance:(NSAppearance *)appearance;

// Set left-top margin of the window buttons..
- (void)setMargin:(const NSPoint *)margin;

// Return the bounds of all 3 buttons, with margin on all sides.
- (NSRect)getButtonsBounds;

// Update the button layout. This needs to be called every time the
// container view relayouts.
- (void)performLayout;
@end
