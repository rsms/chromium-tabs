// Copyright (c) 2008 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "scoped_nsautorelease_pool.h"
#import <Foundation/Foundation.h>

ScopedNSAutoreleasePool::ScopedNSAutoreleasePool() {
}

ScopedNSAutoreleasePool::~ScopedNSAutoreleasePool() {
}

// Cycle the internal pool, allowing everything there to get cleaned up and
// start anew.
void ScopedNSAutoreleasePool::Recycle() {
}
