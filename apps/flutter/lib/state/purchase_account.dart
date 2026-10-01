import '../api/api_models.dart';

/// The authenticated backend is authoritative for shared membership and credits.
abstract interface class PurchaseAccount {
  String? get userId;
  ApiPremium? get premium;
  int get restoreCredits;
  ApiCouple? get remoteCouple;
  Future<ApiUser> syncPurchases();
  Future<ApiCouple?> refreshCouple();
  Future<ApiRestorable> restoreCouple(String expectedCoupleId);
}
