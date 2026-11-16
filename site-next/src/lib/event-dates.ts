// Event dates as the app writes them (event_date_format.dart). No imports,
// so the signed-in pages can use it in the browser too.

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
export const MONTHS_LONG = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const parts = (d: string) => d.split('-').map(Number) as [number, number, number];

/** formatEventDateRange: "27 Aug 2026", "27–30 Aug 2026", "30 Aug – 2 Sep 2026". */
export function formatDateRange(e: { startDate: string; endDate: string }): string {
  const [sy, sm, sd] = parts(e.startDate);
  const [ey, em, ed] = parts(e.endDate);
  if (sy === ey && sm === em && sd === ed) return `${sd} ${MONTHS[sm - 1]} ${sy}`;
  if (sy === ey && sm === em) return `${sd}–${ed} ${MONTHS[sm - 1]} ${sy}`;
  if (sy === ey) return `${sd} ${MONTHS[sm - 1]} – ${ed} ${MONTHS[em - 1]} ${sy}`;
  return `${sd} ${MONTHS[sm - 1]} ${sy} – ${ed} ${MONTHS[em - 1]} ${ey}`;
}

