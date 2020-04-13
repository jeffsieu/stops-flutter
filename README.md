![Stops](https://user-images.githubusercontent.com/8487294/79132837-950b1f80-7ddd-11ea-8f57-6b946067c62d.png)

Stops is an app built with Flutter that displays live bus timings for bus stops in Singapore.
It uses live data exposed by [LTA Datamall](https://www.mytransport.sg/content/mytransport/home/dataMall.html)'s API.

## Features
 - Pin your favorite bus stops
 - Search bus stops by their name or code
 - Rename bus stops as you wish
 - Light/dark mode options
 - Add routes to easily organize bus stops you frequent
 - Get notified when bus is arriving soon


## Screenshots

### Light vs Dark
<img src="https://user-images.githubusercontent.com/8487294/78435346-e3ffd900-76a8-11ea-8e07-4a10348a53c5.png" width=300>
<img src="https://user-images.githubusercontent.com/8487294/78457074-44f3d500-76da-11ea-8ee6-0cdebb52fc2a.png" width=300>

### Homepage
<img src="https://user-images.githubusercontent.com/8487294/78438056-abacca80-76a9-11ea-81ca-e13061e2687a.png" width=300>

### Others
<img src="https://user-images.githubusercontent.com/8487294/78457073-432a1180-76da-11ea-874f-2a0c8912179f.png" width=300>
<img src="https://user-images.githubusercontent.com/8487294/78438029-a9e30700-76a9-11ea-94f4-bfcc55cb8f16.png" width=300>
<img src="https://user-images.githubusercontent.com/8487294/78438042-ab143400-76a9-11ea-8613-261acdb7293f.png" width=300>

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
