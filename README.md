## Finjinon

Finjinon is a custom AVFoundation based camera UI, focused on quickly adding several photos. Selecting existing photos from the camera roll is supported through a pluggable interface, a default implementation using UIImagePickerController is provided.

Captured images are provided as an `Asset` which can retrieve image data asynchrously in order to keep memory usage low.

* Quickly capture multiple photos (not bursted though)
* Remove photos
* Adapter based photo picking from photo library
* Drag to reorder captured photos (longpress on thumbnail to initiate)

![screenshot](Screenshots/screenshot.png)

## Requirements

* iOS8+
* Swift 2.0

## Installation

If you need to support iOS7 you have to copy the sources in `Finjinon` into your project. Otherwise there's a Finjinon.podspec available in the repo.

## Usage

See the included Example project for usage.

## License

MIT, see LICENSE
