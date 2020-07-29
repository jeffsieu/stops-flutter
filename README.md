![Stops](https://user-images.githubusercontent.com/8487294/88384504-1dd32780-cddf-11ea-8458-0692972d2ec4.png)

Stops is an app built with Flutter that displays live bus timings for bus stops in Singapore.
It uses live data exposed by [LTA Datamall](https://www.mytransport.sg/content/mytransport/home/dataMall.html)'s API.

## Download (Android)
[![Get Stops on Google Play](https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png)](https://play.google.com/store/apps/details?id=com.jeffsieu.stops)
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
 <img src="https://user-images.githubusercontent.com/8487294/88450897-0b132e00-ce85-11ea-8a07-5c200e6eabbb.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/88450899-0c445b00-ce85-11ea-8540-65293e3453a5.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/88450914-2aaa5680-ce85-11ea-9406-d40dda15dde0.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/88450917-2c741a00-ce85-11ea-8599-0d4b079386cd.png" width=300>
 <img src="https://user-images.githubusercontent.com/8487294/88450982-da7fc400-ce85-11ea-84b7-151add2f3443.png" width=300>
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
