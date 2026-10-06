import 'package:flutter/material.dart';
import '../models/category_envelope_data.dart';
import '../models/envelope_pillar.dart';

class PillarAllocationCard extends StatelessWidget {
  const PillarAllocationCard({super.key, required this.data});
  final CategoryEnvelopeData data;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: EnvelopeStyle.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 22,
              color: EnvelopeStyle.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Phân bổ 4 trụ cột Kakeibo',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${data.suggested ? 'Gợi ý' : 'Tổng'}:\n100%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: EnvelopeStyle.muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          label: EnvelopePillar.values
              .map((p) => '${p.label} ${data.percent(p).toStringAsFixed(1)}%')
              .join(', '),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 13,
              child: Row(
                children: [
                  for (final pillar in EnvelopePillar.values)
                    if (data.percent(pillar) > 0)
                      Expanded(
                        flex: (data.percent(pillar) * 100).round().clamp(
                          1,
                          10000,
                        ),
                        child: ColoredBox(
                          color: pillar.barColor,
                          child: const SizedBox.expand(),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < 2; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: _legend(EnvelopePillar.values[row * 2])),
                const SizedBox(width: 12),
                Expanded(child: _legend(EnvelopePillar.values[row * 2 + 1])),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EnvelopeStyle.soft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.spa_outlined,
                size: 18,
                color: EnvelopeStyle.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.suggested
                      ? 'Tỉ lệ gợi ý để bắt đầu. Tái cân bằng để lưu ngân sách của bạn.'
                      : '“Cân đối 4 phong bao giúp tâm an yên trước mọi biến thiên chi tiêu của đời sống thường nhật.”',
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    color: Color(0xFF414943),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _legend(EnvelopePillar pillar) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: pillar.barColor,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      Expanded(child: Text(pillar.label, style: const TextStyle(fontSize: 11))),
      Text(
        '${data.percent(pillar).toStringAsFixed(data.suggested ? 0 : 1).replaceAll('.0', '')}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: pillar.color,
        ),
      ),
    ],
  );
}
