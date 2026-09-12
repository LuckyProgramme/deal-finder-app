"""Normalize optional marketplace metadata without rejecting valid listings."""

from datetime import datetime, timezone
import math
from collections.abc import Mapping
from urllib.parse import urlsplit


def normalize_timestamp(value):
    if value is None or isinstance(value, bool):
        return None
    try:
        if isinstance(value, (int, float)) or str(value).isdigit():
            number = float(value)
            if not math.isfinite(number):
                return None
            if abs(number) >= 100_000_000_000:
                number /= 1000
            parsed = datetime.fromtimestamp(number, timezone.utc)
        else:
            parsed = datetime.fromisoformat(str(value).replace('Z', '+00:00'))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')
    except (TypeError, ValueError, OverflowError, OSError):
        return None


def _number(value, *, integer=False, maximum=None):
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(value)
        if not math.isfinite(number) or number < 0:
            return None
        if maximum is not None and number > maximum:
            return None
        if integer:
            return int(number) if number.is_integer() else None
        return number
    except (TypeError, ValueError, OverflowError):
        return None


def extract_metadata(card):
    seller = card.get('seller')
    seller = seller if isinstance(seller, Mapping) else {}
    below = card.get('belowFold')
    below = below if isinstance(below, Mapping) else {}
    photo = card.get('thumbnailUrl') or card.get('thumbnail_url')
    photos = card.get('photos')
    if not photo and isinstance(photos, list) and photos:
        photo = photos[0].get('url') if isinstance(photos[0], Mapping) else photos[0]
    if isinstance(photo, str) and photo.startswith('//'):
        photo = 'https:' + photo
    try:
        parsed = urlsplit(photo or '')
        if parsed.scheme not in ('https', 'http') or not parsed.hostname or parsed.username:
            photo = None
    except (ValueError, TypeError):
        photo = None
    locations = below.get('meetupLocations', card.get('meetupLocations', []))
    location = card.get('location')
    if isinstance(locations, list) and locations:
        location = '; '.join(str(p['name']).strip() for p in locations
                             if isinstance(p, Mapping) and p.get('name')) or None
    if not isinstance(location, str):
        location = None
    return {
        'thumbnail_url': photo,
        'seller_rating': _number(seller.get('rating', card.get('rating')), maximum=5),
        'seller_rating_count': _number(seller.get('ratingCount', card.get('ratingCount')), integer=True),
        'like_count': _number(card.get('likeCount'), integer=True),
        'location': location,
        'listing_timestamp': normalize_timestamp(card.get('timeCreated', card.get('listing_timestamp'))),
    }
