import Api from '~/api';
import UsersCache from '~/lib/utils/users_cache';

describe('UsersCache', () => {
  const dummyUsername = 'win';
  const dummyUserId = 123;
  const dummyUser = {
    name: 'has a farm',
    username: 'farmer',
  };
  const dummyUserStatus = 'my status';

  beforeEach(() => {
    UsersCache.internalStorage = {};
  });

  describe('get', () => {
    it('returns undefined for empty cache', () => {
      expect(UsersCache.internalStorage).toEqual({});

      const user = UsersCache.get(dummyUsername);

      expect(user).toBe(undefined);
    });

    it('returns undefined for missing user', () => {
      UsersCache.internalStorage['no body'] = 'no data';

      const user = UsersCache.get(dummyUsername);

      expect(user).toBe(undefined);
    });

    it('returns matching user', () => {
      UsersCache.internalStorage[dummyUsername] = dummyUser;

      const user = UsersCache.get(dummyUsername);

      expect(user).toBe(dummyUser);
    });
  });

  describe('hasData', () => {
    it('returns false for empty cache', () => {
      expect(UsersCache.internalStorage).toEqual({});

      expect(UsersCache.hasData(dummyUsername)).toBe(false);
    });

    it('returns false for missing user', () => {
      UsersCache.internalStorage['no body'] = 'no data';

      expect(UsersCache.hasData(dummyUsername)).toBe(false);
    });

    it('returns true for matching user', () => {
      UsersCache.internalStorage[dummyUsername] = dummyUser;

      expect(UsersCache.hasData(dummyUsername)).toBe(true);
    });
  });

  describe('remove', () => {
    it('does nothing if cache is empty', () => {
      expect(UsersCache.internalStorage).toEqual({});

      UsersCache.remove(dummyUsername);

      expect(UsersCache.internalStorage).toEqual({});
    });

    it('does nothing if cache contains no matching data', () => {
      UsersCache.internalStorage['no body'] = 'no data';
      UsersCache.remove(dummyUsername);

      expect(UsersCache.internalStorage['no body']).toBe('no data');
    });

    it('removes matching data', () => {
      UsersCache.internalStorage[dummyUsername] = dummyUser;
      UsersCache.remove(dummyUsername);

      expect(UsersCache.internalStorage).toEqual({});
    });
  });

  describe('retrieve', () => {
    let apiSpy;

    beforeEach(() => {
      jest.spyOn(Api, 'users').mockImplementation((query, options) => apiSpy(query, options));
    });

    it('stores and returns data from API call if cache is empty', done => {
      apiSpy = (query, options) => {
        expect(query).toBe('');
        expect(options).toEqual({
          username: dummyUsername,
        });

        return Promise.resolve({
          data: [dummyUser],
        });
      };

      UsersCache.retrieve(dummyUsername)
        .then(user => {
          expect(user).toBe(dummyUser);
          expect(UsersCache.internalStorage[dummyUsername]).toBe(dummyUser);
        })
        .then(done)
        .catch(done.fail);
    });

    it('returns undefined if Ajax call fails and cache is empty', done => {
      const dummyError = new Error('server exploded');

      apiSpy = (query, options) => {
        expect(query).toBe('');
        expect(options).toEqual({
          username: dummyUsername,
        });

        return Promise.reject(dummyError);
      };

      UsersCache.retrieve(dummyUsername)
        .then(user => done.fail(`Received unexpected user: ${JSON.stringify(user)}`))
        .catch(error => {
          expect(error).toBe(dummyError);
        })
        .then(done)
        .catch(done.fail);
    });

    it('makes no Ajax call if matching data exists', done => {
      UsersCache.internalStorage[dummyUsername] = dummyUser;

      apiSpy = () => done.fail(new Error('expected no Ajax call!'));

      UsersCache.retrieve(dummyUsername)
        .then(user => {
          expect(user).toBe(dummyUser);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('retrieveById', () => {
    let apiSpy;

    beforeEach(() => {
      jest.spyOn(Api, 'user').mockImplementation(id => apiSpy(id));
    });

    it('stores and returns data from API call if cache is empty', done => {
      apiSpy = id => {
        expect(id).toBe(dummyUserId);

        return Promise.resolve({
          data: dummyUser,
        });
      };

      UsersCache.retrieveById(dummyUserId)
        .then(user => {
          expect(user).toBe(dummyUser);
          expect(UsersCache.internalStorage[dummyUserId]).toBe(dummyUser);
        })
        .then(done)
        .catch(done.fail);
    });

    it('returns undefined if Ajax call fails and cache is empty', done => {
      const dummyError = new Error('server exploded');

      apiSpy = id => {
        expect(id).toBe(dummyUserId);

        return Promise.reject(dummyError);
      };

      UsersCache.retrieveById(dummyUserId)
        .then(user => done.fail(`Received unexpected user: ${JSON.stringify(user)}`))
        .catch(error => {
          expect(error).toBe(dummyError);
        })
        .then(done)
        .catch(done.fail);
    });

    it('makes no Ajax call if matching data exists', done => {
      UsersCache.internalStorage[dummyUserId] = dummyUser;

      apiSpy = () => done.fail(new Error('expected no Ajax call!'));

      UsersCache.retrieveById(dummyUserId)
        .then(user => {
          expect(user).toBe(dummyUser);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('retrieveStatusById', () => {
    let apiSpy;

    beforeEach(() => {
      jest.spyOn(Api, 'userStatus').mockImplementation(id => apiSpy(id));
    });

    it('stores and returns data from API call if cache is empty', done => {
      apiSpy = id => {
        expect(id).toBe(dummyUserId);

        return Promise.resolve({
          data: dummyUserStatus,
        });
      };

      UsersCache.retrieveStatusById(dummyUserId)
        .then(userStatus => {
          expect(userStatus).toBe(dummyUserStatus);
          expect(UsersCache.internalStorage[dummyUserId].status).toBe(dummyUserStatus);
        })
        .then(done)
        .catch(done.fail);
    });

    it('returns undefined if Ajax call fails and cache is empty', done => {
      const dummyError = new Error('server exploded');

      apiSpy = id => {
        expect(id).toBe(dummyUserId);

        return Promise.reject(dummyError);
      };

      UsersCache.retrieveStatusById(dummyUserId)
        .then(userStatus => done.fail(`Received unexpected user: ${JSON.stringify(userStatus)}`))
        .catch(error => {
          expect(error).toBe(dummyError);
        })
        .then(done)
        .catch(done.fail);
    });

    it('makes no Ajax call if matching data exists', done => {
      UsersCache.internalStorage[dummyUserId] = {
        status: dummyUserStatus,
      };

      apiSpy = () => done.fail(new Error('expected no Ajax call!'));

      UsersCache.retrieveStatusById(dummyUserId)
        .then(userStatus => {
          expect(userStatus).toBe(dummyUserStatus);
        })
        .then(done)
        .catch(done.fail);
    });
  });
});
