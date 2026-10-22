const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const { mkdtemp, readFile, rm, writeFile } = require('node:fs/promises');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const test = require('node:test');
const { checkToken, checksumApk, resolveTag, validateArtifactUrl, validateBuild } = require('./release.cjs');

const commit = 'a'.repeat(40);
const projectId = '7b26aada-985d-4a60-898d-69371e8ed989';
const artifactUrl = 'https://expo.dev/artifacts/eas/example123.apk';
function finishedBuild(overrides = {}) {
  return {
    id: 'a8fe47c9-b4b6-4c1d-a0f4-bbd1e883b433',
    status: 'FINISHED',
    platform: 'ANDROID',
    buildProfile: 'preview',
    app: { id: projectId },
    gitCommitHash: commit,
    artifacts: { applicationArchiveUrl: artifactUrl },
    ...overrides,
  };
}

test('tag pushes and manual dispatch select an explicit version tag', () => {
  assert.equal(resolveTag('push', 'refs/tags/v1.0.0-test', ''), 'v1.0.0-test');
  assert.equal(resolveTag('workflow_dispatch', 'refs/heads/main', 'v1.2.3'), 'v1.2.3');
  assert.equal(resolveTag('workflow_dispatch', 'refs/heads/main', 'v1.2.3-rc.1+123'), 'v1.2.3-rc.1+123');
});

test('manual dispatch never treats a branch or latest tag as the release target', () => {
  assert.throws(() => resolveTag('workflow_dispatch', 'refs/heads/main', ''), /explicit existing/);
  assert.throws(() => resolveTag('push', 'refs/heads/main', ''), /version tag push/);
  for (const tag of ['main', 'v1.0.0\n', 'v1.0.0\nvalue=injected', 'v1.0.0;exit 0', 'v1.0.0/other', ' v1.0.0']) {
    assert.throws(() => resolveTag('workflow_dispatch', 'refs/heads/main', tag), /Release tag/);
  }
});

test('missing or malformed Expo token fails without including its value', () => {
  for (const token of [undefined, '', ' \n\t']) assert.throws(() => checkToken(token), /EXPO_TOKEN is missing/);
  const malformed = 'fake-secret-value\n';
  assert.throws(() => checkToken(malformed), (error) => !error.message.includes('fake-secret-value'));
  assert.doesNotThrow(() => checkToken('fake-token'));
});

test('final EAS array and object responses accept uppercase and lowercase enum values', () => {
  assert.deepEqual(validateBuild([finishedBuild()], commit, projectId), {
    id: finishedBuild().id,
    artifactUrl,
  });
  assert.equal(validateBuild(finishedBuild({ status: 'finished', platform: 'android' }), commit, projectId).artifactUrl, artifactUrl);
  assert.equal(validateBuild(finishedBuild({ artifacts: { buildUrl: artifactUrl } }), commit, projectId).artifactUrl, artifactUrl);
});

test('unfinished, canceled, and failed builds cannot publish an artifact', () => {
  for (const status of ['NEW', 'IN_QUEUE', 'IN_PROGRESS', 'PENDING_CANCEL', 'CANCELED', 'ERRORED', undefined]) {
    assert.throws(() => validateBuild(finishedBuild({ status }), commit, projectId), /did not finish/);
  }
});

test('EAS response must contain one matching Android preview build from the selected commit', () => {
  for (const result of [null, [], [finishedBuild(), finishedBuild()], [null]]) {
    assert.throws(() => validateBuild(result, commit, projectId), /exactly one/);
  }
  for (const overrides of [
    { id: undefined }, { platform: 'IOS' }, { buildProfile: 'production' },
    { app: { id: 'another-project' } }, { gitCommitHash: 'b'.repeat(40) },
    { gitCommitHash: undefined }, { artifacts: {} },
  ]) {
    assert.throws(() => validateBuild(finishedBuild(overrides), commit, projectId));
  }
  assert.throws(() => validateBuild(finishedBuild(), '', projectId), /Expected source/);
});

test('artifact download starts only from a canonical HTTPS Expo APK URL', () => {
  assert.equal(validateArtifactUrl(artifactUrl), artifactUrl);
  assert.equal(validateArtifactUrl(`${artifactUrl}?token=example`), `${artifactUrl}?token=example`);
  for (const url of [
    undefined, '', 'not a URL', 'http://expo.dev/artifacts/eas/example.apk',
    'https://expo.dev.evil.example/artifacts/eas/example.apk',
    'https://user:password@expo.dev/artifacts/eas/example.apk',
    'https://expo.dev:8443/artifacts/eas/example.apk',
    'https://expo.dev/artifacts/eas/example.aab',
    'https://expo.dev/artifacts/eas/example.apk#fragment',
    `${artifactUrl}\ninjected=value`,
  ]) assert.throws(() => validateArtifactUrl(url));
});

test('CLI writes validated output and rejects malformed JSON without exposing artifact URLs', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'reader-release-cli-'));
  try {
    const resultPath = join(directory, 'build.json');
    const configPath = join(directory, 'app.json');
    const outputPath = join(directory, 'output');
    await writeFile(resultPath, JSON.stringify([finishedBuild()]));
    await writeFile(configPath, JSON.stringify({ expo: { extra: { eas: { projectId } } } }));
    const run = () => spawnSync(process.execPath, [join(__dirname, 'release.cjs'), 'validate-build', resultPath, commit, configPath], {
      encoding: 'utf8',
      env: { ...process.env, GITHUB_OUTPUT: outputPath },
    });
    const successful = run();
    assert.equal(successful.status, 0, successful.stderr);
    assert.equal(await readFile(outputPath, 'utf8'), `artifact-url=${artifactUrl}\n`);
    assert.equal(successful.stdout.includes(artifactUrl), false);
    await writeFile(resultPath, 'EAS failed, this is not JSON');
    const failed = run();
    assert.equal(failed.status, 1);
    assert.match(failed.stderr, /Unable to read valid EAS build JSON/);
    assert.equal(await readFile(outputPath, 'utf8'), `artifact-url=${artifactUrl}\n`);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('checksum covers the downloaded bytes and rejects HTTP error content', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'reader-release-'));
  try {
    const path = join(directory, 'app.apk');
    await writeFile(path, '<html>download failed</html>');
    await assert.rejects(checksumApk(path), /not an APK/);
    const bytes = Buffer.from([0x50, 0x4b, 0x03, 0x04, 1, 2, 3]);
    await writeFile(path, bytes);
    const expected = `${createHash('sha256').update(bytes).digest('hex')}  app.apk\n`;
    assert.equal(await checksumApk(path), expected);
    assert.equal(await readFile(`${path}.sha256`, 'utf8'), expected);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
