import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemNavigator
import 'package:webview_flutter/webview_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'file edit tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // Recommended for modern dialogs
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  InterstitialAd? _interstitialAd;
  final String _adUnitId = 'ca-app-pub-1540095617189773/8531761941'; // Your Ad Unit ID

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) => debugPrint('WebView loading: $progress%'),
          onPageStarted: (String url) => debugPrint('Page started: $url'),
          onPageFinished: (String url) => debugPrint('Page finished: $url'),
          onWebResourceError: (WebResourceError error) => debugPrint('''
Page resource error:
  code: ${error.errorCode}
  description: ${error.description}
  errorType: ${error.errorType}
  isForMainFrame: ${error.isForMainFrame}
          '''),
          onNavigationRequest: (NavigationRequest request) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse('https://www.fastpdfedit.com'));

    _loadInterstitialAd(); // Load ad when the screen initializes
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          debugPrint('$ad loaded.');
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (AdError error) {
          debugPrint('InterstitialAd failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  // Function to show the exit confirmation dialog
  Future<bool> _showExitDialog(BuildContext context) async {
    // Show the ad if loaded before showing the exit dialog
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          debugPrint('$ad onAdDismissedFullScreenContent');
          ad.dispose();
          _interstitialAd = null;
          // After ad is dismissed, show the exit dialog
          _showExitConfirmation(context);
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          debugPrint('$ad onAdFailedToShowFullScreenContent: $error');
          ad.dispose();
          _interstitialAd = null;
          // If ad fails to show, show the exit dialog
          _showExitConfirmation(context);
        },
      );
      _interstitialAd!.show();
      return false; // Prevent immediate exit, wait for ad callback
    } else {
      // If ad is not loaded, show the exit dialog directly
      return await _showExitConfirmation(context);
    }
  }

  // Function to show the actual exit confirmation dialog
  Future<bool> _showExitConfirmation(BuildContext context) async {
     return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Are you sure you want to exit?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // Stay in app
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // Allow exit
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false; // Return false if dialog is dismissed
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use PopScope to intercept back button presses
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        // If didPop is true, it means the pop was already handled elsewhere (e.g., dialog closed)
        if (didPop) {
          return;
        }

        // Check if the WebView can go back
        final bool canGoBack = await _controller.canGoBack();
        if (canGoBack) {
          // If WebView can go back, navigate back within the WebView
          await _controller.goBack();
        } else {
          // If WebView cannot go back, show the exit confirmation dialog (which now handles showing the ad)
          final bool shouldExit = await _showExitDialog(context);
          if (shouldExit) {
            // If user confirms exit after the ad (or if ad wasn't shown), close the app
            await SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'file edit tool',
            style: TextStyle(color: Colors.white),
          ),
          toolbarHeight: 4.0,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
