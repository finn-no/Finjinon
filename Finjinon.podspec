Pod::Spec.new do |s|
  s.name         = "Finjinon"
  s.version      = "3.0.0"
  s.summary      = "Custom iOS camera optimized for taking a sequence of photos quickly and/or selecting from an image picker"
  s.description  = <<-DESC
Finjinon is a custom AVFoundation based camera UI, focused on quickly adding several photos. Selecting existing photos from the camera roll is supported through a pluggable interface, a default implementation using UIImagePickerController is provided.
                   DESC
  s.author       = "FINN.no AS"
  s.homepage     = "https://github.com/finn-no/Finjinon"
  s.screenshots  = "https://raw.githubusercontent.com/finn-no/Finjinon/master/Screenshots/screenshot.png"
  s.license      = "MIT"
  s.social_media_url  = "http://twitter.com/finn_tech"
  s.platform          = :ios, '10.0'
  s.swift_version     = '4.2'
  s.source            = { :git => "https://github.com/finn-no/Finjinon.git", :tag => s.version }
  s.requires_arc      = true
  s.source_files      = "Source/*.swift"
  s.frameworks        = "Foundation"
end
