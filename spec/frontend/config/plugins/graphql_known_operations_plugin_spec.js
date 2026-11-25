import GraphqlKnownOperationsPlugin from '../../../../config/plugins/graphql_known_operations_plugin';
import { evaluateModuleFromSource } from '../../../../config/helpers/evaluate_module_from_source';

jest.mock('../../../../config/helpers/evaluate_module_from_source', () => ({
  evaluateModuleFromSource: jest.fn(),
}));

const { evaluateModuleFromSource: actualEvaluateModuleFromSource } = jest.requireActual(
  '../../../../config/helpers/evaluate_module_from_source',
);

const getTappedCallback = (mockFn) => mockFn.mock.calls[0][1];

describe('GraphqlKnownOperationsPlugin - Directive Extraction', () => {
  let mockCompilation;
  let emitCallback;

  beforeEach(() => {
    evaluateModuleFromSource.mockImplementation(actualEvaluateModuleFromSource);

    const plugin = new GraphqlKnownOperationsPlugin({ filename: 'test-operations.yml' });

    mockCompilation = {
      modules: new Set(),
      errors: [],
      getAsset: jest.fn(() => null),
      updateAsset: jest.fn(),
      emitAsset: jest.fn(),
    };

    const mockCompiler = {
      hooks: {
        emit: {
          tap: jest.fn(),
        },
      },
    };

    plugin.apply(mockCompiler);

    emitCallback = getTappedCallback(mockCompiler.hooks.emit.tap);
  });

  const createModule = ({
    comments = '',
    operationName,
    operationType = 'query',
    resource = '/path/to/query.graphql',
    definitions,
    originalSource,
  } = {}) => {
    if (originalSource !== undefined) {
      return { resource, originalSource: () => originalSource };
    }

    const doc = {
      kind: 'Document',
      definitions: definitions ?? [
        {
          kind: 'OperationDefinition',
          operation: operationType,
          name: operationName
            ? {
                kind: 'Name',
                value: operationName,
              }
            : undefined,
          variableDefinitions: [],
          directives: [],
          selectionSet: {
            kind: 'SelectionSet',
            selections: [],
          },
        },
      ],
      loc: {
        start: 0,
        end: 10,
      },
    };

    const commentsWithTerminator = comments + (comments ? '\\' : '');
    const escapedComments = JSON.stringify(commentsWithTerminator);
    const graphqlSource = `var __comments = ${escapedComments};
var doc = ${JSON.stringify(doc)};
module.exports = doc;
`;

    return {
      resource,
      originalSource: () => ({
        source: () => Buffer.from(graphqlSource),
      }),
    };
  };

  const emitModule = (module) => {
    mockCompilation.modules.add(module);
    emitCallback(mockCompilation);
  };

  const getEmittedYaml = () => {
    const emitAssetCall = mockCompilation.emitAsset.mock.calls[0];
    if (!emitAssetCall) return null;
    const source = emitAssetCall[1];
    return source.source().toString();
  };

  const getPluginErrors = () => mockCompilation.errors;

  describe('extracting @feature_category directive', () => {
    it('extracts feature_category from GraphQL comment', () => {
      const comments = '# @feature_category: code_review';
      const module = createModule({ comments, operationName: 'GetMergeRequest' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('GetMergeRequest:');
      expect(yaml).toContain('feature_category: code_review');
    });

    it('extracts feature_category with underscores', () => {
      const comments = '# @feature_category: source_code_management';
      const module = createModule({ comments, operationName: 'GetRepository' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('GetRepository:');
      expect(yaml).toContain('feature_category: source_code_management');
    });

    it('handles missing feature_category directive', () => {
      const module = createModule({ operationName: 'GetProject' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('GetProject:');
      expect(yaml).toContain('feature_category: null');
    });
  });

  describe('extracting @urgency directive', () => {
    it('extracts urgency: high', () => {
      const comments = '# @urgency: high';
      const module = createModule({
        comments,
        operationName: 'UpdateIssue',
        operationType: 'mutation',
      });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('UpdateIssue:');
      expect(yaml).toContain('urgency: high');
    });

    it('extracts urgency: low', () => {
      const comments = '# @urgency: low';
      const module = createModule({ comments, operationName: 'GetStats' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('GetStats:');
      expect(yaml).toContain('urgency: low');
    });

    it('handles missing urgency directive (defaults to "default")', () => {
      const module = createModule({ operationName: 'GetIssue' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('GetIssue:');
      expect(yaml).toContain('urgency: default');
    });
  });

  describe('extracting both @feature_category and @urgency directives', () => {
    it('extracts both directives when present', () => {
      const comments = `# @feature_category: code_review
# @urgency: high`;
      const module = createModule({ comments, operationName: 'GetMergeRequest' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('GetMergeRequest:');
      expect(yaml).toContain('feature_category: code_review');
      expect(yaml).toContain('urgency: high');
    });

    it('extracts both directives with extra whitespace', () => {
      const comments = `#   @feature_category:   continuous_integration
#   @urgency:   high`;
      const module = createModule({ comments, operationName: 'GetPipeline' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('GetPipeline:');
      expect(yaml).toContain('feature_category: continuous_integration');
      expect(yaml).toContain('urgency: high');
    });

    it('extracts directives with other comments present', () => {
      const comments = `# This query fetches merge request data
# @feature_category: code_review
# TODO: Add pagination support
# @urgency: high
# Note: This is used in the MR widget`;
      const module = createModule({ comments, operationName: 'GetMergeRequestDetails' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('GetMergeRequestDetails:');
      expect(yaml).toContain('feature_category: code_review');
      expect(yaml).toContain('urgency: high');
    });
  });

  describe('regex extraction validation', () => {
    it('correctly extracts values with special characters', () => {
      const comments = '# @feature_category: continuous_integration';
      const module = createModule({ comments, operationName: 'GetPipeline' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('feature_category: continuous_integration');
    });

    it('stops extraction at newline', () => {
      const comments = `# @feature_category: code_review
# next line should not be included`;
      const module = createModule({ comments, operationName: 'GetMergeRequest' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('feature_category: code_review');
      expect(yaml).not.toContain('next line');
    });

    it('trims whitespace from extracted values', () => {
      const comments = `# @feature_category:    code_review
# @urgency:    low   `;
      const module = createModule({ comments, operationName: 'GetProject' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('feature_category: code_review');
      expect(yaml).toContain('urgency: low');
      expect(yaml).not.toMatch(/code_review\s+\n/);
    });

    it('only extracts the first match per directive', () => {
      const comments = `# @feature_category: code_review
# @feature_category: issues`;
      const module = createModule({ comments, operationName: 'GetMergeRequest' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('feature_category: code_review');
      expect(yaml).not.toContain('feature_category: issues');
    });

    it('handles colons in directive values', () => {
      const comments = '# @feature_category: code_review:mr_widget';
      const module = createModule({ comments, operationName: 'GetMergeRequest' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('feature_category: code_review:mr_widget');
    });

    it('quotes values that YAML 1.1 reads as booleans or numbers', () => {
      const comments = '# @feature_category: yes\n# @urgency: 1:30';
      const module = createModule({ comments, operationName: 'on' });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toBe("'on':\n  feature_category: 'yes'\n  urgency: '1:30'\n");
    });
  });

  describe('content-based operation detection', () => {
    it('picks up an operation in a plainly-named .graphql file', () => {
      const comments = '# @feature_category: code_review';
      const module = createModule({
        comments,
        operationName: 'GetMergeRequest',
        resource: '/path/to/some_plain_name.graphql',
      });

      emitModule(module);

      const yaml = getEmittedYaml();
      expect(yaml).toContain('GetMergeRequest:');
      expect(yaml).toContain('feature_category: code_review');
      expect(getPluginErrors()).toHaveLength(0);
    });

    it('does not error on a fragment-only file with a non-conforming name', () => {
      const module = createModule({
        resource: '/path/to/some_plain_name.graphql',
        definitions: [{ kind: 'FragmentDefinition' }],
      });

      emitModule(module);

      expect(getPluginErrors()).toHaveLength(0);
      expect(getEmittedYaml()).toBe('{}\n');
    });

    it('does not error on a typedefs-only file with a non-conforming name', () => {
      const module = createModule({
        resource: '/path/to/some_plain_name.graphql',
        definitions: [{ kind: 'ObjectTypeDefinition' }],
      });

      emitModule(module);

      expect(getPluginErrors()).toHaveLength(0);
      expect(getEmittedYaml()).toBe('{}\n');
    });

    it('does not error on an anonymous operation', () => {
      const module = createModule({ resource: '/path/to/some_plain_name.graphql' });

      emitModule(module);

      expect(getPluginErrors()).toHaveLength(0);
      expect(getEmittedYaml()).toBe('{}\n');
    });

    it('does not error when a module has no originalSource', () => {
      const module = createModule({
        resource: '/path/to/some_plain_name.graphql',
        originalSource: null,
      });

      emitModule(module);

      expect(getPluginErrors()).toHaveLength(0);
      expect(getEmittedYaml()).toBe('{}\n');
    });

    it('errors when a .graphql file contains no GraphQL definitions at all', () => {
      const module = createModule({ resource: '/path/to/unexpected.graphql', definitions: [] });

      expect(() => emitModule(module)).not.toThrow();

      expect(getPluginErrors()).toHaveLength(1);
      expect(getPluginErrors()[0].message).toContain('/path/to/unexpected.graphql');
      expect(getEmittedYaml()).toBe('{}\n');
    });
  });

  describe('across rebuilds', () => {
    const rebuild = () => {
      mockCompilation.errors = [];
      mockCompilation.emitAsset.mockClear();
      emitCallback(mockCompilation);
    };

    it('reuses the metadata of a module whose source has not changed', () => {
      emitModule(createModule({ operationName: 'GetMergeRequest' }));
      rebuild();

      expect(evaluateModuleFromSource).toHaveBeenCalledTimes(1);
      expect(getEmittedYaml()).toContain('GetMergeRequest:');
    });

    it('evaluates a module again when its source changes', () => {
      emitModule(createModule({ operationName: 'GetMergeRequest' }));
      mockCompilation.modules.clear();
      mockCompilation.modules.add(createModule({ operationName: 'GetMergeRequestDiffs' }));
      rebuild();

      expect(evaluateModuleFromSource).toHaveBeenCalledTimes(2);
      expect(getEmittedYaml()).toContain('GetMergeRequestDiffs:');
      expect(getEmittedYaml()).not.toContain('GetMergeRequest:');
    });

    it('reports a module without definitions on every rebuild', () => {
      emitModule(createModule({ resource: '/path/to/unexpected.graphql', definitions: [] }));
      rebuild();

      expect(getPluginErrors()).toHaveLength(1);
    });
  });
});
