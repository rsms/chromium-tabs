# Chromium Tabs

Chromium Tabs is a [Cocoa](http://developer.apple.com/cocoa/) framework for building applications that works like [Chromium](http://www.chromium.org/)'s window system.

- An *application* has multiple *windows*
- Each *window* represents a unit of *tabs*
- Each *tab* represents a stateful view
- Each *tab* can be freely dragged between *windows*

> **Important:** This is currently work in progress and the framework API will change often.

Requirements: OS X 10.5 or later.

## Usage

The framework is distributed with an [`@rpath`](http://www.codeshorts.ca/2007/nov/01/leopard-linking-making-relocatable-libraries-movin) which means it should be embedded into your applications' Contents/Frameworks directory. In Xcode you can add a new "Copy Files" action with the "Frameworks" destination to your target.

As an alternative, with Xcode4, you can create a new workspace which includes your project and `chromium-tabs.xcodeproj`. Once this is done, `ChromiumTabs.framework` will be available for linking like any other built-in library.

Then you need to do at least two things:

1. `#import <ChromiumTabs/ChromiumTabs.h>`
2. `[[CTBrowser browser] newWindow]` when your application has started (e.g. in the application delegates' `applicationDidFinishLaunching:`)

The example application (in `examples/simple-app/`) illustrates basic usage and likes to be inspected while you drink coffee. It looks like this:

[<img src="http://farm5.static.flickr.com/4082/4927836567_7b9f577af4_o.png" alt="A slightly boring screenshot of the example application">](http://github.com/downloads/rsms/chromium-tabs/Chromium%20Tabs.app.zip)

When building a "real" application you will need to sublcass at least the `CTBrowser` class which factorises tabs and their content. The example application do this at a very basic level (provides custom tab content).

## Download

Visit the [download section on GitHub](http://github.com/rsms/chromium-tabs/downloads) to download the latest release of the framework and the example application.

## Building

1. Check out (or download) the source code
2. Open `chromium-tabs.xcodeproj` in [Xcode](http://developer.apple.com/tools/xcode/)
3. Choose your target and hit "Build"

There is also an optional example application in the Xcode project. You build it by selecting the "Chromium Tabs" target.

## License

See the LICENSE file for details.
