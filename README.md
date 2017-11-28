## Finjinon

Finjinon is a custom AVFoundation based camera UI, focused on quickly adding several photos. Selecting existing photos from the camera roll is supported through a pluggable interface, a default implementation using UIImagePickerController is provided.

Captured images are provided as an `Asset` which can retrieve image data asynchrously in order to keep memory usage low.

* Quickly capture multiple photos (not bursted though)
* Remove photos
* Adapter based photo picking from photo library
* Drag to reorder captured photos (longpress on thumbnail to initiate)

![screenshot](Screenshots/screenshot.png)

## Requirements

* iOS 9.0
* Swift 4.0

## Installation

**Finjinon** is available through [Carthage](https://github.com/Carthage/Carthage). To install
it, simply add the following line to your Cartfile:

```ruby
github "finn-no/Finjinon"
```

## Usage

See the included Example project for usage.

## License

MIT, see LICENSE
