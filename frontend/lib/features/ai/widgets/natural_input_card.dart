import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_one/core/theme/app_theme.dart';

class NaturalInputCard extends StatelessWidget {
  const NaturalInputCard({
    required this.controller,
    required this.isAnalyzing,
    required this.onAnalyze,
    required this.onVoice,
    this.recording = false,
    this.voiceBusy = false,
    this.transcribing = false,
    this.voiceLevel = 0,
    this.heardSpeech = false,
    this.disabled = false,
    super.key,
  });

  final TextEditingController controller;
  final bool isAnalyzing, recording, voiceBusy, disabled;
  final bool transcribing, heardSpeech;
  final double voiceLevel;
  final VoidCallback onAnalyze, onVoice;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.psychology_outlined,
              size: 21,
              color: AppTheme.primaryForestGreen,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Cú pháp tự nhiên hoặc giọng nói',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.lightMintBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Tiếng Việt', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('aiInputText'),
          controller: controller,
          enabled: !disabled && !isAnalyzing && !voiceBusy && !recording,
          minLines: 3,
          maxLines: 5,
          maxLength: 2000,
          style: const TextStyle(fontSize: 17, height: 1.6),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            hintText: 'Ăn trưa bún bò 65k, uống trà sữa 35k chuyển khoản',
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: disabled || isAnalyzing || voiceBusy ? null : onVoice,
              style: TextButton.styleFrom(
                backgroundColor: recording
                    ? const Color(0xFFFFE9E0)
                    : AppTheme.lightMintBg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'BeVietnamPro',
                ),
              ),
              icon: Icon(
                recording ? Icons.stop_circle_outlined : Icons.mic_none,
                color: const Color(0xFFAD3F18),
                size: 18,
              ),
              label: Text(
                voiceBusy
                    ? (transcribing ? 'Đang phiên âm…' : 'Đang bật micro…')
                    : recording
                    ? 'Dừng ghi âm'
                    : 'Nói nhanh',
              ),
            ),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.camera_alt_outlined, size: 19),
              label: const Text('Hóa đơn'),
              style: OutlinedButton.styleFrom(
                side: BorderSide.none,
                backgroundColor: AppTheme.lightMintBg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'BeVietnamPro',
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dán nội dung',
              onPressed: disabled || isAnalyzing || recording || voiceBusy
                  ? null
                  : () async {
                      final data = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (context.mounted && data?.text != null) {
                        final text = data!.text!;
                        controller.text = text.substring(
                          0,
                          text.length.clamp(0, 2000),
                        );
                      }
                    },
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.lightMintBg,
              ),
              icon: const Icon(Icons.content_paste_outlined, size: 20),
            ),
            FilledButton.icon(
              onPressed: disabled || isAnalyzing || recording || voiceBusy
                  ? null
                  : onAnalyze,
              icon: isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high, size: 20),
              label: const Text('Phân tích'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 19,
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'BeVietnamPro',
                ),
              ),
            ),
          ],
        ),
        if (recording || voiceBusy) ...[
          const SizedBox(height: 12),
          if (recording) ...[
            LinearProgressIndicator(value: voiceLevel, minHeight: 5),
            const SizedBox(height: 8),
          ],
          Text(
            recording
                ? (heardSpeech
                      ? 'Đã nghe thấy tiếng. Ngừng nói khoảng 2 giây để chuyển thành chữ, hoặc nhấn Dừng ghi âm.'
                      : 'Micro đã bật. Hãy nói khi thanh âm lượng chuyển động; tối đa 20 giây.')
                : (transcribing
                      ? 'Đang chuyển lời nói thành chữ trên thiết bị. Giả lập có thể mất lâu hơn.'
                      : 'Đang chuẩn bị micro và model tiếng Việt. Chờ dòng “Micro đã bật” rồi nói.'),
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ],
    ),
  );
}
