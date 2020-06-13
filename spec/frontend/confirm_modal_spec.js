import Vue from 'vue';
import initConfirmModal from '~/confirm_modal';
import { TEST_HOST } from 'helpers/test_constants';

describe('ConfirmModal', () => {
  const buttons = [
    {
      path: `${TEST_HOST}/1`,
      method: 'delete',
      modalAttributes: {
        title: 'Remove tracking database entry',
        message: 'Tracking database entry will be removed. Are you sure?',
        okVariant: 'danger',
        okTitle: 'Remove entry',
      },
    },
    {
      path: `${TEST_HOST}/1`,
      method: 'post',
      modalAttributes: {
        title: 'Update tracking database entry',
        message: 'Tracking database entry will be updated. Are you sure?',
        okVariant: 'success',
        okTitle: 'Update entry',
      },
    },
  ];

  beforeEach(() => {
    const buttonContainer = document.createElement('div');

    buttons.forEach(x => {
      const button = document.createElement('button');
      button.setAttribute('class', 'js-confirm-modal-button');
      button.setAttribute('data-path', x.path);
      button.setAttribute('data-method', x.method);
      button.setAttribute('data-modal-attributes', JSON.stringify(x.modalAttributes));
      button.innerHTML = 'Action';
      buttonContainer.appendChild(button);
    });

    document.body.appendChild(buttonContainer);
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  const findJsHooks = () => document.querySelectorAll('.js-confirm-modal-button');
  const findModal = () => document.querySelector('.gl-modal');
  const findModalOkButton = (modal, variant) =>
    modal.querySelector(`.modal-footer .btn-${variant}`);
  const findModalCancelButton = modal => modal.querySelector('.modal-footer .btn-secondary');
  const modalIsHidden = () => findModal().getAttribute('aria-hidden') === 'true';

  const serializeModal = (modal, buttonIndex) => {
    const { modalAttributes } = buttons[buttonIndex];

    return {
      path: modal.querySelector('form').action,
      method: modal.querySelector('input[name="_method"]').value,
      modalAttributes: {
        title: modal.querySelector('.modal-title').innerHTML,
        message: modal.querySelector('.modal-body div').innerHTML,
        okVariant: [...findModalOkButton(modal, modalAttributes.okVariant).classList]
          .find(x => x.match('btn-'))
          .replace('btn-', ''),
        okTitle: findModalOkButton(modal, modalAttributes.okVariant).innerHTML,
      },
    };
  };

  it('starts with only JsHooks', () => {
    expect(findJsHooks()).toHaveLength(buttons.length);
    expect(findModal()).not.toExist();
  });

  describe('when button clicked', () => {
    beforeEach(() => {
      initConfirmModal();
      findJsHooks()
        .item(0)
        .click();
    });

    it('does not replace JsHook with GlModal', () => {
      expect(findJsHooks()).toHaveLength(buttons.length);
    });

    describe('GlModal', () => {
      it('is rendered', () => {
        expect(findModal()).toExist();
        expect(modalIsHidden()).toBe(false);
      });

      describe('Cancel Button', () => {
        beforeEach(() => {
          findModalCancelButton(findModal()).click();

          return Vue.nextTick();
        });

        it('closes the modal', () => {
          expect(modalIsHidden()).toBe(true);
        });
      });
    });
  });

  describe.each`
    index
    ${0}
    ${1}
  `(`when multiple buttons exist`, ({ index }) => {
    beforeEach(() => {
      initConfirmModal();
      findJsHooks()
        .item(index)
        .click();
    });

    it('correct props are passed to gl-modal', () => {
      expect(serializeModal(findModal(), index)).toEqual(buttons[index]);
    });
  });
});
