 ![WebServiceSwift](https://raw.githubusercontent.com/ProVir/WebServiceSwift/master/WebServiceSwiftLogo.png) 


[![CocoaPods Compatible](https://cocoapod-badges.herokuapp.com/v/WebServiceSwift/badge.png)](http://cocoapods.org/pods/WebServiceSwift)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/ProVir/WebServiceSwift)
[![Platform](https://cocoapod-badges.herokuapp.com/p/WebServiceSwift/badge.png)](http://cocoapods.org/pods/WebServiceSwift)
[![License](https://cocoapod-badges.herokuapp.com/l/WebServiceSwift/badge.png)](https://github.com/ProVir/WebServiceSwift/blob/master/LICENSE)

Network layer as Service. Service as an interface for interacting with your web server. Support Swift 5. 

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


## General scheme use WebServiceSwift in project.

 ![Scheme](https://raw.githubusercontent.com/ProVir/WebServiceSwift/master/WebServiceScheme_v3.png) 


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
- Xcode 10.2 and above
- Swift 5.0 and above


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

> CocoaPods 1.6.0+ is required to build WebServiceSwift 3.0.0+.

To integrate WebServiceSwift into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'

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
    .package(url: "https://github.com/ProVir/WebServiceSwift.git", from: "3.0.0")
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

class WebServiceHtmlEndpoint: WebServiceEndpoint {
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

Important - the data passed to `completionWithRawData` can not always be of the `Data` type, in this case it is recommended that this type implement the `WebServiceRawDataSource` protocol. Binary data is needed to be able to save them as Raw in the storage. It is worth noting that from theStorage to the handler, the read data comes in the form of `Data` and it should be taken into account.

Важный момент - данные передаваемые в `completionWithRawData` не всегда могут иметь тип `Data`, в этом случае рекомендуется чтобы этот тип реализовывал протокол `WebServiceRawDataSource`. Бинарные данные нужны для возможности сохранять их как Raw в кеше. Стоит обратить внимание на то, что из хранилища в обработчик прочитанные данные поступают как `Data` и следует это предусмотреть.

#### Example:

```swift
/// Data from server as raw, used only as example
struct ServerData: WebServiceRawDataSource {
    let statusCode: Int
    let binary: Data

    var binaryRawData: Data? { return binary }
}

func dataProcessing(request: WebServiceBaseRequesting, rawData: Any, fromStorage: Bool) throws -> Any {
    guard request is WebServiceHtmlRequesting else {
        throw WebServiceRequestError.notSupportDataProcessing
    }

    let binary: Data
    if let data = rawData as? Data {
        //Data from Storage
        binary = data
    } else if let data = rawData as? ServerData {
        //Data from server
        binary = data.binary
    } else {
        throw WebServiceRequestError.notSupportDataProcessing
    }

    return String(data: binary, encoding: .utf8) ?? String(data: binary, encoding: .windowsCP1251) ?? ""
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
        let endpoint = WebServiceHtmlV2Endpoint()
        
        var storages: [WebServiceStoraging] = []
        if let storage = WebServiceDataBaseStorage() {
            storages.append(storage)
        }
        
        self.init(engines: [WebServiceMockEndpoint(), endpoint], storages: storages)
    }
}
```

You can also make support for a singleton - an example of this approach is in the source code example.

Также можно сделать поддержку синглетона - пример такого подхода есть в исходниках примера. 


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

#

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

You can also exclude duplicate requests. For this, the request must implement the protocol `Hashable` or use a key when perform request (any type that implements the protocol` Hashable`).
Requests that turn out to be duplicates will immediately end with the response `WebServiceResponse.canceledRequest(duplicate: true)`.

Также можно исключать дублирующие запросы. Для этого запрос должен реализовывать протокол `Hashable` или использовать ключ (key) при запросе (любой тип реализующий протокол `Hashable`). 
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

To add more explicit dependencies to your project, as well as to protect against certain errors, you can use providers. Providers are wrappers over WebService and hide it with private access. They provide access only to a limited type of requests in the form of convenient interfaces, excluding a certain class of errors in the code. The main purpose of the provider is to give the access to the permissible part of the WebService functional in the right place in the code.

Для добавления более явных зависимостей в ваш проект, а также для защиты от некоторых ошибок, вы можете использовать провайдеры. Провайдеры являются обертками над WebService и скрывают его private доступом. Они предоставляют доступ только ограниченному типу запросов в виде удобных интерфейсов, исключающие определенный класс ошибок в коде. Основная цель провайдера - в нужном месте в коде дать доступ только к допустимой части функционала WebService. 

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

You can use two ready-made generic provider classes - `WebServiceRequestProvider` (for one type of request) and `WebServiceGroupProvider` (for a group of requests). To support your set of valid requests, you can use `WebServiceRestrictedProvider` instead of `WebServiceGroupProvider`.

Вы можете использовать два готовых шаблоных класса провайдера - `WebServiceRequestProvider` (для одного типа запроса) и `WebServiceGroupProvider` (для группы запросов). Для поддержки своего набора допустимых запросов вместо `WebServiceGroupProvider` доступен `WebServiceRestrictedProvider`.

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

In order for the application to work without the Internet, it is very useful to save the received data in permanent storage, because data stored on the user's device is read as a rule much faster than through the network and does not depend on the state of connection to the Internet.  In most cases, this is enough to save the last received response from the server and provide it on demand. It is for this case that the storage in the service is provided.

You can create your own storage class by implementing the `WebServiceStorage` protocol. But in most cases this is not required, since there are already ready classes for use that cover all the necessary cases of use - `WebServiceFileStorage`, `WebServiceDataBaseStorage` and `WebServiceMemoryStorage`. In most cases, you will only use one to choose from, but in the case of more complex logic, you can combine and repeat them with different settings, separating them by the classification of the data (more on this below).

Not every request is stored in the storage, but only those that meet either the general storage protocol (recommended) or the protocol of a particular storage type.
Data can be stored as a rule in two versions:
- Raw: raw data from the server (usually binary). This type of data after reading is sent for processing to a suitable endpoint;
- Value: processed data. This type of data is immediately sent as a result after reading.

Raw is convenient because you do not need to write the converter to binaries, since the incoming data from the server is usually already in this form.
Value is more optimized, since the data is already processed and does not require re-processing, but it is required to provide converters to binary type and vice versa (Codable is usually used).
If the complexity of processing from the server and in the value converter is the same, then it is much better to use Raw, otherwise, if possible Value - depends on the data and processing request.

Usually storages can provide along with the data (timeStamp) when the data has been saved - this allows you to evaluate whether the data is outdated for use.

The data in storages can be deleted according to one of the following characteristics:
- For concrete request: `WebService.deleteInStorage(request:)`;
- All data in certain storages, intended only for a specific classification data: `WebService.deleteAllInStorages(withDataClassification:)`;
- All data in certain storages intended for any classification, storages with a specific list of data classifications will be omitted: `WebService.deleteAllInStoragesWithAnyDataClassification()`;
- All data in all storages: `WebService.deleteAllInStorages()`;

#

Для того чтобы приложение могло работать без интернета, очень полезно сохранять полученные данные в постоянном хранилище, т.к. данные сохраненные на устройстве пользователя читаются как правило куда быстрее чем через сеть и не зависят от состояния подключения к сети интернет.  В большинстве случаев для этого хватает сохранять последний полученный ответ с сервера и предоставлять его по требованию. Именно для этого случая предосмотрено хранилище в сервисе.

Вы можете сделать свой класс хранилища - нужно реализовать протокол `WebServiceStorage`. Но как правило этого не требуется, т.к. уже есть готовые классы для использования, которые покрывают все необходимые случаи использования - `WebServiceFileStorage`, `WebServiceDataBaseStorage` и `WebServiceMemoryStorage`. В большинстве случаев вы будете использовать только один на выбор, но в случае более сложной логики их можно комбинировать и повторять с разными настройками, разделяя их классификацией данных (подробнее об этом ниже). 

Не каждый запрос сохраняется в хранилище, а только те которые соотвествуют либо общему протоколу хранения (рекомендуется), либо протоколу конкретного типа храннилища. 
Данные могут храниться как правило в двух вариантах:
- Raw: необработанные данные с сервера (как правило бинарные). Такой тип данных после чтения отправляется на обработку в подходящий обработчик (endpoint);
- Value: обработанные данные. Такой тип данных после чтения сразу отправляется как результирующий. 

Raw удобен тем что не нужно писать конвертер в бинаные данные, т.к. приходящие данные с сервера как правило уже в этом виде.
Value более оптимизирован, т.к. данные уже обработаны и не требует повтороной обработки, но требуется предоставить конвертеры в бинарный тип и обратно (обычно используется Codable). 
Если сложность обработки с сервера и в конветере в бинарный тип одинакова, то приемущественно лучше использовать Raw, иначе по возможности Value - зависит от данных и обработчика запроса. 

Обычно хранилища могут предоставить вместе с данными время (timeStamp) когда данные были сохранены - это позволяет оценить устарели ли данные для использования. 

Данные в хранилищах можно удалять по одному из признаков:
- Для конкретного запроса: `WebService.deleteInStorage(request:)`;
- Все данные в определенных хранилищах, предназначенные только для данных определенной классификации: `WebService.deleteAllInStorages(withDataClassification:)`;
- Все данные в определенных хранилищах, предназначенные для любой классификации, хранилища с конкретным списком классификаций будут пропущены: `WebService.deleteAllInStoragesWithAnyDataClassification()`;
- Все данные во всех хранилищах: `WebService.deleteAllInStorages()`;


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

To separate the storage method, requests can be classified by a specific type of storage - which you decide. By default, all data is classified as `WebServiceDefaultDataClassification = "default"`. 

For example, this case can be popular: ordinary caches, user caches (deleted when leaving the account) and temporary caches stored only in RAM while the application is running. Each data class has its own storage.

Для удобства разделения способа хранения, запросы можно классификовать по определенному типу хранения - какому именно решаете вы. По умолчанию все данные классифицируются как `WebServiceDefaultDataClassification = "default"`. 

К примеру, может быть популярен такой случай: обычные кеши, кеши пользователя (удаляются при выходе из аккаунта) и временные кеши хранящийся только в оперативной памяти пока приложение запущено. На каждый класс данных есть свое хранилище. 

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
    var dataClassificationForStorage: AnyHashable { 
        return WebServiceDataClass.user
    }

    var identificatorForStorage: String? {
        return "UserInformation"
    }
}
```

Data from storage should always be requested explicitly. This request can be linked to the request to the server in two versions:
- `WebService.ReadStorageDependencyType.dependSuccessResult`: The request to storage will be canceled if the data from the server comes before without an error;
- `WebService.ReadStorageDependencyType.dependFull`: The request to storage will be canceled if the data from the server comes earlier without error or the request to the server itself will be canceled or it will be a duplicate.

The request to the server to which the request to storage is attached should be called immediately after the request to storage - this request will be bound regardless of its type. 
It is possible to cancel explicit requests in storage only through the main request to the server associated with it as `.dependFull`.


Данные из хранилища всегда нужно запрашивать явно. Это запрос можно привязать к запросу на сервер в двух вариантах:
- `WebService.ReadStorageDependencyType.dependSuccessResult`: Запрос к хранилищу будет отменен если данные с сервера придут раньше без ошибки;
- `WebService.ReadStorageDependencyType.dependFull`: Запрос к хранилищу будет отменен если данные с сервера придут раньше без ошибки или сам запрос на сервер будет отменен или окажется дублирующим.

Запрос к серверу, к которому привязывается запрос к хранилищу должен быть вызван сразу после запроса к хранилищу - именно этот запрос будет привязан в независимости от его типа. 
Отменять явно запросы в хранилище можно только через связанный как `.dependFull` основной запрос на сервер. 


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

/// responseOnlyData - ignore errors and canceled read
webService.readStorage(ExampleRequest(param1: val1, param2: val2), dependencyNextRequest: .dependSuccessResult, responseOnlyData: true, responseDelegate: self)
```


### Mock Endpoints

If part of the API is not available or you just need to generate temporary test data, you can use the `WebServiceMockEndpoint`. The mock endpoint emulates receiving and processing data from a real server and returns exactly the data that you specify. To maintain its request, you need to extend the request to the protocol `WebServiceMockRequesting`.

Если часть API недоступна или вам просто нужно предоставить временные тестовые данные, вы можете использовать `WebServiceMockEndpoint`. Mock endpoint эмулирует получение и обработку данных с реального сервера и возвращает те данные, которые вы указали. Для поддержки его запросом, нужно запрос расширить до протокола `WebServiceMockRequesting`. 

#### Example of request support mock engine:

```swift
extension ExampleRequest: WebServiceMockRequesting {
    var isSupportedRequestForMock: Bool { return true }
    var mockTimeDelay: TimeInterval? { return 3 }

    var mockHelperIdentifier: String? { return "template_html" }
    func mockCreateHelper() -> Any? {
        return "<html><body>%[BODY]%</body></html>"
    }

    func mockResponseHandler(helper: Any?) throws -> String {
        if let template = helper as? String {
            return template.replacingOccurrences(of: "%[BODY]%", with: "<b>Hello world!</b>")
        } else {
            throw WebServiceResponseError.invalidData
        }
    }
}
```

To support your request types instead of `WebServiceMockRequesting`, you can create your mock class by inheriting from `WebServiceMockEndpoint` and overriding the functions `isSupportedRequest()` and `convertToMockRequest`. The latter function converts your request into a suitable type with the implementation of the protocol `WebServiceMockRequesting`. Its class for processing mocks can be useful in the first place for a unit tests - so as not to add the implementation of mocks to the main code.

The other endpoint is well suited for a unit tests - `WebServiceMockRequestEndpoint`. Each instance is intended only for one type of request, all processing is indicated in the place of configuration of the service. Such endpoints can be any number.


Для поддержки своих типов запросов взамен `WebServiceMockRequesting` вы можете создать свой mock класс наследовавшись от `WebServiceMockEndpoint` и переопределив функции `isSupportedRequest()` и `convertToMockRequest`. Последняя функция конвертирует ваш запрос в подходящий ему тип с реализацией протокола `WebServiceMockRequesting`.  Свой класс для обработки моков может быть полезен в первую очередь для юнит тестов - чтобы не добавлять реализации моков в основной код.

Другой вариант, хорошо подходит для юнит тестов - `WebServiceMockRequestEndpoint`. Каждый экземпляр предназначен только для одного типа запроса, вся обработка указывается в месте настройки сервиса. Таких обработчиков может быть сколько угодно. 

#### Example used WebServiceMockRequestEndpoint:

```swift
let template = "<html><body>%[BODY]%</body></html>"
let mockRequest = WebServiceMockRequestEndpoint.init(timeDelay: 3) { (request: ExampleRequest) -> String in
    return template.replacingOccurrences(of: "%[BODY]%", with: "<b>Hello world from MockRequestEndpoint!</b>")
}

let webService = WebService(endpoints: [mockRequest, mockRequest2, mockRequest3], storages: [])
```


## Author

[**ViR (Короткий Виталий)**](http://provir.ru)


## License

WebServiceSwift is released under the MIT license. [See LICENSE](https://github.com/ProVir/WebServiceSwift/blob/master/LICENSE) for details.


