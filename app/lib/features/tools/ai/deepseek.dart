class DeepSeek {
  static const endpoint = String.fromEnvironment(
    'UNIVERSAL_READER_DEEPSEEK_ENDPOINT',
    defaultValue: 'https://api.deepseek.com',
  );

  static const defaultModel = String.fromEnvironment(
    'UNIVERSAL_READER_DEEPSEEK_MODEL',
    defaultValue: 'deepseek-chat',
  );

  static const projectApiKey = String.fromEnvironment(
    'UNIVERSAL_READER_DEEPSEEK_API_KEY',
  );

  static const models = ['deepseek-chat', 'deepseek-reasoner'];
}
