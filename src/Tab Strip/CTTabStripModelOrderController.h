//
//  CTTabStripModelOrderController.h
//  chromium-tabs
//
// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.
//

#import <Foundation/Foundation.h>
#import "CTTabStripModel.h"

@class CTTabContents;
///////////////////////////////////////////////////////////////////////////////
// CTTabStripModelOrderController
//
//  An object that allows different types of ordering and reselection to be
//  heuristics plugged into a TabStripModel.
//
@interface CTTabStripModelOrderController : NSObject

// The insertion policy. Default is INSERT_AFTER.
@property (readwrite, assign) InsertionPolicy insertionPolicy;

- (id)initWithTabStripModel:(CTTabStripModel *)tabStripModel;

// Determine where to place a newly opened tab by using the supplied
// transition and foreground flag to figure out how it was opened.
- (int)determineInsertionIndexWithContents:(CTTabContents *)newContents
								transition:(CTPageTransition)transition
							  inForeground:(BOOL)foreground;

// Returns the index to append tabs at.
- (int)determineInsertionIndexForAppending;

// Determine where to shift selection after a tab is closed.
- (int)determineNewSelectedIndexAfterClose:(int)removedIndex;

@end
