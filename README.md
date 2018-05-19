 ![WebServiceSwift](https://raw.githubusercontent.com/ProVir/WebServiceSwift/dev/WebServiceSwiftLogo.png) 


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
- [Simple File Storage](#simple-file-storage)
- [Mock Engine](#mock-engine)
- [Author](#author)
- [License](#license)


## General scheme use WebServiceSwift in project (SOA).

 ![Scheme](https://raw.githubusercontent.com/ProVir/WebServiceSwift/dev/WebServiceScheme.png) 


## Features

- [x] Easy interface for use
- [x] All work with network in inner engine and storage, hided from interface. 
- [x] Support Dispatch Queue.
- [x] One class for work with many types requests. 
- [x] One class for work with many engines and storages.
- [x] Simple storage on disk in package. Easy - add only engine and work!
- [x] Support NetworkActivityIndicator on iOS (from 2.2).
- [x] Thread safe (from 2.2).
- [x] Responses with concrete type in completion handler closures (from 2.2). 
- [x] Providers for requests (have RequestProvider) for work with only concrete request (from 2.2). Used to indicate more explicit dependencies (DIP). 
- [x] MockEngine for temporary or test  response data without use real api engine (from 2.2). 
- [ ] Simple HTTP Engine.  


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

> CocoaPods 1.1.0+ is required to build WebServiceSwift 2.1.0+.

To integrate WebServiceSwift into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

target '<Your Target Name>' do
    pod 'WebServiceSwift', '~> 2.2'
end
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
github "ProVir/WebServiceSwift" ~> 2.2
```

Run `carthage update` to build the framework and drag the built `WebServiceSwift.framework` into your Xcode project.

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. It is in early development, but WebServiceSwift does support its use on supported platforms. 

Once you have your Swift package set up, adding WebServiceSwift as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .Package(url: "https://github.com/ProVir/WebServiceSwift.git", majorVersion: 2)
]
```

### Manually

If you prefer not to use any of the aforementioned dependency managers, you can integrate WebServiceSwift into your project manually.

Copy files from directory `Source` in your project. 


---

## Usage (English / Русский)

To use the library, you need:
1. Create at least one type of request that implements the `WebServiceRequesting` protocol.
2. Create at least one class for work with the network (engine), implementing the protocol `WebServiceEngining`. It should provide its own protocol, the implementation of which with queries using the extensions will allow this engine to process the request.
3. If desired, you can create a class for storing hashes or use the existing one - `WebServiceSimpleStore`.
4. If desired, you can create a class for mocks requests when part API don't completed - `WebServiceMockEngine`.  It is recommended to use it first in the array of `engines`.
5. Write method to generate a `WebService` object. For example can be used factory to generate a WebService object or write an extension for it with a convenience constructor. 

**Note:** To use the library, remember to include it in each file: `import WebServiceSwift`.

The project has a less abstract example of using the library, which can be downloaded separately.

#

Для использования библиотеки вам нужно:
1. Создать как минимум один тип запроса, реализующий протокол `WebServiceRequesting`. 
2. Создать как минимум один класс для работ с сетью, реализующий протокол `WebServiceEngining`.  Он должен предоставлять собственный протокол, реализация которого у запросов с помощью расширения позволит этому движку обрабатывать запрос.
3. По желанию можно создать класс для хранения хешей или использовать существующий - `WebServiceSimpleStore`.  
4. По желанию можно создать класс для обработки mock запросов в случаях, когда часть АПИ не реализована - `WebServiceMockEngine`. Рекомендуется использовать его первым в списке `engines`. 
5. Написать метод получение готового объекта сервиса `WebService` . К примеру, можно использовать фабрику или написать для сервиса расширение с конструктором, вызывающий базовый конструктор с параметрами.

**Замечание:** для использования библиотеки не забудьте ее подключить в каждом файле: `import WebServiceSwift`.

В проекте есть менее абстрактный пример использования библиотеки, который можно скачать отдельно. 


### Base usage

#### An example request structure:

```swift
struct ExampleRequest: WebServiceRequesting, Hashable {
    let param1: String  
    let param2: Int 
    
    typealias ResultType = String
}
```

Such types of requests can be as many as you like and for their processing you can use different engines. There can also be several versions of the storage.

Таких типов запросов может быть сколько угодно и для их обработки можно использовать разные движки (engines). Разновидностей хранилища тоже может быть несколько.



#### Example of a class for working with a network using a library [Alamofire](https://github.com/Alamofire/Alamofire):

```swift
protocol WebServiceHtmlRequesting: WebServiceBaseRequesting {
    var url: URL { get }
}

class WebServiceHtmlEngine: WebServiceEngining {
    let queueForRequest: DispatchQueue? = DispatchQueue.global(qos: .background)
    let queueForDataHandler: DispatchQueue? = nil
    let queueForDataHandlerFromStorage: DispatchQueue? = DispatchQueue.global(qos: .default)
    let useNetworkActivityIndicator = true

    func isSupportedRequest(_ request: WebServiceBaseRequesting, rawDataTypeForRestoreFromStorage: Any.Type?) -> Bool {
        return request is WebServiceHtmlRequesting
    }

    func performRequest(requestId:UInt64, request:WebServiceBaseRequesting,
                        completionWithData: @escaping (_ data:Any) -> Void,
                        completionWithError: @escaping (_ error:Error) -> Void,
                        canceled: @escaping () -> Void) {

        guard let url = (request as? WebServiceHtmlRequesting)?.url else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }

        Alamofire.request(url).responseData { response in
            switch response.result {
            case .success(let data):
                completionWithData(data)

            case .failure(let error):
                completionWithError(error)
            }
        }
    }

    func cancelRequest(requestId: UInt64) { /* Don't support */ }

    func dataHandler(request: WebServiceBaseRequesting, data: Any, isRawFromStorage: Bool) throws -> Any? {
        guard request is WebServiceHtmlRequesting, let data = data as? Data else {
            throw WebServiceRequestError.notSupportDataHandler
        }

        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251)
    }
}
```

Working with the network is not a prerequisite for the engine. Behind this layer, you can hide the work with the database or at least temporarily put a stub. On the interface service side, this is not important and during the development of the engine can be unnoticeably replaced, without changing the code of the requests themselves.

Вовсе не обязательно движок (engine) должен работать с сетью. За этим слоем вы можете скрыть работу с БД или вовсе временно выставить заглушку. Со стороны интерфейса сервиса это не важно и в процессе разработки движки можно незаметно подменять, не меняя код самих запросов. 


#### Simple request support concrete engine example:

```swift
extension ExampleRequest: WebServiceHtmlRequesting {
    var url: URL {
        /* .... Logic create URL from param1 and param2 ... */
    }
    
    var responseDecoder: WebServiceHtmlResponseDecoder {
        /* ... Create concrete decoder for data from server ... */
    }
}
```

Each request must implement the support protocols for each engine that can handle it. If multiple engines are supported by a single query, then the first engine, supported from the list `engines`, is selected for processing.

Каждый запрос должен реализовать протоколы поддержки каждого движка, который может его обрабатывать. Если поддерживается несколько движков одним запросом, то выбирается первый поддерживаемый из списка `engines` для обработки. 


#### WebService create service - used factory constructor example:

```swift
extension WebService {
    convenience init(delegate: WebServiceDelegate? = nil) {
        let engine = WebServiceEngine()
        
        var storages: [WebServiceStoraging] = []
        if let storage = WebServiceSimpleStore() {
            storages.append(storage)
        }
        
        self.init(engines: [WebServiceMockEngine(), engine], storages: storages)
        
        self.delegate = delegate
    }
}
```

You can also make support for a singleton - an example of this approach is in the source code.

Также можно сделать поддержку синглетона - пример такого подхода есть в исходниках. 


#### An example of using the closure and without reading the hash from the disk:

```swift
let webService = WebService()

webService.performRequest(ExampleRequest(param1: val1, param2: val2)) { [weak self] response in
    switch response {
    case .canceledRequest, .duplicateRequest: 
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


#### An example using a delegate and reading a hash from disk:

```swift
let webService = WebService(delegate: self)

webService.performRequest(ExampleRequest(param1: val1, param2: val2), includeResponseStorage: true)

func webServiceResponse(request: WebServiceRequesting, isStorageRequest: Bool, response: WebServiceAnyResponse) {
    if let request = request as? ExampleRequest {
        let response = response.convert(request: request)

        switch response {
        case .canceledRequest, .duplicateRequest: 
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

If data from the disk is received earlier than from the network, or there will be an error in retrieving data from the network - hashed data will return to the delegate (`isStorageRequest = true`), otherwise only data from the network will be received.

Если данные с диска будут получены раньше, чем с сети, либо произойдет ошибка получения данных с сети - хешированные данные вернутся в делегат (`isStorageRequest = true`), иначе будут получены данные только с сети.


#### Example of requesting hash data without requesting a server:

```swift
let webService = WebService()

webService.requestReadStorage(ExampleRequest(param1: val1, param2: val2)) { [weka self] response in
    switch response {
    case .canceledRequest, .duplicateRequest: 
        break

    case .data(let dataCustomType):
        self?.dataFromStorage = dataCustomType
    
    case .error(let error):
        self?.showError(error)
    }  
}
```

You can also request data from the storage. In case of a reading error, you will be able to find out the reason. Enums `.canceledRequest` and `.duplicateRequest` will never be returned.

Также можно отдельно запросить данные с хеша. В случае ошибки чтения можно будет узнать причину. Значения `.canceledRequest` и `.duplicateRequest` никогда не будут возвращены. 



### Simple File Storage

For support response data store in `WebServiceSimpleFileStorage` you need conform to `WebServiceRequestRawStorage` (save raw binary data from server and decode in engine when read) or `WebServiceRequestValueStorage` (save any decoded types from server).


#### Example of request support storage as raw data:

```swift
extension ExampleRequest: WebServiceRequestRawStorage {
    var identificatorForRawStorage: String? {
        return "example_data.bin"
    }
}
```

#### Example of request support storage as value data:

```swift
extension ExampleRequest: WebServiceRequestValueStorage {
    var identificatorForValueStorage: String? {
        return "example_data.txt"
    }

    func writeDataToStorage(value: Any) -> Data? {
        if let value = value as? String {
            return value.data(using: String.Encoding.utf8)
        } else {
            return nil
        }
    }

    func readDataFromStorage(data: Data) throws -> Any? {
        return String(data: data, encoding: String.Encoding.utf8)
    }
}
```

### Mock Engine

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


