require File.expand_path(File.dirname(__FILE__) + '/test_helper')

describe "#import" do
  
  it "should return the number of inserts performed" do
    assert_difference "Topic.count", +10 do
      result = Topic.import Build(3, :topics)
      assert_equal 3, result.num_inserts

      result = Topic.import Build(7, :topics)
      assert_equal 7, result.num_inserts
    end
  end
  
  context "with :validation option" do
    let(:columns) { %w(title author_name) }
    let(:valid_values) { [[ "LDAP", "Jerry Carter"], ["Rails Recipes", "Chad Fowler"]] }
    let(:invalid_values) { [[ "The RSpec Book", ""], ["Agile+UX", ""]] }
  
    context "with validation checks turned off" do
      it "should import valid data" do
        assert_difference "Topic.count", +2 do
          result = Topic.import columns, valid_values, :validate => false
          assert_equal 2, result.num_inserts
        end
      end
  
      it "should import invalid data" do
        assert_difference "Topic.count", +2 do
          result = Topic.import columns, invalid_values, :validate => false
          assert_equal 2, result.num_inserts
        end
      end
    end
  
    context "with validation checks turned on" do
      it "should import valid data" do
        assert_difference "Topic.count", +2 do
          result = Topic.import columns, valid_values, :validate => true
          assert_equal 2, result.num_inserts
        end
      end
  
      it "should not import invalid data" do
        assert_no_difference "Topic.count" do
          result = Topic.import columns, invalid_values, :validate => true
          assert_equal 0, result.num_inserts
        end
      end

      it "should report the failed instances" do
        results = Topic.import columns, invalid_values, :validate => true
        assert_equal invalid_values.size, results.failed_instances.size
        results.failed_instances.each{ |e| assert_kind_of Topic, e }
      end

      it "should import valid data when mixed with invalid data" do
        assert_difference "Topic.count", +2 do
          result = Topic.import columns, valid_values + invalid_values, :validate => true
          assert_equal 2, result.num_inserts
        end
        assert_equal 0, Topic.find_all_by_title(invalid_values.map(&:first)).count
      end
    end
  end

  context "with an array of unsaved model instances" do
    let(:topic) { Build(:topic, :title => "The RSpec Book", :author_name => "David Chelimsky")}
    let(:topics) { Build(9, :topics) }
    let(:invalid_topics){ Build(7, :invalid_topics)}
    
    it "should import records based on those model's attributes" do
      assert_difference "Topic.count", +9 do
        result = Topic.import topics
        assert_equal 9, result.num_inserts
      end
      
      Topic.import [topic]
      assert Topic.find_by_title_and_author_name("The RSpec Book", "David Chelimsky")
    end

    it "should not overwrite existing records" do
      topic = Generate(:topic, :title => "foobar")
      assert_no_difference "Topic.count" do
        begin
          topic.title = "baz"
          Topic.import [topic]
        rescue Exception
          # no-op
        end
      end
      assert_equal "foobar", topic.reload.title
    end
    
    context "with validation checks turned on" do
      it "should import valid models" do
        assert_difference "Topic.count", +9 do
          result = Topic.import topics, :validate => true
          assert_equal 9, result.num_inserts
        end
      end
      
      it "should not import invalid models" do
        assert_no_difference "Topic.count" do
          result = Topic.import invalid_topics, :validate => true
          assert_equal 0, result.num_inserts
        end
      end
    end
    
    context "with validation checks turned off" do
      it "should import invalid models" do
        assert_difference "Topic.count", +7 do
          result = Topic.import invalid_topics, :validate => false
          assert_equal 7, result.num_inserts
        end
      end
    end
  end
  
  context "with an array of columns and an array of unsaved model instances" do
    let(:topics) { Build(2, :topics) }
    
    it "should import records populating the supplied columns with the corresponding model instance attributes" do
      assert_difference "Topic.count", +2 do
        result = Topic.import [:author_name, :title], topics
        assert_equal 2, result.num_inserts
      end
      
      # imported topics should be findable by their imported attributes
      assert Topic.find_by_author_name(topics.first.author_name)
      assert Topic.find_by_author_name(topics.last.author_name)
    end

    it "should not populate fields for columns not imported" do
      topics.first.author_email_address = "zach.dennis@gmail.com"
      assert_difference "Topic.count", +2 do
        result = Topic.import [:author_name, :title], topics
        assert_equal 2, result.num_inserts
      end
      
      assert !Topic.find_by_author_email_address("zach.dennis@gmail.com")
    end
  end

  context "ActiveRecord timestamps" do
    context "when the timestamps columns are present" do
      setup do
        Delorean.time_travel_to("5 minutes ago") do
          assert_difference "Book.count", +1 do
            result = Book.import [:title, :author_name, :publisher], [["LDAP", "Big Bird", "Del Rey"]]
            assert_equal 1, result.num_inserts
          end
          @book = Book.first
        end
      end
    
      it "should set the created_at column for new records"  do
        assert_equal 5.minutes.ago.strftime("%H:%m"), @book.created_at.strftime("%H:%m")
      end

      it "should set the created_on column for new records" do
        assert_equal 5.minutes.ago.strftime("%H:%m"), @book.created_on.strftime("%H:%m")
      end

      it "should set the updated_at column for new records" do
        assert_equal 5.minutes.ago.strftime("%H:%m"), @book.updated_at.strftime("%H:%m")
      end

      it "should set the updated_on column for new records" do
        assert_equal 5.minutes.ago.strftime("%H:%m"), @book.updated_on.strftime("%H:%m")
      end
    end
    
    context "when a custom time zone is set" do
      setup do
        original_timezone = ActiveRecord::Base.default_timezone
        ActiveRecord::Base.default_timezone = :utc
        Delorean.time_travel_to("5 minutes ago") do
          assert_difference "Book.count", +1 do
            result = Book.import [:title, :author_name, :publisher], [["LDAP", "Big Bird", "Del Rey"]]
            assert_equal 1, result.num_inserts
          end
        end
        ActiveRecord::Base.default_timezone = original_timezone
        @book = Book.first
      end

      it "should set the created_at column for new records respecting the time zone"  do
        assert_equal 5.minutes.ago.utc.strftime("%H:%m"), @book.created_at.strftime("%H:%m")
      end

      it "should set the created_on column for new records respecting the time zone" do
        assert_equal 5.minutes.ago.utc.strftime("%H:%m"), @book.created_on.strftime("%H:%m")
      end

      it "should set the updated_at column for new records respecting the time zone" do
        assert_equal 5.minutes.ago.utc.strftime("%H:%m"), @book.updated_at.strftime("%H:%m")
      end

      it "should set the updated_on column for new records respecting the time zone" do
        assert_equal 5.minutes.ago.utc.strftime("%H:%m"), @book.updated_on.strftime("%H:%m")
      end
    end
  end

  context "importing with database reserved words" do
    let(:group) { Build(:group, :order => "superx") }
    
    it "should import just fine" do
      assert_difference "Group.count", +1 do
        result = Group.import [group]
        assert_equal 1, result.num_inserts
      end
      assert_equal "superx", Group.first.order
    end
  end
  
    
  # 
  # describe "computing insert value sets" do
  #   context "when the max allowed bytes is 33 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 3 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 40 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 3 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 41 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 2 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 48 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 2 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 49 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 1 value sets of 7 bytes a piece"
  #   end
  # 
  #   context "when the max allowed bytes is 999999 and the base SQL is 26 bytes" do
  #     it "should return 3 value sets when given 1 value sets of 7 bytes a piece"
  #   end
  # end
end