import { __ } from '~/locale';

export const sidebarAnimationDuration = 300; // milliseconds.

export const chartHeight = 300;
/**
 * Valid strings for this regex are
 * 2019-10-01 and 2019-10-01 01:02:03
 */
export const dateTimePickerRegex = /^(\d{4})-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])(?: (0[0-9]|1[0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9]))?$/;

export const graphTypes = {
  deploymentData: 'scatter',
};

export const symbolSizes = {
  default: 14,
};

export const lineTypes = {
  default: 'solid',
};

export const timeWindows = {
  thirtyMinutes: __('30 minutes'),
  threeHours: __('3 hours'),
  eightHours: __('8 hours'),
  oneDay: __('1 day'),
  threeDays: __('3 days'),
  oneWeek: __('1 week'),
};

export const dateFormats = {
  timeOfDay: 'h:MM TT',
  default: 'dd mmm yyyy, h:MMTT',
  dateTimePicker: {
    format: 'yyyy-mm-dd hh:mm:ss',
    ISODate: "yyyy-mm-dd'T'HH:MM:ss'Z'",
    stringDate: 'yyyy-mm-dd HH:MM:ss',
  },
};

export const secondsIn = {
  thirtyMinutes: 60 * 30,
  threeHours: 60 * 60 * 3,
  eightHours: 60 * 60 * 8,
  oneDay: 60 * 60 * 24 * 1,
  threeDays: 60 * 60 * 24 * 3,
  oneWeek: 60 * 60 * 24 * 7 * 1,
};

export const timeWindowsKeyNames = Object.keys(secondsIn).reduce(
  (otherTimeWindows, timeWindow) => ({
    ...otherTimeWindows,
    [timeWindow]: timeWindow,
  }),
  {},
);
