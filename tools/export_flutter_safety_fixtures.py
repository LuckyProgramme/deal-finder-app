"""Export synthetic safety fixtures through the unchanged Python domain engine.

Run: uv run python tools/export_flutter_safety_fixtures.py
Private .env import and network access are disabled. Expectations are computed,
not handwritten; inputs extend the named checked-in tests with Unicode edges.
"""
import hashlib
import json
import logging
from pathlib import Path
import platform
import random
import subprocess
import unicodedata

import rapidfuzz
from rapidfuzz import fuzz, utils

from offline_oracle import isolated_oracle_imports, network_disabled

with isolated_oracle_imports():
    from deal_finder.accessory_checker import is_accessory_only_listing
    from deal_finder.candidate_filter import CandidateMatch
    from deal_finder.deal_engine import _condition_after_audit, extract_freebies, run_two_stage_cascade
    from deal_finder.gemini_auditor import audit_batch
    from deal_finder.models import AuditResult, Listing, PriceListTarget
    from deal_finder.text_cleaner import clean_description_for_audit
    from deal_finder.variant_tokens import build_family_lookup, build_variant_token_map, filter_candidates


GAME = {"Item Name": "Zelda BOTW", "Category": "", "Target Type": "Game",
        "Search Mode": "Item Name", "Deal Price (PHP)": 1200, "Allow Bundle Check": True}
BUNDLE = {"id": "bundle-1", "title": "Naruto + Zelda BOTW games", "price": 2300,
          "description": "Selling individually:\nNaruto - PHP 1500\nZelda BOTW - PHP 1000",
          "condition": "Like New", "eligible_target_names": ["Zelda BOTW"]}
AUDIT = {"id": "bundle-1", "matched_item": "Zelda BOTW", "confidence": 95,
         "specs_matched": True, "issues": [], "freebies": [], "downgrade_condition": False,
         "is_accessory": False, "is_bundle": True, "individual_price": 1000,
         "separately_available": True, "price_evidence": "Zelda BOTW - PHP 1000"}


class Response:
    status_code = 200

    def __init__(self, audits):
        self.audits = audits

    def json(self):
        return {"candidates": [{"content": {"parts": [{"text": json.dumps({"audits": self.audits})}]}}]}


def normalized_deal(deal):
    return {
        "id": deal.get("id", deal.get("listing_id")),
        "target": deal["matched_item"],
        "price_centavos": round(deal.get("price", deal.get("carousell_price")) * 100),
        "savings_centavos": round(deal["savings"] * 100),
        "original_price_centavos": round(deal["original_listing_price"] * 100)
            if deal.get("original_listing_price") is not None else None,
        "condition": deal["final_condition"],
        "issues": list(deal.get("issues", [])),
        "freebies": list(deal.get("freebies", deal.get("bundles", []))),
        "is_bundle": deal.get("is_bundle", False),
        "price_evidence": deal.get("price_evidence"),
        "source": deal["audit_source"],
        "gemini_confidence": deal.get("gemini_confidence"),
        "local_score": deal.get("local_match_score"),
    }


def cascade_case(name, *, listing=None, target=None, audits=None, local=False, targets=None):
    listing = dict(BUNDLE if listing is None else listing)
    targets = targets or [dict(GAME if target is None else target)]
    audits = [dict(AUDIT)] if audits is None else audits
    result = run_two_stage_cascade(
        [listing], targets, include_local_fallback=local,
        audit_candidates=lambda candidates, price_targets: audit_batch(
            candidates, price_targets, api_key="offline-fixture", model="fixture-model",
            http_post=lambda *args, **kwargs: Response(audits), sleep=lambda _: None,
        ),
    )
    return {"name": name, "listing": listing, "targets": targets, "audits": audits,
            "include_local": local,
            "candidates": [{"target": c.target.item_name, "price_centavos": round(c.effective_price * 100),
                            "flag": c.price_flag} for c in result.candidates],
            "failed_ids": sorted(result.audit_result.fallback_ids),
            "unknown_ids": sorted(result.audit_result.unknown_ids),
            "deals": [normalized_deal(d) for d in result.deals],
            "python_local_proposals": [normalized_deal(d) for d in result.audit_result.fallback_deals]}


def collect():
    cases = [cascade_case("valid split preserves source price and excludes paid items",
                          audits=[{**AUDIT, "freebies": ["Naruto (PHP 1500)"]}])]
    for price, enabled in [(3600, True), (3600.01, True), (4000, True), (2300, False), (0, True), (1000, False)]:
        cases.append(cascade_case(f"bundle ceiling {price} enabled={enabled}",
                     listing={**BUNDLE, "price": price}, target={**GAME, "Allow Bundle Check": enabled}))
    for field, values in {
        "individual_price": [None, 1300, 1500, 0, -1, True, "1000"],
        "separately_available": [False, "TRUE"], "is_bundle": ["true"],
        "price_evidence": [None, "Naruto - PHP 1500", "Zelda BOTW - PHP 999", "", "x" * 801],
        "confidence": [79, True, 101], "specs_matched": [False], "is_accessory": [True],
        "matched_item": ["Naruto", None],
    }.items():
        for i, value in enumerate(values):
            cases.append(cascade_case(f"invalid audit {field} {i}", audits=[{**AUDIT, field: value}]))
    for field in ["is_bundle", "individual_price", "separately_available", "price_evidence"]:
        cases.append(cascade_case(f"missing {field}", audits=[{k: v for k, v in AUDIT.items() if k != field}]))
    for terms in ["Take all only.", "Bundle only.", "No splitting.", "No individual sales.",
                  "Not sold separately."]:
        cases.append(cascade_case(f"seller restriction {terms}", listing={**BUNDLE, "description": terms + "\n" + AUDIT["price_evidence"]}))
    for line in ["Zelda BOTW - PHP 1000 SOLD", "Originally Zelda BOTW - PHP 1000",
                 "Deposit: Zelda BOTW - PHP 1000", "Zelda BOTW - PHP 1000 if you buy both",
                 "Zelda BOTW - PHP 2000; Naruto - PHP 1000", "Zelda BOTW - PHP 10000",
                 "Zelda BOTW - 1k", "Zelda BOTW - 1,000", "Zelda BOTW - PHP 1000.00"]:
        evidence = AUDIT["price_evidence"] if line.endswith("10000") else line
        cases.append(cascade_case(f"source evidence {line}", listing={**BUNDLE, "description": line},
                                 audits=[{**AUDIT, "price_evidence": evidence}]))
    for spelling in ["Pokémon Scarlet", "Pokèmon Scarlet", "Pokmon Scarlet"]:
        line = f"{spelling} - PHP 1000"
        cases.append(cascade_case(f"unicode target evidence {spelling}",
            target={**GAME, "Item Name": "Pokémon Scarlet"},
            listing={**BUNDLE, "title": "Pokémon Scarlet + Violet games", "description": line,
                     "eligible_target_names": ["Pokémon Scarlet"]},
            audits=[{**AUDIT, "matched_item": "Pokémon Scarlet", "price_evidence": line}]))
    for name, spelling in [("Straße Racer", "STRASSE Racer"), ("ΟΣ Racer", "ος Racer"),
                           ("İ Racer", "i\u0307 Racer"), ("Game_2", "Game 2"),
                           ("東京 Racer", "京都 Racer")]:
        line = f"{spelling} - PHP 1000"
        cases.append(cascade_case(f"casefold evidence {name} / {spelling}",
            target={**GAME, "Item Name": name},
            listing={**BUNDLE, "title": f"{name} + games", "description": line, "eligible_target_names": [name]},
            audits=[{**AUDIT, "matched_item": name, "price_evidence": line}]))
    for price, title, description in [(0, "PS5 Slim", "PM me"), (100, "PS5 Slim", "PM me"),
                                      (0, "PS5 Slim", "Asking PHP 17000"),
                                      (17000, "PS5 Slim", "No issue. Comes with a controller."),
                                      (15000, "PS5 Slim Digital", ""),
                                      (22000, "MacBook Air 2020 13-inch", "")]:
        rows = [{"Item Name": "PS5 Slim", "Deal Price (PHP)": 18000, "Keyword for Finding Freebies": "comes with"},
                {"Item Name": "PS5 Slim Digital", "Deal Price (PHP)": 16000},
                {"Item Name": "MacBook M4", "Deal Price (PHP)": 50000}]
        cases.append(cascade_case(f"local fallback {price} {title}", targets=rows,
            listing={"id": "local-1", "title": title, "price": price, "description": description, "condition": "Like New"},
            audits=[], local=True))
    cases.append(cascade_case("failed bundle never becomes local deal", audits=[], local=True))
    # Owner approved 2026-09-11: retain every Stage-1 candidate, rather than
    # reproducing audit_batch's first-target-per-ID loss. Keep oracle output
    # untouched and separately assert the native matcher's exact proposal.
    digital = next(c for c in cases if c["name"] == "local fallback 15000 PS5 Slim Digital")
    assert digital["deals"] == [] and len(digital["python_local_proposals"]) == 1
    assert digital["python_local_proposals"][0]["target"] == "PS5 Slim Digital"
    digital["approved_difference"] = "Retain all valid Stage-1 candidates (owner approved 2026-09-11)"
    digital["approved_flutter_deals"] = digital["python_local_proposals"]

    conditions = []
    descriptions = ["There is a cosmetic issue.", "No issue at all.", "No issue, but later there is a defect.",
                    "Never had an issue.", "not one two three issue", "not one two three four issue",
                    "This showcase looks good.", "There is an issueñ.", "There is éissue.",
                    "no número pequeño issue", "no issue. An issue is present now."]
    for original in ["Brand New", "Like New", "Lightly Used", "Well Used", "Heavily Used", "  LIKE\tNEW  "]:
        for description in descriptions:
            target = PriceListTarget("PS5 Slim", "", 18000, downsizing_keywords=("issue", "defect", "case"))
            listing = Listing("condition", "PS5 Slim", 17000, original, description)
            audit = AuditResult("condition", "PS5 Slim", 95, True)
            candidate = CandidateMatch(listing, target, 17000, 100, "normal")
            conditions.append({"name": f"{original}: {description}", "original": original, "title": listing.title,
                "description": description, "keywords": list(target.downsizing_keywords), "game": False,
                "downgrade": False, "issues": [], "expected": _condition_after_audit(candidate, audit)[0]})
    for keywords in [[" ISSUE "], [""], ["  "], ["", "defect"]]:
        target = PriceListTarget("PS5 Slim", "", 18000, downsizing_keywords=tuple(keywords))
        listing = Listing("condition", "PS5 Slim", 17000, "Like New", "There is an issue.")
        candidate = CandidateMatch(listing, target, 17000, 100, "normal")
        conditions.append({"name": f"keyword normalization {keywords}", "original": "Like New", "title": listing.title,
            "description": listing.description, "keywords": keywords, "game": False,
            "downgrade": False, "issues": [], "expected": _condition_after_audit(candidate, AuditResult("condition", "PS5 Slim", 95, True))[0]})
    for issues in [[], ["No case"], ["No case", "Damaged contacts"], ["damaged contacts"]]:
        target = PriceListTarget("Zelda BOTW", "", 1200, target_type="Game", downsizing_keywords=("case",))
        listing = Listing("condition", "Zelda BOTW cartridge only", 1000, "Like New", "Cartridge only (no case).")
        candidate = CandidateMatch(listing, target, 1000, 100, "normal")
        audit = AuditResult("condition", target.item_name, 95, True, tuple(issues), (), True)
        conditions.append({"name": f"game packaging {issues}", "original": "Like New", "title": listing.title,
            "description": listing.description, "keywords": ["case"], "game": True, "downgrade": True,
            "issues": issues, "expected": _condition_after_audit(candidate, audit)[0]})

    variants = []
    for names in [["PS5 Slim", "PS5 Slim Digital", "Nintendo Switch OLED"],
                  ["MacBook M4"], ["iPhone 15", "iPhone 15 Pro", "iPhone 15 Pro Max"],
                  ["PS5 Slim", "", "PS5 Slim", "PS5 Slim Digital"]]:
        family = build_family_lookup(names)
        token_map = build_variant_token_map(names)
        titles = ["PS5 Slim console", "PS5 Slim Digital console", "MacBook Air 2020 13-inch", "MacBook M4 16GB",
                  "iPhone 15 Pro Max", "iPhone 15 Pro", "iPhone 15", "Nintendo Switch OLED console"]
        variants.append({"names": names, "families": family,
            "tokens": {name: sorted(tokens) for name, tokens in token_map.items()},
            "decisions": [{"title": title, "target": name, "accepted": filter_candidates(title, name, token_map, family_lookup=family)}
                          for title in titles for name in family]})

    texts = [("🎮 " * 300 + "\nZelda BOTW - PHP 1000", 800),
             ("A\rZelda BOTW - PHP 1000\rB", 800), ("A\u2028Zelda BOTW - PHP 1000\u2029B", 800),
             ("#café Useful description", 800), ("Useful game information. " * 15 + "\nZelda BOTW - PHP 1000", 800),
             ("Item - PHP 1000", 13), ("\ufeffTitle\x85Next line", 800),
             ("🎮 Zelda - PHP 1000", 1), ("🎮 Zelda - PHP 1000", 0),
             ("🎮 Zelda - PHP 1000", 17), ("#東京 Useful description", 800)]
    fuzzy = [("🎮a", "🎮b"), ("a🎮b", "🎮b"), ("z😀ab", "😀abx"), ("é oled", "è oled"),
             ("東京 switch", "switch 東京"), ("abc_123", "abc 123"), ("Pokémon Scarlet", "Pokemon Scarlet"),
             ("İ ẞ ΟΣ ſ ᾼ", "i ß οσ s ᾳ"), ("a\x85b", "b a"), ("a\ufeffb", "b a"),
             ("\U00010000 \ue000 abc", "\ue000 \U00010000 def")]
    rng = random.Random(20260911)
    for space in [chr(c) for c in range(0x110000) if chr(c).isspace()] + ["\ufeff"]:
        for suffix in ["", "é", "東京", "🎮"]:
            fuzzy.append((f"a{space}b{suffix}", f"b{suffix} a"))
            fuzzy.append((f"a{space}b", f"b{suffix} a"))
    alphabet = "abé🎮😀_ \x85\ufeff"
    for _ in range(300):
        fuzzy.append(tuple("".join(rng.choices(alphabet, k=rng.randrange(0, 15))) for _ in range(2)))
    for _ in range(12):
        fuzzy.append(tuple("".join(rng.choices("ab🎮 ", k=rng.randrange(65, 90))) for _ in range(2)))
    accessories = [
        ("Nintendo Switch Joy-Con (L) Blue & (R) Red", ""),
        ("PRAGMATA Nintendo Switch Game - Capcom", ""), ("MacBook Air charger 65W", ""),
        ("iPhone 15 Pro case only", ""), ("Nintendo Switch OLED console bundle", "Includes charger and case."),
        ("MacBook M4 16GB", "Complete unit with charger."), ("Zelda BOTW case only", ""),
        ("Zelda BOTW cartridge only", "No case"), ("Zelda BOTW", "No game case"),
        ("Zelda BOTW", "No game"), ("Zelda BOTW empty box", ""), ("Zelda BOTW cover art", ""),
    ]
    return {"cascade": cases, "conditions": conditions, "variants": variants,
            "clean_text": [{"text": text, "max_chars": size, "expected": clean_description_for_audit(text, size)} for text, size in texts],
            "fuzzy": [{"a": a, "b": b, "ratio": fuzz.ratio(a, b), "partial": fuzz.partial_ratio(a, b),
                       "token_sort": fuzz.token_sort_ratio(a, b),
                       "token_set": fuzz.token_set_ratio(a, b), "process_a": utils.default_process(a),
                       "process_b": utils.default_process(b)} for a, b in fuzzy],
            "accessories": [{"title": title, "description": description, "type": kind,
                "expected": is_accessory_only_listing(title, description, target_type=kind)}
                for title, description in accessories for kind in ["Hardware", "Game"]],
            "freebies": [{"description": text, "keywords": words, "expected": extract_freebies(text, words)}
                         for text, words in [("Includes a case and charger, free screen protector. Includes a case and charger.", ["includes", "free"]),
                                             ("Comes with one two three four five six seven.", ["comes with"]),
                                             ("Includes a case.", []), ("Includes a case.", ["  INCLUDES  "])]]}


def main():
    root = Path(__file__).resolve().parent.parent
    logging.disable(logging.CRITICAL)
    with network_disabled():
        fixtures = collect()
    digests = {name: hashlib.sha256() for name in ["casefold", "process", "word"]}
    for code in range(0x110000):
        if 0xD800 <= code <= 0xDFFF:
            continue  # Invalid Unicode scalar values are not application text.
        char = chr(code)
        digests["casefold"].update(char.casefold().encode("utf-8") + b"\0")
        digests["process"].update(utils.default_process(char).encode("utf-8") + b"\0")
        digests["word"].update(bytes([int(char.isalnum() or char == "_")]))
    manifest = {
        "baseline_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "python": platform.python_version(), "rapidfuzz": rapidfuzz.__version__, "unicode": unicodedata.unidata_version,
        "source_sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((root / "src/deal_finder").glob("*.py"))},
        "test_sources": ["tests/test_bundle_auditing.py", "tests/test_deal_engine.py", "tests/test_variant_tokens.py", "tests/test_accessory_checker.py"],
        "unicode_scalar_sha256": {name: digest.hexdigest() for name, digest in digests.items()},
        **fixtures,
    }
    path = root / "deal_finder_app/test/fixtures/python_safety_parity.json"
    path.write_text(json.dumps(manifest, ensure_ascii=False, allow_nan=False, indent=2) + "\n", encoding="utf-8")
    print("Exported safety fixtures: " + ", ".join(f"{key}={len(value)}" for key, value in fixtures.items()))


if __name__ == "__main__":
    main()
