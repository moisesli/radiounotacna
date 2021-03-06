import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';



final BannerAdListener listener = BannerAdListener(
  // Called when an ad is successfully received.
  onAdLoaded: (Ad ad) => print('Ad loaded.'),
  // Called when an ad request failed.
  onAdFailedToLoad: (Ad ad, LoadAdError error) {
    // Dispose the ad here to free resources.
    ad.dispose();
    print('Ad failed to load: $error');
  },
  // Called when an ad opens an overlay that covers the screen.
  onAdOpened: (Ad ad) => print('Ad opened.'),
  // Called when an ad removes an overlay that covers the screen.
  onAdClosed: (Ad ad) => print('Ad closed.'),
  // Called when an impression occurs on the ad.
  onAdImpression: (Ad ad) => print('Ad impression.'),
);

final BannerAd myBanner = BannerAd(
  adUnitId: 'ca-app-pub-5852042324891789/8523087733',
  size: AdSize.banner,
  request: AdRequest(),
  listener: BannerAdListener(),
);

final AdWidget adWidget = AdWidget(ad: myBanner);

final Container adContainer = Container(
  alignment: Alignment.center,
  child: adWidget,
  width: myBanner.size.width.toDouble(),
  height: myBanner.size.height.toDouble(),
);