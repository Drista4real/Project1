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
      base_url: 'https://postman-gateway:8443',
      supabase_url: 'https://postman-gateway:8443',
      supabase_publishable_key: process.env.TEST_ANON_KEY,
      test_scope: 'disposable-ci',
    }).map(([key, value]) => ({ key, value, enabled: true })),
  }), { mode: 0o600 });

  const result = spawnSync('/opt/postman/node_modules/@postman/pm-bin-linux-x64/bin/postman', [
    'collection', 'run', 'regression.postman_collection.json',
    '--environment', environment,
    '--bail', 'failure',
    '--timeout', '180000',
    '--timeout-request', '20000',
    '--timeout-script', '5000',
    '--ssl-extra-ca-certs', '/certs/ca.crt',
    '--no-report-events',
    '--reporters', 'cli,junit',
    '--reporter-junit-export', '/reports/postman.xml',
  ], { stdio: 'inherit', env: { ...process.env, CI: 'true' } });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  rmSync(temporary, { recursive: true, force: true });
}
