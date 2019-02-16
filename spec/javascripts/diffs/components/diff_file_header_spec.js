import Vue from 'vue';
import Vuex from 'vuex';
import diffsModule from '~/diffs/store/modules';
import notesModule from '~/notes/stores/modules';
import DiffFileHeader from '~/diffs/components/diff_file_header.vue';
import { mountComponentWithStore } from 'spec/helpers/vue_mount_component_helper';

Vue.use(Vuex);

const discussionFixture = 'merge_requests/diff_discussion.json';

describe('diff_file_header', () => {
  let vm;
  let props;
  const diffDiscussionMock = getJSONFixture(discussionFixture)[0];
  const Component = Vue.extend(DiffFileHeader);

  const store = new Vuex.Store({
    modules: {
      diffs: diffsModule(),
      notes: notesModule(),
    },
  });

  beforeEach(() => {
    const diffFile = diffDiscussionMock.diff_file;

    diffFile.added_lines = 2;
    diffFile.removed_lines = 1;

    props = {
      diffFile: { ...diffFile },
      canCurrentUserFork: false,
    };
  });

  afterEach(() => {
    vm.$destroy();
  });

  describe('computed', () => {
    describe('icon', () => {
      beforeEach(() => {
        props.diffFile.blob.icon = 'file-text-o';
      });

      it('returns the blob icon for files', () => {
        props.diffFile.submodule = false;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.icon).toBe(props.diffFile.blob.icon);
      });

      it('returns the archive icon for submodules', () => {
        props.diffFile.submodule = true;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.icon).toBe('archive');
      });
    });

    describe('titleLink', () => {
      beforeEach(() => {
        props.discussionPath = 'link://to/discussion';
        Object.assign(props.diffFile, {
          submodule_link: 'link://to/submodule',
          submodule_tree_url: 'some://tree/url',
        });
      });

      it('returns the discussionPath for files', () => {
        props.diffFile.submodule = false;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.titleLink).toBe(props.discussionPath);
      });

      it('returns the submoduleTreeUrl for submodules', () => {
        props.diffFile.submodule = true;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.titleLink).toBe(props.diffFile.submodule_tree_url);
      });

      it('returns the submoduleLink for submodules without submoduleTreeUrl', () => {
        Object.assign(props.diffFile, {
          submodule: true,
          submodule_tree_url: null,
        });

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.titleLink).toBe(props.diffFile.submodule_link);
      });

      it('sets the correct path to the discussion', () => {
        props.discussionPath = 'link://to/discussion';
        vm = mountComponentWithStore(Component, { props, store });
        const href = vm.$el.querySelector('.js-title-wrapper').getAttribute('href');

        expect(href).toBe(vm.discussionPath);
      });
    });

    describe('filePath', () => {
      beforeEach(() => {
        Object.assign(props.diffFile, {
          blob: { id: 'b10b1db10b1d' },
          file_path: 'path/to/file',
        });
      });

      it('returns the filePath for files', () => {
        props.diffFile.submodule = false;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.filePath).toBe(props.diffFile.file_path);
      });

      it('appends the truncated blob id for submodules', () => {
        props.diffFile.submodule = true;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.filePath).toBe(
          `${props.diffFile.file_path} @ ${props.diffFile.blob.id.substr(0, 8)}`,
        );
      });
    });

    describe('titleTag', () => {
      it('returns a link tag if fileHash is set', () => {
        props.diffFile.file_hash = 'some hash';

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.titleTag).toBe('a');
      });

      it('returns a span tag if fileHash is not set', () => {
        props.diffFile.file_hash = null;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.titleTag).toBe('span');
      });
    });

    describe('isUsingLfs', () => {
      beforeEach(() => {
        Object.assign(props.diffFile, {
          stored_externally: true,
          external_storage: 'lfs',
        });
      });

      it('returns true if file is stored in LFS', () => {
        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.isUsingLfs).toBe(true);
      });

      it('returns false if file is not stored externally', () => {
        props.diffFile.stored_externally = false;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.isUsingLfs).toBe(false);
      });

      it('returns false if file is not stored in LFS', () => {
        props.diffFile.external_storage = 'not lfs';

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.isUsingLfs).toBe(false);
      });
    });

    describe('collapseIcon', () => {
      it('returns chevron-down if the diff is expanded', () => {
        props.expanded = true;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.collapseIcon).toBe('chevron-down');
      });

      it('returns chevron-right if the diff is collapsed', () => {
        props.expanded = false;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.collapseIcon).toBe('chevron-right');
      });
    });

    describe('viewFileButtonText', () => {
      it('contains the truncated content SHA', () => {
        const dummySha = 'deebd00f is no SHA';
        props.diffFile.content_sha = dummySha;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.viewFileButtonText).not.toContain(dummySha);
        expect(vm.viewFileButtonText).toContain(dummySha.substr(0, 8));
      });
    });

    describe('viewReplacedFileButtonText', () => {
      it('contains the truncated base SHA', () => {
        const dummySha = 'deadabba sings no more';
        props.diffFile.diff_refs.base_sha = dummySha;

        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.viewReplacedFileButtonText).not.toContain(dummySha);
        expect(vm.viewReplacedFileButtonText).toContain(dummySha.substr(0, 8));
      });
    });
  });

  describe('methods', () => {
    describe('handleToggleFile', () => {
      beforeEach(() => {
        spyOn(vm, '$emit').and.stub();
      });

      it('emits toggleFile if checkTarget is false', () => {
        vm.handleToggleFile(null, false);

        expect(vm.$emit).toHaveBeenCalledWith('toggleFile');
      });

      it('emits toggleFile if checkTarget is true and event target is header', () => {
        vm.handleToggleFile({ target: vm.$refs.header }, true);

        expect(vm.$emit).toHaveBeenCalledWith('toggleFile');
      });

      it('does not emit toggleFile if checkTarget is true and event target is not header', () => {
        vm.handleToggleFile({ target: 'not header' }, true);

        expect(vm.$emit).not.toHaveBeenCalled();
      });
    });
  });

  describe('template', () => {
    describe('collapse toggle', () => {
      const collapseToggle = () => vm.$el.querySelector('.diff-toggle-caret');

      it('is visible if collapsible is true', () => {
        props.collapsible = true;

        vm = mountComponentWithStore(Component, { props, store });

        expect(collapseToggle()).not.toBe(null);
      });

      it('is hidden if collapsible is false', () => {
        props.collapsible = false;

        vm = mountComponentWithStore(Component, { props, store });

        expect(collapseToggle()).toBe(null);
      });
    });

    it('displays an file icon in the title', () => {
      vm = mountComponentWithStore(Component, { props, store });

      expect(vm.$el.querySelector('svg.js-file-icon use').getAttribute('xlink:href')).toContain(
        'ruby',
      );
    });

    describe('file paths', () => {
      const filePaths = () => vm.$el.querySelectorAll('.file-title-name');

      it('displays the path of a added file', () => {
        props.diffFile.renamed_file = false;

        vm = mountComponentWithStore(Component, { props, store });

        expect(filePaths()).toHaveLength(1);
        expect(filePaths()[0]).toHaveText(props.diffFile.file_path);
      });

      it('displays path for deleted file', () => {
        props.diffFile.renamed_file = false;
        props.diffFile.deleted_file = true;

        vm = mountComponentWithStore(Component, { props, store });

        expect(filePaths()).toHaveLength(1);
        expect(filePaths()[0]).toHaveText(`${props.diffFile.file_path} deleted`);
      });

      it('displays old and new path if the file was renamed', () => {
        props.diffFile.renamed_file = true;

        vm = mountComponentWithStore(Component, { props, store });

        expect(filePaths()).toHaveLength(2);
        expect(filePaths()[0]).toHaveText(props.diffFile.old_path);
        expect(filePaths()[1]).toHaveText(props.diffFile.new_path);
      });
    });

    it('displays a copy to clipboard button', () => {
      vm = mountComponentWithStore(Component, { props, store });

      const button = vm.$el.querySelector('.btn-clipboard');

      expect(button).not.toBe(null);
      expect(button.dataset.clipboardText).toBe(
        '{"text":"files/ruby/popen.rb","gfm":"`files/ruby/popen.rb`"}',
      );
    });

    describe('file mode', () => {
      it('it displays old and new file mode if it changed', () => {
        props.diffFile.mode_changed = true;

        vm = mountComponentWithStore(Component, { props, store });

        const { fileMode } = vm.$refs;

        expect(fileMode).not.toBe(undefined);
        expect(fileMode).toContainText(props.diffFile.a_mode);
        expect(fileMode).toContainText(props.diffFile.b_mode);
      });

      it('does not display the file mode if it has not changed', () => {
        props.diffFile.mode_changed = false;

        vm = mountComponentWithStore(Component, { props, store });

        const { fileMode } = vm.$refs;

        expect(fileMode).toBe(undefined);
      });
    });

    describe('LFS label', () => {
      const lfsLabel = () => vm.$el.querySelector('.label-lfs');

      it('displays the LFS label for files stored in LFS', () => {
        Object.assign(props.diffFile, {
          stored_externally: true,
          external_storage: 'lfs',
        });

        vm = mountComponentWithStore(Component, { props, store });

        expect(lfsLabel()).not.toBe(null);
        expect(lfsLabel()).toHaveText('LFS');
      });

      it('does not display the LFS label for files stored in repository', () => {
        props.diffFile.stored_externally = false;

        vm = mountComponentWithStore(Component, { props, store });

        expect(lfsLabel()).toBe(null);
      });
    });

    describe('edit button', () => {
      it('should not render edit button if addMergeRequestButtons is not true', () => {
        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.$el.querySelector('.js-edit-blob')).toEqual(null);
      });

      it('should show edit button when file is editable', () => {
        props.addMergeRequestButtons = true;
        props.diffFile.edit_path = '/';
        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.$el.querySelector('.js-edit-blob')).toContainText('Edit');
      });

      it('should not show edit button when file is deleted', () => {
        props.addMergeRequestButtons = true;
        props.diffFile.deleted_file = true;
        props.diffFile.edit_path = '/';
        vm = mountComponentWithStore(Component, { props, store });

        expect(vm.$el.querySelector('.js-edit-blob')).toEqual(null);
      });
    });

    describe('addMergeRequestButtons', () => {
      beforeEach(() => {
        props.addMergeRequestButtons = true;
        props.diffFile.edit_path = '';
      });

      describe('view on environment button', () => {
        const url = 'some.external.url/';
        const title = 'url.title';

        it('displays link to external url', () => {
          props.diffFile.external_url = url;
          props.diffFile.formatted_external_url = title;

          vm = mountComponentWithStore(Component, { props, store });

          expect(vm.$el.querySelector(`a[href="${url}"]`)).not.toBe(null);
          expect(vm.$el.querySelector(`a[data-original-title="View on ${title}"]`)).not.toBe(null);
        });

        it('hides link if no external url', () => {
          props.diffFile.external_url = '';
          props.diffFile.formattedExternal_url = title;

          vm = mountComponentWithStore(Component, { props, store });

          expect(vm.$el.querySelector(`a[data-original-title="View on ${title}"]`)).toBe(null);
        });
      });
    });

    describe('handles toggle discussions', () => {
      it('renders a disabled button when diff has no discussions', () => {
        const propsCopy = Object.assign({}, props);
        propsCopy.diffFile.submodule = false;
        propsCopy.diffFile.blob = {
          id: '848ed9407c6730ff16edb3dd24485a0eea24292a',
          path: 'lib/base.js',
          name: 'base.js',
          mode: '100644',
          readable_text: true,
          icon: 'file-text-o',
        };
        propsCopy.addMergeRequestButtons = true;
        propsCopy.diffFile.deleted_file = true;

        vm = mountComponentWithStore(Component, {
          props: propsCopy,
          store,
        });

        expect(
          vm.$el.querySelector('.js-btn-vue-toggle-comments').getAttribute('disabled'),
        ).toEqual('disabled');
      });

      describe('with discussions', () => {
        it('dispatches toggleFileDiscussions when user clicks on toggle discussions button', () => {
          const propsCopy = Object.assign({}, props);
          propsCopy.diffFile.submodule = false;
          propsCopy.diffFile.blob = {
            id: '848ed9407c6730ff16edb3dd24485a0eea24292a',
            path: 'lib/base.js',
            name: 'base.js',
            mode: '100644',
            readable_text: true,
            icon: 'file-text-o',
          };
          propsCopy.addMergeRequestButtons = true;
          propsCopy.diffFile.deleted_file = true;

          const discussionGetter = () => [
            {
              ...diffDiscussionMock,
            },
          ];
          const notesModuleMock = notesModule();
          notesModuleMock.getters.discussions = discussionGetter;
          vm = mountComponentWithStore(Component, {
            props: propsCopy,
            store: new Vuex.Store({
              modules: {
                diffs: diffsModule(),
                notes: notesModuleMock,
              },
            }),
          });

          spyOn(vm, 'toggleFileDiscussions');

          vm.$el.querySelector('.js-btn-vue-toggle-comments').click();

          expect(vm.toggleFileDiscussions).toHaveBeenCalled();
        });
      });
    });
  });
});
