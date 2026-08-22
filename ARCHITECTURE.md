# TaskFlow — Architecture

Companion to [README.md](README.md). This document covers the layering, the
data layer, state management, the simulated auth flow, local storage, error
handling and navigation, plus the reasoning behind the decisions that were not
obvious.

---

## 1. Layering

```
┌─────────────────────────────────────────────────────────────────────┐
│  presentation/                                                      │
│                                                                     │
│   Screens ──watch──▶ Riverpod controllers ──call──▶ UseCases        │
│   (widgets)          (AsyncNotifier)                                │
│                                                                     │
│   Knows: Flutter, entities, usecases                                │
│   Does NOT know: JSON, repositories, the asset bundle               │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ depends on
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│  domain/                            ← depends on NOTHING            │
│                                                                     │
│   entities/       Task, Project, User, OrgMember, AuthSession …     │
│   repositories/   abstract interfaces  ◀── the swap boundary        │
│   usecases/       business rules + authorization                    │
│                                                                     │
│   Pure Dart. No Flutter import. No JSON. No packages but equatable. │
└──────────────────────────────▲──────────────────────────────────────┘
                               │ implements
                               │
┌──────────────────────────────┴──────────────────────────────────────┐
│  data/                                                              │
│                                                                     │
│   repositories/   TaskRepositoryImpl, ProjectRepositoryImpl …       │
│   models/         TaskModel, ProjectModel …   JSON ⟷ entity         │
│   datasources/    MockJsonDataSource   ← the ONLY rootBundle user   │
│                   SessionStorage       ← Keystore / Keychain        │
│                   LocalCache           ← offline snapshot           │
└─────────────────────────────────────────────────────────────────────┘
```

Both arrows point **inward**, at `domain/`. That is the whole discipline. Two
invariants make it checkable rather than aspirational:

```bash
# must print exactly one filename
grep -rl "rootBundle" lib/

# must print nothing
grep -rn "package:flutter/" lib/domain/ --include=*.dart | grep import
grep -rn "/data/" lib/domain/ --include=*.dart
```

### Why the boundary is `domain/repositories/`

`TaskRepository` is an `abstract interface class`: it can be implemented but
not extended, so nobody can inherit half of it. It returns **entities**, never
`Map<String, dynamic>`, and it has an **error contract** — implementations
throw only `AppException` subtypes.

A future `HttpTaskRepository` would catch `SocketException` and rethrow
`NetworkTimeoutException`. Everything above the interface — every usecase,
provider, widget and test — would be unable to tell that the transport changed.
That is the concrete answer to *"would this survive being swapped for a real
API?"*

---

## 2. Request path, end to end

Taking "the user opens the Tasks tab":

```
TaskListScreen
   │  ref.watch(taskListProvider)
   ▼
TaskListController                       presentation/tasks/providers/
   │  watches currentSessionProvider + taskFilterProvider
   │  ref.read(taskUseCasesProvider).list(session, filter: filter)
   ▼
TaskUseCases.list                        domain/usecases/
   │  _requireMembership(session)        ← re-reads the real role
   │  _projectIdsInOrg(session)          ← org scoping
   │  filters tasks to those project ids
   ▼
TaskRepository (interface)               domain/repositories/
   ▼
TaskRepositoryImpl                       data/repositories/
   │  _guard() → only AppException escapes
   │  TaskModel.fromJson on each row
   │  applies TaskFilter.matches
   ▼
MockJsonDataSource.readCollection        data/datasources/
   │  _simulateRoundTrip()  → 300-800ms, or a forced failure
   │  _database()           → asset on first call, or offline snapshot
   ▼
assets/mock_data/taskflow_mock_data.json
```

Note where each concern lives, and that none of them is duplicated:

| Concern | Layer |
|---|---|
| Which spinner to show | presentation |
| Who is allowed to see this | domain (usecase) |
| Which rows belong to this org | domain (usecase) |
| Turning `"in_progress"` into an enum | data (model) |
| Rejecting an empty title | data (repository) *and* presentation (form) |
| Latency, timeouts, offline | data (data source) |

---

## 3. The data layer

### `MockJsonDataSource` — a small in-memory server

One JSON asset is decoded once into a **mutable** map that acts as the
database. Reads hand out deep copies (`jsonDecode(jsonEncode(row))`) so a
caller mutating what it received cannot corrupt the store; only private write
methods touch the live lists.

```dart
Future<Map<String, dynamic>> _database() => _pending ??= _loadDatabase();
```

The **Future** is cached, not the result. Two screens loading at once on a cold
start share a single asset read instead of racing.

### Simulated failures

`MockApiConfig` is an immutable value object holding five knobs, injected into
the data source rather than read from a global:

| Field | Effect |
|---|---|
| `minDelay` / `maxDelay` | random sleep per call, default 300–800 ms |
| `isOffline` | reads serve the snapshot; writes throw |
| `forceTimeout` | every call throws `NetworkTimeoutException` |
| `forceServerError` | every call throws `UnknownException` (a simulated 500) |
| `notFoundIdMarker` | any id containing `_404` throws `NotFoundException` |

Injected, not global, for three reasons: tests pass `MockApiConfig.instant` and
run in 25 seconds instead of sleeping; Riverpod can watch it so a debug toggle
takes effect immediately; and Task 01 grades dependency injection.

The provider wiring has one subtlety worth pointing at:

```dart
final mockJsonDataSourceProvider = Provider<MockJsonDataSource>((ref) {
  final dataSource = MockJsonDataSource(config: ref.read(mockApiConfigProvider), …);
  ref.listen<MockApiConfig>(mockApiConfigProvider, (_, next) => dataSource.config = next);
  return dataSource;
});
```

`ref.read` + `ref.listen`, **not** `ref.watch`. Watching would rebuild the data
source on every toggle, constructing a fresh object with an empty database —
so every task the user created would vanish the moment they flipped the offline
switch. Instead the config is pushed into the existing instance.

### Models vs entities

```
JSON row                TaskModel                Task
{"status":              fromJson  ──▶            TaskStatus.inProgress
 "in_progress"}         toJson    ◀──
data/models/                                     domain/entities/
```

`statusToWire` switches over the **enum**, so it is exhaustive and needs no
`default` — add a fifth status and it will not compile until you handle it.
`statusFromWire` switches over a **String**, so `_` is required, and it throws
`ValidationException` rather than defaulting; silently turning garbage into
`TaskStatus.todo` would hide real bugs.

### Local storage — two stores, deliberately

| Store | Backed by | Holds | Why |
|---|---|---|---|
| `SessionStorage` | `flutter_secure_storage` | the auth session incl. tokens | secrets belong in Keystore/Keychain |
| `LocalCache` | `shared_preferences` | a snapshot of the whole mock DB | not sensitive; avoids paying Keystore decryption on every cache read |

Both are interfaces with in-memory implementations, because the real ones need
platform channels that do not exist in a `flutter test` process.

`SecureSessionStorage.read()` catches decode failures and returns null after
clearing. Corrupt session data on launch is the worst possible crash — the user
cannot get past the splash screen and has no way to recover. "Signed out"
always leaves a path forward. The key is versioned (`taskflow.session.v1`) so
a future shape change ignores old data instead of throwing.

---

## 4. State management

### Provider graph

```
                    ┌──────────────────────┐
                    │  mockApiConfig       │  Notifier — debug toggles
                    └──────────┬───────────┘
                               │ listen
                    ┌──────────▼───────────┐
   localCache ─────▶│  mockJsonDataSource  │◀──── assets
                    └──────────┬───────────┘
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
       taskRepository   projectRepository  organizationRepository
              └────────────────┼────────────────┘
                     ┌─────────▼─────────┐
                     │  taskUseCases     │   projectUseCases
                     └─────────┬─────────┘
       ┌───────────────┬───────┴────────┬──────────────────┐
       ▼               ▼                ▼                  ▼
  taskListProvider  projectList   taskDetailProvider   orgMembers
  (AsyncNotifier)   (AsyncNotifier)  (FutureProvider)  (FutureProvider)
       │                 │
       └────────┬────────┘
                ▼
          authController (AsyncNotifier<AuthSession?>)
          — every list watches currentSessionProvider,
            so signing out tears them all down
```

Repository providers are typed as their **interfaces**, never their `Impl`.
That is what lets a test write
`taskRepositoryProvider.overrideWithValue(FakeTaskRepository())` in one line,
and what would let production swap in an HTTP implementation by editing four
lines.

### Riverpod as the DI container

There is no `get_it` and no service locator. `Provider<AuthRepository>` is the
registration, `ref.watch(authRepositoryProvider)` is the resolution, and
`ProviderScope(overrides: [...])` is the test-time substitution. That is the
whole of Task 01's dependency-management requirement.

### The five states

Handled once, in `AsyncValue.when`, and rendered by three shared widgets in
`presentation/shared/widgets/state_views.dart`:

```dart
projects.when(
  loading: () => const LoadingView(),
  error:   (e, _) => PullableCenter(child: ErrorView(error: e, onRetry: …)),
  data:    (items) => items.isEmpty
      ? PullableCenter(child: EmptyView(…))
      : ListView.separated(…),
)
```

`PullableCenter` exists because `RefreshIndicator` only works over a
scrollable. A plain `Center` silently kills pull-to-refresh on exactly the
empty and error states — the two moments a user most wants to retry.

---

## 5. Error handling

`AppException` is a **sealed** hierarchy, which buys compile-time
exhaustiveness:

```dart
sealed class AppException implements Exception { final String message; }

NotFoundException        simulated 404
NetworkTimeoutException  simulated timeout   (named to avoid dart:async's)
ValidationException      simulated 422, carries fieldErrors
UnauthorizedException    simulated 401
ForbiddenException       simulated 403
OfflineException         connectivity toggle
UnknownException         catch-all / simulated 500
```

`ErrorView` switches over it with **no `default` clause**:

```dart
return switch (error) {
  NotFoundException()       => (Icons.search_off, error.message),
  NetworkTimeoutException() => (Icons.timer_off_outlined, error.message),
  …
};
```

Because the hierarchy is sealed, adding an eighth exception type breaks the
build until it is given a presentation. No error can reach a user as a blank
screen.

### Where each failure surfaces

| Failure | Destination | Why |
|---|---|---|
| Load failure | `ErrorView` replacing the list, with Retry | there is no content to preserve |
| `ValidationException` with `fieldErrors` | inline under the offending input | the user needs to know *which* field |
| Any other mutation failure | snackbar over the intact screen | the content is still valid |

`_guard()` in every repository upholds the interface's promise: `on
AppException { rethrow; }` first — so a deliberate `NotFoundException` passes
through untouched — then a catch-all that converts anything unexpected into
`UnknownException`. Raw `TypeError`s never reach the UI.

---

## 6. Simulated authentication

```
┌──────────┐   email+password    ┌──────────────────┐
│  Login   │────────────────────▶│ AuthRepository   │
│  screen  │                     │      Impl        │
└──────────┘                     └────────┬─────────┘
                                          │ readObject('auth_mock')
                                          ▼
                              ┌───────────────────────┐
                              │ MockJsonDataSource    │
                              │  test_credentials     │
                              │  mock_login_response  │
                              └───────────┬───────────┘
                                          │
              ┌───────────────────────────┴───────────────┐
              │ match email + password                    │
              │ resolve User from `users`                 │
              │ AuthTokensModel.fromLoginResponse(        │
              │     response, issuedAt: clock())          │
              │   900s  → accessTokenExpiresAt            │
              │   604800s → refreshTokenExpiresAt         │
              └───────────────────────────┬───────────────┘
                                          ▼
                              ┌───────────────────────┐
                              │ SecureSessionStorage  │  Keystore / Keychain
                              └───────────┬───────────┘
                                          ▼
                              authController: AsyncData(session)
                                          │
                                          ▼
                              router redirect → /home
```

### Design points

**The clock is injected.** `AuthRepositoryImpl` takes
`DateTime Function() clock`, and every expiry method on `AuthTokens` takes
`now` as a parameter. A test asserts 16-minute expiry instantly instead of
waiting 16 minutes.

**Relative → absolute at login.** Explained in the README; the short version is
that "900 seconds from now" is meaningless after a restart.

**The mock login response contains no user id.** Only two token strings. So the
repository matches the email against `test_credentials` to get `org_id` and
`role`, then looks the profile up in `users`. Worth knowing if you extend it.

**Registration creates a workspace.** The mock data has no mechanism for adding
a member to an existing org, and inventing one would be fabricated behaviour.
Real SaaS signup creates your own workspace, so that is what is simulated — and
it yields a demonstrable **empty state**, which Task 06 requires.

---

## 7. Navigation

`go_router` with a `StatefulShellRoute.indexedStack`:

```
/                     Splash        ← initialLocation
/login                Login
/register             Register

StatefulShellRoute  (AppShell: bottom nav + offline banner)
  ├── /home          Dashboard
  ├── /projects      Project list
  ├── /tasks         Task list
  └── /profile       Profile / Settings / debug toggles

/project/:projectId   Project details   ← pushed on the ROOT navigator
/task/:taskId         Task details      ← pushed on the ROOT navigator
```

Detail routes sit on the root navigator so they cover the bottom bar, the way
native apps behave. Singular path prefixes (`/project/…` vs the `/projects`
branch) keep them from colliding.

### The guard

```dart
redirect: (context, state) {
  final auth = ref.read(authControllerProvider);
  if (auth.isLoading && atSplash) return null;        // still checking
  if (!signedIn) return atAuthScreen ? null : '/login';
  if (atSplash || atAuthScreen) return '/home';
  return null;
}
```

It runs on **every** navigation — pasted deep links and the Android back button
included — which is why the guard lives here and not in each screen's
`initState`. It is the first line of defence, not the only one: the usecase
layer re-checks authorization, so a deep link that somehow reached a screen
still fails at the business-logic layer.

### Riverpod → go_router bridge

go_router wants a `Listenable`; Riverpod does not provide one. A tiny
`ChangeNotifier` bridges them:

```dart
final _routerRefreshProvider = Provider<_RouterRefresh>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);
  return refresh;
});
```

Without this, the router would have to `ref.watch` the auth state, which
rebuilds the entire `GoRouter` — discarding the navigation stack — on every
session change. `ref.onDispose(router.dispose)` matters too: a leaked router
keeps listeners alive and, in tests, keeps scheduling frames so `pumpAndSettle`
never settles.

---

## 8. Authorization model

Three independent layers, in decreasing order of importance:

```
1. UseCase guards      ← the real enforcement
     _requireMembership(session)   re-reads the role from the org directory
     _requireAdmin(session)        ForbiddenException if not an admin
     _requireSameOrg(resource)     NotFoundException across tenants
     _requireAssignable(userId)    ValidationException for a cross-org assignee

2. Router redirect     ← blocks unauthenticated deep links

3. Hidden UI           ← convenience only; never trusted
```

The critical detail is that **`session.isAdmin` is never trusted**. It came
from the client. Every guard looks the membership up fresh:

```dart
final membership = await _organizations.findMembership(
  orgId: session.orgId,
  userId: session.user.id,
);
if (membership == null) throw const ForbiddenException(…);
if (!membership.isAdmin) throw const ForbiddenException(…);
```

`test/unit/project_authorization_test.dart` proves it by forging an
`AuthSession` for a member with `role: OrgRole.orgAdmin`, asserting
`forged.isAdmin == true`, and then showing the delete still throws.

**Cross-tenant returns 404, not 403.** "Forbidden" would confirm the resource
exists, which leaks one tenant's data to another.

---

## 9. Offline model

```
                    online                          offline
                      │                                │
  read  ──▶  asset / in-memory DB              persisted snapshot
             then snapshot to disk                     │
                      │                                │
  write ──▶  mutate DB, then snapshot         OfflineException
                                              "cannot be saved yet"
```

One snapshot of the whole database rather than per-collection entries, because
the collections reference each other and a half-updated cache would show tasks
belonging to projects that are not there.

Asymmetry is intentional and matches real offline-first behaviour: reading
stale data is useful, writing into a void is not. The banner in `AppShell`
reports when the snapshot was written, satisfying *"clearly indicate when
displayed data may be stale"*.

Not implemented: the bonus pending-operations queue that would let writes
happen offline and sync later.

---

## 10. What would change for a real backend

1. Write `HttpTaskFlowApi` with the same six methods as `MockJsonDataSource`,
   translating `SocketException` / non-2xx into `AppException` subtypes.
2. Change four lines in `core/di/providers.dart` to construct
   `Http*RepositoryImpl` instead of the mock-backed ones.
3. Move token attachment into an HTTP interceptor that calls
   `AuthRepository.refreshSession` on a 401.
4. Delete `assets/mock_data/` and `MockApiConfig`.

Everything in `domain/` and `presentation/` — every entity, usecase, provider,
screen and widget, and every unit test above the data layer — is untouched.
