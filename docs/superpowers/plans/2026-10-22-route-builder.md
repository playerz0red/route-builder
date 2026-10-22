# Route Builder (iOS) — план реализации

> **Для агентов-исполнителей:** ОБЯЗАТЕЛЬНЫЙ САБ-СКИЛЛ: superpowers:subagent-driven-development (рекомендуется) или superpowers:executing-plans. Шаги размечены чекбоксами (`- [ ]`).

**Цель:** iOS-приложение Route Builder из двух экранов (Stops и Instructions), которое переживает реальное поведение mock-сервиса и запускается на физическом iPhone.

**Архитектура:**
- Локальный Swift Package `RouteBuilderKit` с двумя библиотеками:
  - `RouteAPI` — транспорт, DTO, ошибки, повторы, пагинатор;
  - `RouteCore` — домен, чистые правила, `@MainActor`-сторы на `ObservableObject`.
- Приложение содержит только SwiftUI-вью, тему и сборку зависимостей.
- Зависимости строго в одну сторону: `App → RouteCore → RouteAPI`.

**Стек:** Swift 5 (language mode), SwiftUI, Combine (`ObservableObject`), XCTest, `URLSession`. Сторонних зависимостей нет.

**Спека:** `docs/superpowers/specs/2026-10-22-route-builder-design.md`. Исполнитель читает и спеку, и план. Ссылки вида «§N» ведут в спеку.

## Глобальные ограничения

- iOS deployment target **16.0**. Никаких API новее iOS 16.0: `@Observable`, `ContentUnavailableView`, `scrollTransition`, `scrollTargetBehavior`, `presentationCompactAdaptation` и т. п.
- Только iPhone, только портрет. Тема светлая: `.preferredColorScheme(.light)`.
- Swift language mode 5 и в пакете, и в приложении. У приложения `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`, `SWIFT_APPROACHABLE_CONCURRENCY = NO`. Сторы помечены `@MainActor` явно.
- Пакет: `swift-tools-version:5.9`, `platforms: [.iOS(.v16), .macOS(.v13)]`, ни одной зависимости. `RouteCore` не импортирует SwiftUI и UIKit.
- Base URL задаётся только в `RouteBuilder/Config/App.xcconfig` (`API_BASE_URL`) и попадает в приложение через `Info.plist` → `APIBaseURL`.
- Интерфейс на английском. Тексты UI берутся дословно из спеки (§7–§9).
- Шрифты SF Pro и SF Mono, размеры и цвета из §10.
- **Агент никогда не выполняет `git commit` и `git push`.** Каждая задача заканчивается передачей автору на коммит. Worktree и ветку агент создаёт сам.
- **Ручные шаги в Xcode** (задачи 3 и 4) автор делает в проекте **внутри worktree**, а не в основной рабочей копии.
- Команды проверки:
  - пакет: `cd RouteBuilderKit && swift test`;
  - приложение: `xcodebuild -project RouteBuilder/RouteBuilder.xcodeproj -scheme RouteBuilder -destination 'generic/platform=iOS Simulator' -derivedDataPath RouteBuilder/build build`, результат — `** BUILD SUCCEEDED **`. Путь `build/` уже в `.gitignore`.

## Фокус ревью

Пять ситуаций, которые вытекают из спеки, но которые ни одна задача не проверяет сама по себе. Для каждой ниже указан тест или проверка в задаче-владельце:

1. **Пользователь удаляет карточку, в поле которой стоит фокус (открыта клавиатура).** Ожидается: приложение не падает, индекс фокуса пересчитывается. → Задача 14: `FeedFocus.layout` с `activeIndex` за пределами массива ведёт себя как при `nil`. Задача 23: ручная проверка на симуляторе.
2. **Клавиатура закрывает поле последней карточки.** Ожидается: поле подскролливается и видно над клавиатурой и панелью Done. → Задача 24, проверка на симуляторе.
3. **Первый запуск: Local Network не разрешён или сервер выключен.** Ожидается: ошибка с Retry, а не бесконечный спиннер, и Retry восстанавливает каталог. → Задача 16: `testCatalogFailureThenRetryLoads`.
4. **Быстрый ввод в поиске упирается в 429 с длинным `Retry-After`.** Ожидается: «Too many requests. Try again in 39 s.», а не «No stop found». → Задача 16: `testSearch429ShowsFailedNotEmpty`, задача 13: `testCopyFor429WithRetryAfter`.
5. **Очень длинное имя (Roma Pizza — Central Bus Station…) в строке, чипе, окне количества и карточке.** Ожидается: многоточие, вёрстка не ломается, кнопки не уезжают. → Задачи 20, 21, 23: проверка на симуляторе с остановкой `stp_1016`.

---

## Структура файлов

```
RouteBuilderKit/
  Package.swift
  Sources/RouteAPI/
    Sleeper.swift                 Sleeper, TaskSleeper
    HTTPTransport.swift           HTTPTransport, URLSessionTransport
    APIConfiguration.swift        разбор base URL
    Decoding/FlexibleInt.swift, FlexibleDate.swift, LossyArray.swift
    DTO/StopDTO.swift, StopsPageDTO.swift, ErrorBodyDTO.swift, RouteDTO.swift
    APIError.swift                APIError, CreateRouteOutcome, маппинг
    RequestBuilder.swift          URLRequest для эндпоинтов
    RetryPolicy.swift
    StopPaginator.swift           StopPaginator, StopsResult
    APIClient.swift               APIClient: StopsAPI, RoutesAPI
    APIProtocols.swift            StopsAPI, RoutesAPI, CreatedRoute
  Sources/RouteCore/
    Models/Stop.swift, RouteStopDraft.swift
    Rules/StopListRules.swift, InstructionRules.swift, QuantityRules.swift,
          LocalSearch.swift, ErrorCopy.swift, FeedFocus.swift
    Stores/RouteDraftStore.swift, PickerStore.swift, SubmissionStore.swift
  Tests/RouteAPITests/            Fixtures/*.json, Support/FakeTransport.swift, *Tests.swift
  Tests/RouteCoreTests/           Support/{ManualSleeper,FakeStopsAPI,FakeRoutesAPI,StopFactory}.swift, *Tests.swift
  Tests/RouteAPILiveTests/        LiveServerTests.swift
RouteBuilder/
  Config/App.xcconfig, Config/Info.plist
  RouteBuilder/                   (synchronized group: новые файлы подхватываются сами)
    App/RouteBuilderApp.swift, AppEnvironment.swift, RootView.swift, AppRoute.swift, ConfigErrorView.swift
    Theme/Colors.swift, Typography.swift, Metrics.swift
    Components/PrimaryButton.swift, AvatarView.swift, ErrorBanner.swift
    Features/Picker/…, Features/Instructions/…, Features/Success/SuccessScreen.swift
README.md, DECISIONS.md, AI_PROCESS.md, docs/ai/verification.md
```

---

## Часть A. Каркас

### Задача 1: Настройки языка и конкурентности приложения

**Файлы:**
- Изменить: `RouteBuilder/RouteBuilder.xcodeproj/project.pbxproj`, конфигурации Debug и Release таргета `RouteBuilder` (сейчас это примерно строки 277–278 и 314–315).

**Интерфейсы:** не производит.

- [ ] **Шаг 1.** В обеих конфигурациях таргета заменить:
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES;` → `SWIFT_APPROACHABLE_CONCURRENCY = NO;`
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;` → `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated;`

  Остальное не трогать: `SWIFT_VERSION = 5.0`, `IPHONEOS_DEPLOYMENT_TARGET = 16`.
- [ ] **Шаг 2.** Выполнить `xcodebuild -project RouteBuilder/RouteBuilder.xcodeproj -target RouteBuilder -showBuildSettings | grep -E 'SWIFT_DEFAULT_ACTOR_ISOLATION|SWIFT_APPROACHABLE_CONCURRENCY|SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET'`.

  Ожидается: `nonisolated`, `NO`, `5.0`, `16.0`.
- [ ] **Шаг 3.** Собрать приложение командой из глобальных ограничений. Ожидается `** BUILD SUCCEEDED **`.
- [ ] **Шаг 4.** Передать автору на коммит. Предлагаемое сообщение: `Configure app target: Swift 5 mode, nonisolated default isolation`.

### Задача 2: Скелет Swift Package

**Файлы:**
- Создать: `RouteBuilderKit/Package.swift`, `Sources/RouteAPI/Sleeper.swift`, `Sources/RouteCore/Models/Stop.swift` (пока пустой `public struct Stop {}`), `Tests/RouteAPITests/SmokeTests.swift`, `Tests/RouteCoreTests/SmokeTests.swift`, `Tests/RouteAPITests/Fixtures/.gitkeep`.

**Интерфейсы:**
- Производит:
  - продукты `RouteAPI` и `RouteCore`;
  - `public protocol Sleeper: Sendable { func sleep(seconds: Double) async throws }`;
  - `public struct TaskSleeper: Sleeper { public init() }` — внутри `Task.sleep(nanoseconds:)`, при отмене бросает `CancellationError`.

- [ ] **Шаг 1.** `Package.swift`:
  - таргеты `RouteAPI`, `RouteCore` (зависит от `RouteAPI`);
  - `RouteAPITests` с `resources: [.copy("Fixtures")]`;
  - `RouteCoreTests`;
  - `RouteAPILiveTests` (зависит от `RouteAPI`, пока с одним пустым файлом);
  - библиотечные продукты `RouteAPI` и `RouteCore`.
- [ ] **Шаг 2.** Smoke-тесты: `testTaskSleeperThrowsWhenCancelled`. Запускаем `Task { try await TaskSleeper().sleep(seconds: 10) }`, сразу отменяем, проверяем, что `await task.result` содержит ошибку `CancellationError`.
- [ ] **Шаг 3.** Выполнить `cd RouteBuilderKit && swift test`. Ожидается: PASS, 0 failures.
- [ ] **Шаг 4.** Передать автору на коммит: `Add RouteBuilderKit package skeleton`.

### Задача 3: Подключение пакета к приложению (ручной шаг автора)

**Файлы:**
- Изменить: `RouteBuilder/RouteBuilder/RouteBuilderApp.swift`, добавить `import RouteAPI` и `import RouteCore`.

- [ ] **Шаг 1. Автор, в Xcode внутри worktree:** File → Add Package Dependencies → Add Local… → выбрать `RouteBuilderKit`. В таргет `RouteBuilder` добавить **обе** библиотеки: `RouteAPI` и `RouteCore`.
- [ ] **Шаг 2. Агент:** добавить в `RouteBuilderApp.swift` оба `import` и собрать приложение. Ожидается `** BUILD SUCCEEDED **`. Если ошибка «no such module», значит, одна из библиотек не добавлена, вернуться к шагу 1.
- [ ] **Шаг 3.** Передать автору на коммит: `Link RouteBuilderKit to app target` (в коммит входят `project.pbxproj` и `RouteBuilderApp.swift`).

### Задача 4: Конфигурация base URL, Info.plist и проверка на iPhone

**Файлы:**
- Создать: `RouteBuilder/Config/App.xcconfig`, `RouteBuilder/Config/Info.plist`, `RouteBuilderKit/Sources/RouteAPI/APIConfiguration.swift`, `RouteBuilderKit/Tests/RouteAPITests/APIConfigurationTests.swift`.
- Изменить: `project.pbxproj` (`INFOPLIST_FILE = Config/Info.plist;` в Debug и Release таргета) и `RouteBuilder/RouteBuilder/ContentView.swift` (временная проверка связи, её заменит задача 19).

**Интерфейсы:**
- Производит: `public enum APIConfiguration { public static let infoPlistKey = "APIBaseURL"; public static func baseURL(fromInfoValue value: Any?) -> URL? }`.
  - Возвращает URL, только если `value` — строка со схемой `http` или `https` и непустым host.
  - Пустая строка, `"$(API_BASE_URL)"` (переменная не подставилась), отсутствие схемы → `nil`.

- [ ] **Шаг 1. Тесты** `APIConfigurationTests`:
  - `testValidHTTPURL` — `"http://10.204.20.147:4000"` → URL с host `10.204.20.147` и портом 4000;
  - `testRejectsNil`, `testRejectsEmpty`;
  - `testRejectsUnexpandedVariable` (`"$(API_BASE_URL)"`);
  - `testRejectsMissingScheme` (`"10.204.20.147:4000"`);
  - `testRejectsNonString` (`42`).
- [ ] **Шаг 2.** `swift test --filter APIConfigurationTests`. Ожидается FAIL: `APIConfiguration` не определён.
- [ ] **Шаг 3.** Реализовать `APIConfiguration.baseURL(fromInfoValue:)`.
- [ ] **Шаг 4.** `swift test --filter APIConfigurationTests`. Ожидается PASS.
- [ ] **Шаг 5.** `App.xcconfig` — дословно из §11 спеки. `Info.plist`:
  - `APIBaseURL` = `$(API_BASE_URL)`;
  - `NSAppTransportSecurity` → `NSAllowsLocalNetworking` = `true`;
  - `NSLocalNetworkUsageDescription` = «Route Builder connects to the dispatch server on your local network.».

  Добавить в pbxproj `INFOPLIST_FILE = Config/Info.plist;`, а `GENERATE_INFOPLIST_FILE = YES` оставить.
- [ ] **Шаг 6. Автор, в Xcode внутри worktree:**
  1. перетащить `RouteBuilder/Config/App.xcconfig` в навигатор проекта, **не** отмечая target membership;
  2. Project → Info → Configurations: для таргета RouteBuilder в Debug и Release выбрать `App`.
- [ ] **Шаг 7. Агент:** собрать приложение, затем выполнить `plutil -p RouteBuilder/build/Build/Products/Debug-iphonesimulator/RouteBuilder.app/Info.plist | grep -E 'APIBaseURL|NSAllowsLocalNetworking|NSLocalNetworkUsageDescription'`.

  Ожидается `"APIBaseURL" => "http://10.204.20.147:4000"`, `NSAllowsLocalNetworking` — 1, текст описания на месте.
- [ ] **Шаг 8.** Временный `ContentView`:
  - читает `Bundle.main.object(forInfoDictionaryKey: APIConfiguration.infoPlistKey)`;
  - если адрес не разобрался — показывает «API base URL is not configured»;
  - иначе делает `GET /health` через `URLSession.shared` и выводит тело ответа или `URLError.code`.
- [ ] **Шаг 9. Автор, на iPhone:** собрать на устройство с сервером `node server.js` на Mac. Ожидается:
  - системный запрос доступа к Local Network, после разрешения — `{"ok":true,...}`;
  - если `URLError -1022` (ATS): применить запасной вариант из §11 — создать `Config/Info-Debug.plist` (копия плюс `NSAllowsArbitraryLoads = true`), в Debug указать `INFOPLIST_FILE = Config/Info-Debug.plist`, проверить ещё раз и записать решение в черновик DECISIONS (задача 26).
- [ ] **Шаг 10.** Передать автору на коммит: `Add base URL config, Info.plist with ATS and Local Network keys`.

---

## Часть B. RouteAPI (TDD)

### Задача 5: Гибкое декодирование и DTO

**Файлы:**
- Создать: `Decoding/FlexibleInt.swift`, `Decoding/FlexibleDate.swift`, `Decoding/LossyArray.swift`, `DTO/StopDTO.swift`, `DTO/StopsPageDTO.swift`, `DTO/ErrorBodyDTO.swift`, `DTO/RouteDTO.swift`.
- Фикстуры:
  - `Tests/RouteAPITests/Fixtures/stops_page1_size50.json`, `search_sov_null.json`, `route_created.json` — сняты с живого сервера;
  - `stops_lossy.json` — написан вручную.
- Тесты: `DecodingTests.swift`.

**Интерфейсы:**
- Производит:
  - `public struct FlexibleInt: Decodable, Sendable { public let value: Int? }` — `Int` → значение; строка с `Int` → значение; ≤0, `null`, мусор → `nil`. **Никогда не бросает ошибку.**
  - `public struct FlexibleDate: Decodable, Sendable { public let value: Date? }` — ISO 8601 с долями секунды и без, с `Z` и без (без `Z` → UTC); число → epoch в секундах; иначе `nil`. Никогда не бросает.
  - `public struct LossyArray<Element: Decodable>: Decodable { public let elements: [Element]; public let skippedCount: Int }`.
  - `public struct StopDTO: Decodable, Sendable, Equatable { public let id, name, address, phone: String; public let packagesMax: Int?; public let lastDeliveryAt: Date?; public let zone: String?; public let notes: String? }` — правила полей из §5.2. Пустой или отсутствующий `id` или `name` → ошибка декодирования, `LossyArray` такую запись пропустит.
  - `public struct StopsPageDTO: Decodable, Sendable { public let items: [StopDTO]; public let skippedCount: Int; public let page: Int? }` — `items: null` или отсутствие поля → `[]`.
  - `public struct ErrorBodyDTO: Decodable { public let error: String? }`.
  - `public struct RouteStopPayload: Codable, Sendable, Equatable { public let stopID: String; public let packages: Int; public let instructions: String }` — ключи `stop_id`, `packages`, `instructions`.
  - `public struct CreateRouteResponseDTO: Decodable { public let id: String; public let stops: [RouteStopPayload]?; public let status: String? }`.

- [ ] **Шаг 1. Снять фикстуры.** Свежий сервер `node server.js 4123`, **не больше 8 запросов**: хаос срабатывает на 9-м запросе по общему счётчику.
  ```bash
  curl -s 'http://localhost:4123/v1/stops?page=1&page_size=50' > …/Fixtures/stops_page1_size50.json
  curl -s 'http://localhost:4123/v1/stops?q=sov' > …/Fixtures/search_sov_null.json
  curl -s -X POST -d '{"stops":[{"stop_id":"stp_1002","packages":2,"instructions":"Enter from the parking lot"}]}' http://localhost:4123/v1/routes > …/Fixtures/route_created.json
  ```
  Остановить сервер. `stops_lossy.json` — 4 элемента:
  - валидный;
  - без `id`;
  - с `name: ""`;
  - с `packages_max: "abc"` и `last_delivery_at: "yesterday"` (запись валидна, оба поля дают `nil`).
- [ ] **Шаг 2. Тесты** (`DecodingTests`):
  - `testFlexibleIntVariants` — `5` → 5, `"7"` → 7, `null` → nil, `"abc"` → nil, `0` → nil, `-3` → nil;
  - `testFlexibleDateVariants` — `"2026-10-22T08:37:32.584Z"`, `"2026-10-22T08:37:32.584"` (без `Z`, тот же момент в UTC), `1792651052` → `Date(timeIntervalSince1970: 1792651052)`, `"yesterday"` → nil;
  - `testRealPageDecodesAll24` — 24 записи, `skippedCount == 0`; у `stp_1000` `packagesMax == nil` и `notes == nil`; у `stp_1003` `packagesMax == 7` (пришло строкой `"7"`); у `stp_1002` `lastDeliveryAt != nil` (пришло epoch);
  - `testNullItemsBecomesEmpty` — `search_sov_null.json` → `items.isEmpty`;
  - `testLossyArraySkipsInvalid` — 2 элемента, `skippedCount == 2`;
  - `testRouteCreatedDecodes` — `id == "rt_2000"`, `stops?.first?.stopID == "stp_1002"`;
  - `testPayloadEncodesSnakeCase` — JSON содержит `"stop_id"`.
- [ ] **Шаг 3.** `swift test --filter DecodingTests`. Ожидается FAIL: типы не определены.
- [ ] **Шаг 4.** Реализовать типы.
- [ ] **Шаг 5.** `swift test --filter DecodingTests`. Ожидается PASS.
- [ ] **Шаг 6.** Передать автору на коммит: `Add lenient DTO decoding with server fixtures`.

### Задача 6: APIError, классификация и исходы POST

**Файлы:** создать `APIError.swift` и `Tests/RouteAPITests/APIErrorTests.swift`.

**Интерфейсы:**
- Производит:
  ```swift
  public enum APIError: Error, Sendable, Equatable {
      case cancelled
      case notDelivered(URLError.Code)
      case ambiguous(URLError.Code)
      case http(status: Int, code: String?, retryAfter: Double?)
      case decoding
  }
  public enum CreateRouteOutcome: Equatable, Sendable { case notCreated, maybeCreated, rejected }
  extension APIError {
      public static func from(_ error: Error) -> APIError          // порядок маппинга §5.3
      public static func from(response: HTTPURLResponse, body: Data) -> APIError   // .http(...)
      public static func parseRetryAfter(_ header: String?) -> Double?
      public var createRouteOutcome: CreateRouteOutcome             // таблица §5.3
  }
  ```
  `from(_:)`: уже готовый `APIError` возвращается как есть; ошибка `DecodingError` → `.decoding`.

- [ ] **Шаг 1. Тесты** (`APIErrorTests`):
  - `testCancellationMapsFirst` — и `URLError(.cancelled)`, и `CancellationError()` → `.cancelled`;
  - `testNotDeliveredCodes` — `.notConnectedToInternet`, `.cannotConnectToHost`, `.cannotFindHost`, `.dnsLookupFailed` → `.notDelivered`;
  - `testOtherURLErrorsAreAmbiguous` — `.timedOut`, `.networkConnectionLost`, `.secureConnectionFailed`, `.appTransportSecurityRequiresSecureConnection` → `.ambiguous`;
  - `testHTTPMapping` — 503 с `Retry-After: 2` и телом `{"error":"upstream_unavailable"}` → `.http(status: 503, code: "upstream_unavailable", retryAfter: 2)`; тело без JSON → `code == nil`;
  - `testParseRetryAfter` — `"39"` → 39, `nil` → nil, `"soon"` → nil;
  - `testCreateRouteOutcomeTable` — `.notDelivered` → `.notCreated`; `.ambiguous(.timedOut)` → `.maybeCreated`; `.ambiguous(.networkConnectionLost)` → `.maybeCreated`; `.decoding` → `.maybeCreated`; `.cancelled` → `.maybeCreated`; HTTP 400 → `.rejected`; 404 → `.rejected`; 422 → `.rejected`; 429 → `.notCreated`; 500 → `.notCreated`; 501 → `.notCreated`; 502 → `.maybeCreated`; 503 → `.notCreated`; 504 → `.maybeCreated`.
- [ ] **Шаг 2.** `swift test --filter APIErrorTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** `swift test --filter APIErrorTests`. Ожидается PASS.
- [ ] **Шаг 5.** Передать автору на коммит: `Add APIError classification and create-route outcomes`.

### Задача 7: Транспорт, сборка запросов и политика повторов

**Файлы:**
- Создать: `HTTPTransport.swift`, `RequestBuilder.swift`, `RetryPolicy.swift`, `Tests/RouteAPITests/Support/FakeTransport.swift`, `RequestBuilderTests.swift`, `RetryPolicyTests.swift`.

**Интерфейсы:**
- Потребляет: `APIError` (задача 6), `Sleeper` (задача 2).
- Производит:
  - `public protocol HTTPTransport: Sendable { func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) }`.
  - `public struct URLSessionTransport: HTTPTransport { public init(session: URLSession = .shared) }`. Ответ не HTTP → `APIError.decoding`.
  - `struct RequestBuilder` (internal, `init(baseURL: URL)`):
    - `func stops(page: Int, pageSize: Int, query: String?) -> URLRequest` — GET, таймаут 10 с;
    - `func createRoute(_ stops: [RouteStopPayload]) throws -> URLRequest` — POST, таймаут 30 с, `Content-Type: application/json`.

    `+` в `q` кодируется как `%2B`; пустой или `nil` `query` → параметра `q` нет.
  - `public struct RetryPolicy: Sendable { public static let `default`; public let maxRetries: Int /*2*/; public let maxWait: Double /*5*/; public func delay(for error: APIError, retryNumber: Int) -> Double? }`:
    - `nil` — не повторять;
    - `retryNumber` начинается с 1;
    - значения по §5.4.
  - `func send(_ request: URLRequest, retrying: Bool) async throws -> (Data, HTTPURLResponse)` внутри `APIClient` (internal):
    - не 2xx → `APIError.from(response:body:)`;
    - ошибка транспорта → `APIError.from(_:)`;
    - при `retrying == true` повторы идут по политике через `Sleeper`.

    Сам `APIClient` объявляется в этой задаче: `public struct APIClient: Sendable { public init(baseURL: URL, transport: HTTPTransport, sleeper: Sleeper, retryPolicy: RetryPolicy = .default) }`.
- Тестовая поддержка: `final class FakeTransport: HTTPTransport, @unchecked Sendable`:
  - `var responses: [Result<(Int, [String: String], Data), Error>]` — отдаются по очереди;
  - `private(set) var requests: [URLRequest]`;
  - доступ защищён `NSLock`.
- Тестовая поддержка: `struct RecordingSleeper: Sleeper` пишет запрошенные задержки в общий массив и сразу возвращает управление.

- [ ] **Шаг 1. Тесты:**
  - `RequestBuilderTests.testQueryEncoding` — `q = "Taylor & Sons +44"` → в URL `q=Taylor%20%26%20Sons%20%2B44`;
  - `RequestBuilderTests.testNoQueryForBlank`;
  - `RequestBuilderTests.testPageParams` (`page=2&page_size=50`);
  - `RequestBuilderTests.testCreateRouteRequest` — метод POST, таймаут 30, тело декодируется обратно в `[RouteStopPayload]`;
  - `RetryPolicyTests.testDelays` — `.http(500)` → 0.5; `.http(503, retryAfter: 2)` → 2; `.http(503, nil)` → 2; `.http(503, retryAfter: 30)` → 5; `.http(429, retryAfter: 3)` → 3; `.http(429, retryAfter: 39)` → nil; `.notDelivered` → nil; `.ambiguous(.timedOut)` → nil; `.decoding` → nil; `.http(404)` → nil; `retryNumber: 3` → nil при любой ошибке;
  - `RetryPolicyTests.testClientRetriesGetThenSucceeds` — `FakeTransport` отвечает 500, затем 200: результат 200, сделано 2 запроса, задержка `[0.5]`;
  - `RetryPolicyTests.testClientGivesUpAfterTwoRetries` — 500 ×3 → бросает `.http(status: 500, …)`, сделано 3 запроса;
  - `RetryPolicyTests.testNoRetryWhenDisabled` — `retrying: false`, ответ 503 → 1 запрос.
- [ ] **Шаг 2.** `swift test --filter "RequestBuilderTests|RetryPolicyTests"`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS.
- [ ] **Шаг 5.** Передать автору на коммит: `Add transport, request builder and GET retry policy`.

### Задача 8: Пагинатор и StopsAPI

**Файлы:** создать `StopPaginator.swift`, `APIProtocols.swift`; изменить `APIClient.swift`; тест `StopPaginatorTests.swift`.

**Интерфейсы:**
- Потребляет: `StopsPageDTO`, `APIClient.send(_:retrying:)`, `RequestBuilder.stops`.
- Производит:
  - `public struct StopsResult: Sendable, Equatable { public let stops: [StopDTO]; public let skippedCount: Int; public let truncated: Bool }`.
  - `public struct StopPaginator: Sendable { public static let pageSize = 50; public static let maxPages = 10; public static func collect(fetchPage: (Int) async throws -> StopsPageDTO) async throws -> StopsResult }` — правила §5.5. Ошибка любой страницы → ошибка всего обхода.
  - `public protocol StopsAPI: Sendable { func fetchAllStops() async throws -> StopsResult; func searchStops(query: String) async throws -> StopsResult }` — бросает только `APIError`.
  - `APIClient: StopsAPI`: GET с `retrying: true`, `page_size=50`.

- [ ] **Шаг 1. Тесты** (`StopPaginatorTests`, страницы строятся в коде хелпером `page(_ ids: [String])`):
  - `testSinglePartialPageStops` — 24 записи на странице 1 → 1 вызов, 24 записи;
  - `testShiftedPageIsDeduplicated` — страница 1: `s0…s49`; страница 2: `s49, s50…s98` (50 записей, первая — дубль); страница 3: `s100…s119` → 3 вызова, 119 уникальных `id`, без дублей;
  - `testEmptyPageStops` — страница 1: 50 записей, страница 2: `[]` → 2 вызова;
  - `testNoNewIDsStops` — страница 2 повторяет страницу 1 → 2 вызова, 50 записей;
  - `testMaxPagesTruncates` — каждая страница 50 новых → 10 вызовов, `truncated == true`;
  - `testErrorOnSecondPageFailsWhole` — страница 2 бросает `.http(500)` → `collect` бросает ошибку;
  - `testClientSearchSendsQuery` — через `FakeTransport`: `searchStops(query: "Sov")` → URL содержит `q=Sov` и `page_size=50`.
- [ ] **Шаг 2.** `swift test --filter StopPaginatorTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS.
- [ ] **Шаг 5.** Передать автору на коммит: `Add stop paginator with dedup and stop rules`.

### Задача 9: createRoute и RoutesAPI

**Файлы:** изменить `APIProtocols.swift`, `APIClient.swift`; тест `CreateRouteTests.swift`.

**Интерфейсы:**
- Производит:
  - `public struct CreatedRoute: Sendable, Hashable { public let id: String; public let status: String?; public let alteredStopIDs: [String] }`;
  - `public protocol RoutesAPI: Sendable { func createRoute(_ stops: [RouteStopPayload]) async throws -> CreatedRoute }`;
  - `APIClient: RoutesAPI` — POST с `retrying: false`, `alteredStopIDs` по §5.7.

- [ ] **Шаг 1. Тесты** (`CreateRouteTests`):
  - `testCreatesRoute` — фикстура `route_created.json` → `id == "rt_2000"`, `alteredStopIDs == []`;
  - `testDetectsAlteredInstructions` — сервер вернул инструкцию короче отправленной → `alteredStopIDs == ["stp_1002"]`;
  - `testMissingStopsMeansNoAltered`;
  - `testNeverRetriesPOST` — для каждого ответа из списка [HTTP 500, HTTP 503 с `Retry-After: 1`, `URLError(.timedOut)`] ровно 1 запрос, брошена соответствующая `APIError`;
  - `test2xxWithGarbageIsDecoding` — 201 с телом `"oops"` → `.decoding`.
- [ ] **Шаг 2.** `swift test --filter CreateRouteTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS.
- [ ] **Шаг 5.** Передать автору на коммит: `Add createRoute without retries and altered-stops check`.

### Задача 10: Живые тесты (opt-in)

**Файлы:** создать `Tests/RouteAPILiveTests/LiveServerTests.swift`.

- [ ] **Шаг 1.** Тесты. Если переменная `ROUTE_API_LIVE_URL` не задана, `setUpWithError` бросает `XCTSkip`. Клиент — `APIClient` с `URLSessionTransport` и `TaskSleeper`.
  - `testCatalogHasNoDuplicateIDs` — `Set(ids).count == ids.count`, `!stops.isEmpty`;
  - `testServerSearchIsCaseSensitive` — `searchStops("sov").stops.isEmpty` и `searchStops("Sov").stops.map(\.id).contains("stp_1002")`.
- [ ] **Шаг 2.** `swift test`. Ожидается: live-тесты skipped, остальные PASS.
- [ ] **Шаг 3.** Свежий `node server.js` и `ROUTE_API_LIVE_URL=http://localhost:4000 swift test --filter RouteAPILiveTests`. Ожидается PASS.
- [ ] **Шаг 4.** Передать автору на коммит: `Add opt-in live tests against server.js`.

---

## Часть C. RouteCore (TDD)

### Задача 11: Модель Stop и правила списка

**Файлы:**
- Изменить: `Models/Stop.swift`.
- Создать: `Rules/StopListRules.swift`, `Tests/RouteCoreTests/Support/StopFactory.swift`, `StopListRulesTests.swift`.

**Интерфейсы:**
- Производит:
  - `public struct Stop: Identifiable, Hashable, Sendable { public let id, name, address, phone: String; public let packagesMax: Int?; public let lastDeliveryAt: Date?; public let zone: String?; public init(dto: StopDTO); public init(id:name:address:phone:packagesMax:lastDeliveryAt:zone:) }` — `Hashable` и `==` только по `id`;
  - `public struct StopSection: Identifiable, Equatable { public let id: String; public let stops: [Stop] }`;
  - `public enum StopListRules`:
    - `initials(for name: String) -> String`;
    - `sectionKey(for name: String) -> String` (A–Z или `#`);
    - `sorted(_ stops: [Stop]) -> [Stop]` (`localizedStandardCompare`);
    - `sections(_ stops: [Stop]) -> [StopSection]` (A–Z, `#` последним);
    - `avatarIndex(for id: String, paletteCount: Int = 5) -> Int`.
- Тестовая поддержка: `StopFactory.stop(_ id: String, _ name: String, packagesMax: Int? = nil, phone: String = "020 7946 0000") -> Stop`.

- [ ] **Шаг 1. Тесты** (`StopListRulesTests`):
  - `testInitialsTable` — точная таблица из §6.2, плюс `"Isaac's Hardware"` → `IH`, `"North Cafe"` → `NC`, `"Zita"` → `Z`;
  - `testSectionKeys` — `"Éden"` → `E`, `"24/7 Pharmacy"` → `#`, `"The Little Zoo"` → `T`, `"zen"` → `Z`;
  - `testSectionsOrderHashLast` — секции по алфавиту, `#` последняя, внутри секции записи отсортированы;
  - `testSortedIsCaseInsensitive` — `["beta", "Alpha", "gamma"]` → `Alpha, beta, gamma`;
  - `testAvatarIndexStableAndInRange` — `avatarIndex(for: "stp_1002")` равен значению, посчитанному вручную по сумме скаляров `% 5`, и всегда в `0..<5`;
  - `testStopFromDTOCopiesFields`.
- [ ] **Шаг 2.** `swift test --filter StopListRulesTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS.
- [ ] **Шаг 5.** Передать автору на коммит: `Add Stop model and list rules`.

### Задача 12: Правила ввода, локального поиска и количества

**Файлы:** создать `Rules/InstructionRules.swift`, `Rules/QuantityRules.swift`, `Rules/LocalSearch.swift` и тесты `InputRulesTests.swift`.

**Интерфейсы:**
- `public enum InstructionRules { public static let limit = 200; static func clamp(_ text: String) -> String; static func count(_ text: String) -> Int /* utf16 */; static func isBlank(_ text: String) -> Bool; static func normalizedForSending(_ text: String) -> String /* trim */ }`.
- `public enum QuantityRules { public static let fallbackMax = 99; static func range(for stop: Stop) -> ClosedRange<Int>; static func showsMaxCaption(for stop: Stop) -> Bool; static func clamp(_ value: Int, for stop: Stop) -> Int }`.
- `public enum LocalSearch { static func matches(_ stop: Stop, query: String) -> Bool; static func filter(_ stops: [Stop], query: String) -> [Stop]; static func highlightRange(in name: String, query: String) -> Range<String.Index>? }` — правила §6.2.

- [ ] **Шаг 1. Тесты** (`InputRulesTests`):
  - `testClampKeepsShortText`;
  - `testClampCutsAt200UTF16` — `String(repeating: "a", count: 240)` → длина 200;
  - `testClampNeverSplitsEmoji` — `String(repeating: "a", count: 199) + "😀"` (U+1F600, 2 code units) → результат 199 символов `a`, `count == 199`;
  - `testCountIsUTF16` — `"😀"` → 2;
  - `testIsBlank` — `"  \n "` → true, `" a "` → false;
  - `testNormalizedTrims`;
  - `testQuantityRange` — `packagesMax: 6` → `1...6` и подпись показывается; `nil` → `1...99` и подписи нет;
  - `testQuantityClamp` — 0 → 1, 12 при `max` 6 → 6;
  - `testLocalSearchCaseAndDiacritics` — `"sov"` находит «Sova Studio Gallery», `"eden"` находит «Éden Market», `"king st"` находит адрес «42 King St, Northbridge»;
  - `testLocalSearchPhoneDigits` — `"0477"` находит телефон `02079460477`; `"04"` (2 цифры) по телефону не ищет;
  - `testHighlightRange` — `highlightRange(in: "Sova Studio Gallery", query: "sov")` → диапазон `"Sov"`.
- [ ] **Шаг 2.** `swift test --filter InputRulesTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS.
- [ ] **Шаг 5.** Передать автору на коммит: `Add instruction, quantity and local search rules`.

### Задача 13: Тексты ошибок

**Файлы:** создать `Rules/ErrorCopy.swift` и тест `ErrorCopyTests.swift`.

**Интерфейсы:** `public enum ErrorCopy { public static func message(for error: APIError) -> String }` — тексты из таблицы §9.3 дословно:
- `.ambiguous` → «The server didn't respond in time.»;
- прочие 4xx на GET → «Request failed (HTTP {status}).»;
- `.cancelled` → `""` (вызывающий код такую ошибку не показывает).

- [ ] **Шаг 1. Тесты** (`ErrorCopyTests`):
  - `testCopyNotDelivered`;
  - `testCopyFor429WithRetryAfter` — `.http(429, retryAfter: 39)` → «Too many requests. Try again in 39 s.»;
  - `testCopyFor429WithoutRetryAfter` → «Too many requests. Try again in a minute.»;
  - `testCopyFor5xx` — 503 → «The server had a problem (HTTP 503).»;
  - `testCopyFor404` → «Request failed (HTTP 404).»;
  - `testCopyDecoding`;
  - `testCopyAmbiguous`.
- [ ] **Шаг 2.** `swift test --filter ErrorCopyTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS.
- [ ] **Шаг 5.** Передать автору на коммит: `Add user-facing error copy`.

### Задача 14: Фокус ленты

**Файлы:** создать `Rules/FeedFocus.swift` и тест `FeedFocusTests.swift`.

**Интерфейсы:**
```swift
public struct CardVisual: Equatable, Sendable { public let scaleX, scaleY, opacity: Double; public let isFocused: Bool }
public struct FeedLayout: Equatable, Sendable { public let focusedIndex: Int?; public let cards: [CardVisual] }
public enum FeedFocus { public static func layout(distances: [Double], cardHeight: Double, activeIndex: Int?) -> FeedLayout }
```
Формулы — §6.2. `activeIndex` за пределами `distances` ведёт себя как `nil`. Пустой массив даёт `focusedIndex == nil` и `cards == []`. При `cardHeight <= 0` считаем `t = 0`.

- [ ] **Шаг 1. Тесты** (`FeedFocusTests`, сравнение с точностью 0.0001):
  - `testNearestToCenterIsFocused` — `distances [-400, 20, 450]`, `cardHeight 420`, `nil` → `focusedIndex 1`; у карточки 1 масштаб ≈ (0.990476, 0.997143), прозрачность ≈ 0.983333; у карточки 2 — ровно (0.8, 0.94, 0.65);
  - `testActiveFieldWinsOverGeometry` — те же расстояния, `activeIndex: 0` → `focusedIndex 0`, у карточки 0 значения (1, 1, 1) и `isFocused`; у карточки 1 `isFocused == false`, значения по геометрии;
  - `testActiveIndexOutOfBoundsIsIgnored` — `activeIndex: 5` при 3 карточках → результат как при `nil` (Фокус ревью, п. 1);
  - `testEmpty`.
- [ ] **Шаг 2.** `swift test --filter FeedFocusTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS.
- [ ] **Шаг 5.** Передать автору на коммит: `Add feed focus layout rules`.

### Задача 15: RouteDraftStore

**Файлы:** создать `Models/RouteStopDraft.swift`, `Stores/RouteDraftStore.swift` и тест `RouteDraftStoreTests.swift`.

**Интерфейсы:**
```swift
public enum SelectionMode: Sendable { case single, multi }
public struct RouteStopDraft: Identifiable, Equatable, Sendable {
    public var id: String { stop.id }
    public let stop: Stop; public var packages: Int; public var instruction: String; public var hasError: Bool
}
public struct RouteTotals: Equatable { public let packages: Int; public let stops: Int }
public enum ChangeResult: Equatable { case applied(becameEmpty: Bool), needsConfirmation(names: [String]) }

@MainActor public final class RouteDraftStore: ObservableObject {
    @Published public private(set) var stops: [RouteStopDraft] = []
    public init()
    public func isSelected(_ id: String) -> Bool
    public func draft(for id: String) -> RouteStopDraft?
    public var totals: RouteTotals { get }
    public func toggle(_ stop: Stop, mode: SelectionMode) -> ChangeResult   // выбор, снятие или замена (§6.3)
    public func confirmToggle(_ stop: Stop, mode: SelectionMode)            // то же без проверки инструкций
    public func remove(_ id: String) -> ChangeResult
    public func confirmRemove(_ id: String) -> ChangeResult                 // всегда .applied
    public func applyMode(_ mode: SelectionMode) -> ChangeResult            // Multi → One: остаётся последняя
    public func confirmApplyMode(_ mode: SelectionMode)
    public func setPackages(_ value: Int, for id: String)                   // QuantityRules.clamp
    public func setInstruction(_ text: String, for id: String)              // InstructionRules.clamp, снимает hasError, если не пусто
    public func clearInstruction(for id: String)
    @discardableResult public func validate() -> [String]                  // ставит hasError, возвращает id по порядку
    public func payload() -> [RouteStopPayload]                             // порядок выбора, normalizedForSending
    public func reset()
}
```
`needsConfirmation(names:)` возвращается, только если у затрагиваемых остановок `!InstructionRules.isBlank(instruction)`.

- [ ] **Шаг 1. Тесты** (`RouteDraftStoreTests`, каждый `@MainActor`):
  - `testMultiAppendsInSelectionOrder` — выбрали C, A, B → порядок `[C, A, B]`, у каждой количество 1;
  - `testToggleSelectedRemoves`;
  - `testSingleReplaces`;
  - `testSingleReplaceWithInstructionNeedsConfirmation` — `.needsConfirmation(names: ["A"])`, выбор не изменился; после `confirmToggle` выбран B;
  - `testMultiToSingleKeepsLast` — `[A, B, C]` → `.applied`, остался `[C]`;
  - `testMultiToSingleWithInstructionsNeedsConfirmation`;
  - `testRemoveEmptyInstructionApplies` — удаление последней → `.applied(becameEmpty: true)`;
  - `testRemoveWithInstructionNeedsConfirmation` — инструкция `"   "` (пустая после trim) → `.applied`, инструкция `"Ring"` → `.needsConfirmation`;
  - `testSetPackagesClamps` — `packagesMax` 6, установить 12 → 6;
  - `testValidateFlagsBlankAndClearsOnInput`;
  - `testInstructionIsClamped`;
  - `testTotals` — количества 12, 3, 6, 4 → `RouteTotals(packages: 25, stops: 4)`;
  - `testPayloadTrimsAndKeepsOrder`;
  - `testReset`.
- [ ] **Шаг 2.** `swift test --filter RouteDraftStoreTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS.
- [ ] **Шаг 5.** Передать автору на коммит: `Add RouteDraftStore`.

### Задача 16: PickerStore — каталог и поиск

**Файлы:** создать `Stores/PickerStore.swift`, `Tests/RouteCoreTests/Support/ManualSleeper.swift`, `Support/FakeStopsAPI.swift` и тест `PickerStoreTests.swift`.

**Интерфейсы:**
```swift
public enum CatalogState: Equatable { case loading, loaded([Stop]), failed(APIError) }
public enum SearchState: Equatable { case idle, searching, results([Stop]), empty, failed(APIError) }

@MainActor public final class PickerStore: ObservableObject {
    @Published public private(set) var catalog: CatalogState = .loading
    @Published public private(set) var query: String = ""
    @Published public private(set) var search: SearchState = .idle
    @Published public private(set) var mode: SelectionMode = .single
    public init(api: StopsAPI, draft: RouteDraftStore, sleeper: Sleeper, debounce: Double = 0.35)
    public var sections: [StopSection] { get }          // из .loaded, через StopListRules.sections
    public func load() async                              // повторный вызов при .loaded ничего не делает
    public func reload() async
    public func updateQuery(_ text: String)
    public func retrySearch()
    public func setMode(_ mode: SelectionMode) -> ChangeResult   // делегирует в draft.applyMode
    public func confirmSetMode(_ mode: SelectionMode)
    public func reset()                                   // query "", search .idle, mode .single; каталог не трогает
    var searchTask: Task<Void, Never>?                   // internal, для тестов через @testable
}
```
- Поиск — §7.4, шаги 1–6. Устаревший ответ (`query` изменился или задача отменена) не применяется. `.cancelled` никогда не превращается в `.failed`.
- Результаты сортируются через `StopListRules.sorted`.
- Если у `StopsResult` `skippedCount > 0` или `truncated == true`, пишется предупреждение через `os.Logger(subsystem: "RouteBuilder", category: "catalog")`. Пользователю это не показывается (§5.2, §5.5).
- Тестовая поддержка:
  - `actor ManualSleeper: Sleeper` — `sleep` приостанавливает вызывающего до `resumeAll()`, при отмене задачи бросает `CancellationError` (`withTaskCancellationHandler`); `var pendingCount: Int`;
  - `final class FakeStopsAPI: StopsAPI, @unchecked Sendable` — `catalogResults: [Result<StopsResult, APIError>]` отдаются по очереди; `searchHandler: (String) async throws -> StopsResult`; `private(set) var searchQueries: [String]`.

- [ ] **Шаг 1. Тесты** (`PickerStoreTests`, `@MainActor`):
  - `testLoadSuccessBuildsSections`;
  - `testCatalogFailureThenRetryLoads` — первый ответ `.notDelivered(.cannotConnectToHost)` → `.failed`; `reload()` → `.loaded` (Фокус ревью, п. 3);
  - `testDebounceCoalescesTyping` — `updateQuery("S")`, `"So"`, `"Sov"`, затем `resumeAll()` → `searchQueries == ["Sov"]`;
  - `testBlankQueryDoesNotHitNetwork` — `updateQuery("   ")` → `search == .idle`, запросов нет;
  - `testStaleResponseIsDropped` — `searchHandler` для `"Sov"` ждёт, пока его отпустят; затем `updateQuery("Tal")` и ответ на него; после этого отпускается ответ на `"Sov"` → в `search` результаты для `"Tal"`;
  - `testCancellationIsNotAnError` — новый ввод во время запроса → ни в какой момент `search` не становится `.failed(.cancelled)`;
  - `testEmptySuccessFallsBackToLocal` — API вернул `[]` по `"sov"` при загруженном каталоге с Sova → `.results([Sova])`;
  - `testEmptySuccessWithoutCatalogIsEmpty`;
  - `testLocalFallbackEmptyIsEmpty`;
  - `testSearch429ShowsFailedNotEmpty` — API бросает `.http(429, retryAfter: 39)` → `.failed(.http(status: 429, code: nil, retryAfter: 39))`, локальный поиск не вызывается (Фокус ревью, п. 4);
  - `testRetrySearchRepeatsCurrentQuery`;
  - `testModeSwitchDelegatesToDraft`;
  - `testResetKeepsCatalog`.
- [ ] **Шаг 2.** `swift test --filter PickerStoreTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск, **три раза подряд**. Ожидается PASS каждый раз: это проверка, что тесты не нестабильны.
- [ ] **Шаг 5.** Передать автору на коммит: `Add PickerStore with debounced API search and local fallback`.

### Задача 17: SubmissionStore

**Файлы:** создать `Stores/SubmissionStore.swift`, `Tests/RouteCoreTests/Support/FakeRoutesAPI.swift` и тест `SubmissionStoreTests.swift`; изменить `Rules/ErrorCopy.swift`.

**Интерфейсы:**
```swift
public enum SubmissionFailure: Equatable, Sendable { case notCreated(APIError), maybeCreated(APIError), rejected(code: String?) }
public enum SubmissionState: Equatable { case idle, submitting, failed(SubmissionFailure), succeeded(CreatedRoute) }
public enum SubmitAttempt: Equatable { case started, ignored, invalid(firstInvalidID: String) }

@MainActor public final class SubmissionStore: ObservableObject {
    @Published public private(set) var state: SubmissionState = .idle
    public init(api: RoutesAPI, draft: RouteDraftStore)
    @discardableResult public func submit() -> SubmitAttempt
    public func reset()
    var submitTask: Task<Void, Never>?        // internal; публичной отмены нет (§9.1.1)
}
extension ErrorCopy { public static func message(for failure: SubmissionFailure) -> String }
```
- `submit()` — по §9.1: `.ignored` в состояниях `submitting` и `succeeded`; `.invalid` после `draft.validate()`; иначе `.started`.
- Задачу отправки стор создаёт и хранит сам.
- Отмена в состоянии `submitting` → `failed(.maybeCreated(.cancelled))`.
- Тексты:
  - `.maybeCreated` → «The route may have been created. Sending again could create a duplicate.»;
  - `.rejected(code)` → «The server rejected the route ({code}).», при `nil` — «The server rejected the route.»;
  - `.notCreated(e)` → `message(for: e)`.
- Тестовая поддержка: `final class FakeRoutesAPI: RoutesAPI, @unchecked Sendable` — `handler: ([RouteStopPayload]) async throws -> CreatedRoute`, `private(set) var calls: Int`.

- [ ] **Шаг 1. Тесты** (`SubmissionStoreTests`, `@MainActor`):
  - `testDoubleSubmitSendsOnce` — два `submit()` подряд → второй `.ignored`; после `await submitTask?.value` `calls == 1`;
  - `testInvalidDraftSendsNothing` — `.invalid(firstInvalidID:)` с первым пустым по порядку, `calls == 0`;
  - `testSuccess` → `.succeeded(route)`, повторный `submit()` → `.ignored`;
  - `testOutcomeMapping` — `.notDelivered` → `.notCreated`; `.ambiguous(.timedOut)` → `.maybeCreated`; HTTP 502 → `.maybeCreated`; 422 → `.rejected(code: "validation_failed")`; 503 → `.notCreated`;
  - `testCancelDuringSubmittingIsMaybeCreated` — обработчик ждёт; `submitTask?.cancel()` → `state == .failed(.maybeCreated(.cancelled))`, а не `.idle`; следующий `submit()` → `.started` (это повтор из `failed`);
  - `testRetryAfterFailureSendsAgain`;
  - `testRejectedAllowsResubmit` — после `.rejected` `submit()` → `.started`;
  - `testReset`;
  - `testFailureCopy` — три текста дословно.
- [ ] **Шаг 2.** `swift test --filter SubmissionStoreTests`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Выполнить `swift test` целиком. Ожидается: все PASS, live-тесты skipped.
- [ ] **Шаг 5.** Передать автору на коммит: `Add SubmissionStore state machine`.

---

## Часть D. Приложение

Для задач 18–25 TDD не применяется. Проверка каждой: сборка приложения и визуальная сверка на симуляторе iPhone (390×844) с соответствующим экраном макета. Сервер `node server.js` работает на Mac. Симулятор достаёт до IP Mac из xcconfig, отдельная настройка не нужна.

### Задача 18: Тема и общие компоненты

**Файлы:** создать `Theme/Colors.swift`, `Theme/Typography.swift`, `Theme/Metrics.swift`, `Components/PrimaryButton.swift`, `Components/AvatarView.swift`, `Components/ErrorBanner.swift`.

**Интерфейсы:**
- `extension Color { init(hex: UInt32, opacity: Double = 1) }`.
- `enum Palette` — статические `Color` с именами токенов из §10, например `Palette.accent`, `Palette.avatar: [Color]` из 5 элементов.
- `enum Typo` — статические `Font` по таблице §10, например `Typo.routeTitle = .system(size: 20, weight: .heavy)`, `Typo.pill = .system(size: 12, weight: .medium, design: .monospaced)`.
- `enum Metrics` — числа из §10.
- `struct PrimaryButton: View { init(_ title: String, isEnabled: Bool, isLoading: Bool = false, action: @escaping () -> Void) }` — 52 pt, радиус 12; неактивное состояние `disabledFill` / `disabledText`.
- `struct AvatarView: View { init(stop: Stop) }` — инициалы из `StopListRules.initials`, фон `Palette.avatar[StopListRules.avatarIndex(for:)]`.
- `struct ErrorBanner: View { init(message: String, retryTitle: String?, onRetry: (() -> Void)?) }`.

- [ ] **Шаг 1.** Реализовать файлы.
- [ ] **Шаг 2.** Собрать приложение. Ожидается `** BUILD SUCCEEDED **`.
- [ ] **Шаг 3.** Передать автору на коммит: `Add theme tokens and shared components`.

### Задача 19: Корень приложения, навигация и сборка зависимостей

**Файлы:**
- Создать: `App/AppEnvironment.swift`, `App/AppRoute.swift`, `App/RootView.swift`, `App/ConfigErrorView.swift`.
- Изменить: `RouteBuilderApp.swift`.
- Удалить: `ContentView.swift` (временную проверку из задачи 4).
- Создать временные заглушки `Features/Picker/PickerScreen.swift`, `Features/Instructions/InstructionsScreen.swift`, `Features/Success/SuccessScreen.swift`. Их заменят задачи 20, 23, 25.

**Интерфейсы:**
- `enum AppRoute: Hashable { case instructions, success(CreatedRoute) }`.
- `@MainActor final class AppEnvironment: ObservableObject`:
  - `let draft: RouteDraftStore`, `let picker: PickerStore`, `let submission: SubmissionStore`;
  - `@Published var path: [AppRoute] = []`;
  - `static func make(bundle: Bundle = .main) -> AppEnvironment?` — `nil`, если `APIConfiguration.baseURL` вернул `nil`;
  - `func startNewRoute()` — `draft.reset()`, `submission.reset()`, `picker.reset()`, `path = []`.

  Создаётся один раз в `RouteBuilderApp` через `@StateObject`; благодаря этому сторы живут всё время работы приложения (§9.1.1).
- `RootView` — `NavigationStack(path: $env.path)` с `PickerScreen` в корне и `.navigationDestination(for: AppRoute.self)`; на корне `.preferredColorScheme(.light)`.
- Если `make` вернул `nil`, показывается `ConfigErrorView` с текстом «API base URL is not configured».

- [ ] **Шаг 1.** Реализовать файлы.
- [ ] **Шаг 2.** Собрать приложение. Ожидается `** BUILD SUCCEEDED **`.
- [ ] **Шаг 3.** Запустить на симуляторе. Ожидается: открывается заглушка пикера, падений нет.
- [ ] **Шаг 4.** Передать автору на коммит: `Add app root, navigation and dependency wiring`.

### Задача 20: Экран Stops — список, поиск, состояния

**Файлы:** создать в `Features/Picker/`: `PickerScreen.swift`, `RouteHeader.swift`, `StepTabs.swift`, `ModeToggle.swift`, `SearchField.swift`, `StopRow.swift`, `SectionHeaderView.swift`, `PickerStateViews.swift`.

**Интерфейсы:**
- Потребляет: `PickerStore`, `RouteDraftStore`, `LocalSearch.highlightRange`, `ErrorCopy`, `QuantityRules`.
- `StopRow(stop:, isSelected:, packages: Int?, highlight: String?, onTap:, onPillTap:)`:
  - пилюля — зона нажатия 44×44 pt (`contentShape`, отступы), визуально как в макете;
  - у выбранной строки вместо телефона пилюля.
- Подтверждения через `confirmationDialog` для `.needsConfirmation` из `toggle` и `setMode`. Тексты: «Remove {name}? Its instructions will be lost.» для одной остановки; для нескольких — «Remove {n} stops? Their instructions will be lost.».

- [ ] **Шаг 1.** Реализовать файлы по §7.1–§7.4:
  - на пикере `navigationBarHidden`;
  - `.task { await picker.load() }`;
  - `.refreshable { await picker.reload() }`;
  - `LazyVStack(pinnedViews: [.sectionHeaders])`;
  - поиск — плоский список с подсветкой;
  - пустое состояние «No stop found» / «Try another name, street, or phone»;
  - ошибка — `ErrorBanner` с Retry.
- [ ] **Шаг 2.** Собрать приложение и запустить на симуляторе. Сверить с макетом, экраны 1 и 2:
  - заголовки секций идут по алфавиту, `#` последний;
  - `sov` находит Sova через локальное дополнение, `Quarry Lane` показывает пустое состояние;
  - тап по строке выбирает её, в режиме One выбор заменяется;
  - **длинное имя `stp_1016` (Roma Pizza…) обрезается многоточием** (Фокус ревью, п. 5).
- [ ] **Шаг 3.** Остановить сервер и нажать Retry. Ожидается ошибка «Can't reach the server…». Запустить сервер и снова нажать Retry: каталог загружается.
- [ ] **Шаг 4.** Передать автору на коммит: `Add Stops screen list, search and states`.

### Задача 21: Экран Stops — чипы, Continue, окно количества

**Файлы:** создать `Features/Picker/SelectionBar.swift`, `StopChip.swift`, `QuantityOverlay.swift`; изменить `PickerScreen.swift`.

**Интерфейсы:**
- `QuantityOverlay(stop:, initial: Int, onSave: (Int) -> Void, onCancel: () -> Void)` — только ядро §7.5:
  - затемнение `scrim` и карточка: −, число, + и Save;
  - подпись «Max N» показывается только при `QuantityRules.showsMaxCaption`;
  - тап по затемнению — отмена.
- `StopChip(draft:, onRemove:)` — ✕ с зоной нажатия 44×44 pt.
- `SelectionBar` — чипы в горизонтальном `ScrollView` и `PrimaryButton("Continue (1 stop)" / "Continue (N stops)")`; по нажатию `env.path.append(.instructions)`.
- Вкладка Instructions в `StepTabs` с выбором делает то же, что Continue.
- Подзаголовок `RouteHeader`: `"{P} packages | {N} stops"`, единственное и множественное число согласуются, например «1 package | 1 stop».

- [ ] **Шаг 1.** Реализовать.
- [ ] **Шаг 2.** На симуляторе сверить с макетом, экраны 3 и 4:
  - у Sova (`packagesMax` 6) кнопка + неактивна на 6 и видна подпись «Max 6»;
  - у `stp_1000` (`null`) подписи нет, предел 99;
  - ✕ на чипе снимает выбор;
  - Continue неактивен при 0 и пушит экран Instructions (пока заглушку);
  - длинное имя в чипе и в окне обрезается многоточием (Фокус ревью, п. 5).
- [ ] **Шаг 3.** Передать автору на коммит: `Add selection bar, chips and quantity overlay`.

### Задача 22: Алфавитный индекс

**Файлы:** создать `Features/Picker/AlphabetIndex.swift`; изменить `PickerScreen.swift` (`ScrollViewReader`, `id` у секций).

**Интерфейсы:** `AlphabetIndex(available: Set<String>, onSelect: (String) -> Void)`:
- колонка шириной 28 pt, буквы A–Z (9.5 pt, `muted`);
- `DragGesture(minimumDistance: 0)` по всей высоте колонки переводит координату Y в букву, `onSelect` вызывается только при смене буквы;
- `PickerScreen` переводит букву без секции в ближайшую следующую доступную (если такой нет — последнюю), затем `proxy.scrollTo(key, anchor: .top)`;
- во время поиска колонка скрыта.

- [ ] **Шаг 1.** Реализовать.
- [ ] **Шаг 2.** На симуляторе: тап по «T» скроллит к секции T; протяжка от A до Z проходит по секциям; тап по «Q» (секции нет) ведёт к R.
- [ ] **Шаг 3.** Передать автору на коммит: `Add alphabet index with drag scrubbing`.

### Задача 23: Экран Instructions — карточки, ввод, удаление

**Файлы:** создать в `Features/Instructions/`: `InstructionsScreen.swift`, `StopCard.swift`, `InstructionField.swift`, `PageDots.swift`, `FeedBackground.swift`, `FinishBar.swift`.

**Интерфейсы:**
- Потребляет: `RouteDraftStore` (`setInstruction`, `clearInstruction`, `remove`, `confirmRemove`), `InstructionRules.count`.
- `StopCard(draft:, isFocused: Bool, isLocked: Bool, onRemove:)` — структура §8.3:
  - счётчик `"\(count)/200"`;
  - ошибка: рамка `warning` и «Add instructions for this stop before finishing»;
  - `Clear all` неактивна при пустом поле;
  - кнопка «Remove from route» 44 pt;
  - сноска «Instructions are sent with the route when you finish».
- `.becameEmpty` → `env.path = []`.
- `FinishBar` на этом этапе только вызывает `draft.validate()` и скроллит к первой карточке с ошибкой. Отправку подключит задача 25.

- [ ] **Шаг 1.** Реализовать по §8.1–§8.3 и §8.5 (без свайпа и без фото).
- [ ] **Шаг 2.** На симуляторе сверить с экраном 5 макета:
  - вставка текста длиннее 200 обрезается, счётчик показывает 200/200;
  - Finish с пустой карточкой скроллит к ней и показывает ошибку, ввод текста ошибку снимает;
  - Remove у пустой карточки срабатывает сразу, у заполненной открывает диалог;
  - удаление последней возвращает на пикер;
  - назад на пикер и снова вперёд — текст сохранился;
  - длинное имя в заголовке карточки обрезается многоточием (Фокус ревью, п. 5);
  - удаление карточки с открытой клавиатурой не роняет приложение (Фокус ревью, п. 1).
- [ ] **Шаг 3.** Передать автору на коммит: `Add Instructions feed cards and removal`.

### Задача 24: Фокус-эффект и клавиатура

**Файлы:** создать `Features/Instructions/CardOffsetPreference.swift`; изменить `InstructionsScreen.swift`, `StopCard.swift`, `PageDots.swift`.

**Интерфейсы:**
- `struct CardOffsetPreference: PreferenceKey` — `[String: Double]`, ключ `stop.id`, значение — `midY` карточки в координатном пространстве `"feed"` минус центр видимой области.
- `InstructionsScreen` собирает расстояния в порядке `draft.stops`, берёт `activeIndex` из `@FocusState var focusedID: String?` и вызывает `FeedFocus.layout`. Результат применяется через `scaleEffect(x:y:)` и `opacity`; `isFocused` передаётся в карточку и в `PageDots`.
- При фокусе поля `proxy.scrollTo(id, anchor: .top)` с анимацией.
- Над клавиатурой `ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") }`.
- Пока клавиатура открыта, `FinishBar` скрыт (уведомления `keyboardWillShow` / `keyboardWillHide`).

- [ ] **Шаг 1.** Реализовать.
- [ ] **Шаг 2.** На симуляторе сверить с экранами 5 и 6:
  - соседние карточки уменьшены и полупрозрачны, центральная — в полном размере с бирюзовой рамкой;
  - при вводе в карточку, которая уехала вверх, она остаётся в полном размере;
  - **поле последней карточки при открытой клавиатуре видно над панелью Done** (Фокус ревью, п. 2);
  - скролл плавный, без рывков.
- [ ] **Шаг 3.** Передать автору на коммит: `Add feed focus effect and keyboard handling`.

### Задача 25: Отправка и Success

**Файлы:** создать `Features/Instructions/SubmissionBanner.swift`, `Features/Success/SuccessScreen.swift` (вместо заглушки); изменить `InstructionsScreen.swift`, `FinishBar.swift`.

**Интерфейсы:**
- Потребляет: `SubmissionStore`, `ErrorCopy.message(for: SubmissionFailure)`, `AppEnvironment.startNewRoute()`.
- `FinishBar`:
  - вызывает `submission.submit()`;
  - `.invalid(firstInvalidID:)` → скролл к этой карточке и фокус в её поле;
  - во время отправки — «Sending…» со спиннером.
- Во время `submitting`: `navigationBarBackButtonHidden(true)`, поля и удаление заблокированы (`isLocked`).
- `SubmissionBanner`:
  - `.notCreated` → Retry;
  - `.maybeCreated` → Retry открывает `confirmationDialog` с кнопкой «Send again»;
  - `.rejected` → без Retry.
- `.succeeded(route)` → `env.path.append(.success(route))`, ровно один раз (`onChange(of: state)`).
- `SuccessScreen(route:, totals:)`:
  - «Route {id} created»;
  - `"{N} stops · {P} packages"` (согласование чисел — как в шапке пикера);
  - предупреждение «The server changed instructions for {k} stops.» при непустом `alteredStopIDs`;
  - кнопка `New route` → `startNewRoute()`;
  - `navigationBarBackButtonHidden(true)`.

- [ ] **Шаг 1.** Реализовать.
- [ ] **Шаг 2.** На симуляторе:
  - полный поток → Success; кнопки «назад» нет, свайп от края не работает;
  - New route открывает пустой пикер в режиме One stop;
  - двойной тап по Finish создаёт один маршрут: в логе сервера один `POST`, следующий маршрут получит `id` на 1 больше;
  - при остановленном сервере — плашка «Can't reach the server…» с Retry; после запуска сервера Retry проходит.
- [ ] **Шаг 3.** Передать автору на коммит: `Add submission states and Success screen`.

### Задача 26: Документы, проверка на устройстве и ревью ядра

**Файлы:** создать `README.md`, `DECISIONS.md`, `AI_PROCESS.md`, `docs/ai/verification.md`.

- [ ] **Шаг 1.** `README.md` — по §13 спеки, пункт за пунктом. Добавить команду `ipconfig getifaddr` для интерфейса из `route get default`.
- [ ] **Шаг 2.** `DECISIONS.md` — не больше одной страницы, ~60 строк: решения, вырезанное, вопросы к PM (§13). Плюс решение по ATS из задачи 4 и итог по свайпу, если задача 28 уже пройдена.
- [ ] **Шаг 3.** `AI_PROCESS.md` — заготовка не больше одной страницы: кит, агент, пройденные гейты, места, где автор поправил агента (список из брейншторминга). Поле модели и время заполняет автор.
- [ ] **Шаг 4.** `docs/ai/verification.md` — чек-лист устройства из §12 с колонкой результата.
- [ ] **Шаг 5. Автор, на iPhone:** пройти чек-лист после перезапуска сервера, отметить результаты.
- [ ] **Шаг 6. Агент:** `swift test` целиком и сборка приложения. Ожидается: всё PASS и `BUILD SUCCEEDED`. Затем ревью ядра через superpowers:requesting-code-review.
- [ ] **Шаг 7.** Передать автору на коммит: `Add README, DECISIONS, AI_PROCESS and device verification`.

---

## Часть E. Задачи, которые можно отрезать

Порядок строгий. Ни одна задача ядра от них не зависит. Если задача отрезана, это фиксируется в DECISIONS.

### Задача 27: Полировка окна количества

**Файлы:** изменить `Features/Picker/QuantityOverlay.swift`, `PickerScreen.swift`.

- Над затемнением рисуется копия выбранной строки в её экранной позиции. Позиция строки передаётся через `anchorPreference` (`Anchor<CGRect>`).
- Карточка ставится под строкой со стрелкой: квадрат 12 pt, повёрнутый на 45°, смещение 24 pt от левого края карточки. Если снизу места не хватает, карточка ставится над строкой.

- [ ] **Шаг 1.** Реализовать.
- [ ] **Шаг 2.** На симуляторе сверить с экраном 3: для первой строки, для строки в середине и для последней видимой строки карточка не выходит за экран.
- [ ] **Шаг 3.** Передать автору на коммит: `Polish quantity overlay: lifted row and arrow`.

### Задача 28: Свайп-удаление (лимит времени 1 час)

**Файлы:** изменить `Features/Instructions/StopCard.swift`, `InstructionsScreen.swift`.

- `DragGesture(minimumDistance: 12)` через `simultaneousGesture`. Жест учитывается, только если `abs(dx) > abs(dy)` и `dx > 0`.
- Под карточкой подложка `removeBG` с «Remove from route».
- Если отпустить при `dx > 150`, вызывается тот же `onRemove`, что у кнопки; иначе карточка пружиной возвращается.
- Во время отправки жест отключён.

- [ ] **Шаг 1.** Засечь время начала. Реализовать.
- [ ] **Шаг 2. Автор, на iPhone:** вертикальный скролл ленты не ломается, в том числе если начать его с горизонтальным отклонением; свайп удаляет карточку по тем же правилам подтверждения.
- [ ] **Шаг 3.** Если через 1 час критерий не выполнен, откатить изменения задачи (`git checkout -- <файлы задачи>`, коммитов нет) и записать в DECISIONS: «Swipe removed: conflicted with vertical scroll on iOS 16 ScrollView; button kept». Иначе передать автору на коммит: `Add swipe-to-remove on feed cards`.

### Задача 29: Notify

**Файлы:**
- RouteAPI: изменить `DTO/RouteDTO.swift`, `RequestBuilder.swift`, `APIClient.swift`, `APIProtocols.swift`; тест `NotifyTests.swift`.
- RouteCore: создать `Stores/NotifyStore.swift`, `Tests/RouteCoreTests/Support/FakeNotifyAPI.swift` и тест `NotifyStoreTests.swift`.
- App: изменить `SuccessScreen.swift`, `AppEnvironment.swift`, `StopCard.swift` (сноска).

**Интерфейсы:**
- `public struct NotifyResponseDTO: Decodable { stopID, status: String; reason: String?; attempts: Int?; sentAt: String?; deliveries: Int? }`.
- `public enum NotifyResult: Equatable, Sendable { case sent, failed(reason: String?) }`.
- `public protocol NotifyAPI: Sendable { func notify(routeID: String, stopID: String, idempotencyKey: String) async throws -> NotifyResult }`, его реализует `APIClient`. Протокол отдельный: `RoutesAPI` и `FakeRoutesAPI` из ядра остаются без изменений, и задачу можно отрезать бесследно.
  - POST, таймаут 15 с;
  - заголовок `Idempotency-Key` обязателен;
  - `retrying: false` — повторами управляет стор;
  - результат определяется только по `status`.
- `@MainActor public final class NotifyStore: ObservableObject`:
  - `@Published private(set) var statuses: [String: NotifyStatus]`, где `enum NotifyStatus { case pending, sending, sent, failed(String), rejected(String) }`;
  - `init(api: NotifyAPI, keyFactory: @escaping () -> String = { UUID().uuidString })`;
  - `func start(route: CreatedRoute, stopIDs: [String])` — последовательно, по одному;
  - `func retry(stopID: String)` — правила ключей §5.6: тот же ключ после `.notDelivered`, `.ambiguous`, `.cancelled`, 429, 5xx и `.decoding`; новый ключ только после `failed`; 4xx, кроме 429, дают `.rejected` без кнопки повтора.
- `SuccessScreen` показывает строку статуса на каждую остановку и Retry для `failed` и транзиентных ошибок.
- Сноска на карточке становится «Instructions go to the driver when you finish».

- [ ] **Шаг 1. Тесты:**
  - `NotifyTests.testFailedStatusOn200` → `.failed(reason: "carrier_rejected")`;
  - `NotifyTests.testSendsIdempotencyKeyHeader`;
  - `NotifyStoreTests.testSameKeyAfterTransientErrors` — для каждой ошибки [`.ambiguous(.timedOut)`, `.notDelivered`, HTTP 429, HTTP 503, `.decoding`] повтор уходит с тем же ключом;
  - `NotifyStoreTests.testNewKeyOnlyAfterFailed` — `failed`, затем retry → новый ключ, затем `sent`;
  - `NotifyStoreTests.testRejectedNoRetry` — 422 → `.rejected`, `retry` ничего не делает;
  - `NotifyStoreTests.testSequential` — ни в какой момент нет двух одновременных вызовов.
- [ ] **Шаг 2.** `swift test --filter "NotifyTests|NotifyStoreTests"`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать API и стор.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS. Затем `swift test` целиком: PASS.
- [ ] **Шаг 5.** Подключить UI и сноску. На симуляторе: у `stp_1002` первая попытка `failed`, Retry даёт `sent`.
- [ ] **Шаг 6.** Передать автору на коммит: `Add driver notify with idempotency key rules`.

### Задача 30: Фото с прошлой доставки

**Файлы:**
- RouteAPI: изменить `DTO/`, `RequestBuilder.swift`, `APIClient.swift`, `APIProtocols.swift`; тест `PhotosTests.swift`.
- RouteCore: создать `Stores/PhotoStore.swift`, `Tests/RouteCoreTests/Support/FakePhotosAPI.swift` и тест `PhotoStoreTests.swift`.
- App: создать `Features/Instructions/PhotoStrip.swift`; изменить `StopCard.swift`, `InstructionsScreen.swift`, `AppEnvironment.swift`.

**Интерфейсы:**
- `public struct StopPhoto: Equatable, Sendable { public let id: String; public let url: URL?; public let tag: String }` — `url: null` и невалидный URL → `nil`. Декодирование через `LossyArray`.
- `public protocol PhotosAPI: Sendable { func photos(stopID: String) async throws -> [StopPhoto] }`, его реализует `APIClient`. GET, таймаут 15 с, `retrying: true`. Протокол отдельный: `StopsAPI` и `FakeStopsAPI` из ядра остаются без изменений.
- `@MainActor public final class PhotoStore: ObservableObject`:
  - `@Published private(set) var photos: [String: PhotoState]`, где `enum PhotoState { case loading, loaded([StopPhoto]), unavailable }`;
  - `func load(stopID: String)` — запрос один раз на `id` за сессию, кеш;
  - `func cancel(stopID: String)` — при удалении карточки.
- `PhotoStrip(state:)` — подписи тегов по §8.6; `AsyncImage` с плейсхолдером и иконкой «нет изображения»; при `.unavailable` или 0 фото блок скрыт.
- Загрузка запускается только для фокусной карточки, когда `focusedIndex` меняется.

- [ ] **Шаг 1. Тесты:**
  - `PhotosTests.testNullURLDecodes`;
  - `PhotosTests.testUnknownTagKept`;
  - `PhotoStoreTests.testLoadsOncePerStop` — два вызова `load` → 1 запрос;
  - `PhotoStoreTests.testErrorBecomesUnavailable`;
  - `PhotoStoreTests.testCancelStopsLoading`.
- [ ] **Шаг 2.** `swift test --filter "PhotosTests|PhotoStoreTests"`. Ожидается FAIL.
- [ ] **Шаг 3.** Реализовать.
- [ ] **Шаг 4.** Тот же запуск. Ожидается PASS.
- [ ] **Шаг 5.** Подключить UI. На симуляторе: фото появляются примерно через 4 с только у карточки в фокусе; у `stp_1000` (0 фото) блока нет; второй тег (`url: null`) показывает иконку.
- [ ] **Шаг 6.** Передать автору на коммит: `Add last-delivery photos for focused card`.

---

## Завершение

После последней выполненной задачи:
1. скопировать ledger `.superpowers/sdd/<plan>/progress.md` в `docs/ai/`;
2. финальное ревью ветки через superpowers:requesting-code-review;
3. superpowers:finishing-a-development-branch с вариантом «оставить ветку».

Коммиты и push делает автор.
