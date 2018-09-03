 ![WebServiceSwift](https://raw.githubusercontent.com/ProVir/WebServiceSwift/master/WebServiceSwiftLogo.png) 


[![CocoaPods Compatible](https://cocoapod-badges.herokuapp.com/v/WebServiceSwift/badge.png)](http://cocoapods.org/pods/WebServiceSwift)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/ProVir/WebServiceSwift)
[![Platform](https://cocoapod-badges.herokuapp.com/p/WebServiceSwift/badge.png)](http://cocoapods.org/pods/WebServiceSwift)
[![License](https://cocoapod-badges.herokuapp.com/l/WebServiceSwift/badge.png)](https://github.com/ProVir/WebServiceSwift/blob/master/LICENSE)

Network layer as Service. Service as an interface for interacting with your web server. Support Swift 4. 

- [Features](#features)
- [Requirements](#requirements)
- [Communication](#communication)
- [Installation](#installation)
- [Usage (English / Русский)](#usage-english--%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9)
- [Endpoints](#endpoints)
- [Manage requests](#manage-requests)
- [Providers](#providers)
- [Storages](#storages)
- [Mock Endpoints](#mock-endpoints)
- [Author](#author)
- [License](#license)


## General scheme use WebServiceSwift in project (SOA).

 ![Scheme](https://raw.githubusercontent.com/ProVir/WebServiceSwift/dev/WebServiceScheme.png) 


## Features

- [x] Easy interface for use
- [x] All work with network in inner endpoint and storage, hided from interface. 
- [x] Support Dispatch Queue.
- [x] One class for work with many types requests. 
- [x] One instance for work with many endpoints and storages.
- [x] Simple storages (on disk, data base or in memory) in package. Easy - add only own api endpoint and ready!
- [x] Support NetworkActivityIndicator on iOS.
- [x] Thread safe.
- [x] Responses with concrete type in completion handler closures. 
- [x] Providers for requests (have RequestProvider and GroupProvider) for work with only concrete requests. Used to indicate more explicit dependencies (DIP). 
- [x] Mock endpoints for temporary or test response data without use real api endpoint. 
- [x] Full support Alamofire (include base endpoint).
- [x] Simple HTTP Endpoints (NSURLSession or Alamofire).  


## Requirements

- iOS 8.0+ / macOS 10.10+ / tvOS 9.0+ / watchOS 2.0+
- Xcode 9.0 and above
- Swift 4.0 and above


## Communication

- If you **need help**, go to [provir.ru](http://provir.ru)
- If you **found a bug**, open an issue.
- If you **have a feature request**, open an issue.
- If you **want to contribute**, submit a pull request.



## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 1.1.0+ is required to build WebServiceSwift 3.0.0+.

To integrate WebServiceSwift into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'WebServiceSwift', '~> 3.0'
end
```

Also you can use Alamofire endpoints:
```ruby
pod 'WebServiceSwift/Alamofire', '~> 3.0'
```

Or only core without simple endpoints and storages:
```ruby
pod 'WebServiceSwift/Core', '~> 3.0'
```


Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate WebServiceSwift into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "ProVir/WebServiceSwift" ~> 3.0
```

Run `carthage update` to build the framework and drag the built `WebServiceSwift.framework` into your Xcode project.

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. It is in early development, but WebServiceSwift does support its use on supported platforms. 

Once you have your Swift package set up, adding WebServiceSwift as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .Package(url: "https://github.com/ProVir/WebServiceSwift.git", majorVersion: 3)
]
```

### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate WebServiceSwift into your project manually.

Copy files from directory `Source` in your project. 


---

## Usage (English / Русский)

To use the library, you need:
1. Create at least one type of request that implements the `WebServiceRequesting` protocol.
2. Create at least one class for work with the network (endpoint), implementing the protocol `WebServiceEndpoint`. It should provide its own protocol, the implementation of which with queries using the extensions will allow this endpoint to process the request (see example).
3. If desired, you can create a class for storing caches last responses or use the existing - `WebServiceFileStorage`, `WebServiceDataBaseStorage` or `WebServiceMemoryStorage`.
4. If desired, you can create a class for mocks requests when part API don't completed - `WebServiceMockEndpoint` or its subclass, `WebServiceMockRequestEndpoint` for one type request. It is recommended to use it first in the array of `endpoints`.
5. Write method to generate a `WebService` object. For example can be used factory to generate a WebService object or write an extension for it with a convenience constructor. 

**Note:** To use the library, remember to include it in each file: `import WebServiceSwift`.

The project has a less abstract example of using the library, which can be downloaded separately. Study the classes `WebServiceSimpleEndpoint` и `WebServiceAlamofireSimpleEndpoint` - they are a good example of its endpoint.

To create non-compliant copies of a service with the same set of endpoints and storages, you can call `WebService.clone ()`. Each copy independently manages its requests and cancels them automatically when an instance of the service is deinited.

#

Для использования библиотеки вам нужно:
1. Создать как минимум один тип запроса, реализующий протокол `WebServiceRequesting`. 
2. Создать как минимум один класс для работы с сетью, реализующий протокол `WebServiceEndpoint`.  Он должен предоставлять собственный протокол, реализация которого у запросов с помощью расширения позволит этому классу обрабатывать запрос (смотрите пример).
3. По желанию можно создать класс для хранения кешей последних ответов или использовать существующие - `WebServiceFileStorage`, `WebServiceDataBaseStorage` или `WebServiceMemoryStorage`.
4. По желанию можно создать класс для обработки mock запросов в случаях, когда часть АПИ не реализована - `WebServiceMockEndpoint` или наследоваться от него, `WebServiceMockRequestEndpoint` для одного типа запроса. Рекомендуется использовать его первым в списке `endpoints`. 
5. Написать метод получение готового объекта сервиса `WebService` . К примеру, можно использовать фабрику или написать для сервиса расширение с конструктором, вызывающий базовый конструктор с параметрами.

**Замечание:** для использования библиотеки не забудьте ее подключить в каждом файле: `import WebServiceSwift`.

В проекте есть менее абстрактный пример использования библиотеки, который можно скачать отдельно.  Изучите классы `WebServiceSimpleEndpoint` и `WebServiceAlamofireSimpleEndpoint` - они являются хорошим примером своего обработчика (endpoint).

Для создания независмых копий сервиса с одинаковым набором обработчиков и хранилищ вы можете вызвать `WebService.clone()`. Каждая копия независимо управляет своими запросами и отменяет их автоматически при удалении экземпляра сервиса. 


### Endpoints

#### An example request structure (swift 4.1+):

```swift
struct ExampleRequest: WebServiceRequesting, Hashable {
    let param1: String  
    let param2: Int 
    
    typealias ResultType = String
}
```

Such types of requests can be as many as you like and for their processing you can use different endpoints, automatically selected from the array. There can also be several versions of the storage.
Typically, you should create your own endpoint to interact with the API, but sometimes you may have enough of the basic functionality of the ready-made solutions - `WebServiceSimpleEndpoint` or` WebServiceAlamofireSimpleEndpoint`.

Таких типов запросов может быть сколько угодно и для их обработки можно использовать разные обработчики (endpoints), выбираемые из списка автоматически. Разновидностей хранилищ тоже может быть несколько.
Как правило вам следует создать свой собственный обработчик (endpoint) для взаимодействия с АПИ, но иногда может хватить базового функционала готовых решений - `WebServiceSimpleEndpoint` или `WebServiceAlamofireSimpleEndpoint`. 


#### Example of a own endpoint for working with a network using a library [Alamofire](https://github.com/Alamofire/Alamofire):

```swift
protocol WebServiceHtmlRequesting: WebServiceBaseRequesting {
    var url: URL { get }
}

class WebServiceHtmlEngine: WebServiceEndpoint {
    let queueForRequest: DispatchQueue? = DispatchQueue.global(qos: .background)
    let queueForDataProcessing: DispatchQueue? = nil
    let queueForDataProcessingFromStorage: DispatchQueue? = DispatchQueue.global(qos: .background)
    let useNetworkActivityIndicator = true

    func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceHtmlRequesting
    }

    func performRequest(requestId: UInt64, request: WebServiceBaseRequesting,
                        completionWithRawData: @escaping (_ data: Any) -> Void,
                        completionWithError: @escaping (_ error: Error) -> Void) {

        guard let url = (request as? WebServiceHtmlRequesting)?.url else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }

        Alamofire.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                completionWithRawData(data)

            case .failure(let error):
                completionWithError(error)
            }
        }
    }

    func canceledRequest(requestId: UInt64) { /* Don't support in example */ }

    func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any {
        guard request is WebServiceHtmlRequesting, let binary = rawData as? Data else {
            throw WebServiceRequestError.notSupportDataProcessing
        }
    
        if let result = String(data: binary, encoding: .utf8) ?? String(data: binary, encoding: .windowsCP1251) {
            return result
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}
```

#### Example of a endpoint with use Alamofire base endpoint:

```swift
class WebServiceHtmlV2Endpoint: WebServiceAlamofireBaseEndpoint {
    init() {
        super.init(queueForRequest: DispatchQueue.global(qos: .background), useNetworkActivityIndicator: true)
    }

    override func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceHtmlRequesting
    }

    override func performRequest(requestId: UInt64, data: RequestData) throws -> Alamofire.DataRequest? {
        guard let url = (data.request as? WebServiceHtmlRequesting)?.url else {
            throw WebServiceRequestError.notSupportRequest
        }

        return Alamofire.request(url)
    }

    override func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any {
        guard request is WebServiceHtmlRequesting, let binary = rawData as? Data else {
            throw WebServiceRequestError.notSupportDataProcessing
        }

        if let result = String(data: binary, encoding: .utf8) ?? String(data: binary, encoding: .windowsCP1251) {
            return result
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}
```



Working with the network is not a prerequisite for the endpoint. Behind this layer, you can hide the work with the database or at least temporarily put a stub. On the interface service side, this is not important and during the development of the endpoint can be unnoticeably replaced, without changing the code of the requests themselves.

Вовсе не обязательно обработчик (endpoint) должен работать с сетью. За этим слоем вы можете скрыть работу с БД или вовсе временно выставить заглушку. Со стороны интерфейса сервиса это не важно и в процессе разработки обработчики можно незаметно подменять, не меняя код самих запросов. 


#### Simple request support concrete endpoint example:

```swift
extension ExampleRequest: WebServiceHtmlRequesting {
    var url: URL {
        /* .... Logic create URL from param1 and param2 ... */
    }
    
    func decodeResponse(data: Data) throws -> String {
        /* ... Create concrete decoder data from server and decoding ... */
    }
}
```

Each request must implement the support protocols for each endpoint that can handle it. If multiple endpoints are supported by a single request, then the first endpoint, supported from the array `endpoints`, is selected for processing.

Каждый запрос должен реализовать протоколы поддержки каждого обработчика (endpoint), который может его обрабатывать. Если поддерживается несколько обработчиков одним запросом, то выбирается первый поддерживаемый из списка `endpoints` для обработки. 


#### WebService create service - used factory constructor example:

```swift
extension WebService {
    convenience init() {
        let endpoint = WebServiceEndpoint()
        
        var storages: [WebServiceStoraging] = []
        if let storage = WebServiceDataBaseStorage() {
            storages.append(storage)
        }
        
        self.init(engines: [WebServiceMockEndpoint(), endpoint], storages: storages)
    }
}
```

You can also make support for a singleton - an example of this approach is in the source code.

Также можно сделать поддержку синглетона - пример такого подхода есть в исходниках. 


#### An example of using the closure:

```swift
let webService = WebService()

webService.performRequest(ExampleRequest(param1: val1, param2: val2)) { [weak self] response in
    switch response {
    case .canceledRequest: 
        break

    case .data(let dataCustomType):
        self?.dataFromServer = dataCustomType
        
    case .error(let error):
        self?.showError(error)
    }
}
```

We pass the data in request, on the output we get the ready object for display.

Передаем данные в запросе, на выходе получаем готовый объект для отображения. 


#### An example using a delegate:

```swift
let webService = WebService()

webService.performRequest(ExampleRequest(param1: val1, param2: val2), responseDelegate: self)

func webServiceResponse(request: WebServiceRequesting, key: AnyHashable?, isStorageRequest: Bool, response: WebServiceAnyResponse) {
    if let request = request as? ExampleRequest {
        let response = response.convert(request: request)

        switch response {
        case .canceledRequest: 
            break

        case .data(let dataCustomType):
            if isStorageRequest {
                dataFromStorage = dataCustomType
            } else {
                dataFromServer = dataCustomType
            }
                
        case .error(let error):
            showError(error)
        }
    }
}
```

### Manage requests

Executable requests can be controlled - check for execution (containt) and cancel. In endpoint, you can implement a method of canceling query execution - this is necessary for optimizations, regardless of whether you cancel the request in the endpoint, the request will be canceled and its results ignored.

You can manage requests in several ways:
- All: `containsManyRequests()` and `cancelAllRequests()`;
- On a request instance, if it is hashabled (`Request: WebServiceBaseRequesting, Hashable`): `containsRequest(Request)` and `cancelRequests(Request)`;
- By request type: `containsRequest(type: WebServiceBaseRequesting.Type)` and `cancelRequests(type: WebServiceBaseRequesting.Type)`;
- By the key (more on this): `containsRequest(key:)` and `cancelRequests(key:)`;
- By type of key: `containsRequest(keyType:)` and `cancelRequests(keyType:)`.

All canceled requests will end with an response `WebServiceResponse.canceledRequest(duplicate: false)`.


Выполняемыми запросами можно управлять - проверять на выполнение (containt) и отменять (cancel). В endpoint можно реализовать метод отмены выполнения запроса - это нужно для оптимизаций, не зависимо отмените ли вы запрос в endpoint, запрос будет отменен и его результаты проигнорированы. 

Запросами можно управлять несколькими способами:
- Всеми: `containsManyRequests()` и `cancelAllRequests()`;
- По экземпляру запроса, если он хешируемый (`Request: WebServiceBaseRequesting, Hashable`): `containsRequest(Request)` и `cancelRequests(Request)`;
- По типу запроса: `containsRequest(type: WebServiceBaseRequesting.Type)` и `cancelRequests(type: WebServiceBaseRequesting.Type)`;
- По ключу (об этом далее): `containsRequest(key:)` и `cancelRequests(key:)`;
- По типу ключа: `containsRequest(keyType:)` и `cancelRequests(keyType:)`.

Все отмененные запросы завершатся с ответом `WebServiceResponse.canceledRequest(duplicate: false)`.


#### Example contains and cancel requests:

```swift
struct ExampleKey: Hashable {
    let value: String
}

let isContains1 = webService.containsRequest(ExampleRequest(param1: val1, param2: val2))
let isContains2 = webService.containsRequest(type: ExampleRequest.self)
let isContains3 = webService.containsRequest(key: ExampleKey(value: val1))
let isContains3 = webService.containsRequest(keyType: ExampleKey.self)

webService.cancelRequests(ExampleRequest(param1: val1, param2: val2))
webService.cancelRequests(type: ExampleRequest.self)
webService.cancelRequests(key: ExampleKey(value: val1))
webService.cancelRequests(keyType: ExampleKey.self)
```

You can also exclude duplicate requests. For this, the request must implement the protocol `Hashable` or use a key for requests (any type that implements the protocol` Hashable`).
Requests that turn out to be duplicates will immediately end with the response `WebServiceResponse.canceledRequest(duplicate: true)`.

Также можно исключать дублирующие запросы. Для этого запрос должен реализовывать протокол `Hashable` или использовать ключ (key) для запросов (любой тип реализующий протокол `Hashable`). 
Запросы которые окажутся дублирующими сразу завершатся с ответом `WebServiceResponse.canceledRequest(duplicate: true)`.

#### Example use test for duplicates requests:

```swift
webService.performRequest(ExampleRequest(param1: val1, param2: val2), excludeDuplicate: true) { [weak self] response in
    switch response {
    case .canceledRequest(duplicate: let duplicate): 
        if duplicate {
            print("Request is duplicate!")
        }

    case .data(let dataCustomType):
        self?.dataFromServer = dataCustomType

    case .error(let error):
        self?.showError(error)
    }
}

webService.performRequest(ExampleRequest(param1: val1, param2: val2), key: ExampleKey(value: val1), excludeDuplicate: true) { [weak self] response in
    switch response {
    case .canceledRequest(duplicate: let duplicate): 
        if duplicate {
            print("Key is duplicate!")
        }

    case .data(let dataCustomType):
        self?.dataFromServer = dataCustomType

    case .error(let error):
        self?.showError(error)
    }
}
```

### Providers

To add more explicit dependencies to your project, as well as to protect against errors of a certain type, you can use providers. Providers are wrappers over WebService and hide it with private access. They provide access only to a limited type of requests in the form of convenient interfaces, excluding a certain class of errors in the code. The main purpose of the provider is to give the access to the permissible part of the WebService functional in the right place in the code.

Для добавления более явных зависимостей в ваш проекта, а также для защиты от ошибок определеного типа, вы можете использовать провайдеры. Провайдеры являются обертками над WebService и скрывают его с private доступом. Они предоставляют доступ только ограниченному типу запросов в виде удобных интерфейсов, исключающие определенный класс ошибок в коде. Основная цель провайдера - в нужном месте в коде дать доступ только к допустимой части функционала WebService. 

#### Example own provider:

```swift
struct SiteWebServiceRequests: WebServiceGroupRequests {
    static let requestTypes: [WebServiceBaseRequesting.Type] 
        = [ExampleRequest.self, GetList.self]
    
    struct Example: WebServiceRequesting, Hashable {
        let site: String  
        let domainRu: Bool
    
        typealias ResultType = String
    }
    
    struct GetList: WebServiceEmptyRequesting, Hashable {
        typealias ResultType = [String]
    }
}


class SiteWebProvider: WebServiceProvider {
    private let webService: WebService

    required init(webService: WebService) {
        self.webService = webService
    }
    
    enum Site: String {
    case google
    case yandex
    }

    func requestExampleData(site: Site, domainRu: Bool = true, completionHandler: @escaping (_ response: WebServiceResponse<String>) -> Void) {
        webService.performRequest(SiteWebServiceRequests.Example(site: site.rawValue, domainRu: domainRu), completionHandler: completionHandler)
    }
}
```

You can use two ready-made template provider classes - `WebServiceRequestProvider` (for one type of request) and `WebServiceGroupProvider` (for a group of requests). To support your set of valid requests, you can use `WebServiceRestrictedProvider` instead of `WebServiceGroupProvider`.

Вы можете использовать два готовых шаблоных класса провайдера - `WebServiceRequestProvider` (для одноготипа запроса) и `WebServiceGroupProvider` (для группы запросов). Для поддержки своего набора допустимых запросов вместо `WebServiceGroupProvider` вы можете использовать `WebServiceRestrictedProvider`.

#### Example providers:

```swift
let getListSiteWebProvider: WebServiceRequestProvider<SiteWebServiceRequests.GetList>
let exampleSiteWebProvider: WebServiceRequestProvider<SiteWebServiceRequests.Example>
let siteWebProvider:        WebServiceGroupProvider<SiteWebServiceRequests>

init(webService: WebService) {
    getListSiteWebProvider = webService.createProvider()
    exampleSiteWebProvider = webService.createProvider()
    siteWebProvider = webService.createProvider()
}

func performRequests() {
    // RequestProvider for WebServiceEmptyRequesting
    getListSiteWebProvider.performRequest() { [weak self] response in
        switch response {
        case .canceledRequest(duplicate: let duplicate): 
            break
    
        case .data(let list):
            self?.sites = list
    
        case .error(let error):
            self?.showError(error)
        }
    }
    
    // RequestProvider for request with params
    exampleSiteWebProvider.performRequest(.init(site: "google", domainRu: false)) { _ in }
    
    // GroupProvider, if request don't contains in group - assert (crash in debug, .canceledRequests in release usually).
    siteWebProvider.performRequest(SiteWebServiceRequests.Example(site: "yandex", domainRu: true)) { _ in }
}
```


### Storages

Для того чтобы приложение могло работать без интернета, очень полезно сохранять полученные данные в постоянном хранилище, т.к. данные сохраненные на устройстве пользователя читаются как правило куда быстрее чем через сеть и не зависят от состояния подключения к сети интернет.  В большинстве случаев для этого хватает сохранять последний полученный ответ с сервера и предоставлять его по требованию. Именно для этого случая предосмотрено хранилище в сервисе.

Вы можете сделать свой класс хранилища - нужно реализовать протокол `WebServiceStorage`. Но как правило этого не требуется, т.к. уже есть готовые классы для использования, которые покрывают все необходимые случаи использования - `WebServiceFileStorage`, `WebServiceDataBaseStorage` и `WebServiceMemoryStorage`. В большинстве случаев вы будете использовать только один на выбор, но в случае более сложной логики их можно комбинировать и повторять с разными настройками, разделяя их класификацией данных (подробнее об этом ниже). 

Не каждый запрос сохраняется в хранилище, а только те которые соотвествуют либо общему протоколу хранения (рекомендуется), либо протоколу конкретного типа храннилища. 
Данные могут храниться как правило в двух варианта:
- Raw: необработанные данные с сервера (как правило бинарные). Такой тип данных после чтения отправляется на обработку в подходящий обработчик (endpoint);
- Value: обработанные данные. Такой тип данных после чтения сразу отправляется как результирующий. 

Raw удобен тем что не нужно писать конвертер в бинаные данные, т.к. приходящие данные с сервера как правило уже в этом виде.
Value более оптимизирован, т.к. данные уже обработаны и не требует повтороной обработки, но требуется предоставить конвертеры в бинарный тип и обратно (обычно используется Codable). 
Если сложность обработки с сервера и в конветере в бинарный тип одинакова, то приемущественно лучше использовать Raw, иначе по возможности Value - зависит от данных и обработчика запроса. 

Обычно хранилища могут предоставить вместе с данными время (timeStamp) когда данные были сохранены - это позволяет оценить устарели ли данные для использования. 

Данные в хранилищах можно удалять по одному из признаков:
- Для конкретного запроса: `WebService.deleteInStorage(request:)`;
- Все данные в хранилищах предназначенные только для данных определенной классификации: `WebService.deleteAllInStorages(withDataClassification:)`;
- Все данные в хранилищах предназначенные для любой классификации, хранилища с конкретным списком классификаций будут пропущены: `WebService.deleteAllInStoragesWithAnyDataClassification()`;
- Все хранилища: `WebService.deleteAllInStorages()`;


#### Example support request storing:

```swift
extension SiteWebServiceRequests.Example: WebServiceRequestRawGeneralStoring {
    var identificatorForStorage: String? {
        return "SiteWebServiceRequests_Example"
    }
}

extension SiteWebServiceRequests.GetList: WebServiceRequestValueGeneralStoring {
    var identificatorForStorage: String? {
        return "SiteWebServiceRequests_GetList"
    }
    
    func writeDataToStorage(value: [String]) -> Data? {
        return try? PropertyListEncoder().encode(value)
    }
    
    func readDataFromStorage(data: Data) throws -> [String]? {
        return try PropertyListDecoder().decode([String].self, from: data)
    }
}
```

Для удобства разделения способа хранения запросы можно класификовать по определенному типу хранения - какоему именно решаете вы. По умолчанию все данные классифицируются как `WebServiceDefaultDataClassification = "default"`. 
К примеру может быть популярен такой случай: обычные кеши, кеши пользователя (удаляются при выходе из аккаунта) и временные кеши хранящийся только в оперативной памяти пока приложение запущено. На каждый класс данных есть свое хранилище. 

#### Example data classification:

```swift
enum WebServiceDataClass: Hashable {
    case user
    case temporary
}

extension WebService {
    static func create() -> WebService {
        let endpoint = WebServiceHtmlV2Endpoint()

        var storages: [WebServiceStorage] = []
        
        // Support temporary in memory Data Classification
        storages.append(WebServiceMemoryStorage(supportDataClassification: [WebServiceDataClass.temporary]))
   
        // Support user Data Classification
        if let dbUserURL = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("userCaches.sqlite"),
           let storage = WebServiceDataBaseStorage(sqliteFileUrl: dbUserURL, supportDataClassification: [WebServiceDataClass.user]) {
            storages.append(storage)
        }
        
        // Support any Data Classification (also can use WebServiceDataBaseStorage())
        if let storage = WebServiceFileStorage() {
            storages.append(storage)
        }

        return .init(endpoints: [endpoint], storages: storages)
    }
    
    func clearUserCaches() {
        deleteAllInStorages(withDataClassification: WebServiceDataClass.user)
    }
}

extension UserWebServiceRequests.GetInformation: WebServiceRequestRawGeneralStoring {
    var identificatorForStorage: String? {
        return "UserInformation"
    }
    
    var dataClassificationForStorage: AnyHashable { 
        return WebServiceDataClass.user
    }
}
```

Данные их хранилища всегда нужно запрашивать явно. Это запрос можно привязать к запросу на сервер в двух вариантах:
- `ReadStorageDependencyType.dependSuccessResult`: Запрос к хранилищу будет отменен если данные с сервера прийдут раньше без ошибки;
- `ReadStorageDependencyType.dependFull`: Запрос к хранилищу будет отменен если данные с сервера прийдут раньше без ошибки или сам запрос на сервер будет отменен или окажется дублирующим;

Запрос к серверу, к которому привязывается запрос к хранилищу должен быть вызван сразу после запроса к хранилищу - именно этот запрос будет привязан в независимости от его типа. 
Отменять явно запросы в хранилище можно только через связанный как `ReadStorageDependencyType.dependFull` основной запрос на сервер. 


#### Example read data in storages:

```swift
let request = ExampleRequest(param1: val1, param2: val2)

webService.readStorageData(request, dependencyNextRequest: .dependFull) { [weak self] timeStamp, response in
    if case .data(let data) = response {
        if let timeStamp = timeStamp, timeStamp.timeIntervalSinceNow > -3600 {   //no longer than 1 hour
            self?.dataFromStorage = data
        }
    }
}

webService.performRequest(request, excludeDuplicate: true) { [weak self] response in
    switch response {
    case .canceledRequest: 
        break

    case .data(let dataCustomType):
        self?.dataFromServer = dataCustomType

    case .error(let error):
        self?.showError(error)
    }
}

webService.readStorageData(TestRequest(), dependencyNextRequest: .notDepend) { [weak self] timeStamp, response in
    if case .data(let data) = response {
        self?.testData = data
    }
}
```



### Mock Endpoints

If part of the API is not available or you just need to generate temporary test data, you can use the `WebServiceMockEngine`. The mock engine emulates receiving and processing data from a real server and returns exactly the data that you specify.

Если часть API недоступна или вам просто нужно предоставить временные тестовые данные, вы можете использовать `WebServiceMockEngine`. Mock engine эмулирует получение и обработку данных с реального сервера и возвращает те данные, которые вы указали.


#### Example of request support mock engine:

```swift
extension ExampleRequest: WebServiceMockRequesting {
    var isSupportedRequest: Bool { return true }

    var timeWait: TimeInterval? { return 3 }

    var helperIdentifier: String? { return "template_html" }
    func createHelper() -> Any? {
        return "<html><body>%[BODY]%</body></html>"
    }

    func responseHandler(helper: Any?) throws -> String {
        if let template = helper as? String {
            return template.replacingOccurrences(of: "%[BODY]%", with: "<b>Hello world!</b>")
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}
```




## Author

[**ViR (Короткий Виталий)**](http://provir.ru)


## License

WebServiceSwift is released under the MIT license. [See LICENSE](https://github.com/ProVir/WebServiceSwift/blob/master/LICENSE) for details.


