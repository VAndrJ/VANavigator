# VANavigator audit — 2026-10-21

Audited the library, example, shared scheme, test plan, and README at `fc46e71`, followed by the configuration and
documentation corrections recorded below. Validation used Xcode 27.1, Swift 6.4, and the iOS 27.1 SDK.

## Result

No functional library defect was confirmed in the reviewed and exercised navigation paths. The existing iOS 27.1
arrangement integration agrees with the current SDK and Apple guidance; no additional navigation API was required.
One test-configuration issue was corrected: coverage was enabled but the original report contained zero targets and
zero executable lines. Successful tests alone therefore did not provide a usable coverage measurement.

## Corrections

- Changed the shared test plan and scheme to collect coverage for all built targets. The final Duo run now reports
  the `VANavigator` library separately: **3,735 of 3,943 executable lines covered (94.72%)**. Arrangement integration
  covers **68 of 71 executable lines (95.77%)**. These are library measurements, excluding test and example code.
- Corrected the arrangement integration comment: the Catalyst exclusion works around Xcode 27.1 compilation issue
  **185924957**. It does not mean Apple declares the API permanently unavailable on Catalyst.
- Documented Duo's multiple simulator displays and the need to direct screenshots and input to the active display.
  Also clarified which coverage target to inspect.

Library runtime behavior and public API signatures were unchanged by this audit.

## Automated validation

| Validation | Result |
| --- | --- |
| iPhone Duo, iOS 27.1, final Xcode MCP test run | 277 case executions passed; no failures, skips, or unrun tests |
| iPhone 16, iOS 18.4 | 264 case executions passed; no failures; five iOS 27.1-only test definitions skipped |
| iPad (A16), iOS 26.5 | 264 case executions passed; no failures; five iOS 27.1-only test definitions skipped |
| Clean Release library build for generic iOS device | Passed with `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` and signing disabled |
| Test-plan JSON, scheme XML, and diff whitespace validation | Passed |

Parameterized tests contribute multiple case executions. Xcode's top-level test-definition counts differ from those
execution counts; the older runtimes each report 220 passed definitions and five unavailable definitions skipped.

The source review and regression suite cover:

- Window-root replacement, transition validation, and initial window visibility.
- Presentation sources, popover anchoring, incompatible controller hierarchies, and failure diagnostics.
- Push, pop, stack-root replacement, stack removal, and closing the top controller.
- Identity and instance lookup through navigation, tabs, custom containers, classic splits, and collapsed columns.
- Revealing nested stacks and tabs before responder events, including transition rejection and queued continuation.
- Arrangement stacking order, retained hidden content, hidden-destination rejection, resizing, and navigation around
  or inside arrangements.
- Navigation queue ordering, awaited responder events, fallback chains, interception resolution, and cancellation.

## Example verification on Duo

The example built and launched. Device Hub controlled the active display after the Xcode interaction tool initially
captured an inactive display and delivered ineffective taps there.

Verified details navigation through `1 → 2 → 3`, return to `2`, and closing to existing Main. Tab presentation and
popover flows opened and dismissed their expected content.

Both presented and window-root arrangements retained primary and secondary draft text across closed, open, and
partially open poses, and through detail push/return. Overlay and axis toggles worked. Done dismissed the presented
arrangement; Main replaced the window-root arrangement successfully. The root arrangement also survived portrait
rotation. The smaller panel during editing reflected the example's intentional 20%/80% sizing policy.

Automation sessions expired after inactivity while interacting through Device Hub. Keeping the session active
resolved the apparent Home-screen exits; no app crash was confirmed. Queue and authorization flows were covered by
automated tests, rather than this interactive pass.

## Apple documentation and SDK review

Used Xcode MCP DocumentationSearch, web search, Apple's current Markdown documentation, and installed UIKit headers.
The semantic documentation index did not return the new arrangement symbols, so current documentation and headers
provided the API verification.

- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo):
  the example already uses scene-local windows, container-relative Auto Layout, independent safe-area edges,
  keyboard layout guides, standard bars, and titled/symbol-based toolbar items. No production shared-screen sizing,
  orientation-based layout branches, device-idiom layout decisions, or cached safe-area assumptions were found.
- [UIArrangementViewController](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller):
  integration uses runtime availability, primary/secondary placements, view state, and retained content. The README
  already distinguishes lookup support from recommended container composition and warns about nesting arrangements
  with split/tab/scroll containers. Layout policy remains with the application.
- [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes):
  confirmed Swift 6.4, the iOS 27.1 SDK, and the Catalyst conditional-compilation workaround.

## Verification limits

This audit establishes passing behavior for the tested scenarios, rather than every possible UIKit hierarchy.
Physical hardware, every pose/orientation combination, larger accessibility text sizes, and exhaustive interactive
back/dismiss cancellation were not verified. The iOS 15 deployment target compiled, but iOS 15 runtime behavior and
building with an older Swift 6.2 SDK/toolchain were not exercised. Hosted CI was not run locally.

The older-runtime console included UIKit snapshot/appearance-transition warnings in synthetic nested-container
tests, despite passing assertions. Duo example logs also included system bar-constraint diagnostics during layout
changes. No persistent visual defect or functional failure was established from those messages. Coverage is below
100%, and does not prove correctness of unexecuted paths.
