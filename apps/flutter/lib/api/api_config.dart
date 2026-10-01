/// Explicit demo builds remain available. Configured endpoints
/// always use the backend; network failures never fall back to demo data.
class ApiConfig {
  const ApiConfig._(this.baseUri);
  final Uri baseUri;

  factory ApiConfig(String url) {
    final uri = Uri.parse(url);
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError.value(url, 'url', 'Expected an HTTP(S) API origin');
    }
    const localHosts = {'localhost', '127.0.0.1', '::1', '10.0.2.2'};
    if (uri.scheme == 'http' && !localHosts.contains(uri.host)) {
      throw ArgumentError('Remote API endpoints must use HTTPS');
    }
    return ApiConfig._(uri.replace(path: '/'));
  }

  static ApiConfig? fromEnvironment() {
    if (const bool.fromEnvironment('CAMEO_DEMO_MODE')) return null;
    const value = String.fromEnvironment(
      'CAMEO_API_BASE_URL',
      defaultValue: 'https://api.cameo.deltalab.dev',
    );
    return value.isEmpty ? null : ApiConfig(value);
  }
}
