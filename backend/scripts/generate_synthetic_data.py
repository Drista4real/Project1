"""Generate reproducible six-category Vietnamese transactions and balance history."""

import argparse
import csv
import random
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXT_TEMPLATES: dict[str, tuple[str, ...]] = {
    "Ăn uống": (
        "cơm sườn {amount}k",
        "bún bò {amount}k",
        "cà phê highland {amount}k",
        "trà sữa {amount}k",
        "ăn trưa {amount}k",
        "phở bò {amount}k",
        "mua bánh mì {amount}k",
        "bữa tối ở quán {amount}k",
        "ăn sáng xôi gà {amount}k",
        "nước ép cam {amount}k",
        "đặt đồ ăn giao tận nhà {amount}k",
        "ăn lẩu cùng gia đình {amount}k",
    ),
    "Đi lại": (
        "đổ xăng {amount}k",
        "grab car {amount}k",
        "be bike {amount}k",
        "vé xe buýt {amount}k",
        "gửi xe {amount}k",
        "đi taxi {amount}k",
        "vé tàu điện {amount}k",
        "tiền xe ôm {amount}k",
        "phí cầu đường {amount}k",
        "đặt vé xe khách {amount}k",
        "thay dầu xe máy {amount}k",
        "vá lốp xe {amount}k",
    ),
    "Mua sắm": (
        "mua áo thun {amount}k",
        "đơn hàng shopee {amount}k",
        "mua tai nghe {amount}k",
        "mua sạc cáp {amount}k",
        "mua đồ gia dụng ở siêu thị {amount}k",
        "mua giày {amount}k",
        "mua quần jeans {amount}k",
        "mua balo {amount}k",
        "mua bàn phím {amount}k",
        "mua sách {amount}k",
        "mua áo {amount}k",
        "mua đồ {amount}k",
    ),
    "Hóa đơn/Nhà ở": (
        "tiền điện {amount}k",
        "tiền nước {amount}k",
        "đóng tiền trọ {amount}k",
        "thanh toán mạng wifi {amount}k",
        "trả tiền thuê nhà {amount}k",
        "đóng phí chung cư {amount}k",
        "hóa đơn internet {amount}k",
        "trả tiền gas nấu ăn {amount}k",
        "phí vệ sinh khu trọ {amount}k",
        "thanh toán cước điện thoại {amount}k",
        "phí quản lý căn hộ {amount}k",
        "đóng tiền phòng tháng này {amount}k",
    ),
    "Y tế": (
        "mua thuốc panadol {amount}k",
        "khám răng {amount}k",
        "mua khẩu trang {amount}k",
        "mua vitamin {amount}k",
        "khám bệnh {amount}k",
        "mua thuốc cảm {amount}k",
        "xét nghiệm máu {amount}k",
        "tiêm phòng {amount}k",
        "mua băng gạc {amount}k",
        "lấy cao răng {amount}k",
        "mua nước muối sinh lý {amount}k",
        "phí khám mắt {amount}k",
    ),
    "Khác": (
        "bao bạn bè {amount}k",
        "mừng cưới {amount}k",
        "tiền phạt {amount}k",
        "từ thiện {amount}k",
        "ủng hộ đồng bào {amount}k",
        "lì xì cháu {amount}k",
        "quyên góp quỹ cộng đồng {amount}k",
        "phúng viếng {amount}k",
        "biếu ông bà {amount}k",
        "tặng tiền sinh nhật bạn {amount}k",
        "đóng góp quỹ lớp {amount}k",
        "phạt vi phạm giao thông {amount}k",
    ),
}
NOISY_TEMPLATES: dict[str, tuple[str, ...]] = {
    "Ăn uống": (
        "hl {amount} cành",
        "trasua {amount}k",
        "cf highland {amount}k",
        "bunbo {amount} cành",
        "com suon {amount}k",
        "ăn trua {amount}k",
        "bmi {amount} cành",
        "caphe {amount}k",
        "order đồ ăn {amount} cành",
        "trà sữa {amount} xị",
        "pho bo {amount}k",
        "cafe sáng {amount} cành",
    ),
    "Đi lại": (
        "grab {amount}k",
        "be bike {amount} cành",
        "do xang {amount}k",
        "gửi xe {amount} cành",
        "bus {amount}k",
        "grap car {amount}k",
        "xang xe {amount} cành",
        "taxi {amount} xị",
        "ve xe buyt {amount}k",
        "xe om {amount}k",
        "grabcar {amount} cành",
        "phí cao tốc {amount} xị",
    ),
    "Mua sắm": (
        "mua đồ {slang_amount}",
        "shope {amount}k",
        "ao thun {amount} cành",
        "tai nge {amount}k",
        "sac cap {amount}k",
        "sieu thi đồ gia dụng {amount}k",
        "mua giay {amount} cành",
        "chốt đơn shopee {slang_amount}",
        "quần jean {amount} xị",
        "ban phim {amount}k",
        "mua ao {amount}k",
        "mua balo {amount} cành",
    ),
    "Hóa đơn/Nhà ở": (
        "đóng trọ {slang_amount}",
        "tien dien {amount}k",
        "tiền nc {amount}k",
        "wifi {amount} cành",
        "dong tro {slang_amount}",
        "tiền nhà {amount} xị",
        "net tháng này {amount}k",
        "hd điện {amount} cành",
        "cuoc dt {amount}k",
        "phí cc {amount}k",
        "gas bếp {amount} xị",
        "thue nha {slang_amount}",
    ),
    "Y tế": (
        "thuoc panadol {amount}k",
        "kham rang {amount} cành",
        "khau trang {amount}k",
        "vitamin {amount} xị",
        "mua thuoc cam {amount}k",
        "khám bv {amount}k",
        "xn máu {amount} cành",
        "tiem phong {amount}k",
        "panadol {amount} cành",
        "băng gac {amount}k",
        "kham mat {amount}k",
        "nước muối sl {amount}k",
    ),
    "Khác": (
        "bao bb {amount}k",
        "mung cuoi {slang_amount}",
        "tien phat {amount}k",
        "tu thien {amount} cành",
        "li xi {amount} xị",
        "ung ho {amount}k",
        "phung vieng {slang_amount}",
        "biếu ob {amount}k",
        "quỹ lop {amount} cành",
        "mừng sn bạn {amount}k",
        "phat gt {amount} xị",
        "quyen gop {amount}k",
    ),
}


def generate_transactions(
    output_dir: Path, text_count: int = 1500, seed: int = 42
) -> Path:
    """Overwrite canonical CSV with balanced classes and 70/30 clear/noisy texts.

    Clear rows equal floor(0.7 * text_count); remaining rows are noisy. For counts
    divisible by ten the ratio is exact. Both styles are apportioned per class.
    """
    if text_count < 1500:
        raise ValueError("Transaction dataset must contain at least 1500 rows")
    rng = random.Random(seed)
    rows: list[tuple[str, str]] = []
    noisy_total = text_count - text_count * 7 // 10
    cumulative_count = 0
    cumulative_noisy = 0
    for index, category in enumerate(TEXT_TEMPLATES):
        category_count = text_count // 6 + (index < text_count % 6)
        cumulative_count += category_count
        target_noisy = noisy_total * cumulative_count // text_count
        noisy_count = target_noisy - cumulative_noisy
        cumulative_noisy = target_noisy
        for templates, count in (
            (TEXT_TEMPLATES[category], category_count - noisy_count),
            (NOISY_TEMPLATES[category], noisy_count),
        ):
            for _ in range(count):
                amount = rng.randint(15, 1000)
                slang_amount = rng.choice(
                    (
                        "1 củ rưỡi",
                        "3tr5",
                        "2 củ",
                        "500 cành",
                        "2tr5",
                        "1 triệu rưỡi",
                        "3 củ",
                        "5 xị",
                        "1tr2",
                        "2 củ rưỡi",
                    )
                )
                text = rng.choice(templates).format(
                    amount=amount, slang_amount=slang_amount
                )
                rows.append((text, category))
    rng.shuffle(rows)
    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / "data_transactions.csv"
    try:
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(("text", "category"))
            writer.writerows(rows)
    except (OSError, csv.Error) as exc:
        raise RuntimeError(f"Cannot write transaction dataset: {path}") from exc
    return path


def generate_balances(
    output_dir: Path,
    balance_days: int = 180,
    seed: int = 42,
    start_date: date = date(2026, 1, 1),
) -> tuple[Path, Path]:
    """Write fixed/flexible daily cashflows with integer VND cumulative balances.

    Flexible payouts are 4 or 6 million VND, separated by random 7..18-day gaps.
    Weekend spending in the fixed profile rounds the 30% increase to nearest VND.
    Each profile has its own seeded RNG, independent of transaction generation.
    """
    if type(balance_days) is not int or balance_days < 1:
        raise ValueError("Balance days must be a positive integer")
    if not isinstance(start_date, date):
        raise ValueError("start_date must be a date")
    # Validate the complete date range before creating or overwriting files.
    start_date + timedelta(days=balance_days - 1)
    output_dir.mkdir(parents=True, exist_ok=True)
    fixed_path = output_dir / "balance_fixed.csv"
    flexible_path = output_dir / "balance_flexible.csv"
    for path, initial_balance, profile_seed, is_fixed in (
        (fixed_path, 5_000_000, seed, True),
        (flexible_path, 8_000_000, seed + 1, False),
    ):
        rng = random.Random(profile_seed)
        balance = initial_balance
        next_income_offset = rng.randint(7, 18) if not is_fixed else -1
        try:
            with path.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.writer(handle)
                writer.writerow(("date", "income", "expense", "balance"))
                for offset in range(balance_days):
                    day = start_date + timedelta(days=offset)
                    if is_fixed:
                        income = 15_000_000 if day.day == 5 else 0
                        expense = rng.randint(100_000, 300_000)
                        if day.weekday() >= 5:
                            expense = (expense * 13 + 5) // 10
                        if day.day == 30:
                            expense += 3_500_000
                    else:
                        income = 0
                        if offset == next_income_offset:
                            income = rng.choice((4_000_000, 6_000_000))
                            next_income_offset += rng.randint(7, 18)
                        expense = rng.randint(50_000, 500_000)
                    balance += income - expense
                    writer.writerow((day.isoformat(), income, expense, balance))
        except (OSError, csv.Error) as exc:
            raise RuntimeError(f"Cannot write balance dataset: {path}") from exc
    return fixed_path, flexible_path


def generate(
    output_dir: Path,
    text_count: int = 1500,
    balance_days: int = 180,
    seed: int = 42,
    start_date: date = date(2026, 1, 1),
) -> tuple[Path, Path, Path]:
    """Write canonical transaction data and both reproducible cashflow profiles."""
    if type(balance_days) is not int or balance_days < 1:
        raise ValueError("Balance days must be a positive integer")
    transactions_path = generate_transactions(output_dir, text_count, seed)
    fixed_path, flexible_path = generate_balances(
        output_dir, balance_days, seed, start_date
    )
    return transactions_path, fixed_path, flexible_path


def main() -> None:
    """Generate all canonical datasets or only the requested dataset family."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "data/processed")
    parser.add_argument("--text-count", type=int, default=1500)
    parser.add_argument("--balance-days", type=int, default=180)
    parser.add_argument("--seed", type=int, default=42)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--transactions-only", action="store_true")
    mode.add_argument("--balances-only", action="store_true")
    parser.add_argument(
        "--start-date", type=date.fromisoformat, default=date(2026, 1, 1)
    )
    args = parser.parse_args()
    try:
        paths: tuple[Path, ...]
        if args.transactions_only:
            paths = (
                generate_transactions(args.output_dir, args.text_count, args.seed),
            )
        elif args.balances_only:
            paths = generate_balances(
                args.output_dir, args.balance_days, args.seed, args.start_date
            )
        else:
            paths = generate(
                args.output_dir,
                args.text_count,
                args.balance_days,
                args.seed,
                args.start_date,
            )
    except (OSError, ValueError, RuntimeError, OverflowError, csv.Error) as exc:
        parser.exit(1, f"Generation failed: {exc}\n")
    for path in paths:
        print(path)


if __name__ == "__main__":
    main()
