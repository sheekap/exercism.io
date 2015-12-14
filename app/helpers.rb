module ExercismWeb
  module Helpers
    {
      Session: 'session',
      FuzzyTime: 'fuzzy_time',
      NgEsc: 'ng_esc',
      Markdown: 'markdown',
      Syntax: 'syntax',
      NotificationCount: 'notification_count',
      Gravatar: 'gravatar',
      Profile: 'profile',
      Submission: 'submission',
      SiteTitle: 'site_title',
    }.each do |name, file|
      autoload name, Exercism.relative_to_root('app', 'helpers', file)
    end
  end
end
