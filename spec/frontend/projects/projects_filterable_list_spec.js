import ProjectsFilterableList from '~/projects/projects_filterable_list';
import { getJSONFixture, setHTMLFixture } from '../helpers/fixtures';

describe('ProjectsFilterableList', () => {
  let List;
  let form;
  let filter;
  let holder;

  beforeEach(() => {
    setHTMLFixture(`
      <form id="project-filter-form">
        <input name="name" class="js-projects-list-filter" />
      </div>
      <div class="js-projects-list-holder"></div>
    `);
    getJSONFixture('static/projects.json');
    form = document.querySelector('form#project-filter-form');
    filter = document.querySelector('.js-projects-list-filter');
    holder = document.querySelector('.js-projects-list-holder');
    List = new ProjectsFilterableList(form, filter, holder);
  });

  describe('getFilterEndpoint', () => {
    it('updates converts getPagePath for projects', () => {
      jest.spyOn(List, 'getPagePath').mockReturnValue('blah/projects?');

      expect(List.getFilterEndpoint()).toEqual('blah/projects.json?');
    });
  });
});
