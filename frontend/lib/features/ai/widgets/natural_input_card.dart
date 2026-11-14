import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NaturalInputCard extends StatelessWidget {
  const NaturalInputCard({
    required this.controller,
    required this.isAnalyzing,
    required this.onAnalyze,
    required this.onVoice,
    required this.onReceipt,
    this.recording = false,
    this.voiceBusy = false,
    this.transcribing = false,
    this.voiceLevel = 0,
    this.heardSpeech = false,
    this.disabled = false,
    this.analyzingReceipt = false,
    super.key,
  });

  final TextEditingController controller;
  final bool isAnalyzing, recording, voiceBusy, disabled;
  final bool transcribing, heardSpeech;
  final bool analyzingReceipt;
  final double voiceLevel;
  final VoidCallback onAnalyze, onVoice, onReceipt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final busy = disabled || isAnalyzing || recording || voiceBusy;
    final secondaryStyle = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      side: BorderSide(color: colors.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
    final voiceButton = OutlinedButton.icon(
      key: const ValueKey('aiVoiceButton'),
      onPressed: disabled || isAnalyzing || voiceBusy ? null : onVoice,
      style: recording
          ? secondaryStyle.copyWith(
              backgroundColor: WidgetStatePropertyAll(colors.errorContainer),
              foregroundColor: WidgetStatePropertyAll(colors.onErrorContainer),
            )
          : secondaryStyle,
      icon: Icon(
        recording ? Icons.stop_rounded : Icons.mic_none_rounded,
        size: 20,
      ),
      label: Text(recording ? 'Dừng ghi âm' : 'Ghi âm'),
    );
    final receiptButton = OutlinedButton.icon(
      key: const ValueKey('aiReceiptButton'),
      onPressed: busy ? null : onReceipt,
      style: secondaryStyle,
      icon: const Icon(Icons.image_outlined, size: 20),
      label: const Text('Ảnh hóa đơn'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Nội dung',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Dán nội dung',
                    child: TextButton.icon(
                      onPressed: busy
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
                      icon: const Icon(Icons.content_paste_outlined, size: 16),
                      label: const Text('Dán'),
                      style: TextButton.styleFrom(
                        textStyle: const TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              TextField(
                key: const ValueKey('aiInputText'),
                controller: controller,
                enabled: !busy,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                style: const TextStyle(fontSize: 16, height: 1.6),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  counterText: '',
                  hintText: 'Ví dụ: Ăn trưa 65k, cà phê 30k',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 280 ||
                MediaQuery.textScalerOf(context).scale(14) > 19) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  voiceButton,
                  const SizedBox(height: 10),
                  receiptButton,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: voiceButton),
                const SizedBox(width: 12),
                Expanded(child: receiptButton),
              ],
            );
          },
        ),
        if (recording || voiceBusy) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (recording) ...[
                    LinearProgressIndicator(
                      value: voiceLevel,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    recording
                        ? (heardSpeech
                              ? 'Đang nghe. Ngừng nói 2 giây để kết thúc.'
                              : 'Bạn nói nhé. Mỗi lần ghi tối đa 20 giây.')
                        : (transcribing
                              ? 'Đang chuyển giọng nói thành chữ…'
                              : 'Đang bật micro, bạn chờ một chút…'),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Ảnh được gửi đến dịch vụ AI để đọc hóa đơn.',
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => FilledButton.icon(
            key: const ValueKey('aiAnalyzeButton'),
            onPressed: busy || value.text.trim().isEmpty ? null : onAnalyze,
            iconAlignment: IconAlignment.end,
            icon: isAnalyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded, size: 20),
            label: Text(
              isAnalyzing
                  ? (analyzingReceipt ? 'Đang đọc hóa đơn…' : 'Đang xử lý…')
                  : 'Xem giao dịch',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              textStyle: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Bạn có thể sửa lại trước khi lưu.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
