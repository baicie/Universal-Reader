import 'package:flutter/material.dart';

const selectionConfirmKey = Key('selection-confirm');

class SelectionConfirmBar extends StatelessWidget {
  const SelectionConfirmBar({
    required this.quote,
    required this.saveLabel,
    required this.onSave,
    required this.onDismiss,
    super.key,
  });

  final String quote;
  final String saveLabel;
  final VoidCallback onSave;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Material(
      key: selectionConfirmKey,
      color: theme.colorScheme.surface,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  quote.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ink, height: 1.4),
                ),
              ),
              TextButton(onPressed: onSave, child: Text(saveLabel)),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: onDismiss,
                icon: Icon(Icons.close, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
