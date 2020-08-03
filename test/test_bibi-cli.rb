require 'helper'
require 'bibi/publish'

class TestBibiCLI < Test::Unit::TestCase

  def test_version
    version = Bibi::CLI.const_get('VERSION')

    assert !version.empty?, 'should have a VERSION constant'
  end

end
