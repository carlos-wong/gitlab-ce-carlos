import { SUPPORTED_FORMATS, getFormatter } from '~/lib/utils/unit_format';
import { s__ } from '~/locale';

const yAxisBoundaryGap = [0.1, 0.1];
/**
 * Max string length of formatted axis tick
 */
const maxDataAxisTickLength = 8;

//  Defaults
const defaultFormat = SUPPORTED_FORMATS.number;

const defaultYAxisFormat = defaultFormat;
const defaultYAxisPrecision = 2;

const defaultTooltipFormat = defaultFormat;
const defaultTooltipPrecision = 3;

// Give enough space for y-axis with units and name.
const chartGridLeft = 75;

// Axis options

/**
 * Converts .yml parameters to echarts axis options for data axis
 * @param {Object} param - Dashboard .yml definition options
 */
const getDataAxisOptions = ({ format, precision, name }) => {
  const formatter = getFormatter(format);

  return {
    name,
    nameLocation: 'center', // same as gitlab-ui's default
    scale: true,
    axisLabel: {
      formatter: val => formatter(val, precision, maxDataAxisTickLength),
    },
  };
};

/**
 * Converts .yml parameters to echarts y-axis options
 * @param {Object} param - Dashboard .yml definition options
 */
export const getYAxisOptions = ({
  name = s__('Metrics|Values'),
  format = defaultYAxisFormat,
  precision = defaultYAxisPrecision,
} = {}) => {
  return {
    nameGap: 63, // larger gap than gitlab-ui's default to fit with formatted numbers
    scale: true,
    boundaryGap: yAxisBoundaryGap,

    ...getDataAxisOptions({
      name,
      format,
      precision,
    }),
  };
};

// Chart grid

/**
 * Grid with enough room to display chart.
 */
export const getChartGrid = ({ left = chartGridLeft } = {}) => ({ left });

// Tooltip options

export const getTooltipFormatter = ({
  format = defaultTooltipFormat,
  precision = defaultTooltipPrecision,
} = {}) => {
  const formatter = getFormatter(format);
  return num => formatter(num, precision);
};
