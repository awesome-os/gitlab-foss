const os = require('os');
const { Worker, isMainThread, parentPort, workerData } = require('worker_threads');
const { program } = require('commander');
const glob = require('glob');

const { GettextExtractor, JsExtractors } = require('gettext-extractor');
const {
  decorateJSParserWithVueSupport,
  decorateExtractorWithHelpers,
} = require('gettext-extractor-vue');
const compilerSfc = require('@vue/compiler-sfc');
const vue3Template = require('../../config/vue3migration/compilers/vue3_template');
const { compatConfig } = require('../../app/assets/javascripts/lib/utils/vue3compat/compat_config');

// Compile templates the way the bundler does. The plain compiler crashes on some templates.
// Source maps are on by default but unused here, and generating them is a large share of runtime.
const vue3TemplateCompiler = {
  ...compilerSfc,
  parse: (source, options) => compilerSfc.parse(source, { ...options, sourceMap: false }),
  compileTemplate: (options) =>
    compilerSfc.compileTemplate({
      ...options,
      compiler: vue3Template,
      compilerOptions: { whitespace: 'preserve', compatConfig, sourceMap: false },
    }),
};

// Each worker loads its own copy of the TypeScript and Vue compilers, so more
// workers stop paying off quickly.
const MAX_WORKERS = 4;

program
  .option('-f, --file <file>', 'Extract message from one single file')
  .option('-a, --all', 'Extract message from all js/vue files');

const extractor = decorateExtractorWithHelpers(new GettextExtractor());

function ensureSingleLine(str) {
  // This guard makes the function significantly faster
  if (str.includes('\n') || str.includes('\r')) {
    return str
      .split(/\s*[\r\n]+\s*/)
      .filter((s) => s !== '')
      .join(' ');
  }
  return str;
}

extractor.addMessageTransformFunction(ensureSingleLine);

const jsParser = extractor.createJsParser([
  // Place all the possible expressions to extract here:
  JsExtractors.callExpression(['__', 's__'], {
    arguments: {
      text: 0,
    },
  }),
  JsExtractors.callExpression('n__', {
    arguments: {
      text: 0,
      textPlural: 1,
    },
  }),
]);

const vueParser = decorateJSParserWithVueSupport(jsParser, {
  vue3TemplateCompiler,
  // All of our expressions contain `__`.
  // So we can safely ignore parsing files _not_ containing it.
  guard: '__',
});

function collectMessages() {
  return extractor.getMessages().reduce((acc, message) => {
    let { text } = message;
    if (message.textPlural) {
      text += `\u0000${message.textPlural}`;
    }

    message.references.forEach((reference) => {
      const filename = reference.replace(/:\d+$/, '');

      if (!Array.isArray(acc[filename])) {
        acc[filename] = [];
      }

      acc[filename].push([text, reference]);
    });

    return acc;
  }, {});
}

function printJson(messages) {
  console.log(JSON.stringify(messages));
}

async function parseFiles(files) {
  for (const file of files) {
    // eslint-disable-next-line no-await-in-loop
    await vueParser.parseFile(file);
  }
  return collectMessages();
}

function parseFilesInWorker(files) {
  return new Promise((resolve, reject) => {
    const worker = new Worker(__filename, { workerData: files });
    worker.once('message', resolve);
    worker.once('error', reject);
    worker.once('exit', (code) => reject(new Error(`Worker exited with code ${code}`)));
  });
}

async function parseAllFiles() {
  const files = glob.sync('{ee/app,app}/assets/javascripts/**/*.{js,vue}');
  const workerCount = Math.min(os.availableParallelism(), MAX_WORKERS);
  const chunks = Array.from({ length: workerCount }, () => []);
  files.forEach((file, index) => chunks[index % workerCount].push(file));

  // Results are keyed by file and every file is parsed by exactly one worker, so keys never clash.
  const results = await Promise.all(chunks.map((chunk) => parseFilesInWorker(chunk)));
  return Object.assign({}, ...results);
}

async function main() {
  program.parse(process.argv);
  const args = program.opts();

  if (args.file) {
    return vueParser.parseFile(args.file).then(() => printJson(collectMessages()));
  }

  if (args.all) {
    return parseAllFiles().then(printJson);
  }

  throw new Error('ERROR: Please use the script correctly:');
}

if (isMainThread) {
  main().catch((error) => {
    console.warn(error.message);
    program.outputHelp();
    process.exit(1);
  });
} else {
  // Left unhandled on purpose: a rejection reaches the main thread as the worker's 'error' event.
  // eslint-disable-next-line promise/catch-or-return
  parseFiles(workerData).then((messages) => parentPort.postMessage(messages));
}
