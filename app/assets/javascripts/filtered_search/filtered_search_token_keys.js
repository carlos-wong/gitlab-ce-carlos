export default class FilteredSearchTokenKeys {
  constructor(tokenKeys = [], alternativeTokenKeys = [], conditions = []) {
    this.tokenKeys = tokenKeys;
    this.alternativeTokenKeys = alternativeTokenKeys;
    this.conditions = conditions;

    this.tokenKeysWithAlternative = this.tokenKeys.concat(this.alternativeTokenKeys);
  }

  get() {
    return this.tokenKeys;
  }

  getKeys() {
    return this.tokenKeys.map(i => i.key);
  }

  getAlternatives() {
    return this.alternativeTokenKeys;
  }

  getConditions() {
    return this.conditions;
  }

  shouldUppercaseTokenName(tokenKey) {
    const token = this.searchByKey(tokenKey.toLowerCase());
    return token && token.uppercaseTokenName;
  }

  shouldCapitalizeTokenValue(tokenKey) {
    const token = this.searchByKey(tokenKey.toLowerCase());
    return token && token.capitalizeTokenValue;
  }

  searchByKey(key) {
    return this.tokenKeys.find(tokenKey => tokenKey.key === key) || null;
  }

  searchBySymbol(symbol) {
    return this.tokenKeys.find(tokenKey => tokenKey.symbol === symbol) || null;
  }

  searchByKeyParam(keyParam) {
    return (
      this.tokenKeysWithAlternative.find(tokenKey => {
        let tokenKeyParam = tokenKey.key;

        // Replace hyphen with underscore to compare keyParam with tokenKeyParam
        // e.g. 'my-reaction' => 'my_reaction'
        tokenKeyParam = tokenKeyParam.replace('-', '_');

        if (tokenKey.param) {
          tokenKeyParam += `_${tokenKey.param}`;
        }

        return keyParam === tokenKeyParam;
      }) || null
    );
  }

  searchByConditionUrl(url) {
    return this.conditions.find(condition => condition.url === url) || null;
  }

  searchByConditionKeyValue(key, value) {
    return (
      this.conditions.find(
        condition =>
          condition.tokenKey === key && condition.value.toLowerCase() === value.toLowerCase(),
      ) || null
    );
  }

  addExtraTokensForMergeRequests() {
    const wipToken = {
      key: 'wip',
      type: 'string',
      param: '',
      symbol: '',
      icon: 'admin',
      tag: 'Yes or No',
      lowercaseValueOnSubmit: true,
      uppercaseTokenName: true,
      capitalizeTokenValue: true,
    };

    this.tokenKeys.push(wipToken);
    this.tokenKeysWithAlternative.push(wipToken);
  }
}
