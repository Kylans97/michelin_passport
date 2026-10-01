/// The one correct way to build a `mailto:` URI in this app.
///
/// RFC 6068 (the mailto spec) wants RFC 3986 percent-encoding for its
/// query — spaces become `%20`. `Uri(..., queryParameters: {...})`
/// doesn't give you that: a `queryParameters` Map always encodes through
/// `Uri.encodeQueryComponent`, which is `application/x-www-form-encoded`
/// — spaces become `+`, a form-encoding convention, not every mail
/// client decodes back to a space. [Uri.encodeComponent] (used here) is
/// the correct one.
///
/// Every mailto link in this app must build through this function, not
/// its own `Uri(...)` call — the point of having exactly one of these is
/// that the fix above lives in one place, not re-derived (or silently
/// gotten wrong again) by hand at each new call site.
Uri mailtoUri(String email, {required String subject}) {
  final encodedSubject = Uri.encodeComponent(subject);
  return Uri(scheme: 'mailto', path: email, query: 'subject=$encodedSubject');
}
