Add-Type -AssemblyName System.Text
$path = 'D:\workspace\git-code\Universal-Reader\app\test\library_controller_test.dart'
$utf8 = New-Object System.Text.UTF8Encoding $false
$content = [System.IO.File]::ReadAllText($path, $utf8)

# Detect line ending
$lf = $false
if ($content.Contains("`r`n")) { $eol = "`r`n" } else { $eol = "`n" }

# Find the closing brace at end of file
$idx = $content.LastIndexOf('}')
if ($idx -lt 0) { Write-Output 'no closing brace found'; exit 1 }

# Split: take content up to last '}' inclusive (but exclude trailing whitespace)
# We want to insert new group BEFORE the last '}'.
$before = $content.Substring(0, $idx)
$after  = $content.Substring($idx)

$addition = @'

  group('importNamedBytes outcomes', () {
    test('returns cancelled for an empty file list', () async {
      final controller = PersistedLibraryController(
        repository: InMemoryLibraryRepository(),
      );
      await controller.load();

      final outcome = await controller.importNamedBytes(const []);

      expect(outcome.cancelled, isTrue);
      expect(outcome.count, 0);
      expect(outcome.failed, isFalse);
    });

    test(
      'returns imported with the actual count when at least one file is '
      'supported',
      () async {
        final controller = PersistedLibraryController(
          repository: InMemoryLibraryRepository(),
        );
        await controller.load();

        final outcome = await controller.importNamedBytes([
          (name: 'notes.txt', bytes: [1]),
          (name: 'rust.txt', bytes: [2, 3]),
        ]);

        expect(outcome.cancelled, isFalse);
        expect(outcome.failed, isFalse);
        expect(outcome.count, 2);
      },
    );

    test(
      'returns unsupported when every file is in an unknown format',
      () async {
        final controller = PersistedLibraryController(
          repository: InMemoryLibraryRepository(),
        );
        await controller.load();

        final outcome = await controller.importNamedBytes([
          (name: 'mystery.bin', bytes: [1, 2, 3]),
        ]);

        expect(outcome.cancelled, isFalse);
        expect(outcome.failed, isFalse);
        expect(outcome.count, 0);
      },
    );

    test(
      'returns failed when the repository import throws on every file',
      () async {
        final repository = _ThrowingLibraryRepository();
        final controller = PersistedLibraryController(
          repository: repository,
        );
        await controller.load();

        final outcome = await controller.importNamedBytes([
          (name: 'notes.txt', bytes: [1]),
        ]);

        expect(outcome.cancelled, isFalse);
        expect(outcome.failed, isTrue);
        expect(outcome.count, 0);
      },
    );
  });
'@

$newContent = $before + $addition + $after
[System.IO.File]::WriteAllText($path, $newContent, $utf8)
Write-Output 'done'
