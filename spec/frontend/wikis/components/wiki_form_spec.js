import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlAlert,
  GlButton,
  GlFormInput,
  GlFormGroup,
  GlCollapsibleListbox,
  GlForm,
  GlModal,
} from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import * as urlUtils from '~/lib/utils/url_utility';
import axios from '~/lib/utils/axios_utils';
import { mockTracking } from 'helpers/tracking_helper';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import WikiForm from '~/wikis/components/wiki_form.vue';
import WikiTemplate from '~/wikis/components/wiki_template.vue';
import DeleteWikiModal from '~/wikis/components/delete_wiki_modal.vue';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import ActionCableProvider from '~/collaborative_editing/action_cable_provider';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import CollaboratorsIndicator from '~/collaborative_editing/components/collaborators_indicator.vue';
import { EDITING_MODE_KEY, EDITING_MODE_CONTENT_EDITOR } from '~/vue_shared/constants';
import { WIKI_FORMAT_LABEL, WIKI_FORMAT_UPDATED_ACTION } from '~/wikis/constants';
import getAutoCommitMessagePreference from '~/wikis/graphql/auto_commit_message_preference.query.graphql';
import { DRAWIO_ORIGIN } from 'spec/test_constants';
import { ignoreConsoleMessages } from 'helpers/console_watcher';
import * as wikiUtils from '~/wikis/utils';
import { mockLocation, restoreLocation } from '../test_utils';

Vue.use(VueApollo);

jest.mock('~/emoji');
jest.mock('~/lib/graphql');
jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_action');
jest.mock('~/lib/utils/copy_to_clipboard');

describe('WikiForm', () => {
  ignoreConsoleMessages([/timers APIs are not replaced with fake timers/]);

  let wrapper;
  let mock;
  let trackingSpy;

  const findForm = () => wrapper.find('form');
  const findTitle = () => wrapper.find('#wiki_title');
  const findPath = () => wrapper.find('#wiki_path');
  const findFormat = () => wrapper.find('#wiki_format');
  const findMessageFormInput = () => wrapper.find("input[name='wiki[message]']");
  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findCancelButton = () => wrapper.findByTestId('wiki-cancel-button');
  const findTemplatesDropdown = () => wrapper.findComponent(WikiTemplate);
  const findPathGenerationToggle = () => wrapper.findComponentByTestId('path-generation-toggle');

  const getFormData = () => new FormData(findForm().element);

  const setFormat = (value) => {
    const format = findFormat();

    return format.find(`option[value=${value}]`).setSelected();
  };

  const inputTitle = (value) => wrapper.findByTestId('wiki-title-textbox').setValue(value);

  const triggerFormSubmit = async () => {
    findForm().element.dispatchEvent(new Event('submit'));

    await nextTick();
  };

  const pageInfoNew = {
    persisted: false,
    slug: '',
    uploadsPath: '/project/path/-/wikis/attachments',
    wikiPath: '/project/path/-/wikis',
    helpPath: '/help/user/project/wiki/_index',
    markdownHelpPath: '/help/user/markdown',
    markdownPreviewPath: '/project/path/-/wikis/.md/preview-markdown',
    createPath: '/project/path/-/wikis/new',
  };

  const pageInfoPersisted = {
    ...pageInfoNew,
    persisted: true,
    slug: 'My-page',
    title: 'My page',
    content: '  My page content  ',
    format: 'markdown',
    path: '/project/path/-/wikis/home',
    containerFullPath: 'group/project',
    lastCommitSha: 'page-commit',
  };

  const pageInfoEditSidebar = {
    ...pageInfoNew,
    persisted: true,
    slug: '_sidebar',
    title: '_sidebar',
    content: '  My page content  ',
    format: 'markdown',
    path: '/project/path/-/wikis/_sidebar/edit',
  };

  const pageInfoNewSidebar = {
    ...pageInfoNew,
    persisted: false,
    slug: '_sidebar',
    title: '_sidebar',
    path: '/project/path/-/wikis/_sidebar',
  };

  const pageInfoWithFrontmatter = () => ({
    frontMatter: { foo: 'bar', title: 'real page title' },
    persisted: true,
    lastCommitSha: 'abcdef123',
    slug: 'foo/bar',
    title: 'bar',
    content: 'foo bar',
  });

  const formatOptions = {
    Markdown: 'markdown',
    RDoc: 'rdoc',
    AsciiDoc: 'asciidoc',
    Org: 'org',
  };
  function createWrapper({
    mountFn = shallowMountExtended,
    persisted = false,
    pageInfo,
    provide = {},
    templates = [],
    autoCommitMessageQueryHandler,
    stubs = {},
    propsData = {},
    mocks = {},
  } = {}) {
    const apolloProvider = createMockApollo([
      [
        getAutoCommitMessagePreference,
        autoCommitMessageQueryHandler ||
          jest.fn().mockResolvedValue({
            data: { currentUser: { id: '1', userPreferences: { wikiUseAutoCommitMessage: true } } },
          }),
      ],
    ]);

    wrapper = mountFn(WikiForm, {
      apolloProvider,
      propsData,
      provide: {
        templates,
        formatOptions,
        pageInfo: {
          ...(persisted ? pageInfoPersisted : pageInfoNew),
          ...pageInfo,
        },
        wikiUrl: '',
        historyUrl: '',
        templatesUrl: '',
        pageHeading: '',
        csrfToken: '',
        pagePersisted: false,
        drawioUrl: null,
        ...provide,
      },
      stubs: {
        GlAlert,
        GlButton,
        GlFormInput,
        GlFormGroup,
        GlForm,
        GlModal,
        PanelActionsPortal: {
          name: 'PanelActionsPortal',
          template: '<div data-testid="panel-actions-portal"><slot></slot></div>',
        },
        ...stubs,
      },
      mocks,
    });
  }

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue(null);

    trackingSpy = mockTracking(undefined, null, jest.spyOn);
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
    localStorage.clear();
  });

  it('displays markdown editor', () => {
    createWrapper({ persisted: true });

    const markdownEditor = findMarkdownEditor();

    expect(markdownEditor.props()).toEqual(
      expect.objectContaining({
        value: pageInfoPersisted.content,
        renderMarkdownPath: pageInfoPersisted.markdownPreviewPath,
        uploadsPath: pageInfoPersisted.uploadsPath,
        autofocus: pageInfoPersisted.persisted,
        immersive: true,
        supportsTableOfContents: true,
      }),
    );

    expect(markdownEditor.props('formFieldProps')).toMatchObject({
      id: 'wiki_content',
    });
  });

  it('empties the title field if random_title=true is set in the URL', () => {
    mockLocation('http://gitlab.com/gitlab-org/gitlab/-/wikis/new?random_title=true');

    createWrapper({ persisted: true, mountFn: mountExtended });

    expect(findTitle().element.value).toBe('');

    restoreLocation();
  });

  it('enables immersive mode on markdown editor', () => {
    createWrapper();

    expect(findMarkdownEditor().props().immersive).toBe(true);
  });

  it('passes the form actions to the markdown editor #header slot', () => {
    createWrapper();

    expect(findMarkdownEditor().find('[data-testid="wiki-form-actions"]').exists()).toBe(true);
  });

  it('renders the save and cancel buttons as panel actions', () => {
    createWrapper({ mountFn: mountExtended });

    const panelActions = wrapper.findByTestId('panel-actions-portal');

    expect(panelActions.find('[data-testid="wiki-submit-button"]').exists()).toBe(true);
    expect(panelActions.find('[data-testid="wiki-submit-message-mode"]').exists()).toBe(true);
    expect(panelActions.find('[data-testid="wiki-cancel-button"]').exists()).toBe(true);
  });

  it('does not render the delete wiki modal', () => {
    createWrapper();

    expect(wrapper.findComponent(DeleteWikiModal).exists()).toBe(false);
  });

  describe('when wiki page is a template', () => {
    beforeEach(() => {
      mockLocation('http://gitlab.com/gitlab-org/gitlab/-/wikis/templates/abc');
    });

    afterEach(() => {
      restoreLocation();
    });

    it('makes sure commit message includes "Create template" for a new page', async () => {
      createWrapper({ persisted: false, mountFn: mountExtended });

      await inputTitle('my page');

      expect(findMessageFormInput().attributes('value')).toBe('Create template my page');
    });

    it('makes sure commit message includes "Update template" for an existing page', async () => {
      createWrapper({ persisted: true, mountFn: mountExtended });

      await inputTitle('my page');

      expect(findMessageFormInput().attributes('value')).toBe('Update template my page');
    });

    it('does not show any help text for title', () => {
      createWrapper({ persisted: true });

      expect(wrapper.text()).not.toContain(
        'You can move this page by adding the path to the beginning of the title.',
      );
      expect(wrapper.text()).not.toContain(
        'You can specify the full path for the new file. We will automatically create any missing directories.',
      );
    });

    it('does not show templates dropdown', () => {
      createWrapper({ persisted: true });

      expect(findTemplatesDropdown().exists()).toBe(false);
    });

    it('shows placeholder for title field', () => {
      createWrapper({ persisted: true });

      expect(findTitle().attributes('placeholder')).toBe('Template title');
    });

    it('disables file attachments', () => {
      createWrapper({ persisted: true });

      expect(findMarkdownEditor().props('disableAttachments')).toBe(true);
    });

    it('renders the delete wiki modal', () => {
      createWrapper({ persisted: true });

      expect(wrapper.findComponent(DeleteWikiModal).exists()).toBe(true);
    });
  });

  describe('templates dropdown', () => {
    const templates = [
      { title: 'Markdown template 1', format: 'markdown', path: '/project/path/-/wikis/template1' },
      { title: 'Markdown template 2', format: 'markdown', path: '/project/path/-/wikis/template2' },
      { title: 'Rdoc template', format: 'rdoc', path: '/project/path/-/wikis/template3' },
      { title: 'Asciidoc template', format: 'asciidoc', path: '/project/path/-/wikis/template4' },
      { title: 'Org template', format: 'org', path: '/project/path/-/wikis/template5' },
    ];

    it('shows the dropdown when page is not a template', () => {
      createWrapper({ templates, mountFn: mountExtended });

      expect(findTemplatesDropdown().exists()).toBe(true);
    });

    it('shows templates dropdown even if no templates to show', () => {
      createWrapper({ mountFn: mountExtended });

      expect(findTemplatesDropdown().exists()).toBe(true);
    });

    it.each`
      format        | visibleTemplates
      ${'markdown'} | ${['Markdown template 1', 'Markdown template 2']}
      ${'rdoc'}     | ${['Rdoc template']}
      ${'asciidoc'} | ${['Asciidoc template']}
      ${'org'}      | ${['Org template']}
    `('shows appropriate templates for format $format', async ({ format, visibleTemplates }) => {
      createWrapper({ templates, mountFn: mountExtended });

      await setFormat(format);

      expect(
        findTemplatesDropdown()
          .findComponent(GlCollapsibleListbox)
          .props('items')
          .map(({ text }) => text),
      ).toEqual(visibleTemplates);
    });
  });

  it.each`
    title                | persisted | message
    ${'my page'}         | ${false}  | ${'Create my page'}
    ${'my-page'}         | ${false}  | ${'Create my page'}
    ${'somedir/my-page'} | ${false}  | ${'Create somedir/my page'}
    ${'my-page'}         | ${true}   | ${'Update my page'}
  `(
    'updates the commit message to $message when title is $title and persisted=$persisted',
    async ({ title, message, persisted }) => {
      createWrapper({ persisted, mountFn: mountExtended });

      await findTitle().setValue(title);

      expect(findMessageFormInput().attributes('value')).toBe(message);
    },
  );

  it('sets the commit message to "Update My page" when the page first loads when persisted', async () => {
    createWrapper({ persisted: true, mountFn: mountExtended });

    await nextTick();

    expect(findMessageFormInput().attributes('value')).toBe('Update My page');
  });

  it('does not trim page content by default', () => {
    createWrapper({ persisted: true });

    expect(findMarkdownEditor().props().value).toBe('  My page content  ');
  });

  it.each`
    format        | enabled  | action
    ${'markdown'} | ${true}  | ${'displays'}
    ${'rdoc'}     | ${false} | ${'hides'}
    ${'asciidoc'} | ${false} | ${'hides'}
    ${'org'}      | ${false} | ${'hides'}
  `('$action preview in the markdown field when format is $format', async ({ format, enabled }) => {
    createWrapper({ mountFn: mountExtended });

    await setFormat(format);

    expect(findMarkdownEditor().vm.$attrs['enable-preview']).toBe(enabled);
  });

  describe('when wiki content is updated', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended, persisted: true });

      await findMarkdownEditor().vm.$emit('input', ' Lorem ipsum dolar sit! ');
    });

    describe('form submit', () => {
      beforeEach(async () => {
        await triggerFormSubmit();
      });

      it('submits the content', () => {
        expect([...getFormData().entries()]).toEqual([
          ['authenticity_token', ''],
          ['_method', 'put'],
          ['wiki[last_commit_sha]', 'page-commit'],
          ['wiki[message]', 'Update My page'],
          ['wiki[title]', 'My-page'],
          ['wiki[format]', 'markdown'],
          ['wiki[content]', ' Lorem ipsum dolar sit! '],
        ]);
      });

      it('triggers wiki format tracking event', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'wiki_format_updated', {
          extra: {
            old_format: 'markdown',
            project_path: '/project/path/-/wikis/home',
            value: 'markdown',
          },
          label: 'wiki_format',
        });
      });

      it('tracks editor type used', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'save_markdown', {
          label: 'markdown_editor',
          property: 'Wiki',
        });
      });

      it('does not trim page content', () => {
        expect(findMarkdownEditor().props().value).toBe(' Lorem ipsum dolar sit! ');
      });
    });
  });

  describe('cancel button', () => {
    it.each([true, false])('does not have an href when persisted=%s', (persisted) => {
      createWrapper({ persisted });

      expect(findCancelButton().attributes().href).toBeUndefined();
    });

    it('emits is-editing=false when clicked', async () => {
      createWrapper();

      await findCancelButton().trigger('click');

      expect(wrapper.emitted('is-editing')).toEqual([[false]]);
    });
  });

  it.each`
    format        | enabled  | action
    ${'markdown'} | ${true}  | ${'enables'}
    ${'rdoc'}     | ${false} | ${'disables'}
    ${'asciidoc'} | ${false} | ${'disables'}
    ${'org'}      | ${false} | ${'disables'}
  `('$action content editor when format is $format', async ({ format, enabled }) => {
    createWrapper({ mountFn: mountExtended });

    setFormat(format);

    await nextTick();

    expect(findMarkdownEditor().props().enableContentEditor).toBe(enabled);
  });

  describe('when markdown editor activates the content editor', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mountExtended, persisted: true });

      await findMarkdownEditor().vm.$emit('content-editor');
    });

    it('disables the format dropdown', () => {
      expect(findFormat().element.getAttribute('disabled')).toBeDefined();
    });

    describe('when triggering form submit', () => {
      const updatedMarkdown = 'hello **world**';

      beforeEach(async () => {
        findMarkdownEditor().vm.$emit('input', updatedMarkdown);
        await triggerFormSubmit();
      });

      it('triggers tracking events on form submit', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, WIKI_FORMAT_UPDATED_ACTION, {
          label: WIKI_FORMAT_LABEL,
          extra: {
            value: findFormat().element.value,
            old_format: pageInfoPersisted.format,
            project_path: pageInfoPersisted.path,
          },
        });
      });
    });
  });

  describe('when drawioURL is provided', () => {
    it('enables drawio editor in the Markdown Editor', () => {
      createWrapper({ provide: { drawioUrl: DRAWIO_ORIGIN } });

      expect(findMarkdownEditor().props().drawioEnabled).toBe(true);
    });
  });

  describe('when drawioURL is empty', () => {
    it('disables drawio editor in the Markdown Editor', () => {
      createWrapper();

      expect(findMarkdownEditor().props().drawioEnabled).toBe(false);
    });
  });

  describe('path field', () => {
    beforeEach(() => {
      createWrapper({
        mountFn: mountExtended,
        pageInfo: pageInfoWithFrontmatter(),
      });
    });

    it('shows the path field', () => {
      expect(findPath().exists()).toBe(true);
    });

    it("retains page's frontmatter on form submit", async () => {
      await findForm().trigger('submit');

      expect([...getFormData().entries()]).toEqual([
        ['authenticity_token', ''],
        ['_method', 'put'],
        ['wiki[last_commit_sha]', 'abcdef123'],
        ['wiki[message]', 'Update real page title'],
        ['wiki[title]', 'foo/bar'],
        ['wiki[format]', 'markdown'],
        ['wiki[content]', '---\nfoo: bar\ntitle: real page title\n---\nfoo bar'],
      ]);
    });

    describe('if generate path from title is unchecked', () => {
      it("saves page's title in frontmatter on submit", async () => {
        await findTitle().setValue('new title');
        await findForm().trigger('submit');

        expect([...getFormData().entries()]).toEqual([
          ['authenticity_token', ''],
          ['_method', 'put'],
          ['wiki[last_commit_sha]', 'abcdef123'],
          ['wiki[message]', 'Update new title'],
          ['wiki[title]', 'foo/bar'],
          ['wiki[format]', 'markdown'],
          ['wiki[content]', '---\nfoo: bar\ntitle: new title\n---\nfoo bar'],
        ]);
      });

      it.each(['yes', 'on', '2026-01-01', '1:30'])(
        'quotes the title "%s", which YAML 1.1 does not read as a string',
        async (title) => {
          await findTitle().setValue(title);
          await findForm().trigger('submit');

          expect([...getFormData().entries()]).toContainEqual([
            'wiki[content]',
            `---\nfoo: bar\ntitle: '${title}'\n---\nfoo bar`,
          ]);
        },
      );
    });
  });

  describe('title placeholder functionality', () => {
    const pageInfoWithNewPageTitle = {
      persisted: false,
      slug: 'parent/path/{new_page_title}',
      title: 'parent/path/{new_page_title}',
      uploadsPath: '/project/path/-/wikis/attachments',
      wikiPath: '/project/path/-/wikis',
      helpPath: '/help/user/project/wiki/_index',
      markdownHelpPath: '/help/user/markdown',
      markdownPreviewPath: '/project/path/-/wikis/.md/preview-markdown',
      createPath: '/project/path/-/wikis/new',
    };

    describe('when creating a new page with placeholder in title', () => {
      beforeEach(() => {
        createWrapper({
          mountFn: mountExtended,
          pageInfo: pageInfoWithNewPageTitle,
        });
      });

      it('renders the correct initial value in the title input', () => {
        expect(findTitle().element.value).toBe('{Give this page a title}');
      });

      it('sets the path to the parent path', () => {
        expect(findPath().element.value).toBe('parent/path/');
      });

      it('clears placeholder when user starts typing', async () => {
        await findTitle().setValue('My New Page');
        expect(findTitle().element.value).toBe('My New Page');
      });

      it('clears placeholder when user presses a printable key', async () => {
        await findTitle().trigger('focus');
        await findTitle().trigger('keydown', {
          key: 'M',
          ctrlKey: false,
          metaKey: false,
          altKey: false,
        });
        expect(findTitle().element.value).toBe('');
      });

      it('does not clear placeholder for non-printable keys', async () => {
        await findTitle().trigger('focus');
        await findTitle().trigger('keydown', {
          key: 'Enter',
          ctrlKey: false,
          metaKey: false,
          altKey: false,
        });
        expect(findTitle().element.value).toBe('{Give this page a title}');
      });

      it('does not clear placeholder for modifier key combinations', async () => {
        await findTitle().trigger('focus');
        await findTitle().trigger('keydown', {
          key: 'a',
          ctrlKey: true,
          metaKey: false,
          altKey: false,
        });
        expect(findTitle().element.value).toBe('{Give this page a title}');
      });
    });

    describe('when creating a new page with parent and a custom path', () => {
      beforeEach(async () => {
        createWrapper({
          mountFn: mountExtended,
          pageInfo: pageInfoWithNewPageTitle,
        });

        await nextTick();
      });

      it('does not overwrite a custom path when generating path from title is disabled', async () => {
        findPathGenerationToggle().vm.$emit('change', false);
        await nextTick();

        findPath().setValue('parent/path/custom-slug');
        await nextTick();

        await findTitle().setValue('My New Page');
        await nextTick();

        expect(findPath().element.value).toBe('parent/path/custom-slug');
      });

      it('restores parent path in generated path when re-enabling path generation', async () => {
        await findTitle().setValue('My New Page');
        await nextTick();

        findPathGenerationToggle().vm.$emit('change', false);
        await nextTick();

        findPathGenerationToggle().vm.$emit('change', true);
        await nextTick();

        expect(findPath().element.value).toBe('parent/path/My-New-Page');
      });
    });

    describe('when creating a new page without placeholder in title', () => {
      const pageInfoWithoutPlaceholder = {
        persisted: false,
        slug: 'normal-page',
        title: 'normal-page',
        uploadsPath: '/project/path/-/wikis/attachments',
        wikiPath: '/project/path/-/wikis',
        helpPath: '/help/user/project/wiki/_index',
        markdownHelpPath: '/help/user/markdown',
        markdownPreviewPath: '/project/path/-/wikis/.md/preview-markdown',
        createPath: '/project/path/-/wikis/new',
      };

      beforeEach(() => {
        createWrapper({
          mountFn: mountExtended,
          pageInfo: pageInfoWithoutPlaceholder,
        });
      });

      it('renders the correct initial value in the title input', () => {
        expect(findTitle().element.value).toBe('normal-page');
      });

      it('handles normal input without placeholder logic', async () => {
        await findTitle().setValue('updated-title');
        expect(findTitle().element.value).toBe('updated-title');
      });
    });

    describe('when editing an existing page', () => {
      beforeEach(() => {
        createWrapper({
          mountFn: mountExtended,
          persisted: true,
        });
      });

      it('renders the correct initial value in the title input', () => {
        expect(findTitle().element.value).not.toBe('parent/path/{Give this page a title}');
      });

      it('handles input normally without placeholder logic', async () => {
        await findTitle().setValue('updated-title');
        expect(findTitle().element.value).toBe('updated-title');
      });
    });
  });

  describe('title newline prevention', () => {
    beforeEach(() => {
      createWrapper({
        mountFn: mountExtended,
        persisted: true,
      });
    });

    it('prevents Enter key from inserting a newline', () => {
      const titleInput = findTitle();
      const event = new KeyboardEvent('keydown', { key: 'Enter', cancelable: true });
      titleInput.element.dispatchEvent(event);

      expect(event.defaultPrevented).toBe(true);
    });

    it('does not submit the form on Enter alone', async () => {
      const submitSpy = jest.spyOn(findForm().element, 'submit').mockImplementation(() => {});
      findTitle().element.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
      await waitForPromises();

      expect(submitSpy).not.toHaveBeenCalled();
    });

    it.each(['ctrlKey', 'metaKey'])('submits the form on %s+Enter', async (modifier) => {
      const submitSpy = jest.spyOn(findForm().element, 'submit').mockImplementation(() => {});
      findTitle().element.dispatchEvent(
        new KeyboardEvent('keydown', { key: 'Enter', [modifier]: true }),
      );
      await waitForPromises();

      expect(submitSpy).toHaveBeenCalled();
    });

    it('replaces newlines with spaces in pasted content', async () => {
      await inputTitle('line1\nline2\rline3\u2028line4\u2029line5');

      expect(findTitle().element.value).toBe('line1 line2 line3 line4 line5');
    });
  });

  describe.each`
    case                                                                                                                | isTemplateUrl | persisted | originalTitle                          | originalPath                           | titleInput       | expectedTitle    | expectedPath
    ${'new page: user enters parent path and title -> saves as entered'}                                                | ${false}      | ${false}  | ${'parent/path/{new_page_title}'}      | ${'parent/path/{new_page_title}'}      | ${'My page'}     | ${'My page'}     | ${'parent/path/My-page'}
    ${'new page: user enters title: generates path from title'}                                                         | ${false}      | ${false}  | ${''}                                  | ${''}                                  | ${'My page'}     | ${'My page'}     | ${'My-page'}
    ${'new page: user does not enter title -> auto-generates both path and title'}                                      | ${false}      | ${false}  | ${''}                                  | ${''}                                  | ${''}            | ${'Untitled'}    | ${'untitled-20230730042400'}
    ${'new page with existing title and no path: user updates title -> generates path from title'}                      | ${false}      | ${false}  | ${'Foo'}                               | ${''}                                  | ${'Bar'}         | ${'Bar'}         | ${'Bar'}
    ${'new page with existing title and path: user updates title -> regenerates path from title'}                       | ${false}      | ${false}  | ${'Foo'}                               | ${'foo'}                               | ${'Bar'}         | ${'Bar'}         | ${'Bar'}
    ${'new page with existing title and no path: user removes title -> generates path from untitled title'}             | ${false}      | ${false}  | ${'Foo'}                               | ${''}                                  | ${''}            | ${'Untitled'}    | ${'untitled-20230730042400'}
    ${'new page without title but with path: user does nothing -> generates title and keeps existing path'}             | ${false}      | ${false}  | ${''}                                  | ${'bar'}                               | ${''}            | ${'Untitled'}    | ${'bar'}
    ${'new page without title but with path: user enters title -> regenerates path from title'}                         | ${false}      | ${false}  | ${''}                                  | ${'bar'}                               | ${'Foo'}         | ${'Foo'}         | ${'Foo'}
    ${'existing page: user updates title -> keeps path'}                                                                | ${false}      | ${true}   | ${'Foo'}                               | ${'foo'}                               | ${'Bar'}         | ${'Bar'}         | ${'foo'}
    ${'existing page: user removes title -> keeps path'}                                                                | ${false}      | ${true}   | ${'Foo'}                               | ${'foo'}                               | ${''}            | ${'Untitled'}    | ${'foo'}
    ${'existing page without title: user updates title -> generates new path from title'}                               | ${false}      | ${true}   | ${'Untitled'}                          | ${'untitled-20221310061200'}           | ${'Bar'}         | ${'Bar'}         | ${'Bar'}
    ${'existing page without title: user removes title -> keeps autogenerated path'}                                    | ${false}      | ${true}   | ${'Untitled'}                          | ${'untitled-20221310061200'}           | ${''}            | ${'Untitled'}    | ${'untitled-20221310061200'}
    ${'existing page with title and autogenerated path: user removes title -> keeps autogenerated path'}                | ${false}      | ${true}   | ${'Foo'}                               | ${'untitled-20221310061200'}           | ${''}            | ${'Untitled'}    | ${'untitled-20221310061200'}
    ${'existing page with title and path: user removes title -> keeps path'}                                            | ${false}      | ${true}   | ${'Foo'}                               | ${'bar'}                               | ${''}            | ${'Untitled'}    | ${'bar'}
    ${'existing page without title but with path: user updates title -> keeps path'}                                    | ${false}      | ${true}   | ${'Untitled'}                          | ${'bar'}                               | ${'Foo'}         | ${'Foo'}         | ${'bar'}
    ${'existing page without title but with path: user removes title -> keeps path'}                                    | ${false}      | ${true}   | ${'Untitled'}                          | ${'bar'}                               | ${''}            | ${'Untitled'}    | ${'bar'}
    ${'new template: user enters title -> path generated from title and prefixed with `templates/`'}                    | ${true}       | ${false}  | ${''}                                  | ${''}                                  | ${'My template'} | ${'My template'} | ${'templates/My-template'}
    ${'new template with title: user updates title -> path regenerated and prefixed with `templates/'}                  | ${true}       | ${false}  | ${'Foo'}                               | ${''}                                  | ${'My template'} | ${'My template'} | ${'templates/My-template'}
    ${'new template with no title: user does nothing -> path autogenerated and prefixed with `templates/`'}             | ${true}       | ${false}  | ${''}                                  | ${''}                                  | ${''}            | ${'Untitled'}    | ${'templates/untitled-20230730042400'}
    ${'existing template without title: user enters title -> path generated from title and prefixed with `templates/`'} | ${true}       | ${true}   | ${'Untitled'}                          | ${'templates/untitled-20221310061200'} | ${'My template'} | ${'My template'} | ${'templates/My-template'}
    ${'existing template with title: user updates title -> path regenerated and prefixed with `templates/`'}            | ${true}       | ${true}   | ${'Foo'}                               | ${'templates/foo'}                     | ${'My template'} | ${'My template'} | ${'templates/My-template'}
    ${'existing template with no title: user does nothing -> regenerates autogenerated path'}                           | ${true}       | ${true}   | ${'Untitled'}                          | ${'templates/untitled-20221310061200'} | ${''}            | ${'Untitled'}    | ${'templates/untitled-20230730042400'}
    ${'existing template with title and path: user removes title -> keeps path'}                                        | ${true}       | ${true}   | ${'Foo'}                               | ${'templates/foo'}                     | ${''}            | ${'Untitled'}    | ${'templates/foo'}
    ${'isTemplate via path only: user updates title -> path regenerated and prefixed with `templates/`'}                | ${false}      | ${false}  | ${'Foo'}                               | ${'templates/foo'}                     | ${'Bar'}         | ${'Bar'}         | ${'templates/Bar'}
    ${'new template with parent path placeholder: user enters title -> prefixes templates and parent path'}             | ${true}       | ${false}  | ${'templates/parent/{new_page_title}'} | ${'templates/parent/{new_page_title}'} | ${'My template'} | ${'My template'} | ${'templates/parent/My-template'}
  `(
    '$case',
    ({
      isTemplateUrl,
      persisted,
      originalTitle,
      originalPath,
      titleInput,
      expectedTitle,
      expectedPath,
    }) => {
      let submittedFormData;

      beforeEach(async () => {
        jest.spyOn(wikiUtils, 'isTemplate').mockReturnValue(isTemplateUrl);

        jest
          .useFakeTimers({ legacyFakeTimers: false })
          .setSystemTime(new Date('2023-07-30T04:24:00'));
        createWrapper({
          mountFn: shallowMountExtended,
          persisted,
          pageInfo: {
            slug: originalPath,
            title: originalTitle,
          },
        });

        await waitForPromises();

        const input = wrapper.findByTestId('wiki-title-textbox');
        input.element.value = titleInput;
        await input.trigger('input');

        await nextTick();
        await triggerFormSubmit();

        submittedFormData = [...getFormData().entries()];
      });

      it(`submits "${expectedPath}" as the path`, () => {
        expect(submittedFormData).toContainEqual(['wiki[title]', expectedPath]);
      });

      if (isTemplateUrl || originalPath.startsWith('templates/')) {
        it('does not include a frontmatter block in the content', () => {
          const content = submittedFormData.find(([key]) => key === 'wiki[content]')[1];
          expect(content).not.toMatch(/^---\n/);
        });
      } else {
        it(`submits "${expectedTitle}" as the title`, () => {
          expect(submittedFormData).toContainEqual([
            'wiki[content]',
            expect.stringContaining(`---\ntitle: ${expectedTitle}\n---`),
          ]);
        });
      }
    },
  );

  describe('adding a commit message', () => {
    let mutateSpy;

    beforeEach(async () => {
      createWrapper({ mountFn: shallowMountExtended });
      await waitForPromises();
      mutateSpy = jest.spyOn(wrapper.vm.$apollo.provider.defaultClient, 'mutate');

      wrapper.findComponentByTestId('wiki-submit-message-mode').vm.$emit('select', 'CUSTOM');
    });

    afterEach(() => {
      mutateSpy.mockRestore();
    });

    it('shows the commit message modal', () => {
      expect(wrapper.findComponentByTestId('commit-message-modal').props('visible')).toBe(true);
    });

    it('shows the input field', () => {
      expect(wrapper.findByTestId('wiki-message-textbox').isVisible()).toBe(true);
    });

    it('persists the preference via mutation', () => {
      expect(mutateSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: {
            input: {
              wikiUseAutoCommitMessage: false,
            },
          },
        }),
      );
    });

    it('includes the commit message in the form', async () => {
      wrapper.findComponentByTestId('wiki-message-textbox').vm.$emit('input', 'Foobar');
      await nextTick();
      expect(wrapper.find('input[name="wiki[message]"]').attributes('value')).toBe('Foobar');
    });

    describe('auto commit message toggle', () => {
      const findToggle = () => wrapper.findComponentByTestId('auto-commit-message-toggle');

      it('renders the toggle in the modal', () => {
        expect(findToggle().exists()).toBe(true);
        expect(findToggle().props('label')).toBe('Use the default commit message for future saves');
      });

      it('reflects the current preference value', () => {
        expect(findToggle().props('value')).toBe(false);
      });

      it('updates the preference when toggled on', async () => {
        mutateSpy.mockClear();

        findToggle().vm.$emit('change', true);
        await nextTick();

        expect(findToggle().props('value')).toBe(true);
        expect(mutateSpy).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: {
              input: {
                wikiUseAutoCommitMessage: true,
              },
            },
          }),
        );
      });

      it('does not submit the form when toggled', async () => {
        const submitSpy = jest.spyOn(findForm().element, 'submit');

        findToggle().vm.$emit('change', true);
        await waitForPromises();

        expect(submitSpy).not.toHaveBeenCalled();
      });
    });
  });

  describe('saving through the commit message modal', () => {
    let submitSpy;

    beforeEach(async () => {
      createWrapper({
        pageInfo: { title: 'Foo' },
      });
      await waitForPromises();
      submitSpy = jest.spyOn(findForm().element, 'submit');

      wrapper.findComponentByTestId('wiki-submit-message-mode').vm.$emit('select', 'CUSTOM');

      await waitForPromises();

      wrapper.findComponentByTestId('wiki-message-textbox').vm.$emit('input', 'Foobar');

      await nextTick();
    });

    it('saves the form when selecting the primary action on the commit message modal', async () => {
      wrapper.findComponentByTestId('commit-message-modal').vm.$emit('primary');
      await nextTick();

      expect(submitSpy).toHaveBeenCalled();
    });

    it.each(['secondary', 'cancel'])(
      'does not save the form when the commit message modal emits "%s"',
      async (event) => {
        wrapper.findComponentByTestId('commit-message-modal').vm.$emit(event);
        await nextTick();

        expect(submitSpy).not.toHaveBeenCalled();
      },
    );
  });

  describe('save message mode preference', () => {
    const autoCommitMessageQueryResponse = (value) =>
      jest.fn().mockResolvedValue({
        data: {
          currentUser: {
            id: '1',
            userPreferences: { wikiUseAutoCommitMessage: value },
          },
        },
      });

    describe('when clicking save button', () => {
      it('submits form directly when useAutoCommitMessage is true', async () => {
        createWrapper({
          pageInfo: { title: 'Foo' },
          autoCommitMessageQueryHandler: autoCommitMessageQueryResponse(true),
        });
        await waitForPromises();
        const submitSpy = jest.spyOn(findForm().element, 'submit');

        wrapper.findComponentByTestId('wiki-submit-button').vm.$emit('click', new Event('click'));
        await nextTick();

        expect(submitSpy).toHaveBeenCalled();
      });

      it('opens commit message modal when useAutoCommitMessage is false', async () => {
        createWrapper({
          pageInfo: { title: 'Foo' },
          autoCommitMessageQueryHandler: autoCommitMessageQueryResponse(false),
        });
        await waitForPromises();
        const submitSpy = jest.spyOn(findForm().element, 'submit');

        wrapper.findComponentByTestId('wiki-submit-button').vm.$emit('click', new Event('click'));
        await nextTick();

        expect(wrapper.findComponentByTestId('commit-message-modal').props('visible')).toBe(true);
        expect(submitSpy).not.toHaveBeenCalled();
      });

      it('does not call the preference mutation', async () => {
        createWrapper({
          pageInfo: { title: 'Foo' },
        });
        await waitForPromises();
        const spy = jest.spyOn(wrapper.vm.$apollo.provider.defaultClient, 'mutate');

        wrapper.findComponentByTestId('wiki-submit-button').vm.$emit('click', new Event('click'));
        await nextTick();

        expect(spy).not.toHaveBeenCalled();
        spy.mockRestore();
      });
    });

    describe.each`
      preference | selectedMode | shouldOpenCommitMessageModal | updatesPreference
      ${true}    | ${'AUTO'}    | ${false}                     | ${false}
      ${true}    | ${'CUSTOM'}  | ${true}                      | ${true}
      ${false}   | ${'AUTO'}    | ${false}                     | ${true}
      ${false}   | ${'CUSTOM'}  | ${true}                      | ${false}
    `(
      'when preference is $preference and selecting $selectedMode from dropdown',
      ({ preference, selectedMode, shouldOpenCommitMessageModal, updatesPreference }) => {
        let submitSpy;
        let mutateSpyLocal;

        beforeEach(async () => {
          createWrapper({
            pageInfo: { title: 'Foo' },
            autoCommitMessageQueryHandler: autoCommitMessageQueryResponse(preference),
          });
          await waitForPromises();
          submitSpy = jest.spyOn(findForm().element, 'submit');
          mutateSpyLocal = jest.spyOn(wrapper.vm.$apollo.provider.defaultClient, 'mutate');

          wrapper
            .findComponentByTestId('wiki-submit-message-mode')
            .vm.$emit('select', selectedMode);
          await waitForPromises();
        });

        afterEach(() => {
          mutateSpyLocal.mockRestore();
        });

        if (shouldOpenCommitMessageModal) {
          it('opens commit message modal', () => {
            expect(wrapper.findComponentByTestId('commit-message-modal').props('visible')).toBe(
              true,
            );
            expect(submitSpy).not.toHaveBeenCalled();
          });
        } else {
          it('submits form directly', () => {
            expect(submitSpy).toHaveBeenCalled();
          });
        }

        if (updatesPreference) {
          it('updates the preference via mutation', () => {
            expect(mutateSpyLocal).toHaveBeenCalledWith(
              expect.objectContaining({
                variables: {
                  input: {
                    wikiUseAutoCommitMessage: selectedMode === 'AUTO',
                  },
                },
              }),
            );
          });

          it('shows loading state on the save button while mutation is in-flight', async () => {
            createWrapper({
              pageInfo: { title: 'Foo' },
              autoCommitMessageQueryHandler: autoCommitMessageQueryResponse(preference),
            });
            await waitForPromises();

            let resolveMutate;
            jest.spyOn(wrapper.vm.$apollo.provider.defaultClient, 'mutate').mockReturnValue(
              new Promise((resolve) => {
                resolveMutate = resolve;
              }),
            );

            wrapper
              .findComponentByTestId('wiki-submit-message-mode')
              .vm.$emit('select', selectedMode);
            await nextTick();

            expect(wrapper.findComponentByTestId('wiki-submit-button').props('loading')).toBe(true);

            resolveMutate();
            await waitForPromises();

            expect(wrapper.findComponentByTestId('wiki-submit-button').props('loading')).toBe(
              false,
            );
          });
        } else {
          it('does not update the preference via mutation', () => {
            expect(mutateSpyLocal).not.toHaveBeenCalled();
          });
        }
      },
    );
  });

  describe('edit sidebar', () => {
    describe('when sidebar is persisted', () => {
      beforeEach(() => {
        createWrapper({
          mountFn: shallowMountExtended,
          pageInfo: pageInfoEditSidebar,
          provide: {
            wikiUrl: '_sidebar',
            pagePersisted: true,
          },
        });
      });

      it('shows an edit sidebar header', () => {
        expect(wrapper.text()).toContain('Edit Sidebar');
      });

      it('hides the title input', () => {
        expect(wrapper.findByTestId('wiki-title-textbox').exists()).toBe(false);
      });

      it('hides the path input', () => {
        expect(wrapper.findByTestId('wiki-path-textbox').exists()).toBe(false);
      });

      it('hides the generate path from title toggle', () => {
        expect(wrapper.findByTestId('path-generation-toggle').exists()).toBe(false);
      });

      it('renders the delete wiki modal', () => {
        expect(wrapper.findComponent(DeleteWikiModal).exists()).toBe(true);
      });

      it('includes a hidden wiki[title] input with value _sidebar', () => {
        const hiddenInput = wrapper.find('input[name="wiki[title]"][type="hidden"]');
        expect(hiddenInput.exists()).toBe(true);
        expect(hiddenInput.attributes('value')).toBe('_sidebar');
      });
    });

    describe('when sidebar is not persisted', () => {
      beforeEach(() => {
        createWrapper({
          mountFn: shallowMountExtended,
          pageInfo: pageInfoNewSidebar,
          provide: {
            wikiUrl: '_sidebar',
            isEditingPath: true,
          },
        });
      });

      it('shows a create custom sidebar header', () => {
        expect(wrapper.text()).toContain('Create custom sidebar');
      });
    });
  });

  describe('submit button text', () => {
    it.each`
      scenario               | isTemplateUrl | persisted | originalPath       | expectedText
      ${'new page'}          | ${false}      | ${false}  | ${''}              | ${'Create page'}
      ${'existing page'}     | ${false}      | ${true}   | ${'foo'}           | ${'Save changes'}
      ${'new template'}      | ${true}       | ${false}  | ${''}              | ${'Create template'}
      ${'existing template'} | ${true}       | ${true}   | ${'templates/foo'} | ${'Save template'}
      ${'template by path'}  | ${false}      | ${false}  | ${'templates/foo'} | ${'Create template'}
    `(
      'renders "$expectedText" for $scenario',
      async ({ isTemplateUrl, persisted, originalPath, expectedText }) => {
        jest.spyOn(wikiUtils, 'isTemplate').mockReturnValue(isTemplateUrl);

        createWrapper({
          mountFn: shallowMountExtended,
          persisted,
          pageInfo: { slug: originalPath },
        });

        await waitForPromises();

        expect(wrapper.findByTestId('wiki-submit-button').text()).toBe(expectedText);
      },
    );
  });

  describe('autosave drafts', () => {
    const lastCommitSha = 'sha-abc123';
    const persistedPageInfo = { ...pageInfoPersisted, lastCommitSha };
    const draftKey = (field) => `autosave/${persistedPageInfo.path}/${field}`;
    const lockVersionKey = (field) => `${draftKey(field)}/lockVersion`;
    const findAlert = () => wrapper.findComponent(GlAlert);
    const clickAlertButton = async (text) => {
      await wrapper
        .findAll('.gl-alert-action')
        .filter((button) => button.text() === text)
        .at(0)
        .trigger('click');
      await waitForPromises();
    };

    const seedDraft = ({
      title = 'draft title',
      content = 'draft content',
      format = 'markdown',
      commit = 'draft commit',
      lockVersion = lastCommitSha,
    } = {}) => {
      localStorage.setItem(draftKey('title'), title);
      localStorage.setItem(draftKey('content'), content);
      localStorage.setItem(draftKey('format'), format);
      localStorage.setItem(draftKey('commit'), commit);
      if (lockVersion) {
        localStorage.setItem(lockVersionKey('title'), lockVersion);
      }
    };

    describe('on submit', () => {
      it('persists drafts to localStorage before submitting the form', async () => {
        createWrapper({ persisted: true, pageInfo: { lastCommitSha } });
        await waitForPromises();

        const submitSpy = jest.spyOn(findForm().element, 'submit').mockImplementation(() => {});

        await inputTitle('Updated title');
        findMarkdownEditor().vm.$emit('input', 'Updated content');
        await nextTick();

        await triggerFormSubmit();
        await nextTick();

        expect(localStorage.getItem(draftKey('title'))).toBe('Updated title');
        expect(localStorage.getItem(draftKey('content'))).toBe('Updated content');
        expect(localStorage.getItem(draftKey('format'))).toBe('markdown');
        expect(localStorage.getItem(lockVersionKey('title'))).toBe(lastCommitSha);
        expect(submitSpy).toHaveBeenCalled();
      });

      it('does not clear drafts on beforeunload while a submit is in flight', async () => {
        createWrapper({ persisted: true, pageInfo: { lastCommitSha } });
        await waitForPromises();

        jest.spyOn(findForm().element, 'submit').mockImplementation(() => {});

        await inputTitle('Updated title');
        findMarkdownEditor().vm.$emit('input', 'Updated content');
        await nextTick();

        await triggerFormSubmit();
        await nextTick();

        window.dispatchEvent(new Event('beforeunload'));

        expect(localStorage.getItem(draftKey('title'))).toBe('Updated title');
        expect(localStorage.getItem(draftKey('content'))).toBe('Updated content');
      });
    });

    describe('on mount', () => {
      it('restores drafts whose lockVersion matches pageInfo.lastCommitSha', async () => {
        seedDraft({
          title: 'saved draft title',
          content: 'saved draft content',
          lockVersion: lastCommitSha,
        });

        createWrapper({
          persisted: true,
          mountFn: mountExtended,
          pageInfo: { lastCommitSha },
        });
        await waitForPromises();

        expect(findTitle().element.value).toBe('saved draft title');
        expect(findMarkdownEditor().props('value')).toBe('saved draft content');
        expect(findAlert().exists()).toBe(false);
      });

      describe('when the stored lockVersion no longer matches', () => {
        const expectDraftShown = () => {
          expect(findTitle().element.value).toBe('stale draft title');
          expect(findFormat().element.value).toBe('rdoc');
          expect(findMarkdownEditor().props('value')).toBe('stale draft content');
          expect(findMessageFormInput().element.value).toBe('stale draft commit');
        };

        const expectUpstreamShown = () => {
          expect(findTitle().element.value).toBe('My page');
          expect(findFormat().element.value).toBe('markdown');
          expect(findMarkdownEditor().props('value')).toBe('  My page content  ');
          expect(findMessageFormInput().element.value).toBe('Update My page');
        };

        const expectDraftsCleared = () => {
          expect(localStorage.getItem(draftKey('title'))).toBeNull();
          expect(localStorage.getItem(draftKey('content'))).toBeNull();
          expect(localStorage.getItem(draftKey('format'))).toBeNull();
          expect(localStorage.getItem(draftKey('commit'))).toBeNull();
          expect(localStorage.getItem(lockVersionKey('title'))).toBeNull();
        };

        beforeEach(async () => {
          seedDraft({
            title: 'stale draft title',
            content: 'stale draft content',
            format: 'rdoc',
            commit: 'stale draft commit',
            lockVersion: 'old-sha',
          });

          createWrapper({
            persisted: true,
            mountFn: mountExtended,
            pageInfo: { lastCommitSha },
          });
          await waitForPromises();
        });

        it('restores the draft', () => {
          expectDraftShown();
        });

        it('warns that someone else edited the page', () => {
          expect(findAlert().props('variant')).toBe('danger');
          expect(findAlert().text()).toContain('Someone edited the page the same time you did.');
          expect(findAlert().text()).toContain('View their version');
          expect(findAlert().text()).toContain('Discard my changes');
        });

        it('keeps the stored lockVersion on beforeunload', () => {
          window.dispatchEvent(new Event('beforeunload'));

          expect(localStorage.getItem(draftKey('content'))).toBe('stale draft content');
          expect(localStorage.getItem(lockVersionKey('title'))).toBe('old-sha');
        });

        it('stores edits made before viewing their version', async () => {
          findMarkdownEditor().vm.$emit('input', 'edited draft content');
          await findForm().trigger('input');
          await clickAlertButton('View their version');
          window.dispatchEvent(new Event('beforeunload'));

          expect(localStorage.getItem(draftKey('content'))).toBe('edited draft content');
          expect(localStorage.getItem(lockVersionKey('title'))).toBe('old-sha');
        });

        describe('when viewing their version', () => {
          beforeEach(async () => {
            await clickAlertButton('View their version');
          });

          it('shows the upstream title, content and commit message', () => {
            expectUpstreamShown();
          });

          it('offers to switch back to the draft', () => {
            expect(findAlert().text()).toContain(
              'You are viewing the page as saved by someone else (read-only). You have shelved changes.',
            );
            expect(findAlert().text()).toContain('Edit my version');
            expect(findAlert().text()).toContain('Discard my changes');
          });

          it('makes the form read-only', () => {
            expect(findMarkdownEditor().props('disabled')).toBe(true);
            expect(findTitle().attributes('readonly')).toBeDefined();
            expect(wrapper.findComponentByTestId('wiki-submit-button').props('disabled')).toBe(
              true,
            );
          });

          const pressCtrlEnter = () =>
            findMarkdownEditor().vm.$emit(
              'keydown',
              new KeyboardEvent('keydown', { key: 'Enter', ctrlKey: true }),
            );

          it.each([
            ['submit', triggerFormSubmit],
            ['Ctrl+Enter', pressCtrlEnter],
          ])('does not save on %s', async (_, action) => {
            const submitSpy = jest.spyOn(findForm().element, 'submit');

            await action();
            await waitForPromises();

            expect(submitSpy).not.toHaveBeenCalled();
            expect(localStorage.getItem(draftKey('content'))).toBe('stale draft content');
          });

          it('keeps the draft in localStorage on beforeunload', () => {
            window.dispatchEvent(new Event('beforeunload'));

            expect(localStorage.getItem(draftKey('title'))).toBe('stale draft title');
            expect(localStorage.getItem(draftKey('content'))).toBe('stale draft content');
            expect(localStorage.getItem(draftKey('commit'))).toBe('stale draft commit');
          });

          describe('and then viewing my changes', () => {
            beforeEach(async () => {
              await clickAlertButton('Edit my version');
            });

            it('shows the draft title, content and commit message again', () => {
              expectDraftShown();
            });

            it('makes the form editable again', () => {
              expect(findMarkdownEditor().props('disabled')).toBe(false);
              expect(findTitle().attributes('readonly')).toBeUndefined();
            });

            it('shows the warning again', () => {
              expect(findAlert().props('variant')).toBe('danger');
            });
          });

          describe('and then discarding my changes', () => {
            beforeEach(async () => {
              confirmAction.mockResolvedValue(true);
              await clickAlertButton('Discard my changes');
            });

            it('keeps showing the upstream version', () => {
              expectUpstreamShown();
            });

            it('clears the drafts and the alert', () => {
              expectDraftsCleared();
              expect(findAlert().exists()).toBe(false);
            });

            it('makes the form editable again', () => {
              expect(findMarkdownEditor().props('disabled')).toBe(false);
              expect(findTitle().attributes('readonly')).toBeUndefined();
              expect(wrapper.findComponentByTestId('wiki-submit-button').props('disabled')).toBe(
                false,
              );
            });
          });
        });

        it('restores the page path when discarding my changes', async () => {
          await findPath().setValue('renamed');
          confirmAction.mockResolvedValue(true);
          await clickAlertButton('Discard my changes');
          await waitForPromises();

          expect(findPath().element.value).toBe('My-page');
        });

        describe('when discarding my changes', () => {
          beforeEach(async () => {
            confirmAction.mockResolvedValue(true);
            await clickAlertButton('Discard my changes');
          });

          it('asks for confirmation', () => {
            expect(confirmAction).toHaveBeenCalledWith(
              'Your changes to this page will be permanently deleted.',
              expect.objectContaining({
                title: 'Discard your changes?',
                primaryBtnText: 'Discard changes',
                primaryBtnVariant: 'danger',
                cancelBtnText: 'Keep my changes',
              }),
            );
          });

          it('shows the upstream title, content and commit message', () => {
            expectUpstreamShown();
          });

          it('clears the drafts and the alert', () => {
            expectDraftsCleared();
            expect(findAlert().exists()).toBe(false);
          });
        });

        describe('when discarding my changes is cancelled', () => {
          beforeEach(async () => {
            confirmAction.mockResolvedValue(false);
            await clickAlertButton('Discard my changes');
          });

          it('keeps the draft and the warning', () => {
            expectDraftShown();
            expect(localStorage.getItem(draftKey('content'))).toBe('stale draft content');
            expect(findAlert().props('variant')).toBe('danger');
          });
        });
      });

      describe('when the page has a front matter title and the draft title was edited', () => {
        beforeEach(async () => {
          seedDraft({ title: 'My title', lockVersion: 'old-sha' });

          createWrapper({
            persisted: true,
            mountFn: mountExtended,
            pageInfo: { lastCommitSha, frontMatter: { title: 'Their title' } },
          });
          await waitForPromises();
          await inputTitle('My titleX');
        });

        it.each(['View their version', 'Discard my changes'])(
          'shows the upstream title after clicking "%s"',
          async (buttonText) => {
            confirmAction.mockResolvedValue(true);
            await clickAlertButton(buttonText);

            expect(findTitle().element.value).toBe('Their title');
          },
        );
      });

      describe('when the stored lockVersion no longer matches but the draft is unchanged', () => {
        beforeEach(async () => {
          seedDraft({
            title: 'My page',
            content: 'My page content\n',
            commit: 'Update My page',
            lockVersion: 'old-sha',
          });

          createWrapper({
            persisted: true,
            mountFn: mountExtended,
            pageInfo: { lastCommitSha },
          });
          await waitForPromises();
        });

        it('does not warn about a conflict', () => {
          expect(findAlert().exists()).toBe(false);
        });

        it('clears the drafts', () => {
          expect(localStorage.getItem(draftKey('title'))).toBeNull();
          expect(localStorage.getItem(draftKey('content'))).toBeNull();
          expect(localStorage.getItem(draftKey('format'))).toBeNull();
          expect(localStorage.getItem(draftKey('commit'))).toBeNull();
          expect(localStorage.getItem(lockVersionKey('title'))).toBeNull();
        });
      });

      describe('when the server reports a conflict', () => {
        const conflictMessage =
          'Someone edited the page the same time you did. Please make sure your changes will not unintentionally remove theirs.';

        const historyUrl = '/project/path/-/wikis/home/history';
        const notSavedMessage =
          'Your changes were not saved because someone else edited this page. Review their changes in the page history before you try again.';

        const createConflictWrapper = async (provide = {}) => {
          createWrapper({
            persisted: true,
            mountFn: mountExtended,
            pageInfo: { lastCommitSha },
            propsData: { pageChanged: true },
            provide: { historyUrl, ...provide },
          });
          await waitForPromises();
        };

        it('says the changes were not saved and links to the history when there is no stored draft', async () => {
          await createConflictWrapper();

          expect(findAlert().props('variant')).toBe('danger');
          expect(findAlert().text()).toContain(notSavedMessage);
          expect(findAlert().find(`a[href="${historyUrl}"]`).text()).toBe('View page history');
          expect(wrapper.findAllComponents(GlAlert)).toHaveLength(1);
        });

        it('omits the history link when there is no history URL', async () => {
          await createConflictWrapper({ historyUrl: '' });

          expect(findAlert().text()).toContain(notSavedMessage);
          expect(findAlert().find('.gl-alert-action').exists()).toBe(false);
        });

        it('shows only the stale draft alert when there is a stale draft', async () => {
          seedDraft({
            title: 'stale draft title',
            content: 'stale draft content',
            lockVersion: 'old-sha',
          });
          await createConflictWrapper();

          expect(findAlert().text()).toContain(conflictMessage);
          expect(findAlert().text()).toContain('View their version');
          expect(findAlert().text()).toContain('Discard my changes');
          expect(wrapper.findAllComponents(GlAlert)).toHaveLength(1);
        });

        it('does not warn again after the stale draft is discarded', async () => {
          seedDraft({
            title: 'stale draft title',
            content: 'stale draft content',
            lockVersion: 'old-sha',
          });
          await createConflictWrapper();
          confirmAction.mockResolvedValue(true);

          await clickAlertButton('Discard my changes');

          expect(findAlert().exists()).toBe(false);
        });
      });

      it('does not warn about a conflict without a stored draft or a server conflict', async () => {
        createWrapper({ persisted: true, mountFn: mountExtended, pageInfo: { lastCommitSha } });
        await waitForPromises();

        expect(findAlert().exists()).toBe(false);
      });

      it('restores drafts for a new (non-persisted) page even without a lockVersion', async () => {
        const newDraftKey = (field) => `autosave/${pageInfoNew.createPath}/${field}`;
        localStorage.setItem(newDraftKey('title'), 'new page draft');
        localStorage.setItem(newDraftKey('content'), 'new page content');

        createWrapper({ mountFn: mountExtended });
        await waitForPromises();

        expect(findTitle().element.value).toBe('new page draft');
        expect(findMarkdownEditor().props('value')).toBe('new page content');
      });
    });
  });

  describe('keyboard shortcut form submission', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('submits the form when ctrl+enter is triggered on the markdown editor', async () => {
      const submitSpy = jest.spyOn(findForm().element, 'submit');
      const ctrlEnterEvent = new KeyboardEvent('keydown', {
        key: 'Enter',
        ctrlKey: true,
      });

      findMarkdownEditor().vm.$emit('keydown', ctrlEnterEvent);
      await nextTick();

      expect(submitSpy).toHaveBeenCalled();
    });

    it('submits the form when meta+enter is triggered on the markdown editor', async () => {
      const submitSpy = jest.spyOn(findForm().element, 'submit');
      const metaEnterEvent = new KeyboardEvent('keydown', {
        key: 'Enter',
        metaKey: true,
      });

      findMarkdownEditor().vm.$emit('keydown', metaEnterEvent);
      await nextTick();

      expect(submitSpy).toHaveBeenCalled();
    });
  });

  describe('collaborative editing', () => {
    const findCollaboratorsIndicator = () => wrapper.findComponent(CollaboratorsIndicator);
    const findCollaborationProvider = () => findMarkdownEditor().props('collaborationProvider');

    const createCollaborativeWrapper = ({ pageInfo = {}, glFeatures = {}, ...options } = {}) =>
      createWrapper({
        persisted: true,
        pageInfo,
        provide: { glFeatures: { wikiCollaborativeEditing: true, ...glFeatures } },
        ...options,
      });

    const activateRichTextEditor = async () => {
      findMarkdownEditor().vm.$emit('content-editor');
      await nextTick();
    };

    beforeEach(() => {
      jest.spyOn(ActionCableProvider.prototype, 'connect').mockImplementation(() => {});
      jest.spyOn(ActionCableProvider.prototype, 'destroy').mockImplementation(() => {});
    });

    it('connects a provider and passes it to the editor', async () => {
      createCollaborativeWrapper();
      await activateRichTextEditor();

      expect(ActionCableProvider.prototype.connect).toHaveBeenCalled();
      expect(findCollaborationProvider()).not.toBeNull();
    });

    it('subscribes to the wiki page channel for this page', async () => {
      createCollaborativeWrapper();
      await activateRichTextEditor();

      expect(findCollaborationProvider().channel).toBe('CollaborativeEditing::WikiPageChannel');
      expect(findCollaborationProvider().channelParams).toEqual({
        container_full_path: 'group/project',
        slug: 'My-page',
      });
    });

    // ContentEditor captures the provider in its own created(). Once the async chunk is
    // cached, that runs before MarkdownEditor mounts and emits the editing-mode event,
    // so the session has to be live before the first render or the editor never joins.
    describe('when the editor opens in rich text mode', () => {
      const expectSessionLiveBeforeFirstRender = () => {
        // Deliberately not awaited: a provider here proves created() started the
        // session, rather than a child event doing it later.
        expect(ActionCableProvider.prototype.connect).toHaveBeenCalledTimes(1);
        expect(findCollaborationProvider()).not.toBeNull();
      };

      it('starts a session for a rich text editor preference', () => {
        window.gon = { ...window.gon, text_editor: 'rich_text_editor' };

        createCollaborativeWrapper();

        expectSessionLiveBeforeFirstRender();
      });

      it('starts a session for a stored rich text mode', () => {
        localStorage.setItem(EDITING_MODE_KEY, EDITING_MODE_CONTENT_EDITOR);

        createCollaborativeWrapper();

        expectSessionLiveBeforeFirstRender();
      });

      it('still passes the provider once the content editor has mounted', async () => {
        window.gon = { ...window.gon, text_editor: 'rich_text_editor' };

        createCollaborativeWrapper({ mountFn: mountExtended, stubs: { ContentEditor: true } });
        await waitForPromises();

        expect(ActionCableProvider.prototype.connect).toHaveBeenCalledTimes(1);
        expect(findCollaborationProvider()).not.toBeNull();
      });

      it('does not start a session for a plain text editor preference', () => {
        window.gon = { ...window.gon, text_editor: 'plain_text_editor' };

        createCollaborativeWrapper();

        expect(ActionCableProvider.prototype.connect).not.toHaveBeenCalled();
        expect(findCollaborationProvider()).toBeNull();
      });
    });

    it('shows the collaborators indicator', async () => {
      createCollaborativeWrapper();
      await activateRichTextEditor();

      expect(findCollaboratorsIndicator().exists()).toBe(true);
    });

    describe('when edits stop synchronizing', () => {
      const findSubmitButton = () => wrapper.findComponentByTestId('wiki-submit-button');
      const findSaveModeListbox = () => wrapper.findComponentByTestId('wiki-submit-message-mode');
      const findCustomAlert = () => findMarkdownEditor().props('customAlert');

      let showToast;

      const stall = async (reason) => {
        findCollaborationProvider().onStallChange(reason);
        await nextTick();
      };

      const leaveForPlainText = async () => {
        findMarkdownEditor().vm.$emit('markdown-field');
        await nextTick();
      };

      beforeEach(async () => {
        showToast = jest.fn();
        createCollaborativeWrapper({
          mountFn: mountExtended,
          stubs: { ContentEditor: true },
          mocks: { $toast: { show: showToast } },
          autoCommitMessageQueryHandler: jest.fn().mockResolvedValue({
            data: {
              currentUser: { id: '1', userPreferences: { wikiUseAutoCommitMessage: false } },
            },
          }),
        });
        await waitForPromises();
        await activateRichTextEditor();
      });

      it('freezes the barrier content and SHA until native submission', async () => {
        let accept;
        const provider = findCollaborationProvider();
        const startSave = jest.spyOn(provider, 'startSave').mockImplementation(
          () =>
            new Promise((resolve) => {
              accept = resolve;
            }),
        );
        const submitSpy = jest.spyOn(findForm().element, 'submit');
        findMarkdownEditor().vm.$emit('input', 'At barrier');
        await nextTick();
        findMarkdownEditor().vm.$emit(
          'keydown',
          new KeyboardEvent('keydown', { ctrlKey: true, key: 'Enter' }),
        );
        findMarkdownEditor().vm.$emit(
          'keydown',
          new KeyboardEvent('keydown', { ctrlKey: true, key: 'Enter' }),
        );
        await nextTick();
        expect(startSave).toHaveBeenCalledTimes(1);
        expect(findSubmitButton().props('loading')).toBe(true);
        provider.onVersionChange('new-version');
        findMarkdownEditor().vm.$emit('input', 'Remote later');
        accept({ sessionId: 'generation', saveId: 'save' });
        await waitForPromises();

        expect(submitSpy).toHaveBeenCalledTimes(1);
        expect(getFormData().get('wiki[content]')).toBe('At barrier');
        expect(getFormData().get('wiki[last_commit_sha]')).toBe('page-commit');
        expect(getFormData().get('collaboration_session_id')).toBe('generation');
        expect(localStorage.getItem(`autosave/${pageInfoPersisted.path}/content`)).toBe(
          'At barrier',
        );
        expect(localStorage.getItem(`autosave/${pageInfoPersisted.path}/title/lockVersion`)).toBe(
          'page-commit',
        );
      });

      it('saves the corrected title in the frozen front matter', async () => {
        jest
          .spyOn(findCollaborationProvider(), 'startSave')
          .mockResolvedValue({ sessionId: 'generation', saveId: 'save' });
        jest.spyOn(findForm().element, 'submit');
        await findTitle().setValue('');
        await triggerFormSubmit();
        wrapper.findComponent(GlModal).vm.$emit('primary');
        await waitForPromises();

        expect(getFormData().get('wiki[content]')).toContain('title: Untitled\n');
      });

      it('keeps content and allows another save after a rejected barrier', async () => {
        jest.spyOn(findCollaborationProvider(), 'startSave').mockRejectedValue(new Error('busy'));
        const submitSpy = jest.spyOn(findForm().element, 'submit');
        findMarkdownEditor().vm.$emit('input', 'Keep this');
        await triggerFormSubmit();
        wrapper.findComponent(GlModal).vm.$emit('primary');
        await waitForPromises();

        expect(submitSpy).not.toHaveBeenCalled();
        expect(findSubmitButton().props('loading')).toBe(false);
        expect(findMarkdownEditor().props('value')).toBe('Keep this');
        expect(showToast).toHaveBeenCalledWith('Another editor is saving this page. Try again.');
      });

      it('uses the barrier from the dialog but omits continuation fields after leaving for plain text', async () => {
        const provider = findCollaborationProvider();
        const startSave = jest
          .spyOn(provider, 'startSave')
          .mockRejectedValue(new Error('unsynchronised'));
        await triggerFormSubmit();
        wrapper.findComponent(GlModal).vm.$emit('primary');
        await waitForPromises();
        expect(startSave).toHaveBeenCalledTimes(1);
        await leaveForPlainText();
        await triggerFormSubmit();
        wrapper.findComponent(GlModal).vm.$emit('primary');
        await waitForPromises();

        expect(startSave).toHaveBeenCalledTimes(1);
        expect(getFormData().has('collaboration_session_id')).toBe(false);
        expect(getFormData().has('collaboration_save_id')).toBe(false);
      });

      it('shows no alert and allows saving while the session is healthy', () => {
        expect(findCustomAlert()).toBeNull();
        expect(findSubmitButton().props('disabled')).toBe(false);
      });

      it.each`
        reason                   | variant      | text
        ${'payload_too_large'}   | ${'danger'}  | ${'Your changes are too large to synchronize with other editors, so you cannot save them. Copy the page content to keep your work, then switch to the plain text editor to save it.'}
        ${'unacknowledged'}      | ${'warning'} | ${'Your recent changes are not synchronized with other editors, so you cannot save them. GitLab keeps trying to synchronize them. Copy the page content to keep your work.'}
        ${'session_invalidated'} | ${'danger'}  | ${'This collaborative session has ended because the page changed or the session expired, so you cannot save in rich text or plain text. Copy the page content, reload the page, and reconcile your changes with the latest version.'}
        ${'lookup_failed'}       | ${'danger'}  | ${'GitLab temporarily cannot verify the latest page version, so this collaborative session cannot continue. Copy the page content, reload the page, and reconcile your changes with the latest version.'}
      `('warns with a $variant alert for $reason', async ({ reason, variant, text }) => {
        await stall(reason);

        expect(findCustomAlert()).toMatchObject({
          variant,
          message: text,
          primaryButtonText: 'Copy page content',
        });
        expect(findCustomAlert().dismiss).toBeUndefined();
      });

      it('prevents every way of saving', async () => {
        const submitSpy = jest.spyOn(findForm().element, 'submit');
        await stall('payload_too_large');

        await triggerFormSubmit();
        findMarkdownEditor().vm.$emit(
          'keydown',
          new KeyboardEvent('keydown', { ctrlKey: true, key: 'Enter' }),
        );
        wrapper.findComponent(GlModal).vm.$emit('primary');
        await nextTick();

        expect(findSubmitButton().props('disabled')).toBe(true);
        expect(findSaveModeListbox().props('disabled')).toBe(true);
        expect(wrapper.findComponent(GlModal).props('visible')).toBe(false);
        expect(submitSpy).not.toHaveBeenCalled();
      });

      it('closes a commit message dialog that is already open', async () => {
        await triggerFormSubmit();
        expect(wrapper.findComponent(GlModal).props('visible')).toBe(true);

        await stall('unacknowledged');

        expect(wrapper.findComponent(GlModal).props('visible')).toBe(false);
      });

      it('allows saving again once the edits synchronize', async () => {
        await stall('unacknowledged');
        await stall(null);

        expect(findCustomAlert()).toBeNull();
        expect(findSubmitButton().props('disabled')).toBe(false);
      });

      it('clears the stall when the user leaves the session for plain text', async () => {
        await stall('payload_too_large');

        await leaveForPlainText();

        expect(findCustomAlert()).toBeNull();
        expect(findSubmitButton().props('disabled')).toBe(false);
      });

      describe.each(['session_invalidated', 'lookup_failed'])('after %s', (reason) => {
        beforeEach(async () => {
          findMarkdownEditor().vm.$emit('input', 'Latest local recovery content');
          await stall(reason);
        });

        it('keeps the current content available to copy', async () => {
          copyToClipboard.mockResolvedValue();

          await findCustomAlert().primaryAction();

          expect(copyToClipboard).toHaveBeenCalledWith('Latest local recovery content');
          expect(findCustomAlert().message).toContain('reconcile your changes');
        });

        it('blocks plain-text saving and reopening collaboration', async () => {
          const submitSpy = jest.spyOn(findForm().element, 'submit');
          await leaveForPlainText();
          await triggerFormSubmit();
          findMarkdownEditor().vm.$emit(
            'keydown',
            new KeyboardEvent('keydown', { ctrlKey: true, key: 'Enter' }),
          );
          wrapper.findComponent(GlModal).vm.$emit('primary');
          await nextTick();

          expect(findSubmitButton().props('disabled')).toBe(true);
          expect(findSaveModeListbox().props('disabled')).toBe(true);
          expect(submitSpy).not.toHaveBeenCalled();
          expect(findCustomAlert().message).toContain(
            reason === 'lookup_failed'
              ? 'temporarily cannot verify'
              : 'you cannot save in rich text or plain text',
          );
          expect(findMarkdownEditor().props('value')).toBe('Latest local recovery content');
          await expect(
            findMarkdownEditor().props('beforeContentEditor')('Latest local recovery content'),
          ).resolves.toBe(false);
          await activateRichTextEditor();
          expect(ActionCableProvider.prototype.connect).toHaveBeenCalledTimes(1);
          expect(findCollaborationProvider()).toBeNull();
        });
      });

      it('does not submit if the session ends while preparing a save', async () => {
        const submitSpy = jest.spyOn(findForm().element, 'submit');
        await triggerFormSubmit();

        wrapper.findComponent(GlModal).vm.$emit('primary');
        findCollaborationProvider().onStallChange('session_invalidated');
        await waitForPromises();

        expect(submitSpy).not.toHaveBeenCalled();
        expect(showToast).not.toHaveBeenCalled();
        expect(findSubmitButton().props('disabled')).toBe(true);
        expect(findCustomAlert().message).toContain('This collaborative session has ended');
      });

      describe('returning to rich text after leaving for plain text', () => {
        const returnToRichText = () =>
          findMarkdownEditor().props('beforeContentEditor')('Edited in rich text');

        beforeEach(async () => {
          findMarkdownEditor().vm.$emit('input', 'Edited in rich text');
          await nextTick();
        });

        it('asks before discarding edits that never synchronized', async () => {
          confirmAction.mockResolvedValue(false);
          await stall('payload_too_large');
          await leaveForPlainText();

          const allowed = await returnToRichText();

          expect(confirmAction).toHaveBeenCalledTimes(1);
          expect(confirmAction).toHaveBeenCalledWith(
            expect.stringContaining("your changes that didn't synchronize"),
            expect.objectContaining({ title: 'Discard unsynchronized changes?' }),
          );
          expect(allowed).toBe(false);
          expect(findMarkdownEditor().props('value')).toBe('Edited in rich text');
        });

        it('does not ask when the edits had synchronized', async () => {
          await leaveForPlainText();

          const allowed = await returnToRichText();

          expect(confirmAction).not.toHaveBeenCalled();
          expect(allowed).toBe(true);
        });

        it('describes only plain text changes once the unsynchronized edits are discarded', async () => {
          confirmAction.mockResolvedValue(true);
          await stall('payload_too_large');
          await leaveForPlainText();
          await returnToRichText();

          await findMarkdownEditor().props('beforeContentEditor')('Changed in plain text');

          expect(confirmAction).toHaveBeenCalledTimes(2);
          expect(confirmAction).toHaveBeenLastCalledWith(
            'Switching to rich text will discard changes made in plain text. Continue?',
            expect.objectContaining({ title: 'Discard plain text changes?' }),
          );
        });
      });

      describe('copying the page content', () => {
        beforeEach(async () => {
          findMarkdownEditor().vm.$emit('input', 'Unsynchronized content');
          await stall('payload_too_large');
        });

        it('copies the current content and confirms', async () => {
          copyToClipboard.mockResolvedValue();

          await findCustomAlert().primaryAction();

          expect(copyToClipboard).toHaveBeenCalledWith('Unsynchronized content');
          expect(showToast).toHaveBeenCalledWith('Page content copied to clipboard.');
        });

        it('tells the user to copy manually when the clipboard is unavailable', async () => {
          copyToClipboard.mockRejectedValue(new Error('Clipboard write failed'));

          await findCustomAlert().primaryAction();

          expect(showToast).toHaveBeenCalledWith(
            'Could not copy the page content. Select and copy it manually.',
          );
        });
      });
    });

    describe('before the rich text editor is active', () => {
      it('does not open a connection', async () => {
        createCollaborativeWrapper();
        await nextTick();

        expect(ActionCableProvider.prototype.connect).not.toHaveBeenCalled();
        expect(findCollaborationProvider()).toBeNull();
      });

      it('does not show the collaborators indicator', async () => {
        createCollaborativeWrapper();
        await nextTick();

        expect(findCollaboratorsIndicator().exists()).toBe(false);
      });
    });

    it('tears the provider down when the form is destroyed', async () => {
      createCollaborativeWrapper();
      await activateRichTextEditor();

      wrapper.destroy();

      expect(ActionCableProvider.prototype.destroy).toHaveBeenCalled();
    });

    describe('switching editing mode', () => {
      describe('after leaving rich text', () => {
        beforeEach(async () => {
          createCollaborativeWrapper();
          await activateRichTextEditor();
          findMarkdownEditor().vm.$emit('markdown-field');
          await nextTick();
        });

        describe('when plain text has changed', () => {
          beforeEach(async () => {
            findMarkdownEditor().vm.$emit('input', 'Plain text draft');
            await nextTick();
          });

          describe('when the user declines to discard', () => {
            it('keeps the plain text edits', async () => {
              confirmAction.mockResolvedValue(false);

              const allowed =
                await findMarkdownEditor().props('beforeContentEditor')('Plain text draft');

              expect(allowed).toBe(false);
              expect(findMarkdownEditor().props('value')).toBe('Plain text draft');
            });
          });

          describe('when the user confirms the discard', () => {
            it('restores the previous content', async () => {
              confirmAction.mockResolvedValue(true);

              const allowed =
                await findMarkdownEditor().props('beforeContentEditor')('Plain text draft');
              await nextTick();

              expect(allowed).toBe(true);
              expect(findMarkdownEditor().props('value')).toBe(pageInfoPersisted.content);
            });
          });
        });

        describe('when plain text has not changed', () => {
          it('switches without confirmation', async () => {
            const allowed = await findMarkdownEditor().props('beforeContentEditor')(
              pageInfoPersisted.content,
            );

            expect(allowed).toBe(true);
            expect(confirmAction).not.toHaveBeenCalled();
          });
        });
      });

      describe('when a plain text draft is restored', () => {
        beforeEach(async () => {
          localStorage.setItem(
            `autosave/${pageInfoPersisted.path}/content`,
            'Saved plain text draft',
          );
          createCollaborativeWrapper();
          findMarkdownEditor().vm.$emit('markdown-field');
          await nextTick();
        });

        it('guards the draft before entering rich text', async () => {
          confirmAction.mockResolvedValue(false);

          const allowed =
            await findMarkdownEditor().props('beforeContentEditor')('Saved plain text draft');

          expect(allowed).toBe(false);
          expect(findMarkdownEditor().props('value')).toBe('Saved plain text draft');
        });
      });

      describe('when collaboration is disabled', () => {
        beforeEach(async () => {
          createCollaborativeWrapper({ glFeatures: { wikiCollaborativeEditing: false } });
          findMarkdownEditor().vm.$emit('input', 'Plain text draft');
          await nextTick();
        });

        it('allows the switch without guarding the edits', async () => {
          const allowed =
            await findMarkdownEditor().props('beforeContentEditor')('Plain text draft');

          expect(allowed).toBe(true);
          expect(confirmAction).not.toHaveBeenCalled();
        });
      });

      it('leaves the session when switching to plain text', async () => {
        createCollaborativeWrapper();
        await activateRichTextEditor();

        findMarkdownEditor().vm.$emit('markdown-field');
        await nextTick();

        expect(ActionCableProvider.prototype.destroy).toHaveBeenCalled();
        expect(findCollaborationProvider()).toBeNull();
      });

      it('rejoins with a live provider when switching back to rich text', async () => {
        createCollaborativeWrapper();
        await activateRichTextEditor();

        findMarkdownEditor().vm.$emit('markdown-field');
        await nextTick();
        await activateRichTextEditor();

        expect(ActionCableProvider.prototype.connect).toHaveBeenCalledTimes(2);
        expect(findCollaborationProvider()).not.toBeNull();
      });

      it('does not open a second connection while already collaborating', async () => {
        createCollaborativeWrapper();
        await activateRichTextEditor();
        await activateRichTextEditor();

        expect(ActionCableProvider.prototype.connect).toHaveBeenCalledTimes(1);
      });
    });

    // ContentEditor ignores markdown-prop updates while collaborating, so applying a
    // template would desync the visible document from the submitted content.
    describe('applying a template', () => {
      it('is disabled while collaborating', async () => {
        createCollaborativeWrapper({ mountFn: mountExtended, stubs: { ContentEditor: true } });
        await activateRichTextEditor();

        expect(findTemplatesDropdown().props('disabled')).toBe(true);
      });

      it('is enabled again after leaving the session', async () => {
        createCollaborativeWrapper({ mountFn: mountExtended, stubs: { ContentEditor: true } });
        await activateRichTextEditor();

        findMarkdownEditor().vm.$emit('markdown-field');
        await nextTick();

        expect(findTemplatesDropdown().props('disabled')).toBe(false);
      });

      it('drops a confirmation left pending from plain text mode', async () => {
        createCollaborativeWrapper({ mountFn: mountExtended, stubs: { ContentEditor: true } });
        await nextTick();

        findTemplatesDropdown().vm.$emit('input', 'Template content');
        await nextTick();

        expect(wrapper.findComponent(GlAlert).exists()).toBe(true);

        await activateRichTextEditor();

        expect(wrapper.findComponent(GlAlert).exists()).toBe(false);
        expect(findMarkdownEditor().props('value')).toBe(pageInfoPersisted.content);
      });
    });

    describe('when it should not start a session', () => {
      it.each`
        scenario                        | options
        ${'the feature flag is off'}    | ${{ glFeatures: { wikiCollaborativeEditing: false } }}
        ${'the page is not persisted'}  | ${{ pageInfo: { persisted: false } }}
        ${'the format is not markdown'} | ${{ pageInfo: { format: 'asciidoc' } }}
      `('does not connect when $scenario', async ({ options }) => {
        createCollaborativeWrapper(options);
        await activateRichTextEditor();

        expect(ActionCableProvider.prototype.connect).not.toHaveBeenCalled();
        expect(findCollaborationProvider()).toBeNull();
        expect(findCollaboratorsIndicator().exists()).toBe(false);
      });
    });
  });
});
