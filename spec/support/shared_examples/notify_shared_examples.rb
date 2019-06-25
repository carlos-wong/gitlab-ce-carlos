shared_context 'gitlab email notification' do
  set(:group) { create(:group) }
  set(:subgroup) { create(:group, parent: group) }
  set(:project) { create(:project, :repository, name: 'a-known-name', group: group) }
  set(:recipient) { create(:user, email: 'recipient@example.com') }

  let(:gitlab_sender_display_name) { Gitlab.config.gitlab.email_display_name }
  let(:gitlab_sender) { Gitlab.config.gitlab.email_from }
  let(:gitlab_sender_reply_to) { Gitlab.config.gitlab.email_reply_to }
  let(:new_user_address) { 'newguy@example.com' }

  before do
    email = recipient.emails.create(email: "notifications@example.com")
    recipient.update_attribute(:notification_email, email.email)
    stub_incoming_email_setting(enabled: true, address: "reply+%{key}@#{Gitlab.config.gitlab.host}")
  end
end

shared_context 'reply-by-email is enabled with incoming address without %{key}' do
  before do
    stub_incoming_email_setting(enabled: true, address: "reply@#{Gitlab.config.gitlab.host}")
  end
end

shared_examples 'a multiple recipients email' do
  it 'is sent to the given recipient' do
    is_expected.to deliver_to recipient.notification_email
  end
end

shared_examples 'an email sent from GitLab' do
  it 'has the characteristics of an email sent from GitLab' do
    sender = subject.header[:from].addrs[0]
    reply_to = subject.header[:reply_to].addresses

    aggregate_failures do
      expect(sender.display_name).to eq(gitlab_sender_display_name)
      expect(sender.address).to eq(gitlab_sender)
      expect(reply_to).to eq([gitlab_sender_reply_to])
    end
  end
end

shared_examples 'an email sent to a user' do
  let(:group_notification_email) { 'user+group@example.com' }

  it 'is sent to user\'s global notification email address' do
    expect(subject).to deliver_to(test_recipient.notification_email)
  end

  context 'that is part of a project\'s group' do
    it 'is sent to user\'s group notification email address when set' do
      create(:notification_setting, user: test_recipient, source: project.group, notification_email: group_notification_email)
      expect(subject).to deliver_to(group_notification_email)
    end

    it 'is sent to user\'s global notification email address when no group email set' do
      create(:notification_setting, user: test_recipient, source: project.group, notification_email: '')
      expect(subject).to deliver_to(test_recipient.notification_email)
    end
  end

  context 'when project is in a sub-group', :nested_groups do
    before do
      project.update!(group: subgroup)
    end

    it 'is sent to user\'s subgroup notification email address when set' do
      # Set top-level group notification email address to make sure it doesn't get selected
      create(:notification_setting, user: test_recipient, source: group, notification_email: group_notification_email)

      subgroup_notification_email = 'user+subgroup@example.com'
      create(:notification_setting, user: test_recipient, source: subgroup, notification_email: subgroup_notification_email)

      expect(subject).to deliver_to(subgroup_notification_email)
    end

    it 'is sent to user\'s group notification email address when set and subgroup email address not set' do
      create(:notification_setting, user: test_recipient, source: subgroup, notification_email: '')
      expect(subject).to deliver_to(test_recipient.notification_email)
    end
  end
end

shared_examples 'an email that contains a header with author username' do
  it 'has X-GitLab-Author header containing author\'s username' do
    is_expected.to have_header 'X-GitLab-Author', user.username
  end
end

shared_examples 'an email with X-GitLab headers containing IDs' do
  it 'has X-GitLab-*-ID header' do
    is_expected.to have_header "X-GitLab-#{model.class.name}-ID", "#{model.id}"
  end

  it 'has X-GitLab-*-IID header if model has iid defined' do
    if model.respond_to?(:iid)
      is_expected.to have_header "X-GitLab-#{model.class.name}-IID", "#{model.iid}"
    else
      expect(subject.header["X-GitLab-#{model.class.name}-IID"]).to eq nil
    end
  end
end

shared_examples 'an email with X-GitLab headers containing project details' do
  it 'has X-GitLab-Project headers' do
    aggregate_failures do
      full_path_as_domain = "#{project.name}.#{project.namespace.path}"
      is_expected.to have_header('X-GitLab-Project', /#{project.name}/)
      is_expected.to have_header('X-GitLab-Project-Id', /#{project.id}/)
      is_expected.to have_header('X-GitLab-Project-Path', /#{project.full_path}/)
      is_expected.to have_header('List-Id', "#{project.full_path} <#{project.id}.#{full_path_as_domain}.#{Gitlab.config.gitlab.host}>")
    end
  end
end

shared_examples 'a new thread email with reply-by-email enabled' do
  it 'has the characteristics of a threaded email' do
    host = Gitlab.config.gitlab.host
    route_key = "#{model.class.model_name.singular_route_key}_#{model.id}"

    aggregate_failures do
      is_expected.to have_header('Message-ID', "<#{route_key}@#{host}>")
      is_expected.to have_header('References', /\A<reply\-.*@#{host}>\Z/ )
    end
  end
end

shared_examples 'a thread answer email with reply-by-email enabled' do
  include_examples 'an email with X-GitLab headers containing project details'
  include_examples 'an email with X-GitLab headers containing IDs'

  it 'has the characteristics of a threaded reply' do
    host = Gitlab.config.gitlab.host
    route_key = "#{model.class.model_name.singular_route_key}_#{model.id}"

    aggregate_failures do
      is_expected.to have_header('Message-ID', /\A<.*@#{host}>\Z/)
      is_expected.to have_header('In-Reply-To', "<#{route_key}@#{host}>")
      is_expected.to have_header('References', /\A<reply\-.*@#{host}> <#{route_key}@#{host}>\Z/ )
      is_expected.to have_subject(/^Re: /)
    end
  end
end

shared_examples 'an email starting a new thread with reply-by-email enabled' do
  include_examples 'an email with X-GitLab headers containing project details'
  include_examples 'an email with X-GitLab headers containing IDs'
  include_examples 'a new thread email with reply-by-email enabled'

  it 'includes "Reply to this email directly or <View it on GitLab>"' do
    expect(subject.default_part.body).to include(%(Reply to this email directly or <a href="#{Gitlab::UrlBuilder.build(model)}">view it on GitLab</a>.))
  end

  context 'when reply-by-email is enabled with incoming address with %{key}' do
    it 'has a Reply-To header' do
      is_expected.to have_header 'Reply-To', /<reply+(.*)@#{Gitlab.config.gitlab.host}>\Z/
    end
  end

  context 'when reply-by-email is enabled with incoming address without %{key}' do
    include_context 'reply-by-email is enabled with incoming address without %{key}'
    include_examples 'a new thread email with reply-by-email enabled'

    it 'has a Reply-To header' do
      is_expected.to have_header 'Reply-To', /<reply@#{Gitlab.config.gitlab.host}>\Z/
    end
  end
end

shared_examples 'an answer to an existing thread with reply-by-email enabled' do
  include_examples 'an email with X-GitLab headers containing project details'
  include_examples 'an email with X-GitLab headers containing IDs'
  include_examples 'a thread answer email with reply-by-email enabled'

  context 'when reply-by-email is enabled with incoming address with %{key}' do
    it 'has a Reply-To header' do
      is_expected.to have_header 'Reply-To', /<reply+(.*)@#{Gitlab.config.gitlab.host}>\Z/
    end
  end

  context 'when reply-by-email is enabled with incoming address without %{key}' do
    include_context 'reply-by-email is enabled with incoming address without %{key}'
    include_examples 'a thread answer email with reply-by-email enabled'

    it 'has a Reply-To header' do
      is_expected.to have_header 'Reply-To', /<reply@#{Gitlab.config.gitlab.host}>\Z/
    end
  end
end

shared_examples 'it should have Gmail Actions links' do
  it do
    aggregate_failures do
      is_expected.to have_body_text('<script type="application/ld+json">')
      is_expected.to have_body_text('ViewAction')
    end
  end
end

shared_examples 'it should not have Gmail Actions links' do
  it do
    aggregate_failures do
      is_expected.not_to have_body_text('<script type="application/ld+json">')
      is_expected.not_to have_body_text('ViewAction')
    end
  end
end

shared_examples 'it should show Gmail Actions View Issue link' do
  it_behaves_like 'it should have Gmail Actions links'

  it { is_expected.to have_body_text('View Issue') }
end

shared_examples 'it should show Gmail Actions View Merge request link' do
  it_behaves_like 'it should have Gmail Actions links'

  it { is_expected.to have_body_text('View Merge request') }
end

shared_examples 'it should show Gmail Actions View Commit link' do
  it_behaves_like 'it should have Gmail Actions links'

  it { is_expected.to have_body_text('View Commit') }
end

shared_examples 'an unsubscribeable thread' do
  it_behaves_like 'an unsubscribeable thread with incoming address without %{key}'

  it 'has a List-Unsubscribe header in the correct format, and a body link' do
    aggregate_failures do
      is_expected.to have_header('List-Unsubscribe', /unsubscribe/)
      is_expected.to have_header('List-Unsubscribe', /mailto/)
      is_expected.to have_header('List-Unsubscribe', /^<.+,.+>$/)
      is_expected.to have_body_text('unsubscribe')
    end
  end
end

shared_examples 'an unsubscribeable thread with incoming address without %{key}' do
  include_context 'reply-by-email is enabled with incoming address without %{key}'

  it 'has a List-Unsubscribe header in the correct format, and a body link' do
    aggregate_failures do
      is_expected.to have_header('List-Unsubscribe', /unsubscribe/)
      is_expected.not_to have_header('List-Unsubscribe', /mailto/)
      is_expected.to have_header('List-Unsubscribe', /^<[^,]+>$/)
      is_expected.to have_body_text('unsubscribe')
    end
  end
end

shared_examples 'a user cannot unsubscribe through footer link' do
  it 'does not have a List-Unsubscribe header or a body link' do
    aggregate_failures do
      is_expected.not_to have_header('List-Unsubscribe', /unsubscribe/)
      is_expected.not_to have_body_text('unsubscribe')
    end
  end
end

shared_examples 'an email with a labels subscriptions link in its footer' do
  it { is_expected.to have_body_text('label subscriptions') }
end

shared_examples 'a note email' do
  it_behaves_like 'it should have Gmail Actions links'

  it 'is sent to the given recipient as the author' do
    sender = subject.header[:from].addrs[0]

    aggregate_failures do
      expect(sender.display_name).to eq(note_author.name)
      expect(sender.address).to eq(gitlab_sender)
      expect(subject).to deliver_to(recipient.notification_email)
    end
  end

  it 'contains the message from the note' do
    is_expected.to have_body_text note.note
  end

  it 'does not contain note author' do
    is_expected.not_to have_body_text note.author_name
  end

  context 'when enabled email_author_in_body' do
    before do
      stub_application_setting(email_author_in_body: true)
    end

    it 'contains a link to note author' do
      is_expected.to have_body_text note.author_name
    end
  end
end

shared_examples 'appearance header and footer enabled' do
  it "contains header and footer" do
    create :appearance, header_message: "Foo", footer_message: "Bar", email_header_and_footer_enabled: true

    aggregate_failures do
      expect(subject.html_part).to have_body_text("<div class=\"header-message\" style=\"\"><p>Foo</p></div>")
      expect(subject.html_part).to have_body_text("<div class=\"footer-message\" style=\"\"><p>Bar</p></div>")

      expect(subject.text_part).to have_body_text(/^Foo/)
      expect(subject.text_part).to have_body_text(/Bar$/)
    end
  end
end

shared_examples 'appearance header and footer not enabled' do
  it "does not contain header and footer" do
    create :appearance, header_message: "Foo", footer_message: "Bar", email_header_and_footer_enabled: false

    aggregate_failures do
      expect(subject.html_part).not_to have_body_text("<div class=\"header-message\" style=\"\"><p>Foo</p></div>")
      expect(subject.html_part).not_to have_body_text("<div class=\"footer-message\" style=\"\"><p>Bar</p></div>")

      expect(subject.text_part).not_to have_body_text(/^Foo/)
      expect(subject.text_part).not_to have_body_text(/Bar$/)
    end
  end
end
