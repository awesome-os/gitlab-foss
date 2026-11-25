import { InMemoryCache } from '@apollo/client/core';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import cacheConfig from '~/ci/pipeline_details/jobs/graphql/cache_config';
import getPipelineJobsQuery from '~/ci/pipeline_details/jobs/graphql/queries/get_pipeline_jobs.query.graphql';
import getFailedJobsQuery from '~/ci/pipeline_details/jobs/graphql/queries/get_failed_jobs.query.graphql';
import { mockFailedJobsQueryResponse, mockPipelineJobsQueryResponse } from '../../mock_data';

const { project } = mockPipelineJobsQueryResponse.data;
const [jobTemplate] = project.pipeline.jobs.nodes;
const [failedJobTemplate] = mockFailedJobsQueryResponse.data.project.pipeline.jobs.nodes;

const jobsVariables = { fullPath: 'root/ci-project', iid: 1 };
const failedJobsVariables = { fullPath: 'root/ci-project', pipelineIid: 1 };

const pipelineData = (jobs) => ({
  project: { ...project, pipeline: { ...project.pipeline, jobs } },
});

const jobsPage = (ids, { hasNextPage = true } = {}) =>
  pipelineData({
    __typename: 'CiJobConnection',
    pageInfo: {
      __typename: 'PageInfo',
      startCursor: `cursor-${ids[0]}`,
      endCursor: `cursor-${ids.at(-1)}`,
      hasNextPage,
      hasPreviousPage: false,
    },
    nodes: ids.map((id) => ({ ...jobTemplate, id: `gid://gitlab/Ci::Build/${id}` })),
  });

const failedJobs = (ids) =>
  pipelineData({
    __typename: 'CiJobConnection',
    nodes: ids.map((id) => ({ ...failedJobTemplate, id: `gid://gitlab/Ci::Build/${id}` })),
  });

describe('Pipeline jobs cache config', () => {
  let cache;

  const writeJobs = (data, after) =>
    cache.writeQuery({
      query: getPipelineJobsQuery,
      variables: after ? { ...jobsVariables, after } : jobsVariables,
      data,
    });

  const writeFailedJobs = (data) =>
    cache.writeQuery({ query: getFailedJobsQuery, variables: failedJobsVariables, data });

  const readJobs = () =>
    cache.readQuery({ query: getPipelineJobsQuery, variables: jobsVariables }).project.pipeline
      .jobs;

  const readJobIds = () => readJobs().nodes.map(({ id }) => getIdFromGraphQLId(id));

  const readFailedJobIds = () =>
    cache
      .readQuery({ query: getFailedJobsQuery, variables: failedJobsVariables })
      .project.pipeline.jobs.nodes.map(({ id }) => getIdFromGraphQLId(id));

  beforeEach(() => {
    cache = new InMemoryCache(cacheConfig);
  });

  describe('when the first page loads', () => {
    it('stores the first page', () => {
      writeJobs(jobsPage([9, 8, 7]));

      expect(readJobIds()).toEqual([9, 8, 7]);
      expect(readJobs().pageInfo).toMatchObject({ endCursor: 'cursor-7', hasNextPage: true });
    });
  });

  describe('when the next page loads', () => {
    beforeEach(() => {
      writeJobs(jobsPage([9, 8, 7]));
    });

    it('appends the page and uses its page info', () => {
      writeJobs(jobsPage([6, 5, 4]), 'cursor-7');

      expect(readJobIds()).toEqual([9, 8, 7, 6, 5, 4]);
      expect(readJobs().pageInfo).toMatchObject({ endCursor: 'cursor-4', hasNextPage: true });
    });

    it('does not duplicate jobs when the page after the same cursor loads again', () => {
      writeJobs(jobsPage([6, 5, 4]), 'cursor-7');
      writeJobs(jobsPage([6, 5, 4]), 'cursor-7');

      expect(readJobIds()).toEqual([9, 8, 7, 6, 5, 4]);
      expect(readJobs().pageInfo).toMatchObject({ endCursor: 'cursor-4', hasNextPage: true });
    });
  });

  describe('when polling refetches the first page after more pages loaded', () => {
    beforeEach(() => {
      writeJobs(jobsPage([9, 8, 7]));
      writeJobs(jobsPage([6, 5, 4]), 'cursor-7');
    });

    it('keeps the loaded jobs when the first page is unchanged', () => {
      writeJobs(jobsPage([9, 8, 7]));

      expect(readJobIds()).toEqual([9, 8, 7, 6, 5, 4]);
      expect(readJobs().pageInfo).toMatchObject({ endCursor: 'cursor-4', hasNextPage: true });
    });

    it('adds a new job on top and keeps the loaded jobs and the last page cursor', () => {
      writeJobs(jobsPage([10, 9, 8]));

      expect(readJobIds()).toEqual([10, 9, 8, 7, 6, 5, 4]);
      expect(readJobs().pageInfo).toMatchObject({
        startCursor: 'cursor-10',
        endCursor: 'cursor-4',
        hasNextPage: true,
      });
    });

    it('drops a job that is no longer in the first page', () => {
      writeJobs(jobsPage([9, 7, 6]));

      expect(readJobIds()).toEqual([9, 7, 6, 5, 4]);
    });

    it('resets to the first page when it does not overlap the loaded jobs', () => {
      writeJobs(jobsPage([15, 14, 13]));

      expect(readJobIds()).toEqual([15, 14, 13]);
      expect(readJobs().pageInfo).toMatchObject({ endCursor: 'cursor-13', hasNextPage: true });
    });

    it('ignores a page requested before the reset', () => {
      writeJobs(jobsPage([15, 14, 13]));
      writeJobs(jobsPage([3, 2, 1]), 'cursor-4');

      expect(readJobIds()).toEqual([15, 14, 13]);
      expect(readJobs().pageInfo).toMatchObject({ endCursor: 'cursor-13', hasNextPage: true });
    });
  });

  describe('when polling refetches the first page after the last page loaded', () => {
    it('adds a new job on top and keeps all loaded jobs and the last page info', () => {
      writeJobs(jobsPage([9, 8, 7]));
      writeJobs(jobsPage([6, 5, 4], { hasNextPage: false }), 'cursor-7');
      writeJobs(jobsPage([10, 9, 8]));

      expect(readJobIds()).toEqual([10, 9, 8, 7, 6, 5, 4]);
      expect(readJobs().pageInfo).toMatchObject({ endCursor: 'cursor-4', hasNextPage: false });
    });
  });

  describe('when all jobs fit in one page', () => {
    it('replaces the stored jobs', () => {
      writeJobs(jobsPage([9, 8, 7], { hasNextPage: false }));
      writeJobs(jobsPage([10, 9], { hasNextPage: false }));

      expect(readJobIds()).toEqual([10, 9]);
    });
  });

  describe('failed jobs', () => {
    beforeEach(() => {
      writeJobs(jobsPage([9, 8, 7]));
      writeJobs(jobsPage([6, 5, 4]), 'cursor-7');
      writeFailedJobs(failedJobs([3, 1]));
    });

    it('stores the failed jobs separately from the jobs list', () => {
      expect(readFailedJobIds()).toEqual([3, 1]);
      expect(readJobIds()).toEqual([9, 8, 7, 6, 5, 4]);
    });

    it('replaces the failed jobs on refetch', () => {
      writeFailedJobs(failedJobs([3]));

      expect(readFailedJobIds()).toEqual([3]);
    });
  });
});
