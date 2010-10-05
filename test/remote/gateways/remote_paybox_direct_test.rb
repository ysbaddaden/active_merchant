require 'test_helper'
require File.expand_path("../../../../lib/active_merchant/billing/gateways/paybox_direct.rb", __FILE__)

class RemotePayboxDirectTest < Test::Unit::TestCase
  
  def setup
    @gateway = PayboxDirectGateway.new(fixtures(:paybox_direct))
    
    @amount = 100
    @credit_card = credit_card('1111222233334444')
    @declined_card = credit_card('1111222233334445')
    
    @options = { 
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
    
    @recurring_options = {
      :order_id => '1',
      :subscription_id => 'activemerchant_remote_test'
    }
  end
  
  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'The transaction was approved', response.message
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal "PAYBOX : Numéro de porteur invalide", response.message
  end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'The transaction was approved', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization, :order_id => '1')
    assert_success capture
  end
  
  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'The transaction was approved', purchase.message
    assert purchase.authorization
    # Paybox requires you to remember the expiration date
    assert void = @gateway.void(purchase.authorization, :order_id => '1', :amount => @amount)
    assert_equal 'The transaction was approved', void.message
    assert_success void
  end

  def test_failed_capture
    assert response = @gateway.capture(@amount, '', :order_id => '1')
    assert_failure response
    assert_equal "Mandatory values missing keyword:13 Type:1", response.message
  end
  
  def test_purchase_and_partial_credit
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase
    assert_equal 'The transaction was approved', purchase.message
    assert purchase.authorization
    assert credit = @gateway.credit(@amount / 2, purchase.authorization, :order_id => '1')
    assert_equal 'The transaction was approved', credit.message
    assert_success credit
  end
  
  def test_invalid_login
    gateway = PayboxDirectGateway.new(
                :login => '199988899',
                :password => '1999888F'
              )
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "PAYBOX : Accès refusé ou site/rang/clé invalide", response.message
  end
  
  def test_recurring
    assert sub = @gateway.recurring(@amount, @credit_card, @recurring_options)
    assert_success sub
    assert_equal 'The transaction was approved', sub.message
    
    assert update = @gateway.update_recurring(200, @credit_card, @recurring_options)
    assert_success update
    assert_equal 'The transaction was approved', update.message
    
    assert cancel = @gateway.cancel_recurring(@recurring_options)
    assert_success cancel
  rescue => e
    cleanup_recurring
    raise e
  end
  
  def test_recurring_authorize_and_capture
    sub, partial = create_recurring
    
    assert auth = @gateway.authorize_recurring(@amount, partial, @recurring_options)
    assert_success auth
    assert auth.authorization
    assert_equal 'The transaction was approved', auth.message
    
    assert capture = @gateway.capture_recurring(@amount, auth.authorization, @recurring_options)
    assert_success capture
  ensure
    cleanup_recurring
  end
  
  def test_recurring_purchase
    sub, partial = create_recurring
    
    assert response = @gateway.purchase_recurring(@amount, partial, @recurring_options)
    assert_success response
    assert_equal 'The transaction was approved', response.message
  ensure
    cleanup_recurring
  end
  
  def test_recurring_purchase_and_void
    sub, partial = create_recurring
    
    assert purchase = @gateway.purchase_recurring(@amount, partial, @recurring_options)
    assert_success purchase
    assert_equal 'The transaction was approved', purchase.message
    assert purchase.authorization
    
    assert void = @gateway.void_recurring(purchase.authorization,
      @recurring_options.merge(:amount => @amount))
    assert_success void
    assert_equal 'The transaction was approved', void.message
  ensure
    cleanup_recurring
  end
  
  private
    def cleanup_recurring
      @gateway.cancel_recurring(@recurring_options)
    end
    
    # paybox requires you to remember partial fields from the credit card
    def create_recurring
      sub = @gateway.recurring(@amount, @credit_card, @recurring_options)
      [sub, credit_card(sub.params['porteur'])]
    end
end
