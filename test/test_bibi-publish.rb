require 'helper'
require 'bibi/publish'

class TestBibiPublish < Test::Unit::TestCase

  def test_version
    version = Bibi::Publish.const_get('VERSION')

    assert !version.empty?, 'should have a VERSION constant'
  end

end
