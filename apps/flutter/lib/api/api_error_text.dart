import '../content/app.g.dart';
import 'cameo_api.dart';

String apiErrorText(Object error) => apiErrorCodeText(
  error is ApiException
      ? error.code == 'purchase:required' && error.meta['required'] == 'restore'
            ? 'recovery_credit_required'
            : error.code
      : 'internal_error',
);

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
    'couple:not_connected' => copy.notConnected,
    'photo_too_large' => copy.photoTooLarge,
    'photo_unsupported' => copy.photoUnsupported,
    'upload_failed' || 'photo:upload_incomplete' => copy.uploadFailed,
    'video_unavailable' => copy.videoUnavailable,
    'camera_unavailable' => copy.cameraUnavailable,
    'call:busy' => copy.callBusy,
    'call:invalid_state' => copy.callInvalidState,
    'microphone_required' => copy.microphoneRequired,
    'playback_failed' => copy.playbackFailed,
    'billing_unconfigured' ||
    'billing_test_release' ||
    'billing_test_store_required' => copy.billingPreparing,
    'billing_product_unavailable' => copy.billingProductUnavailable,
    'billing_verification_failed' => copy.billingVerificationFailed,
    'billing_pending' => copy.billingPending,
    'billing_nothing_to_restore' => copy.billingNothingToRestore,
    'billing_unavailable' => copy.billingError,
    'billing_server_pending' => copy.billingServerPending,
    'billing_server_unavailable' => copy.billingServerUnavailable,
    'purchase:required' => copy.premiumRequired,
    'recovery_credit_required' => copy.recoveryCreditRequired,
    'recovery_context_changed' => copy.recoveryContextChanged,
    _ => copy.genericError,
  };
}
