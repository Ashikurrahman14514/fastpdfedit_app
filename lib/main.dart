import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart'; // For launching external URLs if needed
import 'package:device_info_plus/device_info_plus.dart'; // Added for checking Android SDK version

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
  final Dio _dio = Dio();

  String _getExtensionFromMimeType(String mimeType) {
    switch (mimeType.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/gif':
        return 'gif';
      case 'application/pdf':
        return 'pdf';
      case 'text/plain':
        return 'txt';
      // Add more common types as needed
      default:
        // Try to get from the last part of the mime type if it contains a recognizable extension
        final parts = mimeType.split('/');
        if (parts.length > 1 && parts.last.length < 5 && parts.last.isNotEmpty) { // Basic heuristic
          return parts.last;
        }
        return 'bin'; // Default to binary if unknown
    }
  }

  Future<void> _downloadFile(DownloadStartRequest downloadStartRequest) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context); // Capture ScaffoldMessenger
    if (!mounted) return; // Ensure widget is still mounted

    // Re-applying logic to request MANAGE_EXTERNAL_STORAGE on Android 11+
    PermissionStatus status;
    if (Platform.isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 30) { // Android 11 (API level 30) and above
        // Request MANAGE_EXTERNAL_STORAGE for Android 11+
        status = await Permission.manageExternalStorage.request();
        // Optional: Fallback to Permission.storage if MANAGE is denied, though less likely to work if MANAGE failed.
        // We'll keep the original fallback logic for now.
        if (status.isDenied && mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Manage external storage permission denied, trying standard storage permission...')),
            );
            await Future.delayed(const Duration(seconds: 2)); // Give user time to read
            status = await Permission.storage.request();
        }
      } else {
        // For older Android versions (below 11 / API 30)
        status = await Permission.storage.request();
      }
    } else {
      // For iOS or other platforms
      status = await Permission.storage.request();
    }


    if (status.isGranted) {
      // Permission granted, proceed with download logic
    } else if (status.isPermanentlyDenied) {
      // User has permanently denied the permission. Guide them to settings.
      if (mounted) { // Check if widget is still in the tree
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Storage permission permanently denied. Please enable it in app settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }
      return; // Stop the download process
    } else {
      // Handle other non-granted statuses (denied, restricted, limited)
      // For .isDenied, user denied the prompt but can be asked again.
      // For .isRestricted, OS restricts access (e.g. parental controls).
      // For .isLimited (iOS specific for photos), some access granted.
      if (mounted) { // Check if widget is still in the tree
         scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Storage permission is required to download files. Please grant the permission.')),
        );
      }
      return; // Stop the download process
    }

    // If we reach here, permission is granted.
    Directory? downloadsDir;
    String filePath = ''; // Will be set by either data URI or dio logic

    // Common logic to get downloads directory
    if (Platform.isAndroid) {
      // Alternative way to get Downloads directory path on Android
      final Directory? extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final String downloadsPath = '${extDir.path}/Download';
        downloadsDir = Directory(downloadsPath);
        // Ensure the directory exists
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }
      }
    } else if (Platform.isIOS) {
      downloadsDir = await getApplicationDocumentsDirectory(); // iOS typical downloads location
    }

    if (downloadsDir == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Could not determine downloads directory.')),
      );
      return;
    }

    String fileName = downloadStartRequest.suggestedFilename ?? Uri.decodeFull(downloadStartRequest.url.pathSegments.last);
    if (fileName.isEmpty) {
      fileName = "downloaded_file"; // Fallback filename
    }
    // Sanitize filename if necessary, though dio and OS usually handle it
    // final String filePath = '${downloadsDir.path}/$fileName'; // Moved filePath initialization

    final Uri uri = downloadStartRequest.url;

    if (uri.scheme == 'data') {
      // Handle data URI
      final UriData? data = UriData.fromUri(uri);
      if (data != null) {
        final Uint8List fileBytes = data.contentAsBytes();
        String mimeType = data.mimeType;
        String fileExtension = _getExtensionFromMimeType(mimeType);

        fileName = downloadStartRequest.suggestedFilename ?? 'downloaded_file_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        if (downloadsDir == null) { // Should have been caught earlier, but double check
             if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Could not determine downloads directory.')));
            return;
        }
        filePath = '${downloadsDir.path}/$fileName';

        try {
          final file = File(filePath);
          await file.writeAsBytes(fileBytes);
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Downloaded $fileName successfully!'),
                action: SnackBarAction(
                  label: 'OPEN',
                  onPressed: () {
                    OpenFilex.open(filePath);
                  },
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Data URI Save error: $e');
          if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to save $fileName: $e')));
        }
      } else {
        if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Failed to parse data URL.')));
      }
      return; // Data URI handling finished
    } else {
      // Handle HTTP/HTTPS URLs with Dio
      if (downloadsDir == null) { // Should have been caught earlier
          if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Could not determine downloads directory.')));
          return;
      }
      fileName = downloadStartRequest.suggestedFilename ?? Uri.decodeFull(uri.pathSegments.last);
      if (fileName.isEmpty) {
        fileName = "downloaded_file_${DateTime.now().millisecondsSinceEpoch}.bin"; // Fallback for http if no name
      }
      filePath = '${downloadsDir.path}/$fileName';

      try {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Downloading $fileName...')),
          );
        }

        await _dio.download(
          uri.toString(),
          filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              debugPrint('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
            }
          },
        );
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Downloaded $fileName successfully!'),
              action: SnackBarAction(
                label: 'OPEN',
                onPressed: () {
                  OpenFilex.open(filePath);
                },
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Download error: $e');
        if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text('Failed to download $fileName: $e')));
      }
    }
    // Faulty comment block removed, ensuring method and class are properly closed.
  }

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

  Future<bool> _showExitConfirmation(BuildContext dialogContext) async {
    // Use dialogContext to avoid using 'context' from the broader widget if it might be unmounted
    if (!dialogContext.mounted) return false;
    return await showDialog<bool>(
      context: dialogContext,
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
          onDownloadStartRequest: (controller, downloadStartRequest) async {
            debugPrint("onDownloadStartRequest: ${downloadStartRequest.url}");
            // Ask user if they want to download the file
            // You can use a dialog for this
            final bool? shouldDownload = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Download File?'),
                content: Text(
                    'Do you want to download ${downloadStartRequest.suggestedFilename ?? downloadStartRequest.url.pathSegments.last}?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Download'),
                  ),
                ],
              ),
            );

            if (shouldDownload == true) {
              _downloadFile(downloadStartRequest);
            }
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
          // Add this to handle external links that are not downloads
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            var uri = navigationAction.request.url!;
            if (!["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
              if (await canLaunchUrl(uri)) {
                // Launch the App
                await launchUrl(uri);
                // and cancel the request
                return NavigationActionPolicy.CANCEL;
              }
            }
            return NavigationActionPolicy.ALLOW;
          },
        ),
>>>>>>> edit
      ),
    );
  }
}
