# Storybook Webpack Example

<p>
  <!-- Web -->
  <img alt="Supports Expo Web" longdesc="Supports Expo Web" src="https://img.shields.io/badge/web-4630EB.svg?style=flat-square&logo=GOOGLE-CHROME&labelColor=4285F4&logoColor=fff" />
</p>

You can use Storybook to test and share your component library quickly and easily! This example shows how to use Expo libraries with Storybook CLI and Webpack.

## Launch your own

[![Launch with Expo](https://github.com/expo/examples/blob/master/.gh-assets/launch.svg?raw=true)](https://launch.expo.dev/?github=https://github.com/expo/examples/tree/master/with-storybook)

## Running with Storybook CLI

> web only / Webpack

This system uses the [community react-native-web addon](https://github.com/storybookjs/addon-react-native-web/) to configure Storybook's Webpack config to support running React Native for web.

This method runs your Expo components in a Storybook-React environment. This is different to Expo CLI's Webpack config.

- Create Expo project `npx create expo my-project`
  - You can use any template, we'll use the managed blank TypeScript project for this example.
- `cd` into the project and run `npx sb init --type react`, and select Webpack 5 to bootstrap a new React project.
- Install the requisite dependencies `npx expo add react-dom react-native-web @storybook/addon-react-native-web expo-pwa`
- The contents of `.storybook/main.js` have been modified to support loading the Expo config for the `expo-constants` libraries.
- Run `yarn build-storybook` to try it out!
  - The example should open to `http://localhost:6006/`

To learn more, configure the Storybook plugin according to [the official guide](https://github.com/storybookjs/addon-react-native-web/).


## Build version check from artifact in AppCircle


### 1. Unzip the archive

```unzip build.xcarchive.zip -d /tmp/xcarchive_check```


### 2. Find the app's Info.plist

```find /tmp/xcarchive_check -name "Info.plist" -path "*.app/Info.plist"```


### 3. Read the version values

```
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" /tmp/xcarchive_check/Volumes/*/workflow_data/*/AC_OUTPUT_DIR/build.xcarchive/Products/Applications/withstory.app/Info.plist

# then this

/usr/libexec/PlistBuddy -c "Print CFBundleVersion" /tmp/xcarchive_check/Volumes/*/workflow_data/*/AC_OUTPUT_DIR/build.xcarchive/Products/Applications/withstory.app/Info.plist
```

## Apk file if needed.

- npx expo prebuild --platform android --clean

###  1. Generate Android project
- npx expo prebuild --platform android --clean

### 2. Run the version script
bash scripts/update_version.sh
 
### 3. Build debug APK
cd android && ./gradlew assembleDebug

## option b for apk

### Install EAS CLI
npm install -g eas-cli

### Login to Expo
eas login

### Build APK (no local SDK needed, builds in cloud)

eas build --platform android --profile preview