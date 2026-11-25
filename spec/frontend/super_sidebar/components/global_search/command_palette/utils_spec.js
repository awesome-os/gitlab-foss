import {
  commandMapper,
  linksReducer,
  fileMapper,
} from '~/super_sidebar/components/global_search/command_palette/utils';
import { COMMANDS, LINKS, TRANSFORMED_LINKS } from './mock_data';

describe('linksReducer', () => {
  it('should transform links', () => {
    expect(LINKS.reduce(linksReducer, [])).toEqual(TRANSFORMED_LINKS);
  });

  it('lists the pages of a section nested inside a section', () => {
    const settings = {
      title: 'Settings',
      icon: 'settings',
      link: '/profile',
      items: [
        { id: 'profile_menu', title: 'Edit profile', link: '/profile', items: [] },
        {
          id: 'access_menu',
          title: 'Access',
          link: '/ssh_keys',
          items: [{ id: 'ssh_keys', title: 'SSH keys', link: '/ssh_keys' }],
        },
      ],
    };

    expect([settings].reduce(linksReducer, []).map(({ text, href }) => ({ text, href }))).toEqual([
      { text: 'Settings', href: '/profile' },
      { text: 'Settings > Edit profile', href: '/profile' },
      { text: 'Settings > Access', href: '/ssh_keys' },
      { text: 'Settings > Access > SSH keys', href: '/ssh_keys' },
    ]);
  });

  it('matches a page by its search keywords as well as its title', () => {
    const ai = { title: 'AI', items: [{ title: 'Automations', search_keywords: ['Triggers'] }] };

    expect([ai].reduce(linksReducer, [])[1].keywords).toBe('Automations Triggers');
  });
});

describe('commandMapper', () => {
  it('should temporarily remove the `invite_members` item', () => {
    const initialCommandsLength = COMMANDS[0].items.length;
    expect(COMMANDS.map(commandMapper)[0].items).toHaveLength(initialCommandsLength - 1);
  });
});

describe('fileMapper', () => {
  it('should transform files', () => {
    const file = 'file';
    const projectBlobPath = 'project/blob/path';
    expect(fileMapper(projectBlobPath, file)).toEqual({
      icon: 'doc-code',
      text: file,
      href: `${projectBlobPath}/${file}`,
      extraAttrs: {
        'data-track-action': 'click_command_palette_item',
        'data-track-label': 'file',
      },
    });
  });

  it('should encode file names with special characters', () => {
    const file = 'lua-amx_%.bbappend';
    const projectBlobPath = 'project/blob/path';
    expect(fileMapper(projectBlobPath, file)).toEqual({
      icon: 'doc-code',
      text: file,
      href: 'project/blob/path/lua-amx_%25.bbappend',
      extraAttrs: {
        'data-track-action': 'click_command_palette_item',
        'data-track-label': 'file',
      },
    });
  });

  it('should handle an un-encoded non-ASCII branch name in projectBlobPath', () => {
    const file = 'CODEOWNERS';
    const projectBlobPath = 'project/blob/Abhängigkeiten';
    expect(fileMapper(projectBlobPath, file)).toEqual({
      icon: 'doc-code',
      text: file,
      href: 'project/blob/Abhängigkeiten/CODEOWNERS',
      extraAttrs: {
        'data-track-action': 'click_command_palette_item',
        'data-track-label': 'file',
      },
    });
  });

  it('should not double-encode a percent-encoded non-ASCII branch name in projectBlobPath', () => {
    const file = 'CODEOWNERS';
    const projectBlobPath = 'project/blob/Abh%C3%A4ngigkeiten';
    expect(fileMapper(projectBlobPath, file)).toEqual({
      icon: 'doc-code',
      text: file,
      href: 'project/blob/Abh%C3%A4ngigkeiten/CODEOWNERS',
      extraAttrs: {
        'data-track-action': 'click_command_palette_item',
        'data-track-label': 'file',
      },
    });
  });
});
