/// What to do with a page a WebView wants to open.
enum ArmorNavigation {
  /// Load it in the WebView.
  allow,

  /// Don't load it; open it in the system browser / mail / phone app.
  openExternally,

  /// Don't load it at all.
  block,
}

/// Helpers for opening links safely.
class SafeUrls {
  SafeUrls._();

  /// [url] as an HTTPS address: `http://` is upgraded and a missing scheme
  /// gets `https://`. Null when it is not a web address (e.g.
  /// `javascript:`, `file:`, `intent:`).
  static Uri? https(String url) {
    String value = url.trim();
    if (value.isEmpty) return null;
    // A scheme is letters then ":", not a port like "example.com:8080".
    final RegExpMatch? scheme =
        RegExp(r'^([a-z][a-z0-9+.-]*):(?!\d)', caseSensitive: false)
            .firstMatch(value);
    switch (scheme?.group(1)?.toLowerCase()) {
      case null:
        value = 'https://$value';
      case 'http':
        value = 'https${value.substring(4)}';
      case 'https':
        break;
      default:
        return null;
    }
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  /// Whether [url] is an HTTPS address with a host.
  static bool isHttps(String url) {
    final Uri? uri = Uri.tryParse(url.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}

/// Keeps an in-app WebView on your own sites.
///
/// The page may only move to [allowedHosts] (and their subdomains) over
/// HTTPS. Other `https`, `mailto` and `tel` links should open outside the
/// app, so a link in a chat or ad can't load a look-alike login page inside
/// it. Anything else is blocked.
///
/// With webview_flutter:
/// ```dart
/// final policy = ArmorWebViewPolicy(allowedHosts: ['support.example.com']);
/// NavigationDelegate(onNavigationRequest: (r) {
///   switch (policy.decide(r.url, isMainFrame: r.isMainFrame)) {
///     case ArmorNavigation.allow: return NavigationDecision.navigate;
///     case ArmorNavigation.openExternally: launchUrl(Uri.parse(r.url));
///     case ArmorNavigation.block: break;
///   }
///   return NavigationDecision.prevent;
/// });
/// ```
class ArmorWebViewPolicy {
  ArmorWebViewPolicy({
    required Iterable<String> allowedHosts,
    this.allowSubdomains = true,
    this.externalSchemes = const {'https', 'mailto', 'tel'},
  }) : allowedHosts = allowedHosts.map((h) => h.toLowerCase()).toSet();

  /// Allows [url]'s registrable domain, e.g. `https://help.example.com`
  /// allows `example.com` and its subdomains.
  factory ArmorWebViewPolicy.forSite(String url) {
    final String host = Uri.tryParse(url)?.host ?? '';
    final List<String> labels = host.split('.');
    final String domain =
        labels.length < 2 ? host : labels.sublist(labels.length - 2).join('.');
    return ArmorWebViewPolicy(allowedHosts: [if (domain.isNotEmpty) domain]);
  }

  final Set<String> allowedHosts;
  final bool allowSubdomains;
  final Set<String> externalSchemes;

  bool isAllowed(Uri uri) {
    if (uri.scheme == 'about') return true;
    if (uri.scheme != 'https') return false;
    final String host = uri.host.toLowerCase();
    return allowedHosts.any((allowed) =>
        host == allowed || (allowSubdomains && host.endsWith('.$allowed')));
  }

  /// Frames inside the page (chat widgets, embeds) are allowed; only moving
  /// the whole page is checked.
  ArmorNavigation decide(String url, {bool isMainFrame = true}) {
    if (!isMainFrame) return ArmorNavigation.allow;
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return ArmorNavigation.block;
    if (isAllowed(uri)) return ArmorNavigation.allow;
    if (externalSchemes.contains(uri.scheme)) {
      return ArmorNavigation.openExternally;
    }
    return ArmorNavigation.block;
  }
}
