import { debounce } from 'lodash';
import {
  init as initConfidentialMergeRequest,
  isConfidentialIssue,
  canCreateConfidentialMergeRequest,
} from '~/confidential_merge_request';
import confidentialMergeRequestState from '~/confidential_merge_request/state';
import DropLab from '~/filtered_search/droplab/drop_lab_deprecated';
import ISetter from '~/filtered_search/droplab/plugins/input_setter';
import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { __, sprintf } from '~/locale';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import api from '~/api';

// Todo: Remove this when fixing issue in input_setter plugin
const InputSetter = { ...ISetter };

const CREATE_MERGE_REQUEST = 'create-mr';
const CREATE_BRANCH = 'create-branch';

function createEndpoint(projectPath, endpoint) {
  if (canCreateConfidentialMergeRequest()) {
    return endpoint.replace(
      projectPath,
      confidentialMergeRequestState.selectedProject.pathWithNamespace,
    );
  }

  return endpoint;
}

export default class CreateMergeRequestDropdown {
  constructor(wrapperEl) {
    this.wrapperEl = wrapperEl;
    this.availableButton = this.wrapperEl.querySelector('.available');
    this.branchInput = this.wrapperEl.querySelector('.js-branch-name');
    this.branchMessage = this.wrapperEl.querySelector('.js-branch-message');
    this.createMergeRequestButton = this.wrapperEl.querySelector('.js-create-merge-request');
    this.createMergeRequestLoading = this.createMergeRequestButton.querySelector('.js-spinner');
    this.createTargetButton = this.wrapperEl.querySelector('.js-create-target');
    this.dropdownList = this.wrapperEl.querySelector('.dropdown-menu');
    this.dropdownToggle = this.wrapperEl.querySelector('.js-dropdown-toggle');
    this.refInput = this.wrapperEl.querySelector('.js-ref');
    this.refMessage = this.wrapperEl.querySelector('.js-ref-message');
    this.unavailableButton = this.wrapperEl.querySelector('.unavailable');
    this.unavailableButtonSpinner = this.unavailableButton.querySelector('.js-create-mr-spinner');
    this.unavailableButtonText = this.unavailableButton.querySelector('.text');

    this.branchCreated = false;
    this.branchIsValid = true;
    this.canCreatePath = this.wrapperEl.dataset.canCreatePath;
    this.createBranchPath = this.wrapperEl.dataset.createBranchPath;
    this.createMrPath = this.wrapperEl.dataset.createMrPath;
    this.droplabInitialized = false;
    this.isCreatingBranch = false;
    this.isCreatingMergeRequest = false;
    this.isGettingRef = false;
    this.refCancelToken = null;
    this.mergeRequestCreated = false;
    this.refDebounce = debounce((value, target) => this.getRef(value, target), 500);
    this.refIsValid = true;
    this.refsPath = this.wrapperEl.dataset.refsPath;
    this.suggestedRef = this.refInput.value;
    this.projectPath = this.wrapperEl.dataset.projectPath;
    this.projectId = this.wrapperEl.dataset.projectId;

    // These regexps are used to replace
    // a backend generated new branch name and its source (ref)
    // with user's inputs.
    this.regexps = {
      branch: {
        createBranchPath: /(branch_name=)(.+?)(?=&issue)/,
        createMrPath: /(source_branch%5D=)(.+?)(?=&)/,
      },
      ref: {
        createBranchPath: /(ref=)(.+?)$/,
        createMrPath: /(target_branch%5D=)(.+?)$/,
      },
    };

    this.init();

    if (isConfidentialIssue()) {
      this.createMergeRequestButton.dataset.dropdownTrigger = '#create-merge-request-dropdown';
      initConfidentialMergeRequest();
    }
  }

  available() {
    this.availableButton.classList.remove('hidden');
    this.unavailableButton.classList.add('hidden');
  }

  bindEvents() {
    this.createMergeRequestButton.addEventListener(
      'click',
      this.onClickCreateMergeRequestButton.bind(this),
    );
    this.createTargetButton.addEventListener(
      'click',
      this.onClickCreateMergeRequestButton.bind(this),
    );
    this.branchInput.addEventListener('input', this.onChangeInput.bind(this));
    this.branchInput.addEventListener('keyup', this.onChangeInput.bind(this));
    this.dropdownToggle.addEventListener('click', this.onClickSetFocusOnBranchNameInput.bind(this));
    // Detect for example when user pastes ref using the mouse
    this.refInput.addEventListener('input', this.onChangeInput.bind(this));
    // Detect for example when user presses right arrow to apply the suggested ref
    this.refInput.addEventListener('keyup', this.onChangeInput.bind(this));
    // Detect when user clicks inside the input to apply the suggested ref
    this.refInput.addEventListener('click', this.onChangeInput.bind(this));
    // Detect when user clicks outside the input to apply the suggested ref
    this.refInput.addEventListener('blur', this.onChangeInput.bind(this));
    // Detect when user presses tab to apply the suggested ref
    this.refInput.addEventListener('keydown', CreateMergeRequestDropdown.processTab.bind(this));
  }

  checkAbilityToCreateBranch() {
    this.setUnavailableButtonState();

    axios
      .get(this.canCreatePath)
      .then(({ data }) => {
        this.setUnavailableButtonState(false);

        if (data.can_create_branch) {
          this.available();
          this.enable();
          this.updateBranchName(data.suggested_branch_name);

          if (!this.droplabInitialized) {
            this.droplabInitialized = true;
            this.initDroplab();
            this.bindEvents();
          }
        } else {
          this.hide();
        }
      })
      .catch(() => {
        this.unavailable();
        this.disable();
        createFlash({
          message: __('Failed to check related branches.'),
        });
      });
  }

  createBranch(navigateToBranch = true) {
    this.isCreatingBranch = true;

    return axios
      .post(createEndpoint(this.projectPath, this.createBranchPath), {
        confidential_issue_project_id: canCreateConfidentialMergeRequest() ? this.projectId : null,
      })
      .then(({ data }) => {
        this.branchCreated = true;

        if (navigateToBranch) {
          window.location.href = data.url;
        }
      })
      .catch(() =>
        createFlash({
          message: __('Failed to create a branch for this issue. Please try again.'),
        }),
      );
  }

  createMergeRequest() {
    this.isCreatingMergeRequest = true;

    return this.createBranch(false)
      .then(() => api.trackRedisHllUserEvent('i_code_review_user_create_mr_from_issue'))
      .then(() => {
        let path = canCreateConfidentialMergeRequest()
          ? this.createMrPath.replace(
              this.projectPath,
              confidentialMergeRequestState.selectedProject.pathWithNamespace,
            )
          : this.createMrPath;
        path = mergeUrlParams(
          {
            'merge_request[target_branch]': this.refInput.value,
            'merge_request[source_branch]': this.branchInput.value,
          },
          path,
        );

        window.location.href = path;
      });
  }

  disable() {
    this.disableCreateAction();
  }

  setLoading(loading) {
    this.createMergeRequestLoading.classList.toggle('gl-display-none', !loading);
  }

  disableCreateAction() {
    this.createMergeRequestButton.classList.add('disabled');
    this.createMergeRequestButton.setAttribute('disabled', 'disabled');

    this.createTargetButton.classList.add('disabled');
    this.createTargetButton.setAttribute('disabled', 'disabled');
  }

  enable() {
    if (isConfidentialIssue() && !canCreateConfidentialMergeRequest()) return;

    this.createMergeRequestButton.classList.remove('disabled');
    this.createMergeRequestButton.removeAttribute('disabled');

    this.createTargetButton.classList.remove('disabled');
    this.createTargetButton.removeAttribute('disabled');
  }

  static findByValue(objects, ref, returnFirstMatch = false) {
    if (!objects || !objects.length) return false;
    if (objects.indexOf(ref) > -1) return ref;
    if (returnFirstMatch) return objects.find((item) => new RegExp(`^${ref}`).test(item));

    return false;
  }

  getDroplabConfig() {
    return {
      addActiveClassToDropdownButton: true,
      InputSetter: [
        {
          input: this.createMergeRequestButton,
          valueAttribute: 'data-value',
          inputAttribute: 'data-action',
        },
        {
          input: this.createMergeRequestButton,
          valueAttribute: 'data-text',
        },
        {
          input: this.createTargetButton,
          valueAttribute: 'data-value',
          inputAttribute: 'data-action',
        },
        {
          input: this.createTargetButton,
          valueAttribute: 'data-text',
        },
      ],
      hideOnClick: false,
    };
  }

  static getInputSelectedText(input) {
    const start = input.selectionStart;
    const end = input.selectionEnd;

    return input.value.substr(start, end - start);
  }

  getRef(ref, target = 'all') {
    if (!ref) return false;

    this.refCancelToken = axios.CancelToken.source();

    return axios
      .get(`${createEndpoint(this.projectPath, this.refsPath)}${encodeURIComponent(ref)}`, {
        cancelToken: this.refCancelToken.token,
      })
      .then(({ data }) => {
        const branches = data[Object.keys(data)[0]];
        const tags = data[Object.keys(data)[1]];
        let result;

        if (target === 'branch') {
          result = CreateMergeRequestDropdown.findByValue(branches, ref);
        } else {
          result =
            CreateMergeRequestDropdown.findByValue(branches, ref, true) ||
            CreateMergeRequestDropdown.findByValue(tags, ref, true);
          this.suggestedRef = result;
        }

        this.isGettingRef = false;

        return this.updateInputState(target, ref, result);
      })
      .catch((thrown) => {
        if (axios.isCancel(thrown)) {
          return false;
        }
        this.unavailable();
        this.disable();
        createFlash({
          message: __('Failed to get ref.'),
        });

        this.isGettingRef = false;

        return false;
      });
  }

  getTargetData(target) {
    return {
      input: this[`${target}Input`],
      message: this[`${target}Message`],
    };
  }

  hide() {
    this.wrapperEl.classList.add('hidden');
  }

  init() {
    this.checkAbilityToCreateBranch();
  }

  initDroplab() {
    this.droplab = new DropLab();

    this.droplab.init(
      this.dropdownToggle,
      this.dropdownList,
      [InputSetter],
      this.getDroplabConfig(),
    );
  }

  inputsAreValid() {
    return this.branchIsValid && this.refIsValid;
  }

  isBusy() {
    return (
      this.isCreatingMergeRequest ||
      this.mergeRequestCreated ||
      this.isCreatingBranch ||
      this.branchCreated ||
      this.isGettingRef
    );
  }

  onChangeInput(event) {
    this.disable();
    let target;
    let value;

    // User changed input, cancel to prevent previous request from interfering
    if (this.refCancelToken !== null) {
      this.refCancelToken.cancel();
    }

    if (event.target === this.branchInput) {
      target = 'branch';
      ({ value } = this.branchInput);
    } else if (event.target === this.refInput) {
      target = 'ref';
      if (event.target === document.activeElement) {
        value =
          event.target.value.slice(0, event.target.selectionStart) +
          event.target.value.slice(event.target.selectionEnd);
      } else {
        value = event.target.value;
      }
    } else {
      return false;
    }

    if (this.isGettingRef) return false;

    // `ENTER` key submits the data.
    if (event.keyCode === 13 && this.inputsAreValid()) {
      event.preventDefault();
      return this.createMergeRequestButton.click();
    }

    // If the input is empty, use the original value generated by the backend.
    if (!value) {
      this.createBranchPath = this.wrapperEl.dataset.createBranchPath;
      this.createMrPath = this.wrapperEl.dataset.createMrPath;

      if (target === 'branch') {
        this.branchIsValid = true;
      } else {
        this.refIsValid = true;
      }

      this.enable();
      this.showAvailableMessage(target);
      this.refDebounce(value, target);
      return true;
    }

    this.showCheckingMessage(target);
    this.refDebounce(value, target);

    return true;
  }

  onClickCreateMergeRequestButton(event) {
    let xhr = null;
    event.preventDefault();

    if (isConfidentialIssue() && !event.target.classList.contains('js-create-target')) {
      this.droplab.hooks.forEach((hook) => hook.list.toggle());

      return;
    }

    if (this.isBusy()) {
      return;
    }

    if (event.target.dataset.action === CREATE_MERGE_REQUEST) {
      xhr = this.createMergeRequest();
    } else if (event.target.dataset.action === CREATE_BRANCH) {
      xhr = this.createBranch();
    }

    xhr.catch(() => {
      this.isCreatingMergeRequest = false;
      this.isCreatingBranch = false;

      this.enable();
      this.setLoading(false);
    });

    this.setLoading(true);
    this.disable();
  }

  onClickSetFocusOnBranchNameInput() {
    this.branchInput.focus();
  }

  // `TAB` autocompletes the source.
  static processTab(event) {
    if (event.keyCode !== 9 || this.isGettingRef) return;

    const selectedText = CreateMergeRequestDropdown.getInputSelectedText(this.refInput);

    // if nothing selected, we don't need to autocomplete anything. Do the default TAB action.
    // If a user manually selected text, don't autocomplete anything. Do the default TAB action.
    if (!selectedText || this.refInput.dataset.value === this.suggestedRef) return;

    event.preventDefault();
    const caretPositionEnd = this.refInput.value.length;
    this.refInput.setSelectionRange(caretPositionEnd, caretPositionEnd);
  }

  removeMessage(target) {
    const { input, message } = this.getTargetData(target);
    const inputClasses = ['gl-field-error-outline', 'gl-field-success-outline'];
    const messageClasses = ['gl-text-gray-600', 'gl-text-red-500', 'gl-text-green-500'];

    inputClasses.forEach((cssClass) => input.classList.remove(cssClass));
    messageClasses.forEach((cssClass) => message.classList.remove(cssClass));
    message.style.display = 'none';
  }

  setUnavailableButtonState(isLoading = true) {
    if (isLoading) {
      this.unavailableButtonSpinner.classList.remove('gl-display-none');
      this.unavailableButtonText.textContent = __('Checking branch availability...');
    } else {
      this.unavailableButtonSpinner.classList.add('gl-display-none');
      this.unavailableButtonText.textContent = __('New branch unavailable');
    }
  }

  showAvailableMessage(target) {
    const { input, message } = this.getTargetData(target);
    const text = target === 'branch' ? __('Branch name') : __('Source');

    this.removeMessage(target);
    input.classList.add('gl-field-success-outline');
    message.classList.add('gl-text-green-500');
    message.textContent = sprintf(__('%{text} is available'), { text });
    message.style.display = 'inline-block';
  }

  showCheckingMessage(target) {
    const { message } = this.getTargetData(target);
    const text = target === 'branch' ? __('branch name') : __('source');

    this.removeMessage(target);
    message.classList.add('gl-text-gray-600');
    message.textContent = sprintf(__('Checking %{text} availability…'), { text });
    message.style.display = 'inline-block';
  }

  showNotAvailableMessage(target) {
    const { input, message } = this.getTargetData(target);
    const text =
      target === 'branch' ? __('Branch is already taken') : __('Source is not available');

    this.removeMessage(target);
    input.classList.add('gl-field-error-outline');
    message.classList.add('gl-text-red-500');
    message.textContent = text;
    message.style.display = 'inline-block';
  }

  unavailable() {
    this.availableButton.classList.add('hidden');
    this.unavailableButton.classList.remove('hidden');
  }

  updateBranchName(suggestedBranchName) {
    this.branchInput.value = suggestedBranchName;
    this.updateCreatePaths('branch', suggestedBranchName);
  }

  updateInputState(target, ref, result) {
    // target - 'branch' or 'ref' - which the input field we are searching a ref for.
    // ref - string - what a user typed.
    // result - string - what has been found on backend.

    // If a found branch equals exact the same text a user typed,
    // that means a new branch cannot be created as it already exists.
    if (ref === result) {
      if (target === 'branch') {
        this.branchIsValid = false;
        this.showNotAvailableMessage('branch');
      } else {
        this.refIsValid = true;
        this.refInput.dataset.value = ref;
        this.showAvailableMessage('ref');
        this.updateCreatePaths(target, ref);
      }
    } else if (target === 'branch') {
      this.branchIsValid = true;
      this.showAvailableMessage('branch');
      this.updateCreatePaths(target, ref);
    } else {
      this.refIsValid = false;
      this.refInput.dataset.value = ref;
      this.disableCreateAction();
      this.showNotAvailableMessage('ref');

      // Show ref hint.
      if (result) {
        this.refInput.value = result;
        this.refInput.setSelectionRange(ref.length, result.length);
      }
    }

    if (this.inputsAreValid()) {
      this.enable();
    } else {
      this.disableCreateAction();
    }
  }

  // target - 'branch' or 'ref'
  // ref - string - the new value to use as branch or ref
  updateCreatePaths(target, ref) {
    const pathReplacement = `$1${encodeURIComponent(ref)}`;

    this.createBranchPath = this.createBranchPath.replace(
      this.regexps[target].createBranchPath,
      pathReplacement,
    );
    this.createMrPath = this.createMrPath.replace(
      this.regexps[target].createMrPath,
      pathReplacement,
    );

    this.wrapperEl.dataset.createMrPath = this.createMrPath;
  }
}
