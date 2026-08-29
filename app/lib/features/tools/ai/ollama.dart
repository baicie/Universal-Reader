class Ollama {
  static const endpoint = String.fromEnvironment(
    'UNIVERSAL_READER_OLLAMA_ENDPOINT',
    defaultValue: 'http://127.0.0.1:11434',
  );

  static const defaultModel = String.fromEnvironment(
    'UNIVERSAL_READER_OLLAMA_MODEL',
    defaultValue: 'llama3.2',
  );
}

enum AiProvider { deepseek, ollama }
