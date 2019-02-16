/* eslint-disable class-methods-use-this */

import { Node } from 'tiptap';

// Transforms generated HTML back to GFM for Banzai::Filter::TaskListFilter
export default class TaskList extends Node {
  get name() {
    return 'task_list';
  }

  get schema() {
    return {
      group: 'block',
      content: '(task_list_item|list_item)+',
      parseDOM: [
        {
          priority: 51,
          tag: 'ul.task-list',
        },
      ],
      toDOM: () => ['ul', { class: 'task-list' }, 0],
    };
  }

  toMarkdown(state, node) {
    state.renderList(node, '  ', () => '* ');
  }
}
