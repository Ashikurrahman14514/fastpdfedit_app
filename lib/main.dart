import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'file edit tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({Key? key}) : super(key: key);

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late InAppWebViewController _controller;
  InterstitialAd? _interstitialAd;
  final String _adUnitId = 'ca-app-pub-1540095617189773/8531761941';

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
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

  Future<bool> _showExitDialog(BuildContext context) async {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          debugPrint('$ad onAdDismissedFullScreenContent');
          ad.dispose();
          _interstitialAd = null;
          _showExitConfirmation(context);
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          debugPrint('$ad onAdFailedToShowFullScreenContent: $error');
          ad.dispose();
          _interstitialAd = null;
          _showExitConfirmation(context);
        },
      );
      _interstitialAd!.show();
      return false;
    } else {
      return await _showExitConfirmation(context);
    }
  }

  Future<bool> _showExitConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to exit?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }

        final bool canGoBack = await _controller.canGoBack();
        if (canGoBack) {
          await _controller.goBack();
        } else {
          final bool shouldExit = await _showExitDialog(context);
          if (shouldExit) {
            await SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
<<<<<<< HEAD
        body: WebViewWidget(controller: _controller),
=======
        appBar: AppBar(
          title: const Text(
            'file edit tool',
            style: TextStyle(color: Colors.white),
          ),
          toolbarHeight: 4.0,
        ),
        body: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri('https://www.fastpdfedit.com')),
          initialSettings: InAppWebViewSettings(
            allowsInlineMediaPlayback: true,
            javaScriptEnabled: true,
            transparentBackground: true,
          ),
           onWebViewCreated: (controller) {
            _controller = controller;
          },
          onProgressChanged: (controller, progress) {
            debugPrint('WebView loading: $progress%');
          },
          onLoadStart: (controller, url) {
            debugPrint('Page started: $url');
          },
          onLoadStop: (controller, url) {
            debugPrint('Page finished: $url');
          },
           onReceivedError: (controller, request, error) {
             debugPrint('''
Page resource error:
  description: ${error.description}
            ''');
          },
        ),
>>>>>>> edit
      ),
    );
  }
}
