/* eslint no-param-reassign: "off" */

import $ from 'jquery';
import GfmAutoComplete from '~/gfm_auto_complete';

import 'vendor/jquery.caret';
import 'vendor/jquery.atwho';

describe('GfmAutoComplete', () => {
  const gfmAutoCompleteCallbacks = GfmAutoComplete.prototype.getDefaultCallbacks.call({
    fetchData: () => {},
  });

  let atwhoInstance;
  let items;
  let sorterValue;

  describe('DefaultOptions.sorter', () => {
    describe('assets loading', () => {
      beforeEach(() => {
        jest.spyOn(GfmAutoComplete, 'isLoading').mockReturnValue(true);

        atwhoInstance = { setting: {} };
        items = [];

        sorterValue = gfmAutoCompleteCallbacks.sorter.call(atwhoInstance, '', items);
      });

      it('should disable highlightFirst', () => {
        expect(atwhoInstance.setting.highlightFirst).toBe(false);
      });

      it('should return the passed unfiltered items', () => {
        expect(sorterValue).toEqual(items);
      });
    });

    describe('assets finished loading', () => {
      beforeEach(() => {
        jest.spyOn(GfmAutoComplete, 'isLoading').mockReturnValue(false);
        jest.spyOn($.fn.atwho.default.callbacks, 'sorter').mockImplementation(() => {});
      });

      it('should enable highlightFirst if alwaysHighlightFirst is set', () => {
        atwhoInstance = { setting: { alwaysHighlightFirst: true } };

        gfmAutoCompleteCallbacks.sorter.call(atwhoInstance);

        expect(atwhoInstance.setting.highlightFirst).toBe(true);
      });

      it('should enable highlightFirst if a query is present', () => {
        atwhoInstance = { setting: {} };

        gfmAutoCompleteCallbacks.sorter.call(atwhoInstance, 'query');

        expect(atwhoInstance.setting.highlightFirst).toBe(true);
      });

      it('should call the default atwho sorter', () => {
        atwhoInstance = { setting: {} };

        const query = 'query';
        items = [];
        const searchKey = 'searchKey';

        gfmAutoCompleteCallbacks.sorter.call(atwhoInstance, query, items, searchKey);

        expect($.fn.atwho.default.callbacks.sorter).toHaveBeenCalledWith(query, items, searchKey);
      });
    });
  });

  describe('DefaultOptions.beforeInsert', () => {
    const beforeInsert = (context, value) =>
      gfmAutoCompleteCallbacks.beforeInsert.call(context, value);

    beforeEach(() => {
      atwhoInstance = { setting: { skipSpecialCharacterTest: false } };
    });

    it('should not quote if value only contains alphanumeric charecters', () => {
      expect(beforeInsert(atwhoInstance, '@user1')).toBe('@user1');
      expect(beforeInsert(atwhoInstance, '~label1')).toBe('~label1');
    });

    it('should quote if value contains any non-alphanumeric characters', () => {
      expect(beforeInsert(atwhoInstance, '~label-20')).toBe('~"label\\-20"');
      expect(beforeInsert(atwhoInstance, '~label 20')).toBe('~"label 20"');
    });

    it('should quote integer labels', () => {
      expect(beforeInsert(atwhoInstance, '~1234')).toBe('~"1234"');
    });

    it('should escape Markdown emphasis characters, except in the first character', () => {
      expect(beforeInsert(atwhoInstance, '@_group')).toEqual('@\\_group');
      expect(beforeInsert(atwhoInstance, '~_bug')).toEqual('~\\_bug');
      expect(beforeInsert(atwhoInstance, '~a `bug`')).toEqual('~"a \\`bug\\`"');
      expect(beforeInsert(atwhoInstance, '~a ~bug')).toEqual('~"a \\~bug"');
      expect(beforeInsert(atwhoInstance, '~a **bug')).toEqual('~"a \\*\\*bug"');
    });
  });

  describe('DefaultOptions.matcher', () => {
    const defaultMatcher = (context, flag, subtext) =>
      gfmAutoCompleteCallbacks.matcher.call(context, flag, subtext);

    const flagsUseDefaultMatcher = ['@', '#', '!', '~', '%', '$'];
    const otherFlags = ['/', ':'];
    const flags = flagsUseDefaultMatcher.concat(otherFlags);

    const flagsHash = flags.reduce((hash, el) => {
      hash[el] = null;
      return hash;
    }, {});

    beforeEach(() => {
      atwhoInstance = { setting: {}, app: { controllers: flagsHash } };
    });

    const minLen = 1;
    const maxLen = 20;
    const argumentSize = [minLen, maxLen / 2, maxLen];

    const allowedSymbols = [
      '',
      'a',
      'n',
      'z',
      'A',
      'Z',
      'N',
      '0',
      '5',
      '9',
      'А',
      'а',
      'Я',
      'я',
      '.',
      "'",
      '+',
      '-',
      '_',
    ];
    const jointAllowedSymbols = allowedSymbols.join('');

    describe('should match regular symbols', () => {
      flagsUseDefaultMatcher.forEach(flag => {
        allowedSymbols.forEach(symbol => {
          argumentSize.forEach(size => {
            const query = new Array(size + 1).join(symbol);
            const subtext = flag + query;

            it(`matches argument "${flag}" with query "${subtext}"`, () => {
              expect(defaultMatcher(atwhoInstance, flag, subtext)).toBe(query);
            });
          });
        });

        it(`matches combination of allowed symbols for flag "${flag}"`, () => {
          const subtext = flag + jointAllowedSymbols;

          expect(defaultMatcher(atwhoInstance, flag, subtext)).toBe(jointAllowedSymbols);
        });
      });
    });

    describe('should not match special sequences', () => {
      const shouldNotBeFollowedBy = flags.concat(['\x00', '\x10', '\x3f', '\n', ' ']);
      const shouldNotBePrependedBy = ['`'];

      flagsUseDefaultMatcher.forEach(atSign => {
        shouldNotBeFollowedBy.forEach(followedSymbol => {
          const seq = atSign + followedSymbol;

          it(`should not match ${JSON.stringify(seq)}`, () => {
            expect(defaultMatcher(atwhoInstance, atSign, seq)).toBe(null);
          });
        });

        shouldNotBePrependedBy.forEach(prependedSymbol => {
          const seq = prependedSymbol + atSign;

          it(`should not match "${seq}"`, () => {
            expect(defaultMatcher(atwhoInstance, atSign, seq)).toBe(null);
          });
        });
      });
    });
  });

  describe('isLoading', () => {
    it('should be true with loading data object item', () => {
      expect(GfmAutoComplete.isLoading({ name: 'loading' })).toBe(true);
    });

    it('should be true with loading data array', () => {
      expect(GfmAutoComplete.isLoading(['loading'])).toBe(true);
    });

    it('should be true with loading data object array', () => {
      expect(GfmAutoComplete.isLoading([{ name: 'loading' }])).toBe(true);
    });

    it('should be false with actual array data', () => {
      expect(
        GfmAutoComplete.isLoading([{ title: 'Foo' }, { title: 'Bar' }, { title: 'Qux' }]),
      ).toBe(false);
    });

    it('should be false with actual data item', () => {
      expect(GfmAutoComplete.isLoading({ title: 'Foo' })).toBe(false);
    });
  });

  describe('Issues.insertTemplateFunction', () => {
    it('should return default template', () => {
      expect(GfmAutoComplete.Issues.insertTemplateFunction({ id: 5, title: 'Some Issue' })).toBe(
        '${atwho-at}${id}', // eslint-disable-line no-template-curly-in-string
      );
    });

    it('should return reference when reference is set', () => {
      expect(
        GfmAutoComplete.Issues.insertTemplateFunction({
          id: 5,
          title: 'Some Issue',
          reference: 'grp/proj#5',
        }),
      ).toBe('grp/proj#5');
    });
  });

  describe('Issues.templateFunction', () => {
    it('should return html with id and title', () => {
      expect(GfmAutoComplete.Issues.templateFunction({ id: 5, title: 'Some Issue' })).toBe(
        '<li><small>5</small> Some Issue</li>',
      );
    });

    it('should replace id with reference if reference is set', () => {
      expect(
        GfmAutoComplete.Issues.templateFunction({
          id: 5,
          title: 'Some Issue',
          reference: 'grp/proj#5',
        }),
      ).toBe('<li><small>grp/proj#5</small> Some Issue</li>');
    });
  });
});
