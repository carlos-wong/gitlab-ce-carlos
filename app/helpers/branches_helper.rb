# frozen_string_literal: true

module BranchesHelper
  def project_branches
    options_for_select(@project.repository.branch_names, @project.default_branch)
  end

  def protected_branch?(project, branch)
    ProtectedBranch.protected?(project, branch.name)
  end
end

BranchesHelper.prepend_if_ee('EE::BranchesHelper')
