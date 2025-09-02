import 'package:flutter/material.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class AdService {
  static bool _isInitialized = false;
  static int _sessionAdCount = 0;
  static const int _maxAdsPerSession = 3;
  static DateTime _lastAdTime = DateTime(2000);
  
  // Unity Ads Configuration - Real Game IDs
  static const String _androidGameId = '5936707'; // Google Play Store
  static const String _iosGameId = '5936706'; // Apple App Store
  
  // Ad Unit IDs
  static const String _bannerAndroid = 'Banner_Android';
  static const String _bannerIOS = 'Banner_iOS';
  static const String _interstitialAndroid = 'Interstitial_Android';
  static const String _interstitialIOS = 'Interstitial_iOS';
  static const String _rewardedAndroid = 'Rewarded_Android';
  static const String _rewardedIOS = 'Rewarded_iOS';
  
  /// Initialize Unity Ads - Only on mobile platforms
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Only initialize Unity Ads on mobile platforms
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (kDebugMode) {
        print('🖥️ Unity Ads: Skipping initialization on desktop platform (${Platform.operatingSystem})');
      }
      return;
    }
    
    try {
      final gameId = Platform.isAndroid ? _androidGameId : _iosGameId;
      
      await UnityAds.init(
        gameId: gameId,
        testMode: false, // Production mode - real ads enabled
        onComplete: () {
          _isInitialized = true;
          print('✅ Unity Ads initialized successfully with Game ID: $gameId');
          
          // Configure content filtering for educational app
          _configureContentFiltering();
          
          // Preload ads after initialization
          Future.delayed(const Duration(seconds: 2), () {
            preloadAds();
          });
        },
        onFailed: (error, message) {
          print('❌ Unity Ads initialization failed: $error - $message');
        },
      );
    } catch (e) {
      print('❌ Unity Ads initialization error: $e');
    }
  }
  
  /// Show rewarded video ad
  static Future<bool> showRewardedVideo([String? customPlacementId]) async {
    // Return false immediately on desktop platforms
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (kDebugMode) {
        print('🖥️ Unity Ads: Rewarded video not available on desktop platform');
      }
      return false;
    }
    
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return false;
    }
    
    if (!_canShowAd()) return false;
    
    try {
      final placementId = customPlacementId ?? 
          (Platform.isAndroid ? _rewardedAndroid : _rewardedIOS);
      
      // Load the ad first with proper async handling
      bool isLoaded = false;
      bool loadFailed = false;
      
      await UnityAds.load(
        placementId: placementId,
        onComplete: (placementId) {
          isLoaded = true;
          print('✅ Ad loaded successfully: $placementId');
        },
        onFailed: (placementId, error, message) {
          loadFailed = true;
          print('❌ Ad load failed: $error - $message');
        },
      );
      
      // Wait for production ads to load (Unity needs time to fetch inventory)
      int waitTime = 0;
      while (!isLoaded && !loadFailed && waitTime < 10000) {
        await Future.delayed(const Duration(milliseconds: 500));
        waitTime += 500;
      }
      
      if (!isLoaded || loadFailed) {
        print('❌ Ad not loaded after ${waitTime}ms, cannot show');
        return false;
      }
      
      bool adCompleted = false;
      
      // Show the ad
      await UnityAds.showVideoAd(
        placementId: placementId,
        onComplete: (placementId) {
          adCompleted = true;
          _sessionAdCount++;
          _lastAdTime = DateTime.now();
          print('✅ Rewarded video completed: $placementId');
        },
        onFailed: (placementId, error, message) {
          print('❌ Rewarded video failed: $error - $message');
        },
        onStart: (placementId) {
          print('🎬 Rewarded video started: $placementId');
        },
        onSkipped: (placementId) {
          print('⏭️ Rewarded video skipped: $placementId');
        },
      );
      
      return adCompleted;
    } catch (e) {
      print('❌ Rewarded video error: $e');
      return false;
    }
  }
  
  /// Configure content filtering for educational app
  static void _configureContentFiltering() {
    try {
      // Unity Ads doesn't have direct content filtering in Flutter plugin
      // Content filtering must be configured in Unity Dashboard
      print('📚 Educational app - content filtering should be configured in Unity Dashboard');
      print('🚫 Block categories: Dating, Adult, Gambling, Alcohol, Violence');
      print('✅ Allow categories: Education, Productivity, Games (E-rated), Utilities');
    } catch (e) {
      print('❌ Content filtering configuration error: $e');
    }
  }
  
  /// Preload ads for better performance - Only rewarded video (used in About screen)
  static Future<void> preloadAds() async {
    if (!_isInitialized) return;
    
    // Only preload on mobile platforms
    if (!Platform.isAndroid && !Platform.isIOS) return;
    
    try {
      final rewardedId = Platform.isAndroid ? _rewardedAndroid : _rewardedIOS;
      
      // Only preload rewarded video (used in About screen for "Support EduNest")
      UnityAds.load(
        placementId: rewardedId,
        onComplete: (placementId) {
          print('✅ Preloaded rewarded ad: $placementId');
        },
        onFailed: (placementId, error, message) {
          print('⚠️ Preload failed for rewarded: $error');
        },
      );
      
      // Note: Interstitial ads removed - not used in the app
      if (kDebugMode) {
        print('📊 Ad preload: Only rewarded video (interstitial ads not used)');
      }
    } catch (e) {
      print('❌ Preload error: $e');
    }
  }
  
  /// Show interstitial ad - Currently not used in the app
  static Future<bool> showInterstitialAd([String? customPlacementId]) async {
    // Return false immediately on desktop platforms
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (kDebugMode) {
        print('🖥️ Unity Ads: Interstitial ad not available on desktop platform');
      }
      return false;
    }
    
    // Note: This method is available but not currently used in the app
    if (kDebugMode) {
      print('📊 Unity Ads: Interstitial ad requested but not currently used in app');
    }
    
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return false;
    }
    
    if (!_canShowAd()) return false;
    
    try {
      final placementId = customPlacementId ?? 
          (Platform.isAndroid ? _interstitialAndroid : _interstitialIOS);
      
      await UnityAds.load(placementId: placementId);
      
      bool adShown = false;
      
      await UnityAds.showVideoAd(
        placementId: placementId,
        onComplete: (placementId) {
          adShown = true;
          _sessionAdCount++;
          _lastAdTime = DateTime.now();
          print('✅ Interstitial ad completed: $placementId');
        },
        onFailed: (placementId, error, message) {
          print('❌ Interstitial ad failed: $error - $message');
        },
        onStart: (placementId) {
          adShown = true;
          print('🎬 Interstitial ad started: $placementId');
        },
      );
      
      return adShown;
    } catch (e) {
      print('❌ Interstitial ad error: $e');
      return false;
    }
  }
  
  /// Build banner ad widget - Currently not used in the app
  static Widget buildBannerAd([String? customPlacementId]) {
    // Return empty widget on desktop platforms
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const SizedBox.shrink();
    }
    
    // Note: Banner ads are available but not currently used in the app
    if (kDebugMode) {
      print('📊 Unity Ads: Banner ad requested but not currently used in app');
    }
    
    if (!_isInitialized) {
      // Initialize in background
      initialize();
      return const SizedBox.shrink();
    }
    
    final placementId = customPlacementId ?? 
        (Platform.isAndroid ? _bannerAndroid : _bannerIOS);
    
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        children: [
          // Advertisement label for transparency
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Text(
                'Advertisement',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Actual banner ad
          Expanded(
            child: UnityBannerAd(
              placementId: placementId,
              onLoad: (placementId) {
                print('✅ Banner ad loaded: $placementId');
              },
              onFailed: (placementId, error, message) {
                print('❌ Banner ad failed: $error - $message');
              },
              onClick: (placementId) {
                print('👆 Banner ad clicked: $placementId');
              },
            ),
          ),
        ],
      ),
    );
  }
  
  /// Check if ad can be shown based on frequency limits
  static bool _canShowAd() {
    // Respect session ad limits
    if (_sessionAdCount >= _maxAdsPerSession) {
      print('⚠️ Session ad limit reached: $_sessionAdCount/$_maxAdsPerSession');
      return false;
    }
    
    // Check time since last ad (minimum 30 seconds)
    final timeSinceLastAd = DateTime.now().difference(_lastAdTime);
    if (timeSinceLastAd.inSeconds < 30) {
      print('⚠️ Too soon since last ad: ${timeSinceLastAd.inSeconds}s');
      return false;
    }
    
    return true;
  }
  
  /// Reset session counter (call on app restart)
  static void resetSession() {
    _sessionAdCount = 0;
    print('🔄 Ad session reset');
  }
  
  /// Get current session ad count
  static int get sessionAdCount => _sessionAdCount;
  
  /// Check if ads are initialized
  static bool get isInitialized => _isInitialized;
  
  /// Show support mission dialog with rewarded video
  static Future<void> showSupportMissionDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.pink],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text('Support EduNest'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Watch a short ad to help us keep EduNest free for all students!',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This helps us cover server and development costs',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first
                
                // Add small delay to ensure smooth transition
                await Future.delayed(const Duration(milliseconds: 300));
                
                final success = await showRewardedVideo();
                
                // Ensure we're back to the app smoothly
                await Future.delayed(const Duration(milliseconds: 500));
                
                if (success && context.mounted) {
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Thank you for supporting EduNest! 💙'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                } else if (!success && context.mounted) {
                  // Show error message if ad failed
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Ad not available right now. Try again later!'),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Watch Ad'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
