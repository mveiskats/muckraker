require 'test_helper'

class LineParserTest < ActiveSupport::TestCase
  HEADER = 'I, [2000-01-01T00:00:00.123456 #12345]  INFO -- : '

  test 'line type :started' do
    str = [
      HEADER,
      'Started GET "/foo" for 1.1.1.1 at 2000-01-01 00:00:00 +0000',
      "\n",
    ].join
    assert_equal :started, LineParser.parse(str)[0]
  end

  test 'line type :processing' do
    str = [
      HEADER,
      'Processing by Devise::SessionsController#create as HTML',
      "\n",
    ].join
    assert_equal :processing, LineParser.parse(str)[0]
  end

  test 'line type :parameters' do
    str = [
      HEADER,
      '  Parameters: {"utf8"=>"✓", "foo"=>"bar"}',
      "\n",
    ].join
    assert_equal :parameters, LineParser.parse(str)[0]
  end

  test 'line type :completed' do
    str = [
      HEADER,
      'Completed 200 OK in 123.4ms (Views: 12.3ms | ActiveRecord: 111.1ms)',
      "\n",
    ].join
    assert_equal :completed, LineParser.parse(str)[0]
  end

  test 'line type :user' do
    str = [
      HEADER,
      'User id: 123456',
      "\n",
    ].join
    assert_equal :user, LineParser.parse(str)[0]
  end

  test 'line type :error_header' do
    str = HEADER + "\n"
    assert_equal :error_header, LineParser.parse(str)[0]
  end

  test 'line type :other' do
    str = %q(NoMethodError (undefined method `foo' for nil:NilClass):) + "\n"
    assert_equal :other, LineParser.parse(str)[0]
  end
end
