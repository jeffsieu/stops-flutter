![Stops](assets/images/banner.png)

Stops is an app built with Flutter that displays live bus timings for bus stops in Singapore.
It uses live data exposed by [LTA Datamall](https://www.mytransport.sg/content/mytransport/home/dataMall.html)'s API.

## Download (Android)

<a href="https://play.google.com/store/apps/details?id=com.jeffsieu.stops">
 <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" width="300">
</a>

Or check out the [releases page](https://github.com/jeffsieu/stops-flutter/releases).

## Features
 - Pin your favorite bus stops
 - Search bus stops by their name or code
 - Rename bus stops as you wish
 - Light/dark mode options
 - Add routes to easily organize bus stops you frequent
 - Track buses with live notifications
 - Get notified when bus is arriving soon


## Screenshots

<p align="middle">
 <img src="https://user-images.githubusercontent.com/8487294/155939870-15718cc7-929a-4ec1-a8f2-d2dbaa2a3d9c.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/155939871-1d852da4-e53a-4cfe-912f-d850c713f890.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/155939862-9ff5f850-d6dd-4498-92a5-861da788a540.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/155939867-bb53a1e5-6d97-47d1-bca9-88620aa51407.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/155939868-82444371-ef33-42b4-b194-86b4871ca918.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/88450919-2ed67400-ce85-11ea-9954-e3f09718995a.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/88451013-03a05480-ce86-11ea-8983-ebff80ba871a.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/88451016-04d18180-ce86-11ea-9786-558d2ad26149.png" width=300>
</p>


## Getting Started
 ```
 git clone https://github.com/jeffsieu/stops-flutter.git
 ```
 
### Setting API keys
Set your [Google Maps API key](https://console.cloud.google.com/google/maps-apis/overview) for Android at `stops-flutter/android/local.properties`.
 ```properties
...
googleMaps.apiKey=apikey
 ```

 
 For bus stop retrieval, set your [LTA API key](https://www.mytransport.sg/content/mytransport/home/dataMall/request-for-api.html) at `stops-flutter/assets/secrets.json`. 
 ```json
 {
     "lta_api_key": "apikey"
 }
 ```
 
## Built with
 - [Flutter](https://flutter.dev/) - The mobile-app framework used
 - [Rubber](https://github.com/mcrovero/rubber) - An awesome bottom-sheet implementation in Flutter

## Credits
This app is an experiment by Jeff Sieu.
