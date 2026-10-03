import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class AiInputBoxCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isAnalyzing;
  final VoidCallback onAnalyze;

  const AiInputBoxCard({
    required this.controller,
    required this.isAnalyzing,
    required this.onAnalyze,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.psychology_outlined,
                    size: 19,
                    color: AppTheme.primaryForestGreen,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Cú pháp tự nhiên hoặc giọng nói',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textCharcoal,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tiếng Việt đa ngữ',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          TextField(
            controller: controller,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textCharcoal,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Nhập nội dung thu chi...',
            ),
          ),

          const SizedBox(height: 12),

          // Action Pills: [Nói nhanh ●] [Hóa đơn] [Paste] [Phân tích]
          Row(
            children: [
              // Nói nhanh
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, size: 15, color: Color(0xFFB64F2D)),
                    SizedBox(width: 4),
                    Text(
                      'Nói nhanh',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textCharcoal,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.circle, size: 6, color: Color(0xFFB64F2D)),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Hóa đơn
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Tính năng quét hóa đơn OCR qua Camera.',
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 15,
                        color: AppTheme.textMuted,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Hóa đơn',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Paste clip
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.content_paste_outlined,
                  size: 18,
                  color: AppTheme.textMuted,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F1),
                  padding: const EdgeInsets.all(8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              const Spacer(),

              // Phân tích button
              FilledButton.icon(
                onPressed: isAnalyzing ? null : onAnalyze,
                icon: isAnalyzing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_fix_high, size: 15),
                label: const Text(
                  'Phân tích',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryForestGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
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
