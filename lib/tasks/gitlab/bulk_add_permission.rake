namespace :gitlab do
  namespace :import do
    desc "GitLab | Import | Add all users to all projects (admin users are added as maintainers)"
    task all_users_to_all_projects: :environment  do |t, args|
      user_ids = User.where(admin: false).pluck(:id)
      admin_ids = User.where(admin: true).pluck(:id)
      project_ids = Project.pluck(:id)

      puts "Importing #{user_ids.size} users into #{project_ids.size} projects"
      ProjectMember.add_users_to_projects(project_ids, user_ids, ProjectMember::DEVELOPER)

      puts "Importing #{admin_ids.size} admins into #{project_ids.size} projects"
      ProjectMember.add_users_to_projects(project_ids, admin_ids, ProjectMember::MAINTAINER)
    end

    desc "GitLab | Import | Add a specific user to all projects (as a developer)"
    task :user_to_projects, [:email] => :environment do |t, args|
      user = User.find_by(email: args.email)
      project_ids = Project.pluck(:id)
      puts "Importing #{user.email} users into #{project_ids.size} projects"
      ProjectMember.add_users_to_projects(project_ids, Array.wrap(user.id), ProjectMember::DEVELOPER)
    end

    desc "GitLab | Import | Add all users to all groups (admin users are added as owners)"
    task all_users_to_all_groups: :environment do |t, args|
      user_ids = User.where(admin: false).pluck(:id)
      admin_ids = User.where(admin: true).pluck(:id)
      groups = Group.all

      puts "Importing #{user_ids.size} users into #{groups.size} groups"
      puts "Importing #{admin_ids.size} admins into #{groups.size} groups"
      groups.each do |group|
        group.add_users(user_ids, GroupMember::DEVELOPER)
        group.add_users(admin_ids, GroupMember::OWNER)
      end
    end

    desc "GitLab | Import | Add a specific user to all groups (as a developer)"
    task :user_to_groups, [:email] => :environment do |t, args|
      user = User.find_by_email args.email
      groups = Group.all
      puts "Importing #{user.email} users into #{groups.size} groups"
      groups.each do |group|
        group.add_users(Array.wrap(user.id), GroupMember::DEVELOPER)
      end
    end
  end
end
