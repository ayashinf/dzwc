import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

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
  InAppWebViewController? _c;
  bool _failed = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    [Permission.locationWhenInUse, Permission.camera].request();
  }

  @override
  Widget build(BuildContext context) {
    final host = Uri.parse(siteUrl).host;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_c != null && await _c!.canGoBack()) {
          _c!.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(siteUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                geolocationEnabled: true,
                useShouldOverrideUrlLoading: true,
              ),
              onWebViewCreated: (c) => _c = c,
              onProgressChanged: (c, p) => setState(() => _progress = p / 100),
              onLoadStop: (c, u) => setState(() => _failed = false),
              onReceivedError: (c, req, err) {
                if (req.isForMainFrame ?? true) setState(() => _failed = true);
              },
              onGeolocationPermissionsShowPrompt: (c, origin) async =>
                  GeolocationPermissionShowPromptResponse(
                      origin: origin, allow: true, retain: true),
              onPermissionRequest: (c, req) async => PermissionResponse(
                  resources: req.resources,
                  action: PermissionResponseAction.GRANT),
              shouldOverrideUrlLoading: (c, action) async {
                final uri = action.request.url;
                if (uri == null) return NavigationActionPolicy.ALLOW;
                if (uri.host == host ||
                    uri.scheme == 'about' ||
                    uri.scheme == 'data' ||
                    uri.scheme == 'blob') {
                  return NavigationActionPolicy.ALLOW;
                }
                await launchUrl(Uri.parse(uri.toString()),
                    mode: LaunchMode.externalApplication);
                return NavigationActionPolicy.CANCEL;
              },
            ),
            if (_progress < 1) LinearProgressIndicator(value: _progress),
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
                          _c?.reload();
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
