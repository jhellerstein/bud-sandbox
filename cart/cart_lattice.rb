require 'rubygems'
require 'bud'

ACTION_OP = 0
CHECKOUT_OP = 1

# The CartLattice represents the state of an in-progress or checked-out shopping
# cart. The cart can hold two kinds of items: add/remove operations, and
# checkout operations. Both kinds of operations are identified with a unique ID;
# internally, the set of items is represented as a map from ID to value. Each
# value in the map is a pair: [op_type, op_val]. op_type is either ACTION_OP or
# CHECKOUT_OP.
#
# For ACTION_OPs, the value is a nested pair: [item_id, mult], where mult is the
# incremental change to the number of item_id's in the cart (positive or
# negative).
#
# For CHECKOUT_OPs, the value is a single number, lbound. This identifies the
# smallest ID number that must be in the cart for it to be complete; we also
# assume that carts are intended to be "dense" -- that is, that a complete cart
# includes exactly the operations with IDs from lbound to the CHECKOUT_OP's
# ID. Naturally, a given cart can only have a single CHECKOUT_OP.
class CartLattice < Bud::Lattice
  lattice_name :lcart

  def initialize(i={})
    # Sanity check the set of operations in the cart
    i.each do |k,v|
      op_type, op_val = v

      case op_type
      when ACTION_OP
        reject_input(i) unless (op_val.class <= Enumerable && op_val.size == 2)
      when CHECKOUT_OP
      else
        reject_input(i)
      end
    end

    checkout_ops = get_checkouts(i)
    reject_input(i) unless checkout_ops.size <= 1
    unless checkout_ops.empty?
      ubound, op_val = checkout_ops.first
      lbound = op_val.last

      # All the IDs in the cart should be between the lbound ID and the ID of
      # the checkout message (inclusive).
      i.each do |k,_|
        reject_input(i) unless (k >= lbound && k <= ubound)
      end
    end

    @v = i
  end

  def merge(i)
    rv = @v.merge(i.reveal) do |k, lhs_v, rhs_v|
      raise Bud::Error unless lhs_v == rhs_v
      lhs_v
    end
    return CartLattice.new(rv)
  end

  morph :cart_done
  def cart_done
    c_list = get_checkouts(@v)
    return Bud::BoolLattice.new(false) if c_list.empty?

    ubound, op_val = c_list.first
    lbound = op_val.last
    (lbound..ubound).each do |n|
      return Bud::BoolLattice.new(false) unless @v.has_key? n
    end

    return Bud::BoolLattice.new(true)
  end

  private
  def get_checkouts(i)
    i.select {|_, v| v.first == CHECKOUT_OP}
  end
end
