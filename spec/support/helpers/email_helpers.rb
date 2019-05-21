module EmailHelpers
  def sent_to_user(user, recipients: email_recipients)
    recipients.count { |to| to == user.notification_email }
  end

  def reset_delivered_emails!
    ActionMailer::Base.deliveries.clear
  end

  def should_only_email(*users, kind: :to)
    recipients = email_recipients(kind: kind)

    users.each { |user| should_email(user, recipients: recipients) }

    expect(recipients.count).to eq(users.count)
  end

  def should_email(user, times: 1, recipients: email_recipients)
    amount = sent_to_user(user, recipients: recipients)
    failed_message = lambda { "User #{user.username} (#{user.id}): email test failed (expected #{times}, got #{amount})" }
    expect(amount).to eq(times), failed_message
  end

  def should_not_email(user, recipients: email_recipients)
    should_email(user, times: 0, recipients: recipients)
  end

  def should_not_email_anyone
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  def email_recipients(kind: :to)
    ActionMailer::Base.deliveries.flat_map(&kind)
  end

  def find_email_for(user)
    ActionMailer::Base.deliveries.find { |d| d.to.include?(user.notification_email) }
  end

  def have_referable_subject(referable, include_project: true, reply: false)
    prefix = (include_project && referable.project ? "#{referable.project.name} | " : '').freeze
    prefix = "Re: #{prefix}" if reply

    suffix = "#{referable.title} (#{referable.to_reference})"

    have_subject [prefix, suffix].compact.join
  end
end
