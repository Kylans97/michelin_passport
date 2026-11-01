#!/bin/bash
c=$1
python3 -I -c "import json;[print(json.loads(l)['url']) for l in open('gm_list_$c.jsonl')]" | while read u; do
  slug=${u##*/}; f=prof_$c/$slug.html
  [ -s "$f" ] && continue
  curl -sL -A "Mozilla/5.0" -o "$f" "$u"; sleep 0.4
done
echo done $c $(ls prof_$c | wc -l)
