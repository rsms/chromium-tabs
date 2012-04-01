// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE-chromium file.

#import "CTPageTransition.h"
#import <stdlib.h>

const char* CTPageTransitionCoreString(CTPageTransition type) {
	switch (type & CTPageTransitionCoreMask) {
		case 0: return "link";
		case 1: return "typed";
		case 2: return "auto_bookmark";
		case 3: return "auto_subframe";
		case 4: return "manual_subframe";
		case 5: return "generated";
		case 6: return "start_page";
		case 7: return "form_submit";
		case 8: return "reload";
		case 9: return "keyword";
		case 10: return "keyword_generated";
	}
	return NULL;
}
