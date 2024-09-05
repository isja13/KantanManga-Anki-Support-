![CI](https://github.com/juanj/KantanManga/workflows/CI/badge.svg?branch=development)
[![codecov](https://codecov.io/gh/juanj/KantanManga/branch/development/graph/badge.svg)](https://codecov.io/gh/juanj/KantanManga)


![kantan manga logo](/img/repo-header.png)

# KantanManga
KantanManga is an application that helps you read raw manga

[![AppStore](/img/appstore.svg)](https://appstore.com/kantanmanga)

INSTALL //

Download the latest release

Sideload with Altstore

*Sign with third party signing tool if necessary*



BUILDING

Download/Clone the repo

Install dependencies as per documentation

Run in Xcode (If you are on windows, run a virtual machine instance of macOS Sonoma in VMware that you can format into an iso from a working Mac)

Once in Xcode, you may have to set teams, Id, and provisioning profiles to your own

It would also be smart to sync the firebase with your own project (Just set up in firebase, download the file, and replace the existing one)

Ensure that dic.db (in Resources) is the full database file, and not a git link + has write permissions

Ensure dictionary logic is sound in CompoundDictionary and (DB) Dictionary//

Double check for dependencies and binary links. Xcode may be missing the IOS sdk frameworks by default.

Either build onto device or Archive to create ipa for sideloading// (IOS App Signer to avoid paying Apple)

Enjoy!

////////////////////


ANKI CONNECT GUIDE//

Make sure Anki Connect is installed as an add on for Anki desktop

Go to Config from the Add ons window and ensure make sure it matches : 
{
    "apiKey": null,
    "apiLogPath": null,
    "ignoreOriginList": [],
    "webBindAddress": "0.0.0.0",
    "webBindPort": 8765,
    "webCorsOriginList": [
        "http://localhost"
    ]
}


Open app and go to 'sentences' tab

Hit the settings gear in top right

Set the top value to your Computer's local IP address followed by ':8765'

If done correctly, you should now be able to access your Decks and Types to choose how you will save the flashcards

Select the sync button (top left) and it will upload all saved cards to the Deck you chose.

If it says 'Sync failed, card is a duplicate' on any of them, that is an issue with Anki wanting unique identifiers, the easiest way to fix it is by duplicating the card type you are using and then selecting that for the duplicates//

Enjoy! Happy reading/studying!



# Running locally

## Cloning
1. Clone the repository including submodules.
```
git clone --recurse-submodules https://github.com/juanj/KantanManga.git
```
2. Use bundler to install Cocoapods
```
bundle install
```
3. Install dependencies using Cocoapods
```
bundle exec pod install
```
4. Open the workspace
```
open Kantan-Manga.xcworkspace
```
