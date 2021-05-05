# Publishing your app on Samsung Galaxy Store/TV App Store

## Prepare for release

- Make sure your app's manifest file (`tizen/tizen-manifest.xml`) is configured properly. Update the package id, version, label, icon, and required privileges if necessary. The rest of the file is automatically created by the tool, so you don't typically need to change them yourself. For more information on the XML elements in the file, see [Tizen Docs: Configuring the Application Manifest](https://docs.tizen.org/application/tizen-studio/native-tools/manifest-text-editor).

- Make sure your app is signed with a correct certificte for release. If you want to sign your app with a different ceritifate, open _Certificate Manager_ and set the profile you want to use to active.

- Build a release version of your app:

  ```sh
  # Watch app
  flutter-tizen build tpk --device-profile wearable

  # TV app
  flutter-tizen build tpk --device-profile tv
  ```

  A signed `.tpk` file should be generated in `build/tizen`.

- Test the release version of your app thoroughly on at least one real device.

  ```sh
  flutter-tizen install
  ```

## Release a watch app

To get started with releasing your watch app on Samsung Galaxy Store, go to [**Galaxy Store Seller Portal**](https://seller.samsungapps.com) and sign up for an account. After logging in, follow the steps in [this PDF file](https://developer.samsung.com/glxygames/file/8d1b5610-1a28-411b-846d-f58e15cf9711) to register your app. To learn more about the Seller Portal, visit [Samsung Developers: Get Started in Galaxy Store](https://developer.samsung.com/galaxy-games/get-started-in-galaxy-store.html).

## Release a TV app

**To be detailed.**
