# frozen_string_literal: true

# == Schema Information
#
# Table name: queries
#
#  id             :integer          not null, primary key
#  arranged_next  :integer
#  arranged_at    :integer
#  query_text     :string(191)
#  notes          :text(65535)
#  threshold      :float(24)
#  threshold_enbl :boolean
#  case_id        :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  options        :text(65535)
#

require 'arrangement/item'

class Query < ApplicationRecord
  # Arrangement
  include Arrangement::Item

  # Associations
  belongs_to  :case, autosave: true, optional: false

  has_many    :ratings,
              dependent: :destroy

  has_many    :snapshot_queries,
              dependent: :destroy

  # Validations
  validates :query_text,
            presence: true

  # Scopes

  def parent_list
    self.case.queries
  end

  def list_owner
    self.case
  end

  # FIXME: I dislike this method.
  # rubocop:disable Metrics/MethodLength
  def ratings_by_doc_id_and_user_id
    ratings_by_doc = {}
    ratings.each do |rating|
      user_key = rating.user_id.nil? ? 'blank' : rating.user_id.to_s
      ratings_by_doc_id = if ratings_by_doc.key? rating.doc_id
                            ratings_by_doc[rating.doc_id]
                          else
                            ratings_by_doc[rating.doc_id] = {}
                          end

      ratings_data = if ratings_by_doc_id.key? user_key
                       ratings_by_doc_id[user_key]
                     else
                       ratings_by_doc_id[user_key] = []
                     end
      ratings_data << rating
    end
    ratings_by_doc
  end
  # rubocop:enable Metrics/MethodLength

  # FIXME: I can't get good stuff.
  def relative_variance
    rand
  end

  # FIXME.  Nate, our front end doesn't support decimals at this time, yet
  # this does decimals.  https://imgflip.com/i/4rahhg
  RatingAveraged = Struct.new(:doc_id, :query_id, :rating, :id, :user_id)

  # this method may not be needed if we just use the .average(:rating) on the ActiveRecord?
  def self.ratings_averaged ratings
    ratings_by_doc = group_by_doc_id(ratings)

    ratings_averaged = []
    ratings_by_doc.each do |_key, value|
      value[:rating] = mean(value[:ratings]).round(0)

      ratings_averaged << RatingAveraged.new(value[:doc_id], value[:query_id], value[:rating])
    end
    ratings_averaged
  end

  def self.ratings_variance ratings
    ratings_by_doc = group_by_doc_id(ratings)

    ratings_variants = []

    ratings_by_doc.each do |_key, value|
      value[:rating] = variance(value[:ratings]).round(2)

      ratings_variants << RatingAveraged.new(value[:doc_id], value[:query_id], value[:rating])
    end
    ratings_variants
  end

  def self.relative_variance max_label, variance
    variance / max_label
  end

  def self.group_by_doc_id ratings
    ratings_by_doc = {}
    ratings.each do |rating|
      if ratings_by_doc.key? rating.doc_id
        ratings_by_doc[rating.doc_id][:ratings] << rating[:rating].to_f
      else
        ratings_by_doc[rating.doc_id] =
          { doc_id: rating[:doc_id], query_id: rating[:query_id], ratings: [ rating[:rating].to_f ] }
      end
    end
    ratings_by_doc
  end

  def self.group_by_doc_id_version_two ratings
    require 'pp'
    pp ratings
    ratings_by_doc = {}
    ratings.each do |rating|
      if ratings_by_doc.key? rating.doc_id
        ratings_by_doc[rating.doc_id] << rating
      else
        ratings_by_doc[rating.doc_id] = [rating]
      end
    end
    pp ratings_by_doc
    ratings_by_doc
  end


  def self.variance array_of_numbers
    m = mean(array_of_numbers)
    sum = 0.0
    array_of_numbers.each { |v| sum += (v - m)**2 }
    sum / (array_of_numbers.size - 1)
  end

  def self.sigma x
    Math.sqrt(variance(x))
  end

  def self.mean x
    x.sum(0.0) / x.size
    # x.inject(0, :+) / x.size
  end
end
