// The only writable target is the disposable stack from tests/backend-e2e.
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

if (process.env.GITHUB_ACTIONS !== 'true' || !process.env.TEST_ANON_KEY) {
  throw new Error('Run the Backend Java E2E workflow with generated test credentials.');
}

const temporary = mkdtempSync(join(tmpdir(), 'kakeibo-postman-'));
try {
  const environment = join(temporary, 'environment.json');
  writeFileSync(environment, JSON.stringify({
    name: 'Disposable CI only',
    values: Object.entries({
      base_url: 'http://api:8000',
      supabase_url: 'http://gateway:8000',
      supabase_publishable_key: process.env.TEST_ANON_KEY,
      test_scope: 'disposable-ci',
    }).map(([key, value]) => ({ key, value, enabled: true })),
  }), { mode: 0o600 });

  const result = spawnSync('postman', [
    'collection', 'run', 'regression.postman_collection.json',
    '--environment', environment,
    '--bail', 'failure',
    '--timeout', '180000',
    '--timeout-request', '20000',
    '--timeout-script', '5000',
    '--no-report-events',
    '--reporters', 'cli,junit',
    '--reporter-junit-export', '/reports/postman.xml',
  ], { stdio: 'inherit', env: { ...process.env, CI: 'true' } });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
