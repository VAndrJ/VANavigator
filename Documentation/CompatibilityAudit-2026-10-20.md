VANavigator review — 20 October 2026

Reviewed revision: `adab15f` on `develop`. The original assessment and verification below record the state on 20 October. Implementation and example updates made on 21 October are recorded in the follow-up at the end.

VANavigator is a UIKit navigation coordinator for iOS 15 and later. It assembles screens through a factory, locates controllers by instance or identity, applies stack/modal/window/split strategies, serializes navigation, delivers responder events, and suspends/resumes flows through an interceptor. It is useful for reusable routing, deep links, authentication gates, and returning to existing screens. Layout, scene ownership, accessibility, and application state remain responsibilities of the integrating app. The package itself has no third-party dependencies; the example does.

The existing implementation has substantial defensive handling: main-actor isolation, hierarchy validation, transition rejection, typed diagnostics, fallback handling, awaited event delivery, interception cancellation, and queue retention. No failure was observed in the existing runnable tests. That does not establish flawless behavior across all supported operating systems or the new Duo poses.

| Verification | Result |
| --- | --- |
| Xcode MCP test run: iPhone 18 Pro, iOS 27.0, iOS 27.1 SDK | 237 passed, 0 failed, 3 skipped, 2 not run; 242 result entries |
| Xcode MCP test run: iPad (A16), iOS 26.5, iOS 27.1 SDK | 237 passed, 0 failed, 3 skipped, 2 not run; 242 result entries |
| Xcode test build diagnostics | Build succeeded; no compiler warnings reported by MCP |
| Standalone package Release build, arm64 iOS 15 minimum, iOS 27.1 SDK, warnings as errors | Passed |
| Exact standalone Release command from CI, run locally with Xcode 27.1 | Passed with normal Xcode access |
| Exact standalone Release command on a clean temporary package copy | Passed without cached `.swiftpm` or `.build` state |
| Example Release build with normal project settings | Passed; one App Intents metadata-extraction warning because the example has no AppIntents dependency |
| Duo/iOS 27.1 execution | Unavailable: the runtime is not installed as an available simulator |
| Code coverage percentage | Unavailable: `xccov` could not load the coverage archive's missing `Metadata.plist` |

Both test runs explicitly skipped the three arrangement test definitions because they require iOS 27.1. The two additional “not run” entries are the parameterized arrangement method entries reported by Xcode. They are not passing tests. No physical-device pose testing, minimum-version iOS 15/16 runtime testing, or Swift 6.2 toolchain run was performed. The local Xcode 27.1 compiler is Swift 6.4.

Changes warranted by the review, in priority order:

1. **Execute the arrangement tests in CI.** Every current CI test lane uses an SDK/runtime older than 27.1 (`.github/workflows/swift.yml:17`). The compile guard excludes arrangement tests entirely with those older SDKs. Add a lane with Xcode 27.1 or later and the iPhone Duo 27.1 runtime when the runner actually provides them; retain older compatibility lanes. Require that lane to execute arrangement tests rather than accepting an all-skipped result. Locally, the SDK compiles the integration, but neither simulator test run executes it.

2. **Enable the example to verify landscape on iPhone.** `Example/VANavigator/Info.plist:48` permits portrait only for iPhone, while the README asks for Duo testing in both orientations. Add the desired landscape orientations to the example and verify its screens after rotation. Orientation support is app configuration; this does not require changing the framework's deployment target. Apple recommends checking every supported pose and orientation in its [Duo preparation guide](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo).

3. **Check split-pop visibility consistently before reporting success.** This is a source-level finding awaiting iOS 27.1 reproduction. In `VANavigator/Classes/Navigator+SplitStrategy.swift:149`, `.split(... .pop)` finds a destination recursively, including retained arrangement children. After the enclosing stack is popped, line 170 completes successfully without the arrangement visibility validation used by ordinary `.popToExisting` and `.closeToExisting` in `Navigator+ExistingStrategies.swift:75`. If a split column's navigation stack contains an arrangement with a retained hidden target, this path can deliver a successful pop event while that placement remains hidden. Add an iOS 27.1 regression for that hierarchy and either apply the same visibility check or explicitly define/reject that container combination. Keep navigation containers outside arrangement content, and avoid container nesting that makes arrangement content inaccessible.

Further verification and documentation additions would improve confidence:

- Add tests that start and cancel real interactive back and modal-dismiss transitions, then verify completion, fallback, and the next queued operation. Existing tests cover externally held transitions and rejected coordinator registration, but do not exercise actual interactive cancellation.
- Extend arrangement tests to pop to hidden content without a fallback, nested arrangements, and presentation/popover anchors during size or pose changes. The current resize test changes frames and traits; it does not reproduce hardware reserved regions or display handoff.
- Make the example's scroll helper respond to the keyboard. `Example/VANavigator/Extensions/UIView+Support.swift:29` pins the viewport to safe areas and has no keyboard layout guide or keyboard-inset handling. Verify text entry in short windows and partially folded layouts, particularly with large text. This is an example-layout concern, not navigation-core behavior.
- Add a published verification matrix distinguishing deployment support, SDK compilation, tested runtimes, and manual pose checks. State clearly that iOS 15 is the package minimum, while the example/test host currently targets iOS 17.
- Supplement the README with the current SDK-specific behavior, the relevant Xcode known issues, and the container-placement caveat. Its existing scene lifecycle, retained-hidden-content, and standard-bar guidance is already useful and largely current.

The Duo work already present is appropriate: `UIArrangementViewController` availability checks, primary/secondary traversal using visibility and z-order, retained-content lookup, navigation outside the arrangement in the example, and scene-owned windows. The local SDK's header and Swift interface confirm the used `ViewPlacement`, `ViewState`, `state(for:)`, and controller-management APIs. Apple describes arrangement as a layout container that adapts to size and hardware context; no new device-model routing branch is warranted. See [UIArrangementViewController](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller) and [UIKit updates](https://developer.apple.com/documentation/updates/uikit).

Apple's [Duo design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) emphasizes continuous state, flexible layouts, standard vertical controls, and reserved regions. Those concerns mostly belong in the host app. The framework should continue operating on its supplied window and controller hierarchy. Camera accessories and other-display presentation do not need to become generic Navigator features merely because Duo supports them.

The final [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes), read directly from Apple's documentation JSON, still list Mac Catalyst errors for iOS 27.1-specific APIs and recommend compile-time exclusion. The existing Catalyst guard matches that guidance. The notes also list slow first simulator launch, unavailable StandBy and most extension debugging in the Duo runtime, and a simulator-only ability for camera accessories to use both displays without active capture. None requires changing the navigation core. Simulator behavior should not be used as proof of unrestricted physical-device display access.

The Xcode MCP documentation search was used for UIKit and scene lifecycle guidance. The Duo preparation article and final Xcode notes were additionally read from Apple's documentation JSON because normal web opens returned JavaScript placeholders. Public web search and Apple's [Duo readiness guidance](https://developer.apple.com/iphone-duo/prepare/) supplied further primary-source checks. No separate readable iOS 27.1 OS release-notes document was found, so this assessment does not claim exhaustive coverage of all iOS 27.1 changes.

The exact standalone `xcodebuild` invocation from CI succeeded with normal Xcode access. An earlier sandboxed invocation misleadingly reported that no project/workspace/package existed; that is not retained as a repository defect. A separate whole-example audit build with a global warnings-as-errors override encountered conflicting `-warnings-as-errors` and `-suppress-warnings` flags in Swiftional. The standalone library passed its strict build; the normal example build is recorded separately above.

At completion of the initial assessment, all initiated test and build runs had finished, the original iPhone 18 Pro run destination was restored, and the only repository addition was this report.

Follow-up — 21 October 2026

The split-pop visibility issue is now reproduced and fixed. A regression run on the newly available iPhone Duo/iOS 27.1 simulator showed that the original implementation reported success, delivered pop and application events to hidden content, and bypassed fallback. Both hidden-destination cases failed; both visible-destination controls passed.

Split-column pop now shares the post-pop hierarchy and arrangement-visibility validation used by `.popToExisting` and `.closeToExisting`. A retained destination that remains hidden reports `mutationRejected` before responder events are delivered, invokes its fallback when supplied, and releases queued navigation. The new parameterized regression covers hidden and visible destinations, with and without fallback, after returning from a detail above the arrangement.

The example's iPhone orientation configuration now supports portrait, landscape left, and landscape right. The existing iPad orientations are preserved. The README also documents the split-pop visibility check.

Verification after the fix: all 248 tests passed on iPhone Duo/iOS 27.1, with no failures, skips, or unexecuted entries. The standalone Release library build passed with warnings treated as errors. Xcode also built the example successfully; its processed Info.plist contains portrait and both landscape orientations. The only example build warning was the existing App Intents metadata-extraction warning. The original iPhone 18 Pro run destination was restored. The hosted CI lane recommendation remains outstanding; this follow-up changes only the requested navigation behavior, regression coverage, example orientation configuration, and related documentation.
