# PokeTool iOS

Native iOS browser automation platform built with UIKit, WKWebView, JavaScriptCore, and MVVM.

## Requirements

- Xcode 16 or newer
- iOS 18.0 or newer
- No third-party dependencies
- No Storyboard
- No SwiftUI

## Phase 0

Phase 0 provides the native application shell, dependency container, programmatic UIKit navigation, MVVM boundaries, a WKWebView browser host, a JavaScriptCore runtime, a typed native bridge, file/network/keychain/background/notification services, and GitHub Actions IPA packaging.

No PokeTool business mode is included in this phase.

## Local build

Open `PokeTool.xcodeproj`, select an Apple Development team, then run the `PokeTool` scheme on an iPhone running iOS 18 or newer.

## CI signing secrets

Unsigned IPA generation requires no secrets. For optional signed IPA generation, configure:

- `IOS_CERTIFICATE_P12_BASE64`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `IOS_SIGNING_IDENTITY`

