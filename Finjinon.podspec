Pod::Spec.new do |s|
  s.name         = "Finjinon"
  s.version      = "2.3.4"
  s.summary      = "Custom iOS camera optimized for taking a sequence of photos quickly and/or selecting from an image picker"
  s.description  = <<-DESC
Finjinon is a custom AVFoundation based camera UI, focused on quickly adding several photos. Selecting existing photos from the camera roll is supported through a pluggable interface, a default implementation using UIImagePickerController is provided.
                   DESC
  s.homepage     = "https://github.com/finn-no/Finjinon"
  s.screenshots  = "https://raw.githubusercontent.com/finn-no/Finjinon/master/Screenshots/screenshot.png"
  s.license      = "MIT"
  s.author             = { "FINN AS" => "apps@finn.no" }
  s.social_media_url   = "http://twitter.com/finn_tech"
  s.platform     = :ios
  s.ios.deployment_target = "8.1"
  s.source       = { :git => "https://github.com/finn-no/Finjinon.git", :tag => s.version.to_s }
  s.source_files  = "Finjinon"
end
