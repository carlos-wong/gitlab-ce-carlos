import _ from 'underscore';
import { scaleLinear, scaleTime } from 'd3-scale';
import { line, area, curveLinear } from 'd3-shape';
import { extent, max, sum } from 'd3-array';
import { timeMinute, timeSecond } from 'd3-time';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';

const d3 = {
  scaleLinear,
  scaleTime,
  line,
  area,
  curveLinear,
  extent,
  max,
  timeMinute,
  timeSecond,
  sum,
};

const defaultColorPalette = {
  blue: ['#1f78d1', '#8fbce8'],
  orange: ['#fc9403', '#feca81'],
  red: ['#db3b21', '#ed9d90'],
  green: ['#1aaa55', '#8dd5aa'],
  purple: ['#6666c4', '#d1d1f0'],
};

const defaultColorOrder = ['blue', 'orange', 'red', 'green', 'purple'];

const defaultStyleOrder = ['solid', 'dashed', 'dotted'];

function queryTimeSeries(query, graphDrawData, lineStyle) {
  let usedColors = [];
  let renderCanary = false;
  const timeSeriesParsed = [];

  function pickColor(name) {
    let pick;
    if (name && defaultColorPalette[name]) {
      pick = name;
    } else {
      const unusedColors = _.difference(defaultColorOrder, usedColors);
      if (unusedColors.length > 0) {
        [pick] = unusedColors;
      } else {
        usedColors = [];
        [pick] = defaultColorOrder;
      }
    }
    usedColors.push(pick);
    return defaultColorPalette[pick];
  }

  function findByDate(series, time) {
    const val = series.find(v => Math.abs(d3.timeSecond.count(time, v.time)) < 60);
    if (val) {
      return val.value;
    }
    return NaN;
  }

  // The timeseries data may have gaps in it
  // but we need a regularly-spaced set of time/value pairs
  // this gives us a complete range of one minute intervals
  // offset the same amount as the original data
  const [minX, maxX] = graphDrawData.xDom;
  const offset = d3.timeMinute(minX) - Number(minX);
  const datesWithoutGaps = d3.timeSecond
    .every(60)
    .range(d3.timeMinute.offset(minX, -1), maxX)
    .map(d => d - offset);

  query.result.forEach((timeSeries, timeSeriesNumber) => {
    let metricTag = '';
    let lineColor = '';
    let areaColor = '';
    let shouldRenderLegend = true;
    const timeSeriesValues = timeSeries.values.map(d => d.value);
    const maximumValue = d3.max(timeSeriesValues);
    const accum = d3.sum(timeSeriesValues);
    const trackName = capitalizeFirstCharacter(query.track ? query.track : 'Stable');

    if (trackName === 'Canary') {
      renderCanary = true;
    }

    const timeSeriesMetricLabel = timeSeries.metric[Object.keys(timeSeries.metric)[0]];
    const seriesCustomizationData =
      query.series != null && _.findWhere(query.series[0].when, { value: timeSeriesMetricLabel });

    if (seriesCustomizationData) {
      metricTag = seriesCustomizationData.value || timeSeriesMetricLabel;
      [lineColor, areaColor] = pickColor(seriesCustomizationData.color);
      if (timeSeriesParsed.length > 0) {
        shouldRenderLegend = false;
      } else {
        shouldRenderLegend = true;
      }
    } else {
      metricTag = timeSeriesMetricLabel || query.label || `series ${timeSeriesNumber + 1}`;
      [lineColor, areaColor] = pickColor();
      if (timeSeriesParsed.length > 1) {
        shouldRenderLegend = false;
      }
    }

    const values = datesWithoutGaps.map(time => ({
      time,
      value: findByDate(timeSeries.values, time),
    }));

    timeSeriesParsed.push({
      linePath: graphDrawData.lineFunction(values),
      areaPath: graphDrawData.areaBelowLine(values),
      timeSeriesScaleX: graphDrawData.timeSeriesScaleX,
      timeSeriesScaleY: graphDrawData.timeSeriesScaleY,
      values: timeSeries.values,
      max: maximumValue,
      average: accum / timeSeries.values.length,
      lineStyle,
      lineColor,
      areaColor,
      metricTag,
      trackName,
      shouldRenderLegend,
      renderCanary,
    });

    if (!shouldRenderLegend) {
      if (!timeSeriesParsed[0].tracksLegend) {
        timeSeriesParsed[0].tracksLegend = [];
      }
      timeSeriesParsed[0].tracksLegend.push({
        max: maximumValue,
        average: accum / timeSeries.values.length,
        lineStyle,
        lineColor,
        metricTag,
      });
    }
  });

  return timeSeriesParsed;
}

function xyDomain(queries) {
  const allValues = queries.reduce(
    (allQueryResults, query) =>
      allQueryResults.concat(
        query.result.reduce((allResults, result) => allResults.concat(result.values), []),
      ),
    [],
  );

  const xDom = d3.extent(allValues, d => d.time);
  const yDom = [0, d3.max(allValues.map(d => d.value))];

  return {
    xDom,
    yDom,
  };
}

export function generateGraphDrawData(queries, graphWidth, graphHeight, graphHeightOffset) {
  const { xDom, yDom } = xyDomain(queries);

  const timeSeriesScaleX = d3.scaleTime().range([0, graphWidth - 70]);
  const timeSeriesScaleY = d3.scaleLinear().range([graphHeight - graphHeightOffset, 0]);

  timeSeriesScaleX.domain(xDom);
  timeSeriesScaleX.ticks(d3.timeMinute, 60);
  timeSeriesScaleY.domain(yDom);

  const defined = d => !Number.isNaN(d.value) && d.value != null;

  const lineFunction = d3
    .line()
    .defined(defined)
    .curve(d3.curveLinear) // d3 v4 uses curbe instead of interpolate
    .x(d => timeSeriesScaleX(d.time))
    .y(d => timeSeriesScaleY(d.value));

  const areaBelowLine = d3
    .area()
    .defined(defined)
    .curve(d3.curveLinear)
    .x(d => timeSeriesScaleX(d.time))
    .y0(graphHeight - graphHeightOffset)
    .y1(d => timeSeriesScaleY(d.value));

  const areaAboveLine = d3
    .area()
    .defined(defined)
    .curve(d3.curveLinear)
    .x(d => timeSeriesScaleX(d.time))
    .y0(0)
    .y1(d => timeSeriesScaleY(d.value));

  return {
    lineFunction,
    areaBelowLine,
    areaAboveLine,
    xDom,
    yDom,
    timeSeriesScaleX,
    timeSeriesScaleY,
  };
}

export default function createTimeSeries(queries, graphWidth, graphHeight, graphHeightOffset) {
  const graphDrawData = generateGraphDrawData(queries, graphWidth, graphHeight, graphHeightOffset);

  const timeSeries = queries.reduce((series, query, index) => {
    const lineStyle = defaultStyleOrder[index % defaultStyleOrder.length];
    return series.concat(queryTimeSeries(query, graphDrawData, lineStyle));
  }, []);

  return {
    timeSeries,
    graphDrawData,
  };
}
