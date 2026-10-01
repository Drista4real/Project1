import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class CashflowDeficitWarningCard extends StatelessWidget {
  const CashflowDeficitWarningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF7D6CC), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF9E3E26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CẢNH BÁO THÂM HỤT DÒNG TIỀN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Color(0xFF9E3E26),
                      ),
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textCharcoal,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(text: 'Số dư có nguy cơ âm '),
                          TextSpan(
                            text: '-500.000 ₫',
                            style: TextStyle(color: Color(0xFF9E3E26)),
                          ),
                          TextSpan(text: ' vào 20/11'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF6B453A),
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: 'Duy trì tốc độ chi hiện tại sẽ gây thiếu hụt. ',
                ),
                TextSpan(
                  text: 'Dự kiến:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:
                      ' Chi phí định kỳ (tiền nhà, hóa đơn) cộng cà phê & ăn ngoài vượt ',
                ),
                TextSpan(
                  text: '32%',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9E3E26),
                  ),
                ),
                TextSpan(text: ' hạn mức an toàn.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã kích hoạt chế độ chi tiêu tiết kiệm chánh niệm!',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shield_outlined, size: 16),
                  label: const Text(
                    'Kích hoạt tiết kiệm',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E3E26),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Chi tiết dự báo thâm hụt'),
                        content: const Text(
                          'Mô hình phát hiện 3 khoản chi lớn định kỳ rơi vào ngày 18-20/11: tiền thuê nhà (4.5tr), điện nước (850k) trong khi chi tiêu hàng ngày đang tăng 15% so với tuần trước.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Đã hiểu'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFDCD0),
                    foregroundColor: const Color(0xFF9E3E26),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Chi tiết',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
