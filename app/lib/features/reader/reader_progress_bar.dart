import 'package:flutter/material.dart';

/// Bottom progress strip shown while the reader chrome is visible.
class ReaderProgressBar extends StatelessWidget {
  const ReaderProgressBar({
    super.key,
    required this.progress,
    required this.label,
    required this.paper,
    required this.muted,
    required this.ink,
    required this.onSeek,
  });

  final double progress;
  final String label;
  final Color paper;
  final Color muted;
  final Color ink;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Material(
      color: paper,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(value: clamped, onChanged: onSeek),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                    Text(
                      '${(clamped * 100).round()}%',
                      style: TextStyle(
                        color: ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
