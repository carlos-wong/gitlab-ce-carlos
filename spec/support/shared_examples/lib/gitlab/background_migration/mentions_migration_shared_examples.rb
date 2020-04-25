# frozen_string_literal: true

shared_examples 'resource mentions migration' do |migration_class, resource_class|
  it 'migrates resource mentions' do
    join = migration_class::JOIN
    conditions = migration_class::QUERY_CONDITIONS

    expect do
      subject.perform(resource_class.name, join, conditions, false, resource_class.minimum(:id), resource_class.maximum(:id))
    end.to change { user_mentions.count }.by(1)

    user_mention = user_mentions.last
    expect(user_mention.mentioned_users_ids.sort).to eq(mentioned_users.pluck(:id).sort)
    expect(user_mention.mentioned_groups_ids.sort).to eq([group.id])
    expect(user_mention.mentioned_groups_ids.sort).not_to include(inaccessible_group.id)

    # check that performing the same job twice does not fail and does not change counts
    expect do
      subject.perform(resource_class.name, join, conditions, false, resource_class.minimum(:id), resource_class.maximum(:id))
    end.to change { user_mentions.count }.by(0)
  end
end

shared_examples 'resource notes mentions migration' do |migration_class, resource_class|
  before do
    note1.becomes(Note).save!
    note2.becomes(Note).save!
    note3.becomes(Note).save!
    # note4.becomes(Note).save(validate: false)
  end

  it 'migrates mentions from note' do
    join = migration_class::JOIN
    conditions = migration_class::QUERY_CONDITIONS

    # there are 4 notes for each noteable_type, but one does not have mentions and
    # another one's noteable_id points to an inexistent resource
    expect(notes.where(noteable_type: resource_class.to_s).count).to eq 4

    expect do
      subject.perform(resource_class.name, join, conditions, true, Note.minimum(:id), Note.maximum(:id))
    end.to change { user_mentions.count }.by(2)

    # check that the user_mention for regular note is created
    user_mention = user_mentions.first
    expect(Note.find(user_mention.note_id).system).to be false
    expect(user_mention.mentioned_users_ids.sort).to eq(users.pluck(:id).sort)
    expect(user_mention.mentioned_groups_ids.sort).to eq([group.id])
    expect(user_mention.mentioned_groups_ids.sort).not_to include(inaccessible_group.id)

    # check that the user_mention for system note is created
    user_mention = user_mentions.second
    expect(Note.find(user_mention.note_id).system).to be true
    expect(user_mention.mentioned_users_ids.sort).to eq(users.pluck(:id).sort)
    expect(user_mention.mentioned_groups_ids.sort).to eq([group.id])
    expect(user_mention.mentioned_groups_ids.sort).not_to include(inaccessible_group.id)

    # check that performing the same job twice does not fail and does not change counts
    expect do
      subject.perform(resource_class.name, join, conditions, true, Note.minimum(:id), Note.maximum(:id))
    end.to change { user_mentions.count }.by(0)
  end
end

shared_examples 'schedules resource mentions migration' do |resource_class, is_for_notes|
  it 'schedules background migrations' do
    Sidekiq::Testing.fake! do
      Timecop.freeze do
        migrate!

        migration = described_class::MIGRATION
        join = described_class::JOIN
        conditions = described_class::QUERY_CONDITIONS

        expect(migration).to be_scheduled_delayed_migration(2.minutes, resource_class.name, join, conditions, is_for_notes, resource1.id, resource1.id)
        expect(migration).to be_scheduled_delayed_migration(4.minutes, resource_class.name, join, conditions, is_for_notes, resource2.id, resource2.id)
        expect(migration).to be_scheduled_delayed_migration(6.minutes, resource_class.name, join, conditions, is_for_notes, resource3.id, resource3.id)
        expect(BackgroundMigrationWorker.jobs.size).to eq 3
      end
    end
  end
end
