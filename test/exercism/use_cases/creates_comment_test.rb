require_relative '../../integration_helper'
require 'mocha/setup'

class CreatesCommentTest < Minitest::Test
  include DBCleaner

  def problem
    Problem.new('ruby', 'one')
  end

  def submission
    return @submission if @submission

    @submission = Submission.on(problem)
    @submission.user = User.create(username: 'bob')
    @submission.save
    @submission
  end

  def teardown
    super
    @bob = nil
    @submission = nil
  end

  def test_nitpicking_a_submission_saves_a_nit
    nitpicker = User.new(username: 'alice')
    CreatesComment.new(submission.id, nitpicker, 'Too many variables').create
    nit = submission.reload.comments.first
    assert_equal 'Too many variables', nit.body
    refute submission.liked?, "Should NOT be liked"
  end

  def test_nitpicking_increments_nit_count
    nitpicker = User.new(username: 'alice')
    assert_equal 0, submission.nit_count
    CreatesComment.create(submission.id, nitpicker, 'Too many variables')
    assert_equal 1, submission.reload.nit_count
  end

  def test_own_comment_does_not_increment_nit_count
    assert_equal 0, submission.nit_count
    CreatesComment.create(submission.id, submission.user, 'it was complicated')
    assert_equal 0, submission.reload.nit_count
  end

  def test_should_return_invalid_comment_if_invalid
    nitpicker = User.new(username: 'alice')
    cc = CreatesComment.new(submission.id, nitpicker, '')
    cc.create
    assert cc.comment
  end

  def test_empty_nit_does_not_get_created
    nitpicker = User.new(username: 'alice')
    CreatesComment.new(submission.id, nitpicker, '').create
    assert_equal 0, submission.comments(true).count
  end

  def test_nitpicking_archived_exercise_does_not_reactivate_it
    nitpicker = User.new(username: 'alice')
    exercise = UserExercise.create(
      user: nitpicker,
      archived: true,
      submissions: [ submission ]
    )

    CreatesComment.new(submission.id, nitpicker, 'a comment').create
    exercise.reload
    assert exercise.archived?
  end

  def test_nitpick_with_mentions
    nitpicker = User.new(username: 'alice')
    CreatesComment.new(submission.id, nitpicker, "Mention @#{@submission.user.username}").create
    submission.reload
    comment = submission.comments.last
    assert_equal 1, comment.mentions.count
    assert_equal submission.user, comment.mentions.first
  end

  def test_ignore_mentions_in_code_spans
    nitpicker = User.new(username: 'alice')
    CreatesComment.new(submission.id, nitpicker, "`@#{@submission.user.username}`").create
    submission.reload
    comment = submission.comments.last
    assert_equal 0, comment.mentions.count
  end

  def test_ignore_mentions_in_fenced_code_blocks
    nitpicker = User.new(username: 'alice')
    CreatesComment.new(submission.id, nitpicker, "```\n@#{submission.user.username}\n```").create
    submission.reload
    comment = submission.comments.last
    assert_equal 0, comment.mentions.count
  end

  def test_sanitation
    nitpicker = User.new(username: 'alice')
    content = "<script type=\"text/javascript\">bad();</script>good"
    ConvertsMarkdownToHTML.expects(:convert).with(content)
    CreatesComment.create(submission.id, nitpicker, content)
  end
end
