#!/bin/bash
# $1=nl|be $2=base url
c=$1; base=$2; p=1
while [ $p -le 80 ]; do
  f=dl_$c/list_p$p.html
  curl -sL -A "Mozilla/5.0" -o $f "$base?order=score&page=$p"
  n=$(grep -c 'class="place position-relative"' $f)
  echo "$c page $p: $n"
  [ "$n" = "0" ] && break
  p=$((p+1)); sleep 1
done
