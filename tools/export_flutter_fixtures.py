"""Generate deterministic, synthetic parity fixtures from the Python oracle.

Run from the repository root: uv run python tools/export_flutter_fixtures.py
Only the checked-in synthetic benchmark is read; no credentials or live data.
"""
import hashlib
import json
from pathlib import Path
import subprocess

from rapidfuzz import fuzz
from offline_oracle import isolated_oracle_imports, network_disabled

with isolated_oracle_imports():
    from deal_finder.candidate_filter import find_candidate_matches, compute_lexical_recall_score
    from deal_finder.models import PriceListTarget
    from deal_finder.sheets_handler import DEFAULT_PRICE_LIST_ROWS, PRICE_LIST_HEADERS
    from deal_finder.text_cleaner import expand_aliases, clean_description_for_audit


def main():
    root = Path(__file__).resolve().parent.parent
    benchmark = json.loads((root / 'tests/data/benchmark_listings.json').read_text(encoding='utf-8'))
    rows = [dict(zip(PRICE_LIST_HEADERS, row)) for row in DEFAULT_PRICE_LIST_ROWS]
    targets = [PriceListTarget.from_mapping(row) for row in rows]
    cases = []
    for listing in benchmark:
        candidates = find_candidate_matches(listing, targets)
        cases.append({
            'listing': listing,
            'aliases': expand_aliases(listing['title']),
            'clean_description': clean_description_for_audit(listing.get('description', '')),
            'scores': {t.item_name: compute_lexical_recall_score(listing['title'], t.item_name) for t in targets},
            'candidates': [{'target': c.target.item_name, 'price_centavos': round(c.effective_price * 100),
                            'flag': c.price_flag} for c in candidates],
        })
    manifest = {
        'baseline_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
        'source_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sorted((root / 'src/deal_finder').glob('*.py'))},
        'targets': rows, 'cases': cases,
        'fuzzy_edges': [{'a': a, 'b': b, 'ratio': fuzz.ratio(a, b), 'partial': fuzz.partial_ratio(a, b),
                         'token_set': fuzz.token_set_ratio(a, b)}
                        for a, b in [('', ''), ('', 'a'), ('abcd', 'bcde'), ('abc', 'xyz'),
                                     ('new new phone', 'new phone'), ('Nintendo Switch', 'Switch Nintendo OLED')]],
    }
    path = root / 'deal_finder_app/test/fixtures/python_parity.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Exported {len(cases)} listings and {len(targets)} targets to {path}')


if __name__ == '__main__':
    with network_disabled():
        main()
