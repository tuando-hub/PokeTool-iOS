# PokeTool iOS

Native iOS browser automation platform built with UIKit, WKWebView, JavaScriptCore, and MVVM.

## Requirements

- Xcode 16 or newer
- iOS 18.0 or newer
- No third-party dependencies
- No Storyboard
- No SwiftUI

## Phase 1

Phase 1 implements the native Browser Engine foundation: multi-session ownership, lifecycle and state tracking, navigation/history observation, cookie and website-data management, download lifecycle models, session user agents, viewport state, browser events, typed errors, and internal metrics.

No PokeTool business mode is included in this phase.

The Browser Bridge namespace remains empty. The engine intentionally has no JavaScript-facing browser API, runtime evaluation, click, typing, selector, or website automation capability. See [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md).

## Local build

Open `PokeTool.xcodeproj`, select an Apple Development team, then run the `PokeTool` scheme on an iPhone running iOS 18 or newer.

## CI signing secrets

Unsigned IPA generation requires no secrets. For optional signed IPA generation, configure:

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_SIGNING_IDENTITY`
