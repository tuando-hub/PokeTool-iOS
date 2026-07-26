# PokeTool iOS

Native iOS browser automation platform built with UIKit, WKWebView, JavaScriptCore, and MVVM.

## Requirements

- Xcode 16 or newer
- iOS 18.0 or newer
- No third-party dependencies
- No Storyboard
- No SwiftUI

## Phase 0.5

Phase 0.5 refines the platform boundaries with BrowserManager/BrowserPool/BrowserSession ownership, namespaced Native Bridge objects, a shared EventBus, unified logging, explicit dependency lifecycles, and plugin-facing interfaces.

No PokeTool business mode is included in this phase.

The browser layer intentionally has no load, evaluate, click, selector, or automation API yet. See [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md).

## Local build

Open `PokeTool.xcodeproj`, select an Apple Development team, then run the `PokeTool` scheme on an iPhone running iOS 18 or newer.

## CI signing secrets

Unsigned IPA generation requires no secrets. For optional signed IPA generation, configure:

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_SIGNING_IDENTITY`
