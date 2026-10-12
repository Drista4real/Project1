"""Deterministic Vietnamese spoken/slang money normalization; no network or LLM."""

import re
import unicodedata
from decimal import Decimal, InvalidOperation

_DIGITS = {
    "không": 0,
    "một": 1,
    "mốt": 1,
    "hai": 2,
    "ba": 3,
    "bốn": 4,
    "tư": 4,
    "năm": 5,
    "lăm": 5,
    "sáu": 6,
    "bảy": 7,
    "tám": 8,
    "chín": 9,
}
_DIGIT_WORD = "(?:" + "|".join(_DIGITS) + ")"
_NUMBER_WORD = (
    "(?:" + "|".join((*_DIGITS, "mười", "mươi", "chục", "trăm", "linh", "lẻ")) + ")"
)
_NUMBER = rf"(?:\d+(?:[.,]\d+)*|{_NUMBER_WORD}(?:\s+{_NUMBER_WORD}){{0,5}})"
_UNITS = {
    "k": 1000,
    "cành": 1000,
    "nghìn": 1000,
    "ngàn": 1000,
    "lít": 100_000,
    "loét": 100_000,
    "củ": 1_000_000,
    "triệu": 1_000_000,
    "tr": 1_000_000,
    "đồng": 1,
    "vnd": 1,
    "đ": 1,
}
_MONEY = re.compile(
    rf"(?<![\w+\-])(?:"
    rf"(?P<compact>\d+)\s*tr(?P<fraction>\d{{1,3}})"
    rf"|(?P<number>{_NUMBER})\s*(?P<unit>{'|'.join(_UNITS)})"
    rf"(?:\s+(?P<half>rưỡi))?"
    rf"|(?P<tens>{_DIGIT_WORD}|\d+)\s+chục"
    rf")(?!\w)",
)


def _spoken_integer(words: list[str]) -> int:
    """Parse single digits, spoken tens, compact 'ba lăm', and hundreds."""
    if not words:
        raise ValueError("Missing spoken number")
    if len(words) >= 2 and words[0] in _DIGITS and words[1] == "trăm":
        return _DIGITS[words[0]] * 100 + (
            _spoken_integer(words[2:]) if words[2:] else 0
        )
    if words[0] in {"linh", "lẻ"} and len(words) == 2:
        return _spoken_integer(words[1:])
    if len(words) == 1 and words[0] in _DIGITS:
        return _DIGITS[words[0]]
    if words[0] == "mười" and len(words) <= 2:
        return 10 + (_DIGITS[words[1]] if len(words) == 2 else 0)
    if words[0] in _DIGITS:
        if len(words) in (2, 3) and words[1] in {"mươi", "chục"}:
            return _DIGITS[words[0]] * 10 + (
                _DIGITS[words[2]] if len(words) == 3 else 0
            )
        if len(words) == 2 and words[1] in _DIGITS:
            return _DIGITS[words[0]] * 10 + _DIGITS[words[1]]
    raise ValueError("Unsupported spoken-number grammar")


def _number(value: str) -> Decimal:
    """Use decimal arithmetic; dots in groups of three denote thousands."""
    if value[0].isdigit():
        if re.fullmatch(r"\d{1,3}(?:\.\d{3})+", value):
            return Decimal(value.replace(".", ""))
        return Decimal(value.replace(",", "."))
    return Decimal(_spoken_integer(value.split()))


class VietnameseFinancialSlangNormalizer:
    """Normalize money to '<integer> đồng'; return the first amount, without summing.

    k/cành/nghìn/ngàn = 1,000; lít/loét = 100,000; củ/triệu/tr = 1,000,000.
    A bare spoken 'năm chục' means 50,000. Compact '1tr5' means 1,500,000.
    Bare numerals without a monetary unit are never interpreted as money.
    """

    def normalize(self, text: str) -> tuple[str, int | None]:
        """Lowercase/NFC/space-normalize and replace supported monetary phrases."""
        if not isinstance(text, str):
            raise TypeError("Financial text must be a string")
        text = " ".join(unicodedata.normalize("NFC", text).lower().split())
        first_amount: int | None = None

        def replace(match: re.Match[str]) -> str:
            """Convert one unambiguous positive monetary phrase into integer VND."""
            nonlocal first_amount
            if re.search(r"[+\-]\s*$", text[: match.start()]):
                return match.group(0)
            try:
                if match.group("compact") is not None:
                    fraction = match.group("fraction")
                    amount = (
                        Decimal(match.group("compact")) + Decimal("0." + fraction)
                    ) * 1_000_000
                elif match.group("tens") is not None:
                    amount = _number(match.group("tens")) * 10_000
                else:
                    number = _number(match.group("number"))
                    if match.group("half"):
                        number += Decimal("0.5")
                    amount = number * _UNITS[match.group("unit")]
                if amount != amount.to_integral_value():
                    return match.group(0)
                integer = int(amount)
            except (ValueError, KeyError, InvalidOperation):
                # Preserve unrecognized grammar instead of inventing a transaction.
                return match.group(0)
            if first_amount is None:
                first_amount = integer
            return f"{integer} đồng"

        normalized = _MONEY.sub(replace, text)
        return normalized, first_amount


# Keep the original scaffold name usable by callers.
FinancialSlangNormalizer = VietnameseFinancialSlangNormalizer
