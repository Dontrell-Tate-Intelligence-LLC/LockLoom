# LockLoom Secure Access Platform
LockLoom is a cross-platform (Android and iOS) mobile security solution that enforces biometric **and** PIN verification before users can unlock their devices or launch protected applications. Administrators can define per-app factor policies (including different biometric modalities and PINs), optionally hide protected apps behind LockLoom’s secure launcher folder with its own PIN policy, cloak LockLoom behind another app’s icon/name, require the LockLoom console itself to use every available biometric plus an 8-digit admin PIN, enforce timed re-authentication overlays that sever active sessions on failure, and receive geolocated email/SMS alerts (including SOS beacons) for access attempts, failures, configuration changes, and text-triggered distress/shutdown/photo-capture actions.

LockLoom supports silent SMS codewords—with three configurable phrases per action—for SOS beaconing, remote shutdown, forced photo capture, forced audio capture, and forced video capture. Forced photo workflows use both front and rear cameras (when present) and deliver the images to the secondary notification mailbox, while audio and video captures default to five-second clips (expandable to 30 seconds) before shipping encrypted evidence to the same destination. Failed authentication attempts automatically trigger the dual-camera photo capture and alert flow, ensuring evidence is gathered whenever policies are challenged.

The consumer app ships with an in-app walkthrough that guides buyers through Android Device Owner or iOS MDM-lite/TestFlight enrollment, captures consent for degraded coverage when management rights are refused, provisions carrier/CPaaS relays for mirrored SMS distress triggers, and documents silent SOS automation (radios auto-toggle without indicators, with an optional NFC tag/Bluetooth fob hardware kill switch). Users can require the kill switch’s presence for normal operation and, when absent, LockLoom immediately locks the device until the switch returns. Telemetry retention is capped at 30 days, stored as salted SHA-512 hashes under consumer-owned keys, and onboarding recommends dedicated Proton Mail accounts for alerts and key escrow.

LockLoom launches as a single consumer-tier SKU priced at a $1 lifetime purchase, with optional upgrades delivered via in-app unlocks while retaining enterprise manageability through configuration.

See [`docs/architecture.md`](docs/architecture.md) for the complete architecture blueprint.

## Repository Layout

- `core/` – Kotlin Multiplatform core library for shared networking, policy models, and DI primitives.
- `mobile/` – Android and iOS application sources, including integrations with the shared core library.
- `backend/` – Control plane services, automation pipelines, and alert distribution interfaces.
- `web/` – React-based administration console (scaffolding now in place with Apollo Client integration).
- `infrastructure/` – Infrastructure-as-code definitions, CI/CD automation, and operational runbooks.
- `docs/` – Architecture references, decision records, and user-facing guides.
- `.editorconfig`, `.gitignore` – Shared tooling configuration to keep editors and build artifacts consistent across the monorepo.

## Build Tooling Stubs

- `gradlew` – Delegates to `tools/wrappers/gradlew`, which uses a system Gradle installation (8.x recommended) until a bundled wrapper is added.
- `bazelw` – Delegates to `tools/wrappers/bazelw`, expecting Bazelisk/Bazel on the host for now.
- `xcodebuild.sh` – Delegates to `tools/wrappers/xcodebuild.sh`, which requires macOS with Xcode CLIs when real builds exist.
- `tools/run_lint.sh` – Placeholder entry point for aggregated linting once modules materialize.
- `tools/run_tests.sh` – Runs Go unit tests under `backend/` and remains the placeholder entry point for upcoming mobile suites.
- `tools/ci_check.sh` – Top-level script that runs lint and tests; currently emits no-op status so CI wiring can start without failing.

## Kotlin Multiplatform Core

- Shared services such as dependency injection, network contracts, and policy models live in [`core/`](core/).
- Run the shared unit tests and metadata build with:

  ```bash
  ./gradlew :core:build
  ```

- When an Android SDK is available (`ANDROID_HOME`, `ANDROID_SDK_ROOT`, or `local.properties`), the module automatically enables the Android target and compiles AAR artifacts. Without an SDK, the build gracefully falls back to the JVM/desktop target so the shared models and serializers are still covered by tests.

## Backend SMS Mirror Connector

- The Go service under [`backend/cmd/smsmirror`](backend/cmd/smsmirror) ingests carrier/CPaaS webhooks at `/v1/cpaas/mirror`, validates HMAC SHA-256 signatures, and records mirrored SMS payloads for downstream alerting.
- Run the connector locally with:

  ```bash
  go run ./backend/cmd/smsmirror
  ```

- Execute backend tests (also invoked by `tools/run_tests.sh`) via:

  ```bash
  go test ./backend/...
  ```

## Admin Console GraphQL API

- The console API lives in [`backend/cmd/consoleapi`](backend/cmd/consoleapi) and exposes a role-enforced GraphQL endpoint for policies, devices, and telemetry.
- Provide bearer tokens through `LOCKLOOM_CONSOLE_TOKENS` formatted as `token|subject|ROLE1,ROLE2;...`; each request must include `Authorization: Bearer <token>`.
- Run the service locally with:

  ```bash
  LOCKLOOM_CONSOLE_TOKENS="devtoken|admin@lockloom|ADMIN,AUDITOR" \
  go run ./backend/cmd/consoleapi --addr :8080
  ```

- Backend tests cover schema validation, RBAC enforcement, and token parsing.

## Web Console Scaffolding

- The React-based admin console lives in [`web/console`](web/console/) and currently exposes authentication, layout,
  and Apollo Client wiring against the GraphQL API.
- Install dependencies with `pnpm install` and run `pnpm dev` for local development.
- Configure `VITE_GRAPHQL_ENDPOINT` to point at the console API when testing end-to-end flows.
- Run Vitest unit tests via `pnpm test` (also invoked by `npm test` for compatibility with the task success criteria).

## Android Device-Owner Shell

- The Android launcher lives in [`androidApp/`](androidApp/), wiring Jetpack Compose navigation to the shared core and exposing manifest hooks plus a guided device-owner enrollment flow.
- The home screen now surfaces live Device Owner status, QR/NFC provisioning launchers, and a manual checklist that opens the relevant system settings when QR/NFC triggers are unavailable.
- Instrumentation coverage ships with an Espresso-based test that stubs the provisioning intent, simulates enrollment success, and verifies LockLoom observes `DevicePolicyManager.isDeviceOwnerApp = true` after a refresh.
- Build an installable debug APK (with Compose previews enabled) via:

  ```bash
  ./gradlew :androidApp:assembleDebug
  ```

- The shell provides a guided enrollment checklist and registers a `DeviceAdminReceiver` so future tasks can extend the provisioning and policy orchestration flows.

## iOS SwiftUI Shell

- The iOS placeholder lives in [`iosApp/`](iosApp/) and links against the shared Kotlin Multiplatform core via a generated `LockLoomCore.xcframework`.
- Build prerequisites on macOS:
  - Generate the framework once with `./gradlew :core:assembleLockLoomCoreXCFramework` (the Xcode project runs this automatically if the bundle is missing).
  - Open `iosApp/LockLoom.xcodeproj` or execute:

    ```bash
    ./xcodebuild.sh -scheme LockLoom -configuration Debug
    ```

- The SwiftUI shell renders a placeholder enrollment view and verifies the Kotlin bridge by instantiating `LockLoomCore` through the generated framework.

## CI/CD Workflows

- `.github/workflows/mobile-ci.yml` – Runs placeholder mobile checks on every pull request until the Android/iOS builds land.
- `.github/workflows/backend-ci.yml` – Executes backend placeholders so service builds/tests can bolt in later without rewiring triggers.
- `.github/workflows/web-ci.yml` – Provides a staging ground for future web or documentation site validations.

## Contributing & Coding Standards

- Review [`CONTRIBUTING.md`](CONTRIBUTING.md) for branching, review, and commit expectations.
- Language-specific style guides live under [`docs/style/`](docs/style/):
  - [`kotlin.md`](docs/style/kotlin.md)
  - [`swift.md`](docs/style/swift.md)
  - [`go_rust.md`](docs/style/go_rust.md)
  - [`typescript.md`](docs/style/typescript.md)
