import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'package:lolisnatcher/src/data/booru.dart';
import 'package:lolisnatcher/src/data/constants.dart';
import 'package:lolisnatcher/src/data/settings/app_mode.dart';
import 'package:lolisnatcher/src/data/settings/hand_side.dart';
import 'package:lolisnatcher/src/data/theme_item.dart';
import 'package:lolisnatcher/src/data/update_info.dart';
import 'package:lolisnatcher/src/handlers/database_handler.dart';
import 'package:lolisnatcher/src/handlers/navigation_handler.dart';
import 'package:lolisnatcher/src/handlers/search_handler.dart';
import 'package:lolisnatcher/src/handlers/service_handler.dart';
import 'package:lolisnatcher/src/services/get_perms.dart';
import 'package:lolisnatcher/src/utils/http_overrides.dart';
import 'package:lolisnatcher/src/utils/logger.dart';
import 'package:lolisnatcher/src/widgets/common/flash_elements.dart';
import 'package:lolisnatcher/src/widgets/common/settings_widgets.dart';

/// This class is used loading from and writing settings to files
class SettingsHandler extends GetxController {
  static SettingsHandler get instance => Get.find<SettingsHandler>();

  DBHandler dbHandler = DBHandler();
  DBHandler favDbHandler = DBHandler();

  // service vars
  RxBool isInit = false.obs;
  String cachePath = "";
  String path = "";
  String boorusPath = "";

  // TODO don't forget to update these on every new release
  // version vars
  String appName = "LoliSnatcher";
  String packageName = "com.noaisu.loliSnatcher";
  String verStr = "2.2.5";
  int buildNumber = 172;
  Rx<UpdateInfo?> updateInfo = Rxn(null);

  ////////////////////////////////////////////////////

  // runtime settings vars
  bool hasHydrus = false;
  RxBool mergeEnabled = RxBool(false);
  List<LogTypes> ignoreLogTypes = List.from(LogTypes.values);
  RxString discordURL = RxString(Constants.discordURL);

  // debug toggles
  RxBool isDebug = (kDebugMode || false).obs;
  RxBool showFPS = false.obs;
  RxBool showPerf = false.obs;
  RxBool showImageStats = false.obs;
  bool showURLOnThumb = false;
  bool disableImageScaling = false;
  // disable isolates on debug builds, because they cause lags in emulator
  bool disableImageIsolates = kDebugMode || false;
  bool desktopListsDrag = false;

  ////////////////////////////////////////////////////

  // saveable settings vars
  String defTags = "rating:safe";
  String previewMode = "Sample";
  String videoCacheMode = "Stream";
  String prefBooru = "";
  String previewDisplay = "Square";
  String galleryMode = "Full Res";
  String shareAction = "Ask";
  Rx<AppMode> appMode = AppMode.defaultValue.obs;
  Rx<HandSide> handSide = HandSide.defaultValue.obs;
  String galleryBarPosition = 'Top';
  String galleryScrollDirection = 'Horizontal';
  String extPathOverride = "";
  String drawerMascotPathOverride = "";
  String zoomButtonPosition = "Right";
  String changePageButtonsPosition = (Platform.isWindows || Platform.isLinux) ? "Right" : "Disabled";
  String lastSyncIp = '';
  String lastSyncPort = '';

  List<String> hatedTags = [];
  List<String> lovedTags = [];

  int limit = 20;
  int portraitColumns = 2;
  int landscapeColumns = 4;
  int preloadCount = 1;
  int snatchCooldown = 250;
  int volumeButtonsScrollSpeed = 200;
  int galleryAutoScrollTime = 4000;
  int cacheSize = 3;

  int currentColumnCount(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait
        ? portraitColumns
        : landscapeColumns;
  }

  Duration cacheDuration = Duration.zero;

  List<List<String>> buttonList = [
    ["autoscroll", "AutoScroll"],
    ["snatch", "Save"],
    ["favourite", "Favourite"],
    ["info", "Display Info"],
    ["share", "Share"],
    ["open", "Open in Browser"],
    ["reloadnoscale", "Reload w/out scaling"]
  ];
  List<List<String>> buttonOrder = [
    ["autoscroll", "AutoScroll"],
    ["snatch", "Save"],
    ["favourite", "Favourite"],
    ["info", "Display Info"],
    ["share", "Share"],
    ["open", "Open in Browser"],
    ["reloadnoscale", "Reload w/out scaling"]
  ];

  bool jsonWrite = false;
  bool autoPlayEnabled = true;
  bool loadingGif = false;
  bool thumbnailCache = true;
  bool mediaCache = false;
  bool autoHideImageBar = false;
  bool dbEnabled = true;
  bool searchHistoryEnabled = true;
  bool filterHated = false;
  bool useVolumeButtonsForScroll = false;
  bool shitDevice = false;
  bool disableVideo = false;
  bool enableDrawerMascot = false;
  bool allowSelfSignedCerts = false;
  bool wakeLockEnabled = true;
  bool tagTypeFetchEnabled = true;
  RxList<Booru> booruList = RxList<Booru>([]);
  ////////////////////////////////////////////////////

  // themes wip
  Rx<ThemeItem> theme = ThemeItem(
    name: "Pink",
    primary: Colors.pink[200],
    accent: Colors.pink[600]
  ).obs..listen((ThemeItem theme) {
    print('newTheme ${theme.name} ${theme.primary}');
  });

  Rx<Color?> customPrimaryColor = Colors.pink[200].obs;
  Rx<Color?> customAccentColor = Colors.pink[600].obs;

  Rx<ThemeMode> themeMode = ThemeMode.dark.obs; // system, light, dark
  RxBool isAmoled = false.obs;
  ////////////////////////////////////////////////////

  // list of setting names which shouldnt be synced with other devices
  List<String> deviceSpecificSettings = [
    'shitDevice', 'disableVideo',
    'thumbnailCache', 'mediaCache',
    'dbEnabled', 'searchHistoryEnabled',
    'useVolumeButtonsForScroll', 'volumeButtonsScrollSpeed',
    'prefBooru', 'appMode', 'handSide', 'extPathOverride',
    'lastSyncIp', 'lastSyncPort',
    'theme', 'themeMode', 'isAmoled',
    'customPrimaryColor', 'customAccentColor',
    'version', 'SDK', 'disableImageScaling',
    'cacheDuration', 'cacheSize', 'enableDrawerMascot',
    'drawerMascotPathOverride', 'allowSelfSignedCerts',
    'showFPS', 'showPerf', 'showImageStats',
    'isDebug', 'showURLOnThumb', 'disableImageIsolates',
    'mergeEnabled', 'desktopListsDrag'
  ];
  // default values and possible options map for validation
  // TODO build settings widgets from this map, need to add Label/Description/other options required for the input element
  // TODO move it in another file?
  Map<String, Map<String, dynamic>> map = {
    // stringFromList
    "previewMode": {
      "type": "stringFromList",
      "default": "Sample",
      "options": <String>["Sample", "Thumbnail"],
    },
    "previewDisplay": {
      "type": "stringFromList",
      "default": "Square",
      "options": <String>["Square", "Rectangle", "Staggered"],
    },
    "shareAction": {
      "type": "stringFromList",
      "default": "Ask",
      "options": <String>["Ask", "Post URL", "File URL", "File", "Hydrus"],
    },
    "videoCacheMode": {
      "type": "stringFromList",
      "default": "Stream",
      "options": <String>["Stream", "Cache", "Stream+Cache"],
    },
    "galleryMode": {
      "type": "stringFromList",
      "default": "Full Res",
      "options": <String>["Sample", "Full Res"],
    },
    "galleryScrollDirection": {
      "type": "stringFromList",
      "default": "Horizontal",
      "options": <String>["Horizontal", "Vertical"],
    },
    "galleryBarPosition": {
      "type": "stringFromList",
      "default": "Top",
      "options": <String>["Top", "Bottom"],
    },
    "zoomButtonPosition": {
      "type": "stringFromList",
      "default": "Right",
      "options": <String>["Disabled", "Left", "Right"],
    },
    "changePageButtonsPosition": {
      "type": "stringFromList",
      "default": (Platform.isWindows || Platform.isLinux) ? "Right" : "Disabled",
      "options": <String>["Disabled", "Left", "Right"],
    },

    // string
    "defTags": {
      "type": "string",
      "default": "rating:safe",
    },
    "prefBooru": {
      "type": "string",
      "default": "",
    },
    "extPathOverride": {
      "type": "string",
      "default": "",
    },
    "drawerMascotPathOverride": {
      "type": "string",
      "default": "",
    },
    "lastSyncIp": {
      "type": "string",
      "default": "",
    },
    "lastSyncPort": {
      "type": "string",
      "default": "",
    },

    // stringList
    "hatedTags": {
      "type": "stringList",
      "default": <String>[],
    },
    "lovedTags": {
      "type": "stringList",
      "default": <String>[],
    },

    // int
    "limit": {
      "type": "int",
      "default": 20,
      "upperLimit": 100,
      "lowerLimit": 10,
    },
    "portraitColumns": {
      "type": "int",
      "default": 2,
      "upperLimit": 100,
      "lowerLimit": 1,
    },
    "landscapeColumns": {
      "type": "int",
      "default": 4,
      "upperLimit": 100,
      "lowerLimit": 1,
    },
    "preloadCount": {
      "type": "int",
      "default": 1,
      "upperLimit": 3,
      "lowerLimit": 0,
    },
    "snatchCooldown": {
      "type": "int",
      "default": 250,
      "upperLimit": 10000,
      "lowerLimit": 0,
    },
    "volumeButtonsScrollSpeed": {
      "type": "int",
      "default": 200,
      "upperLimit": 1000000,
      "lowerLimit": 0,
    },
    "galleryAutoScrollTime": {
      "type": "int",
      "default": 4000,
      "upperLimit": 100000,
      "lowerLimit": 100,
    },
    "cacheSize": {
      "type": "int",
      "default": 3,
      "upperLimit": 10,
      "lowerLimit": 0,
    },

    // double

    // bool
    "jsonWrite": {
      "type": "bool",
      "default": false,
    },
    "autoPlayEnabled": {
      "type": "bool",
      "default": true,
    },
    "loadingGif": {
      "type": "bool",
      "default": false,
    },
    "thumbnailCache": {
      "type": "bool",
      "default": true,
    },
    "mediaCache": {
      "type": "bool",
      "default": false,
    },
    "autoHideImageBar": {
      "type": "bool",
      "default": false,
    },
    "dbEnabled": {
      "type": "bool",
      "default": true,
    },
    "searchHistoryEnabled": {
      "type": "bool",
      "default": true,
    },
    "filterHated": {
      "type": "bool",
      "default": false,
    },
    "useVolumeButtonsForScroll": {
      "type": "bool",
      "default": false,
    },
    "shitDevice": {
      "type": "bool",
      "default": false,
    },
    "disableVideo": {
      "type": "bool",
      "default": false,
    },
    "enableDrawerMascot": {
      "type": "bool",
      "default": false,
    },
    "allowSelfSignedCerts":{
      "type" : "bool",
      "default": false,
    },
    "disableImageScaling": {
      "type": "bool",
      "default": false,
    },
    "disableImageIsolates": {
      "type": "bool",
      "default": false,
    },
    "desktopListsDrag": {
      "type": "bool",
      "default": false,
    },
    "wakeLockEnabled": {
      "type": "bool",
      "default": true,
    },
    "tagTypeFetchEnabled": {
      "type": "bool",
      "default": true,
    },

    // other
    "buttonOrder": {
      "type": "other",
      "default": <List<String>>[
        ["autoscroll", "AutoScroll"],
        ["snatch", "Save"],
        ["favourite", "Favourite"],
        ["info", "Display Info"],
        ["share", "Share"],
        ["open", "Open in Browser"],
        ["reloadnoscale", "Reload w/out scaling"]
      ],
    },
    "cacheDuration": {
      "type": "duration",
      "default": Duration.zero,
      "options": <Map<String, dynamic>>[
        {'label': 'Never', 'value': Duration.zero},
        {'label': '30 minutes', 'value': const Duration(minutes: 30)},
        {'label': '1 hour', 'value': const Duration(hours: 1)},
        {'label': '6 hours', 'value': const Duration(hours: 6)},
        {'label': '12 hours', 'value': const Duration(hours: 12)},
        {'label': '1 day', 'value': const Duration(days: 1)},
        {'label': '2 days', 'value': const Duration(days: 2)},
        {'label': '1 week', 'value': const Duration(days: 7)},
        {'label': '1 month', 'value': const Duration(days: 30)},
      ],
    },

    // theme
    "appMode": {
      "type": "appMode",
      "default": AppMode.defaultValue,
      "options": AppMode.values,
    },
    "handSide": {
      "type": "handSide",
      "default": HandSide.defaultValue,
      "options": HandSide.values,
    },
    "theme": {
      "type": "theme",
      "default": ThemeItem(name: "Pink", primary: Colors.pink[200], accent: Colors.pink[600]),
      "options": <ThemeItem>[
        ThemeItem(name: "Pink", primary: Colors.pink[200], accent: Colors.pink[600]),
        ThemeItem(name: "Purple", primary: Colors.deepPurple[600], accent: Colors.deepPurple[800]),
        ThemeItem(name: "Blue", primary: Colors.lightBlue, accent: Colors.lightBlue[600]),
        ThemeItem(name: "Teal", primary: Colors.teal, accent: Colors.teal[600]),
        ThemeItem(name: "Red", primary: Colors.red[700], accent: Colors.red[800]),
        ThemeItem(name: "Green", primary: Colors.green, accent: Colors.green[700]),
        ThemeItem(name: "Custom", primary: null, accent: null),
      ]
    },
    "themeMode": {
      "type": "themeMode",
      "default": ThemeMode.dark,
      "options": ThemeMode.values,
    },
    "isAmoled": {
      "type": "rxbool",
      "default": false.obs,
    },
    "customPrimaryColor": {
      "type": "rxcolor",
      "default": Colors.pink[200],
    },
    "customAccentColor": {
      "type": "rxcolor",
      "default": Colors.pink[600],
    },
  };

  dynamic validateValue(String name, dynamic value, {bool toJSON = false}) {
    Map<String, dynamic>? settingParams = map[name];

    if(toJSON) {
      value = getByString(name);
    }

    if(settingParams == null) {
      if(toJSON) {
        return value.toString();
      } else {
        return value;
      }
    }

    try {
      switch (settingParams["type"]) {
        case 'stringFromList':
          String validValue = List<String>.from(settingParams["options"]!).firstWhere((el) => el == value, orElse: () => '');
          if(validValue != '') {
            return validValue;
          } else {
            return settingParams["default"];
          }

        case 'string':
          if(value is! String) {
            throw 'value "$value" for $name is not a String';
          } else {
            return value;
          }

        case 'int':
          int? parse = (value is String) ? int.tryParse(value) : (value is int ? value : null);
          if(parse == null) {
            throw 'value "$value" of type ${value.runtimeType} for $name is not an int';
          } else if (parse < settingParams["lowerLimit"] || parse > settingParams["upperLimit"]) {
            if(toJSON) {
              // force default value when not passing validation when saving
              setByString(name, settingParams["default"]);
            }
            return settingParams["default"];
          } else {
            return parse;
          }

        case 'bool':
          if(value is! bool) {
            if(value is String && (value == 'true' || value == 'false')) {
              return value == 'true' ? true : false;
            } else {
              throw 'value "$value" for $name is not a bool';
            }
          } else {
            return value;
          }

        case 'rxbool':
          if (toJSON) {
            // rxbool to bool
            return value.value;
          } else {
            // bool to rxbool
            if(value is RxBool) {
              return value;
            } else if (value is bool) {
              return value.obs;
            } else {
              throw 'value "$value" for $name is not a rxbool';
            }
          }

        case 'appMode':
          if(toJSON) {
            // rxobject to string
            return value.value.toString();
          } else {
            if(value is String) {
              // string to rxobject
              return AppMode.fromString(value);
            } else {
              return settingParams["default"];
            }
          }

        case 'handSide':
          if(toJSON) {
            // rxobject to string
            return value.value.toString();
          } else {
            if(value is String) {
              // string to rxobject
              return HandSide.fromString(value);
            } else {
              return settingParams["default"];
            }
          }

        case 'theme':
          if(toJSON) {
            // rxobject to string
            return value.value.name;
          } else {
            if(value is String) {
              // string to rxobject
              final ThemeItem findTheme = List<ThemeItem>.from(settingParams["options"]!).firstWhere((el) => el.name == value, orElse: () => settingParams["default"]);
              return findTheme;
            } else {
              return settingParams["default"];
            }
          }

        case 'themeMode':
          if (toJSON) {
            // rxobject to string
            return value.value.toString().split('.')[1]; // ThemeMode.dark => dark
          } else {
            if (value is String) {
              // string to rxobject
              final List<ThemeMode> findMode = ThemeMode.values.where((element) => element.toString() == 'ThemeMode.$value').toList();
              if (findMode.isNotEmpty) {
                // if theme mode is present
                return findMode[0];
              } else {
                // if not theme mode with given name
                return settingParams["default"];
              }
            } else {
              return settingParams["default"];
            }
          }

        case 'rxcolor':
          if (toJSON) {
            // rxobject to int
            return value.value.value; // Color => int
          } else {
            // int to rxobject
            if (value is int) {
              return Color(value);
            } else {
              return settingParams["default"];
            }
          }

        case 'duration':
          if (toJSON) {
            return value.inSeconds; // Duration => int
          } else {
            if (value is Duration) {
              return value;
            } else if(value is int) {
              // int to Duration
              return Duration(seconds: value);
            } else {
              return settingParams["default"];
            }
          }

        // case 'stringList':
        default:
          return value;
      }
    } catch(err) {
      // return default value on exceptions
      Logger.Inst().log('value validation error: $err', "SettingsHandler", "validateValue", LogTypes.settingsError);
      return settingParams["default"];
    }
  }

  Future<bool> loadSettings() async {
    if (path == "") await setConfigDir();
    if (cachePath == "") cachePath = await ServiceHandler.getCacheDir();

    if(await checkForSettings()) {
      await loadSettingsJson();
    } else {
      await saveSettings(restate: true);
    }

    if (dbEnabled) {
      await dbHandler.dbConnect(path);
      await favDbHandler.dbConnectReadOnly(path);
    } else {
      dbHandler = DBHandler();
      favDbHandler = DBHandler();
    }
    return true;
  }

  Future<bool> checkForSettings() async {
    File settingsFile = File("${path}settings.json");
    return await settingsFile.exists();
  }
  Future<void> loadSettingsJson() async {
    File settingsFile = File("${path}settings.json");
    String settings = await settingsFile.readAsString();
    // print('loadJSON $settings');
    loadFromJSON(settings, true);
    return;
  }


  dynamic getByString(String varName) {
    switch (varName) {
      case 'defTags':
        return defTags;
      case 'previewMode':
        return previewMode;
      case 'videoCacheMode':
        return videoCacheMode;
      case 'previewDisplay':
        return previewDisplay;
      case 'galleryMode':
        return galleryMode;
      case 'shareAction':
        return shareAction;
      case 'limit':
        return limit;
      case 'portraitColumns':
        return portraitColumns;
      case 'landscapeColumns':
        return landscapeColumns;
      case 'preloadCount':
        return preloadCount;
      case 'snatchCooldown':
        return snatchCooldown;
      case 'galleryBarPosition':
        return galleryBarPosition;
      case 'galleryScrollDirection':
        return galleryScrollDirection;
      case 'buttonOrder':
        return buttonOrder;
      case 'hatedTags':
        return hatedTags;
      case 'lovedTags':
        return lovedTags;
      case 'autoPlayEnabled':
        return autoPlayEnabled;
      case 'loadingGif':
        return loadingGif;
      case 'thumbnailCache':
        return thumbnailCache;
      case 'mediaCache':
        return mediaCache;
      case 'autoHideImageBar':
        return autoHideImageBar;
      case 'dbEnabled':
        return dbEnabled;
      case 'searchHistoryEnabled':
        return searchHistoryEnabled;
      case 'filterHated':
        return filterHated;
      case 'useVolumeButtonsForScroll':
        return useVolumeButtonsForScroll;
      case 'volumeButtonsScrollSpeed':
        return volumeButtonsScrollSpeed;
      case 'disableVideo':
        return disableVideo;
      case 'shitDevice':
        return shitDevice;
      case 'galleryAutoScrollTime':
        return galleryAutoScrollTime;
      case 'jsonWrite':
        return jsonWrite;
      case 'zoomButtonPosition':
        return zoomButtonPosition;
      case 'changePageButtonsPosition':
        return changePageButtonsPosition;
      case 'disableImageScaling':
        return disableImageScaling;
      case 'disableImageIsolates':
        return disableImageIsolates;
      case 'desktopListsDrag':
        return desktopListsDrag;
      case 'cacheDuration':
        return cacheDuration;
      case 'cacheSize':
        return cacheSize;
      case 'allowSelfSignedCerts':
        return allowSelfSignedCerts;

      case 'prefBooru':
        return prefBooru;
      case 'extPathOverride':
        return extPathOverride;
      case 'drawerMascotPathOverride':
        return drawerMascotPathOverride;
      case 'enableDrawerMascot':
        return enableDrawerMascot;
      case 'lastSyncIp':
        return lastSyncIp;
      case 'lastSyncPort':
        return lastSyncPort;
      case 'wakeLockEnabled':
        return wakeLockEnabled;
      case 'tagTypeFetchEnabled':
        return tagTypeFetchEnabled;
      // theme stuff
      case 'appMode':
        return appMode;
      case 'handSide':
        return handSide;
      case 'theme':
        return theme;
      case 'themeMode':
        return themeMode;
      case 'isAmoled':
        return isAmoled;
      case 'customPrimaryColor':
        return customPrimaryColor;
      case 'customAccentColor':
        return customAccentColor;
      default:
        return null;
    }
  }

  dynamic setByString(String varName, dynamic value) {
    dynamic validatedValue = validateValue(varName, value);
    //Could this just be replaced with getByString(varName) = validatedValue?
    switch (varName) {
      case 'defTags':
        defTags = validatedValue;
        break;
      case 'previewMode':
        previewMode = validatedValue;
        break;
      case 'videoCacheMode':
        videoCacheMode = validatedValue;
        break;
      case 'previewDisplay':
        previewDisplay = validatedValue;
        break;
      case 'galleryMode':
        galleryMode = validatedValue;
        break;
      case 'shareAction':
        shareAction = validatedValue;
        break;
      case 'limit':
        limit = validatedValue;
        break;
      case 'portraitColumns':
        portraitColumns = validatedValue;
        break;
      case 'landscapeColumns':
        landscapeColumns = validatedValue;
        break;
      case 'preloadCount':
        preloadCount = validatedValue;
        break;
      case 'snatchCooldown':
        snatchCooldown = validatedValue;
        break;
      case 'galleryBarPosition':
        galleryBarPosition = validatedValue;
        break;
      case 'galleryScrollDirection':
        galleryScrollDirection = validatedValue;
        break;

      // TODO special cases
      // case 'buttonOrder':
      //   buttonOrder = validatedValue;
      //   break;
      // case 'hatedTags':
      //   hatedTags = validatedValue;
      //   break;
      // case 'lovedTags':
      //   lovedTags = validatedValue;
      //   break;
      case 'autoPlayEnabled':
        autoPlayEnabled = validatedValue;
        break;
      case 'loadingGif':
        loadingGif = validatedValue;
        break;
      case 'thumbnailCache':
        thumbnailCache = validatedValue;
        break;
      case 'mediaCache':
        mediaCache = validatedValue;
        break;
      case 'autoHideImageBar':
        autoHideImageBar = validatedValue;
        break;
      case 'dbEnabled':
        dbEnabled = validatedValue;
        break;
      case 'searchHistoryEnabled':
        searchHistoryEnabled = validatedValue;
        break;
      case 'filterHated':
        filterHated = validatedValue;
        break;
      case 'useVolumeButtonsForScroll':
        useVolumeButtonsForScroll = validatedValue;
        break;
      case 'volumeButtonsScrollSpeed':
        volumeButtonsScrollSpeed = validatedValue;
        break;
      case 'disableVideo':
        disableVideo = validatedValue;
        break;
      case 'shitDevice':
        shitDevice = validatedValue;
        break;
      case 'galleryAutoScrollTime':
        galleryAutoScrollTime = validatedValue;
        break;
      case 'jsonWrite':
        jsonWrite = validatedValue;
        break;
      case 'zoomButtonPosition':
        zoomButtonPosition = validatedValue;
        break;
      case 'changePageButtonsPosition':
        changePageButtonsPosition = validatedValue;
        break;
      case 'disableImageScaling':
        disableImageScaling = validatedValue;
        break;
      case 'disableImageIsolates':
        disableImageIsolates = validatedValue;
        break;
      case 'desktopListsDrag':
        desktopListsDrag = validatedValue;
        break;
      case 'cacheDuration':
        cacheDuration = validatedValue;
        break;
      case 'cacheSize':
        cacheSize = validatedValue;
        break;
      case 'prefBooru':
        prefBooru = validatedValue;
        break;
      case 'extPathOverride':
        extPathOverride = validatedValue;
        break;
      case 'lastSyncIp':
        lastSyncIp = validatedValue;
        break;
      case 'lastSyncPort':
        lastSyncPort = validatedValue;
        break;
      case 'allowSelfSignedCerts':
        allowSelfSignedCerts = validatedValue;
        break;
      // theme stuff
      case 'appMode':
        appMode.value = validatedValue;
        break;
      case 'handSide':
        handSide.value = validatedValue;
        break;
      case 'theme':
        theme.value = validatedValue;
        break;
      case 'themeMode':
        themeMode.value = validatedValue;
        break;
      case 'isAmoled':
        isAmoled = validatedValue;
        break;
      case 'customPrimaryColor':
        customPrimaryColor.value = validatedValue;
        break;
      case 'customAccentColor':
        customAccentColor.value = validatedValue;
        break;
      case 'drawerMascotPathOverride':
        drawerMascotPathOverride = validatedValue;
        break;
      case 'enableDrawerMascot':
        enableDrawerMascot = validatedValue;
        break;
      case 'wakeLockEnabled':
        wakeLockEnabled = validatedValue;
        break;
      case 'tagTypeFetchEnabled':
        tagTypeFetchEnabled = validatedValue;
        break;
      default:
        break;
    }
  }


  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      "defTags": validateValue("defTags", null, toJSON: true),
      "previewMode": validateValue("previewMode", null, toJSON: true),
      "videoCacheMode": validateValue("videoCacheMode", null, toJSON: true),
      "previewDisplay": validateValue("previewDisplay", null, toJSON: true),
      "galleryMode": validateValue("galleryMode", null, toJSON: true),
      "shareAction" : validateValue("shareAction", null, toJSON: true),
      "limit" : validateValue("limit", null, toJSON: true),
      "portraitColumns" : validateValue("portraitColumns", null, toJSON: true),
      "landscapeColumns" : validateValue("landscapeColumns", null, toJSON: true),
      "preloadCount" : validateValue("preloadCount", null, toJSON: true),
      "snatchCooldown" : validateValue("snatchCooldown", null, toJSON: true),
      "galleryBarPosition" : validateValue("galleryBarPosition", null, toJSON: true),
      "galleryScrollDirection" : validateValue("galleryScrollDirection", null, toJSON: true),
      "jsonWrite" : validateValue("jsonWrite", null, toJSON: true),
      "autoPlayEnabled" : validateValue("autoPlayEnabled", null, toJSON: true),
      "loadingGif" : validateValue("loadingGif", null, toJSON: true),
      "thumbnailCache" : validateValue("thumbnailCache", null, toJSON: true),
      "mediaCache": validateValue("mediaCache", null, toJSON: true),
      "autoHideImageBar" : validateValue("autoHideImageBar", null, toJSON: true),
      "dbEnabled" : validateValue("dbEnabled", null, toJSON: true),
      "searchHistoryEnabled" : validateValue("searchHistoryEnabled", null, toJSON: true),
      "filterHated" : validateValue("filterHated", null, toJSON: true),
      "useVolumeButtonsForScroll" : validateValue("useVolumeButtonsForScroll", null, toJSON: true),
      "volumeButtonsScrollSpeed" : validateValue("volumeButtonsScrollSpeed", null, toJSON: true),
      "disableVideo" : validateValue("disableVideo", null, toJSON: true),
      "shitDevice" : validateValue("shitDevice", null, toJSON: true),
      "galleryAutoScrollTime" : validateValue("galleryAutoScrollTime", null, toJSON: true),
      "zoomButtonPosition": validateValue("zoomButtonPosition", null, toJSON: true),
      "changePageButtonsPosition": validateValue("changePageButtonsPosition", null, toJSON: true),
      "disableImageScaling" : validateValue("disableImageScaling", null, toJSON: true),
      "disableImageIsolates" : validateValue("disableImageIsolates", null, toJSON: true),
      "desktopListsDrag" : validateValue("desktopListsDrag", null, toJSON: true),
      "cacheDuration" : validateValue("cacheDuration", null, toJSON: true),
      "cacheSize" : validateValue("cacheSize", null, toJSON: true),
      "allowSelfSignedCerts": validateValue("allowSelfSignedCerts", null, toJSON: true),

      //TODO
      "buttonOrder": buttonOrder.map((e) => e[0]).toList(),
      "hatedTags": cleanTagsList(hatedTags),
      "lovedTags": cleanTagsList(lovedTags),

      "prefBooru": validateValue("prefBooru", null, toJSON: true),
      "appMode": validateValue("appMode", null, toJSON: true),
      "handSide": validateValue("handSide", null, toJSON: true),
      "extPathOverride": validateValue("extPathOverride", null, toJSON: true),
      "lastSyncIp": validateValue("lastSyncIp", null, toJSON: true),
      "lastSyncPort": validateValue("lastSyncPort", null, toJSON: true),

      "theme": validateValue("theme", null, toJSON: true),
      "themeMode": validateValue("themeMode", null, toJSON: true),
      "isAmoled": validateValue("isAmoled", null, toJSON: true),
      "enableDrawerMascot" : validateValue("enableDrawerMascot", null, toJSON: true),
      "drawerMascotPathOverride": validateValue("drawerMascotPathOverride", null, toJSON: true),
      "customPrimaryColor": validateValue("customPrimaryColor", null, toJSON: true),
      "customAccentColor": validateValue("customAccentColor", null, toJSON: true),
      "wakeLockEnabled" : validateValue("wakeLockEnabled", null, toJSON: true),
      "tagTypeFetchEnabled" : validateValue("tagTypeFetchEnabled", null, toJSON: true),
      "version": verStr,
      // TODO split into two variables - system name and system version/sdk number
      // "SDK": SDKVer,
    };

    // print('JSON $json');
    return json;
  }

  Future<bool> loadFromJSON(String jsonString, bool setMissingKeys) async {
    Map<String, dynamic> json = {};
    try {
      json = jsonDecode(jsonString);
    } catch (e) {
      Logger.Inst().log('Failed to parse settings config $e', 'SettingsHandler', 'loadFromJSON', LogTypes.exception);
    }

    // TODO add error handling for invalid values
    // (don't allow user to exit the page until the value is correct? or just set to default (current behaviour)? mix of both?)

    dynamic tempBtnOrder = json["buttonOrder"];
    if(tempBtnOrder is List) {
      // print('btnorder is a list');
    } else if(tempBtnOrder is String) {
      // print('btnorder is a string');
      tempBtnOrder = tempBtnOrder.split(',');
    } else {
      // print('btnorder is a ${tempBtnOrder.runtimeType} type');
      tempBtnOrder = [];
    }
    List<List<String>> btnOrder = List<String>.from(tempBtnOrder).map((bstr) {
      List<String> button = buttonList.singleWhere((el) => el[0] == bstr, orElse: () => ['null', 'null']);
      return button;
    }).where((el) => el[0] != 'null').toList();
    btnOrder.addAll(buttonList.where((el) => !btnOrder.contains(el))); // add all buttons that are not present in the parsed list (future proofing, in case we add more buttons later)
    buttonOrder = btnOrder;

    dynamic tempHatedTags = json["hatedTags"];
    if(tempHatedTags is List) {
      // print('hatedTags is a list');
    } else if(tempHatedTags is String) {
      // print('hatedTags is a string');
      tempHatedTags = tempHatedTags.split(',');
    } else {
      // print('hatedTags is a ${tempHatedTags.runtimeType} type');
      tempHatedTags = [];
    }
    List<String> hateTags = List<String>.from(tempHatedTags);
    for (int i = 0; i < hateTags.length; i++){
      if (!hatedTags.contains(hateTags.elementAt(i))) {
        hatedTags.add(hateTags.elementAt(i));
      }
    }

    dynamic tempLovedTags = json["lovedTags"];
    if(tempLovedTags is List) {
      // print('lovedTags is a list');
    } else if(tempLovedTags is String) {
      // print('lovedTags is a string');
      tempLovedTags = tempLovedTags.split(',');
    } else {
      // print('lovedTags is a ${tempLovedTags.runtimeType} type');
      tempLovedTags = [];
    }
    List<String> loveTags = List<String>.from(tempLovedTags);
    for (int i = 0; i < loveTags.length; i++){
      if (!lovedTags.contains(loveTags.elementAt(i))){
        lovedTags.add(loveTags.elementAt(i));
      }
    }

    List<String> leftoverKeys = json.keys.where((element) => !['buttonOrder', 'hatedTags', 'lovedTags'].contains(element)).toList();
    for(String key in leftoverKeys) {
      // print('key $key val ${json[key]} type ${json[key].runtimeType}');
      setByString(key, json[key]);
    }

    if(setMissingKeys) {
      // find all keys that are missing in the file and set them to default values
      map.forEach((key, value) {
        if (!json.keys.contains(key)) {
          if (map[key] != null) {
            setByString(key, map[key]!['default']);
          }
        }
      });
    }

    return true;
  }

  Future<bool> saveSettings({required bool restate}) async {
    await getPerms();
    if (path == "") await setConfigDir();
    await Directory(path).create(recursive:true);
    File settingsFile = File("${path}settings.json");
    var writer = settingsFile.openWrite();
    writer.write(jsonEncode(toJson()));
    writer.close();

    if(restate) {
      SearchHandler.instance.rootRestate(); // force global state update to redraw stuff
    }
    return true;
  }

  Future<bool> loadBoorus() async {
    List<Booru> tempList = [];
    try {
      if (path == "") await setConfigDir();

      Directory directory = Directory(boorusPath);
      List<FileSystemEntity> files = [];
      if(await directory.exists()) {
        files = await directory.list().toList();
      }

      if (files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          if (files[i].path.contains(".json")) { // && files[i].path != 'settings.json'
            // print(files[i].toString());
            File booruFile = files[i] as File;
            Booru booruFromFile = Booru.fromJSON(await booruFile.readAsString());
            tempList.add(booruFromFile);

            if (booruFromFile.type == "Hydrus") {
              hasHydrus = true;
            }
          }
        }
      }

      if (dbEnabled && tempList.isNotEmpty){
        tempList.add(Booru("Favourites", "Favourites", "", "", ""));
      }
    } catch (e){
      print('Booru loading error: $e');
    }

    booruList.value = tempList.where((element) => !booruList.contains(element)).toList(); // filter due to possibility of duplicates

    if (tempList.isNotEmpty){
      sortBooruList();
    } else {
      print(prefBooru);
      print(tempList.isNotEmpty);
    }
    return true;
  }



  void sortBooruList() async {
    List<Booru> sorted = [...booruList]; // spread the array just in case, to guarantee that we don't affect the original value
    sorted.sort((a, b) {
      // sort alphabetically
      return a.name!.toLowerCase().compareTo(b.name!.toLowerCase());
    });

    int prefIndex = 0;
    for (int i = 0; i < sorted.length; i++){
      if (sorted[i].name == prefBooru && prefBooru.isNotEmpty){
        prefIndex = i;
        // print("prefIndex is" + prefIndex.toString());
      }
    }
    if (prefIndex != 0){
      // move default booru to top
      // print("Booru pref found in booruList");
      Booru tmp = sorted.elementAt(prefIndex);
      sorted.remove(tmp);
      sorted.insert(0, tmp);
      // print("booruList is");
      // print(sorted);
    }

    int favsIndex = sorted.indexWhere((el) => el.type == 'Favourites');
    if(favsIndex != -1) {
      // move favourites to the end
      Booru tmp = sorted.elementAt(favsIndex);
      sorted.remove(tmp);
      sorted.add(tmp);
    }
    booruList.value = sorted;
  }

  Future saveBooru(Booru booru, {bool onlySave = false}) async {
    if (path == "") await setConfigDir();

    await Directory(boorusPath).create(recursive:true);
    File booruFile = File("$boorusPath${booru.name}.json");
    var writer = booruFile.openWrite();
    writer.write(jsonEncode(booru.toJson()));
    writer.close();

    if(!onlySave) {
      // used only to avoid duplication after migration to json format
      // TODO remove condition when migration logic is removed
      booruList.add(booru);
      sortBooruList();
    }
    return true;
  }

  Future<bool> deleteBooru(Booru booru) async {
    File booruFile = File("$boorusPath${booru.name}.json");
    await booruFile.delete();
    if (prefBooru == booru.name){
      prefBooru = "";
      saveSettings(restate: true);
    }
    booruList.remove(booru);
    sortBooruList();
    return true;
  }

  List<List<String>> parseTagsList(List<String> itemTags, {bool isCapped = true}) {
    List<String> cleanItemTags = cleanTagsList(itemTags);
    List<String> hatedInItem = hatedTags.where((tag) => cleanItemTags.contains(tag)).toList();
    List<String> lovedInItem = lovedTags.where((tag) => cleanItemTags.contains(tag)).toList();
    List<String> soundInItem = ['sound', 'sound_edit', 'has_audio', 'voice_acted'].where((tag) => cleanItemTags.contains(tag)).toList();
    // TODO add more sound tags?

    if(isCapped) {
      if(hatedInItem.length > 5) {
        hatedInItem = [...hatedInItem.take(5), '...'];
      }
      if(lovedInItem.length > 5) {
        lovedInItem = [...lovedInItem.take(5), '...'];
      }
    }

    return [hatedInItem, lovedInItem, soundInItem];
  }

  void addTagToList(String type, String tag) {
    switch (type) {
      case 'hated':
        if (!hatedTags.contains(tag)) {
          hatedTags.add(tag);
        }
        break;
      case 'loved':
        if (!lovedTags.contains(tag)) {
          lovedTags.add(tag);
        }
        break;
      default: break;
    }
    saveSettings(restate: false);
  }

  void removeTagFromList(String type, String tag) {
    switch (type) {
      case 'hated':
        if (hatedTags.contains(tag)) {
          hatedTags.remove(tag);
        }
        break;
      case 'loved':
        if (lovedTags.contains(tag)) {
          lovedTags.remove(tag);
        }
        break;
      default: break;
    }
    saveSettings(restate: false);
  }

  List<String> cleanTagsList(List<String> tags) {
    return tags.where((tag) => tag != "").map((tag) => tag.trim().toLowerCase()).toList();
  }

  void checkUpdate({bool withMessage = false}) async {
    const String changelog = r"""Changelog""";
    Map<String, dynamic> fakeUpdate = {
      "version_name": "2.2.0",
      "build_number": 170,
      "title": "Title",
      "changelog": changelog,
      "is_in_store": true, // is app still in store
      "is_update_in_store": true, // is update available in store [LEGACY], after 2.2.0 hits the store - left this in update.json as true for backwards compatibility with pre-2.2
      "is_important": false, // is update important => force open dialog on start
      "store_package": "com.noaisu.play.loliSnatcher", // custom app package name, to allow to redirect store users to new app if it will be needed
      "github_url": "https://github.com/NO-ob/LoliSnatcher_Droid/releases/latest"
    }; // fake update json for tests
    // String fakeUpdate = '123'; // broken string

    try {
      const String updateFileName = EnvironmentConfig.isFromStore ? "update_store.json" : "update.json";
      final response = await http.get(Uri.parse('https://raw.githubusercontent.com/NO-ob/LoliSnatcher_Droid/master/$updateFileName'));
      final json = jsonDecode(response.body);
      // final json = jsonDecode(jsonEncode(fakeUpdate));

      // use this and fakeUpdate to generate json file
      Logger.Inst().log(jsonEncode(json), 'SettingsHandler', 'checkUpdate', LogTypes.settingsError);

      updateInfo.value = UpdateInfo(
        versionName: json["version_name"] ?? '0.0.0',
        buildNumber: json["build_number"] ?? 0,
        title: json["title"] ?? '...',
        changelog: json["changelog"] ?? '...',
        isInStore: json["is_in_store"] ?? false,
        isImportant: json["is_important"] ?? false,
        storePackage: json["store_package"] ?? '',
        githubURL: json["github_url"] ?? 'https://github.com/NO-ob/LoliSnatcher_Droid/releases/latest',
      );

      String? discordFromGithub = json["discord_url"];
      if(discordFromGithub != null && discordFromGithub.isNotEmpty) {
        // overwrite included discord url if it's not the same as the one in update info
        if(discordFromGithub != discordURL.value) {
          discordURL.value = discordFromGithub;
        }
      }

      if(buildNumber < (updateInfo.value!.buildNumber)) { // if current build number is less than update build number in json
        if(EnvironmentConfig.isFromStore) { // installed from store
          if(updateInfo.value!.isInStore) { // app is still in store
            showUpdate(withMessage || updateInfo.value!.isImportant);
          } else { // app was removed from store
            // then always notify user so they can move to github version and get news about removal
            showUpdate(true);
          }
        } else { // installed from github
          showUpdate(withMessage || updateInfo.value!.isImportant);
        }
      } else { // otherwise show latest version message
        showLastVersionMessage(withMessage);
        updateInfo.value = null;
      }

    } catch (e) {
      if(withMessage) {
        FlashElements.showSnackbar(
          title: const Text(
            "Update Check Error!",
            style: TextStyle(fontSize: 20)
          ),
          content: Text(
            e.toString()
          ),
          sideColor: Colors.red,
          leadingIcon: Icons.update,
          leadingIconColor: Colors.red,
        );
      }
    }
  }

  void showLastVersionMessage(bool withMessage) {
    if(withMessage) {
      FlashElements.showSnackbar(
        title: const Text(
          "You already have the latest version!",
          style: TextStyle(fontSize: 20)
        ),
        sideColor: Colors.green,
        leadingIcon: Icons.update,
        leadingIconColor: Colors.green,
      );
    }
  }

  void showUpdate(bool withMessage) {
    if(withMessage && updateInfo.value != null) {
      // TODO get from some external variable when building
      bool isFromStore = EnvironmentConfig.isFromStore;

      showDialog(
        context: NavigationHandler.instance.navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return SettingsDialog(
            title: Text('Update Available: ${updateInfo.value!.versionName}+${updateInfo.value!.buildNumber}'),
            contentItems: [
              Text('Currently Installed: $verStr+$buildNumber'),
              const Text(''),
              Text(updateInfo.value!.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text(''),
              const Text('Changelog:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text(''),
              Text(updateInfo.value!.changelog),
              // .replaceAll("\n", r"\n").replaceAll("\r", r"\r")
            ],
            actionButtons: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Later')
              ),
              if(isFromStore && updateInfo.value!.isInStore)
                ElevatedButton.icon(
                  onPressed: () async {
                    // try {
                    //   ServiceHandler.launchURL("market://details?id=" + updateInfo.value!.storePackage);
                    // } on PlatformException catch(e) {
                    //   ServiceHandler.launchURL("https://play.google.com/store/apps/details?id=" + updateInfo.value!.storePackage);
                    // }
                    ServiceHandler.launchURL("https://play.google.com/store/apps/details?id=${updateInfo.value!.storePackage}");
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Visit Play Store')
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    ServiceHandler.launchURL(updateInfo.value!.githubURL);
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Visit Releases')
                ),
            ],
          );
        },
        barrierDismissible: false,
      );
    }
  }

  Future<void> setConfigDir() async {
    // print('-=-=-=-=-=-=-=-');
    // print(Platform.environment);
    path = await ServiceHandler.getConfigDir();
    boorusPath = '${path}boorus/';
    return;
  }


  Future<void> initialize() async {
    try {
      await getPerms();
      await loadSettings();

      if (booruList.isEmpty){
        await loadBoorus();
      }
      if (allowSelfSignedCerts){
        HttpOverrides.global = MyHttpOverrides();
      }

      if(Platform.isAndroid || Platform.isIOS) {
        PackageInfo packageInfo = await PackageInfo.fromPlatform();
        packageName = packageInfo.packageName;
      }

      // if(Platform.isAndroid || Platform.isIOS) {
      //   // TODO on desktop flutter doesnt't use version data from pubspec
      //   PackageInfo packageInfo = await PackageInfo.fromPlatform();
      //   appName = packageInfo.appName;
      //   verStr = packageInfo.version;

      //   // in debug build this gives the right number, but in release it adds 2? (162 => 2162)
      //   buildNumber = int.tryParse(packageInfo.buildNumber) ?? 100;
      //   // print('packegaInfo: ${packageInfo.version} ${packageInfo.buildNumber} ${packageInfo.buildSignature}');
      // }

      print('isFromStore: ${EnvironmentConfig.isFromStore}');

      // print('=-=-=-=-=-=-=-=-=-=-=-=-=');
      // print(toJSON());
      // print(jsonEncode(toJSON()));

      checkUpdate(withMessage: false);
      isInit.value = true;
    } catch (e) {
      print('Settings Init error :: $e');
      FlashElements.showSnackbar(
        title: const Text(
          "Initialization Error!",
          style: TextStyle(fontSize: 20)
        ),
        content: Text(
          e.toString()
        ),
        sideColor: Colors.red,
        leadingIcon: Icons.error,
        leadingIconColor: Colors.red,
      );
    }
    return;
  }
}

class EnvironmentConfig {
  static const isFromStore = bool.fromEnvironment(
    'LS_IS_STORE',
    defaultValue: false
  );
}
