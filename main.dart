import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// غيّر هذا الرابط إلى رابط مجلد toilets على موقعك (وينتهي بشرطة مائلة /)
const String siteUrl = 'https://contact.is-best.net/toilets/';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: 'مراحيض الجزائر',
    debugShowCheckedModeBanner: false,
    home: WebShell(),
  ));
}

class WebShell extends StatefulWidget {
  const WebShell({super.key});
  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController _c;
  bool _failed = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    [Permission.locationWhenInUse, Permission.camera].request();

    final host = Uri.parse(siteUrl).host;
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p),
        onPageStarted: (_) => setState(() => _failed = false),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) setState(() => _failed = true);
        },
        onNavigationRequest: (req) {
          final uri = Uri.parse(req.url);
          if (uri.host == host ||
              uri.scheme == 'about' ||
              uri.scheme == 'data' ||
              uri.scheme == 'blob') {
            return NavigationDecision.navigate;
          }
          launchUrl(uri, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(siteUrl));

    final platform = _c.platform;
    if (platform is AndroidWebViewController) {
      platform.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: (request) async =>
            const GeolocationPermissionsResponse(allow: true, retain: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _c.canGoBack()) {
          _c.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(children: [
            WebViewWidget(controller: _c),
            if (_progress < 100)
              LinearProgressIndicator(value: _progress / 100),
            if (_failed)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('تعذّر الاتصال بالموقع',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _failed = false);
                          _c.loadRequest(Uri.parse(siteUrl));
                        },
                        child: const Text('إعادة المحاولة'),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
