require 'test/unit'
require 'pxg'

class PxgTest < Test::Unit::TestCase
	def test_hello
		assert_equal "hello pxg",
		Pxg.hi()
	end
end