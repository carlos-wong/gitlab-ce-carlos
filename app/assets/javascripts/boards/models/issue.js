/* eslint-disable no-unused-vars */
/* global ListLabel */
/* global ListMilestone */
/* global ListAssignee */

import Vue from 'vue';
import '~/vue_shared/models/label';
import IssueProject from './project';
import boardsStore from '../stores/boards_store';

class ListIssue {
  constructor(obj, defaultAvatar) {
    this.id = obj.id;
    this.iid = obj.iid;
    this.title = obj.title;
    this.confidential = obj.confidential;
    this.dueDate = obj.due_date;
    this.subscribed = obj.subscribed;
    this.labels = [];
    this.assignees = [];
    this.selected = false;
    this.position = obj.relative_position || Infinity;
    this.isFetching = {
      subscriptions: true,
    };
    this.isLoading = {};
    this.sidebarInfoEndpoint = obj.issue_sidebar_endpoint;
    this.referencePath = obj.reference_path;
    this.path = obj.real_path;
    this.toggleSubscriptionEndpoint = obj.toggle_subscription_endpoint;
    this.milestone_id = obj.milestone_id;
    this.project_id = obj.project_id;
    this.timeEstimate = obj.time_estimate;
    this.assignableLabelsEndpoint = obj.assignable_labels_endpoint;

    if (obj.project) {
      this.project = new IssueProject(obj.project);
    }

    if (obj.milestone) {
      this.milestone = new ListMilestone(obj.milestone);
    }

    obj.labels.forEach(label => {
      this.labels.push(new ListLabel(label));
    });

    this.assignees = obj.assignees.map(a => new ListAssignee(a, defaultAvatar));
  }

  addLabel(label) {
    if (!this.findLabel(label)) {
      this.labels.push(new ListLabel(label));
    }
  }

  findLabel(findLabel) {
    return this.labels.find(label => label.id === findLabel.id);
  }

  removeLabel(removeLabel) {
    if (removeLabel) {
      this.labels = this.labels.filter(label => removeLabel.id !== label.id);
    }
  }

  removeLabels(labels) {
    labels.forEach(this.removeLabel.bind(this));
  }

  addAssignee(assignee) {
    if (!this.findAssignee(assignee)) {
      this.assignees.push(new ListAssignee(assignee));
    }
  }

  findAssignee(findAssignee) {
    return this.assignees.find(assignee => assignee.id === findAssignee.id);
  }

  removeAssignee(removeAssignee) {
    if (removeAssignee) {
      this.assignees = this.assignees.filter(assignee => assignee.id !== removeAssignee.id);
    }
  }

  removeAllAssignees() {
    this.assignees = [];
  }

  getLists() {
    return boardsStore.state.lists.filter(list => list.findIssue(this.id));
  }

  updateData(newData) {
    Object.assign(this, newData);
  }

  setFetchingState(key, value) {
    this.isFetching[key] = value;
  }

  setLoadingState(key, value) {
    this.isLoading[key] = value;
  }

  update() {
    const data = {
      issue: {
        milestone_id: this.milestone ? this.milestone.id : null,
        due_date: this.dueDate,
        assignee_ids: this.assignees.length > 0 ? this.assignees.map(u => u.id) : [0],
        label_ids: this.labels.map(label => label.id),
      },
    };

    if (!data.issue.label_ids.length) {
      data.issue.label_ids = [''];
    }

    const projectPath = this.project ? this.project.path : '';
    return Vue.http.patch(`${this.path}.json`, data);
  }
}

window.ListIssue = ListIssue;

export default ListIssue;
