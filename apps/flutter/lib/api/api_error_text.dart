import '../content/app.g.dart';
import 'cameo_api.dart';

String apiErrorText(Object error) =>
    apiErrorCodeText(error is ApiException ? error.code : 'internal_error');

String apiErrorCodeText(String code) {
  final copy = appContent.v6.backend;
  return switch (code) {
    'network_unavailable' || 'network_timeout' => copy.networkError,
    'rate_limit' => copy.rateLimit,
    'unauthenticated' => copy.expired,
    'couple:code_not_found' => copy.codeNotFound,
    'couple:self' => copy.selfCode,
    'couple:already_connected' => copy.alreadyConnected,
    'couple:partner_unavailable' => copy.partnerUnavailable,
    'invalid_request' => copy.invalidRequest,
    _ => copy.genericError,
  };
}
