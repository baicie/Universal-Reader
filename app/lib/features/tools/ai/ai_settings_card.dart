import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../l10n/l10n.dart';
import 'ai_settings.dart';
import 'deepseek.dart';
import 'ollama.dart';

class AiSettingsCard extends ConsumerStatefulWidget {
  const AiSettingsCard({super.key});

  @override
  ConsumerState<AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends ConsumerState<AiSettingsCard> {
  late final TextEditingController endpoint;
  late final TextEditingController apiKey;
  late final TextEditingController model;
  bool synced = false;

  @override
  void initState() {
    super.initState();
    endpoint = TextEditingController();
    apiKey = TextEditingController();
    model = TextEditingController();
  }

  @override
  void dispose() {
    endpoint.dispose();
    apiKey.dispose();
    model.dispose();
    super.dispose();
  }

  void _sync(AiSettings settings) {
    if (synced) return;
    final resolved = settings.withProjectDefaults();
    endpoint.text = resolved.endpoint;
    apiKey.text = resolved.apiKey;
    model.text = resolved.model;
    synced = true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(aiSettingsProvider);
    final settings = controller.settings.withProjectDefaults();
    if (!controller.loading && !synced) {
      _sync(settings);
    }
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final runtime = ref.watch(aiRuntimeProvider);
    final models = <String>{
      ...DeepSeek.models,
      if (settings.model.trim().isNotEmpty) settings.model.trim(),
    }.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.enableAssistant),
              subtitle: Text(l10n.enableAssistantSubtitle),
              value: settings.enabled,
              onChanged: (value) {
                controller.update(settings.copyWith(enabled: value));
              },
            ),
            DropdownButtonFormField<AiProvider>(
              initialValue: settings.provider,
              decoration: InputDecoration(labelText: l10n.assistantProvider),
              items: [
                DropdownMenuItem(
                  value: AiProvider.deepseek,
                  child: Text(l10n.providerDeepSeek),
                ),
                DropdownMenuItem(
                  value: AiProvider.ollama,
                  child: Text(l10n.providerOllama),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                controller.update(
                  settings.copyWith(provider: value, endpoint: '', model: ''),
                );
                synced = false;
              },
            ),
            const SizedBox(height: 12),
            if (settings.provider == AiProvider.deepseek)
              DropdownButtonFormField<String>(
                initialValue: models.contains(settings.model)
                    ? settings.model
                    : DeepSeek.defaultModel,
                decoration: InputDecoration(labelText: l10n.modelLabel),
                items: [
                  for (final model in models)
                    DropdownMenuItem(value: model, child: Text(model)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.update(settings.copyWith(model: value));
                  }
                },
              )
            else
              TextField(
                controller: model,
                decoration: InputDecoration(
                  labelText: l10n.modelLabel,
                  hintText: Ollama.defaultModel,
                ),
                onChanged: (value) {
                  controller.update(settings.copyWith(model: value));
                },
              ),
            const SizedBox(height: 12),
            if (!runtime.useGateway) ...[
              TextField(
                controller: endpoint,
                decoration: InputDecoration(
                  labelText: l10n.endpointLabel,
                  hintText: settings.provider == AiProvider.ollama
                      ? Ollama.endpoint
                      : DeepSeek.endpoint,
                ),
                onChanged: (value) {
                  controller.update(settings.copyWith(endpoint: value));
                },
              ),
              const SizedBox(height: 12),
            ],
            if (settings.provider == AiProvider.deepseek)
              TextField(
                controller: apiKey,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.apiKeyLabel,
                  hintText: runtime.serverHasKey
                      ? l10n.apiKeyOptionalHint
                      : l10n.apiKeyHint,
                ),
                onChanged: (value) {
                  controller.update(settings.copyWith(apiKey: value));
                },
              ),
            if (runtime.useGateway) ...[
              const SizedBox(height: 12),
              Text(
                l10n.assistantGatewayNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              l10n.assistantPrivacyNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
