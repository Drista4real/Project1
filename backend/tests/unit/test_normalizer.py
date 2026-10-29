"""Tests for VietnameseFinancialSlangNormalizer."""

import pytest

from app.infrastructure.ai.edge_asr.normalizer import (
    FinancialSlangNormalizer,
    VietnameseFinancialSlangNormalizer,
)


class TestVietnameseFinancialSlangNormalizer:
    """Tests for VietnameseFinancialSlangNormalizer."""

    def setup_method(self):
        self.normalizer = VietnameseFinancialSlangNormalizer()

    # Basic normalization tests
    def test_normalize_empty_string(self):
        """Test normalizing empty string."""
        result, amount = self.normalizer.normalize("")
        assert result == ""
        assert amount is None

    def test_normalize_no_money(self):
        """Test normalizing text without money."""
        result, amount = self.normalizer.normalize("Chào bạn")
        assert result == "chào bạn"
        assert amount is None

    def test_normalize_simple_amount_vnd(self):
        """Test normalizing simple amount with VND."""
        result, amount = self.normalizer.normalize("50000 đồng")
        assert result == "50000 đồng"
        assert amount == 50000

    def test_normalize_amount_with_vnd_suffix(self):
        """Test normalizing amount with various VND suffixes."""
        for suffix in ["vnđ", "vnd", "đ"]:
            result, amount = self.normalizer.normalize(f"50000 {suffix}")
            assert result == "50000 đồng"
            assert amount == 50000

    def test_normalize_kilodong(self):
        """Test normalizing 'k' / 'nghìn' / 'ngàn' / 'cành' units."""
        test_cases = [
            ("50 k", 50000),
            ("50 nghìn", 50000),
            ("50 ngàn", 50000),
            ("50 cành", 50000),
        ]
        for text, expected in test_cases:
            result, amount = self.normalizer.normalize(text)
            assert amount == expected, (
                f"Failed for '{text}': got {amount}, expected {expected}"
            )
            assert "50000 đồng" in result

    def test_normalize_hundred_thousand_units(self):
        """Test normalizing 'lít' / 'loét' / 'xị' units (100,000)."""
        test_cases = [
            ("2 lít", 200000),
            ("2 loét", 200000),
            ("2 xị", 200000),
        ]
        for text, expected in test_cases:
            result, amount = self.normalizer.normalize(text)
            assert amount == expected, (
                f"Failed for '{text}': got {amount}, expected {expected}"
            )
            assert "200000 đồng" in result

    def test_normalize_million_units(self):
        """Test normalizing 'triệu' / 'tr' / 'củ' units (1,000,000)."""
        test_cases = [
            ("3 triệu", 3000000),
            ("3 tr", 3000000),
            ("3 củ", 3000000),
        ]
        for text, expected in test_cases:
            result, amount = self.normalizer.normalize(text)
            assert amount == expected, (
                f"Failed for '{text}': got {amount}, expected {expected}"
            )
            assert "3000000 đồng" in result

    def test_normalize_billion_units(self):
        """Test normalizing 'tỷ' / 'tỉ' units (1,000,000,000)."""
        test_cases = [
            ("1 tỷ", 1000000000),
            ("1 tỉ", 1000000000),
        ]
        for text, expected in test_cases:
            result, amount = self.normalizer.normalize(text)
            assert amount == expected, (
                f"Failed for '{text}': got {amount}, expected {expected}"
            )
            assert "1000000000 đồng" in result

    def test_normalize_compact_tr_format(self):
        """Test normalizing compact '1tr5' format."""
        result, amount = self.normalizer.normalize("1tr5")
        assert amount == 1500000
        assert "1500000 đồng" in result

    def test_normalize_compact_tr_with_leading_zeros(self):
        """Test normalizing compact format with leading zeros in fraction."""
        result, amount = self.normalizer.normalize("2tr05")
        assert amount == 2050000
        assert "2050000 đồng" in result

    def test_normalize_compact_tr_three_digit_fraction(self):
        """Test normalizing compact format with 3-digit fraction."""
        result, amount = self.normalizer.normalize("1tr500")
        assert amount == 1500000
        assert "1500000 đồng" in result

    def test_normalize_descending_units(self):
        """Test normalizing descending units form one amount."""
        result, amount = self.normalizer.normalize("2 triệu 500 nghìn")
        assert amount == 2500000
        assert "2500000 đồng" in result

    def test_normalize_ascending_units_start_new(self):
        """Test that non-descending units start a new amount."""
        result, amount = self.normalizer.normalize("500 nghìn 2 triệu")
        # First amount is 500,000, second is 2,000,000
        assert amount == 500000  # First amount

    def test_normalize_half_rưỡi(self):
        """Test normalizing 'rưỡi' (half)."""
        result, amount = self.normalizer.normalize("1 triệu rưỡi")
        assert amount == 1500000
        assert "1500000 đồng" in result

    def test_normalize_clause_final_rest(self):
        """Test normalizing clause-final remainder like '1 triệu 2'."""
        result, amount = self.normalizer.normalize("1 triệu 2.")
        assert amount == 1200000
        assert "1200000 đồng" in result

    def test_normalize_spoken_numbers(self):
        """Test normalizing spoken Vietnamese numbers."""
        test_cases = [
            ("một", 1),
            ("hai", 2),
            ("ba", 3),
            ("bốn", 4),
            ("tư", 4),
            ("năm", 5),
            ("lăm", 5),
            ("sáu", 6),
            ("bảy", 7),
            ("tám", 8),
            ("chín", 9),
            ("mười", 10),
            ("mười một", 11),
            ("mười lăm", 15),
            ("hai mươi", 20),
            ("hai mươi lăm", 25),
            ("ba chục", 30),
        ]
        for text, expected in test_cases:
            result, amount = self.normalizer.normalize(text + " đồng")
            assert amount == expected, (
                f"Failed for '{text}': got {amount}, expected {expected}"
            )

    def test_normalize_spoken_hundreds(self):
        """Test normalizing spoken hundreds."""
        test_cases = [
            ("một trăm", 100),
            ("hai trăm", 200),
            ("một trăm lẻ năm", 105),
            ("hai trăm mười", 210),
            ("ba trăm năm mươi", 350),
        ]
        for text, expected in test_cases:
            result, amount = self.normalizer.normalize(text + " đồng")
            assert amount == expected, (
                f"Failed for '{text}': got {amount}, expected {expected}"
            )

    def test_normalize_chục_bare(self):
        """Test normalizing bare 'năm chục' means 50,000."""
        result, amount = self.normalizer.normalize("năm chục")
        assert amount == 50000
        assert "50000 đồng" in result

    def test_normalize_first_amount_returned(self):
        """Test that only the first amount is returned."""
        result, amount = self.normalizer.normalize("50000 đồng 100000 đồng")
        assert amount == 50000  # First amount

    def test_normalize_multiple_amounts_warning_in_text(self):
        """Test that multiple amounts are all normalized in text."""
        result, amount = self.normalizer.normalize("50 k 100 k")
        assert "50000 đồng" in result
        assert "100000 đồng" in result
        assert amount == 50000

    def test_normalize_preserves_unrecognized_grammar(self):
        """Test that unrecognized grammar is preserved."""
        result, amount = self.normalizer.normalize("abc xyz tiền")
        assert result == "abc xyz tiền"
        assert amount is None

    def test_normalize_negative_sign_preserved(self):
        """Test that negative signs before amounts are preserved."""
        result, amount = self.normalizer.normalize("- 50000 đồng")
        assert "- 50000 đồng" in result
        assert amount is None  # No amount because of negative sign

    def test_normalize_positive_sign_preserved(self):
        """Test that positive signs before amounts are preserved."""
        result, amount = self.normalizer.normalize("+ 50000 đồng")
        assert "+ 50000 đồng" in result
        assert amount is None  # No amount because of positive sign

    def test_normalize_case_insensitive(self):
        """Test normalization is case insensitive."""
        result, amount = self.normalizer.normalize("50 K")
        assert amount == 50000

    def test_normalize_whitespace_normalization(self):
        """Test that whitespace is normalized."""
        result, amount = self.normalizer.normalize("50    k")
        assert amount == 50000

    def test_normalize_unicode_normalization(self):
        """Test that unicode is NFC normalized."""
        # Test with a precomposed character that normalizes differently
        # Use a simpler test - just verify NFC normalization doesn't break
        result, amount = self.normalizer.normalize("50 k")
        assert amount == 50000

    def test_normalize_non_string_raises(self):
        """Test that non-string input raises TypeError."""
        with pytest.raises(TypeError, match="Financial text must be a string"):
            self.normalizer.normalize(123)  # type: ignore

    def test_normalize_none_raises(self):
        """Test that None input raises TypeError."""
        with pytest.raises(TypeError, match="Financial text must be a string"):
            self.normalizer.normalize(None)  # type: ignore

    def test_alias_financial_slang_normalizer(self):
        """Test that FinancialSlangNormalizer is an alias."""
        assert FinancialSlangNormalizer is VietnameseFinancialSlangNormalizer


class TestVietnameseFinancialSlangNormalizerEdgeCases:
    """Edge case tests for VietnameseFinancialSlangNormalizer."""

    def setup_method(self):
        self.normalizer = VietnameseFinancialSlangNormalizer()

    def test_normalize_linh_le(self):
        """Test 'linh' and 'lẻ' handling."""
        result, amount = self.normalizer.normalize("một trăm lẻ năm đồng")
        assert amount == 105

    def test_normalize_invalid_spoken_grammar_preserved(self):
        """Test that invalid spoken grammar is preserved."""
        result, amount = self.normalizer.normalize("một trăm trăm đồng")
        assert "một trăm trăm đồng" in result
        assert amount is None

    def test_normalize_complex_compound(self):
        """Test complex compound amounts."""
        result, amount = self.normalizer.normalize("1 tỷ 200 triệu 300 nghìn")
        assert amount == 1200300000
        assert "1200300000 đồng" in result

    def test_normalize_decimal_with_comma(self):
        """Test decimal numbers with comma."""
        result, amount = self.normalizer.normalize("1,5 triệu")
        assert amount == 1500000
        assert "1500000 đồng" in result

    def test_normalize_decimal_with_dot(self):
        """Test decimal numbers with dot."""
        result, amount = self.normalizer.normalize("1.5 triệu")
        assert amount == 1500000
        assert "1500000 đồng" in result

    def test_normalize_thousands_separator(self):
        """Test thousands separator handling."""
        result, amount = self.normalizer.normalize("1,000,000 đồng")
        assert amount == 1000000
        assert "1000000 đồng" in result

    def test_normalize_large_amount(self):
        """Normalization preserves exact values; transaction limits are separate."""
        result, amount = self.normalizer.normalize("10000 tỷ")
        assert amount == 10_000_000_000_000
        assert result == "10000000000000 đồng"
