require 'digest/sha1'

class User < ActiveRecord::Base
  serialize :mastery, Array

  has_many :submissions
  has_many :notifications
  has_many :comments
  has_many :five_a_day_counts
  has_many :exercises, class_name: "UserExercise"
  has_many :lifecycle_events, ->{ order 'created_at ASC' }, class_name: "LifecycleEvent"

  has_many :management_contracts, class_name: "TeamManager"
  has_many :managed_teams, through: :management_contracts, source: :team
  has_many :team_memberships, ->{ where confirmed: true }, class_name: "TeamMembership", dependent: :destroy
  has_many :teams, through: :team_memberships
  has_many :inviters, through: :team_memberships, class_name: "User", foreign_key: :inviter_id
  has_many :unconfirmed_team_memberships, ->{ where confirmed: false }, class_name: "TeamMembership", dependent: :destroy
  has_many :unconfirmed_teams, through: :unconfirmed_team_memberships, source: :team

  before_save do
    self.key ||= Exercism.uuid
    true
  end

  def reset_key
    self.key = Exercism.uuid
    save
  end

  def can_access?(problem)
    ACL.where(user_id: id, language: problem.track_id, slug: problem.slug).count > 0
  end

  def self.from_github(id, username, email, avatar_url)
    user = User.where(github_id: id).first
    if user.nil?
      # try to match an invitation that has been sent.
      # GitHub ID will only be nil if the user has never logged in.
      user = User.where(username: username, github_id: nil).first
    end
    if user.nil?
      user = User.new(github_id: id, email: email)
    end

    user.github_id  = id
    user.email      = email if !user.email
    user.username   = username
    user.avatar_url = avatar_url.gsub(/\?.+$/, '') if avatar_url && !user.avatar_url
    track_event = user.new_record?
    user.save

    conflict = User.where(username: username).first
    if conflict.present? && conflict.github_id != user.github_id
      conflict.username = ''
      conflict.save
    end
    LifecycleEvent.track('joined', user.id) if track_event
    user
  end

  def self.find_or_create_in_usernames(usernames)
    members = find_in_usernames(usernames).map(&:username).map(&:downcase)
    usernames.reject {|username| members.include?(username.downcase)}.each do |username|
      User.create(username: username)
    end
    find_in_usernames(usernames)
  end

  def self.find_in_usernames(usernames)
    where(username: usernames)
  end

  def self.find_by_username(username)
    find_by(username: username)
  end

  def sees_exercises?
    ACL.where(user_id: id).count > 0
  end

  def onboarding_steps
    @onboarding_steps ||= lifecycle_events.map(&:key)
  end

  def fetched?
    onboarding_steps.include?("fetched")
  end

  def onboarded?
    !!onboarded_at
  end

  def submissions_on(problem)
    submissions.order('id DESC').where(language: problem.track_id, slug: problem.slug)
  end

  def guest?
    false
  end

  def nitpicker
    @nitpicker ||= items_where "user_exercises", "iteration_count > 0"
  end

  def owns?(submission)
    self == submission.user
  end

  def increment_five_a_day
    if five_a_day_counts.where(day: Date.today).exists?
      five_a_day_counts.where(day: Date.today).first.increment!(:total)
    else
      FiveADayCount.create(user_id: self.id, total: 1, day: Date.today)
    end
  end

  def count_existing_five_a_day_sql
    <<-SQL
      SELECT total
      FROM five_a_day_counts
      WHERE user_id=#{id}
      AND day='#{Date.today}'
    SQL
  end

  def count_existing_five_a_day
    [
      ActiveRecord::Base.connection.execute(count_existing_five_a_day_sql).field_values("total").first.to_i,
      5
    ].min
  end

  def five_a_day_exercises
    @exercises_list ||= ActiveRecord::Base.connection.execute(five_a_day_exercises_sql).to_a
  end

  def show_five_suggestions?
    onboarded? && five_available?
  end

  def five_available?
    (five_a_day_exercises.count + count_existing_five_a_day) == 5
  end

  def default_language
    ACL.select('DISTINCT language').where(user_id: id).order(:language).map(&:language).first
  end

  private

  def items_where(table, condition)
    sql = "SELECT language AS track_id, slug FROM #{table} WHERE user_id = %s AND #{condition} ORDER BY created_at ASC" % id.to_s
    User.connection.execute(sql).to_a.each_with_object(Hash.new {|h, k| h[k] = []}) do |result, problems|
      problems[result["track_id"]] << result["slug"]
    end
  end

  def five_a_day_exercises_sql
    <<-SQL
      SELECT
        e.language,
        e.slug,
        e.key,
        u.username AS username,
        COALESCE(c.comment_count, 0)
        FROM acls a
        INNER JOIN user_exercises e
          ON a.language=e.language
          AND a.slug=e.slug
        INNER JOIN users u
          ON u.id = e.user_id
        LEFT JOIN (
          SELECT
            COUNT(c.id) AS comment_count,
            s.user_exercise_id AS exercise_id,
            EVERY(c.user_id<>#{id}) AS no_comment
          FROM comments c
          INNER JOIN submissions s
          ON s.id=c.submission_id
          GROUP BY s.user_exercise_id
        ) as c
        ON c.exercise_id=e.id
        WHERE e.user_id<>#{id}
          AND a.user_id=#{id}
          AND e.archived='f'
          AND e.slug<>'hello-world'
          AND (c.no_comment='t' OR c.no_comment IS NULL)
          AND e.last_iteration_at > (NOW()-INTERVAL '30 days')
      ORDER BY COALESCE(c.comment_count, 0) ASC, e.iteration_count DESC
      LIMIT (5-#{count_existing_five_a_day});
    SQL
  end
end
