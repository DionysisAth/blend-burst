import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_strings_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppStrings
/// returned by `AppStrings.of(context)`.
///
/// Applications need to include `AppStrings.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_strings.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppStrings.localizationsDelegates,
///   supportedLocales: AppStrings.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppStrings.supportedLocales
/// property.
abstract class AppStrings {
  AppStrings(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Button: confirm / dismiss a message.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// Price label or season track name: costs nothing.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Button: go back to the level map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// Button: play the next level.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @great.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get great;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Premium currency name, used as a heading.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get gold;

  /// No description provided for @notEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins'**
  String get notEnoughCoins;

  /// No description provided for @winLevelsForCoins.
  ///
  /// In en, this message translates to:
  /// **'Win levels to earn more coins!'**
  String get winLevelsForCoins;

  /// No description provided for @notEnoughGold.
  ///
  /// In en, this message translates to:
  /// **'Not enough gold'**
  String get notEnoughGold;

  /// No description provided for @levelN.
  ///
  /// In en, this message translates to:
  /// **'Level {id}'**
  String levelN(int id);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language option that follows the phone's system language.
  ///
  /// In en, this message translates to:
  /// **'Phone language'**
  String get languageSystem;

  /// No description provided for @errorWidget.
  ///
  /// In en, this message translates to:
  /// **'Oops, something went wrong here.'**
  String get errorWidget;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the game'**
  String get loadFailed;

  /// Name of world (episode) 1 on the level map.
  ///
  /// In en, this message translates to:
  /// **'Art Studio'**
  String get episode1;

  /// Short, playful title of level 1.
  ///
  /// In en, this message translates to:
  /// **'First Drops'**
  String get levelName1;

  /// Tutorial card text shown at the start of level 1 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Swipe a tile into a neighbor to match 3 or more of the same color!'**
  String get tutorial1;

  /// Short, playful title of level 2.
  ///
  /// In en, this message translates to:
  /// **'Line Up'**
  String get levelName2;

  /// Tutorial card text shown at the start of level 2 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Match 4 in a line, or a 2x2 square, to make a Line Blaster. Swipe it to blast a whole row!'**
  String get tutorial2;

  /// Short, playful title of level 3.
  ///
  /// In en, this message translates to:
  /// **'Mix It Up'**
  String get levelName3;

  /// Tutorial card text shown at the start of level 3 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Swipe a Red tile into a Blue tile to BLEND them into Purple!'**
  String get tutorial3;

  /// Short, playful title of level 4.
  ///
  /// In en, this message translates to:
  /// **'Green Thumb'**
  String get levelName4;

  /// Tutorial card text shown at the start of level 4 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Blue + Yellow = Green. Match 3 Greens for a big paint splash!'**
  String get tutorial4;

  /// Short, playful title of level 5.
  ///
  /// In en, this message translates to:
  /// **'Orange Glow'**
  String get levelName5;

  /// Tutorial card text shown at the start of level 5 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Red + Yellow = Orange. Secondary-color matches clear their neighbors too.'**
  String get tutorial5;

  /// Short, playful title of level 6.
  ///
  /// In en, this message translates to:
  /// **'Paint Bomb'**
  String get levelName6;

  /// Tutorial card text shown at the start of level 6 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Match in an L or T shape to make a Paint Bomb that clears a 3x3 area.'**
  String get tutorial6;

  /// Short, playful title of level 7.
  ///
  /// In en, this message translates to:
  /// **'First Stains'**
  String get levelName7;

  /// Tutorial card text shown at the start of level 7 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Paint stains hide under tiles. Make matches on top of them to clean them up!'**
  String get tutorial7;

  /// Short, playful title of level 8.
  ///
  /// In en, this message translates to:
  /// **'Studio Corners'**
  String get levelName8;

  /// Short, playful title of level 9.
  ///
  /// In en, this message translates to:
  /// **'Prism Light'**
  String get levelName9;

  /// Tutorial card text shown at the start of level 9 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Match 5 in a line to make a Prism. Swap it with any tile to clear every tile of that color!'**
  String get tutorial9;

  /// Short, playful title of level 10.
  ///
  /// In en, this message translates to:
  /// **'Messy Easel'**
  String get levelName10;

  /// Short, playful title of level 11.
  ///
  /// In en, this message translates to:
  /// **'White Burst'**
  String get levelName11;

  /// Tutorial card text shown at the start of level 11 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Blend a secondary with the primary it\'s missing (Purple + Yellow, Green + Red, Orange + Blue) to make a White Burst!'**
  String get tutorial11;

  /// Short, playful title of level 12.
  ///
  /// In en, this message translates to:
  /// **'Palette Knife'**
  String get levelName12;

  /// Short, playful title of level 13.
  ///
  /// In en, this message translates to:
  /// **'Diamond Canvas'**
  String get levelName13;

  /// Short, playful title of level 14.
  ///
  /// In en, this message translates to:
  /// **'Color Study'**
  String get levelName14;

  /// Short, playful title of level 15.
  ///
  /// In en, this message translates to:
  /// **'Gallery Opening'**
  String get levelName15;

  /// Name of world (episode) 2 on the level map.
  ///
  /// In en, this message translates to:
  /// **'Rainbow Garden'**
  String get episode2;

  /// Short, playful title of level 16.
  ///
  /// In en, this message translates to:
  /// **'Greenhouse'**
  String get levelName16;

  /// Tutorial card text shown at the start of level 16 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Glass blocks break when you make a match next to them, or blast them with specials.'**
  String get tutorial16;

  /// Short, playful title of level 17.
  ///
  /// In en, this message translates to:
  /// **'Window Box'**
  String get levelName17;

  /// Short, playful title of level 18.
  ///
  /// In en, this message translates to:
  /// **'Double Glazed'**
  String get levelName18;

  /// Tutorial card text shown at the start of level 18 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Some glass has 2 layers. Hit it twice!'**
  String get tutorial18;

  /// Short, playful title of level 19.
  ///
  /// In en, this message translates to:
  /// **'Garden Path'**
  String get levelName19;

  /// Short, playful title of level 20.
  ///
  /// In en, this message translates to:
  /// **'Thorny Hedge'**
  String get levelName20;

  /// Short, playful title of level 21.
  ///
  /// In en, this message translates to:
  /// **'Violet Bloom'**
  String get levelName21;

  /// Tutorial card text shown at the start of level 21 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Purple tiles now grow on the board. Blend more to collect faster!'**
  String get tutorial21;

  /// Short, playful title of level 22.
  ///
  /// In en, this message translates to:
  /// **'Sunflowers'**
  String get levelName22;

  /// Short, playful title of level 23.
  ///
  /// In en, this message translates to:
  /// **'Lily Pond'**
  String get levelName23;

  /// Short, playful title of level 24.
  ///
  /// In en, this message translates to:
  /// **'Trellis'**
  String get levelName24;

  /// Short, playful title of level 25.
  ///
  /// In en, this message translates to:
  /// **'Rainbow Gate'**
  String get levelName25;

  /// Short, playful title of level 26.
  ///
  /// In en, this message translates to:
  /// **'Mixed Bouquet'**
  String get levelName26;

  /// Short, playful title of level 27.
  ///
  /// In en, this message translates to:
  /// **'Glass Garden'**
  String get levelName27;

  /// Short, playful title of level 28.
  ///
  /// In en, this message translates to:
  /// **'Seed Rows'**
  String get levelName28;

  /// Short, playful title of level 29.
  ///
  /// In en, this message translates to:
  /// **'Petal Spiral'**
  String get levelName29;

  /// Short, playful title of level 30.
  ///
  /// In en, this message translates to:
  /// **'Royal Garden'**
  String get levelName30;

  /// Name of world (episode) 3 on the level map.
  ///
  /// In en, this message translates to:
  /// **'Paint Factory'**
  String get episode3;

  /// Short, playful title of level 31.
  ///
  /// In en, this message translates to:
  /// **'Rising Paint'**
  String get levelName31;

  /// Tutorial card text shown at the start of level 31 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'In the Paint Factory, gravity can change! Here tiles fall UP. Watch the arrow on the board edge.'**
  String get tutorial31;

  /// Short, playful title of level 32.
  ///
  /// In en, this message translates to:
  /// **'Sideways Drip'**
  String get levelName32;

  /// Tutorial card text shown at the start of level 32 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Gravity pulls to the left now. New tiles enter from the right.'**
  String get tutorial32;

  /// Short, playful title of level 33.
  ///
  /// In en, this message translates to:
  /// **'Conveyor'**
  String get levelName33;

  /// Short, playful title of level 34.
  ///
  /// In en, this message translates to:
  /// **'Switch Gear'**
  String get levelName34;

  /// Tutorial card text shown at the start of level 34 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Tiles with a swirl badge are Gravity Switches. Clear one to rotate gravity 90 degrees!'**
  String get tutorial34;

  /// Short, playful title of level 35.
  ///
  /// In en, this message translates to:
  /// **'Upside Studio'**
  String get levelName35;

  /// Short, playful title of level 36.
  ///
  /// In en, this message translates to:
  /// **'Spin Cycle'**
  String get levelName36;

  /// Short, playful title of level 37.
  ///
  /// In en, this message translates to:
  /// **'Paint Mixer'**
  String get levelName37;

  /// Short, playful title of level 38.
  ///
  /// In en, this message translates to:
  /// **'Pressure Pipes'**
  String get levelName38;

  /// Short, playful title of level 39.
  ///
  /// In en, this message translates to:
  /// **'Tumble Dryer'**
  String get levelName39;

  /// Short, playful title of level 40.
  ///
  /// In en, this message translates to:
  /// **'Gravity Storm'**
  String get levelName40;

  /// Short, playful title of level 41.
  ///
  /// In en, this message translates to:
  /// **'Clockwork'**
  String get levelName41;

  /// Tutorial card text shown at the start of level 41 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'These gears turn on their own! Gravity rotates every few moves; the counter by the arrow shows when.'**
  String get tutorial41;

  /// Short, playful title of level 42.
  ///
  /// In en, this message translates to:
  /// **'Flip Switch'**
  String get levelName42;

  /// Tutorial card text shown at the start of level 42 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'New booster: Gravity Flip! Choose where tiles fall for your next move.'**
  String get tutorial42;

  /// Short, playful title of level 43.
  ///
  /// In en, this message translates to:
  /// **'Conveyor Belts'**
  String get levelName43;

  /// Tutorial card text shown at the start of level 43 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Arrows on cells are gravity zones: tiles there fall the way the arrow points.'**
  String get tutorial43;

  /// Short, playful title of level 44.
  ///
  /// In en, this message translates to:
  /// **'Spin Dryer'**
  String get levelName44;

  /// Short, playful title of level 45.
  ///
  /// In en, this message translates to:
  /// **'Factory Finale'**
  String get levelName45;

  /// Name of world (episode) 4 on the level map.
  ///
  /// In en, this message translates to:
  /// **'Sky Gallery'**
  String get episode4;

  /// Short, playful title of level 46.
  ///
  /// In en, this message translates to:
  /// **'Chained Canvas'**
  String get levelName46;

  /// Tutorial card text shown at the start of level 46 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Chained tiles cannot move. Match them (or blast them) to break the chains!'**
  String get tutorial46;

  /// Short, playful title of level 47.
  ///
  /// In en, this message translates to:
  /// **'Gallery Wall'**
  String get levelName47;

  /// Short, playful title of level 48.
  ///
  /// In en, this message translates to:
  /// **'Double Bolted'**
  String get levelName48;

  /// Tutorial card text shown at the start of level 48 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Gold padlocks have two chains: break them twice.'**
  String get tutorial48;

  /// Short, playful title of level 49.
  ///
  /// In en, this message translates to:
  /// **'Hanging Frames'**
  String get levelName49;

  /// Short, playful title of level 50.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get levelName50;

  /// Short, playful title of level 51.
  ///
  /// In en, this message translates to:
  /// **'Skylight'**
  String get levelName51;

  /// Short, playful title of level 52.
  ///
  /// In en, this message translates to:
  /// **'Cloud Steps'**
  String get levelName52;

  /// Short, playful title of level 53.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get levelName53;

  /// Short, playful title of level 54.
  ///
  /// In en, this message translates to:
  /// **'Exhibit'**
  String get levelName54;

  /// Short, playful title of level 55.
  ///
  /// In en, this message translates to:
  /// **'Locked Wing'**
  String get levelName55;

  /// Short, playful title of level 56.
  ///
  /// In en, this message translates to:
  /// **'Open Air'**
  String get levelName56;

  /// Short, playful title of level 57.
  ///
  /// In en, this message translates to:
  /// **'Sky Bridge'**
  String get levelName57;

  /// Short, playful title of level 58.
  ///
  /// In en, this message translates to:
  /// **'Wind Chimes'**
  String get levelName58;

  /// Short, playful title of level 59.
  ///
  /// In en, this message translates to:
  /// **'Curator'**
  String get levelName59;

  /// Short, playful title of level 60.
  ///
  /// In en, this message translates to:
  /// **'Grand Gallery'**
  String get levelName60;

  /// Name of world (episode) 5 on the level map.
  ///
  /// In en, this message translates to:
  /// **'Ink Lagoon'**
  String get episode5;

  /// Short, playful title of level 61.
  ///
  /// In en, this message translates to:
  /// **'Inkwell'**
  String get levelName61;

  /// Tutorial card text shown at the start of level 61 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Ink spreads every move you do not clear any! Match next to it to wipe it out.'**
  String get tutorial61;

  /// Short, playful title of level 62.
  ///
  /// In en, this message translates to:
  /// **'Spill'**
  String get levelName62;

  /// Short, playful title of level 63.
  ///
  /// In en, this message translates to:
  /// **'Tide Pool'**
  String get levelName63;

  /// Short, playful title of level 64.
  ///
  /// In en, this message translates to:
  /// **'Squid Trail'**
  String get levelName64;

  /// Short, playful title of level 65.
  ///
  /// In en, this message translates to:
  /// **'Black Lagoon'**
  String get levelName65;

  /// Short, playful title of level 66.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get levelName66;

  /// Short, playful title of level 67.
  ///
  /// In en, this message translates to:
  /// **'Ink Rings'**
  String get levelName67;

  /// Short, playful title of level 68.
  ///
  /// In en, this message translates to:
  /// **'Shoreline'**
  String get levelName68;

  /// Short, playful title of level 69.
  ///
  /// In en, this message translates to:
  /// **'Deep Current'**
  String get levelName69;

  /// Short, playful title of level 70.
  ///
  /// In en, this message translates to:
  /// **'Kraken'**
  String get levelName70;

  /// Short, playful title of level 71.
  ///
  /// In en, this message translates to:
  /// **'Low Tide'**
  String get levelName71;

  /// Short, playful title of level 72.
  ///
  /// In en, this message translates to:
  /// **'Bottle Message'**
  String get levelName72;

  /// Short, playful title of level 73.
  ///
  /// In en, this message translates to:
  /// **'Riptide'**
  String get levelName73;

  /// Short, playful title of level 74.
  ///
  /// In en, this message translates to:
  /// **'Pearl Diver'**
  String get levelName74;

  /// Short, playful title of level 75.
  ///
  /// In en, this message translates to:
  /// **'Lagoon Storm'**
  String get levelName75;

  /// Name of world (episode) 6 on the level map.
  ///
  /// In en, this message translates to:
  /// **'Prism Peaks'**
  String get episode6;

  /// Short, playful title of level 76.
  ///
  /// In en, this message translates to:
  /// **'Tinted Glass'**
  String get levelName76;

  /// Tutorial card text shown at the start of level 76 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Color filters paint any tile that falls into them. Use them to collect colors!'**
  String get tutorial76;

  /// Short, playful title of level 77.
  ///
  /// In en, this message translates to:
  /// **'Rainbow Ridge'**
  String get levelName77;

  /// Short, playful title of level 78.
  ///
  /// In en, this message translates to:
  /// **'Crystal Cave'**
  String get levelName78;

  /// Short, playful title of level 79.
  ///
  /// In en, this message translates to:
  /// **'Prism Pass'**
  String get levelName79;

  /// Short, playful title of level 80.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get levelName80;

  /// Short, playful title of level 81.
  ///
  /// In en, this message translates to:
  /// **'Glacier'**
  String get levelName81;

  /// Short, playful title of level 82.
  ///
  /// In en, this message translates to:
  /// **'Summit'**
  String get levelName82;

  /// Short, playful title of level 83.
  ///
  /// In en, this message translates to:
  /// **'Opal Steps'**
  String get levelName83;

  /// Short, playful title of level 84.
  ///
  /// In en, this message translates to:
  /// **'Lens'**
  String get levelName84;

  /// Short, playful title of level 85.
  ///
  /// In en, this message translates to:
  /// **'Aurora'**
  String get levelName85;

  /// Short, playful title of level 86.
  ///
  /// In en, this message translates to:
  /// **'Geode'**
  String get levelName86;

  /// Short, playful title of level 87.
  ///
  /// In en, this message translates to:
  /// **'Kaleidoscope'**
  String get levelName87;

  /// Short, playful title of level 88.
  ///
  /// In en, this message translates to:
  /// **'Snowcap'**
  String get levelName88;

  /// Short, playful title of level 89.
  ///
  /// In en, this message translates to:
  /// **'Prism Heart'**
  String get levelName89;

  /// Short, playful title of level 90.
  ///
  /// In en, this message translates to:
  /// **'Peak of Colors'**
  String get levelName90;

  /// Name of world (episode) 7 on the level map.
  ///
  /// In en, this message translates to:
  /// **'Bucket Brigade'**
  String get episode7;

  /// Short, playful title of level 91.
  ///
  /// In en, this message translates to:
  /// **'First Delivery'**
  String get levelName91;

  /// Tutorial card text shown at the start of level 91 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Bring the paint buckets to the exit, the glowing edge in the gravity direction!'**
  String get tutorial91;

  /// Short, playful title of level 92.
  ///
  /// In en, this message translates to:
  /// **'Bucket Line'**
  String get levelName92;

  /// Short, playful title of level 93.
  ///
  /// In en, this message translates to:
  /// **'Paint Run'**
  String get levelName93;

  /// Short, playful title of level 94.
  ///
  /// In en, this message translates to:
  /// **'Downhill'**
  String get levelName94;

  /// Short, playful title of level 95.
  ///
  /// In en, this message translates to:
  /// **'Heavy Load'**
  String get levelName95;

  /// Short, playful title of level 96.
  ///
  /// In en, this message translates to:
  /// **'Upward Pour'**
  String get levelName96;

  /// Tutorial card text shown at the start of level 96 (teaches a new mechanic; keep it short).
  ///
  /// In en, this message translates to:
  /// **'Gravity is up here, so the exit is at the top!'**
  String get tutorial96;

  /// Short, playful title of level 97.
  ///
  /// In en, this message translates to:
  /// **'Chained Cargo'**
  String get levelName97;

  /// Short, playful title of level 98.
  ///
  /// In en, this message translates to:
  /// **'Side Chute'**
  String get levelName98;

  /// Short, playful title of level 99.
  ///
  /// In en, this message translates to:
  /// **'Ink Spill'**
  String get levelName99;

  /// Short, playful title of level 100.
  ///
  /// In en, this message translates to:
  /// **'Century'**
  String get levelName100;

  /// Short, playful title of level 101.
  ///
  /// In en, this message translates to:
  /// **'Turntable'**
  String get levelName101;

  /// Short, playful title of level 102.
  ///
  /// In en, this message translates to:
  /// **'Switchback'**
  String get levelName102;

  /// Short, playful title of level 103.
  ///
  /// In en, this message translates to:
  /// **'Funnel'**
  String get levelName103;

  /// Short, playful title of level 104.
  ///
  /// In en, this message translates to:
  /// **'Color Pipeline'**
  String get levelName104;

  /// Short, playful title of level 105.
  ///
  /// In en, this message translates to:
  /// **'Brigade Finale'**
  String get levelName105;

  /// Name of world (episode) 8 on the level map.
  ///
  /// In en, this message translates to:
  /// **'Gravity Galaxy'**
  String get episode8;

  /// Short, playful title of level 106.
  ///
  /// In en, this message translates to:
  /// **'Orbit'**
  String get levelName106;

  /// Short, playful title of level 107.
  ///
  /// In en, this message translates to:
  /// **'Comet Tail'**
  String get levelName107;

  /// Short, playful title of level 108.
  ///
  /// In en, this message translates to:
  /// **'Moon Phases'**
  String get levelName108;

  /// Short, playful title of level 109.
  ///
  /// In en, this message translates to:
  /// **'Black Hole'**
  String get levelName109;

  /// Short, playful title of level 110.
  ///
  /// In en, this message translates to:
  /// **'Supernova'**
  String get levelName110;

  /// Short, playful title of level 111.
  ///
  /// In en, this message translates to:
  /// **'Zero G'**
  String get levelName111;

  /// Short, playful title of level 112.
  ///
  /// In en, this message translates to:
  /// **'Nebula'**
  String get levelName112;

  /// Short, playful title of level 113.
  ///
  /// In en, this message translates to:
  /// **'Asteroid Belt'**
  String get levelName113;

  /// Short, playful title of level 114.
  ///
  /// In en, this message translates to:
  /// **'Starlight'**
  String get levelName114;

  /// Short, playful title of level 115.
  ///
  /// In en, this message translates to:
  /// **'Eclipse'**
  String get levelName115;

  /// Short, playful title of level 116.
  ///
  /// In en, this message translates to:
  /// **'Gravity Well'**
  String get levelName116;

  /// Short, playful title of level 117.
  ///
  /// In en, this message translates to:
  /// **'Constellation'**
  String get levelName117;

  /// Short, playful title of level 118.
  ///
  /// In en, this message translates to:
  /// **'Warp Drive'**
  String get levelName118;

  /// Short, playful title of level 119.
  ///
  /// In en, this message translates to:
  /// **'Cosmic Canvas'**
  String get levelName119;

  /// Short, playful title of level 120.
  ///
  /// In en, this message translates to:
  /// **'Blend Burst'**
  String get levelName120;

  /// Booster that removes one tile. Shown under a small booster icon: keep it short.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get boosterBrush;

  /// Booster: swap any two tiles without using a move. Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Free Swap'**
  String get boosterFreeSwap;

  /// Booster that paints a whole row in one color. Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Color Splash'**
  String get boosterColorSplash;

  /// Booster: choose the direction tiles fall. Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Gravity Flip'**
  String get boosterGravityFlip;

  /// Special tile that clears a whole row or column (made by matching 4). Also a pre-level booster. Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Line Blaster'**
  String get boosterLineBlaster;

  /// Special tile that clears a 3x3 area (made by an L or T match). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Paint Bomb'**
  String get boosterPaintBomb;

  /// Special tile that clears every tile of one color (made by matching 5). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Prism'**
  String get boosterPrism;

  /// No description provided for @boosterBrushHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap a tile to wipe it away.'**
  String get boosterBrushHelp;

  /// No description provided for @boosterFreeSwapHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap two tiles to swap them.'**
  String get boosterFreeSwapHelp;

  /// No description provided for @boosterColorSplashHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap a tile to paint its whole row in its color.'**
  String get boosterColorSplashHelp;

  /// No description provided for @boosterGravityFlipHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick where tiles fall during your next move.'**
  String get boosterGravityFlipHelp;

  /// No description provided for @boosterLineBlasterHelp.
  ///
  /// In en, this message translates to:
  /// **'Start the level with a Line Blaster.'**
  String get boosterLineBlasterHelp;

  /// No description provided for @boosterPaintBombHelp.
  ///
  /// In en, this message translates to:
  /// **'Start the level with a Paint Bomb.'**
  String get boosterPaintBombHelp;

  /// No description provided for @boosterPrismHelp.
  ///
  /// In en, this message translates to:
  /// **'Start the level with a Prism.'**
  String get boosterPrismHelp;

  /// Tile color name. Used alone (e.g. 'Collect 5 {color}', 'Collect {color} tiles!'): use a form that reads well on its own, like a noun for the color.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// Dark brown tile color (cannot be blended).
  ///
  /// In en, this message translates to:
  /// **'Umber'**
  String get colorUmber;

  /// Dark gray tile color (cannot be blended).
  ///
  /// In en, this message translates to:
  /// **'Charcoal'**
  String get colorCharcoal;

  /// Phone notification title.
  ///
  /// In en, this message translates to:
  /// **'Your lives are full!'**
  String get reminderLivesTitle;

  /// No description provided for @reminderLivesBody.
  ///
  /// In en, this message translates to:
  /// **'Come back and blend some colors.'**
  String get reminderLivesBody;

  /// Phone notification. 'Paint Collector' is the name of the weekly event: translate it the same way everywhere.
  ///
  /// In en, this message translates to:
  /// **'Paint Collector ends soon'**
  String get reminderEventTitle;

  /// No description provided for @reminderEventBody.
  ///
  /// In en, this message translates to:
  /// **'Only 3 hours left to collect {color} tiles!'**
  String reminderEventBody(String color);

  /// No description provided for @reminderDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your daily gift is ready'**
  String get reminderDailyTitle;

  /// Keep 'Blend Burst' (the game's name) untranslated.
  ///
  /// In en, this message translates to:
  /// **'Open Blend Burst to claim it.'**
  String get reminderDailyBody;

  /// Settings switch title and the phone's notification channel name.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// Description of the notification channel in the phone's settings.
  ///
  /// In en, this message translates to:
  /// **'Full lives and event reminders'**
  String get notificationChannelHelp;

  /// Title of the level editor screen.
  ///
  /// In en, this message translates to:
  /// **'Level editor'**
  String get editorTitle;

  /// Default name of a new level in the editor.
  ///
  /// In en, this message translates to:
  /// **'Custom level'**
  String get editorCustomLevel;

  /// No description provided for @editorJsonCopied.
  ///
  /// In en, this message translates to:
  /// **'Level JSON copied to clipboard'**
  String get editorJsonCopied;

  /// No description provided for @editorImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import level JSON'**
  String get editorImportTitle;

  /// Button: import a level from pasted JSON.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get editorImport;

  /// No description provided for @editorImported.
  ///
  /// In en, this message translates to:
  /// **'Level imported'**
  String get editorImported;

  /// No description provided for @editorInvalidLevel.
  ///
  /// In en, this message translates to:
  /// **'Invalid level: {error}'**
  String editorInvalidLevel(String error);

  /// A computer player test-plays the level; shown when it crashes.
  ///
  /// In en, this message translates to:
  /// **'Bot failed: {error}'**
  String editorBotFailed(String error);

  /// No description provided for @editorLoadLevel.
  ///
  /// In en, this message translates to:
  /// **'Load level'**
  String get editorLoadLevel;

  /// No description provided for @editorImportJson.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get editorImportJson;

  /// No description provided for @editorCopyJson.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON'**
  String get editorCopyJson;

  /// Button: play the level being edited to test it.
  ///
  /// In en, this message translates to:
  /// **'Play test'**
  String get editorPlayTest;

  /// Editor brush: a normal playable board cell.
  ///
  /// In en, this message translates to:
  /// **'Cell'**
  String get editorToolCell;

  /// Editor brush: an empty gap in the board.
  ///
  /// In en, this message translates to:
  /// **'Hole'**
  String get editorToolHole;

  /// Editor brush: a paint stain under a tile.
  ///
  /// In en, this message translates to:
  /// **'Stain'**
  String get editorToolStain;

  /// Editor brush: a glass block with this many layers.
  ///
  /// In en, this message translates to:
  /// **'Glass {layers}'**
  String editorToolGlass(int layers);

  /// Editor brush: a tile that rotates gravity when cleared.
  ///
  /// In en, this message translates to:
  /// **'Gravity switch'**
  String get editorToolSwitch;

  /// Editor brush: a tile of the chosen color.
  ///
  /// In en, this message translates to:
  /// **'Tile'**
  String get editorToolTile;

  /// Editor brush: a tile with a random color.
  ///
  /// In en, this message translates to:
  /// **'Random tile'**
  String get editorToolRandomTile;

  /// No description provided for @editorToolChain.
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get editorToolChain;

  /// No description provided for @editorToolDoubleChain.
  ///
  /// In en, this message translates to:
  /// **'Double chain'**
  String get editorToolDoubleChain;

  /// No description provided for @editorToolInk.
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get editorToolInk;

  /// Editor brush: a paint bucket to bring to the exit.
  ///
  /// In en, this message translates to:
  /// **'Bucket'**
  String get editorToolBucket;

  /// No description provided for @editorToolFilter.
  ///
  /// In en, this message translates to:
  /// **'Color filter'**
  String get editorToolFilter;

  /// No description provided for @editorToolZone.
  ///
  /// In en, this message translates to:
  /// **'Gravity zone'**
  String get editorToolZone;

  /// No description provided for @editorToolClearOverlay.
  ///
  /// In en, this message translates to:
  /// **'Clear filter/zone'**
  String get editorToolClearOverlay;

  /// No description provided for @editorName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get editorName;

  /// No description provided for @editorRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get editorRows;

  /// No description provided for @editorColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get editorColumns;

  /// No description provided for @editorMoves.
  ///
  /// In en, this message translates to:
  /// **'Moves'**
  String get editorMoves;

  /// No description provided for @editorLevelId.
  ///
  /// In en, this message translates to:
  /// **'Level id'**
  String get editorLevelId;

  /// No description provided for @editorBucketsTotal.
  ///
  /// In en, this message translates to:
  /// **'Buckets in total'**
  String get editorBucketsTotal;

  /// No description provided for @editorBucketsOnBoard.
  ///
  /// In en, this message translates to:
  /// **'Buckets on board at once'**
  String get editorBucketsOnBoard;

  /// No description provided for @editorGravityEvery.
  ///
  /// In en, this message translates to:
  /// **'Gravity turns every N moves (0 = off)'**
  String get editorGravityEvery;

  /// No description provided for @editorGravity.
  ///
  /// In en, this message translates to:
  /// **'Gravity'**
  String get editorGravity;

  /// Switch: whether tiles of two colors can be mixed in this level.
  ///
  /// In en, this message translates to:
  /// **'Blending allowed'**
  String get editorBlending;

  /// No description provided for @editorHard.
  ///
  /// In en, this message translates to:
  /// **'Hard level'**
  String get editorHard;

  /// No description provided for @editorSwitchChance.
  ///
  /// In en, this message translates to:
  /// **'Gravity switch spawn chance: {percent}%'**
  String editorSwitchChance(String percent);

  /// No description provided for @editorColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get editorColors;

  /// No description provided for @editorGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get editorGoals;

  /// No description provided for @editorAddGoal.
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get editorAddGoal;

  /// No description provided for @editorStarThresholds.
  ///
  /// In en, this message translates to:
  /// **'Star thresholds (score)'**
  String get editorStarThresholds;

  /// Label: score needed for 1, 2 or 3 stars.
  ///
  /// In en, this message translates to:
  /// **'{n} star'**
  String editorStarN(int n);

  /// No description provided for @editorTutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial text (optional)'**
  String get editorTutorial;

  /// Button: let a computer player try the level several times.
  ///
  /// In en, this message translates to:
  /// **'Bot test ({plays} plays)'**
  String editorBotTest(int plays);

  /// A setting name and its number, e.g. "Rows: 8".
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String editorStepper(String label, int value);

  /// Goal amount to reach.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get editorTarget;

  /// No description provided for @editorCount.
  ///
  /// In en, this message translates to:
  /// **'Count (0 = all)'**
  String get editorCount;

  /// Goal type in the editor: reach a score.
  ///
  /// In en, this message translates to:
  /// **'score'**
  String get editorGoalScore;

  /// Goal type in the editor: clear paint stains.
  ///
  /// In en, this message translates to:
  /// **'stains'**
  String get editorGoalStains;

  /// Goal type in the editor: break glass blocks.
  ///
  /// In en, this message translates to:
  /// **'glass'**
  String get editorGoalGlass;

  /// Goal type in the editor: collect tiles of a color.
  ///
  /// In en, this message translates to:
  /// **'collect'**
  String get editorGoalCollect;

  /// Goal type in the editor: break chains.
  ///
  /// In en, this message translates to:
  /// **'locks'**
  String get editorGoalLocks;

  /// Goal type in the editor: clear all ink.
  ///
  /// In en, this message translates to:
  /// **'ink'**
  String get editorGoalInk;

  /// Goal type in the editor: bring buckets to the exit.
  ///
  /// In en, this message translates to:
  /// **'drop'**
  String get editorGoalDrop;

  /// Small all-caps badge on the level card for a difficult level.
  ///
  /// In en, this message translates to:
  /// **'HARD LEVEL'**
  String get dlgHardLevel;

  /// Heading above the level's goals on the level card.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get dlgGoals;

  /// Number of moves the level gives.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 move} other{{n} moves}}'**
  String dlgMoves(int n);

  /// Strip on the level card; followed by pictures of the free boosters earned. n = wins in a row.
  ///
  /// In en, this message translates to:
  /// **'Win streak {n}!  Free:'**
  String dlgWinStreakFree(int n);

  /// Dialog title offering to buy a booster.
  ///
  /// In en, this message translates to:
  /// **'Get {booster}'**
  String dlgGetBooster(String booster);

  /// help = one-sentence description of the booster; cost = price in coins.
  ///
  /// In en, this message translates to:
  /// **'{help} Buy one for {cost} coins?'**
  String dlgBuyBoosterPrompt(String help, int cost);

  /// Heading above the pre-level booster choices (boosters you start the level with).
  ///
  /// In en, this message translates to:
  /// **'Start with'**
  String get dlgStartWith;

  /// Accessibility label for a pre-level booster button.
  ///
  /// In en, this message translates to:
  /// **'Start with {booster}'**
  String dlgStartWithBooster(String booster);

  /// Accessibility label for an arrow button choosing the direction tiles fall.
  ///
  /// In en, this message translates to:
  /// **'{dir, select, up{Fall up} down{Fall down} left{Fall left} right{Fall right} other{Fall {dir}}}'**
  String dlgFallDirection(String dir);

  /// Title of the booster dialog that picks the gravity direction (same name as the booster).
  ///
  /// In en, this message translates to:
  /// **'Gravity Flip'**
  String get dlgGravityFlipTitle;

  /// No description provided for @dlgGravityFlipQuestion.
  ///
  /// In en, this message translates to:
  /// **'Where should tiles fall during your next move?'**
  String get dlgGravityFlipQuestion;

  /// Ribbon title of the tutorial card that introduces a new mechanic.
  ///
  /// In en, this message translates to:
  /// **'New!'**
  String get dlgTutorialTitle;

  /// Button closing the tutorial card.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get dlgGotIt;

  /// No description provided for @dlgLevelComplete.
  ///
  /// In en, this message translates to:
  /// **'Level complete!'**
  String get dlgLevelComplete;

  /// Small all-caps label above the final score.
  ///
  /// In en, this message translates to:
  /// **'SCORE'**
  String get dlgScore;

  /// Button: go back to the level editor (only when play-testing a level).
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get dlgEditor;

  /// No description provided for @dlgOutOfMoves.
  ///
  /// In en, this message translates to:
  /// **'Out of moves!'**
  String get dlgOutOfMoves;

  /// No description provided for @dlgSoClose.
  ///
  /// In en, this message translates to:
  /// **'So close!'**
  String get dlgSoClose;

  /// Button text: buy extra moves. Short.
  ///
  /// In en, this message translates to:
  /// **'+{n} moves'**
  String dlgPlusMoves(int n);

  /// Button: watch a video ad to get n extra moves. Keep short.
  ///
  /// In en, this message translates to:
  /// **'Watch ad: +{n}'**
  String dlgWatchAdMoves(int n);

  /// No description provided for @dlgGiveUp.
  ///
  /// In en, this message translates to:
  /// **'Give up'**
  String get dlgGiveUp;

  /// No description provided for @dlgLevelFailed.
  ///
  /// In en, this message translates to:
  /// **'Level failed'**
  String get dlgLevelFailed;

  /// No description provided for @dlgTryAgainQuestion.
  ///
  /// In en, this message translates to:
  /// **'Try again?'**
  String get dlgTryAgainQuestion;

  /// No description provided for @dlgLostALife.
  ///
  /// In en, this message translates to:
  /// **'You lost a life'**
  String get dlgLostALife;

  /// No description provided for @dlgLivesLeft.
  ///
  /// In en, this message translates to:
  /// **'Lives left: {n}'**
  String dlgLivesLeft(int n);

  /// No description provided for @dlgPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get dlgPaused;

  /// No description provided for @dlgResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get dlgResume;

  /// Button: quit the level, which costs one life.
  ///
  /// In en, this message translates to:
  /// **'Quit (-1 life)'**
  String get dlgQuitLoseLife;

  /// No description provided for @dlgQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get dlgQuit;

  /// No description provided for @dlgMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get dlgMusic;

  /// No description provided for @dlgSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get dlgSound;

  /// Toggle for vibration (haptic feedback). Short label under a round button.
  ///
  /// In en, this message translates to:
  /// **'Vibrate'**
  String get dlgVibrate;

  /// No description provided for @dlgGetGoldInShop.
  ///
  /// In en, this message translates to:
  /// **'Get gold in the shop?'**
  String get dlgGetGoldInShop;

  /// Title of the lives panel.
  ///
  /// In en, this message translates to:
  /// **'Lives'**
  String get dlgLives;

  /// Title of the lives panel when lives are not full.
  ///
  /// In en, this message translates to:
  /// **'More lives'**
  String get dlgMoreLives;

  /// No description provided for @dlgUnlimitedLives.
  ///
  /// In en, this message translates to:
  /// **'Unlimited lives!'**
  String get dlgUnlimitedLives;

  /// No description provided for @dlgLivesFull.
  ///
  /// In en, this message translates to:
  /// **'Your lives are full!'**
  String get dlgLivesFull;

  /// Followed by a countdown timer on the next line.
  ///
  /// In en, this message translates to:
  /// **'Next life in'**
  String get dlgNextLifeIn;

  /// Button: refill all lives. Short.
  ///
  /// In en, this message translates to:
  /// **'Refill'**
  String get dlgRefill;

  /// Button: watch a video ad to get one life.
  ///
  /// In en, this message translates to:
  /// **'Watch ad: +1 life'**
  String get dlgWatchAdLife;

  /// Reward shown with a video ad.
  ///
  /// In en, this message translates to:
  /// **'+1 life'**
  String get dlgRewardOneLife;

  /// Duration in minutes, short (button: 30 minutes of unlimited lives).
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String dlgMinutes(int n);

  /// Text shared with a screenshot after a big combo. Keep the game name 'Blend Burst' untranslated.
  ///
  /// In en, this message translates to:
  /// **'What a combo on level {id} of Blend Burst!'**
  String gameShareCombo(int id);

  /// Text shared with a screenshot after winning a level. Keep the game name 'Blend Burst' untranslated.
  ///
  /// In en, this message translates to:
  /// **'I beat level {id} of Blend Burst!'**
  String gameShareWin(int id);

  /// Dialog title offering to buy a booster; {booster} is the booster's name.
  ///
  /// In en, this message translates to:
  /// **'Get {booster}'**
  String gameGetBooster(String booster);

  /// No description provided for @gameBuyBoosterQuestion.
  ///
  /// In en, this message translates to:
  /// **'Buy one {booster} for {coins} coins?'**
  String gameBuyBoosterQuestion(String booster, int coins);

  /// Reward label: extra moves for the current level.
  ///
  /// In en, this message translates to:
  /// **'+{n} moves'**
  String gamePlusMoves(int n);

  /// Small button that pops up after a big combo to share a screenshot (tight space).
  ///
  /// In en, this message translates to:
  /// **'Share!'**
  String get gameShareButton;

  /// Screen-reader label of the pause button.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get gamePause;

  /// HUD title while play-testing a level from the level editor.
  ///
  /// In en, this message translates to:
  /// **'Test level'**
  String get gameTestLevel;

  /// Hint while using the Free Swap booster, after the first tile was picked.
  ///
  /// In en, this message translates to:
  /// **'Now tap the second tile.'**
  String get gameTapSecondTile;

  /// Tooltip: tiles currently fall downward.
  ///
  /// In en, this message translates to:
  /// **'Gravity down'**
  String get gameGravityDown;

  /// Tooltip: tiles currently fall upward.
  ///
  /// In en, this message translates to:
  /// **'Gravity up'**
  String get gameGravityUp;

  /// Tooltip: tiles currently fall to the left.
  ///
  /// In en, this message translates to:
  /// **'Gravity left'**
  String get gameGravityLeft;

  /// Tooltip: tiles currently fall to the right.
  ///
  /// In en, this message translates to:
  /// **'Gravity right'**
  String get gameGravityRight;

  /// Tooltip: number of moves until gravity rotates.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{Gravity turns in 1 move} other{Gravity turns in {n} moves}}'**
  String gameGravityTurnsIn(int n);

  /// Tiny uppercase caption above the moves-left number in a small circle (very tight space, ~6 letters).
  ///
  /// In en, this message translates to:
  /// **'MOVES'**
  String get gameMovesBadge;

  /// Big praise callout for a small cascade.
  ///
  /// In en, this message translates to:
  /// **'Great!'**
  String get gamePraiseGreat;

  /// Big praise callout for a bigger cascade.
  ///
  /// In en, this message translates to:
  /// **'Amazing!'**
  String get gamePraiseAmazing;

  /// Big praise callout for a large cascade.
  ///
  /// In en, this message translates to:
  /// **'Brilliant!'**
  String get gamePraiseBrilliant;

  /// Biggest praise callout (huge cascade or whole board cleared).
  ///
  /// In en, this message translates to:
  /// **'Spectacular!'**
  String get gamePraiseSpectacular;

  /// Screen-reader label of the puzzle board.
  ///
  /// In en, this message translates to:
  /// **'Game board'**
  String get gameBoardLabel;

  /// Level goal.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, other{Reach {n} points}}'**
  String gameGoalScore(int n);

  /// Level goal: clean paint stains under tiles.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, other{Clear {n} paint stains}}'**
  String gameGoalStains(int n);

  /// Level goal.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, other{Break {n} glass blocks}}'**
  String gameGoalGlass(int n);

  /// Level goal: collect tiles of a color; {color} is a color name such as 'Purple' (the tiles are implied).
  ///
  /// In en, this message translates to:
  /// **'Collect {n} {color}'**
  String gameGoalCollect(int n, String color);

  /// Level goal: break chains locking tiles.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, other{Break {n} chains}}'**
  String gameGoalLocks(int n);

  /// Level goal: remove all spreading ink.
  ///
  /// In en, this message translates to:
  /// **'Clear all the ink'**
  String get gameGoalInk;

  /// Level goal: move paint buckets to the board's exit edge.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, other{Bring {n} paint buckets to the exit}}'**
  String gameGoalDrop(int n);

  /// Short number in thousands (e.g. 12.5k) in a tiny goal badge.
  ///
  /// In en, this message translates to:
  /// **'{value}k'**
  String gameThousands(String value);

  /// Short duration, e.g. 1h 5m (tight space).
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String gameHoursMinutes(int h, int m);

  /// No description provided for @settingsMoveHints.
  ///
  /// In en, this message translates to:
  /// **'Move hints'**
  String get settingsMoveHints;

  /// No description provided for @settingsMoveHintsSub.
  ///
  /// In en, this message translates to:
  /// **'Show a possible move after 5 seconds'**
  String get settingsMoveHintsSub;

  /// No description provided for @settingsTapActivate.
  ///
  /// In en, this message translates to:
  /// **'Tap to activate specials'**
  String get settingsTapActivate;

  /// Specials are the power-up tiles (Line Blaster, Paint Bomb, Prism).
  ///
  /// In en, this message translates to:
  /// **'Tap a special tile to fire it (uses a move)'**
  String get settingsTapActivateSub;

  /// No description provided for @settingsRemindersSub.
  ///
  /// In en, this message translates to:
  /// **'Full lives, daily gift and event reminders'**
  String get settingsRemindersSub;

  /// No description provided for @settingsRemindersOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for Blend Burst. You can allow them in your phone settings.'**
  String get settingsRemindersOff;

  /// No description provided for @settingsEditor.
  ///
  /// In en, this message translates to:
  /// **'Level editor'**
  String get settingsEditor;

  /// No description provided for @settingsEditorSub.
  ///
  /// In en, this message translates to:
  /// **'Build, play-test and export JSON levels'**
  String get settingsEditorSub;

  /// No description provided for @settingsAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get settingsAnalytics;

  /// No description provided for @settingsAnalyticsSub.
  ///
  /// In en, this message translates to:
  /// **'Win rates and recent events on this device'**
  String get settingsAnalyticsSub;

  /// No description provided for @settingsPrivacyChoices.
  ///
  /// In en, this message translates to:
  /// **'Privacy choices'**
  String get settingsPrivacyChoices;

  /// No description provided for @settingsPrivacyChoicesSub.
  ///
  /// In en, this message translates to:
  /// **'Change your ad consent'**
  String get settingsPrivacyChoicesSub;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsPrivacyPolicySub.
  ///
  /// In en, this message translates to:
  /// **'How the game handles your data'**
  String get settingsPrivacyPolicySub;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset progress'**
  String get settingsReset;

  /// No description provided for @settingsResetSub.
  ///
  /// In en, this message translates to:
  /// **'Start over from level 1'**
  String get settingsResetSub;

  /// No description provided for @settingsResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset?'**
  String get settingsResetTitle;

  /// No description provided for @settingsResetCloud.
  ///
  /// In en, this message translates to:
  /// **'All stars, coins and boosters will be lost, here and in your cloud save.'**
  String get settingsResetCloud;

  /// No description provided for @settingsResetLocal.
  ///
  /// In en, this message translates to:
  /// **'All stars, coins and boosters will be lost.'**
  String get settingsResetLocal;

  /// Button: confirm erasing all progress.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsResetOk;

  /// No description provided for @settingsCredits.
  ///
  /// In en, this message translates to:
  /// **'Music and sounds are made for this game.'**
  String get settingsCredits;

  /// No description provided for @settingsAnalyticsYes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get settingsAnalyticsYes;

  /// No description provided for @settingsAnalyticsNo.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get settingsAnalyticsNo;

  /// Whether the player came back on day N: that day has not come yet.
  ///
  /// In en, this message translates to:
  /// **'not yet'**
  String get settingsAnalyticsNotYet;

  /// No description provided for @settingsAnalyticsKeyMetrics.
  ///
  /// In en, this message translates to:
  /// **'Key metrics'**
  String get settingsAnalyticsKeyMetrics;

  /// Whether the player played again 1, 7 and 30 days after first playing.
  ///
  /// In en, this message translates to:
  /// **'Back on day 1 / 7 / 30'**
  String get settingsAnalyticsRetention;

  /// No description provided for @settingsAnalyticsLevelsPerSession.
  ///
  /// In en, this message translates to:
  /// **'Levels per session'**
  String get settingsAnalyticsLevelsPerSession;

  /// No description provided for @settingsAnalyticsSessionsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Sessions per day'**
  String get settingsAnalyticsSessionsPerDay;

  /// No description provided for @settingsAnalyticsWinRate.
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get settingsAnalyticsWinRate;

  /// No description provided for @settingsAnalyticsAttemptsPerWin.
  ///
  /// In en, this message translates to:
  /// **'Attempts per won level'**
  String get settingsAnalyticsAttemptsPerWin;

  /// No description provided for @settingsAnalyticsExtraMoves.
  ///
  /// In en, this message translates to:
  /// **'Extra moves bought on fail'**
  String get settingsAnalyticsExtraMoves;

  /// No description provided for @settingsAnalyticsAdsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Ads watched per day'**
  String get settingsAnalyticsAdsPerDay;

  /// No description provided for @settingsAnalyticsTutorialsSeen.
  ///
  /// In en, this message translates to:
  /// **'Tutorials seen'**
  String get settingsAnalyticsTutorialsSeen;

  /// No description provided for @settingsAnalyticsPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get settingsAnalyticsPurchases;

  /// No description provided for @settingsAnalyticsHardest.
  ///
  /// In en, this message translates to:
  /// **'Hardest levels'**
  String get settingsAnalyticsHardest;

  /// No description provided for @settingsAnalyticsSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions: {sessions}   Win streak: {streak}'**
  String settingsAnalyticsSessions(int sessions, int streak);

  /// No description provided for @settingsAnalyticsNoLevels.
  ///
  /// In en, this message translates to:
  /// **'No levels played yet.'**
  String get settingsAnalyticsNoLevels;

  /// No description provided for @settingsAnalyticsWins.
  ///
  /// In en, this message translates to:
  /// **'{wins}/{attempts} wins ({percent}%)'**
  String settingsAnalyticsWins(int wins, int attempts, String percent);

  /// No description provided for @settingsAnalyticsRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent events'**
  String get settingsAnalyticsRecent;

  /// No description provided for @cloudLeaderboards.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards'**
  String get cloudLeaderboards;

  /// No description provided for @cloudAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get cloudAchievements;

  /// No description provided for @cloudLeaderboardsNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards need Google Play Games, which is not set up for this version yet. They will appear in a later update.'**
  String get cloudLeaderboardsNotSetUp;

  /// No description provided for @cloudAchievementsNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Achievements need Google Play Games, which is not set up for this version yet. They will appear in a later update.'**
  String get cloudAchievementsNotSetUp;

  /// Last cloud save time, shown after 'Saved'.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get cloudJustNow;

  /// No description provided for @cloudMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String cloudMinAgo(int n);

  /// No description provided for @cloudHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String cloudHoursAgo(int n);

  /// No description provided for @cloudDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String cloudDaysAgo(int n);

  /// No description provided for @cloudComingLater.
  ///
  /// In en, this message translates to:
  /// **'Cloud save and leaderboards are coming in a later update.'**
  String get cloudComingLater;

  /// No description provided for @cloudSignInPitch.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your progress safe in the cloud and compete on the leaderboards.'**
  String get cloudSignInPitch;

  /// No description provided for @cloudSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get cloudSigningIn;

  /// No description provided for @cloudSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String cloudSignedInAs(String name);

  /// No description provided for @cloudSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get cloudSaving;

  /// Last cloud save; {ago} is e.g. 'just now' or '5 min ago'.
  ///
  /// In en, this message translates to:
  /// **'Saved {ago}'**
  String cloudSavedAgo(String ago);

  /// No description provided for @cloudSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get cloudSignIn;

  /// No description provided for @cloudSaveNow.
  ///
  /// In en, this message translates to:
  /// **'Save now'**
  String get cloudSaveNow;

  /// Default player name when Play Games gives none.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get cloudPlayer;

  /// No description provided for @cloudSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in to Play Games.'**
  String get cloudSignInFailed;

  /// No description provided for @cloudReachFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the cloud save. Try again later.'**
  String get cloudReachFailed;

  /// No description provided for @cloudReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the cloud save. Try again later.'**
  String get cloudReadFailed;

  /// No description provided for @cloudUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not upload to the cloud save. Try again later.'**
  String get cloudUploadFailed;

  /// No description provided for @cloudSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Cloud save failed. Try again later.'**
  String get cloudSyncFailed;

  /// No description provided for @cloudSignInFirst.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Play Games first.'**
  String get cloudSignInFirst;

  /// No description provided for @cloudLeaderboardsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the leaderboards.'**
  String get cloudLeaderboardsFailed;

  /// No description provided for @cloudAchievementsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the achievements.'**
  String get cloudAchievementsFailed;

  /// No description provided for @cloudNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Google Play Games is not set up for this version yet.'**
  String get cloudNotSetUp;

  /// No description provided for @storeTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Test purchase'**
  String get storeTestTitle;

  /// {subtitle} is the product description.
  ///
  /// In en, this message translates to:
  /// **'{subtitle}\n\nPrice in the stores: {price}.\nThis test build has no store connected: you will not be charged.'**
  String storeTestBody(String subtitle, String price);

  /// No description provided for @storeTestConfirm.
  ///
  /// In en, this message translates to:
  /// **'Get it (free test)'**
  String get storeTestConfirm;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store unavailable'**
  String get storeUnavailable;

  /// No description provided for @storeUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Google Play could not be reached. Check your connection and try again.'**
  String get storeUnavailableBody;

  /// No description provided for @adsRewardedTitle.
  ///
  /// In en, this message translates to:
  /// **'Rewarded ad'**
  String get adsRewardedTitle;

  /// No description provided for @adsBreakTitle.
  ///
  /// In en, this message translates to:
  /// **'Ad break'**
  String get adsBreakTitle;

  /// No description provided for @adsPlaceholderRewarded.
  ///
  /// In en, this message translates to:
  /// **'No ads SDK in this build: this placeholder stands in for a rewarded video.\n\nReward: {reward}'**
  String adsPlaceholderRewarded(String reward);

  /// No description provided for @adsPlaceholderBreak.
  ///
  /// In en, this message translates to:
  /// **'No ads SDK in this build: this placeholder stands in for a short ad between levels. Any purchase removes ad breaks.'**
  String get adsPlaceholderBreak;

  /// Countdown in seconds.
  ///
  /// In en, this message translates to:
  /// **'Reward in {n}…'**
  String adsRewardIn(int n);

  /// Countdown in seconds.
  ///
  /// In en, this message translates to:
  /// **'Close in {n}…'**
  String adsCloseIn(int n);

  /// No description provided for @adsClaimReward.
  ///
  /// In en, this message translates to:
  /// **'Claim reward'**
  String get adsClaimReward;

  /// No description provided for @adsContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get adsContinue;

  /// No description provided for @adsSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get adsSkip;

  /// No description provided for @adsNoVideo.
  ///
  /// In en, this message translates to:
  /// **'No video right now'**
  String get adsNoVideo;

  /// No description provided for @adsNoVideoBody.
  ///
  /// In en, this message translates to:
  /// **'There is no video to watch at the moment. Please try again in a little while.'**
  String get adsNoVideoBody;

  /// Part of a reward list, e.g. '100 coins'.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 coin} other{{n} coins}}'**
  String rewardCoins(int n);

  /// Amount of gold (premium currency), e.g. '50 gold'. Also the subtitle of gold packs in the shop.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, other{{n} gold}}'**
  String rewardGold(int n);

  /// Part of a reward list, e.g. '5 lives'.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 life} other{{n} lives}}'**
  String rewardLives(int n);

  /// Part of a reward list: minutes of unlimited lives. 'm' = minutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m unlimited lives'**
  String rewardUnlimited(int n);

  /// Part of a reward list: count and booster name, e.g. '2x Brush'.
  ///
  /// In en, this message translates to:
  /// **'{n}x {booster}'**
  String rewardBooster(int n, String booster);

  /// Title of the dialog showing what the player just received.
  ///
  /// In en, this message translates to:
  /// **'Reward!'**
  String get rewardTitle;

  /// No description provided for @productStarterTitle.
  ///
  /// In en, this message translates to:
  /// **'Starter Pack'**
  String get productStarterTitle;

  /// No description provided for @productStarterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'100 gold, 3 of every booster, 1 hour unlimited lives'**
  String get productStarterSubtitle;

  /// Smallest gold pack in the shop.
  ///
  /// In en, this message translates to:
  /// **'Pouch of Gold'**
  String get productGold50Title;

  /// No description provided for @productGold130Title.
  ///
  /// In en, this message translates to:
  /// **'Bag of Gold'**
  String get productGold130Title;

  /// No description provided for @productGold350Title.
  ///
  /// In en, this message translates to:
  /// **'Chest of Gold'**
  String get productGold350Title;

  /// Largest gold pack in the shop.
  ///
  /// In en, this message translates to:
  /// **'Vault of Gold'**
  String get productGold800Title;

  /// No description provided for @productNoAdsTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Ads'**
  String get productNoAdsTitle;

  /// No description provided for @productNoAdsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No more ad breaks between levels'**
  String get productNoAdsSubtitle;

  /// No description provided for @productPassTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium Pass'**
  String get productPassTitle;

  /// No description provided for @productPassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlocks the premium season track'**
  String get productPassSubtitle;

  /// No description provided for @productRefillTitle.
  ///
  /// In en, this message translates to:
  /// **'Lives Refill'**
  String get productRefillTitle;

  /// No description provided for @productRefillSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Refill all {n} lives'**
  String productRefillSubtitle(int n);

  /// No description provided for @productUnlimitedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Lives'**
  String get productUnlimitedTitle;

  /// No description provided for @productUnl30Subtitle.
  ///
  /// In en, this message translates to:
  /// **'30 minutes of free play'**
  String get productUnl30Subtitle;

  /// No description provided for @productUnl60Subtitle.
  ///
  /// In en, this message translates to:
  /// **'1 hour of free play'**
  String get productUnl60Subtitle;

  /// No description provided for @productUnl180Subtitle.
  ///
  /// In en, this message translates to:
  /// **'3 hours of free play'**
  String get productUnl180Subtitle;

  /// No description provided for @productBoosterPackTitle.
  ///
  /// In en, this message translates to:
  /// **'Booster Bundle'**
  String get productBoosterPackTitle;

  /// No description provided for @productBoosterPackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'2 of every in-level booster'**
  String get productBoosterPackSubtitle;

  /// No description provided for @productStartPackTitle.
  ///
  /// In en, this message translates to:
  /// **'Head Start Bundle'**
  String get productStartPackTitle;

  /// No description provided for @productStartPackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'2 of every pre-level booster'**
  String get productStartPackSubtitle;

  /// No description provided for @productFreeBoosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Free Booster'**
  String get productFreeBoosterTitle;

  /// No description provided for @productFreeBoosterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watch an ad, once a day'**
  String get productFreeBoosterSubtitle;

  /// Short label under a small round button (daily gift). Keep very short.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get mapDaily;

  /// Short label under a small round button. Keep very short.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get mapShop;

  /// Short label under a small round button (weekly event). Keep very short.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get mapEvent;

  /// Short label under a small round button (season pass). Keep very short.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get mapPass;

  /// Short label under a small round button (leaderboards). Keep very short.
  ///
  /// In en, this message translates to:
  /// **'Ranks'**
  String get mapRanks;

  /// Small caption under the world name on the map, in capitals.
  ///
  /// In en, this message translates to:
  /// **'EPISODE {n}'**
  String mapEpisodeN(int n);

  /// Tiny badge on a hard level's map node, in capitals. Keep very short.
  ///
  /// In en, this message translates to:
  /// **'HARD'**
  String get mapHard;

  /// Lives counter at the top of the map when all lives are full, e.g. '5 Full'. Tight space.
  ///
  /// In en, this message translates to:
  /// **'{lives} Full'**
  String mapLivesFull(int lives);

  /// Compact duration: hours.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String timeHours(int n);

  /// Compact duration: minutes.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String timeMinutes(int n);

  /// Compact duration: days and hours, e.g. '2d 5h'.
  ///
  /// In en, this message translates to:
  /// **'{d}d {h}h'**
  String timeDaysHours(int d, int h);

  /// Compact duration: hours and minutes, e.g. '4h 30m'.
  ///
  /// In en, this message translates to:
  /// **'{h}h {m}m'**
  String timeHoursMinutes(int h, int m);

  /// No description provided for @dailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Gift'**
  String get dailyTitle;

  /// Day number in the 7-day login calendar. Tight space.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String dailyDayN(int n);

  /// No description provided for @dailyComeBack.
  ///
  /// In en, this message translates to:
  /// **'Come back every day for bigger gifts!'**
  String get dailyComeBack;

  /// No description provided for @dailyComeBackTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for day {day}!'**
  String dailyComeBackTomorrow(int day);

  /// Button: watch a video ad to double the daily gift.
  ///
  /// In en, this message translates to:
  /// **'Watch ad: x2'**
  String get dailyWatchAdDouble;

  /// What a rewarded video gives (shown in the ad screen).
  ///
  /// In en, this message translates to:
  /// **'double daily reward'**
  String get dailyDoubleReward;

  /// Purchase confirmation. item is the product's contents, e.g. 'Refill all 5 lives'.
  ///
  /// In en, this message translates to:
  /// **'{item} for {price} gold?'**
  String shopBuyForGold(String item, int price);

  /// Purchase confirmation. item is the product's contents.
  ///
  /// In en, this message translates to:
  /// **'{item} for {price} coins?'**
  String shopBuyForCoins(String item, int price);

  /// No description provided for @shopMoreGold.
  ///
  /// In en, this message translates to:
  /// **'Get more gold from the gold packs, events and the season pass.'**
  String get shopMoreGold;

  /// No description provided for @shopSpecialOffer.
  ///
  /// In en, this message translates to:
  /// **'Special offer'**
  String get shopSpecialOffer;

  /// Shop section heading.
  ///
  /// In en, this message translates to:
  /// **'Lives'**
  String get shopLives;

  /// Shop section heading.
  ///
  /// In en, this message translates to:
  /// **'Boosters'**
  String get shopBoosters;

  /// Shop section heading.
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get shopExtras;

  /// No description provided for @shopTestBuild.
  ///
  /// In en, this message translates to:
  /// **'Test build: no store is connected, so purchases are free and only unlock items on this device.'**
  String get shopTestBuild;

  /// Shown instead of a price for an item already bought. Tight space.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get shopOwned;

  /// Name of the weekly collection event.
  ///
  /// In en, this message translates to:
  /// **'Paint Collector'**
  String get eventTitle;

  /// No description provided for @eventCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect {color} tiles!'**
  String eventCollect(String color);

  /// color is a color name (lower case in English); time is a compact duration like '2d 5h'.
  ///
  /// In en, this message translates to:
  /// **'Every {color} tile you clear in any level counts. Ends in {time}.'**
  String eventInfo(String color, String time);

  /// Event goal: number of tiles to collect. Narrow column.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{1 tile} other{{n} tiles}}'**
  String eventTierTiles(int n);

  /// Reward already claimed. Tight space.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get eventDone;

  /// Name of the season pass.
  ///
  /// In en, this message translates to:
  /// **'Paint Pass'**
  String get passTitle;

  /// No description provided for @passSeasonRewards.
  ///
  /// In en, this message translates to:
  /// **'Season Rewards'**
  String get passSeasonRewards;

  /// No description provided for @passInfo.
  ///
  /// In en, this message translates to:
  /// **'Win levels to earn points. Ends in {time}.'**
  String passInfo(String time);

  /// No description provided for @passComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete!'**
  String get passComplete;

  /// Season pass progress bar label.
  ///
  /// In en, this message translates to:
  /// **'Tier {tier}: {points} / {total}'**
  String passTierProgress(int tier, int points, int total);

  /// Button: buy the premium track of the season pass.
  ///
  /// In en, this message translates to:
  /// **'Unlock Premium'**
  String get passUnlockPremium;

  /// No description provided for @passPremiumUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Premium unlocked!'**
  String get passPremiumUnlocked;

  /// Column heading: the premium reward track.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get passPremium;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(lookupAppStrings(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

AppStrings lookupAppStrings(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppStringsEn();
  }

  throw FlutterError(
    'AppStrings.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
