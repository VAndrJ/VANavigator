Pod::Spec.new do |s|
  s.name             = 'VANavigator'
  s.version          = '0.0.1'
  s.summary          = 'Easy to use UIKit navigation wrapper.'

  s.description      = <<-DESC
Easy to use UIKit navigation wrapper.
                       DESC

  s.homepage         = 'https://github.com/VAndrJ/VANavigator'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Volodymyr Andriienko' => 'vandrjios@gmail.com' }
  s.source           = { :git => 'https://github.com/VAndrJ/VANavigator.git', :tag => s.version.to_s }
  s.social_media_url = 'https://www.linkedin.com/in/vandrj/'

  s.ios.deployment_target = '13.0'

  s.source_files = 'VANavigator/Classes/**/*'

  s.frameworks = 'UIKit'

  s.swift_versions = '5.7'
end
