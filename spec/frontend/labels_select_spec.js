import $ from 'jquery';
import LabelsSelect from '~/labels_select';

const mockUrl = '/foo/bar/url';

const mockLabels = [
  {
    id: 26,
    title: 'Foo Label',
    description: 'Foobar',
    color: '#BADA55',
    text_color: '#FFFFFF',
  },
];

const mockScopedLabels = [
  {
    id: 27,
    title: 'Foo::Bar',
    description: 'Foobar',
    color: '#333ABC',
    text_color: '#FFFFFF',
  },
];

const mockScopedLabels2 = [
  {
    id: 28,
    title: 'Foo::Bar2',
    description: 'Foobar2',
    color: '#FFFFFF',
    text_color: '#000000',
  },
];

describe('LabelsSelect', () => {
  describe('getLabelTemplate', () => {
    describe('when normal label is present', () => {
      const label = mockLabels[0];
      let $labelEl;

      beforeEach(() => {
        $labelEl = $(
          LabelsSelect.getLabelTemplate({
            labels: mockLabels,
            issueUpdateURL: mockUrl,
            enableScopedLabels: true,
            scopedLabelsDocumentationLink: 'docs-link',
          }),
        );
      });

      it('generated label item template has correct label URL', () => {
        expect($labelEl.find('a').attr('href')).toBe('/foo/bar?label_name[]=Foo%20Label');
      });

      it('generated label item template has correct label title', () => {
        expect($labelEl.find('span.gl-label-text').text()).toBe(label.title);
      });

      it('generated label item template has label description as title attribute', () => {
        expect($labelEl.find('a').attr('title')).toBe(label.description);
      });

      it('generated label item template has correct label styles', () => {
        expect($labelEl.find('span.gl-label-text').attr('style')).toBe(
          `background-color: ${label.color}; color: ${label.text_color};`,
        );
      });

      it('generated label item has a gl-label-text class', () => {
        expect($labelEl.find('span').hasClass('gl-label-text')).toEqual(true);
      });

      it('generated label item template does not have gl-label-icon class', () => {
        expect($labelEl.find('.gl-label-icon')).toHaveLength(0);
      });
    });

    describe('when scoped label is present', () => {
      const label = mockScopedLabels[0];
      let $labelEl;

      beforeEach(() => {
        $labelEl = $(
          LabelsSelect.getLabelTemplate({
            labels: mockScopedLabels,
            issueUpdateURL: mockUrl,
            enableScopedLabels: true,
            scopedLabelsDocumentationLink: 'docs-link',
          }),
        );
      });

      it('generated label item template has correct label URL', () => {
        expect($labelEl.find('a').attr('href')).toBe('/foo/bar?label_name[]=Foo%3A%3ABar');
      });

      it('generated label item template has correct label title', () => {
        const scopedTitle = label.title.split('::');
        expect($labelEl.find('span.gl-label-text').text()).toContain(scopedTitle[0]);
        expect($labelEl.find('span.gl-label-text').text()).toContain(scopedTitle[1]);
      });

      it('generated label item template has html flag as true', () => {
        expect($labelEl.find('a').attr('data-html')).toBe('true');
      });

      it('generated label item template has question icon', () => {
        expect($labelEl.find('i.fa-question-circle')).toHaveLength(1);
      });

      it('generated label item template has gl-label-icon class', () => {
        expect($labelEl.find('.gl-label-icon')).toHaveLength(1);
      });

      it('generated label item template has correct label styles', () => {
        expect($labelEl.find('span.gl-label-text').attr('style')).toBe(
          `background-color: ${label.color}; color: ${label.text_color};`,
        );
        expect(
          $labelEl
            .find('span.gl-label-text')
            .last()
            .attr('style'),
        ).toBe(`color: ${label.color};`);
      });

      it('generated label item has a badge class', () => {
        expect($labelEl.find('span').hasClass('gl-label-text')).toEqual(true);
      });
    });

    describe('when scoped label is present, with text color not white', () => {
      const label = mockScopedLabels2[0];
      let $labelEl;

      beforeEach(() => {
        $labelEl = $(
          LabelsSelect.getLabelTemplate({
            labels: mockScopedLabels2,
            issueUpdateURL: mockUrl,
            enableScopedLabels: true,
            scopedLabelsDocumentationLink: 'docs-link',
          }),
        );
      });

      it('generated label item template has correct label styles', () => {
        expect($labelEl.find('span.gl-label-text').attr('style')).toBe(
          `background-color: ${label.color}; color: ${label.text_color};`,
        );
        expect(
          $labelEl
            .find('span.gl-label-text')
            .last()
            .attr('style'),
        ).toBe(`color: ${label.text_color};`);
      });
    });
  });
});
