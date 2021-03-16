Pod::Spec.new do |s|
  s.name           = 'LucidTestKit'
  s.version        = `cat VERSION`
  s.summary        = 'Test library for Lucid.'
  s.homepage       = 'https://github.com/scribd/Lucid'
  s.license        = { :type => 'MIT', :text => `cat LICENSE` }
  s.author         = { 'Theophane Rupin' => 'theophane.rupin@gmail.com' }
  s.source         = { :git => "https://github.com/scribd/Lucid.git", :tag => `cat VERSION` }
  
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  s.source_files   = 'LucidTestKit/**/*.swift'
  s.requires_arc   = true
  s.swift_version  = '5.0'
end