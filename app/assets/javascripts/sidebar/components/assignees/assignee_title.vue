<script>
import { n__ } from '~/locale';

export default {
  name: 'AssigneeTitle',
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    numberOfAssignees: {
      type: Number,
      required: true,
    },
    editable: {
      type: Boolean,
      required: true,
    },
    assigneeable: {
      type: Boolean,
      required: true,
    },
    showToggle: {
      type: Boolean,
      required: false,
      default: false,
    },
    issuableType: {
      type: String,
      required: false,
      default: 'issue',
    }
  },
  computed: {
    assigneeTitle() {
      const assignees = this.numberOfAssignees;
      return n__('Assignee', `%d Assignees`, assignees);
    },
    assigneeableByIssueableType(){
        return this.issuableType === "merge_request" ?  this.editable : this.assigneeable;
    },
  },
};
</script>
<template>
  <div class="title hide-collapsed">
    {{ assigneeTitle }}
    <i v-if="loading" aria-hidden="true" class="fa fa-spinner fa-spin block-loading"></i>
    <a
      v-if="assigneeableByIssueableType"
      class="js-sidebar-dropdown-toggle edit-link float-right"
      href="#"
      data-track-event="click_edit_button"
      data-track-label="right_sidebar"
      data-track-property="assignee"
    >
      {{ __('Edit') }}
    </a>
    <a
      v-if="showToggle"
      :aria-label="__('Toggle sidebar')"
      class="gutter-toggle float-right js-sidebar-toggle"
      href="#"
      role="button"
    >
      <i aria-hidden="true" data-hidden="true" class="fa fa-angle-double-right"></i>
    </a>
  </div>
</template>
