import actions from '~/ide/stores/actions';
import store from '~/ide/stores';
import service from '~/ide/services';
import router from '~/ide/ide_router';
import eventHub from '~/ide/eventhub';
import consts from '~/ide/stores/modules/commit/constants';
import { resetStore, file } from 'spec/ide/helpers';

describe('IDE commit module actions', () => {
  beforeEach(() => {
    spyOn(router, 'push');
  });

  afterEach(() => {
    resetStore(store);
  });

  describe('updateCommitMessage', () => {
    it('updates store with new commit message', done => {
      store
        .dispatch('commit/updateCommitMessage', 'testing')
        .then(() => {
          expect(store.state.commit.commitMessage).toBe('testing');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('discardDraft', () => {
    it('resets commit message to blank', done => {
      store.state.commit.commitMessage = 'testing';

      store
        .dispatch('commit/discardDraft')
        .then(() => {
          expect(store.state.commit.commitMessage).not.toBe('testing');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('updateCommitAction', () => {
    it('updates store with new commit action', done => {
      store
        .dispatch('commit/updateCommitAction', '1')
        .then(() => {
          expect(store.state.commit.commitAction).toBe('1');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('updateBranchName', () => {
    it('updates store with new branch name', done => {
      store
        .dispatch('commit/updateBranchName', 'branch-name')
        .then(() => {
          expect(store.state.commit.newBranchName).toBe('branch-name');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('setLastCommitMessage', () => {
    beforeEach(() => {
      Object.assign(store.state, {
        currentProjectId: 'abcproject',
        projects: {
          abcproject: {
            web_url: 'http://testing',
          },
        },
      });
    });

    it('updates commit message with short_id', done => {
      store
        .dispatch('commit/setLastCommitMessage', { short_id: '123' })
        .then(() => {
          expect(store.state.lastCommitMsg).toContain(
            'Your changes have been committed. Commit <a href="http://testing/commit/123" class="commit-sha">123</a>',
          );
        })
        .then(done)
        .catch(done.fail);
    });

    it('updates commit message with stats', done => {
      store
        .dispatch('commit/setLastCommitMessage', {
          short_id: '123',
          stats: {
            additions: '1',
            deletions: '2',
          },
        })
        .then(() => {
          expect(store.state.lastCommitMsg).toBe(
            'Your changes have been committed. Commit <a href="http://testing/commit/123" class="commit-sha">123</a> with 1 additions, 2 deletions.',
          );
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('updateFilesAfterCommit', () => {
    const data = {
      id: '123',
      message: 'testing commit message',
      committed_date: '123',
      committer_name: 'root',
    };
    const branch = 'master';
    let f;

    beforeEach(() => {
      spyOn(eventHub, '$emit');

      f = file('changedFile');
      Object.assign(f, {
        active: true,
        changed: true,
        content: 'file content',
      });

      store.state.currentProjectId = 'abcproject';
      store.state.currentBranchId = 'master';
      store.state.projects.abcproject = {
        web_url: 'web_url',
        branches: {
          master: {
            workingReference: '',
          },
        },
      };
      store.state.stagedFiles.push(f, {
        ...file('changedFile2'),
        changed: true,
      });
      store.state.openFiles = store.state.stagedFiles;

      store.state.stagedFiles.forEach(stagedFile => {
        store.state.entries[stagedFile.path] = stagedFile;
      });
    });

    it('updates stores working reference', done => {
      store
        .dispatch('commit/updateFilesAfterCommit', {
          data,
          branch,
        })
        .then(() => {
          expect(store.state.projects.abcproject.branches.master.workingReference).toBe(data.id);
        })
        .then(done)
        .catch(done.fail);
    });

    it('resets all files changed status', done => {
      store
        .dispatch('commit/updateFilesAfterCommit', {
          data,
          branch,
        })
        .then(() => {
          store.state.openFiles.forEach(entry => {
            expect(entry.changed).toBeFalsy();
          });
        })
        .then(done)
        .catch(done.fail);
    });

    it('sets files commit data', done => {
      store
        .dispatch('commit/updateFilesAfterCommit', {
          data,
          branch,
        })
        .then(() => {
          expect(f.lastCommitSha).toBe(data.id);
        })
        .then(done)
        .catch(done.fail);
    });

    it('updates raw content for changed file', done => {
      store
        .dispatch('commit/updateFilesAfterCommit', {
          data,
          branch,
        })
        .then(() => {
          expect(f.raw).toBe(f.content);
        })
        .then(done)
        .catch(done.fail);
    });

    it('emits changed event for file', done => {
      store
        .dispatch('commit/updateFilesAfterCommit', {
          data,
          branch,
        })
        .then(() => {
          expect(eventHub.$emit).toHaveBeenCalledWith(`editor.update.model.content.${f.key}`, {
            content: f.content,
            changed: false,
          });
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('commitChanges', () => {
    let visitUrl;

    beforeEach(() => {
      visitUrl = spyOnDependency(actions, 'visitUrl');

      document.body.innerHTML += '<div class="flash-container"></div>';

      store.state.currentProjectId = 'abcproject';
      store.state.currentBranchId = 'master';
      store.state.projects.abcproject = {
        web_url: 'webUrl',
        branches: {
          master: {
            workingReference: '1',
          },
        },
      };

      const f = {
        ...file('changed'),
        type: 'blob',
        active: true,
        lastCommitSha: '123456789',
      };
      store.state.stagedFiles.push(f);
      store.state.changedFiles = [
        {
          ...f,
        },
      ];
      store.state.openFiles = store.state.changedFiles;

      store.state.openFiles.forEach(localF => {
        store.state.entries[localF.path] = localF;
      });

      store.state.commit.commitAction = '2';
      store.state.commit.commitMessage = 'testing 123';
    });

    afterEach(() => {
      document.querySelector('.flash-container').remove();
    });

    describe('success', () => {
      const COMMIT_RESPONSE = {
        id: '123456',
        short_id: '123',
        message: 'test message',
        committed_date: 'date',
        stats: {
          additions: '1',
          deletions: '2',
        },
      };

      beforeEach(() => {
        spyOn(service, 'commit').and.returnValue(
          Promise.resolve({
            data: COMMIT_RESPONSE,
          }),
        );
      });

      it('calls service', done => {
        store
          .dispatch('commit/commitChanges')
          .then(() => {
            expect(service.commit).toHaveBeenCalledWith('abcproject', {
              branch: jasmine.anything(),
              commit_message: 'testing 123',
              actions: [
                {
                  action: 'update',
                  file_path: jasmine.anything(),
                  content: undefined,
                  encoding: jasmine.anything(),
                  last_commit_id: undefined,
                  previous_path: undefined,
                },
              ],
              start_branch: 'master',
            });

            done();
          })
          .catch(done.fail);
      });

      it('sends lastCommit ID when not creating new branch', done => {
        store.state.commit.commitAction = '1';

        store
          .dispatch('commit/commitChanges')
          .then(() => {
            expect(service.commit).toHaveBeenCalledWith('abcproject', {
              branch: jasmine.anything(),
              commit_message: 'testing 123',
              actions: [
                {
                  action: 'update',
                  file_path: jasmine.anything(),
                  content: undefined,
                  encoding: jasmine.anything(),
                  last_commit_id: '123456789',
                  previous_path: undefined,
                },
              ],
              start_branch: undefined,
            });

            done();
          })
          .catch(done.fail);
      });

      it('sets last Commit Msg', done => {
        store
          .dispatch('commit/commitChanges')
          .then(() => {
            expect(store.state.lastCommitMsg).toBe(
              'Your changes have been committed. Commit <a href="webUrl/commit/123" class="commit-sha">123</a> with 1 additions, 2 deletions.',
            );

            done();
          })
          .catch(done.fail);
      });

      it('adds commit data to files', done => {
        store
          .dispatch('commit/commitChanges')
          .then(() => {
            expect(store.state.entries[store.state.openFiles[0].path].lastCommitSha).toBe(
              COMMIT_RESPONSE.id,
            );

            done();
          })
          .catch(done.fail);
      });

      it('resets stores commit actions', done => {
        store.state.commit.commitAction = consts.COMMIT_TO_NEW_BRANCH;

        store
          .dispatch('commit/commitChanges')
          .then(() => {
            expect(store.state.commit.commitAction).not.toBe(consts.COMMIT_TO_NEW_BRANCH);
          })
          .then(done)
          .catch(done.fail);
      });

      it('removes all staged files', done => {
        store
          .dispatch('commit/commitChanges')
          .then(() => {
            expect(store.state.stagedFiles.length).toBe(0);
          })
          .then(done)
          .catch(done.fail);
      });

      describe('merge request', () => {
        it('redirects to new merge request page', done => {
          spyOn(eventHub, '$on');

          store.state.commit.commitAction = consts.COMMIT_TO_NEW_BRANCH;
          store.state.commit.shouldCreateMR = true;

          store
            .dispatch('commit/commitChanges')
            .then(() => {
              expect(visitUrl).toHaveBeenCalledWith(
                `webUrl/merge_requests/new?merge_request[source_branch]=${
                  store.getters['commit/placeholderBranchName']
                }&merge_request[target_branch]=master`,
              );

              done();
            })
            .catch(done.fail);
        });

        it('does not redirect to new merge request page when shouldCreateMR is not checked', done => {
          spyOn(eventHub, '$on');

          store.state.commit.commitAction = consts.COMMIT_TO_NEW_BRANCH;
          store.state.commit.shouldCreateMR = false;

          store
            .dispatch('commit/commitChanges')
            .then(() => {
              expect(visitUrl).not.toHaveBeenCalled();
              done();
            })
            .catch(done.fail);
        });

        it('resets changed files before redirecting', done => {
          spyOn(eventHub, '$on');

          store.state.commit.commitAction = '3';

          store
            .dispatch('commit/commitChanges')
            .then(() => {
              expect(store.state.stagedFiles.length).toBe(0);

              done();
            })
            .catch(done.fail);
        });
      });
    });

    describe('failed', () => {
      beforeEach(() => {
        spyOn(service, 'commit').and.returnValue(
          Promise.resolve({
            data: {
              message: 'failed message',
            },
          }),
        );
      });

      it('shows failed message', done => {
        store
          .dispatch('commit/commitChanges')
          .then(() => {
            const alert = document.querySelector('.flash-container');

            expect(alert.textContent.trim()).toBe('failed message');

            done();
          })
          .catch(done.fail);
      });
    });
  });
});
