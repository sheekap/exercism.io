class UserTrack
  module Queries
    def execute(sql)
      ActiveRecord::Base.connection.execute(sql).to_a
    end

    def exercise_counts_per_track(user_id)
      rows = execute(exercise_counts_per_track_sql(user_id))
      rows.each_with_object({}) do |row, counts|
        counts[row["language"]] = row["total"].to_i
      end
    end

    def exercise_counts_per_track_sql(user_id)
      <<-SQL
      SELECT COUNT(ex.id) AS total, ex.language
      FROM user_exercises ex
      INNER JOIN acls
        ON ex.language=acls.language
        AND ex.slug=acls.slug
      WHERE acls.user_id=#{user_id}
        AND ex.archived='f'
        AND ex.slug != 'hello-world'
        AND ex.iteration_count > 0
      GROUP BY ex.language
      SQL
    end

    def viewed_counts_per_track(user_id)
      rows = execute(viewed_counts_per_track_sql(user_id))
      rows.each_with_object(Hash.new(0)) do |row, counts|
        counts[row["language"]] = row["total"].to_i
      end
    end

    def viewed_counts_per_track_sql(user_id)
      <<-SQL
      SELECT COUNT(views.id) AS total, ex.language
      FROM views
      INNER JOIN user_exercises ex
        ON ex.id=views.exercise_id
      WHERE views.user_id=#{user_id}
        AND views.last_viewed_at > ex.last_activity_at
        AND ex.archived='f'
        AND ex.slug != 'hello-world'
        AND ex.iteration_count > 0
      GROUP BY ex.language
      SQL
    end

    def problem_counts_in_track(user_id, track_id)
      rows = execute(problem_counts_in_track_sql(user_id, track_id))
      rows.each_with_object({}) do |row, counts|
        counts[row["slug"]] = row["total"].to_i
      end
    end

    def problem_counts_in_track_sql(user_id, track_id)
      <<-SQL
      SELECT COUNT(ex.id) AS total, ex.slug
      FROM user_exercises ex
      INNER JOIN acls
        ON ex.language=acls.language
        AND ex.slug=acls.slug
      WHERE acls.user_id=#{user_id}
        AND ex.archived='f'
        AND ex.slug != 'hello-world'
        AND ex.iteration_count > 0
        AND ex.language='#{track_id}'
      GROUP BY ex.slug
      SQL
    end

    def viewed_counts_in_track(user_id, track_id)
      rows = execute(viewed_counts_in_track_sql(user_id, track_id))
      rows.each_with_object(Hash.new(0)) do |row, counts|
        counts[row["slug"]] = row["total"].to_i
      end
    end

    def viewed_counts_in_track_sql(user_id, track_id)
      <<-SQL
      SELECT COUNT(views.id) AS total, ex.slug
      FROM views
      INNER JOIN user_exercises ex
        ON ex.id=views.exercise_id
      WHERE views.user_id=#{user_id}
        AND views.last_viewed_at > ex.last_activity_at
        AND ex.archived='f'
        AND ex.slug != 'hello-world'
        AND ex.iteration_count > 0
        AND ex.language='#{track_id}'
      GROUP BY ex.slug
      SQL
    end
  end
end
