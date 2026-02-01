# frozen_string_literal: true

class BiddingRound
  ActiveAdmin.register Pledge do
    menu false
    actions :index

    filter :bidding_round, as: :select

    includes membership: [ :basket_size, :member ]
    csv do
      column(:member) { |p| p.membership.member&.display_id }
      column(:membership) { |p| p.membership_id }
      column(:basket_size) { |p| p.membership.basket_size.name }
      column(BiddingRound.human_attribute_name(:default_basket_size_price)) { |p|
        cur(p.membership.basket_size.price, precision: 3)
      }
      column(BiddingRound.human_attribute_name(:pledged_basket_size_price)) { |p|
        cur(p.basket_size_price)
      }
      column(BiddingRound.human_attribute_name(:pledged_at)) { |p|
        p.created_at
      }
    end

    controller do
      def index
        if request.format.csv?
          super
        else
          raise ActionController::RoutingError.new("Not Found")
        end
      end

      def csv_filename
        bidding_round = BiddingRound.find(params[:q][:bidding_round_id_eq])
        "#{bidding_round.filename}-pledges.csv"
      end
    end
  end
end
