require 'rubygems'
require 'bud'
require 'test/unit'
require 'test/kvs_workloads'
require 'kvs/kvs'
require 'kvs/useful_combos'

class TestKVS < Test::Unit::TestCase
  include KVSWorkloads

  def initialize(args)
    @opts = {'dump' => true, 'visualize' => true, 'scoping' => false}
    super
  end

  def test_wl2
    # reliable delivery fails if the recipient is down
    v = SingleSiteKVS.new("localhost", 12347, nil) # {'visualize' => true})
    assert_nothing_raised(RuntimeError) {v.run_bg}
    sleep 1
    add_members(v, "localhost:12347", "localhost:12348")
    if v.is_a?  ReliableDelivery
      sleep 1
      workload1(v)
      assert_equal(0, v.kvstate.length)
    end
  end

  def test_wl5
    # the unmetered kvs fails on a disorderly workload
    v = SingleSiteKVS.new("localhost", 12352, @opts)
    assert_nothing_raised(RuntimeError) {v.run_bg}
    add_members(v, "localhost:12352")
    assert_raise(Bud::KeyConstraintError)  { workload2(v) }
  end

  def test_wl1
    # in a distributed, ordered workload, the right thing happens
    v = BestEffortReplicatedKVS.new("localhost", 12345, @opts)
    v2 = BestEffortReplicatedKVS.new("localhost", 12346, @opts)
    assert_nothing_raised(RuntimeError) {v.run_bg}
    assert_nothing_raised(RuntimeError) {v2.run_bg}
    add_members(v, "localhost:12345", "localhost:12346")
    add_members(v2, "localhost:12345", "localhost:12346")
    sleep 2

    workload1(v)

    assert_equal(1, v.kvstate.length)
    assert_equal("bak", v.kvstate.first[1])
    assert_equal(1, v2.kvstate.length)
    assert_equal("bak", v2.kvstate.first[1])
  end

  def test_simple
    v = SingleSiteKVS.new("localhost", 12360, {'dump' => true, 'scoping' => false, 'visualize' => true})
    assert_nothing_raised(RuntimeError) {v.run_bg}
    add_members(v, "localhost:12360")
    sleep 1 
    workload1(v)
    assert_equal(1, v.kvstate.length)
    assert_equal("bak", v.kvstate.first[1])
  end
end

