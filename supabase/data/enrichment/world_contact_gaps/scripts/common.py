"""Shared helpers for the world contact-gap pass (2026-11-04)."""
import re, unicodedata
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode
import phonenumbers

TRACKING = re.compile(r'^(utm_.*|gclid|fbclid|yclid|msclkid|y_source|scid|_ga|_gl|gad_source|gbraid|wbraid|srsltid|mc_cid|mc_eid|cmpid|cmp|seo_id|icid|mcid|src|source|ref|label|campaign|cid|partner|trackingid|iata|y_.*)$', re.I)
TRACKING_VALUE = re.compile(r'google|gmb|gbp|mybusiness|organic|localsearch|local_listing|yext', re.I)
# Never a website: booking, aggregator, guide, social, delivery, search
BLOCKED = ('opentable.', 'resy.com', 'exploretock.com', 'tock.com', 'sevenrooms.com', 'thefork.', 'lafourchette.', 'tabelog.com',
           'instagram.com', 'facebook.com', 'fb.com', 'linktr.ee', 'yelp.', 'tripadvisor.', 'booking.com', 'expedia.', 'hotels.com',
           'vio.com', 'google.', 'goo.gl', 'g.page', 'guide.michelin.com', 'ikyu.com', 'omakase.in', 'tablecheck.com', 'toreta.in',
           'autoreserve.com', 'gnavi.co.jp', 'hotpepper.jp', 'retty.me', 'line.me', 'lin.ee', 'weibo.com', 'dianping.com', 'meituan.com',
           'x.com', 'twitter.com', 'tiktok.com', 'youtube.com', 'agoda.', 'trip.com', 'ctrip.com', 'airbnb.', 'rakuten.co.jp', 'jalan.net',
           'yanolja.', 'catchtable.', 'chope.co', 'quandoo.', 'zenchef.', 'formitable.', 'covermanager.', 'resdiary.', 'bookatable.',
           'wa.me', 'whatsapp.com', 'linkin.bio', 'beacons.ai', 'carrd.co', 'business.site', 'inline.app', 'eztable.',
           'mr-gourmet', 'reserve.', 'reservations.', 'res.', 'secure.', 'be.synxis.com', 'synxis.com', 'mews.', 'simplebooking.',
           'ebica.jp', 'gourmet.yahoo', 'travel.rakuten', 'relux.jp', 'jtb.co.jp', 'rurubu', 'hitosara',
           'openrice.com', 'gorp.jp', 'myconciergejapan.net', 'tableall.com', 'pocket-concierge.jp', 'omakase.in', 'favy.jp', 'savorjapan', 'byfood.com', 'tablecheck.', 'restaurant.ikyu', 'ozmall.co.jp', 'yelp', 'zomato.', 'resengo.', 'bookings.', 'book.', 'booking.', 'ubereats.com', 'doordash', 'grubhub', 'deliveroo', 'foodpanda', 'eatigo', 'pinterest.', 'linkedin.', 'xiaohongshu')
SECOND_LEVEL = {'co', 'com', 'net', 'org', 'ne', 'or', 'ac', 'gr', 'go', 'ed', 'lg', 'gov', 'edu'}


def clean_url(u):
    if not u:
        return None
    s = urlsplit(u.strip())
    q = [(k, v) for k, v in parse_qsl(s.query, keep_blank_values=True) if not TRACKING.match(k) and not TRACKING_VALUE.search(v)]
    path = s.path or '/'
    return urlunsplit((s.scheme.lower(), s.netloc.lower(), path, urlencode(q), ''))


def host(u):
    h = urlsplit(u).netloc.lower().split('@')[-1].split(':')[0]
    return h[4:] if h.startswith('www.') else h


def reg_domain(u):
    p = host(u).split('.')
    if len(p) >= 3 and p[-2] in SECOND_LEVEL and len(p[-1]) == 2:
        return '.'.join(p[-3:])
    return '.'.join(p[-2:])


def blocked(u):
    """The blocked entry a URL hits, or None. 'x.' = a host label starting x.;
    'a.b' = that domain or a subdomain of it; 'a.b/' = a path on that domain;
    a plain word = anywhere in the host."""
    if re.search(r'%20|\s|https?://.*https?://', u):
        return 'malformed URL'
    h = host(u)
    hp = (h + urlsplit(u).path).lower()
    for b in BLOCKED:
        if b.endswith('/'):
            if b in hp:
                return b
        elif b.endswith('.'):
            if h.startswith(b) or ('.' + b) in h:
                return b
        elif '.' in b:
            if h == b or h.endswith('.' + b):
                return b
        elif b in h:
            return b
    return None


def fold(s):
    s = unicodedata.normalize('NFKC', s or '')
    s = unicodedata.normalize('NFKD', s)
    s = ''.join(c for c in s if not unicodedata.combining(c)).lower().replace('&amp;', '&').replace('&', ' and ')
    return re.sub(r'\s+', ' ', re.sub(r'[^\w]+', ' ', s)).strip()


def parse_phone(raw, cc):
    if not raw:
        return None
    try:
        n = phonenumbers.parse(raw.replace('.', ' '), cc)
    except phonenumbers.NumberParseException:
        return None
    return n if phonenumbers.is_possible_number(n) else None


def e164(n):
    return phonenumbers.format_number(n, phonenumbers.PhoneNumberFormat.E164) if n else None


def intl(n):
    return phonenumbers.format_number(n, phonenumbers.PhoneNumberFormat.INTERNATIONAL) if n else None


PHONE_RE = re.compile(r'(?:\+|＋|tel:)?[\d０-９(（][\d０-９\s().（）\-‐－―ー/]{5,22}[\d０-９]')


def phones_in(text, cc):
    """Every E.164 number written in a page (tel: links and phone-like strings)."""
    out = set()
    text = unicodedata.normalize('NFKC', text or '')
    for m in PHONE_RE.finditer(text):
        s = m.group(0).replace('tel:', '')
        d = re.sub(r'\D', '', s)
        if len(d) < 7 or len(d) > 15:
            continue
        for cand in (s, '+' + d) if not s.startswith('+') else (s,):
            try:
                n = phonenumbers.parse(cand, cc)
            except phonenumbers.NumberParseException:
                continue
            if phonenumbers.is_valid_number(n):
                out.add(e164(n))
    return out
