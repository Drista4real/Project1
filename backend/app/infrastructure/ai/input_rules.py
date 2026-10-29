"""Transparent local fallback labels and punctuation-free input boundaries."""

import re
import unicodedata

from app.infrastructure.ai.edge_asr.normalizer import VietnameseFinancialSlangNormalizer


def folded(text: str) -> str:
    """Compare Vietnamese labels with or without diacritics."""
    return "".join(
        c
        for c in unicodedata.normalize("NFD", text.lower().replace("đ", "d"))
        if unicodedata.category(c) != "Mn"
    )


# Specific intent precedes broad labels, e.g. repairs before transport.
_EXPENSE_RULES = (
    (
        r"sua (?:xe|chua|may|dien|ong)|bao duong|thay (?:lop|nhot)",
        ("sua chua", "bao duong", "di lai"),
    ),
    (r"thuoc|kham|benh vien|y te|nha khoa", ("thuoc", "kham", "y te")),
    (
        r"tra sua|ca phe|cafe|coffee|nhau|bia|gap go",
        ("ca phe", "gap go", "do uong", "an uong"),
    ),
    (r"tien nha|thue nha|tien tro|chung cu", ("thue nha", "chung cu", "nha o")),
    (
        r"dien nuoc|tien dien|tien nuoc|internet|wifi|dien thoai",
        ("hoa don", "internet"),
    ),
    (
        r"xang|grab|taxi|xe buyt|gui xe|ve xe|giao thong",
        ("xang", "giao thong", "di lai"),
    ),
    (r"sach|bao chi|truyen|tri thuc", ("sach", "tri thuc", "van hoa")),
    (r"khoa hoc|hoc phi|ky nang|hoc tieng", ("khoa hoc", "hoc", "giao duc")),
    (r"gym|the thao|yoga|cau long|boi loi", ("gym", "the thao")),
    (r"xem phim|game|giai tri|netflix|spotify", ("giai tri", "phim", "game")),
    (r"du lich|khach san|nghi duong|ve may bay", ("du lich", "nghi duong")),
    (r"dam cuoi|cuoi hoi|hieu hy|qua tang|sinh nhat", ("qua tang", "hieu hy")),
    (r"quan ao|giay|dep|tui xach|my pham|mua sam", ("mua sam", "quan ao")),
    (
        r"an (?:sang|trua|chieu|toi)|com|bun|pho|banh|do an|di cho|sieu thi|thuc pham",
        ("an uong", "di cho", "thuc pham"),
    ),
)
_INCOME_RULES = (
    (r"luong|thuong", ("luong", "thuong")),
    (r"lai|co tuc|dau tu", ("lai", "dau tu")),
    (r"tang|tro cap|(?:me|bo|ba|cha) cho", ("tang", "tro cap")),
    (
        r"freelance|lam them|ban hang|thu tien",
        ("thu nhap phu", "freelance", "lam them"),
    ),
)


def suggest_category(text: str, names: tuple[str, ...], *, income: bool) -> str | None:
    """Match intent to a unique existing label; never create a new category."""
    normalized = folded(text)
    for pattern, aliases in _INCOME_RULES if income else _EXPENSE_RULES:
        if not re.search(r"\b(?:" + pattern + r")\b", normalized):
            continue
        for alias in aliases:
            matches = [name for name in names if alias in folded(name)]
            if len(matches) == 1:
                return matches[0]
        return None
    return None


_MONEY = re.compile(r"(?<![\w+-])\d+ đồng\b")
_PAYMENT = re.compile(
    r"^\s*(?:(?:bằng|qua|từ|trả bằng|thanh toán bằng)\s+)?"
    r"(?:tiền mặt|chuyển khoản|momo|mo mo|zalopay|zalo pay|thẻ|"
    r"vietcombank|techcombank|mbbank|mb bank|acb|bidv|vietinbank)\b",
    re.I,
)
_TIME = re.compile(r"^\s*(?:lúc\s+)?\d{1,2}(?:h|:)\d{0,2}\b", re.I)
_ADJUSTMENT = re.compile(
    r"\b(?:tổng|tất cả|giảm|còn|tiền thừa|tiền trả lại|thực ra|"
    r"đính chính|thành|mỗi|từ|đến|hoặc)\b",
    re.I,
)


def split_transactions(text: str) -> list[str]:
    """Separate descriptions around money, retaining payment suffixes.

    Normalizing money is deterministic. Adjustment/total phrases deliberately
    remain ambiguous, rather than turning totals or change into new expenses.
    """
    explicit = [
        s.strip()
        for s in re.split(
            r"[;\n]+|,(?!\d)|(?<!\s)\s+(?:và|rồi)\s+", text, flags=re.I
        )
        if s.strip()
    ]
    result: list[str] = []
    if any(
        re.match(r"^(?:tổng|tất cả|giảm|còn|tiền thừa|tiền trả lại)\b", c, re.I)
        for c in explicit
    ):
        return [text]
    for clause in explicit:
        normalized, _ = VietnameseFinancialSlangNormalizer().normalize(clause)
        amounts = list(_MONEY.finditer(normalized))
        if len(amounts) < 2:
            result.append(clause)
            continue
        boundaries = [0]
        for previous, current in zip(amounts, amounts[1:], strict=False):
            gap = normalized[previous.end() : current.start()]
            consumed = 0
            for suffix in (_PAYMENT, _TIME):
                match = suffix.match(gap[consumed:])
                if match:
                    consumed += match.end()
            description = gap[consumed:].strip(" .,;:!—-")
            if (
                not description
                or _ADJUSTMENT.search(description)
                or not re.search(r"[^\W\d_]", description)
            ):
                boundaries = []
                break
            boundaries.append(previous.end() + consumed)
        if not boundaries:
            result.append(clause)
        else:
            boundaries.append(len(normalized))
            result.extend(
                normalized[a:b].strip(" .,;:!—-")
                for a, b in zip(boundaries, boundaries[1:], strict=False)
            )
    return result
