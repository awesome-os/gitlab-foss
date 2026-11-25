import MockAdapter from 'axios-mock-adapter';
import Dropzone from 'dropzone';
import $ from 'jquery';
import htmlSnippetsShow from 'test_fixtures/snippets/show.html';
import { Mousetrap } from '~/lib/mousetrap';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import GLForm from '~/gl_form';
import axios from '~/lib/utils/axios_utils';
import * as utils from '~/lib/utils/scroll_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import ZenMode from '~/zen_mode';

describe('ZenMode', () => {
  let mock;
  let zen;
  let dropzoneForElementSpy;

  const getTextarea = () => $('.notes-form textarea');

  function enterZen() {
    document.querySelector('.notes-form .js-zen-enter').click();
  }

  function exitZen() {
    document.querySelector('.notes-form .js-zen-leave').click();
  }

  function escapeKeydown() {
    getTextarea()[0].dispatchEvent(
      new KeyboardEvent('keydown', { keyCode: 27, bubbles: true, cancelable: true }),
    );
  }

  beforeEach(() => {
    mock = new MockAdapter(axios);
    mock.onGet().reply(HTTP_STATUS_OK);

    setHTMLFixture(htmlSnippetsShow);

    const form = $('.js-new-note-form');
    new GLForm(form); // eslint-disable-line no-new

    dropzoneForElementSpy = jest.spyOn(Dropzone, 'forElement').mockImplementation(() => ({
      enable: () => true,
    }));
    zen = new ZenMode();

    // Set this manually because we can't actually scroll the window
    zen.scroll_position = 456;
  });

  afterEach(() => {
    zen.destroy();

    resetHTMLFixture();
  });

  describe('events', () => {
    it('dispatches a bubbling zen_mode:enter event from the enter link', () => {
      const listener = jest.fn();
      document.addEventListener('zen_mode:enter', listener);
      enterZen();
      document.removeEventListener('zen_mode:enter', listener);

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener.mock.calls[0][0].target).toBe(
        document.querySelector('.notes-form .js-zen-enter'),
      );
    });

    it('dispatches a bubbling zen_mode:leave event from the leave link', () => {
      const listener = jest.fn();
      enterZen();
      document.addEventListener('zen_mode:leave', listener);
      exitZen();
      document.removeEventListener('zen_mode:leave', listener);

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener.mock.calls[0][0].target).toBe(
        document.querySelector('.notes-form .js-zen-leave'),
      );
    });

    it('dispatches zen_mode:leave from the document on Escape', () => {
      const listener = jest.fn();
      enterZen();
      document.addEventListener('zen_mode:leave', listener);
      escapeKeydown();
      document.removeEventListener('zen_mode:leave', listener);

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener.mock.calls[0][0].target).toBe(document);
    });
  });

  describe('destroy', () => {
    it('stops reacting to clicks', () => {
      zen.destroy();
      enterZen();

      expect(document.body).not.toHaveClass('zen-mode-fullscreen');
      expect($('.notes-form .zen-backdrop')).not.toHaveClass('fullscreen');
    });

    it('stops reacting to Escape', () => {
      const listener = jest.fn();
      document.addEventListener('zen_mode:leave', listener);

      zen.destroy();
      escapeKeydown();
      document.removeEventListener('zen_mode:leave', listener);

      expect(listener).not.toHaveBeenCalled();
    });
  });

  describe('enabling dropzone', () => {
    beforeEach(() => {
      enterZen();
    });

    it('should not call dropzone if element is not dropzone valid', () => {
      $('.div-dropzone').addClass('js-invalid-dropzone');
      exitZen();

      expect(dropzoneForElementSpy).not.toHaveBeenCalled();
    });

    it('should call dropzone if element is dropzone valid', () => {
      $('.div-dropzone').removeClass('js-invalid-dropzone');
      exitZen();

      expect(dropzoneForElementSpy).toHaveBeenCalledTimes(1);
    });
  });

  describe('on enter', () => {
    it('pauses Mousetrap', () => {
      const mouseTrapPauseSpy = jest.spyOn(Mousetrap, 'pause');
      enterZen();

      expect(mouseTrapPauseSpy).toHaveBeenCalled();
    });

    it('removes textarea styling', () => {
      getTextarea().attr('style', 'height: 400px');
      enterZen();

      expect(getTextarea()).not.toHaveAttr('style');
    });
  });

  describe('in use', () => {
    beforeEach(enterZen);

    it('exits on Escape', () => {
      escapeKeydown();

      expect($('.notes-form .zen-backdrop')).not.toHaveClass('fullscreen');
    });
  });

  describe('on exit', () => {
    beforeEach(enterZen);

    it('unpauses Mousetrap', () => {
      const mouseTrapUnpauseSpy = jest.spyOn(Mousetrap, 'unpause');
      exitZen();

      expect(mouseTrapUnpauseSpy).toHaveBeenCalled();
    });

    it('restores the scroll position', () => {
      jest.spyOn(utils, 'scrollToElement');
      exitZen();

      expect(utils.scrollToElement).toHaveBeenCalled();
    });
  });

  it('restores textarea style', () => {
    const style = 'color: red; overflow-y: hidden;';
    getTextarea().attr('style', style);
    expect(getTextarea()).toHaveAttr('style', style);

    enterZen();
    exitZen();

    expect(getTextarea()).toHaveAttr('style', style);
  });

  it('restores textarea focus', () => {
    getTextarea().trigger('focus');
    enterZen();
    exitZen();

    expect(document.activeElement).toBe(getTextarea()[0]);
  });
});
