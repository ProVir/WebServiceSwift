# WebServiceSwift

[![CocoaPods Compatible](https://cocoapod-badges.herokuapp.com/v/WebServiceSwift/badge.png)](http://cocoapods.org/pods/WebServiceSwift)
[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/ProVir/WebServiceSwift)
[![Platform](https://cocoapod-badges.herokuapp.com/p/WebServiceSwift/badge.png)](http://cocoapods.org/pods/WebServiceSwift)
[![License](https://cocoapod-badges.herokuapp.com/l/WebServiceSwift/badge.png)](https://github.com/ProVir/WebServiceSwift/blob/master/LICENSE)

Wrapper for working with network. Support Swift 3.0 - 4.0

- [Features](#features)
- [Requirements](#requirements)
- [Communication](#communication)
- [Installation](#installation)
- [Usage (English / Русский)](#usage-english--%D0%A0%D1%83%D1%81%D1%81%D0%BA%D0%B8%D0%B9)
- [Author](#author)
- [License](#license)



## Features

- [x] Easy interface for work
- [x] All work with network in inner engine and storage, hided from interface. 
- [x] Support Dispatch Queue.
- [x] One class work with many types requests. 
- [x] One class work with many engines and storages.
- [x] Simple storage on disk in package. Easy - add only engine and work!
- [ ] Support work with NetworkActivityIndicator on iOS.
- [ ] Simple HTTP Engine.  


## Requirements

- iOS 8.0+ / macOS 10.10+ / tvOS 9.0+ / watchOS 2.0+
- Xcode 8.1, 8.2, 8.3, and 9.0
- Swift 3.0, 3.1, 3.2, and 4.0


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
    pod 'WebServiceSwift', '~> 2.1'
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
github "ProVir/WebServiceSwift" ~> 2.1
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
2. Create at least one class for work with the network (engine), implementing the protocol `WebServiceEngining`.
3. If desired, you can create a class for storing hashes or use the existing one - `WebServiceSimpleStore`.
4. Write a factory to generate a WebService object or write an extension for it with a convenience constructor. 

**Note:** To use the library, remember to include it in each file: `import WebServiceSwift`.

The project has a less abstract example of using the library, which can be downloaded separately.

#

Для использования библиотеки вам нужно:
1. Создать как минимум один тип запроса, реализующий протокол `WebServiceRequesting`. 
2. Создать как минимум один класс для работ с сетью, реализующий протокол `WebServiceEngining`. 
3. По желанию можно создать класс для хранения хешей или использовать существующий - `WebServiceSimpleStore`.
4. Написать метод - фабрику для генерации объекта `WebService` или написать для него расширение с конструктором, вызывающий базовый конструктор с параметрами.

**Замечание:** для использования библиотеки не забудьте ее подключить в каждом файле: `import WebService`.

В проекте есть менее абстрактный пример использования библиотеки, который можно скачать отдельно. 



#### An example request structure:

```swift
struct RequestMethod: WebServiceRequesting {
    let method:WebServiceMethod    
    let requestKey:AnyHashable?
    
    init(requestKey:AnyHashable? = nil, method:WebServiceMethod) {
	self.requestKey = requestKey
        self.method = method
    }
}

enum WebServiceMethod {
    case method1(ParamType1, param2:ParamType2)
    case method2(ParamType1)
    case method3
}

```

Such types of requests can be as many as you like and for each one you can use your own class - the engine. There can also be several versions of the storage.

Таких типов запросов может быть сколько угодно и для каждого можно использовать свой класс - движок (engine). Разновидностей хранилища тоже может быть несколько.



#### Example of a class for working with a network using a library [Alamofire](https://github.com/Alamofire/Alamofire):

```swift
class WebServiceEngine: WebServiceEngining {
    
    let queueForRequest:DispatchQueue? = nil
    let queueForDataHandler:DispatchQueue? = nil
    let queueForDataHandlerFromStorage:DispatchQueue? = DispatchQueue.global(qos: .default)
    
    
    func isSupportedRequest(_ request: WebServiceRequesting, rawDataForRestoreFromStorage: Any?) -> Bool {
        return request is RequestMethod
    }

    
    func request(requestId:UInt64, request:WebServiceRequesting,
                 completionWithData:@escaping (_ data:Any) -> Void,
                 completionWithError:@escaping (_ error:Error) -> Void,
                 canceled:@escaping () -> Void) {
        
        guard let method = (request as? RequestMethod)?.method else {
            completionWithError(WebServiceRequestError.notSupportRequest)
            return
        }

	//Custom method without example
	var url = urlFromMethod(method) 

        Alamofire.request(method.url).responseData { response in
            switch response.result {
            case .success(let data):
                completionWithData(data)
                
            case .failure(let error):
                completionWithError(error)
            }
        }
    }

    
    func cancelRequest(requestId: UInt64) {
        
    }
    
    
    func dataHandler(request:WebServiceRequesting, data:Any, isRawFromStorage:Bool) throws -> Any? {
        guard request is RequestMethod, let data = data as? Data else {
            throw WebServiceRequestError.notSupportDataHandler
        }

        return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1251)
    }
    
}
```

Working with the network is not a prerequisite for the engine. Behind this layer, you can hide the work with the database or at least temporarily put a stub. On the interface side, this is not important and during the development of the engine can be unnoticeably replaced, without changing the code of the requests themselves (provided that the type of data returned does not change).


Вовсе не обязательно движок (engine) должен работать с сетью. За этим слоем вы можете скрыть работу с БД или вовсе временно выставить заглушку. Со стороны интерфейса это не важно и в процессе разработки движки можно незаметно подменять, не меняя код самих запросов (при условии что тип возвращаемых данных не меняется). 


#### WebService Factory example:

```swift
extension WebService {
    
    convenience init(delegate:WebServiceDelegate? = nil) {
        let engine = WebServiceEngine()
        
        var storages:[WebServiceStoraging] = []
        if let storage = WebServiceSimpleStore() {
            storages.append(storage)
        }
        
        self.init(engines: [engine], storages:storages)
        
        self.delegate = delegate
    }
}
```

You can also make support for a singleton - an example of this approach is in the source code.

Также можно сделать поддержку синглетона - пример такого подхода есть в исходниках. 


#### An example of using the closure and without reading the hash from the disk:

```swift
let webService = WebService()

webService.request(RequestMethod(method: .method1(val1, param2: val2))) { response in
            switch response {
            case .canceledRequest, .duplicateRequest: 
		break

            case .data(let dataCustomType):
                dataFromServer = dataCustomType
                
            case .error(let error):
                showError(error)

            }
        }
```

We pass the data in request, on the output we get the ready object for display.

Передаем данные в запросе, на выходе получаем готовый объект для отображения. 



#### An example using a delegate and reading a hash from disk:

```swift
let webService = WebService(delegate:self)

webService.request(RequestMethod(method: .method2(val1)), includeResponseStorage: true)

func webServiceResponse(request: WebServiceRequesting, isStorageRequest: Bool, response: WebServiceResponse) {
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
```

If data from the disk is received earlier than from the network, or there will be an error in retrieving data from the network - hashed data will return to the delegate (`isStorageRequest = true`), otherwise only data from the network will be received.

Если данные с диска будут получены раньше, чем с сети, либо произойдет ошибка получения данных с сети - хешированные данные вернутся в делегат (`isStorageRequest = true`), иначе будут получены данные только с сети.


#### Example of requesting hash data without requesting a server:

```swift
let webService = WebService()

webService.requestReadStorage(RequestMethod(.method3)) { response in
          switch response {
            case .canceledRequest, .duplicateRequest: 
		break

            case .data(let dataCustomType):
		dataFromStorage = dataCustomType
                
            case .error(let error):
                showError(error)

            }  
        }
```

You can also request data from the storage. In case of a reading error, you will be able to find out the reason. Enums `.canceledRequest` and `.duplicateRequest` will never be returned.

Также можно отдельно запросить данные с хеша. В случае ошибки чтения можно будет узнать причину. Значения `.canceledRequest` и `.duplicateRequest` никогда не будут возвращены. 




## Author

[**ViR (Короткий Виталий)**](http://provir.ru)


## License

WebServiceSwift is released under the MIT license. [See LICENSE](https://github.com/ProVir/WebServiceSwift/blob/master/LICENSE) for details.


