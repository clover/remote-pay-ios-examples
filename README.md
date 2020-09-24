![Clover logo](https://www.clover.com/assets/images/public-site/press/clover_primary_gray_rgb.png)

# Example Implementation of the Clover SDK for iOS Integration

An example integration of the CloverConnector demonstrating communication between iOS/MacOS and a Clover Mini or Flex.

## Version

Current version: 4.0.0

This example is implemented using v4.0.0 of the CloverConnector SDK, which can be found at [https://github.com/clover/remote-pay-ios/releases/tag/4.0.0](https://github.com/clover/remote-pay-ios/releases/tag/4.0.0).

### Dependencies
* CloverConnector - Provides the communication between the example app and the Clover device.
* ObjectMapper - Provides JSON serialization and deserialization.
* SwiftyJSON - Provides simple JSON parsing.
* Starscream - provides websocket client capabilities.

## Building the example app
* Download and install [Xcode](https://apps.apple.com/us/app/xcode/id497799835?mt=12)
* Install CocoaPods
    * Run `sudo gem install cocoapods`
* Clone/download [this example's source](https://github.com/clover/remote-pay-ios-examples). 
    * cd into `<project root>/remote-pay-ios-examples/CloverConnector iOS Example`
    * Run `pod install`
        * This should create a Pods directory populated with the Pods specified in the Podspec
        * It should also create a workspace file that includes the project, plus a pods project
* Open the `CloverConnector.xcworkspace` file
* Change the Bundle identifier for the CloverConnector > CloverConnector_Example target
* Change the signing Team for the CloverConnector > CloverConnector_Example target

## Additional Resources

* [Release Notes](https://github.com/clover/remote-pay-ios/releases)
* [iOS SDK](https://github.com/clover/remote-pay-ios/tree/4.0.0)
* [Tutorial for the iOS SDK](https://docs.clover.com/clover-platform/docs/ios)
* [API Documentation](https://clover.github.io/remote-pay-ios/4.0.0/docs/index.html)
* [Clover Developer Community](https://community.clover.com/index.html)

## License 
Copyright © 2020 Clover Network, Inc. All rights reserved.
