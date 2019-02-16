import * as datetimeUtility from '~/lib/utils/datetime_utility';

describe('Date time utils', () => {
  describe('timeFor', () => {
    it('returns `past due` when in past', () => {
      const date = new Date();
      date.setFullYear(date.getFullYear() - 1);

      expect(datetimeUtility.timeFor(date)).toBe('Past due');
    });

    it('returns remaining time when in the future', () => {
      const date = new Date();
      date.setFullYear(date.getFullYear() + 1);

      // Add a day to prevent a transient error. If date is even 1 second
      // short of a full year, timeFor will return '11 months remaining'
      date.setDate(date.getDate() + 1);

      expect(datetimeUtility.timeFor(date)).toBe('1 year remaining');
    });
  });

  describe('get day name', () => {
    it('should return Sunday', () => {
      const day = datetimeUtility.getDayName(new Date('07/17/2016'));

      expect(day).toBe('Sunday');
    });

    it('should return Monday', () => {
      const day = datetimeUtility.getDayName(new Date('07/18/2016'));

      expect(day).toBe('Monday');
    });

    it('should return Tuesday', () => {
      const day = datetimeUtility.getDayName(new Date('07/19/2016'));

      expect(day).toBe('Tuesday');
    });

    it('should return Wednesday', () => {
      const day = datetimeUtility.getDayName(new Date('07/20/2016'));

      expect(day).toBe('Wednesday');
    });

    it('should return Thursday', () => {
      const day = datetimeUtility.getDayName(new Date('07/21/2016'));

      expect(day).toBe('Thursday');
    });

    it('should return Friday', () => {
      const day = datetimeUtility.getDayName(new Date('07/22/2016'));

      expect(day).toBe('Friday');
    });

    it('should return Saturday', () => {
      const day = datetimeUtility.getDayName(new Date('07/23/2016'));

      expect(day).toBe('Saturday');
    });
  });

  describe('get day difference', () => {
    it('should return 7', () => {
      const firstDay = new Date('07/01/2016');
      const secondDay = new Date('07/08/2016');
      const difference = datetimeUtility.getDayDifference(firstDay, secondDay);

      expect(difference).toBe(7);
    });

    it('should return 31', () => {
      const firstDay = new Date('07/01/2016');
      const secondDay = new Date('08/01/2016');
      const difference = datetimeUtility.getDayDifference(firstDay, secondDay);

      expect(difference).toBe(31);
    });

    it('should return 365', () => {
      const firstDay = new Date('07/02/2015');
      const secondDay = new Date('07/01/2016');
      const difference = datetimeUtility.getDayDifference(firstDay, secondDay);

      expect(difference).toBe(365);
    });
  });
});

describe('timeIntervalInWords', () => {
  it('should return string with number of minutes and seconds', () => {
    expect(datetimeUtility.timeIntervalInWords(9.54)).toEqual('9 seconds');
    expect(datetimeUtility.timeIntervalInWords(1)).toEqual('1 second');
    expect(datetimeUtility.timeIntervalInWords(200)).toEqual('3 minutes 20 seconds');
    expect(datetimeUtility.timeIntervalInWords(6008)).toEqual('100 minutes 8 seconds');
  });
});

describe('dateInWords', () => {
  const date = new Date('07/01/2016');

  it('should return date in words', () => {
    expect(datetimeUtility.dateInWords(date)).toEqual('July 1, 2016');
  });

  it('should return abbreviated month name', () => {
    expect(datetimeUtility.dateInWords(date, true)).toEqual('Jul 1, 2016');
  });

  it('should return date in words without year', () => {
    expect(datetimeUtility.dateInWords(date, true, true)).toEqual('Jul 1');
  });
});

describe('monthInWords', () => {
  const date = new Date('2017-01-20');

  it('returns month name from provided date', () => {
    expect(datetimeUtility.monthInWords(date)).toBe('January');
  });

  it('returns abbreviated month name from provided date', () => {
    expect(datetimeUtility.monthInWords(date, true)).toBe('Jan');
  });
});

describe('totalDaysInMonth', () => {
  it('returns number of days in a month for given date', () => {
    // 1st Feb, 2016 (leap year)
    expect(datetimeUtility.totalDaysInMonth(new Date(2016, 1, 1))).toBe(29);

    // 1st Feb, 2017
    expect(datetimeUtility.totalDaysInMonth(new Date(2017, 1, 1))).toBe(28);

    // 1st Jan, 2017
    expect(datetimeUtility.totalDaysInMonth(new Date(2017, 0, 1))).toBe(31);
  });
});

describe('getSundays', () => {
  it('returns array of dates representing all Sundays of the month', () => {
    // December, 2017 (it has 5 Sundays)
    const dateOfSundays = [3, 10, 17, 24, 31];
    const sundays = datetimeUtility.getSundays(new Date(2017, 11, 1));

    expect(sundays.length).toBe(5);
    sundays.forEach((sunday, index) => {
      expect(sunday.getDate()).toBe(dateOfSundays[index]);
    });
  });
});

describe('getTimeframeWindowFrom', () => {
  it('returns array of date objects upto provided length (positive number) into the future starting from provided startDate', () => {
    const startDate = new Date(2018, 0, 1);
    const mockTimeframe = [
      new Date(2018, 0, 1),
      new Date(2018, 1, 1),
      new Date(2018, 2, 1),
      new Date(2018, 3, 1),
      new Date(2018, 4, 31),
    ];
    const timeframe = datetimeUtility.getTimeframeWindowFrom(startDate, 5);

    expect(timeframe.length).toBe(5);
    timeframe.forEach((timeframeItem, index) => {
      expect(timeframeItem.getFullYear()).toBe(mockTimeframe[index].getFullYear());
      expect(timeframeItem.getMonth()).toBe(mockTimeframe[index].getMonth());
      expect(timeframeItem.getDate()).toBe(mockTimeframe[index].getDate());
    });
  });

  it('returns array of date objects upto provided length (negative number) into the past starting from provided startDate', () => {
    const startDate = new Date(2018, 0, 1);
    const mockTimeframe = [
      new Date(2018, 0, 1),
      new Date(2017, 11, 1),
      new Date(2017, 10, 1),
      new Date(2017, 9, 1),
      new Date(2017, 8, 1),
    ];
    const timeframe = datetimeUtility.getTimeframeWindowFrom(startDate, -5);

    expect(timeframe.length).toBe(5);
    timeframe.forEach((timeframeItem, index) => {
      expect(timeframeItem.getFullYear()).toBe(mockTimeframe[index].getFullYear());
      expect(timeframeItem.getMonth()).toBe(mockTimeframe[index].getMonth());
      expect(timeframeItem.getDate()).toBe(mockTimeframe[index].getDate());
    });
  });
});

describe('formatTime', () => {
  const expectedTimestamps = [
    [0, '00:00:00'],
    [1000, '00:00:01'],
    [42000, '00:00:42'],
    [121000, '00:02:01'],
    [10921000, '03:02:01'],
    [108000000, '30:00:00'],
  ];

  expectedTimestamps.forEach(([milliseconds, expectedTimestamp]) => {
    it(`formats ${milliseconds}ms as ${expectedTimestamp}`, () => {
      expect(datetimeUtility.formatTime(milliseconds)).toBe(expectedTimestamp);
    });
  });
});

describe('datefix', () => {
  describe('pad', () => {
    it('should add a 0 when length is smaller than 2', () => {
      expect(datetimeUtility.pad(2)).toEqual('02');
    });

    it('should not add a zero when length matches the default', () => {
      expect(datetimeUtility.pad(12)).toEqual('12');
    });

    it('should add a 0 when length is smaller than the provided', () => {
      expect(datetimeUtility.pad(12, 3)).toEqual('012');
    });
  });

  describe('parsePikadayDate', () => {
    // removed because of https://gitlab.com/gitlab-org/gitlab-ce/issues/39834
  });

  describe('pikadayToString', () => {
    it('should format a UTC date into yyyy-mm-dd format', () => {
      expect(datetimeUtility.pikadayToString(new Date('2020-01-29:00:00'))).toEqual('2020-01-29');
    });
  });
});

describe('prettyTime methods', () => {
  const assertTimeUnits = (obj, minutes, hours, days, weeks) => {
    expect(obj.minutes).toBe(minutes);
    expect(obj.hours).toBe(hours);
    expect(obj.days).toBe(days);
    expect(obj.weeks).toBe(weeks);
  };

  describe('parseSeconds', () => {
    it('should correctly parse a negative value', () => {
      const zeroSeconds = datetimeUtility.parseSeconds(-1000);

      assertTimeUnits(zeroSeconds, 16, 0, 0, 0);
    });

    it('should correctly parse a zero value', () => {
      const zeroSeconds = datetimeUtility.parseSeconds(0);

      assertTimeUnits(zeroSeconds, 0, 0, 0, 0);
    });

    it('should correctly parse a small non-zero second values', () => {
      const subOneMinute = datetimeUtility.parseSeconds(10);
      const aboveOneMinute = datetimeUtility.parseSeconds(100);
      const manyMinutes = datetimeUtility.parseSeconds(1000);

      assertTimeUnits(subOneMinute, 0, 0, 0, 0);
      assertTimeUnits(aboveOneMinute, 1, 0, 0, 0);
      assertTimeUnits(manyMinutes, 16, 0, 0, 0);
    });

    it('should correctly parse large second values', () => {
      const aboveOneHour = datetimeUtility.parseSeconds(4800);
      const aboveOneDay = datetimeUtility.parseSeconds(110000);
      const aboveOneWeek = datetimeUtility.parseSeconds(25000000);

      assertTimeUnits(aboveOneHour, 20, 1, 0, 0);
      assertTimeUnits(aboveOneDay, 33, 6, 3, 0);
      assertTimeUnits(aboveOneWeek, 26, 0, 3, 173);
    });

    it('should correctly accept a custom param for hoursPerDay', () => {
      const config = { hoursPerDay: 24 };

      const aboveOneHour = datetimeUtility.parseSeconds(4800, config);
      const aboveOneDay = datetimeUtility.parseSeconds(110000, config);
      const aboveOneWeek = datetimeUtility.parseSeconds(25000000, config);

      assertTimeUnits(aboveOneHour, 20, 1, 0, 0);
      assertTimeUnits(aboveOneDay, 33, 6, 1, 0);
      assertTimeUnits(aboveOneWeek, 26, 8, 4, 57);
    });

    it('should correctly accept a custom param for daysPerWeek', () => {
      const config = { daysPerWeek: 7 };

      const aboveOneHour = datetimeUtility.parseSeconds(4800, config);
      const aboveOneDay = datetimeUtility.parseSeconds(110000, config);
      const aboveOneWeek = datetimeUtility.parseSeconds(25000000, config);

      assertTimeUnits(aboveOneHour, 20, 1, 0, 0);
      assertTimeUnits(aboveOneDay, 33, 6, 3, 0);
      assertTimeUnits(aboveOneWeek, 26, 0, 0, 124);
    });

    it('should correctly accept custom params for daysPerWeek and hoursPerDay', () => {
      const config = { daysPerWeek: 55, hoursPerDay: 14 };

      const aboveOneHour = datetimeUtility.parseSeconds(4800, config);
      const aboveOneDay = datetimeUtility.parseSeconds(110000, config);
      const aboveOneWeek = datetimeUtility.parseSeconds(25000000, config);

      assertTimeUnits(aboveOneHour, 20, 1, 0, 0);
      assertTimeUnits(aboveOneDay, 33, 2, 2, 0);
      assertTimeUnits(aboveOneWeek, 26, 0, 1, 9);
    });
  });

  describe('stringifyTime', () => {
    it('should stringify values with all non-zero units', () => {
      const timeObject = {
        weeks: 1,
        days: 4,
        hours: 7,
        minutes: 20,
      };

      const timeString = datetimeUtility.stringifyTime(timeObject);

      expect(timeString).toBe('1w 4d 7h 20m');
    });

    it('should stringify values with some non-zero units', () => {
      const timeObject = {
        weeks: 0,
        days: 4,
        hours: 0,
        minutes: 20,
      };

      const timeString = datetimeUtility.stringifyTime(timeObject);

      expect(timeString).toBe('4d 20m');
    });

    it('should stringify values with no non-zero units', () => {
      const timeObject = {
        weeks: 0,
        days: 0,
        hours: 0,
        minutes: 0,
      };

      const timeString = datetimeUtility.stringifyTime(timeObject);

      expect(timeString).toBe('0m');
    });

    it('should return non-condensed representation of time object', () => {
      const timeObject = { weeks: 1, days: 0, hours: 1, minutes: 0 };

      expect(datetimeUtility.stringifyTime(timeObject, true)).toEqual('1 week 1 hour');
    });
  });

  describe('abbreviateTime', () => {
    it('should abbreviate stringified times for weeks', () => {
      const fullTimeString = '1w 3d 4h 5m';

      expect(datetimeUtility.abbreviateTime(fullTimeString)).toBe('1w');
    });

    it('should abbreviate stringified times for non-weeks', () => {
      const fullTimeString = '0w 3d 4h 5m';

      expect(datetimeUtility.abbreviateTime(fullTimeString)).toBe('3d');
    });
  });
});

describe('calculateRemainingMilliseconds', () => {
  beforeEach(() => {
    spyOn(Date, 'now').and.callFake(() => new Date('2063-04-04T00:42:00Z').getTime());
  });

  it('calculates the remaining time for a given end date', () => {
    const milliseconds = datetimeUtility.calculateRemainingMilliseconds('2063-04-04T01:44:03Z');

    expect(milliseconds).toBe(3723000);
  });

  it('returns 0 if the end date has passed', () => {
    const milliseconds = datetimeUtility.calculateRemainingMilliseconds('2063-04-03T00:00:00Z');

    expect(milliseconds).toBe(0);
  });
});

describe('newDate', () => {
  it('returns new date instance from existing date instance', () => {
    const initialDate = new Date(2019, 0, 1);
    const copiedDate = datetimeUtility.newDate(initialDate);

    expect(copiedDate.getTime()).toBe(initialDate.getTime());

    initialDate.setMonth(initialDate.getMonth() + 1);

    expect(copiedDate.getTime()).not.toBe(initialDate.getTime());
  });

  it('returns date instance when provided date param is not of type date or is undefined', () => {
    const initialDate = datetimeUtility.newDate();

    expect(initialDate instanceof Date).toBe(true);
  });
});
