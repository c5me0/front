// Notification preferences backed by the current session. Listen during build and use
// non-listening reads inside callbacks.

//

//   IosSwitch(value: prefs.callAlerts, onChanged: prefs.setCallAlerts)
import 'package:flutter/widgets.dart';

import 'session.dart';

@immutable
class NotificationPrefs {
  const NotificationPrefs._(
    this._session, {
    required this.callAlerts,
    required this.highlightAlerts,
  });

  factory NotificationPrefs.of(BuildContext context) =>
      NotificationPrefs.from(SessionScope.of(context));

  factory NotificationPrefs.from(SessionController session) {
    final prefs = session.session.prefs;
    return NotificationPrefs._(
      session,
      callAlerts: prefs.callAlerts,
      highlightAlerts: prefs.highlightAlerts,
    );
  }

  final SessionController _session;

  final bool callAlerts;

  final bool highlightAlerts;

  void setCallAlerts(bool value) =>
      _session.setPref(SessionPref.callAlerts, value);

  void setHighlightAlerts(bool value) =>
      _session.setPref(SessionPref.highlightAlerts, value);
}
