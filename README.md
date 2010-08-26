# Chromium Tabs

Chromium Tabs is a [Cocoa](http://developer.apple.com/cocoa/) framework for building applications that works like [Chromium](http://www.google.com/chrome)s window system.

- An *application* has multiple *windows*
- Each *window* represents a unit of *tabs*
- Each *tab* represents a stateful view
- Each *tab* can be freely dragged between *windows*

> **Important:** This is currently work in progress and the framework API will change often.

Requirements: OS X 10.5 or later.

## Usage

The framework is distributed with an [`@rpath`](http://www.codeshorts.ca/2007/nov/01/leopard-linking-making-relocatable-libraries-movin) which means it should be embedded into your applications' Contents/Frameworks directory. In Xcode you can add a new "Copy Files" action with the "Frameworks" destination to your target.

Then you need to do at least two things:

1. `#import <ChromiumTabs/ChromiumTabs.h>`
2. `[Browser openEmptyWindow]` when your application has started (e.g. in the application delegates' `applicationDidFinishLaunching:`)

The example application (in `examples/simple-app/`) illustrates basic usage and likes to be inspected while you drink coffee.

## Building

1. Check out (or download) a version of the source code
2. Open `chromium-tabs.xcodeproj` in [Xcode](http://developer.apple.com/tools/xcode/)
3. Build the "ChromiumTabs" framework

There is also an optional example application in the Xcode project. You build it by selecting the "Chromium Tabs" target.

## License

See the LICENSE file for details.
