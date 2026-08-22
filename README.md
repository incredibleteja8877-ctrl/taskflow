# TaskFlow

A lightweight project-management app built for the Flutter Developer technical
assignment (Mock Data Edition). Users belong to organizations, create and
manage projects, view and update tasks, and assign work — all against a local
mock JSON asset that behaves like a flaky network.

There is **no backend**. No Firebase, no HTTP client, no BaaS. The mock data
layer is deliberate, and the whole design question it answers is: *would this
survive being swapped for a real API?*

---

## Contents

- [Quick start](#quick-start)
- [Test credentials](#test-credentials)
- [Architecture](#architecture)
- [Folder structure](#folder-structure)
- [State management](#state-management)
- [The mock data layer](#the-mock-data-layer)
- [Authentication and token flow](#authentication-and-token-flow)
- [Triggering the simulated errors and offline state](#triggering-the-simulated-errors-and-offline-state)
- [Testing](#testing)
- [Known limitations](#known-limitations)
- [Technical decisions and trade-offs](#technical-decisions-and-trade-offs)

---

## Quick start

**Toolchain used to build this**

| | Version |
|---|---|
| Flutter | 3.44.0 (stable) |
| Dart | 3.12.0 |
| Android compileSdk | 37.0 |
| Android minSdk | Flutter default (24) |
| Java | 17 |

```bash
flutter pub get
flutter run
flutter test
flutter build apk --release
```

No code generation step. No `build_runner`. No environment variables, no
`.env`, no secrets. `flutter pub get && flutter run` is genuinely all it takes.

### One Android note

`flutter_secure_storage` 11 requires compiling against Android SDK 37, which
the SDK manager installs as `android-37.0` under Android's new minor-version
scheme. Plain `compileSdk = 37` makes Gradle look for a folder named
`android-37`, which does not exist. `android/app/build.gradle.kts` therefore
sets both:

```kotlin
compileSdk = 37
compileSdkMinor = 0
```

If your first build fails with *"Failed to find target with hash string
'android-37'"*, that is this issue; the fix is already committed.

### Integration tests need a device

```bash
flutter test                    # unit + widget, no device needed
flutter test integration_test   # needs a connected device or emulator
```

---

## Test credentials

All four accounts use the password **`Password123!`**.

| Email | Organization | Role |
|---|---|---|
| `ava.admin@nimbusdigital.test` | Nimbus Digital | **org_admin** |
| `marcus.member@nimbusdigital.test` | Nimbus Digital | member |
| `daniel.admin@harborlightstudios.test` | Harborlight Studios | **org_admin** |
| `elena.member@harborlightstudios.test` | Harborlight Studios | member |

**To see role-based behaviour:** sign in as Ava, open a project's ⋮ menu —
Edit and Delete. Sign in as Marcus, same menu — Edit only. The rule is
enforced in the domain layer, not by hiding the button; see
[Authorization](#authorization).

**To see org scoping:** Ava sees *Website Relaunch* and *Mobile App v2*.
Daniel sees only *Client Onboarding Revamp*. Neither can reach the other's
data by any route.

---

## Architecture

Three layers, with all dependencies pointing **inward**:

```
   presentation/  ──depends on──▶   domain/   ◀──depends on──  data/
    widgets                        entities                  JSON reader
    Riverpod providers             repository interfaces      models
                                   usecases                   repo impls
```

`domain/` depends on nothing — no Flutter, no JSON, no packages beyond
`equatable`. It is the only layer that would survive being copied into a Dart
CLI or a server.

Two invariants hold throughout, and both are mechanically checkable:

1. **`rootBundle` appears in exactly one file** — `mock_json_data_source.dart`.
2. **No file under `domain/` imports `package:flutter/`** and none imports
   `data/`.

### The request path

```
Widget
  └─ ref.watch(taskListProvider)          presentation/  Riverpod state
       └─ TaskUseCases.list(session)      domain/        business rules + authz
            └─ TaskRepository (interface) domain/        the swap boundary
                 └─ TaskRepositoryImpl    data/          mapping + validation
                      └─ MockJsonDataSource              latency, errors, cache
                           └─ assets/mock_data/*.json
```

Presentation talks to **usecases**, never straight to a repository. That is
what makes it structurally impossible for a screen to bypass an authorization
check — repositories are not reachable from `presentation/`.

### Authorization

Task 03 requires that a non-admin attempting an admin action *"via a direct
deep link"* is still blocked. Three things enforce that:

1. **Router guard** (`core/router/app_router.dart`) — `redirect` runs on every
   navigation, including pasted deep links and the Android back button.
   Signed-out users can only reach Login and Register.
2. **Usecase guards** (`domain/usecases/`) — every method takes the
   `AuthSession` and re-reads the caller's real membership from the org
   directory. It does **not** trust `session.isAdmin`, because that value came
   from the client.
3. **UI affordances** — non-admins are not offered a Delete button. This is
   convenience, not security, and it is the *least* important of the three.

Cross-tenant access returns **`NotFoundException`, not `ForbiddenException`**.
Saying "forbidden" would confirm to one tenant that another tenant's record
exists. `test/unit/project_authorization_test.dart` proves all of this,
including a test that forges a session claiming `org_admin` and shows the
delete still fails.

A fuller write-up, with diagrams, is in **[ARCHITECTURE.md](ARCHITECTURE.md)**.

---

## Folder structure

```
lib/
├── core/
│   ├── constants/      app_spacing.dart        one 4pt spacing scale
│   ├── di/             providers.dart          the dependency-injection graph
│   ├── error/          app_exception.dart      sealed error hierarchy
│   ├── network/        mock_api_config.dart    latency + failure switches
│   ├── router/         app_router.dart         go_router + the auth guard
│   ├── theme/          app_theme.dart          light + dark Material 3
│   └── utils/          validators.dart, formatters.dart
├── data/
│   ├── datasources/    mock_json_data_source.dart   ← the ONLY rootBundle user
│   │                   session_storage.dart         Keystore/Keychain
│   │                   local_cache.dart             offline snapshot
│   ├── models/         *_model.dart            JSON ⟷ entity translators
│   └── repositories/   *_repository_impl.dart
├── domain/
│   ├── entities/       plain Dart, no Flutter
│   ├── repositories/   abstract interfaces  ← the swap boundary
│   └── usecases/       business rules and authorization
└── presentation/
    ├── auth/  home/  projects/  tasks/  profile/
    │     ├── providers/   Riverpod controllers
    │     ├── screens/
    │     └── widgets/
    └── shared/            reusable widgets + UI-only enum mappings

assets/mock_data/taskflow_mock_data.json
test/unit/  test/widget/  test/support/  integration_test/
```

Each feature folder owns its providers, screens and widgets. `shared/` holds
what genuinely crosses features: the state views, the confirm dialog, the
chips, and `task_display.dart` — the presentation-only mapping from
`TaskStatus.inProgress` to the label "In progress", its colour and its icon.
That mapping is the "UI model" separation Task 01 asks for: the domain knows
the enum, only the UI knows how it is spelled.

---

## State management

**Riverpod 2** (`flutter_riverpod`), chosen for two reasons:

1. **`AsyncValue` models the required states directly.** Task 06 asks for
   `initial → loading → success → empty → error`. `AsyncValue` gives loading,
   data and error as a single value that cannot be internally inconsistent.
   The hand-rolled alternative — `bool isLoading`, `Object? error`,
   `List<T> data` — allows `isLoading == true` *and* `error != null`
   simultaneously, which is meaningless and eventually happens.
2. **It is also the DI container.** `core/di/providers.dart` registers every
   dependency; `ref.watch` resolves it; `ProviderScope(overrides: [...])`
   substitutes it in tests. No `get_it`, no service locator, no generated code.

### How the five states map

| Brief | Implementation |
|---|---|
| initial | `AsyncLoading` before the provider's `build()` resolves |
| loading | `AsyncLoading` |
| success | `AsyncData` with a non-empty list |
| **empty** | `AsyncData` with an **empty** list — derived by the widget |
| error | `AsyncError`, rendered by the shared `ErrorView` |

`empty` is derived rather than stored. A separate flag can drift out of sync
with the list it describes; `data.isEmpty` cannot. `EmptyView` is a distinct
widget from `ErrorView` — an empty list is not a failure, and showing a red
error because a new user has no projects is the most common UX mistake in this
kind of app.

### Reads go into state; writes throw

- `refresh()` wraps its call in `AsyncValue.guard`, so a failed load becomes
  `AsyncError` and the list shows a retry button.
- `createProject()` / `updateTask()` / `assign()` **rethrow**. The form that
  called them needs `ValidationException.fieldErrors` to mark its own inputs.
  Swallowing that into list state would replace the whole screen with an error
  page because a name was too long.

### Reactive by dependency, not by invalidation

`ProjectListController.build()` calls `ref.watch(currentSessionProvider)`.
Sign out and the provider is torn down; sign in as someone else and it rebuilds
for *their* org. There is no "clear the cache on logout" code anywhere, because
there is nothing to remember to clear.

Likewise `TaskListController` watches `taskFilterProvider`: adjusting a filter
chip reloads the list with no imperative call.

---

## The mock data layer

### `MockJsonDataSource` — a small in-memory server

`assets/mock_data/taskflow_mock_data.json` is loaded once and becomes a
**mutable in-memory database**. Reads return deep copies; writes mutate the
live store. That is how create/edit/delete work with no backend.

Its API is transport-shaped on purpose:

```dart
Future<List<Map<String, dynamic>>> readCollection(String key);
Future<Map<String, dynamic>>       readObject(String key);
Future<Map<String, dynamic>>       readById(String key, String id);
Future<Map<String, dynamic>>       insert(String key, Map<String, dynamic> row);
Future<Map<String, dynamic>>       update(String key, String id, Map<String, dynamic> changes);
Future<void>                       delete(String key, String id);
```

Swapping to a real backend means writing an `HttpTaskFlowApi` with these same
methods and repointing four lines in `core/di/providers.dart`. Nothing above
`data/` changes.

### Models and entities are separate

`TaskModel` (in `data/`) knows that `status` arrives as the string
`"in_progress"`. `Task` (in `domain/`) knows only `TaskStatus.inProgress`. If
a real API later sends `status: 2`, six lines in `TaskModel` change and nothing
else does.

Serialization goes both ways — `fromJson` and `toJson` — because in-memory
writes need it, and because a round trip is the single test that catches a typo
in every field name at once.

### Request models

`CreateTaskRequest` and `CreateProjectRequest` exist because a record that does
not exist yet has no `id` and no `createdAt`; the data layer mints both.
Updates take the entity instead, because the caller already holds it and
`copyWith` handles partial changes correctly — including clearing a nullable
assignee, which a half-populated request object gets wrong.

### Artificial latency

Every call sleeps a random **300–800 ms** (`MockApiConfig.minDelay` /
`maxDelay`). Loading spinners are therefore real, not staged. Tests pass
`MockApiConfig.instant`, which zeroes it — the full suite runs in about 25
seconds.

---

## Authentication and token flow

Simulated end to end. No network call.

```
Login
  ├─ validate email + password client-side (Validators)
  ├─ read auth_mock.test_credentials through the data layer
  ├─ match email (case-insensitive) + password (verbatim, never trimmed)
  ├─ resolve the User from the users collection
  ├─ mint tokens from auth_mock.mock_login_response
  └─ store the session in flutter_secure_storage

Cold start (Splash)
  ├─ read the stored session
  ├─ refresh token expired?     → clear it, go to Login
  ├─ access token near expiry?  → refresh silently, continue
  └─ otherwise                  → continue

Logout
  └─ clear secure storage; the router guard blocks every authenticated route
```

### Relative lifetimes become absolute deadlines

The mock response gives `access_token_expires_in_seconds: 900`. *900 seconds
from when?* has no answer after a restart, so at login we convert to a
wall-clock instant and store that. Every later check is
`now.isAfter(deadline)`.

Access tokens expire after **15 minutes**, refresh tokens after **7 days**,
straight from the mock values.

### Refresh produces a genuinely new token

The mock always returns the literal string `"mock.access.token.short_lived"`,
so a naive refresh would hand back a byte-identical token and no test could
prove it ran. The refreshed token is suffixed with the issue instant, making it
verifiably different. You can watch this on **Profile → Refresh access token
now**: the expiry timestamp jumps forward 15 minutes.

### Security rules observed

- **Passwords are never stored.** Validated at login, then out of scope. The
  registration flow deliberately does not add the new password to
  `test_credentials`.
- **Tokens are never logged.** `AuthTokens.toString()` and
  `LoginRequest.toString()` are overridden to redact. Objects that hold secrets
  should refuse to print themselves, because leaks happen through crash reports
  and error dumps rather than deliberate `print` calls.
- **Tokens live in the Keystore/Keychain** via `flutter_secure_storage`, never
  in `SharedPreferences`. The offline cache — which is not sensitive — uses
  `SharedPreferences`.
- **Credentials are never hardcoded in a widget.** The UI can only reach them
  by calling `AuthRepository.login`.
- Login failure gives one message for both "no such account" and "wrong
  password", so the app cannot be used to enumerate registered addresses.

---

## Triggering the simulated errors and offline state

**Everything below is reachable from the running app — no source edits.**
Open the **Profile** tab and scroll to **Developer tools**.

| What | How to trigger | What you should see |
|---|---|---|
| **Simulated 404** | Any record id containing `_404`. Deep-link to `/task/task_404`, or `/project/proj_404`. | Task Details shows the search-off icon, "We could not find what you were looking for", and a Try again button. |
| **Simulated network timeout** | Profile → Developer tools → **Force network timeout**. Then pull-to-refresh any list. | Timer icon, "The request timed out. Please try again.", retry button. |
| **Simulated server error (500)** | Profile → Developer tools → **Force server error**. Then pull-to-refresh. | Generic error icon and message, retry button. |
| **Simulated validation error (422)** | Create a task with an empty title, or a title over 120 characters. Or try to assign a user from another org. | The message appears **inline under the offending field**, not in a snackbar. |
| **Offline** | Profile → Developer tools → **Offline mode**. | An amber banner appears above every screen reading "Offline — showing data saved &lt;timestamp&gt;". Lists keep working from the cached snapshot. Any create/edit/delete fails with "You are offline. This change cannot be saved yet." |
| **Forbidden (403)** | Sign in as `marcus.member@nimbusdigital.test` and attempt a project delete through the usecase. | The Delete option is not offered in the UI; calling the usecase directly throws `ForbiddenException`. Covered by `test/unit/project_authorization_test.dart`. |
| **Cross-tenant access** | Signed in as Ava, deep-link to `/project/proj_1003` (a Harborlight project). | "We could not find what you were looking for" — deliberately not "forbidden". |
| **Artificial latency** | Always on: 300–800 ms per request. | Spinners on every load; the Sign in button shows one while the fields grey out. |

### How offline behaves, precisely

Offline is asymmetric, matching how real offline-first apps work:

- **Reads succeed** from a persisted snapshot of the whole database, written to
  `SharedPreferences` after every successful load and every write.
- **Writes fail** with `OfflineException`, because there is nowhere to send
  them.
- **Stale data is labelled** — the banner shows when the snapshot was written.
- **Cold start with no snapshot** gives "You are offline and no data has been
  saved yet" rather than pretending.

---

## Testing

```bash
flutter test                    # 104 unit + widget tests, ~35 s, no device
flutter test integration_test   # one end-to-end flow (~50s), needs a device
```

| Suite | File | Covers |
|---|---|---|
| Data layer | `test/unit/data_layer_smoke_test.dart` | JSON parsing of all seven collections, the `_404` marker, offline and timeout switches, repository mapping, create/read-back, unassignment |
| Auth | same file | login as admin and member, wrong password, 15-minute expiry, refresh issuing a new token, logout, register, duplicate email |
| Project authz | `test/unit/project_authorization_test.dart` | org scoping, 404-not-403 for cross-tenant, admin-only delete, **a forged admin session still being refused**, cascading delete |
| Task authz | `test/unit/task_authorization_test.dart` | cross-org task reads/writes, **cross-org assignment refused**, status/priority updates, filtering through the usecase |
| Filtering | `test/unit/task_filter_test.dart` | every filter dimension, empty-set semantics, inclusive date ranges, overdue arithmetic, the `copyWith` sentinel |
| Validation | `test/unit/validators_test.dart` | email, password, confirmation, name, non-empty |
| App + projects | `test/widget/app_launch_test.dart` | splash → login redirect, form validation, sign-in, org-scoped list, admin vs member menus, create, delete with confirmation, sign-out |
| Tasks | `test/widget/task_screens_test.dart` | list rendering in **loading / empty / error / success**, status update UI, priority update UI, assign and unassign, the picker excluding other orgs, project details |
| Integration | `integration_test/app_test.dart` | login flow, project listing, task listing, create/update task and task assignment — one end-to-end journey against the real `main()`, nothing mocked |

Tests do not depend on execution order and never touch a network. Each widget
test boots a fresh `ProviderScope`.

### One thing worth knowing about the test harness

`test/support/test_harness.dart` injects an in-memory `AssetBundle` rather than
using `rootBundle`. This is not stylistic: `testWidgets` runs inside
`FakeAsync`, and `rootBundle.loadString` resolves only in the **first** test of
a file — every later one hangs forever on I/O that FakeAsync will not advance.
The `AssetBundle? bundle` parameter on `MockJsonDataSource` is what makes the
widget suite possible at all, which is a concrete argument for injecting
dependencies rather than reaching for globals.

---

## Known limitations

1. **Registered users cannot sign in again.** Registration creates the user,
   an organization and an admin membership, but the password is validated and
   then discarded — Task 02 forbids storing passwords. So register → logout →
   login fails. The alternative would have been to write the password into the
   in-memory credential list, which felt like the wrong trade.
2. **Mutations do not survive an app restart.** The in-memory database resets
   from the asset on a cold start. The offline snapshot preserves data for
   *offline reads*, but a fresh online launch re-seeds from the bundled JSON.
3. **`deleteProject` is not transactional.** It removes the project's tasks
   first, then the project. A failure between the two orphans nothing but
   leaves the tasks gone. A real backend would wrap both in a transaction.
4. **Comments are modelled but not surfaced.** `Comment`, `CommentModel` and
   the four rows in the asset are parsed; no screen shows them. The brief never
   asks for comments.
5. **Notifications are not implemented.** Task 10 is explicitly marked bonus
   and was cut for time. The entity and model exist.
6. **The offline snapshot keeps stale project task counts.** Counts are
   normally recomputed from the tasks collection; offline they come from the
   snapshot as written.
7. **No pending-operations queue.** The Task 08 bonus — queueing writes offline
   and syncing when back online — is not implemented. Offline writes are
   refused outright with a clear message.
8. **No golden tests or coverage report.** Both are Task 11 bonuses.
9. **Biometric unlock and inactivity timeout are not implemented** (Task 02
   bonuses).
10. **iOS is untested.** The brief marks iOS optional; the project is
    configured for it but has only been built and run on Android.

---

## Technical decisions and trade-offs

**Riverpod 2, not 3.** v3 is a substantial rewrite with thinner documentation
and no bearing on anything this assignment grades. Migrating mid-build carried
risk for zero benefit.

**No code generation.** No `freezed`, no `json_serializable`, no
`riverpod_generator`. They would add a `dart run build_runner build` step, and
Task 13 requires the app to run *"without manual source-code modifications"* —
a reviewer who runs only `flutter pub get && flutter run` on generated-but-
uncommitted code gets a broken build. The cost is hand-written `fromJson` and
`copyWith`; the benefit is that `pub get` is genuinely the only setup step.

**`mocktail`, not `mockito`.** Same reason: no code generation.

**Validation is duplicated on purpose.** Forms validate for instant feedback;
repositories validate because a server never trusts a client. Both call the
same `Validators` functions, so the two can never disagree about what "valid"
means.

**Offline lives at the data source, not in each repository.** The data source
*is* the network in this app, so that is the honest place for "the network is
down". Putting it in three repositories would have meant three caches and three
chances to get the fallback wrong.

**`AsyncNotifier` for lists, plain `Provider` for repositories.** Repositories
never change, so they need no state machinery. Lists do.

**The `_unset` sentinel in `copyWith`.** `Task.copyWith(assigneeId: null)` must
mean *unassign*, not *leave alone*. The usual `?? this.field` pattern conflates
those two, which would make Task 05's "remove a user from a task" impossible.
A private sentinel object distinguishes all three cases.

**Cross-tenant returns 404, not 403.** Explained above; it is how real
multi-tenant systems behave and the tests assert it.

**Bottom-navigation shell with `StatefulShellRoute`.** Each tab keeps its own
stack and scroll position. Detail screens push above the shell on the root
navigator, so they cover the bottom bar the way native apps do.
