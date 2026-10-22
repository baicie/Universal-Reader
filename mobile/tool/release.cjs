const { createHash } = require('node:crypto');
const { createReadStream } = require('node:fs');
const { appendFile, open, readFile, writeFile } = require('node:fs/promises');
const { basename } = require('node:path');

const VERSION_TAG = /^v\d+\.\d+\.\d+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const COMMIT = /^[0-9a-f]{40}$/i;

function resolveTag(eventName, ref, inputTag) {
  let tag;
  if (eventName === 'workflow_dispatch') {
    tag = inputTag;
    if (!tag) throw new Error('Manual releases require an explicit existing version tag.');
  } else if (eventName === 'push' && ref?.startsWith('refs/tags/')) {
    tag = ref.slice('refs/tags/'.length);
  } else {
    throw new Error('Releases must start from a version tag push or an explicit manual tag.');
  }
  if (typeof tag !== 'string' || /\s/.test(tag) || !VERSION_TAG.test(tag)) {
    throw new Error('Release tag must be a version such as v1.0.0 or v1.0.0-test.');
  }
  return tag;
}

function checkToken(token) {
  if (typeof token !== 'string' || !token.trim()) {
    throw new Error('EXPO_TOKEN is missing. Configure the EXPO_TOKEN GitHub repository secret with access to this Expo project before rerunning Release.');
  }
  if (/\s/.test(token)) {
    throw new Error('EXPO_TOKEN contains whitespace. Correct the GitHub repository secret before rerunning Release.');
  }
}

function validateArtifactUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error('EAS did not return a valid APK artifact URL.');
  }
  // Start at Expo's canonical artifact endpoint; curl may follow its HTTPS storage redirect.
  if (typeof value !== 'string' || url.href !== value || url.protocol !== 'https:' ||
      url.hostname !== 'expo.dev' || url.port || url.username || url.password || url.hash ||
      !/^\/artifacts\/eas\/[0-9A-Za-z_-]+\.apk$/.test(url.pathname)) {
    throw new Error('EAS APK artifact must use the HTTPS expo.dev/artifacts/eas endpoint.');
  }
  return value;
}

function validateBuild(result, expectedCommit, expectedProjectId) {
  if (typeof expectedCommit !== 'string' || expectedCommit.length !== 40 || !COMMIT.test(expectedCommit) ||
      typeof expectedProjectId !== 'string' || expectedProjectId.length !== 36 || !UUID.test(expectedProjectId)) {
    throw new Error('Expected source commit or Expo project ID is invalid.');
  }
  const builds = Array.isArray(result) ? result : [result];
  if (builds.length !== 1 || !builds[0] || typeof builds[0] !== 'object') {
    throw new Error('EAS must return exactly one Android build.');
  }
  const build = builds[0];
  if (typeof build.id !== 'string' || build.id.length !== 36 || !UUID.test(build.id)) {
    throw new Error('EAS returned an invalid build ID.');
  }
  if (typeof build.status !== 'string' || build.status.toUpperCase() !== 'FINISHED') {
    throw new Error('EAS build did not finish successfully. Inspect the EAS build logs.');
  }
  if (typeof build.platform !== 'string' || build.platform.toUpperCase() !== 'ANDROID') {
    throw new Error('EAS build is not an Android build.');
  }
  if (build.buildProfile !== 'preview' || build.app?.id !== expectedProjectId) {
    throw new Error('EAS build does not match the preview profile and configured Expo project.');
  }
  if (build.gitCommitHash !== expectedCommit) {
    throw new Error('EAS build source commit does not match the selected release tag.');
  }
  const artifactUrl = validateArtifactUrl(build.artifacts?.applicationArchiveUrl || build.artifacts?.buildUrl);
  return { id: build.id, artifactUrl };
}

async function checksumApk(path) {
  if (!path || basename(path) !== 'app.apk') throw new Error('Expected release asset app.apk.');
  const handle = await open(path, 'r');
  try {
    const signature = Buffer.alloc(4);
    const { bytesRead } = await handle.read(signature, 0, 4, 0);
    if (bytesRead !== 4 || !signature.equals(Buffer.from([0x50, 0x4b, 0x03, 0x04]))) {
      throw new Error('Downloaded artifact is not an APK ZIP archive.');
    }
  } finally {
    await handle.close();
  }
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  const checksum = `${hash.digest('hex')}  app.apk\n`;
  await writeFile(`${path}.sha256`, checksum, 'utf8');
  return checksum;
}

async function output(name, value) {
  if (!process.env.GITHUB_OUTPUT) throw new Error('GITHUB_OUTPUT is required.');
  await appendFile(process.env.GITHUB_OUTPUT, `${name}=${value}\n`, 'utf8');
}

async function main([command, ...args]) {
  switch (command) {
    case 'resolve-tag':
      await output('value', resolveTag(process.env.GITHUB_EVENT_NAME, process.env.GITHUB_REF, process.env.RELEASE_INPUT_TAG));
      break;
    case 'check-token':
      checkToken(process.env.EXPO_TOKEN);
      break;
    case 'validate-build': {
      const [resultPath, expectedCommit, configPath] = args;
      let result;
      let config;
      try {
        result = JSON.parse(await readFile(resultPath, 'utf8'));
        config = JSON.parse(await readFile(configPath, 'utf8'));
      } catch {
        throw new Error('Unable to read valid EAS build JSON and Expo app.json. No release will be published.');
      }
      const { id, artifactUrl } = validateBuild(result, expectedCommit, config.expo?.extra?.eas?.projectId);
      // Do not print build JSON or signed artifact URLs to public workflow logs.
      await output('artifact-url', artifactUrl);
      console.log(`Verified Android build ${id} for commit ${expectedCommit}.`);
      break;
    }
    case 'checksum':
      await checksumApk(args[0]);
      break;
    default:
      throw new Error('Unknown release helper command.');
  }
}

module.exports = { checkToken, checksumApk, resolveTag, validateArtifactUrl, validateBuild };

if (require.main === module) {
  main(process.argv.slice(2)).catch((error) => {
    console.error(`::error::${error.message}`);
    process.exitCode = 1;
  });
}
