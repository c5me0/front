import '../content/app.g.dart';
import 'cameo_api.dart';

String apiErrorText(Object error, {AppContent copy = appContent}) =>
    apiErrorCodeText(
      error is ApiException
          ? error.code == 'purchase:required' &&
                    error.meta['required'] == 'restore'
                ? 'recovery_credit_required'
                : error.code
          : 'internal_error',
      copy: copy,
    );

String apiErrorCodeText(String code, {AppContent copy = appContent}) {
  final messages = copy.v6.backend;
  return switch (code) {
    'network_unavailable' || 'network_timeout' => messages.networkError,
    'rate_limit' => messages.rateLimit,
    'unauthenticated' => messages.expired,
    'couple:code_not_found' => messages.codeNotFound,
    'couple:self' => messages.selfCode,
    'couple:already_connected' => messages.alreadyConnected,
    'couple:partner_unavailable' => messages.partnerUnavailable,
    'invalid_request' => messages.invalidRequest,
    'couple:not_connected' => messages.notConnected,
    'photo_too_large' => messages.photoTooLarge,
    'photo_unsupported' => messages.photoUnsupported,
    'upload_failed' || 'photo:upload_incomplete' => messages.uploadFailed,
    'video_unavailable' => messages.videoUnavailable,
    'camera_unavailable' => messages.cameraUnavailable,
    'call:busy' => messages.callBusy,
    'call:invalid_state' => messages.callInvalidState,
    'microphone_required' => messages.microphoneRequired,
    'playback_failed' => messages.playbackFailed,
    'billing_unconfigured' ||
    'billing_test_release' ||
    'billing_test_store_required' => messages.billingPreparing,
    'billing_product_unavailable' => messages.billingProductUnavailable,
    'billing_verification_failed' => messages.billingVerificationFailed,
    'billing_pending' => messages.billingPending,
    'billing_nothing_to_restore' => messages.billingNothingToRestore,
    'billing_unavailable' => messages.billingError,
    'billing_server_pending' => messages.billingServerPending,
    'billing_server_unavailable' => messages.billingServerUnavailable,
    'purchase:required' => messages.premiumRequired,
    'recovery_credit_required' => messages.recoveryCreditRequired,
    'recovery_context_changed' => messages.recoveryContextChanged,
    _ => messages.genericError,
  };
}
