import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemNavigator
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FastPDFEdit Browser',
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
  }

  // Function to show the exit confirmation dialog
  Future<bool> _showExitDialog(BuildContext context) async {
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
          // If WebView cannot go back, show the exit confirmation dialog
          final bool shouldExit = await _showExitDialog(context);
          if (shouldExit) {
            // If user confirms exit, close the app
            await SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
