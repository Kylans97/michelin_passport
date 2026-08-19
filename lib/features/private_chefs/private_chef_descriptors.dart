import '../../models/private_chef.dart';

/// Up to 3 quiet editorial descriptors for a chef's discovery card (Step
/// 2C §11) — deterministically derived from fields [PrivateChef] already
/// has a true/false answer for, never a marketplace filter taxonomy and
/// never invented per-chef. 'PRIVATE DINING' is the one always-shown
/// domain descriptor (every chef in this catalogue offers it, by
/// definition of the catalogue itself); the other two are strictly
/// conditional on the chef's own data. Deliberately doesn't grow a
/// speculative taxonomy (tasting menus, seasonal, local produce, ...)
/// beyond what today's schema can honestly claim about a chef — see
/// PRIVATE_CHEFS.md's Step 2C section.
List<String> chefDescriptors(PrivateChef chef) => [
  'PRIVATE DINING',
  if (chef.winePairingAvailable) 'WINE PAIRING',
  if (chef.travelAvailable) 'TRAVELS',
];
