# frozen_string_literal: true

json.array! @memberships, partial: 'memberships/membership', as: :membership
