Pod::Spec.new do |s|
  s.name         = "WebServiceSwift"
  s.version      = "3.0.0"
  s.summary      = "Network layer as Service."
  s.description  = <<-DESC
			Written in Swift.
			Network layer as Service. 
			Contained simple cache storage on disk as files.
			Contained mock endpoint for test response without API.
                   DESC

  s.homepage     = "https://github.com/ProVir/WebServiceSwift"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "ViR (Vitaliy Korotkiy)" => "admin@provir.ru" }
  s.source       = { :git => "https://github.com/ProVir/WebServiceSwift.git", :tag => "#{s.version}" }

  s.swift_version = '4'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.default_subspec = 'General'
  
  s.subspec 'Core' do |ss|
    ss.source_files = 'Source/*.{h,swift}'
    ss.public_header_files = 'Source/*.h'
  end
  
  s.subspec 'General' do |ss|
      ss.source_files = 'Source/General/*.{swift,xcdatamodeld}'
    
    ss.dependency 'WebServiceSwift/Core'
  end

  s.subspec 'Alamofire' do |ss|
    ss.source_files = 'Source/Alamofire/*.swift'
    
    ss.dependency 'WebServiceSwift/General'
    ss.dependency 'Alamofire'
  end
  
end
