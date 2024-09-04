# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'Kantan-Manga' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  
  # Pods for MangaReader
  pod 'ZIPFoundation', '~> 0.9'
  pod 'GCDWebServer/WebUploader', '~> 3.0'
  pod 'Firebase/Core'
  pod 'FirebaseCoreDiagnostics'
  pod 'FirebaseCore'  # Add this line
  pod 'GRDB.swift'
  pod 'UnrarKit'
  target 'Kantan-MangaTests' do
    inherit! :search_paths
    # Pods for testing
  end
  target 'Kantan-MangaIntegrationTests' do
    inherit! :search_paths
    # Pods for testing
  end
end

target 'Kantan-Keyboard' do
  use_frameworks!
  pod 'GRDB.swift'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if Gem::Version.new('11.0') > Gem::Version.new(config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'])
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
      end
    end
  end
end
