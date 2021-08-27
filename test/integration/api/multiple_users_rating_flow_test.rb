# frozen_string_literal: true

require 'test_helper'

class MultipleUsersRatingFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  let(:owner)                 { users(:team_owner) }
  let(:member1)               { users(:team_member_1) }
  let(:member2)               { users(:team_member_2) }
  let(:matt)                  { users(:matt) }
  let(:team)                  { teams(:team_owner_team) }
  let(:matt_case)             { cases(:matt_case) }

  # rubocop:disable Layout/LineLength
  test 'create a team of raters and have them rate' do
    post users_login_url params: { user:  { email: owner.email, password: 'password' }, format: :json }

    assert_difference 'team.members.count' do
      post api_team_members_url(team), params: { id: matt.id }
    end

    assert_difference 'team.cases.count' do
      post api_team_cases_url(team), params: { id: matt_case.id }
    end

    queries_texts = %w[frog duck]
    assert_difference 'matt_case.queries.count', 2 do
      queries_texts.each do |query_text|
        post api_case_queries_url(matt_case), params: { query: { query_text: query_text } }
        # puts json_response
      end
    end

    # for each of the two queries, we rate 3 deep
    # owner rates 0's
    # member1 rates 1's
    # member2 rates 2's
    ratings_counter = 0
    rating_value = 0
    raters = [ owner, member1, member2 ]
    raters.each do |rater|
      matt_case.queries.each do |query|
        (1..3).each do |doc_counter|
          put api_case_query_ratings_url(matt_case, query),
              params: { rating: { doc_id: "doc_#{query.query_text}_#{doc_counter}", user_id: rater.id, rating: rating_value } }
          ratings_counter += 1
        end
      end
      rating_value += 1
    end

    # confirm that only the last rater rating sticks.
    matt_case.queries.each do |query|
      query.ratings.each do |rating|
        # assert_equal rating.user.id, member2.id
      end
    end

    # and 18 ratings (raters * queries * docs) generated.
    assert_equal ratings_counter, matt_case.ratings.size

    # Lets grab our case!
    get api_case_url(matt_case)

    body = JSON.parse(response.body)

    query = body['queries'].select { |q| 'frog' == q['query_text'] }.first

    # check the average of a 0, 1, and 2 rating:
    # back to 2, cause we only return the most recent rating.
    # assert_equal query['ratings']['doc_frog_1'], 2

    # check that the logged in user, the owner, gets their ratings back.
    assert_equal query['ratings']['doc_frog_1'], 0

    metadatum = matt_case.metadata.where(user_id: owner.id).first

    metadatum.consolidated_ratings_view!

    get api_case_url(matt_case)

    body = JSON.parse(response.body)

    query = body['queries'].select { |q| 'frog' == q['query_text'] }.first

    # check that the logged in user, the owner, gets the averaged rating back.
    assert_equal query['ratings']['doc_frog_1'], 1
  end
  # rubocop:enable Layout/LineLength
end
