import $ from 'jquery';
import _ from 'underscore';
import { __ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import Flash from '~/flash';
import { backOff } from '~/lib/utils/common_utils';
import AUTH_METHOD from './constants';

export default class SSHMirror {
  constructor(formSelector) {
    this.backOffRequestCounter = 0;

    this.$form = $(formSelector);

    this.$repositoryUrl = this.$form.find('.js-repo-url');
    this.$knownHosts = this.$form.find('.js-known-hosts');

    this.$sectionSSHHostKeys = this.$form.find('.js-ssh-host-keys-section');
    this.$hostKeysInformation = this.$form.find('.js-fingerprint-ssh-info');
    this.$btnDetectHostKeys = this.$form.find('.js-detect-host-keys');
    this.$btnSSHHostsShowAdvanced = this.$form.find('.btn-show-advanced');
    this.$dropdownAuthType = this.$form.find('.js-mirror-auth-type');
    this.$hiddenAuthType = this.$form.find('.js-hidden-mirror-auth-type');

    this.$wellAuthTypeChanging = this.$form.find('.js-well-changing-auth');
    this.$wellPasswordAuth = this.$form.find('.js-well-password-auth');
    this.$wellSSHAuth = this.$form.find('.js-well-ssh-auth');
    this.$sshPublicKeyWrap = this.$form.find('.js-ssh-public-key-wrap');
    this.$regeneratePublicSshKeyButton = this.$wellSSHAuth.find('.js-btn-regenerate-ssh-key');
    this.$regeneratePublicSshKeyModal = this.$wellSSHAuth.find(
      '.js-regenerate-public-ssh-key-confirm-modal',
    );
  }

  init() {
    this.handleRepositoryUrlInput(true);

    this.$repositoryUrl.on('keyup', () => this.handleRepositoryUrlInput());
    this.$knownHosts.on('keyup', e => this.handleSSHKnownHostsInput(e));
    this.$dropdownAuthType.on('change', e => this.handleAuthTypeChange(e));
    this.$btnDetectHostKeys.on('click', e => this.handleDetectHostKeys(e));
    this.$btnSSHHostsShowAdvanced.on('click', e => this.handleSSHHostsAdvanced(e));
    this.$regeneratePublicSshKeyButton.on('click', () =>
      this.$regeneratePublicSshKeyModal.toggle(true),
    );
    $('.js-confirm', this.$regeneratePublicSshKeyModal).on('click', e =>
      this.regeneratePublicSshKey(e),
    );
    $('.js-cancel', this.$regeneratePublicSshKeyModal).on('click', () =>
      this.$regeneratePublicSshKeyModal.toggle(false),
    );
  }

  /**
   * Method to monitor Git Repository URL input
   */
  handleRepositoryUrlInput(forceMatch) {
    const protocol = this.$repositoryUrl.val().split('://')[0];
    const protRegEx = /http|git/;

    // Validate URL and verify if it consists only supported protocols
    if (forceMatch || this.$form.get(0).checkValidity()) {
      const isSsh = protocol === 'ssh';
      // Hide/Show SSH Host keys section only for SSH URLs
      this.$sectionSSHHostKeys.collapse(isSsh ? 'show' : 'hide');
      this.$btnDetectHostKeys.enable();

      // Verify if URL is http, https or git and hide/show Auth type dropdown
      // as we don't support auth type SSH for non-SSH URLs
      const matchesProtocol = protRegEx.test(protocol);
      this.$dropdownAuthType.attr('disabled', matchesProtocol);

      if (forceMatch && isSsh) {
        this.$dropdownAuthType.val(AUTH_METHOD.SSH);
        this.toggleAuthWell(AUTH_METHOD.SSH);
      } else {
        this.$dropdownAuthType.val(AUTH_METHOD.PASSWORD);
        this.toggleAuthWell(AUTH_METHOD.PASSWORD);
      }
    }
  }

  /**
   * Click event handler to detect SSH Host key and fingerprints from
   * provided Git Repository URL.
   */
  handleDetectHostKeys() {
    const projectMirrorSSHEndpoint = this.$form.data('project-mirror-ssh-endpoint');
    const repositoryUrl = this.$repositoryUrl.val();
    const currentKnownHosts = this.$knownHosts.val();
    const $btnLoadSpinner = this.$btnDetectHostKeys.find('.js-spinner');

    // Disable button while we make request
    this.$btnDetectHostKeys.disable();
    $btnLoadSpinner.removeClass('d-none');

    // Make backOff polling to get data
    backOff((next, stop) => {
      axios
        .get(
          `${projectMirrorSSHEndpoint}?ssh_url=${repositoryUrl}&compare_host_keys=${encodeURIComponent(
            currentKnownHosts,
          )}`,
        )
        .then(({ data, status }) => {
          if (status === 204) {
            this.backOffRequestCounter += 1;
            if (this.backOffRequestCounter < 3) {
              next();
            } else {
              stop(data);
            }
          } else {
            stop(data);
          }
        })
        .catch(stop);
    })
      .then(res => {
        $btnLoadSpinner.addClass('d-none');
        // Once data is received, we show verification info along with Host keys and fingerprints
        this.$hostKeysInformation
          .find('.js-fingerprint-verification')
          .collapse(res.host_keys_changed ? 'hide' : 'show');
        if (res.known_hosts && res.fingerprints) {
          this.showSSHInformation(res);
        }
      })
      .catch(({ response }) => {
        // Show failure message when there's an error and re-enable Detect host keys button
        const failureMessage = response.data
          ? response.data.message
          : __('An error occurred while detecting host keys');
        Flash(failureMessage);

        $btnLoadSpinner.addClass('hidden');
        this.$btnDetectHostKeys.enable();
      });
  }

  /**
   * Method to monitor known hosts textarea input
   */
  handleSSHKnownHostsInput() {
    // Strike-out fingerprints and remove verification info if `known hosts` value is altered
    this.$hostKeysInformation.find('.js-fingerprints-list').addClass('invalidate');
    this.$hostKeysInformation.find('.js-fingerprint-verification').collapse('hide');
  }

  /**
   * Click event handler for `Show advanced` button under SSH Host keys section
   */
  handleSSHHostsAdvanced() {
    const $knownHost = this.$sectionSSHHostKeys.find('.js-ssh-known-hosts');
    const toggleShowAdvanced = $knownHost.hasClass('show');

    $knownHost.collapse('toggle');
    this.$btnSSHHostsShowAdvanced.toggleClass('show-advanced', toggleShowAdvanced);
  }

  /**
   * Authentication method dropdown change event listener
   */
  handleAuthTypeChange() {
    const projectMirrorAuthTypeEndpoint = `${this.$form.attr('action')}.json`;
    const $sshPublicKey = this.$sshPublicKeyWrap.find('.ssh-public-key');
    const selectedAuthType = this.$dropdownAuthType.val();

    this.$wellPasswordAuth.collapse('hide');
    this.$wellSSHAuth.collapse('hide');
    this.updateHiddenAuthType(selectedAuthType);

    // This request should happen only if selected Auth type was SSH
    // and SSH Public key was not present on page load
    if (selectedAuthType === AUTH_METHOD.SSH && !$sshPublicKey.text().trim()) {
      if (!this.$wellSSHAuth.length) return;

      // Construct request body
      const authTypeData = {
        project: {
          ...this.$regeneratePublicSshKeyButton.data().projectData,
        },
      };

      this.$wellAuthTypeChanging.collapse('show');
      this.$dropdownAuthType.disable();

      axios
        .put(projectMirrorAuthTypeEndpoint, JSON.stringify(authTypeData), {
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
        })
        .then(({ data }) => {
          // Show SSH public key container and fill in public key
          this.toggleAuthWell(selectedAuthType);
          this.toggleSSHAuthWellMessage(true);
          this.setSSHPublicKey(data.import_data_attributes.ssh_public_key);

          this.$wellAuthTypeChanging.collapse('hide');
          this.$dropdownAuthType.enable();
        })
        .catch(() => {
          Flash(__('Something went wrong on our end.'));

          this.$wellAuthTypeChanging.collapse('hide');
          this.$dropdownAuthType.enable();
        });
    } else {
      this.toggleAuthWell(selectedAuthType);
      this.$wellSSHAuth.find('.js-ssh-public-key-present').collapse('show');
    }
  }

  /**
   * Method to parse SSH Host keys data and render it
   * under SSH host keys section
   */
  showSSHInformation(sshHostKeys) {
    const $fingerprintsList = this.$hostKeysInformation.find('.js-fingerprints-list');
    let fingerprints = '';
    sshHostKeys.fingerprints.forEach(fingerprint => {
      const escFingerprints = _.escape(fingerprint.fingerprint);
      fingerprints += `<code>${escFingerprints}</code>`;
    });

    this.$hostKeysInformation.collapse('show');
    $fingerprintsList.removeClass('invalidate');
    $fingerprintsList.html(fingerprints);
    this.$sectionSSHHostKeys.find('.js-known-hosts').val(sshHostKeys.known_hosts);
  }

  /**
   * Toggle Auth type information container based on provided `authType`
   */
  toggleAuthWell(authType) {
    this.$wellPasswordAuth.collapse(authType === AUTH_METHOD.PASSWORD ? 'show' : 'hide');
    this.$wellSSHAuth.collapse(authType === AUTH_METHOD.SSH ? 'show' : 'hide');
    this.updateHiddenAuthType(authType);
  }

  updateHiddenAuthType(authType) {
    this.$hiddenAuthType.val(authType);
    this.$hiddenAuthType.prop('disabled', authType === AUTH_METHOD.SSH);
  }

  /**
   * Toggle SSH auth information message
   */
  toggleSSHAuthWellMessage(sshKeyPresent) {
    this.$sshPublicKeyWrap.collapse(sshKeyPresent ? 'show' : 'hide');
    this.$wellSSHAuth.find('.js-ssh-public-key-present').collapse(sshKeyPresent ? 'show' : 'hide');
    this.$regeneratePublicSshKeyButton.collapse(sshKeyPresent ? 'show' : 'hide');
    this.$wellSSHAuth.find('.js-ssh-public-key-pending').collapse(sshKeyPresent ? 'hide' : 'show');
  }

  /**
   * Sets SSH Public key to Clipboard button and shows it on UI.
   */
  setSSHPublicKey(sshPublicKey) {
    this.$sshPublicKeyWrap.find('.ssh-public-key').text(sshPublicKey);
    this.$sshPublicKeyWrap
      .find('.btn-copy-ssh-public-key')
      .attr('data-clipboard-text', sshPublicKey);
  }

  regeneratePublicSshKey(event) {
    event.preventDefault();

    this.$regeneratePublicSshKeyModal.toggle(false);

    const button = this.$regeneratePublicSshKeyButton;
    const spinner = $('.js-spinner', button);
    const endpoint = button.data('endpoint');
    const authTypeData = {
      project: {
        ...this.$regeneratePublicSshKeyButton.data().projectData,
      },
    };

    button.attr('disabled', 'disabled');
    spinner.removeClass('d-none');

    axios
      .patch(endpoint, authTypeData)
      .then(({ data }) => {
        button.removeAttr('disabled');
        spinner.addClass('d-none');

        this.setSSHPublicKey(data.import_data_attributes.ssh_public_key);
      })
      .catch(() => {
        Flash(_('Unable to regenerate public ssh key.'));
      });
  }

  destroy() {
    this.$repositoryUrl.off('keyup');
    this.$form.find('.js-known-hosts').off('keyup');
    this.$dropdownAuthType.off('change');
    this.$btnDetectHostKeys.off('click');
    this.$btnSSHHostsShowAdvanced.off('click');
    this.$regeneratePublicSshKeyButton.off('click');
    $('.js-confirm', this.$regeneratePublicSshKeyModal).off('click');
    $('.js-cancel', this.$regeneratePublicSshKeyModal).off('click');
  }
}
