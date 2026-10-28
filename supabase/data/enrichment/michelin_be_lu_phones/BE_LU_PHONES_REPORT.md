# Phone numbers: MICHELIN-starred restaurants in Belgium and Luxembourg (2026-10-28)

Status: **PREPARED, NOT APPLIED.**

## Scope

The input is a production export, run by the user on 2026-10-28, of every BE
and LU restaurant with `michelin_stars` set and `phone` null: 132 rows (120 BE,
12 LU), all `open`.

## Result

| | Count |
|---|---|
| Confirmed, in `prepared_be_lu_phone_backfill.sql` | 117 (107 BE, 10 LU) |
| Unclear, left out | 11 |
| Not found | 4 |

The per-row evidence is in `be_lu_phones_all.csv`: the number as printed, the
line type, the official site and the source URL.

Every confirmed number comes from the restaurant's own website. Each was checked
against name, city and address, and against the restaurant's MICHELIN page
wherever that page loaded. The only mismatch was Vivendum, where the site's
number was used.

## Left out

- **Possibly closed, renamed or delisted (QA-212).** Ralf Berendsen (now
  "La Source" at La Butte aux Bois), La Table de Manon, La Durée, Kommilfoo,
  Mémoire, Table d'Amis (now "Chambres d'Amis"). Settle these in the Belgian
  star update; they are not phone questions.
- **Switchboard only.** Grünewald Chef's Table, Aurum, Le Roannay, Arden and
  Fields by René Mathieu.
- **MICHELIN only.** Eliane, Bloesem, L'Envie and Le Cor de Chasse. Their own
  sites list no phone, do not exist, or could not be loaded.

## Also found

These were logged, not fixed:

- QA-213: Aurum's chef change, and La Table de Maxime's announced closure by
  March 2027.
- QA-214: five moves (La Paix, 't Fornuis, The Jane, La Table-Lasne, Bistro
  Racine).

Official websites were found for almost every row. They are in
`official_website`, ready for a separate website backfill.

## Wrong-record traps hit (all rejected)

In each case the restaurant's site is a different domain:

- kelderman.be is a food company.
- kamo.be is a stone supplier.
- bloesem.be is a nursing practice.
- depastorie.be is a work project.
- kommilfoo.be is a cabaret duo.
- moscou.be, demijlpaal.be, mijlpaal.be and restaurantneon.com are for sale.
- altermezzo.be is a placeholder.
- aurum.be is a property developer.

Several sites also print a sister venue's number or a taxi partner's number.
Only the restaurant's own line was taken.

## Testing

The file has the same structure as the World's 50 Best phone backfill, which was
tested on a scratch database; this one was not run separately. It fills empty
values only, and aborts on an unknown code or a country mismatch.
