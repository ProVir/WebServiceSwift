Pod::Spec.new do |s|
  s.name         = "WebServiceSwift"
  s.version      = "2.2.0"
  s.summary      = "Network layer as Service."
  s.description  = <<-DESC
			Written in Swift.
			Network layer as Service. 
			Contained simple cache storage on disk as files.
			Contained mock engine for test response without API. 
                   DESC

  s.homepage     = "https://github.com/ProVir/WebServiceSwift"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "ViR (Vitaliy Korotkiy)" => "admin@provir.ru" }

  s.swift_version = '4'
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.tvos.deployment_target = '9.0'
  s.watchos.deployment_target = '2.0'

  s.source       = { :git => "https://github.com/ProVir/WebServiceSwift.git", :tag => "#{s.version}" }


  s.source_files = 'Source/*.{h,swift}'
  s.public_header_files = 'Source/*.h'

end
