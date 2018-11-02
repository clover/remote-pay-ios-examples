![Clover logo](https://www.clover.com/assets/images/public-site/press/clover_primary_gray_rgb.png)

# Example Implementation of the Clover SDK for iOS Integration

An example integration of the CloverConnector demonstrating communication between iOS/MacOS and a Clover Mini or Flex.

## Version

Current version: 3.0.0

This example is implemented using v3.0.0 of the CloverConnector SDK, which can be found at [https://github.com/clover/remote-pay-ios/tree/3.0.0](https://github.com/clover/remote-pay-ios/tree/3.0.0).

### Dependencies
* CloverConnector - Provides the communication between the example app and the Clover device.
* ObjectMapper - Provides JSON serialization and deserialization.
* SwiftyJSON - Provides simple JSON parsing.
* Starscream - provides websocket client capabilities.

## Building the example app
* Download and install Xcode 10
* Install CocoaPods
    * Run `sudo gem install cocoapods`
* Clone/download the CloverConnector repository
    * cd into `remote-pay-ios/Example`
    * Run `pod install`
        * This should create a Pods directory populated with the Pods specified in the Podspec
        * It should also create a workspace file that includes the project, plus a pods project
    * Run `pod install` a second time
        * This should update the Pods directory with the installed Pods' dependencies
* Open the `CloverConnector.xcworkspace` file
* Change the Bundle identifier for the CloverConnector > CloverConnector_Example target
* Change the signing Team for the CloverConnector > CloverConnector_Example target

## Additional Resources

* [Release Notes](https://github.com/clover/remote-pay-ios/releases)
* [iOS SDK](https://github.com/clover/remote-pay-ios/tree/3.0.0)
* [Tutorial for the iOS SDK](https://docs.clover.com/build/getting-started-with-clover-connector/?sdk=ios)
* [API Documentation](https://clover.github.io/remote-pay-ios/3.0.0/docs/index.html)
* [Clover Developer Community](https://community.clover.com/index.html)

## License 
Copyright © 2018 Clover Network, Inc. All rights reserved.
