// What the app does, for /app and the home page's "In the app" band.
// Each line is checked against docs/Plannnig/CHANGELOG.md (up to 1.7.1).
// No dashes in the copy (product owner: they read as machine written).

export interface AppFeature { kicker: string; title: string; text: string; }

export const APP_FEATURES: AppFeature[] = [
  {
    kicker: 'Events',
    title: 'Evenings that happen once',
    text: 'Four hands dinners, guest chefs, winemaker dinners, galas and festivals. Follow the venues you love, hear when they announce something, and see which friends are going.',
  },
  {
    kicker: 'Discover',
    title: 'Every guide in one place',
    text: "MICHELIN stars and Keys, The World's 50 Best, Gault&Millau, Guía Repsol and our own Mantelier Selection, side by side. With private chefs, luxury trains, small ships and The World's 50 Best Vineyards.",
  },
  {
    kicker: 'Wine',
    title: 'Wine regions on the globe',
    text: 'Tap a region to see its grapes and what they become there. Handed a wine list? Search a region, an appellation or a grape and find out where it comes from.',
  },
  {
    kicker: 'Plan',
    title: 'Save places for later',
    text: 'Restaurants, hotels, events, wine estates, trains and ships, gathered by where they are. Choose the month you would like to go, get a reminder the day before bookings open, and plan the trip with friends on one map.',
  },
  {
    kicker: 'Passport',
    title: 'Keep every evening',
    text: 'Every dinner, stay, journey and estate visit becomes a stamp, with your scores, notes, photos and the wines you drank. A stamp from an event comes only once you have actually been there.',
  },
  {
    kicker: 'Friends',
    title: 'Share only what you want',
    text: 'See where friends have been and what they are planning, and invite them to dinner. You decide what they see.',
  },
];
