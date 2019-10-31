/* eslint-disable func-names, no-var, one-var, camelcase, no-param-reassign, no-return-assign, consistent-return, no-cond-assign, no-else-return */
import _ from 'underscore';

export default {
  parse_log(log) {
    var by_author, by_email, data, entry, i, len, total, normalized_email;
    total = {};
    by_author = {};
    by_email = {};
    for (i = 0, len = log.length; i < len; i += 1) {
      entry = log[i];
      if (total[entry.date] == null) {
        this.add_date(entry.date, total);
      }
      normalized_email = entry.author_email.toLowerCase();
      data = by_author[entry.author_name] || by_email[normalized_email];
      if (data == null) {
        data = this.add_author(entry, by_author, by_email);
      }
      if (!data[entry.date]) {
        this.add_date(entry.date, data);
      }
      this.store_data(entry, total[entry.date], data[entry.date]);
    }
    total = _.toArray(total);
    by_author = _.toArray(by_author);
    return {
      total,
      by_author,
    };
  },
  add_date(date, collection) {
    collection[date] = {};
    return (collection[date].date = date);
  },
  add_author(author, by_author, by_email) {
    var data, normalized_email;
    data = {};
    data.author_name = author.author_name;
    data.author_email = author.author_email;
    normalized_email = author.author_email.toLowerCase();
    by_author[author.author_name] = data;
    by_email[normalized_email] = data;
    return data;
  },
  store_data(entry, total, by_author) {
    this.store_commits(total, by_author);
    this.store_additions(entry, total, by_author);
    return this.store_deletions(entry, total, by_author);
  },
  store_commits(total, by_author) {
    this.add(total, 'commits', 1);
    return this.add(by_author, 'commits', 1);
  },
  add(collection, field, value) {
    if (collection[field] == null) {
      collection[field] = 0;
    }
    return (collection[field] += value);
  },
  store_additions(entry, total, by_author) {
    if (entry.additions == null) {
      entry.additions = 0;
    }
    this.add(total, 'additions', entry.additions);
    return this.add(by_author, 'additions', entry.additions);
  },
  store_deletions(entry, total, by_author) {
    if (entry.deletions == null) {
      entry.deletions = 0;
    }
    this.add(total, 'deletions', entry.deletions);
    return this.add(by_author, 'deletions', entry.deletions);
  },
  get_total_data(parsed_log, field) {
    var log, total_data;
    log = parsed_log.total;
    total_data = this.pick_field(log, field);
    return _.sortBy(total_data, d => d.date);
  },
  pick_field(log, field) {
    var total_data;
    total_data = [];
    _.each(log, d => total_data.push(_.pick(d, [field, 'date'])));
    return total_data;
  },
  get_author_data(parsed_log, field, date_range) {
    var author_data, log;
    if (date_range == null) {
      date_range = null;
    }
    log = parsed_log.by_author;
    author_data = [];
    _.each(
      log,
      (function(_this) {
        return function(log_entry) {
          var parsed_log_entry;
          parsed_log_entry = _this.parse_log_entry(log_entry, field, date_range);
          if (!_.isEmpty(parsed_log_entry.dates)) {
            return author_data.push(parsed_log_entry);
          }
        };
      })(this),
    );
    return _.sortBy(author_data, d => d[field]).reverse();
  },
  parse_log_entry(log_entry, field, date_range) {
    var parsed_entry;
    parsed_entry = {};

    parsed_entry.author_name = log_entry.author_name;
    parsed_entry.author_email = log_entry.author_email;
    parsed_entry.dates = {};

    parsed_entry.commits = 0;
    parsed_entry.additions = 0;
    parsed_entry.deletions = 0;

    _.each(
      _.omit(log_entry, 'author_name', 'author_email'),
      (function(_this) {
        return function(value) {
          if (_this.in_range(value.date, date_range)) {
            parsed_entry.dates[value.date] = value[field];
            parsed_entry.commits += value.commits;
            parsed_entry.additions += value.additions;
            return (parsed_entry.deletions += value.deletions);
          }
        };
      })(this),
    );
    return parsed_entry;
  },
  in_range(date, date_range) {
    var ref;
    if (date_range === null || (date_range[0] <= (ref = new Date(date)) && ref <= date_range[1])) {
      return true;
    } else {
      return false;
    }
  },
};
