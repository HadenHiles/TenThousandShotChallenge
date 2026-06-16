/// Simple global flag to indicate whether RevenueCat Purchases SDK
/// has been successfully configured for this app session.
class RevenueCatConfig {
  static bool configured = false;

  /// True while configure() is in progress — prevents concurrent calls from
  /// both passing the `configured == false` check before either completes.
  static bool configuring = false;

  /// The RevenueCat entitlement identifier for Pro access.
  /// Must match the entitlement identifier in your RevenueCat dashboard.
  static const String proEntitlementIdentifier = 'pro_access';

  /// The RevenueCat offering identifier for the "Pro Access Paywall" offering.
  /// Must match the offering identifier in your RevenueCat dashboard.
  static const String proOfferingIdentifier = 'pro_subscription';
}
