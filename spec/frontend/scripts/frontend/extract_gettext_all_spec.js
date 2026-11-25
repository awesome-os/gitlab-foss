import { spawnSync } from 'child_process';
import { mkdtemp, mkdir, rm, writeFile } from 'fs/promises';
import { tmpdir } from 'os';
import { join, resolve } from 'path';

describe('frontend gettext extraction', () => {
  const script = resolve(__dirname, '../../../../scripts/frontend/extract_gettext_all.js');
  let directory;

  const extract = () =>
    spawnSync(process.execPath, [script, '--all'], {
      cwd: directory,
      encoding: 'utf8',
      timeout: 10000,
    });

  beforeEach(async () => {
    directory = await mkdtemp(join(tmpdir(), 'gettext-extraction-'));
    await mkdir(join(directory, 'app/assets/javascripts'), { recursive: true });
    await mkdir(join(directory, 'ee/app/assets/javascripts'), { recursive: true });
    await Promise.all([
      writeFile(join(directory, 'app/assets/javascripts/a.js'), "__('JavaScript');"),
      writeFile(
        join(directory, 'app/assets/javascripts/b.vue'),
        '<template><p>{{ s__("Context|Template") }}</p></template>',
      ),
      writeFile(join(directory, 'ee/app/assets/javascripts/c.js'), "n__('Item', 'Items', count);"),
      writeFile(
        join(directory, 'ee/app/assets/javascripts/d.vue'),
        '<script>export default { label: __("Vue script") };</script>',
      ),
    ]);
  });

  afterEach(async () => {
    await rm(directory, { recursive: true, force: true });
  });

  it('collects messages and references from every JavaScript and Vue file', () => {
    const { status, stdout, error } = extract();

    expect(error).toBeUndefined();
    expect(status).toBe(0);
    expect(JSON.parse(stdout)).toEqual({
      'app/assets/javascripts/a.js': [['JavaScript', 'app/assets/javascripts/a.js:1']],
      'app/assets/javascripts/b.vue': [['Context|Template', 'app/assets/javascripts/b.vue:5']],
      'ee/app/assets/javascripts/c.js': [['Item\u0000Items', 'ee/app/assets/javascripts/c.js:1']],
      'ee/app/assets/javascripts/d.vue': [['Vue script', 'ee/app/assets/javascripts/d.vue:1']],
    });
  });

  describe('when a worker cannot extract a file', () => {
    beforeEach(async () => {
      await writeFile(
        join(directory, 'app/assets/javascripts/a.js'),
        "n__('Item', 'Items', count); n__('Item', 'Other items', count);",
      );
    });

    it('exits with an error instead of returning partial results', () => {
      const { status, stdout, stderr, error } = extract();

      expect(error).toBeUndefined();
      expect(status).toBe(1);
      expect(stderr).toContain('Incompatible plurals');
      expect(() => JSON.parse(stdout)).toThrow(SyntaxError);
    });
  });
});
